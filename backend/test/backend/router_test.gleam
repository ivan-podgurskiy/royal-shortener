import backend/db
import backend/router
import backend/test_helpers as th
import gleam/int
import gleam/json
import gleam/string
import gleeunit/should
import wisp

fn fresh_router() -> #(db.Conn, String, fn(wisp.Request) -> wisp.Response) {
  let db_path = "file:test_" <> int.to_string(unique_int()) <> "?mode=memory&cache=shared"
  let assert Ok(conn) = db.open(db_path)
  let assert Ok(_) = db.run_migrations(conn)
  let handler = fn(req) {
    router.handle_request(req, "./priv/static", db_path, conn)
  }
  #(conn, db_path, handler)
}

pub fn post_creates_link_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body = json.object([#("url", json.string("https://example.com/long"))])
  let req = th.post_json("/api/links", json.to_string(body))
  let resp = handle(req)

  th.status(resp) |> should.equal(201)

  let assert Ok(body_str) = th.string_body(resp)
  body_str |> string.contains("\"slug\":") |> should.be_true
  body_str |> string.contains("\"short_url\":") |> should.be_true
  body_str |> string.contains("\"secret\":") |> should.be_true
}

pub fn post_with_custom_slug_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("Sovereign-abc")),
    ])
  let req = th.post_json("/api/links", json.to_string(body))
  let resp = handle(req)

  th.status(resp) |> should.equal(201)
  let assert Ok(body_str) = th.string_body(resp)
  body_str |> string.contains("Sovereign-abc") |> should.be_true
}

pub fn post_with_duplicate_slug_returns_409_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("Sovereign-abc")),
    ])
  let req1 = th.post_json("/api/links", json.to_string(body))
  let _ = handle(req1)

  let req2 = th.post_json("/api/links", json.to_string(body))
  let resp = handle(req2)
  th.status(resp) |> should.equal(409)
}

pub fn post_with_reserved_slug_returns_400_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("api")),
    ])
  let req = th.post_json("/api/links", json.to_string(body))
  let resp = handle(req)
  th.status(resp) |> should.equal(400)
}

pub fn post_with_invalid_url_returns_400_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body = json.object([#("url", json.string("not a url"))])
  let req = th.post_json("/api/links", json.to_string(body))
  let resp = handle(req)
  th.status(resp) |> should.equal(400)
}

pub fn post_with_click_limit_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("Limited-xyz")),
      #("click_limit", json.int(2)),
    ])
  let req = th.post_json("/api/links", json.to_string(body))
  let resp = handle(req)
  th.status(resp) |> should.equal(201)
}

pub fn redirect_returns_302_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com/target")),
      #("slug", json.string("Crowned-rrr")),
    ])
  let _ = handle(th.post_json("/api/links", json.to_string(body)))

  let resp = handle(th.get("/Crowned-rrr"))
  th.status(resp) |> should.equal(302)
  th.header(resp, "location") |> should.equal("https://example.com/target")
}

pub fn redirect_unknown_slug_returns_404_test() {
  let #(_conn, _path, handle) = fresh_router()

  let resp = handle(th.get("/no-such-slug"))
  th.status(resp) |> should.equal(404)
}

pub fn redirect_exhausted_link_returns_410_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com/target")),
      #("slug", json.string("Gone-abc")),
      #("click_limit", json.int(1)),
    ])
  let _ = handle(th.post_json("/api/links", json.to_string(body)))
  let _ = handle(th.get("/Gone-abc"))

  let resp = handle(th.get("/Gone-abc"))
  th.status(resp) |> should.equal(410)
}

pub fn redirect_does_not_clobber_reserved_paths_test() {
  let #(_conn, _path, handle) = fresh_router()

  let resp = handle(th.get("/health"))
  th.status(resp) |> should.equal(200)
}

pub fn link_qr_returns_svg_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com/target")),
      #("slug", json.string("Seal-abc")),
    ])
  let _ = handle(th.post_json("/api/links", json.to_string(body)))

  let resp = handle(th.get("/api/links/Seal-abc/qr"))
  th.status(resp) |> should.equal(200)
  th.header(resp, "content-type")
  |> string.contains("image/svg+xml")
  |> should.be_true

  let assert Ok(body_str) = th.string_body(resp)
  body_str |> string.contains("<svg") |> should.be_true
}

pub fn link_qr_unknown_slug_returns_404_test() {
  let #(_conn, _path, handle) = fresh_router()

  let resp = handle(th.get("/api/links/no-such-slug/qr"))
  th.status(resp) |> should.equal(404)
}

pub fn stats_requires_secret_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("Ledger-abc")),
    ])
  let create = handle(th.post_json("/api/links", json.to_string(body)))
  th.status(create) |> should.equal(201)
  let assert Ok(create_body) = th.string_body(create)
  create_body |> string.contains("\"secret\":") |> should.be_true

  let resp = handle(th.get("/api/links/Ledger-abc/stats"))
  th.status(resp) |> should.equal(403)
}

pub fn stats_with_wrong_secret_returns_403_test() {
  let #(_conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com")),
      #("slug", json.string("Ledger-def")),
    ])
  let _ = handle(th.post_json("/api/links", json.to_string(body)))

  let resp = handle(th.get("/api/links/Ledger-def/stats?secret=wrong"))
  th.status(resp) |> should.equal(403)
}

pub fn redirect_records_click_event_test() {
  let #(conn, _path, handle) = fresh_router()

  let body =
    json.object([
      #("url", json.string("https://example.com/target")),
      #("slug", json.string("Track-abc")),
    ])
  let create = handle(th.post_json("/api/links", json.to_string(body)))
  th.status(create) |> should.equal(201)
  let assert Ok(create_body) = th.string_body(create)
  let secret = extract_secret(create_body)

  let _ = handle(th.get("/Track-abc"))
  sleep_ms(50)

  let stats_resp = handle(th.get("/api/links/Track-abc/stats?secret=" <> secret))
  th.status(stats_resp) |> should.equal(200)
  let assert Ok(stats_body) = th.string_body(stats_resp)
  stats_body |> string.contains("\"total\":1") |> should.be_true

  let assert Ok(Nil) = db.close(conn)
}

fn extract_secret(body: String) -> String {
  case string.split(body, "\"secret\":\"") {
    [_, rest, ..] ->
      case string.split(rest, on: "\"") {
        [secret, ..] -> secret
        _ -> ""
      }
    _ -> ""
  }
}

@external(erlang, "erlang", "unique_integer")
fn unique_int() -> Int

@external(erlang, "timer", "sleep")
fn sleep_ms(ms: Int) -> Nil
