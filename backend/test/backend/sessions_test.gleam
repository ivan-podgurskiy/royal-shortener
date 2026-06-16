import backend/db
import backend/sessions as session_store
import backend/users
import gleam/int
import gleeunit/should

pub fn create_session_test() {
  let db_path =
    "file:session_test_"
    <> int.to_string(unique())
    <> "?mode=memory&cache=shared"
  let assert Ok(conn) = db.open(db_path)
  let assert Ok(_) = db.run_migrations(conn)
  let assert Ok(user) = users.create("duke@example.com", "password123", conn)
  let user_id = user.id
  case session_store.create(user_id, conn) {
    Ok(token) -> should.be_true(token != "")
    Error(_) -> Nil
  }
}

@external(erlang, "erlang", "unique_integer")
fn unique() -> Int
