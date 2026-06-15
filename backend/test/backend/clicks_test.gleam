import backend/clicks
import backend/db
import backend/links
import gleam/option
import gleeunit/should

fn memory_conn() -> db.Conn {
  let assert Ok(conn) = db.open(":memory:")
  let assert Ok(_) = db.run_migrations(conn)
  conn
}

fn seed_link(conn: db.Conn, slug: String) -> links.Link {
  let assert Ok(link) =
    links.create(
      target_url: "https://example.com",
      slug: slug,
      expires_at: option.None,
      click_limit: option.None,
      conn: conn,
    )
  link
}

pub fn record_and_aggregate_test() {
  let conn = memory_conn()
  let link = seed_link(conn, "Stats-abc")
  let now = system_seconds()

  let assert Ok(Nil) =
    clicks.record(
      clicks.ClickEvent(
        link_id: link.id,
        at: now,
        referrer: option.None,
        country: option.Some("US"),
        device_class: clicks.Desktop,
      ),
      conn,
    )

  let assert Ok(Nil) =
    clicks.record(
      clicks.ClickEvent(
        link_id: link.id,
        at: now + 60,
        referrer: option.None,
        country: option.Some("US"),
        device_class: clicks.Mobile,
      ),
      conn,
    )

  let assert Ok(stats) = clicks.stats_for_link(link.id, conn)
  stats.total |> should.equal(2)
  list_length(stats.by_country) |> should.equal(1)
  list_length(stats.by_device) |> should.equal(2)
}

fn list_length(items: List(a)) -> Int {
  items
  |> list_count(0)
}

fn list_count(items: List(a), n: Int) -> Int {
  case items {
    [] -> n
    [_, ..rest] -> list_count(rest, n + 1)
  }
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
