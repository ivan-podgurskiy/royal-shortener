//// User accounts.

import backend/db
import backend/password
import gleam/dynamic/decode
import gleam/result
import gleam/string
import sqlight

pub type User {
  User(id: Int, email: String, created_at: Int)
}

pub type Error {
  EmailTaken
  InvalidEmail
  WeakPassword
  NotFound
  InvalidCredentials
  StorageError(String)
}

pub fn create(
  email email: String,
  password plain_password: String,
  conn conn: db.Conn,
) -> Result(User, Error) {
  case validate_email(email) {
    Error(e) -> Error(e)
    Ok(normalized) ->
      case validate_password(plain_password) {
        Error(e) -> Error(e)
        Ok(_) ->
          case password.hash(plain_password) {
            Error(_) -> Error(StorageError("password hash failed"))
            Ok(hash) -> insert_user(normalized, hash, conn)
          }
      }
  }
}

pub fn authenticate(
  email: String,
  plain_password: String,
  conn: db.Conn,
) -> Result(User, Error) {
  let normalized = normalize_email(email)
  case find_by_email(normalized, conn) {
    Error(NotFound) -> Error(InvalidCredentials)
    Error(e) -> Error(e)
    Ok(#(user, hash)) ->
      case password.verify(hash, plain_password) {
        True -> Ok(user)
        False -> Error(InvalidCredentials)
      }
  }
}

pub fn find(id: Int, conn: db.Conn) -> Result(User, Error) {
  let sql = "SELECT id, email, created_at FROM users WHERE id = ?"

  sqlight.query(
    sql,
    on: conn,
    with: [sqlight.int(id)],
    expecting: user_decoder(),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
  |> result.try(fn(rows) {
    case rows {
      [user, ..] -> Ok(user)
      [] -> Error(NotFound)
    }
  })
}

fn insert_user(email: String, hash: String, conn: db.Conn) -> Result(User, Error) {
  let now = system_seconds()
  let sql =
    "INSERT INTO users (email, password_hash, created_at)
     VALUES (?, ?, ?)
     RETURNING id, email, created_at"

  sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(email), sqlight.text(hash), sqlight.int(now)],
    expecting: user_decoder(),
  )
  |> result.map_error(classify_insert_error)
  |> result.try(fn(rows) {
    case rows {
      [user, ..] -> Ok(user)
      [] -> Error(StorageError("insert returned no rows"))
    }
  })
}

fn find_by_email(email: String, conn: db.Conn) -> Result(#(User, String), Error) {
  let sql = "SELECT id, email, created_at, password_hash FROM users WHERE email = ?"

  sqlight.query(
    sql,
    on: conn,
    with: [sqlight.text(email)],
    expecting: auth_decoder(),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
  |> result.try(fn(rows) {
    case rows {
      [#(user, hash), ..] -> Ok(#(user, hash))
      [] -> Error(NotFound)
    }
  })
}

fn validate_email(email: String) -> Result(String, Error) {
  let normalized = normalize_email(email)
  case normalized {
    "" -> Error(InvalidEmail)
    _ ->
      case string.contains(normalized, "@") {
        True -> Ok(normalized)
        False -> Error(InvalidEmail)
      }
  }
}

fn validate_password(password: String) -> Result(Nil, Error) {
  case string.length(password) >= 8 {
    True -> Ok(Nil)
    False -> Error(WeakPassword)
  }
}

fn normalize_email(email: String) -> String {
  string.lowercase(string.trim(email))
}

fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field(0, decode.int)
  use email <- decode.field(1, decode.string)
  use created_at <- decode.field(2, decode.int)
  decode.success(User(id:, email:, created_at:))
}

fn auth_decoder() -> decode.Decoder(#(User, String)) {
  use id <- decode.field(0, decode.int)
  use email <- decode.field(1, decode.string)
  use created_at <- decode.field(2, decode.int)
  use hash <- decode.field(3, decode.string)
  decode.success(#(User(id:, email:, created_at:), hash))
}

fn classify_insert_error(e: sqlight.Error) -> Error {
  case e {
    sqlight.SqlightError(code: sqlight.ConstraintUnique, ..) -> EmailTaken
    other -> StorageError(error_message(other))
  }
}

fn error_message(e: sqlight.Error) -> String {
  case e {
    sqlight.SqlightError(message: message, ..) -> message
  }
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
