//// SQLite connection and migration runner.
////
//// Migrations live in `priv/migrations/NNN_*.sql`. The runner tracks
//// applied versions in `schema_migrations` and runs new files in order.

import envoy
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

pub fn resolve_path(priv: String) -> String {
  case envoy.get("DATABASE_URL") {
    Ok(path) -> path
    Error(_) -> priv <> "/data/royal.sqlite3"
  }
}

pub fn open(path: String) -> Result(Conn, Error) {
  use conn <- result.try(sqlight.open(path) |> result.map_error(OpenError))
  use _ <- result.try(exec("PRAGMA journal_mode=WAL", conn))
  use _ <- result.try(exec("PRAGMA busy_timeout=5000", conn))
  Ok(conn)
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
  let insert =
    "INSERT INTO schema_migrations(version, applied_at) VALUES ("
    <> int.to_string(file.version)
    <> ", "
    <> int.to_string(system_seconds())
    <> ")"
  exec(insert, conn)
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
