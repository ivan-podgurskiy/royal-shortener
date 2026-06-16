//// HTTP client for the Royal Shortener backend API.

import gleam/dynamic/decode
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/effect.{type Effect}
import royal/ffi
import rsvp

pub type User {
  User(id: Int, email: String)
}

pub type DashboardLink {
  DashboardLink(
    slug: String,
    target_url: String,
    click_count: Int,
    created_at: Int,
    short_url: String,
  )
}

pub type ClaimPair {
  ClaimPair(slug: String, secret: String)
}

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

pub fn signup(
  email: String,
  password: String,
  on_response: fn(Result(User, ApiError)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])
  cred_post("/api/auth/signup", json.to_string(body), fn(status, resp_body) {
    on_response(interpret_user(status, resp_body))
  })
}

pub fn login(
  email: String,
  password: String,
  on_response: fn(Result(User, ApiError)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
      ])
  cred_post("/api/auth/login", json.to_string(body), fn(status, resp_body) {
    on_response(interpret_user(status, resp_body))
  })
}

pub fn logout(on_done: fn(Nil) -> msg) -> Effect(msg) {
  cred_post("/api/auth/logout", "{}", fn(_status, _body) { on_done(Nil) })
}

pub fn fetch_my_links(
  on_response: fn(Result(List(DashboardLink), ApiError)) -> msg,
) -> Effect(msg) {
  cred_get("/api/me/links", fn(status, resp_body) {
    on_response(interpret_dashboard_links(status, resp_body))
  })
}

pub fn claim_links(
  pairs: List(ClaimPair),
  on_response: fn(Result(Int, ApiError)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #(
        "pairs",
        json.array(pairs, fn(pair) {
          json.object([
            #("slug", json.string(pair.slug)),
            #("secret", json.string(pair.secret)),
          ])
        }),
      ),
    ])
  cred_post("/api/me/claim-links", json.to_string(body), fn(status, resp_body) {
    on_response(interpret_claimed(status, resp_body))
  })
}

pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use email <- decode.field("email", decode.string)
  decode.success(User(id:, email:))
}

pub fn dashboard_link_decoder() -> decode.Decoder(DashboardLink) {
  use slug <- decode.field("slug", decode.string)
  use target_url <- decode.field("target_url", decode.string)
  use click_count <- decode.field("click_count", decode.int)
  use created_at <- decode.field("created_at", decode.int)
  use short_url <- decode.field("short_url", decode.string)
  decode.success(DashboardLink(
    slug:,
    target_url:,
    click_count:,
    created_at:,
    short_url:,
  ))
}

pub fn claim_pair_decoder() -> decode.Decoder(ClaimPair) {
  use slug <- decode.field("slug", decode.string)
  use secret <- decode.field("secret", decode.string)
  decode.success(ClaimPair(slug:, secret:))
}

fn cred_post(
  path: String,
  body: String,
  handler: fn(Int, String) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    ffi.post_json_cred(path, body, fn(status, resp_body) {
      dispatch(handler(status, resp_body))
    })
  })
}

fn cred_get(path: String, handler: fn(Int, String) -> msg) -> Effect(msg) {
  effect.from(fn(dispatch) {
    ffi.get_cred(path, fn(status, resp_body) {
      dispatch(handler(status, resp_body))
    })
  })
}

fn interpret_user(status: Int, body: String) -> Result(User, ApiError) {
  case status {
    200 | 201 ->
      json.parse(body, user_decoder())
      |> result.map_error(fn(_) { Server("bad response body") })
    400 -> Error(BadRequest(error_message(body)))
    409 -> Error(Conflict)
    401 -> Error(Forbidden)
    0 -> Error(Network("network error"))
    _ -> Error(Server("status " <> int.to_string(status)))
  }
}

fn interpret_dashboard_links(
  status: Int,
  body: String,
) -> Result(List(DashboardLink), ApiError) {
  case status {
    200 -> {
      let decoder = {
        use links <- decode.field("links", decode.list(dashboard_link_decoder()))
        decode.success(links)
      }
      json.parse(body, decoder)
      |> result.map_error(fn(_) { Server("bad response body") })
    }
    401 -> Error(Forbidden)
    0 -> Error(Network("network error"))
    _ -> Error(Server("status " <> int.to_string(status)))
  }
}

fn interpret_claimed(status: Int, body: String) -> Result(Int, ApiError) {
  case status {
    200 -> {
      let decoder = {
        use claimed <- decode.field("claimed", decode.int)
        decode.success(claimed)
      }
      json.parse(body, decoder)
      |> result.map_error(fn(_) { Server("bad response body") })
    }
    401 -> Error(Forbidden)
    0 -> Error(Network("network error"))
    _ -> Error(Server("status " <> int.to_string(status)))
  }
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
