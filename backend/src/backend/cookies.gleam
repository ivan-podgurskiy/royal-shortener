//// Minimal cookie parsing and Set-Cookie helpers.

import gleam/http/response
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import wisp.{type Request, type Response}

pub const session_cookie = "royal_session"

pub fn read(req: Request, name: String) -> Option(String) {
  case list.key_find(req.headers, "cookie") {
    Error(_) -> None
    Ok(header) -> parse_cookie_header(header, name)
  }
}

pub fn set_session(resp: Response, token: String, max_age: Int) -> Response {
  let value =
    session_cookie
    <> "="
    <> token
    <> "; Path=/; HttpOnly; SameSite=Lax; Max-Age="
    <> int.to_string(max_age)

  response.prepend_header(resp, "set-cookie", value)
}

pub fn clear_session(resp: Response) -> Response {
  let value = session_cookie <> "=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0"
  response.prepend_header(resp, "set-cookie", value)
}

fn parse_cookie_header(header: String, name: String) -> Option(String) {
  case
    header
    |> string.split(";")
    |> list.filter_map(fn(part) {
      let part = string.trim(part)
      case string.split_once(part, on: "=") {
        Ok(#(key, value)) ->
          case key == name {
            True -> Ok(value)
            False -> Error(Nil)
          }
        Error(_) -> Error(Nil)
      }
    })
    |> list.first
  {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}
