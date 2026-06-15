//// Persistence for shortened links.

import backend/db
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import sqlight

pub type Link {
  Link(
    id: Int,
    slug: String,
    target_url: String,
    secret: String,
    click_count: Int,
    created_at: Int,
    expires_at: Option(Int),
    click_limit: Option(Int),
  )
}

pub type Error {
  SlugTaken
  NotFound
  StorageError(String)
}

pub type RedirectResult {
  Found(target_url: String, link_id: Int)
  Gone
}

pub fn create(
  target_url target_url: String,
  slug slug: String,
  expires_at expires_at: Option(Int),
  click_limit click_limit: Option(Int),
  conn conn: db.Conn,
) -> Result(Link, Error) {
  let secret = mint_secret()
  let now = system_seconds()

  let sql =
    "INSERT INTO links (slug, target_url, secret, click_count, created_at, expires_at, click_limit)
     VALUES (?, ?, ?, 0, ?, ?, ?)
     RETURNING id, slug, target_url, secret, click_count, created_at, expires_at, click_limit"

  let res =
    sqlight.query(
      sql,
      on: conn,
      with: [
        sqlight.text(slug),
        sqlight.text(target_url),
        sqlight.text(secret),
        sqlight.int(now),
        nullable_int(expires_at),
        nullable_int(click_limit),
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
    "SELECT id, slug, target_url, secret, click_count, created_at, expires_at, click_limit
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
    Error(e) -> Error(StorageError(error_message(e)))
  }
}

/// Atomically increment click_count and return the target URL when the link
/// is still valid. Zero rows updated means expired or exhausted.
pub fn claim_redirect(slug: String, conn: db.Conn) -> Result(RedirectResult, Error) {
  let sql =
    "UPDATE links
     SET click_count = click_count + 1
     WHERE slug = ?
       AND (click_limit IS NULL OR click_count < click_limit)
       AND (expires_at IS NULL OR expires_at > unixepoch())
     RETURNING id, target_url"

  let res =
    sqlight.query(
      sql,
      on: conn,
      with: [sqlight.text(slug)],
      expecting: redirect_decoder(),
    )

  case res {
    Ok([#(link_id, url), ..]) -> Ok(Found(url, link_id))
    Ok([]) ->
      case find_by_slug(slug, conn) {
        Ok(_) -> Ok(Gone)
        Error(NotFound) -> Error(NotFound)
        Error(e) -> Error(e)
      }
    Error(e) -> Error(StorageError(error_message(e)))
  }
}

// ------------ internals --------------------------------------------------

fn redirect_decoder() -> decode.Decoder(#(Int, String)) {
  use link_id <- decode.field(0, decode.int)
  use target_url <- decode.field(1, decode.string)
  decode.success(#(link_id, target_url))
}

fn link_decoder() -> decode.Decoder(Link) {
  use id <- decode.field(0, decode.int)
  use slug <- decode.field(1, decode.string)
  use target_url <- decode.field(2, decode.string)
  use secret <- decode.field(3, decode.string)
  use click_count <- decode.field(4, decode.int)
  use created_at <- decode.field(5, decode.int)
  use expires_at <- decode.field(6, decode.optional(decode.int))
  use click_limit <- decode.field(7, decode.optional(decode.int))
  decode.success(Link(
    id,
    slug,
    target_url,
    secret,
    click_count,
    created_at,
    expires_at,
    click_limit,
  ))
}

fn nullable_int(value: Option(Int)) -> sqlight.Value {
  case value {
    Some(n) -> sqlight.int(n)
    None -> sqlight.null()
  }
}

fn classify_sqlight_error(e: sqlight.Error) -> Error {
  case e {
    sqlight.SqlightError(code: sqlight.ConstraintUnique, ..) -> SlugTaken
    other -> StorageError(error_message(other))
  }
}

fn error_message(e: sqlight.Error) -> String {
  case e {
    sqlight.SqlightError(message: message, ..) -> message
  }
}

fn mint_secret() -> String {
  strong_rand_bytes(16) |> encode_hex
}

@external(erlang, "crypto", "strong_rand_bytes")
fn strong_rand_bytes(n: Int) -> BitArray

@external(erlang, "binary", "encode_hex")
fn encode_hex(bin: BitArray) -> String

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
