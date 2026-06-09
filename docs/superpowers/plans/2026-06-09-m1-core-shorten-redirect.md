# M1 — Core: Shorten + Redirect + SQLite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the first vertical slice of Royal Shortener: an anonymous user can POST a long URL to `/api/links`, gets back `{slug, short_url, secret}`, and `GET /:slug` redirects to the target. The landing page form drives the real API.

**Architecture:** Backend gains a SQLite layer (`sqlight`), a tiny migrations runner, a `links` storage module, and two new HTTP endpoints. The router resolves slug conflicts against reserved top-level paths (`api`, `health`, etc.). The frontend swaps its local `random_slug` for an actual `POST /api/links` via `rsvp` and displays both the short URL and the `secret`. Each task ends with a passing test and a commit.

**Tech Stack:** Gleam (BEAM) + wisp + mist + sqlight + gleam_json on the backend; Gleam (JS target) + lustre + rsvp on the frontend; gleeunit for tests on both sides.

**Source spec:** `docs/superpowers/specs/2026-06-09-product-vision-and-roadmap-design.md` § M1.

**Commit policy for this repo:** Never include a `Co-Authored-By` trailer. Plain author only.

---

## File Map

### Backend — create

- `backend/priv/migrations/001_links.sql` — schema for the `links` table (M1 columns only — expiry and click_limit come in M2).
- `backend/src/backend/slug.gleam` — random royal slug generation, user-slug validation, reserved-slug check.
- `backend/src/backend/db.gleam` — `sqlight` connection helpers and a tiny migration runner.
- `backend/src/backend/links.gleam` — `create` and `find_by_slug` storage operations.
- `backend/src/backend/api.gleam` — `POST /api/links` handler: parse JSON body, validate, call `links.create`, return JSON.
- `backend/test/backend/slug_test.gleam`
- `backend/test/backend/db_test.gleam`
- `backend/test/backend/links_test.gleam`
- `backend/test/backend/router_test.gleam`

### Backend — modify

- `backend/gleam.toml` — add `sqlight`, `gleam_json` deps.
- `backend/manifest.toml` — refreshed by `gleam deps download`.
- `backend/src/backend.gleam` — open DB at startup, run migrations, pass connection to the router via a closure.
- `backend/src/backend/router.gleam` — `/api/links` POST, single-segment top-level `/:slug` GET redirect, 404 for unknown slugs, keep `/health` and SPA fallback.
- `backend/test/backend_test.gleam` — drop the hello-world test (it'll get auto-run anyway and we want a clean slate).

### Backend — secret store

- `backend/.gitignore` — add `*.sqlite3` and `priv/data/` so dev DB never gets committed.

### Frontend — create

- `frontend/src/royal/api.gleam` — typed HTTP client using `rsvp`: `create_link(url, slug_opt)`.
- `frontend/test/royal/api_test.gleam` — decoder test for the response shape.

### Frontend — modify

- `frontend/gleam.toml` — add `rsvp` and `gleam_json` deps.
- `frontend/manifest.toml` — refreshed.
- `frontend/src/royal/types.gleam` — extend `Minted` with `secret: String`; add `MintSucceeded`/`MintFailed` `Msg` variants; add `error: Option(String)` to `Model`.
- `frontend/src/royal/app.gleam` — `shorten` issues an `Effect` calling `api.create_link` instead of synthesising a slug locally. Handle success/failure.
- `frontend/src/royal/view.gleam` — show the `secret` block with "save this — it's your management key" copy; render error if `Model.error` is `Some`.

### Frontend — keep but adjust

- `frontend/src/royal/data.gleam` — `random_slug` becomes dead code. Either delete or leave as utility; this plan deletes it (call site goes away, do not leave orphan code).

---

## Task 1: Slug module — pure functions, no deps

This is pure logic. We TDD it first because it has zero infrastructure surface.

**Files:**
- Create: `backend/src/backend/slug.gleam`
- Create: `backend/test/backend/slug_test.gleam`

### - [ ] Step 1.1: Write failing tests for slug validation and reserved check

Replace contents of `backend/test/backend/slug_test.gleam`:

```gleam
import backend/slug
import gleeunit/should

pub fn valid_slug_accepts_typical_input_test() {
  slug.validate_user_slug("Sovereign-7qz")
  |> should.equal(Ok("Sovereign-7qz"))
}

pub fn valid_slug_accepts_lowercase_and_digits_test() {
  slug.validate_user_slug("abc123") |> should.equal(Ok("abc123"))
}

pub fn invalid_slug_rejects_empty_test() {
  slug.validate_user_slug("") |> should.equal(Error(slug.Empty))
}

pub fn invalid_slug_rejects_too_long_test() {
  let long = string.repeat("a", 65)
  slug.validate_user_slug(long) |> should.equal(Error(slug.TooLong))
}

pub fn invalid_slug_rejects_disallowed_chars_test() {
  slug.validate_user_slug("hi there") |> should.equal(Error(slug.BadCharacters))
}

pub fn invalid_slug_rejects_reserved_test() {
  slug.validate_user_slug("api") |> should.equal(Error(slug.Reserved))
  slug.validate_user_slug("health") |> should.equal(Error(slug.Reserved))
  slug.validate_user_slug("dashboard") |> should.equal(Error(slug.Reserved))
}

pub fn random_slug_format_test() {
  let s = slug.random()
  // Royal word + "-" + 3 lowercase alnum chars
  let assert Ok(#(_, tag)) = string.split_once(s, on: "-")
  string.length(tag) |> should.equal(3)
}

pub fn random_slug_avoids_reserved_test() {
  // 200 generations, none reserved
  list.range(0, 200)
  |> list.map(fn(_) { slug.random() })
  |> list.all(fn(s) { slug.validate_user_slug(s) != Error(slug.Reserved) })
  |> should.be_true
}
```

Add these imports to `slug_test.gleam`:

```gleam
import gleam/list
import gleam/string
```

### - [ ] Step 1.2: Run test to verify it fails

```bash
cd backend && gleam test
```

Expected: compile error / missing module `backend/slug`.

### - [ ] Step 1.3: Implement slug module

Create `backend/src/backend/slug.gleam`:

```gleam
//// Slug generation, validation, and reserved-slug enforcement.
////
//// A slug is a short identifier appearing at the top level of a URL
//// (`royal.sh/<slug>`). It MUST NOT collide with any reserved top-level
//// route. Random slugs are "<RoyalWord>-<3 alnum chars>".

import gleam/int
import gleam/list
import gleam/set
import gleam/string

pub type ValidationError {
  Empty
  TooLong
  BadCharacters
  Reserved
}

const max_length = 64

const royal_words = [
  "Regalia", "Sovereign", "Crowned", "Imperial", "Majesty", "Coronet",
  "Heir", "Throne", "Scepter", "Diadem", "Monarch", "Noble", "Court",
  "Crest", "Royaume", "Sceptre", "Ermine", "Laurel", "Gilded", "Dauphin",
]

const tag_alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

/// Top-level routes that must never be served as a redirect. Update this
/// list whenever a new top-level path is added to the router.
pub const reserved_slugs = [
  "api", "health", "dashboard", "stats", "login", "signup", "logout",
  "static", "assets", "favicon.ico", "robots.txt",
]

/// Validate a user-supplied slug. Returns the slug verbatim on success.
pub fn validate_user_slug(input: String) -> Result(String, ValidationError) {
  case input {
    "" -> Error(Empty)
    _ -> {
      case string.length(input) > max_length {
        True -> Error(TooLong)
        False ->
          case all_allowed(input) {
            False -> Error(BadCharacters)
            True ->
              case is_reserved(input) {
                True -> Error(Reserved)
                False -> Ok(input)
              }
          }
      }
    }
  }
}

/// Mint a random slug, retrying if it collides with a reserved word.
pub fn random() -> String {
  let s = pick(royal_words) <> "-" <> random_tag(3)
  case is_reserved(s) {
    True -> random()
    False -> s
  }
}

pub fn is_reserved(slug: String) -> Bool {
  reserved_slugs
  |> set.from_list
  |> set.contains(string.lowercase(slug))
}

// ------------ helpers ----------------------------------------------------

fn all_allowed(input: String) -> Bool {
  let allowed =
    string.to_graphemes(
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_",
    )
    |> set.from_list
  string.to_graphemes(input)
  |> list.all(fn(c) { set.contains(allowed, c) })
}

fn pick(items: List(String)) -> String {
  let length = list.length(items)
  let index = int.random(length)
  let assert Ok(value) = list.drop(items, index) |> list.first
  value
}

fn random_tag(length: Int) -> String {
  let chars = string.to_graphemes(tag_alphabet)
  case length {
    n if n <= 0 -> ""
    _ -> {
      let index = int.random(list.length(chars))
      let assert Ok(c) = list.drop(chars, index) |> list.first
      c <> random_tag(length - 1)
    }
  }
}
```

### - [ ] Step 1.4: Run tests, expect green

```bash
cd backend && gleam test
```

Expected: all `slug_test` tests pass. The pre-existing `hello_world_test` should still pass.

### - [ ] Step 1.5: Drop the hello-world test

Replace `backend/test/backend_test.gleam` with the minimal runner:

```gleam
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}
```

Re-run tests; should still be green.

### - [ ] Step 1.6: Commit

```bash
cd backend && gleam test  # final confirmation
git add backend/src/backend/slug.gleam backend/test/backend/slug_test.gleam backend/test/backend_test.gleam
git commit -m "Add slug module with reserved-route validation"
```

---

## Task 2: Add SQLite and JSON dependencies

**Files:**
- Modify: `backend/gleam.toml`
- Modify: `backend/manifest.toml` (auto-regenerated)
- Modify: `backend/.gitignore`

### - [ ] Step 2.1: Edit `backend/gleam.toml`

Add to the `[dependencies]` block:

```toml
sqlight = ">= 0.10.0 and < 1.0.0"
gleam_json = ">= 2.0.0 and < 3.0.0"
```

The resulting block should look like (preserve all existing deps):

```toml
[dependencies]
gleam_stdlib = ">= 1.0.0 and < 2.0.0"
wisp = ">= 2.2.2 and < 3.0.0"
mist = ">= 6.0.3 and < 7.0.0"
envoy = ">= 1.2.0 and < 2.0.0"
gleam_http = ">= 4.3.0 and < 5.0.0"
gleam_erlang = ">= 1.3.0 and < 2.0.0"
sqlight = ">= 0.10.0 and < 1.0.0"
gleam_json = ">= 2.0.0 and < 3.0.0"
```

> Verify the latest minor version of each dep at https://hex.pm before locking. If the API surface used by this plan has changed (e.g. `sqlight.query` argument names), adapt the calls in later tasks; the shape (open / exec / query / close) has been stable for years.

### - [ ] Step 2.2: Update `.gitignore`

Append to `backend/.gitignore`:

```
*.sqlite3
*.sqlite3-journal
priv/data/
```

### - [ ] Step 2.3: Pull deps and confirm the project still builds

```bash
cd backend && gleam deps download && gleam build
```

Expected: build succeeds, `manifest.toml` is updated with `sqlight`, `gleam_json`, and their transitive deps.

### - [ ] Step 2.4: Commit

```bash
git add backend/gleam.toml backend/manifest.toml backend/.gitignore
git commit -m "Add sqlight and gleam_json deps"
```

---

## Task 3: DB module — connection + migration runner

We use a hand-rolled migration runner (no third-party migration library). Migrations are numbered SQL files in `priv/migrations/`. The runner reads them, checks a `schema_migrations` table for what's already applied, and runs new ones in order.

**Files:**
- Create: `backend/priv/migrations/001_links.sql`
- Create: `backend/src/backend/db.gleam`
- Create: `backend/test/backend/db_test.gleam`

### - [ ] Step 3.1: Write the migration SQL

Create `backend/priv/migrations/001_links.sql`:

```sql
CREATE TABLE links (
  id          INTEGER PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  target_url  TEXT NOT NULL,
  secret      TEXT NOT NULL,
  click_count INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL
);
```

Future milestones add columns (`expires_at`, `click_limit`, `owner_user_id`) in subsequent numbered files. Do not touch this file again.

### - [ ] Step 3.2: Write the db module tests

Create `backend/test/backend/db_test.gleam`:

```gleam
import backend/db
import gleam/string
import gleeunit/should

pub fn open_in_memory_test() {
  let assert Ok(conn) = db.open(":memory:")
  // Cleanup
  let _ = db.close(conn)
}

pub fn run_migrations_creates_links_table_test() {
  let assert Ok(conn) = db.open(":memory:")
  let assert Ok(_) = db.run_migrations(conn)

  // Verify by selecting from the table; if it doesn't exist this errors.
  let assert Ok(_) = db.exec("SELECT slug FROM links WHERE 1 = 0", conn)

  let _ = db.close(conn)
}

pub fn run_migrations_is_idempotent_test() {
  let assert Ok(conn) = db.open(":memory:")
  let assert Ok(_) = db.run_migrations(conn)
  // Second run must not raise.
  let assert Ok(_) = db.run_migrations(conn)
  let _ = db.close(conn)
}
```

### - [ ] Step 3.3: Implement `backend/src/backend/db.gleam`

```gleam
//// SQLite connection and migration runner.
////
//// Migrations live in `priv/migrations/NNN_*.sql`. The runner tracks
//// applied versions in `schema_migrations` and runs new files in order.

import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import simplifile
import sqlight
import wisp

pub type Error {
  OpenError(sqlight.Error)
  SqlError(sqlight.Error)
  FilesystemError(simplifile.FileError)
  NoPrivDirectory
}

pub type Conn =
  sqlight.Connection

pub fn open(path: String) -> Result(Conn, Error) {
  sqlight.open(path) |> result.map_error(OpenError)
}

pub fn close(conn: Conn) -> Result(Nil, Error) {
  sqlight.close(conn) |> result.map_error(SqlError)
}

pub fn exec(sql: String, conn: Conn) -> Result(Nil, Error) {
  sqlight.exec(sql, conn) |> result.map_error(SqlError)
}

pub fn run_migrations(conn: Conn) -> Result(Nil, Error) {
  use _ <- result.try(ensure_schema_migrations_table(conn))
  use applied <- result.try(applied_versions(conn))
  use files <- result.try(migration_files())

  list.try_each(files, fn(file) {
    case list.contains(applied, file.version) {
      True -> Ok(Nil)
      False -> apply_one(file, conn)
    }
  })
}

// ------------ internals --------------------------------------------------

type MigrationFile {
  MigrationFile(version: Int, name: String, sql: String)
}

fn ensure_schema_migrations_table(conn: Conn) -> Result(Nil, Error) {
  exec(
    "CREATE TABLE IF NOT EXISTS schema_migrations (
       version INTEGER PRIMARY KEY,
       applied_at INTEGER NOT NULL
     )",
    conn,
  )
}

fn applied_versions(conn: Conn) -> Result(List(Int), Error) {
  sqlight.query(
    "SELECT version FROM schema_migrations",
    on: conn,
    with: [],
    expecting: decode.at([0], decode.int),
  )
  |> result.map_error(SqlError)
}

fn migration_files() -> Result(List(MigrationFile), Error) {
  let priv = case wisp.priv_directory("backend") {
    Ok(p) -> Ok(p)
    Error(_) -> Error(NoPrivDirectory)
  }
  use priv <- result.try(priv)
  let dir = priv <> "/migrations"

  use entries <- result.try(
    simplifile.read_directory(dir) |> result.map_error(FilesystemError),
  )

  entries
  |> list.filter(fn(name) { string.ends_with(name, ".sql") })
  |> list.sort(string.compare)
  |> list.try_map(fn(name) {
    let path = dir <> "/" <> name
    use sql <- result.try(
      simplifile.read(path) |> result.map_error(FilesystemError),
    )
    use version <- result.try(parse_version(name))
    Ok(MigrationFile(version: version, name: name, sql: sql))
  })
}

fn parse_version(filename: String) -> Result(Int, Error) {
  // "001_links.sql" -> 1
  let prefix = string.split(filename, on: "_") |> list.first
  case prefix {
    Ok(p) ->
      int.parse(p)
      |> result.replace_error(FilesystemError(simplifile.Eacces))
    Error(_) -> Error(FilesystemError(simplifile.Eacces))
  }
}

fn apply_one(file: MigrationFile, conn: Conn) -> Result(Nil, Error) {
  use _ <- result.try(exec(file.sql, conn))
  let now = int.to_string(system_seconds())
  let insert =
    "INSERT INTO schema_migrations(version, applied_at) VALUES ("
    <> int.to_string(file.version)
    <> ", "
    <> now
    <> ")"
  exec(insert, conn)
}

@external(erlang, "os", "system_time")
fn system_time(unit: String) -> Int

fn system_seconds() -> Int {
  system_time("seconds")
}
```

Notes for the engineer:

- `simplifile` is a stdlib-quality filesystem package; it is a transitive dep of `wisp` so it's already available. If `gleam deps download` reports it missing, add `simplifile = ">= 2.0.0 and < 3.0.0"` to `gleam.toml`.
- `wisp.priv_directory` resolves the `priv/` directory both when running from source and inside an Erlang shipment (the same way `backend.gleam` already uses it for static files).
- The actual `sqlight` query API may use slightly different keyword positions in your version. The shape `sqlight.query(sql, on: conn, with: [...], expecting: decoder)` matches versions ≥ `0.9`. If your version differs, adapt the call sites; semantics are unchanged.
- `system_time/1` is an Erlang BIF; the FFI shim is the idiomatic Gleam-on-BEAM way to read the wall clock without a third-party package.

### - [ ] Step 3.4: Run tests; expect green

```bash
cd backend && gleam test
```

Expected: `db_test` tests pass. If `simplifile` is genuinely absent, add it to `gleam.toml` and rerun.

### - [ ] Step 3.5: Commit

```bash
git add backend/priv/migrations/001_links.sql backend/src/backend/db.gleam backend/test/backend/db_test.gleam backend/gleam.toml backend/manifest.toml
git commit -m "Add SQLite connection and migration runner"
```

---

## Task 4: Links storage module

**Files:**
- Create: `backend/src/backend/links.gleam`
- Create: `backend/test/backend/links_test.gleam`

### - [ ] Step 4.1: Write storage tests

Create `backend/test/backend/links_test.gleam`:

```gleam
import backend/db
import backend/links
import gleam/string
import gleeunit/should

fn fresh_db() -> db.Conn {
  let assert Ok(conn) = db.open(":memory:")
  let assert Ok(_) = db.run_migrations(conn)
  conn
}

pub fn create_returns_link_with_secret_test() {
  let conn = fresh_db()
  let assert Ok(link) =
    links.create(
      target_url: "https://example.com/long",
      slug: "Sovereign-7qz",
      conn: conn,
    )
  link.slug |> should.equal("Sovereign-7qz")
  link.target_url |> should.equal("https://example.com/long")
  string.length(link.secret) |> should.equal(32)
  link.click_count |> should.equal(0)
}

pub fn create_with_duplicate_slug_returns_conflict_test() {
  let conn = fresh_db()
  let assert Ok(_) =
    links.create(
      target_url: "https://example.com/a",
      slug: "Sovereign-7qz",
      conn: conn,
    )
  let result =
    links.create(
      target_url: "https://example.com/b",
      slug: "Sovereign-7qz",
      conn: conn,
    )
  result |> should.equal(Error(links.SlugTaken))
}

pub fn find_by_slug_returns_target_test() {
  let conn = fresh_db()
  let assert Ok(_) =
    links.create(
      target_url: "https://example.com/target",
      slug: "Crowned-abc",
      conn: conn,
    )
  let assert Ok(link) = links.find_by_slug("Crowned-abc", conn)
  link.target_url |> should.equal("https://example.com/target")
}

pub fn find_by_slug_unknown_returns_not_found_test() {
  let conn = fresh_db()
  let result = links.find_by_slug("Nonexistent-xxx", conn)
  result |> should.equal(Error(links.NotFound))
}
```

### - [ ] Step 4.2: Implement `links.gleam`

Create `backend/src/backend/links.gleam`:

```gleam
//// Persistence for shortened links. M1 covers create + find. Expiry,
//// click_limit and analytics arrive in later milestones.

import backend/db
import gleam/dynamic/decode
import gleam/list
import gleam/result
import sqlight

pub type Link {
  Link(
    id: Int,
    slug: String,
    target_url: String,
    secret: String,
    click_count: Int,
    created_at: Int,
  )
}

pub type Error {
  SlugTaken
  NotFound
  StorageError(String)
}

pub fn create(
  target_url target_url: String,
  slug slug: String,
  conn conn: db.Conn,
) -> Result(Link, Error) {
  let secret = mint_secret()
  let now = system_seconds()

  let sql =
    "INSERT INTO links (slug, target_url, secret, click_count, created_at)
     VALUES (?, ?, ?, 0, ?)
     RETURNING id, slug, target_url, secret, click_count, created_at"

  let res =
    sqlight.query(
      sql,
      on: conn,
      with: [
        sqlight.text(slug),
        sqlight.text(target_url),
        sqlight.text(secret),
        sqlight.int(now),
      ],
      expecting: link_decoder(),
    )

  case res {
    Ok([link, ..]) -> Ok(link)
    Ok([]) -> Error(StorageError("insert returned no rows"))
    Error(e) -> Error(classify_sqlight_error(e))
  }
}

pub fn find_by_slug(slug: String, conn: db.Conn) -> Result(Link, Error) {
  let sql =
    "SELECT id, slug, target_url, secret, click_count, created_at
       FROM links WHERE slug = ?"

  let res =
    sqlight.query(
      sql,
      on: conn,
      with: [sqlight.text(slug)],
      expecting: link_decoder(),
    )

  case res {
    Ok([link, ..]) -> Ok(link)
    Ok([]) -> Error(NotFound)
    Error(e) -> Error(StorageError(e.message))
  }
}

// ------------ internals --------------------------------------------------

fn link_decoder() -> decode.Decoder(Link) {
  use id <- decode.field(0, decode.int)
  use slug <- decode.field(1, decode.string)
  use target_url <- decode.field(2, decode.string)
  use secret <- decode.field(3, decode.string)
  use click_count <- decode.field(4, decode.int)
  use created_at <- decode.field(5, decode.int)
  decode.success(Link(id, slug, target_url, secret, click_count, created_at))
}

fn classify_sqlight_error(e: sqlight.Error) -> Error {
  // SQLite unique-constraint violation has code 2067 (SQLITE_CONSTRAINT_UNIQUE).
  case e.code {
    sqlight.ConstraintUnique -> SlugTaken
    _ -> StorageError(e.message)
  }
}

fn mint_secret() -> String {
  // 16 random bytes -> 32 hex chars.
  random_hex(16)
}

@external(erlang, "crypto", "strong_rand_bytes")
fn strong_rand_bytes(n: Int) -> BitArray

@external(erlang, "binary", "encode_hex")
fn encode_hex(bin: BitArray) -> String

fn random_hex(bytes: Int) -> String {
  strong_rand_bytes(bytes) |> encode_hex
}

@external(erlang, "os", "system_time")
fn system_time(unit: String) -> Int

fn system_seconds() -> Int {
  system_time("seconds")
}
```

Notes:

- `crypto:strong_rand_bytes/1` is the OTP CSPRNG; this is the right tool for a management token. `binary:encode_hex/1` exists on OTP 24+; the project is on OTP 29 (per the containerization spec), so it's available.
- The exact `sqlight.Error` constructor name (`ConstraintUnique`) may differ across versions. If the compile errors with an unknown variant, look at `sqlight`'s `Error` type definition and use whichever variant maps to SQLite's unique-constraint code. The fallback is `StorageError(e.message)` plus matching on `string.contains(e.message, "UNIQUE constraint")`.
- The decoder uses positional fields because `sqlight` returns rows as tuples / lists. Adjust to record-style decoding if your `sqlight` version returns named columns.

### - [ ] Step 4.3: Run tests; expect green

```bash
cd backend && gleam test
```

### - [ ] Step 4.4: Commit

```bash
git add backend/src/backend/links.gleam backend/test/backend/links_test.gleam
git commit -m "Add links storage with create and find_by_slug"
```

---

## Task 5: POST /api/links endpoint

**Files:**
- Create: `backend/src/backend/api.gleam`
- Create: `backend/test/backend/router_test.gleam`
- Modify: `backend/src/backend/router.gleam`

### - [ ] Step 5.1: Write integration tests for POST /api/links

Create `backend/test/backend/router_test.gleam`:

```gleam
import backend/db
import backend/router
import gleam/http.{Post}
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should
import wisp/testing

fn fresh_router() -> #(db.Conn, fn(testing.Request) -> testing.Response) {
  let assert Ok(conn) = db.open(":memory:")
  let assert Ok(_) = db.run_migrations(conn)
  let handler = fn(req) { router.handle_request(req, "./priv/static", conn) }
  #(conn, handler)
}

pub fn post_creates_link_test() {
  let #(_conn, handle) = fresh_router()

  let body = json.object([#("url", json.string("https://example.com/long"))])

  let req = testing.post_json("/api/links", [], body)
  let resp = handle(req)

  resp.status |> should.equal(201)

  let assert Ok(body_str) = testing.string_body(resp)
  body_str |> string.contains("\"slug\":") |> should.be_true
  body_str |> string.contains("\"short_url\":") |> should.be_true
  body_str |> string.contains("\"secret\":") |> should.be_true
}

pub fn post_with_custom_slug_test() {
  let #(_conn, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("Sovereign-abc")),
    ])
  let req = testing.post_json("/api/links", [], body)
  let resp = handle(req)

  resp.status |> should.equal(201)
  let assert Ok(body_str) = testing.string_body(resp)
  body_str |> string.contains("Sovereign-abc") |> should.be_true
}

pub fn post_with_duplicate_slug_returns_409_test() {
  let #(_conn, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("Sovereign-abc")),
    ])
  let req1 = testing.post_json("/api/links", [], body)
  let _ = handle(req1)

  let req2 = testing.post_json("/api/links", [], body)
  let resp = handle(req2)
  resp.status |> should.equal(409)
}

pub fn post_with_reserved_slug_returns_400_test() {
  let #(_conn, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("api")),
    ])
  let req = testing.post_json("/api/links", [], body)
  let resp = handle(req)
  resp.status |> should.equal(400)
}

pub fn post_with_invalid_url_returns_400_test() {
  let #(_conn, handle) = fresh_router()

  let body = json.object([#("url", json.string("not a url"))])
  let req = testing.post_json("/api/links", [], body)
  let resp = handle(req)
  resp.status |> should.equal(400)
}
```

### - [ ] Step 5.2: Implement the API handler

Create `backend/src/backend/api.gleam`:

```gleam
//// HTTP handlers for /api/* routes.

import backend/db
import backend/links
import backend/slug
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import wisp.{type Request, type Response}

pub fn create_link(req: Request, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  case decode.run(body, create_request_decoder()) {
    Error(_) -> bad_request("invalid request body")
    Ok(parsed) ->
      case validate_url(parsed.url) {
        Error(reason) -> bad_request(reason)
        Ok(url) ->
          case resolved_slug(parsed.slug) {
            Error(reason) -> bad_request(reason)
            Ok(s) -> insert(url, s, conn)
          }
      }
  }
}

// ------------ internals --------------------------------------------------

type CreateRequest {
  CreateRequest(url: String, slug: Option(String))
}

fn create_request_decoder() -> decode.Decoder(CreateRequest) {
  use url <- decode.field("url", decode.string)
  use slug <- decode.optional_field(
    "slug",
    None,
    decode.optional(decode.string),
  )
  decode.success(CreateRequest(url: url, slug: slug))
}

fn validate_url(input: String) -> Result(String, String) {
  let trimmed = string.trim(input)
  case trimmed {
    "" -> Error("url is empty")
    _ ->
      case uri.parse(trimmed) {
        Error(_) -> Error("url is not a valid URI")
        Ok(parsed) ->
          case parsed.scheme {
            Some("http") | Some("https") -> Ok(trimmed)
            _ -> Error("url must use http or https")
          }
      }
  }
}

fn resolved_slug(input: Option(String)) -> Result(String, String) {
  case input {
    None -> Ok(slug.random())
    Some(user) ->
      slug.validate_user_slug(user)
      |> result.map_error(slug_error_message)
  }
}

fn slug_error_message(e: slug.ValidationError) -> String {
  case e {
    slug.Empty -> "slug is empty"
    slug.TooLong -> "slug is too long"
    slug.BadCharacters ->
      "slug may only contain letters, digits, hyphen, and underscore"
    slug.Reserved -> "slug is reserved"
  }
}

fn insert(url: String, slug: String, conn: db.Conn) -> Response {
  case links.create(target_url: url, slug: slug, conn: conn) {
    Ok(link) -> created(link)
    Error(links.SlugTaken) -> conflict("slug already taken")
    Error(links.NotFound) -> server_error()
    Error(links.StorageError(_)) -> server_error()
  }
}

fn created(link: links.Link) -> Response {
  let body =
    json.object([
      #("slug", json.string(link.slug)),
      #("short_url", json.string("/" <> link.slug)),
      #("secret", json.string(link.secret)),
    ])
  wisp.json_response(json.to_string(body), 201)
}

fn bad_request(message: String) -> Response {
  error_json(400, message)
}

fn conflict(message: String) -> Response {
  error_json(409, message)
}

fn server_error() -> Response {
  error_json(500, "internal error")
}

fn error_json(status: Int, message: String) -> Response {
  let body = json.object([#("error", json.string(message))])
  wisp.json_response(json.to_string(body), status)
}
```

Notes:

- `wisp.require_json` parses the request body to a `Dynamic` you decode yourself.
- `short_url` is returned as a path (`/<slug>`). The frontend prepends its own origin. This avoids hard-coding `royal.sh` in the backend.
- The decoder uses the new `gleam/dynamic/decode` API. If the `wisp` version pinned here gives `Dynamic` from a different module path, adapt the import; the decoder shape is unchanged.

### - [ ] Step 5.3: Update the router to call the API handler

Replace `backend/src/backend/router.gleam` with:

```gleam
import backend/api
import backend/db
import gleam/http/request
import gleam/http/response
import gleam/option
import wisp.{type Request, type Response}

/// Top-level request handler. Order of decisions:
///   1. Static assets from `static_directory`.
///   2. `/api/*` — JSON API.
///   3. `/health` — plain "ok".
///   4. `/:slug` — single-segment redirect (added in Task 6).
///   5. Anything else — return `index.html` so the SPA can take over.
pub fn handle_request(
  req: Request,
  static_directory: String,
  conn: db.Conn,
) -> Response {
  use <- wisp.serve_static(req, under: "/", from: static_directory)

  case request.path_segments(req) {
    ["api", "links"] -> api.create_link(req, conn)
    ["health"] -> health()
    _ -> index(static_directory)
  }
}

fn health() -> Response {
  wisp.ok()
}

fn index(static_directory: String) -> Response {
  let index_path = static_directory <> "/index.html"

  wisp.response(200)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> wisp.set_body(wisp.File(path: index_path, offset: 0, limit: option.None))
}
```

> The redirect arm (`GET /:slug`) lives in Task 6 — adding it here would force you to introduce the storage-lookup wiring before the test for redirect exists.

### - [ ] Step 5.4: Wire the conn argument through `backend.gleam` provisionally

So tests can compile, modify `backend/src/backend.gleam`:

Change

```gleam
  let handler = fn(req) { router.handle_request(req, static_directory) }
```

to

```gleam
  let assert Ok(conn) = backend_db_open()
  let assert Ok(_) = db.run_migrations(conn)
  let handler = fn(req) { router.handle_request(req, static_directory, conn) }
```

and add a helper plus imports near the top:

```gleam
import backend/db

fn backend_db_open() -> Result(db.Conn, db.Error) {
  case envoy.get("DATABASE_URL") {
    Ok(path) -> db.open(path)
    Error(_) -> db.open("./priv/data/royal.sqlite3")
  }
}
```

Make sure the priv data directory exists at runtime:

```gleam
  let _ = simplifile.create_directory_all(priv <> "/data")
```

Add `import simplifile` at the top.

> A nicer factoring of startup will land in Task 7 — for now we just need this to compile and accept the conn so the integration tests in 5.1 can build on a working `handle_request` signature.

### - [ ] Step 5.5: Run tests, expect green

```bash
cd backend && gleam test
```

If `wisp/testing` is not part of the wisp version pinned, you'll need to either upgrade wisp or implement a thin in-test request builder. As of `wisp >= 2.2`, `wisp/testing` is shipped.

### - [ ] Step 5.6: Commit

```bash
git add backend/src/backend/api.gleam backend/src/backend/router.gleam backend/src/backend.gleam backend/test/backend/router_test.gleam
git commit -m "Add POST /api/links endpoint"
```

---

## Task 6: GET /:slug redirect endpoint

**Files:**
- Modify: `backend/src/backend/router.gleam`
- Modify: `backend/src/backend/api.gleam` (add `redirect_slug` function)
- Modify: `backend/test/backend/router_test.gleam` (add redirect tests)

### - [ ] Step 6.1: Add failing tests

Append to `backend/test/backend/router_test.gleam`:

```gleam
import gleam/http.{Get}

pub fn redirect_returns_302_test() {
  let #(_conn, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com/target")),
      #("slug", json.string("Crowned-rrr")),
    ])
  let _ = handle(testing.post_json("/api/links", [], body))

  let req = testing.request(http.Get, "/Crowned-rrr", [], <<>>)
  let resp = handle(req)

  resp.status |> should.equal(302)

  let location =
    list.key_find(resp.headers, "location") |> result.unwrap("")
  location |> should.equal("https://example.com/target")
}

pub fn redirect_unknown_slug_returns_404_test() {
  let #(_conn, handle) = fresh_router()

  let req = testing.request(http.Get, "/no-such-slug", [], <<>>)
  let resp = handle(req)
  resp.status |> should.equal(404)
}

pub fn redirect_does_not_clobber_reserved_paths_test() {
  let #(_conn, handle) = fresh_router()

  // Even if someone had managed to create a link with slug "health"
  // (impossible via our API, but defensively): /health stays /health.
  let req = testing.request(http.Get, "/health", [], <<>>)
  let resp = handle(req)
  resp.status |> should.equal(200)
}
```

Add at the top:

```gleam
import gleam/result
```

### - [ ] Step 6.2: Add `redirect_slug` to `api.gleam`

Append to `backend/src/backend/api.gleam`:

```gleam
import gleam/http/response

pub fn redirect_slug(slug: String, conn: db.Conn) -> Response {
  case links.find_by_slug(slug, conn) {
    Ok(link) ->
      wisp.response(302)
      |> response.set_header("location", link.target_url)
    Error(links.NotFound) -> not_found()
    Error(_) -> server_error()
  }
}

fn not_found() -> Response {
  error_json(404, "not found")
}
```

### - [ ] Step 6.3: Wire redirect into router

Update the `case` block in `backend/src/backend/router.gleam`:

```gleam
  case request.path_segments(req) {
    ["api", "links"] -> api.create_link(req, conn)
    ["health"] -> health()
    [slug] ->
      case req.method, is_reserved_top_level(slug) {
        http.Get, False -> api.redirect_slug(slug, conn)
        _, _ -> index(static_directory)
      }
    _ -> index(static_directory)
  }
```

And add a small defensive helper plus the `http` import:

```gleam
import backend/slug as slug_mod
import gleam/http

fn is_reserved_top_level(path: String) -> Bool {
  slug_mod.is_reserved(path)
}
```

> `req.method` is field access on the wisp `Request` (which wraps `gleam/http/request.Request`). The variants of `gleam/http.Method` are `Get`, `Post`, etc.

### - [ ] Step 6.4: Run tests; expect green

```bash
cd backend && gleam test
```

### - [ ] Step 6.5: Commit

```bash
git add backend/src/backend/router.gleam backend/src/backend/api.gleam backend/test/backend/router_test.gleam
git commit -m "Add GET /:slug redirect endpoint"
```

---

## Task 7: Clean up startup wiring in `backend.gleam`

The provisional wiring in Task 5.4 is fine but messy. Tidy it.

**Files:**
- Modify: `backend/src/backend.gleam`

### - [ ] Step 7.1: Rewrite `backend.gleam`

```gleam
import backend/db
import backend/router
import envoy
import gleam/erlang/process
import gleam/int
import gleam/result
import mist
import simplifile
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let assert Ok(priv) = wisp.priv_directory("backend")
  let static_directory = priv <> "/static"

  let assert Ok(conn) = open_db(priv)
  let assert Ok(_) = db.run_migrations(conn)

  let secret_key_base = secret_key_base()
  let handler = fn(req) { router.handle_request(req, static_directory, conn) }

  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port())
    |> mist.start

  process.sleep_forever()
}

fn open_db(priv: String) -> Result(db.Conn, db.Error) {
  let path = case envoy.get("DATABASE_URL") {
    Ok(p) -> p
    Error(_) -> {
      let dir = priv <> "/data"
      let _ = simplifile.create_directory_all(dir)
      dir <> "/royal.sqlite3"
    }
  }
  db.open(path)
}

fn port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}

fn secret_key_base() -> String {
  case envoy.get("SECRET_KEY_BASE") {
    Ok(key) -> key
    Error(_) -> wisp.random_string(64)
  }
}
```

> `db.Conn` is the alias defined in Task 3 (`pub type Conn = sqlight.Connection`).

### - [ ] Step 7.2: Boot the server manually and probe `/health`

```bash
cd backend
gleam run &
sleep 2
curl -s -i http://localhost:8080/health
kill %1
```

Expected: `HTTP/1.1 200 OK` with body `ok`.

### - [ ] Step 7.3: Manual end-to-end probe of create + redirect

```bash
cd backend
gleam run &
sleep 2

curl -s -X POST http://localhost:8080/api/links \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com/welcome"}'

# Take the slug from the response above, then:
curl -s -i http://localhost:8080/<slug>

kill %1
```

Expected: create returns 201 with `{slug, short_url, secret}`. Redirect returns 302 with `Location: https://example.com/welcome`.

### - [ ] Step 7.4: Commit

```bash
git add backend/src/backend.gleam
git commit -m "Open SQLite at startup, run migrations, inject conn into router"
```

---

## Task 8: Frontend deps — rsvp + gleam_json

**Files:**
- Modify: `frontend/gleam.toml`
- Modify: `frontend/manifest.toml`

### - [ ] Step 8.1: Add deps

Append to `frontend/gleam.toml` `[dependencies]`:

```toml
rsvp = ">= 1.0.0 and < 2.0.0"
gleam_json = ">= 2.0.0 and < 3.0.0"
```

### - [ ] Step 8.2: Pull deps

```bash
cd frontend && gleam deps download && gleam build
```

### - [ ] Step 8.3: Commit

```bash
git add frontend/gleam.toml frontend/manifest.toml
git commit -m "Add rsvp and gleam_json deps to frontend"
```

---

## Task 9: Frontend API client

**Files:**
- Create: `frontend/src/royal/api.gleam`
- Create: `frontend/test/royal/api_test.gleam`

### - [ ] Step 9.1: Write tests for the response decoder

Create `frontend/test/royal/api_test.gleam`:

```gleam
import gleam/dynamic/decode
import gleam/json
import gleeunit/should
import royal/api

pub fn decoder_parses_full_response_test() {
  let payload =
    "{\"slug\":\"Sovereign-7qz\",\"short_url\":\"/Sovereign-7qz\",\"secret\":\"abc123\"}"
  let assert Ok(parsed) = json.parse(payload, api.minted_decoder())
  parsed.slug |> should.equal("Sovereign-7qz")
  parsed.short_url |> should.equal("/Sovereign-7qz")
  parsed.secret |> should.equal("abc123")
}

pub fn decoder_rejects_missing_field_test() {
  let payload = "{\"slug\":\"Sovereign-7qz\"}"
  let result = json.parse(payload, api.minted_decoder())
  case result {
    Error(_) -> Nil
    Ok(_) -> panic as "expected decoder to fail on missing fields"
  }
}
```

### - [ ] Step 9.2: Implement the API client

Create `frontend/src/royal/api.gleam`:

```gleam
//// HTTP client for the Royal Shortener backend API.

import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import lustre/effect.{type Effect}
import rsvp

pub type Minted {
  Minted(slug: String, short_url: String, secret: String)
}

pub type ApiError {
  Network(String)
  Conflict
  BadRequest(String)
  Server(String)
}

pub fn minted_decoder() -> decode.Decoder(Minted) {
  use slug <- decode.field("slug", decode.string)
  use short_url <- decode.field("short_url", decode.string)
  use secret <- decode.field("secret", decode.string)
  decode.success(Minted(slug, short_url, secret))
}

pub fn create_link(
  url: String,
  slug: Option(String),
  on_response: fn(Result(Minted, ApiError)) -> msg,
) -> Effect(msg) {
  let body =
    json.object(case slug {
      None -> [#("url", json.string(url))]
      Some(s) -> [#("url", json.string(url)), #("slug", json.string(s))]
    })

  let handler = fn(result) {
    case result {
      Ok(rsvp_resp) -> on_response(interpret(rsvp_resp))
      Error(e) -> on_response(Error(Network(rsvp_error_message(e))))
    }
  }

  rsvp.post(
    url: "/api/links",
    body: json.to_string(body),
    handler: handler,
  )
}

fn interpret(resp: rsvp.Response) -> Result(Minted, ApiError) {
  case resp.status {
    201 ->
      json.parse(resp.body, minted_decoder())
      |> result.map_error(fn(_) { Server("bad response body") })
    400 -> Error(BadRequest(error_message(resp.body)))
    409 -> Error(Conflict)
    _ -> Error(Server("status " <> int.to_string(resp.status)))
  }
}

fn error_message(body: String) -> String {
  let decoder = {
    use msg <- decode.field("error", decode.string)
    decode.success(msg)
  }
  case json.parse(body, decoder) {
    Ok(m) -> m
    Error(_) -> "bad request"
  }
}

fn rsvp_error_message(e: rsvp.HttpError) -> String {
  // rsvp.HttpError variants are typically NetworkError/InvalidUrl/etc.
  // Convert to a human-readable string; consult rsvp's docs for the exact
  // variant shape in the version you pin.
  "network error"
}
```

Add the missing imports at the top:

```gleam
import gleam/int
import gleam/result
```

Notes:

- The actual `rsvp` API may differ slightly across versions; the *shape* `rsvp.post(url, body, handler)` and `rsvp.Response { status, body, headers }` is the conventional contract. If your version requires `rsvp.expect_json(decoder, on_ok, on_err)` instead, adapt accordingly — the decoder and message shapes don't change.
- `Network`, `Conflict`, `BadRequest`, `Server` map cleanly to the spec's status codes; we don't expose status numbers to the rest of the app.

### - [ ] Step 9.3: Run frontend tests

```bash
cd frontend && gleam test
```

### - [ ] Step 9.4: Commit

```bash
git add frontend/src/royal/api.gleam frontend/test/royal/api_test.gleam
git commit -m "Add frontend API client for /api/links"
```

---

## Task 10: Wire API into app.gleam

**Files:**
- Modify: `frontend/src/royal/types.gleam`
- Modify: `frontend/src/royal/app.gleam`
- Modify: `frontend/src/royal/data.gleam` (drop unused `random_slug`)

### - [ ] Step 10.1: Extend types

Replace `frontend/src/royal/types.gleam` with:

```gleam
//// Royal Shortener — domain types shared by the app and view modules.

import gleam/option.{type Option}
import royal/api

pub type Phase {
  Idle
  Animating
  Done
}

pub type Minted {
  Minted(slug: String, short_url: String, secret: String, long_text: String, title: String)
}

pub type LedgerItem {
  LedgerItem(slug: String, long_text: String, clicks: Int)
}

pub type Model {
  Model(
    url: String,
    phase: Phase,
    result: Option(Minted),
    ledger: List(LedgerItem),
    copied: Option(String),
    error: Option(String),
  )
}

pub type Msg {
  UrlChanged(String)
  ShortenClicked
  KeyPressed(String)
  MintSucceeded(api.Minted)
  MintFailed(api.ApiError)
  AnimationDone
  ResetClicked
  CopyClicked(slug: String, text: String)
  CopyCleared
}
```

### - [ ] Step 10.2: Rewrite `app.gleam`

```gleam
//// Royal Shortener — entry point.

import gleam/list
import gleam/option
import gleam/string
import lustre
import lustre/effect.{type Effect}
import royal/api
import royal/data
import royal/ffi
import royal/format
import royal/types
import royal/view

fn init(_flags) -> #(types.Model, Effect(types.Msg)) {
  let model =
    types.Model(
      url: format.strip_scheme(data.slides_url),
      phase: types.Idle,
      result: option.None,
      ledger: [],
      copied: option.None,
      error: option.None,
    )
  #(model, effect.none())
}

fn update(
  model: types.Model,
  msg: types.Msg,
) -> #(types.Model, Effect(types.Msg)) {
  case msg {
    types.UrlChanged(value) -> #(
      types.Model(..model, url: format.strip_scheme(value), error: option.None),
      effect.none(),
    )

    types.KeyPressed("Enter") -> shorten(model)
    types.KeyPressed(_) -> #(model, effect.none())

    types.ShortenClicked -> shorten(model)

    types.MintSucceeded(minted) -> {
      let long_text = format.strip_scheme(model.url)
      let result =
        types.Minted(
          slug: minted.slug,
          short_url: minted.short_url,
          secret: minted.secret,
          long_text: long_text,
          title: format.derive_title(long_text),
        )
      #(
        types.Model(
          ..model,
          phase: types.Animating,
          result: option.Some(result),
        ),
        after(800, types.AnimationDone),
      )
    }

    types.MintFailed(err) -> #(
      types.Model(
        ..model,
        phase: types.Idle,
        error: option.Some(error_text(err)),
      ),
      effect.none(),
    )

    types.AnimationDone ->
      case model.result {
        option.Some(r) -> {
          let entry = types.LedgerItem(r.slug, r.long_text, 0)
          let ledger = list.take([entry, ..model.ledger], 6)
          #(
            types.Model(..model, phase: types.Done, ledger: ledger),
            effect.none(),
          )
        }
        option.None -> #(types.Model(..model, phase: types.Done), effect.none())
      }

    types.ResetClicked -> #(
      types.Model(
        ..model,
        phase: types.Idle,
        result: option.None,
        url: "",
        error: option.None,
      ),
      effect.none(),
    )

    types.CopyClicked(slug, text) -> {
      ffi.copy_text(text)
      #(
        types.Model(..model, copied: option.Some(slug)),
        after(1800, types.CopyCleared),
      )
    }

    types.CopyCleared -> #(
      types.Model(..model, copied: option.None),
      effect.none(),
    )
  }
}

fn shorten(model: types.Model) -> #(types.Model, Effect(types.Msg)) {
  case model.phase {
    types.Animating -> #(model, effect.none())
    _ -> {
      let raw = string.trim(model.url)
      case raw {
        "" -> #(model, effect.none())
        _ -> {
          let url = ensure_scheme(raw)
          let effect =
            api.create_link(url, option.None, fn(result) {
              case result {
                Ok(m) -> types.MintSucceeded(m)
                Error(e) -> types.MintFailed(e)
              }
            })
          #(
            types.Model(..model, phase: types.Animating, error: option.None),
            effect,
          )
        }
      }
    }
  }
}

fn ensure_scheme(input: String) -> String {
  case string.starts_with(input, "http://") || string.starts_with(input, "https://") {
    True -> input
    False -> "https://" <> input
  }
}

fn error_text(err: api.ApiError) -> String {
  case err {
    api.Network(msg) -> "Network error: " <> msg
    api.Conflict -> "That title is taken — choose another."
    api.BadRequest(msg) -> msg
    api.Server(msg) -> "The realm is briefly indisposed: " <> msg
  }
}

fn after(ms: Int, msg: types.Msg) -> Effect(types.Msg) {
  effect.from(fn(dispatch) { ffi.after(ms, fn() { dispatch(msg) }) })
}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
```

### - [ ] Step 10.3: Drop dead code from `data.gleam`

In `frontend/src/royal/data.gleam`, **remove** `random_slug`, `pick`, `random_tag`, `random_char`, the `royal_words` and `tag_alphabet` constants — they were only used from `app.gleam` and are now obsolete. Leave `features`, `slides_url`, `make_qr` and the QR helpers.

If `ffi.random_int` is no longer referenced by any frontend file after this change, also remove it from `frontend/src/royal/ffi.gleam` and `frontend/src/royal/ffi_ext.mjs`. Run `gleam build` after to confirm no unresolved references.

### - [ ] Step 10.4: Run tests and a type-check

```bash
cd frontend && gleam build && gleam test
```

Expected: clean build, tests green.

### - [ ] Step 10.5: Commit

```bash
git add frontend/src/royal/types.gleam frontend/src/royal/app.gleam frontend/src/royal/data.gleam frontend/src/royal/ffi.gleam frontend/src/royal/ffi_ext.mjs
git commit -m "Wire frontend shorten flow to the backend API"
```

---

## Task 11: View — show secret + error message

**Files:**
- Modify: `frontend/src/royal/view.gleam`

### - [ ] Step 11.1: Render the secret and an error banner

In `frontend/src/royal/view.gleam`:

1. **Inside `result_card`** (around the existing meta and actions block), insert a block showing the management secret. After the `meta` row and before `result-actions`:

```gleam
      html.div([attr.class("secret-row")], [
        html.div([attr.class("k")], [element.text("Management key")]),
        html.code([attr.class("secret mono")], [element.text(result.secret)]),
        html.p([attr.class("hint")], [
          element.text(
            "Save this token. It is the only way to manage this link or view its stats without an account.",
          ),
        ]),
      ]),
```

2. **Inside `shortener`**, between `helper-row` and the existing `stage` div, render an error banner when `model.error` is `Some`:

```gleam
      error_banner(model),
```

And define:

```gleam
fn error_banner(model: types.Model) -> Element(types.Msg) {
  case model.error {
    option.None -> element.none()
    option.Some(msg) ->
      html.div([attr.class("error-banner")], [element.text(msg)])
  }
}
```

3. **Append CSS** to the `extra_css` string at the bottom of the file:

```
.secret-row { margin-top: 16px; padding: 12px 16px; border: 1px dashed rgba(255,200,80,0.4); border-radius: 8px; background: rgba(255,200,80,0.06); }
.secret-row .k { font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; opacity: 0.7; margin-bottom: 4px; }
.secret-row .secret { display: block; padding: 6px 0; font-size: 13px; word-break: break-all; }
.secret-row .hint { margin-top: 4px; font-size: 12px; opacity: 0.75; }
.error-banner { margin-top: 12px; padding: 10px 14px; border-radius: 8px; background: rgba(255,90,90,0.12); color: #ffd7d7; font-size: 14px; }
```

### - [ ] Step 11.2: Build the frontend

```bash
cd frontend && gleam build
```

### - [ ] Step 11.3: Commit

```bash
git add frontend/src/royal/view.gleam
git commit -m "Show management secret and error banner in result card"
```

---

## Task 12: Manual end-to-end verification

**Files:** none modified — this is a sanity check that the slice works end-to-end.

### - [ ] Step 12.1: Boot backend

```bash
cd backend && gleam run &
sleep 2
```

### - [ ] Step 12.2: Boot frontend dev server

```bash
cd frontend && gleam run -m lustre/dev start &
sleep 5
```

### - [ ] Step 12.3: Verify the create flow

Open http://localhost:1234 in a browser. The pre-filled URL (slides_url) should already be in the input. Click **Shorten**.

Expected:
- The collapse animation runs.
- After ~1s, the result card shows a real short URL `/<RoyalWord>-xyz`, a real secret token, and a copy button.
- The copy button copies `royal.sh/<slug>` (or whatever copy_text resolves to).

### - [ ] Step 12.4: Verify the redirect works

Take the slug from the result card and `curl` it against the backend:

```bash
curl -s -i http://localhost:8080/<slug>
```

Expected: `HTTP/1.1 302 Found` with `Location: <the URL you started with>`.

Also open `http://localhost:1234/<slug>` in a browser to confirm the SPA dev-server *proxies* the redirect — actually, the dev-server only proxies `/api`; it serves any other path as the SPA. So this test must be against the backend port directly (`8080`), not the dev server (`1234`).

### - [ ] Step 12.5: Verify error path

In the browser DevTools network tab, throttle to offline. Click **Shorten**. Expect the red error banner.

Restore network. Type a clearly invalid input (one space, e.g. " ") and Shorten. Expect either a graceful no-op (trim → empty) or a backend 400 surfaced as banner.

### - [ ] Step 12.6: Verify duplicate slug

```bash
curl -s -X POST http://localhost:8080/api/links \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com","slug":"Sovereign-zzz"}'

# Repeat the same command:
curl -s -i -X POST http://localhost:8080/api/links \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com","slug":"Sovereign-zzz"}'
```

Expected: first returns 201, second returns 409.

### - [ ] Step 12.7: Stop the dev servers

```bash
kill %1 %2 2>/dev/null
```

### - [ ] Step 12.8: Note

There is nothing to commit here. If anything failed, the failure belongs in the corresponding earlier task — go back and fix it there, then re-run from Step 12.1.

---

## Done

M1 ships when all 12 tasks are green and Step 12 walks cleanly end-to-end:

- `POST /api/links` creates a link in SQLite and returns `{slug, short_url, secret}`.
- `GET /:slug` returns `302` for a known slug and `404` for an unknown one.
- The landing form drives the real API and shows the secret.
- Slug collision returns `409`; reserved slugs return `400`.
- Tests cover happy path, collision, redirect, 404, reserved slug, invalid URL.

The next milestone (M2 — expiry + click limit) will add columns to `links` via `priv/migrations/002_*.sql`, the atomic SQL on the redirect path, and `410 Gone` handling. No code from M1 needs to be undone.
