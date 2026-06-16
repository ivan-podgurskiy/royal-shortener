//// Argon2 password hashing via jargon.

import gleam/result

pub type Error {
  HashFailed
}

pub fn hash(password: String) -> Result(String, Error) {
  hash_password(password)
  |> result.map_error(fn(_) { HashFailed })
}

pub fn verify(encoded: String, password: String) -> Bool {
  verify_password(encoded, password)
}

@external(erlang, "backend_password_ffi", "hash_password")
fn hash_password(password: String) -> Result(String, Nil)

@external(erlang, "backend_password_ffi", "verify_password")
fn verify_password(encoded: String, password: String) -> Bool
