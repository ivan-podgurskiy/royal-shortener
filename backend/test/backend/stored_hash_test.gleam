import backend/db
import backend/users
import gleam/dynamic/decode
import gleam/int
import gleam/string
import gleeunit/should
import sqlight

pub fn stored_hash_prefix_test() {
  let db_path =
    "file:stored_hash_"
    <> int.to_string(unique())
    <> "?mode=memory&cache=shared"
  let assert Ok(conn) = db.open(db_path)
  let assert Ok(_) = db.run_migrations(conn)
  let assert Ok(_user) = users.create("duke@example.com", "password123", conn)

  let sql = "SELECT password_hash FROM users WHERE email = ?"
  let assert Ok(rows) =
    sqlight.query(
      sql,
      on: conn,
      with: [sqlight.text("duke@example.com")],
      expecting: decode.at([0], decode.string),
    )

  let assert [hash, ..] = rows
  hash |> string.starts_with("$argon2") |> should.be_true
}

@external(erlang, "erlang", "unique_integer")
fn unique() -> Int
