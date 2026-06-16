import backend/db
import backend/users
import gleam/int
import gleeunit/should

pub fn create_user_test() {
  let db_path =
    "file:users_test_"
    <> int.to_string(unique())
    <> "?mode=memory&cache=shared"
  let assert Ok(conn) = db.open(db_path)
  let assert Ok(_) = db.run_migrations(conn)
  let assert Ok(user) = users.create("knight@example.com", "swordfish1", conn)
  user.email |> should.equal("knight@example.com")
}

@external(erlang, "erlang", "unique_integer")
fn unique() -> Int
