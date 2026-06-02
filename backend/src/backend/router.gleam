import gleam/http/request
import gleam/http/response
import gleam/option
import wisp.{type Request, type Response}

/// Top-level request handler. Static assets (the compiled Lustre bundle and
/// any other files) are served from `static_directory`; everything else falls
/// through to the application routes.
pub fn handle_request(req: Request, static_directory: String) -> Response {
  use <- wisp.serve_static(req, under: "/", from: static_directory)

  case request.path_segments(req) {
    ["health"] -> health()

    // Single-page app: any unmatched, non-asset path returns the host page so
    // the client-side router can take over.
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
