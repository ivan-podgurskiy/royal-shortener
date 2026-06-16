import backend/api
import backend/auth
import backend/db
import backend/slug as slug_mod
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/option
import wisp.{type Request, type Response}

/// Top-level request handler. Order of decisions:
///   1. Static assets from `static_directory`.
///   2. `/api/*` — JSON API.
///   3. `/health` — plain "ok".
///   4. `/:slug` — single-segment redirect.
///   5. Anything else — return `index.html` so the SPA can take over.
pub fn handle_request(
  req: Request,
  static_directory: String,
  db_path: String,
  conn: db.Conn,
) -> Response {
  use <- wisp.serve_static(req, under: "/", from: static_directory)

  case request.path_segments(req) {
    ["api", "auth", "signup"] -> auth.signup(req, conn)
    ["api", "auth", "login"] -> auth.login(req, conn)
    ["api", "auth", "logout"] -> auth.logout(req, conn)
    ["api", "me", "links"] -> auth.my_links(req, conn)
    ["api", "me", "claim-links"] -> auth.claim_links(req, conn)
    ["api", "links", slug, "stats"] -> api.link_stats(req, slug, conn)
    ["api", "links", slug, "qr"] -> api.link_qr(req, slug, conn)
    ["api", "links"] -> api.create_link(req, conn)
    ["health"] -> health()
    [slug] ->
      case req.method, is_reserved_top_level(slug) {
        http.Get, False -> api.redirect_slug(req, slug, db_path, conn)
        _, _ -> index(static_directory)
      }
    _ -> index(static_directory)
  }
}

fn health() -> Response {
  wisp.ok()
}

fn index(static_directory: String) -> Response {
  let index_path = static_directory <> "/index.html"

  wisp.response(200)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> wisp.set_body(wisp.File(path: index_path, offset: 0, limit: option.None))
}

fn is_reserved_top_level(path: String) -> Bool {
  slug_mod.is_reserved(path)
}
