import backend/db
import backend/router
import backend/test_helpers as th
import gleam/json
import gleam/int
import gleam/string
import gleeunit/should
import wisp

fn fresh_router() -> #(db.Conn, fn(wisp.Request) -> wisp.Response) {
  let db_path =
    "file:auth_test_"
    <> int.to_string(unique())
    <> "?mode=memory&cache=shared"
  let assert Ok(conn) = db.open(db_path)
  let assert Ok(_) = db.run_migrations(conn)
  let handler = fn(req) {
    router.handle_request(req, "./priv/static", db_path, conn)
  }
  #(conn, handler)
}

pub fn signup_and_login_test() {
  let #(_conn, handle) = fresh_router()

  let signup_body =
    json.object([
      #("email", json.string("knight@example.com")),
      #("password", json.string("swordfish1")),
    ])
  let signup = handle(th.post_json("/api/auth/signup", json.to_string(signup_body)))
  th.status(signup) |> should.equal(201)

  let login = handle(th.post_json("/api/auth/login", json.to_string(signup_body)))
  th.status(login) |> should.equal(200)
  th.header(login, "set-cookie")
  |> string.contains("royal_session=")
  |> should.be_true
}

pub fn my_links_requires_session_test() {
  let #(_conn, handle) = fresh_router()
  let resp = handle(th.get("/api/me/links"))
  th.status(resp) |> should.equal(401)
}

pub fn claim_links_binds_anonymous_links_test() {
  let #(_conn, handle) = fresh_router()

  let link_body =
    json.object([
      #("url", json.string("https://example.com/owned")),
      #("slug", json.string("Owned-abc")),
    ])
  let created = handle(th.post_json("/api/links", json.to_string(link_body)))
  th.status(created) |> should.equal(201)
  let assert Ok(created_body) = th.string_body(created)
  let secret = extract_json_field(created_body, "secret")

  let signup_body =
    json.object([
      #("email", json.string("owner@example.com")),
      #("password", json.string("password123")),
    ])
  let _ = handle(th.post_json("/api/auth/signup", json.to_string(signup_body)))

  let login = handle(th.post_json("/api/auth/login", json.to_string(signup_body)))
  th.status(login) |> should.equal(200)
  let cookie = th.header(login, "set-cookie")

  let claim_body =
    json.object([
      #(
        "pairs",
        json.array([
          json.object([
            #("slug", json.string("Owned-abc")),
            #("secret", json.string(secret)),
          ]),
        ], fn(x) { x }),
      ),
    ])

  let claim =
    handle(
      th.with_cookie(
        th.post_json("/api/me/claim-links", json.to_string(claim_body)),
        cookie,
      ),
    )
  th.status(claim) |> should.equal(200)

  let links_resp =
    handle(th.with_cookie(th.get("/api/me/links"), cookie))
  th.status(links_resp) |> should.equal(200)
  let assert Ok(body) = th.string_body(links_resp)
  body |> string.contains("Owned-abc") |> should.be_true
}

fn extract_json_field(body: String, field: String) -> String {
  let prefix = "\"" <> field <> "\":\""
  case string.split(body, prefix) {
    [_, rest, ..] ->
      case string.split(rest, on: "\"") {
        [value, ..] -> value
        _ -> ""
      }
    _ -> ""
  }
}

@external(erlang, "erlang", "unique_integer")
fn unique() -> Int
