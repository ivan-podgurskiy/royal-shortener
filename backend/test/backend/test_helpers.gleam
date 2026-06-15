//// Helpers for building wisp requests in integration tests.

import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/list
import wisp
import wisp/internal

pub fn get(path: String) -> wisp.Request {
  let reader = fn(_size) { Ok(internal.ReadingFinished) }
  let conn = internal.make_connection(reader, "test-secret")
  request.new()
  |> request.set_method(http.Get)
  |> request.set_path(path)
  |> request.set_body(conn)
}

pub fn post_json(path: String, json: String) -> wisp.Request {
  let body = bit_array.from_string(json)
  let reader = fn(_size) {
    Ok(internal.Chunk(body, fn(_size) { Ok(internal.ReadingFinished) }))
  }
  let conn = internal.make_connection(reader, "test-secret")
  request.new()
  |> request.set_method(http.Post)
  |> request.set_path(path)
  |> request.set_header("content-type", "application/json")
  |> request.set_body(conn)
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
