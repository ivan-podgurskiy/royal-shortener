import backend/db
import backend/links
import gleam/option
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
      expires_at: option.None,
      click_limit: option.None,
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
      expires_at: option.None,
      click_limit: option.None,
      conn: conn,
    )
  let result =
    links.create(
      target_url: "https://example.com/b",
      slug: "Sovereign-7qz",
      expires_at: option.None,
      click_limit: option.None,
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
      expires_at: option.None,
      click_limit: option.None,
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

pub fn claim_redirect_increments_click_count_test() {
  let conn = fresh_db()
  let assert Ok(_) =
    links.create(
      target_url: "https://example.com/target",
      slug: "Crowned-abc",
      expires_at: option.None,
      click_limit: option.None,
      conn: conn,
    )

  let assert Ok(links.Found(url, _)) = links.claim_redirect("Crowned-abc", conn)
  url |> should.equal("https://example.com/target")

  let assert Ok(link) = links.find_by_slug("Crowned-abc", conn)
  link.click_count |> should.equal(1)
}

pub fn claim_redirect_respects_click_limit_test() {
  let conn = fresh_db()
  let assert Ok(_) =
    links.create(
      target_url: "https://example.com/target",
      slug: "Limited-abc",
      expires_at: option.None,
      click_limit: option.Some(1),
      conn: conn,
    )

  let assert Ok(links.Found(_, _)) = links.claim_redirect("Limited-abc", conn)
  links.claim_redirect("Limited-abc", conn)
  |> should.equal(Ok(links.Gone))
}

pub fn claim_redirect_respects_expiry_test() {
  let conn = fresh_db()
  let assert Ok(_) =
    links.create(
      target_url: "https://example.com/target",
      slug: "Expired-abc",
      expires_at: option.Some(system_seconds() - 1),
      click_limit: option.None,
      conn: conn,
    )

  links.claim_redirect("Expired-abc", conn)
  |> should.equal(Ok(links.Gone))
}

pub fn claim_redirect_unknown_slug_test() {
  let conn = fresh_db()
  links.claim_redirect("missing-slug", conn)
  |> should.equal(Error(links.NotFound))
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
