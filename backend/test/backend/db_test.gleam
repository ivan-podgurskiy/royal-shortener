import backend/db

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
