//// HTTP handlers for /api/* routes and slug redirects.

import backend/analytics
import backend/clicks
import backend/db
import backend/links
import backend/qr
import backend/slug
import gleam/dynamic/decode
import gleam/http
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import wisp.{type Request, type Response}

pub fn create_link(req: Request, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  case decode.run(body, create_request_decoder()) {
    Error(_) -> bad_request("invalid request body")
    Ok(parsed) ->
      case validate_url(parsed.url) {
        Error(reason) -> bad_request(reason)
        Ok(url) ->
          case resolved_slug(parsed.slug) {
            Error(reason) -> bad_request(reason)
            Ok(s) ->
              case parse_expires_in(parsed.expires_in) {
                Error(reason) -> bad_request(reason)
                Ok(expires_at) ->
                  case validate_click_limit(parsed.click_limit) {
                    Error(reason) -> bad_request(reason)
                    Ok(limit) -> insert(url, s, expires_at, limit, conn)
                  }
              }
          }
      }
  }
}

pub fn redirect_slug(
  req: Request,
  slug: String,
  db_path: String,
  conn: db.Conn,
) -> Response {
  case links.claim_redirect(slug, conn) {
    Ok(links.Found(url, link_id)) -> {
      analytics.record_after_redirect(req, link_id, db_path)
      wisp.response(302)
      |> response.set_header("location", url)
    }
    Ok(links.Gone) -> revoked()
    Error(links.NotFound) -> not_found()
    Error(_) -> server_error()
  }
}

pub fn link_stats(req: Request, slug: String, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Get)

  case list.key_find(wisp.get_query(req), "secret") {
    Error(_) -> forbidden()
    Ok(provided) ->
      case links.find_by_slug(slug, conn) {
        Ok(link) ->
          case provided == link.secret {
            True ->
              case clicks.stats_for_link(link.id, conn) {
                Ok(stats) ->
                  wisp.json_response(json.to_string(clicks.stats_json(stats)), 200)
                Error(_) -> server_error()
              }
            False -> forbidden()
          }
        Error(links.NotFound) -> not_found()
        Error(_) -> server_error()
      }
  }
}

pub fn link_qr(req: Request, slug: String, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Get)

  case links.find_by_slug(slug, conn) {
    Ok(_link) ->
      case qr.to_svg(public_short_url(req, slug)) {
        Ok(svg) ->
          wisp.response(200)
          |> response.set_header("content-type", "image/svg+xml; charset=utf-8")
          |> response.set_header("cache-control", "public, max-age=86400")
          |> wisp.set_body(wisp.Text(svg))
        Error(_) -> server_error()
      }
    Error(links.NotFound) -> not_found()
    Error(_) -> server_error()
  }
}

// ------------ internals --------------------------------------------------

type CreateRequest {
  CreateRequest(
    url: String,
    slug: Option(String),
    expires_in: Option(String),
    click_limit: Option(Int),
  )
}

fn create_request_decoder() -> decode.Decoder(CreateRequest) {
  use url <- decode.field("url", decode.string)
  use slug <- decode.optional_field("slug", None, decode.optional(decode.string))
  use expires_in <- decode.optional_field(
    "expires_in",
    None,
    decode.optional(decode.string),
  )
  use click_limit <- decode.optional_field(
    "click_limit",
    None,
    decode.optional(decode.int),
  )
  decode.success(CreateRequest(url:, slug:, expires_in:, click_limit:))
}

fn validate_url(input: String) -> Result(String, String) {
  let trimmed = string.trim(input)
  case trimmed {
    "" -> Error("url is empty")
    _ ->
      case uri.parse(trimmed) {
        Error(_) -> Error("url is not a valid URI")
        Ok(parsed) ->
          case parsed.scheme {
            Some("http") | Some("https") -> Ok(trimmed)
            _ -> Error("url must use http or https")
          }
      }
  }
}

fn resolved_slug(input: Option(String)) -> Result(String, String) {
  case input {
    None -> Ok(slug.random())
    Some(user) ->
      slug.validate_user_slug(user)
      |> result.map_error(slug_error_message)
  }
}

fn slug_error_message(e: slug.ValidationError) -> String {
  case e {
    slug.Empty -> "slug is empty"
    slug.TooLong -> "slug is too long"
    slug.BadCharacters ->
      "slug may only contain letters, digits, hyphen, and underscore"
    slug.Reserved -> "slug is reserved"
  }
}

fn parse_expires_in(input: Option(String)) -> Result(Option(Int), String) {
  case input {
    None | Some("") -> Ok(None)
    Some("never") -> Ok(None)
    Some("1h") -> Ok(Some(system_seconds() + 3600))
    Some("24h") -> Ok(Some(system_seconds() + 86_400))
    Some("7d") -> Ok(Some(system_seconds() + 604_800))
    Some(_) -> Error("expires_in must be one of: 1h, 24h, 7d, never")
  }
}

fn validate_click_limit(input: Option(Int)) -> Result(Option(Int), String) {
  case input {
    None -> Ok(None)
    Some(n) if n < 1 -> Error("click_limit must be at least 1")
    Some(n) -> Ok(Some(n))
  }
}

fn insert(
  url: String,
  slug: String,
  expires_at: Option(Int),
  click_limit: Option(Int),
  conn: db.Conn,
) -> Response {
  case
    links.create(
      target_url: url,
      slug: slug,
      expires_at: expires_at,
      click_limit: click_limit,
      conn: conn,
    )
  {
    Ok(link) -> created(link)
    Error(links.SlugTaken) -> conflict("slug already taken")
    Error(links.NotFound) -> server_error()
    Error(links.StorageError(_)) -> server_error()
  }
}

fn created(link: links.Link) -> Response {
  let body =
    json.object([
      #("slug", json.string(link.slug)),
      #("short_url", json.string("/" <> link.slug)),
      #("secret", json.string(link.secret)),
    ])
  wisp.json_response(json.to_string(body), 201)
}

fn bad_request(message: String) -> Response {
  error_json(400, message)
}

fn conflict(message: String) -> Response {
  error_json(409, message)
}

fn forbidden() -> Response {
  error_json(403, "forbidden")
}

fn not_found() -> Response {
  error_json(404, "not found")
}

fn server_error() -> Response {
  error_json(500, "internal error")
}

fn error_json(status: Int, message: String) -> Response {
  let body = json.object([#("error", json.string(message))])
  wisp.json_response(json.to_string(body), status)
}

fn revoked() -> Response {
  wisp.response(410)
  |> response.set_header("content-type", "text/html; charset=utf-8")
  |> wisp.set_body(wisp.Text(revoked_html()))
}

fn public_short_url(req: Request, slug: String) -> String {
  let scheme =
    case list.key_find(req.headers, "x-forwarded-proto") {
      Ok("https") -> "https"
      Ok(_) -> "http"
      Error(_) -> "http"
    }
  let host =
    case list.key_find(req.headers, "x-forwarded-host") {
      Ok(value) -> value
      Error(_) ->
        case list.key_find(req.headers, "host") {
          Ok(value) -> value
          Error(_) -> "localhost:8080"
        }
    }
  scheme <> "://" <> host <> "/" <> slug
}

fn revoked_html() -> String {
  "<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>Link Revoked — Royal Shortener</title>
  <style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center;
      font-family: Georgia, serif; background: #0b1020; color: #f5ecd8; }
    main { max-width: 32rem; padding: 2rem; text-align: center; }
    h1 { font-size: 1.75rem; margin-bottom: 0.5rem; color: #e8c872; }
    p { line-height: 1.6; opacity: 0.85; }
  </style>
</head>
<body>
  <main>
    <h1>This link has been revoked</h1>
    <p>By royal decree, this short link has expired or reached its click limit and may no longer be used.</p>
  </main>
</body>
</html>"
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
