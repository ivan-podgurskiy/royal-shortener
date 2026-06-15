import backend/db
import backend/router
import backend/test_helpers as th
import gleam/json
import gleam/string
import gleeunit/should
import wisp

fn fresh_router() -> #(db.Conn, fn(wisp.Request) -> wisp.Response) {
  let assert Ok(conn) = db.open(":memory:")
  let assert Ok(_) = db.run_migrations(conn)
  let handler = fn(req) { router.handle_request(req, "./priv/static", conn) }
  #(conn, handler)
}

pub fn post_creates_link_test() {
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

  let body = json.object([#("url", json.string("not a url"))])
  let req = th.post_json("/api/links", json.to_string(body))
  let resp = handle(req)
  th.status(resp) |> should.equal(400)
}

pub fn post_with_click_limit_test() {
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

  let resp = handle(th.get("/no-such-slug"))
  th.status(resp) |> should.equal(404)
}

pub fn redirect_exhausted_link_returns_410_test() {
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

  let resp = handle(th.get("/health"))
  th.status(resp) |> should.equal(200)
}

pub fn link_qr_returns_svg_test() {
  let #(_conn, handle) = fresh_router()

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
  let #(_conn, handle) = fresh_router()

  let resp = handle(th.get("/api/links/no-such-slug/qr"))
  th.status(resp) |> should.equal(404)
}
