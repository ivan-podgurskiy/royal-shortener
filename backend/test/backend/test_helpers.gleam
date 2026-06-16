//// Helpers for building wisp requests in integration tests.

import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/list
import gleam/string
import gleam/uri
import wisp
import wisp/internal

pub fn get(path: String) -> wisp.Request {
  let #(path_only, query) = split_query(path)
  let reader = fn(_size) { Ok(internal.ReadingFinished) }
  let conn = internal.make_connection(reader, "test-secret")
  request.new()
  |> request.set_method(http.Get)
  |> request.set_path(path_only)
  |> request.set_query(query)
  |> request.set_body(conn)
}

pub fn post_json(path: String, json: String) -> wisp.Request {
  let #(path_only, query) = split_query(path)
  let body = bit_array.from_string(json)
  let reader = fn(_size) {
    Ok(internal.Chunk(body, fn(_size) { Ok(internal.ReadingFinished) }))
  }
  let conn = internal.make_connection(reader, "test-secret")
  request.new()
  |> request.set_method(http.Post)
  |> request.set_path(path_only)
  |> request.set_query(query)
  |> request.set_header("content-type", "application/json")
  |> request.set_body(conn)
}

fn split_query(path: String) -> #(String, List(#(String, String))) {
  case string.split_once(path, on: "?") {
    Ok(#(path_only, query)) ->
      case uri.parse_query(query) {
        Ok(pairs) -> #(path_only, pairs)
        Error(_) -> #(path_only, [])
      }
    Error(_) -> #(path, [])
  }
}

pub fn status(resp: wisp.Response) -> Int {
  resp.status
}

pub fn header(resp: wisp.Response, name: String) -> String {
  case list.key_find(resp.headers, name) {
    Ok(value) -> value
    Error(_) -> ""
  }
}

pub fn string_body(resp: wisp.Response) -> Result(String, Nil) {
  case resp.body {
    wisp.Text(text) -> Ok(text)
    _ -> Error(Nil)
  }
}

pub fn with_cookie(req: wisp.Request, set_cookie: String) -> wisp.Request {
  let cookie = extract_cookie_value(set_cookie)
  request.set_header(req, "cookie", cookie)
}

fn extract_cookie_value(set_cookie: String) -> String {
  case string.split(set_cookie, on: ";") {
    [first, ..] -> string.trim(first)
    [] -> set_cookie
  }
}
