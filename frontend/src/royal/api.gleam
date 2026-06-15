//// HTTP client for the Royal Shortener backend API.

import gleam/dynamic/decode
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/effect.{type Effect}
import rsvp

pub type Minted {
  Minted(slug: String, short_url: String, secret: String)
}

pub type ApiError {
  Network(String)
  Conflict
  BadRequest(String)
  Forbidden
  Server(String)
}

pub type CountRow {
  CountRow(label: String, count: Int)
}

pub type BucketRow {
  BucketRow(at: Int, count: Int)
}

pub type LinkStats {
  LinkStats(
    total: Int,
    by_country: List(CountRow),
    by_device: List(CountRow),
    hourly: List(BucketRow),
    daily: List(BucketRow),
  )
}

pub type CreateOptions {
  CreateOptions(
    url: String,
    slug: Option(String),
    expires_in: Option(String),
    click_limit: Option(Int),
  )
}

pub fn minted_decoder() -> decode.Decoder(Minted) {
  use slug <- decode.field("slug", decode.string)
  use short_url <- decode.field("short_url", decode.string)
  use secret <- decode.field("secret", decode.string)
  decode.success(Minted(slug, short_url, secret))
}

pub fn create_link(
  options: CreateOptions,
  on_response: fn(Result(Minted, ApiError)) -> msg,
) -> Effect(msg) {
  let fields = build_fields(options)
  let body = json.object(fields)

  rsvp.post(
    "/api/links",
    body,
    rsvp.expect_any_response(fn(result) {
      case result {
        Ok(resp) -> on_response(interpret_create(resp))
        Error(e) -> on_response(Error(network_error(e)))
      }
    }),
  )
}

pub fn fetch_stats(
  slug: String,
  secret: String,
  on_response: fn(Result(LinkStats, ApiError)) -> msg,
) -> Effect(msg) {
  let path =
    "/api/links/"
    <> slug
    <> "/stats?secret="
    <> string.replace(secret, "#", "%23")

  rsvp.get(
    path,
    rsvp.expect_any_response(fn(result) {
      case result {
        Ok(resp) -> on_response(interpret_stats(resp))
        Error(e) -> on_response(Error(network_error(e)))
      }
    }),
  )
}

pub fn stats_decoder() -> decode.Decoder(LinkStats) {
  use total <- decode.field("total", decode.int)
  use by_country <- decode.field("by_country", decode.list(count_row_decoder()))
  use by_device <- decode.field("by_device", decode.list(count_row_decoder()))
  use hourly <- decode.field("hourly", decode.list(bucket_row_decoder()))
  use daily <- decode.field("daily", decode.list(bucket_row_decoder()))
  decode.success(LinkStats(
    total:,
    by_country:,
    by_device:,
    hourly:,
    daily:,
  ))
}

fn count_row_decoder() -> decode.Decoder(CountRow) {
  use label <- decode.field("label", decode.string)
  use count <- decode.field("count", decode.int)
  decode.success(CountRow(label:, count:))
}

fn bucket_row_decoder() -> decode.Decoder(BucketRow) {
  use at <- decode.field("at", decode.int)
  use count <- decode.field("count", decode.int)
  decode.success(BucketRow(at:, count:))
}

fn build_fields(options: CreateOptions) -> List(#(String, json.Json)) {
  let base = [#("url", json.string(options.url))]
  let with_slug = case options.slug {
    Some(s) -> [#("slug", json.string(s)), ..base]
    None -> base
  }
  let with_expiry = case options.expires_in {
    Some(value) -> [#("expires_in", json.string(value)), ..with_slug]
    None -> with_slug
  }
  case options.click_limit {
    Some(n) -> [#("click_limit", json.int(n)), ..with_expiry]
    None -> with_expiry
  }
}

fn interpret_create(resp: Response(String)) -> Result(Minted, ApiError) {
  case resp.status {
    201 ->
      json.parse(resp.body, minted_decoder())
      |> result.map_error(fn(_) { Server("bad response body") })
    400 -> Error(BadRequest(error_message(resp.body)))
    409 -> Error(Conflict)
    _ -> Error(Server("status " <> int.to_string(resp.status)))
  }
}

fn interpret_stats(resp: Response(String)) -> Result(LinkStats, ApiError) {
  case resp.status {
    200 ->
      json.parse(resp.body, stats_decoder())
      |> result.map_error(fn(_) { Server("bad response body") })
    403 -> Error(Forbidden)
    404 -> Error(BadRequest("link not found"))
    _ -> Error(Server("status " <> int.to_string(resp.status)))
  }
}

fn error_message(body: String) -> String {
  let decoder = {
    use msg <- decode.field("error", decode.string)
    decode.success(msg)
  }
  case json.parse(body, decoder) {
    Ok(m) -> m
    Error(_) -> "bad request"
  }
}

fn network_error(e: rsvp.Error) -> ApiError {
  case e {
    rsvp.NetworkError -> Network("network error")
    rsvp.BadUrl(url) -> Network("bad url: " <> url)
    rsvp.HttpError(resp) -> Server("status " <> int.to_string(resp.status))
    _ -> Network("request failed")
  }
}
