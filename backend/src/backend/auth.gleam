//// Authentication HTTP handlers and session resolution.

import backend/cookies
import backend/db
import backend/links
import backend/sessions
import backend/users
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import wisp.{type Request, type Response}

pub fn signup(req: Request, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  case decode.run(body, credentials_decoder()) {
    Error(_) -> bad_request("invalid request body")
    Ok(#(email, password)) ->
      case users.create(email:, password:, conn:) {
        Ok(user) -> created_user(user)
        Error(users.EmailTaken) -> conflict("email already registered")
        Error(users.InvalidEmail) -> bad_request("invalid email")
        Error(users.WeakPassword) -> bad_request("password must be at least 8 characters")
        Error(_) -> server_error()
      }
  }
}

pub fn login(req: Request, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  case decode.run(body, credentials_decoder()) {
    Error(_) -> bad_request("invalid request body")
    Ok(#(email, password)) ->
      case users.authenticate(email, password, conn) {
        Ok(user) ->
          case sessions.create(user.id, conn) {
            Ok(token) -> {
              let body = user_json(user)
              wisp.json_response(body, 200)
              |> cookies.set_session(token, sessions.ttl_seconds)
            }
            Error(_) -> server_error()
          }
        Error(users.InvalidCredentials) -> unauthorized()
        Error(_) -> server_error()
      }
  }
}

pub fn logout(req: Request, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Post)

  case session_token(req) {
    None -> wisp.response(204)
    Some(token) -> {
      let _ = sessions.delete(token, conn)
      wisp.response(204)
      |> cookies.clear_session
    }
  }
}

pub fn my_links(req: Request, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Get)

  case require_user(req, conn) {
    Error(_) -> unauthorized()
    Ok(user_id) ->
      case links.list_for_owner(user_id, conn) {
        Ok(items) -> {
          let body =
            json.object([
              #(
                "links",
                json.array(items, fn(item) {
                  json.object([
                    #("slug", json.string(item.slug)),
                    #("target_url", json.string(item.target_url)),
                    #("click_count", json.int(item.click_count)),
                    #("created_at", json.int(item.created_at)),
                    #("short_url", json.string("/" <> item.slug)),
                  ])
                }),
              ),
            ])
          wisp.json_response(json.to_string(body), 200)
        }
        Error(_) -> server_error()
      }
  }
}

pub fn claim_links(req: Request, conn: db.Conn) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_json(req)

  case require_user(req, conn) {
    Error(_) -> unauthorized()
    Ok(user_id) ->
      case decode.run(body, claim_decoder()) {
        Error(_) -> bad_request("invalid request body")
        Ok(pairs) -> {
          let claimed =
            list.fold(pairs, 0, fn(count, pair) {
              case links.claim_ownership(pair.slug, pair.secret, user_id, conn) {
                True -> count + 1
                False -> count
              }
            })
          let body = json.object([#("claimed", json.int(claimed))])
          wisp.json_response(json.to_string(body), 200)
        }
      }
  }
}

pub fn require_user(req: Request, conn: db.Conn) -> Result(Int, Nil) {
  case session_token(req) {
    None -> Error(Nil)
    Some(token) ->
      case sessions.user_id(token, conn) {
        Ok(id) -> Ok(id)
        Error(_) -> Error(Nil)
      }
  }
}

fn session_token(req: Request) -> Option(String) {
  cookies.read(req, cookies.session_cookie)
}

type ClaimPair {
  ClaimPair(slug: String, secret: String)
}

fn credentials_decoder() -> decode.Decoder(#(String, String)) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(#(email, password))
}

fn claim_decoder() -> decode.Decoder(List(ClaimPair)) {
  use pairs <- decode.field("pairs", decode.list(pair_decoder()))
  decode.success(pairs)
}

fn pair_decoder() -> decode.Decoder(ClaimPair) {
  use slug <- decode.field("slug", decode.string)
  use secret <- decode.field("secret", decode.string)
  decode.success(ClaimPair(slug:, secret:))
}

fn created_user(user: users.User) -> Response {
  let body = user_json(user)
  wisp.json_response(body, 201)
}

fn user_json(user: users.User) -> String {
  json.object([
    #("email", json.string(user.email)),
    #("id", json.int(user.id)),
  ])
  |> json.to_string
}

fn bad_request(message: String) -> Response {
  error_json(400, message)
}

fn conflict(message: String) -> Response {
  error_json(409, message)
}

fn unauthorized() -> Response {
  error_json(401, "unauthorized")
}

fn server_error() -> Response {
  error_json(500, "internal error")
}

fn error_json(status: Int, message: String) -> Response {
  let body = json.object([#("error", json.string(message))])
  wisp.json_response(json.to_string(body), status)
}
