//// Session tokens stored in SQLite.

import backend/db
import gleam/dynamic/decode
import gleam/result
import sqlight

pub const ttl_seconds = 2_592_000

pub type Error {
  NotFound
  StorageError(String)
}

pub fn create(user_id: Int, conn: db.Conn) -> Result(String, Error) {
  let token = mint_token()
  let expires_at = system_seconds() + ttl_seconds
  let sql =
    "INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, ?)"

  sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(token), sqlight.int(user_id), sqlight.int(expires_at)],
    expecting: decode.success(Nil),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
  |> result.map(fn(_) { token })
}

pub fn user_id(token: String, conn: db.Conn) -> Result(Int, Error) {
  let now = system_seconds()
  let sql =
    "SELECT user_id FROM sessions WHERE token = ? AND expires_at > ?"

  sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(token), sqlight.int(now)],
    expecting: decode.at([0], decode.int),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
  |> result.try(fn(rows) {
    case rows {
      [id, ..] -> Ok(id)
      [] -> Error(NotFound)
    }
  })
}

pub fn delete(token: String, conn: db.Conn) -> Result(Nil, Error) {
  let sql = "DELETE FROM sessions WHERE token = ?"

  sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(token)],
    expecting: decode.success(Nil),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
  |> result.map(fn(_) { Nil })
}

fn mint_token() -> String {
  mint_token_ffi()
}

@external(erlang, "backend_sessions_ffi", "mint_token")
fn mint_token_ffi() -> String

fn error_message(e: sqlight.Error) -> String {
  case e {
    sqlight.SqlightError(message: message, ..) -> message
  }
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
