//// Royal Shortener — entry point: state (Model), logic (init/update/shorten)
//// and wiring (main). The view markup lives in `royal/view`.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import lustre
import lustre/effect.{type Effect}
import royal/api
import royal/data
import royal/ffi
import royal/format
import royal/types
import royal/view

// INIT ------------------------------------------------------------------------

fn init(_flags) -> #(types.Model, Effect(types.Msg)) {
  let page = parse_page(ffi.app_page())
  let stats_slug = case ffi.stats_page_slug() {
    "" -> option.None
    slug -> option.Some(slug)
  }
  let stats_secret = case ffi.stats_page_secret() {
    "" -> option.None
    secret -> option.Some(secret)
  }
  let model =
    types.Model(
      origin: ffi.short_link_origin(),
      page:,
      url: format.strip_scheme(data.slides_url),
      phase: types.Idle,
      result: option.None,
      ledger: [],
      copied: option.None,
      error: option.None,
      expiry: types.Never,
      click_limit: "",
      stats_slug:,
      stats_secret:,
      stats: option.None,
      stats_error: option.None,
      stats_loading: page == types.Stats && option.is_some(stats_slug),
      auth_email: "",
      auth_password: "",
      auth_error: option.None,
      auth_loading: False,
      user: option.None,
      dashboard_links: [],
      dashboard_loading: page == types.Dashboard,
      dashboard_error: option.None,
    )
  let effects =
    case page {
      types.Stats -> load_stats_effect(stats_slug, stats_secret)
      types.Dashboard -> load_dashboard()
      _ -> effect.none()
    }
  #(model, effects)
}

fn parse_page(name: String) -> types.Page {
  case name {
    "login" -> types.Login
    "signup" -> types.Signup
    "dashboard" -> types.Dashboard
    "stats" -> types.Stats
    _ -> types.Home
  }
}

fn load_stats_effect(
  slug: option.Option(String),
  secret: option.Option(String),
) -> Effect(types.Msg) {
  case slug, secret {
    option.Some(s), option.Some(token) ->
      api.fetch_stats(s, token, fn(result) {
        case result {
          Ok(stats) -> types.StatsLoaded(stats)
          Error(e) -> types.StatsFailed(e)
        }
      })
    _, _ -> effect.none()
  }
}

fn load_dashboard() -> Effect(types.Msg) {
  api.fetch_my_links(fn(result) {
    case result {
      Ok(links) -> types.DashboardLinksLoaded(links)
      Error(e) -> types.DashboardLinksFailed(auth_error_text(e))
    }
  })
}

fn parse_pending_claims(raw: String) -> List(api.ClaimPair) {
  json.parse(raw, decode.list(api.claim_pair_decoder()))
  |> result.unwrap([])
}

fn post_auth_effects(pairs: List(api.ClaimPair)) -> Effect(types.Msg) {
  case pairs {
    [] -> load_dashboard()
    _ ->
      api.claim_links(pairs, fn(result) {
        case result {
          Ok(_) -> types.ClaimDone
          Error(_) -> types.ClaimDone
        }
      })
  }
}

// UPDATE ----------------------------------------------------------------------

fn update(model: types.Model, msg: types.Msg) -> #(types.Model, Effect(types.Msg)) {
  case msg {
    types.UrlChanged(value) -> #(
      types.Model(..model, url: format.strip_scheme(value), error: option.None),
      effect.none(),
    )

    types.ExpiryChanged(value) -> #(
      types.Model(..model, expiry: parse_expiry(value), error: option.None),
      effect.none(),
    )

    types.ClickLimitChanged(value) -> #(
      types.Model(..model, click_limit: value, error: option.None),
      effect.none(),
    )

    types.KeyPressed("Enter") -> submit_primary(model)
    types.KeyPressed(_) -> #(model, effect.none())

    types.ShortenClicked -> shorten(model)

    types.MintSucceeded(minted) -> {
      ffi.save_pending_claim(minted.slug, minted.secret)
      let long_text = format.strip_scheme(model.url)
      let result =
        types.Minted(
          slug: minted.slug,
          short_url: minted.short_url,
          secret: minted.secret,
          long_text: long_text,
          title: format.derive_title(long_text),
          expiry: model.expiry,
          click_limit: parsed_click_limit(model.click_limit),
        )
      #(
        types.Model(
          ..model,
          phase: types.Animating,
          result: option.Some(result),
        ),
        after(800, types.AnimationDone),
      )
    }

    types.MintFailed(err) -> #(
      types.Model(
        ..model,
        phase: types.Idle,
        error: option.Some(error_text(err)),
      ),
      effect.none(),
    )

    types.AnimationDone ->
      case model.result {
        option.Some(r) -> {
          let entry = types.LedgerItem(r.slug, r.long_text, 0)
          let ledger = list.take([entry, ..model.ledger], 6)
          #(
            types.Model(..model, phase: types.Done, ledger: ledger),
            effect.none(),
          )
        }
        option.None -> #(types.Model(..model, phase: types.Done), effect.none())
      }

    types.ResetClicked -> #(
      types.Model(
        ..model,
        phase: types.Idle,
        result: option.None,
        url: "",
        error: option.None,
      ),
      effect.none(),
    )

    types.CopyClicked(slug, text) -> {
      ffi.copy_text(text)
      #(
        types.Model(..model, copied: option.Some(slug)),
        after(1800, types.CopyCleared),
      )
    }

    types.CopyCleared -> #(
      types.Model(..model, copied: option.None),
      effect.none(),
    )

    types.StatsLoaded(stats) -> #(
      types.Model(
        ..model,
        stats: option.Some(stats),
        stats_loading: False,
        stats_error: option.None,
      ),
      effect.none(),
    )

    types.StatsFailed(err) -> #(
      types.Model(
        ..model,
        stats_loading: False,
        stats_error: option.Some(stats_error_text(err)),
      ),
      effect.none(),
    )

    types.AuthEmailChanged(value) -> #(
      types.Model(..model, auth_email: value, auth_error: option.None),
      effect.none(),
    )

    types.AuthPasswordChanged(value) -> #(
      types.Model(..model, auth_password: value, auth_error: option.None),
      effect.none(),
    )

    types.SignupClicked -> auth_submit(model, api.signup)

    types.LoginClicked -> auth_submit(model, api.login)

    types.LogoutClicked -> #(
      types.Model(..model, auth_loading: True),
      api.logout(fn(_) { types.LogoutDone }),
    )

    types.LogoutDone -> #(
      types.Model(
        ..model,
        user: option.None,
        auth_loading: False,
        auth_error: option.None,
        auth_password: "",
        dashboard_links: [],
        dashboard_loading: False,
        dashboard_error: option.None,
        page: types.Home,
      ),
      effect.none(),
    )

    types.AuthSucceeded(user) -> {
      let pairs = parse_pending_claims(ffi.load_pending_claims_json())
      #(
        types.Model(
          ..model,
          user: option.Some(user),
          auth_loading: False,
          auth_error: option.None,
          auth_password: "",
          page: types.Dashboard,
          dashboard_loading: True,
        ),
        post_auth_effects(pairs),
      )
    }

    types.AuthFailed(message) -> #(
      types.Model(
        ..model,
        auth_loading: False,
        auth_error: case message {
          "" -> option.None
          _ -> option.Some(message)
        },
        user: option.None,
      ),
      effect.none(),
    )

    types.ClaimDone -> {
      ffi.clear_pending_claims()
      #(
        types.Model(..model, dashboard_loading: True),
        load_dashboard(),
      )
    }

    types.DashboardLinksLoaded(links) -> #(
      types.Model(
        ..model,
        dashboard_links: links,
        dashboard_loading: False,
        dashboard_error: option.None,
      ),
      effect.none(),
    )

    types.DashboardLinksFailed(message) -> #(
      types.Model(
        ..model,
        dashboard_loading: False,
        dashboard_error: option.Some(message),
        user: option.None,
      ),
      effect.none(),
    )
  }
}

fn auth_submit(
  model: types.Model,
  submit: fn(String, String, fn(Result(api.User, api.ApiError)) -> types.Msg) ->
    Effect(types.Msg),
) -> #(types.Model, Effect(types.Msg)) {
  let email = string.trim(model.auth_email)
  let password = model.auth_password
  case email, password {
    "", _ | _, "" -> #(
      types.Model(
        ..model,
        auth_error: option.Some("Email and password are required."),
      ),
      effect.none(),
    )
    _, _ ->
      #(
        types.Model(..model, auth_loading: True, auth_error: option.None),
        submit(email, password, fn(result) {
          case result {
            Ok(user) -> types.AuthSucceeded(user)
            Error(e) -> types.AuthFailed(auth_error_text(e))
          }
        }),
      )
  }
}

fn submit_primary(model: types.Model) -> #(types.Model, Effect(types.Msg)) {
  case model.page {
    types.Login -> auth_submit(model, api.login)
    types.Signup -> auth_submit(model, api.signup)
    _ -> shorten(model)
  }
}

fn shorten(model: types.Model) -> #(types.Model, Effect(types.Msg)) {
  case model.phase {
    types.Animating -> #(model, effect.none())
    _ -> {
      let raw = string.trim(model.url)
      case raw {
        "" -> #(model, effect.none())
        _ ->
          case parsed_click_limit(model.click_limit) {
            option.Some(n) if n < 1 ->
              #(
                types.Model(
                  ..model,
                  error: option.Some("Click limit must be at least 1."),
                ),
                effect.none(),
              )
            _ -> {
              let url = ensure_scheme(raw)
              let effect =
                api.create_link(
                  api.CreateOptions(
                    url: url,
                    slug: option.None,
                    expires_in: expiry_to_api(model.expiry),
                    click_limit: parsed_click_limit(model.click_limit),
                  ),
                  fn(result) {
                    case result {
                      Ok(m) -> types.MintSucceeded(m)
                      Error(e) -> types.MintFailed(e)
                    }
                  },
                )
              #(
                types.Model(..model, phase: types.Animating, error: option.None),
                effect,
              )
            }
          }
      }
    }
  }
}

fn parse_expiry(value: String) -> types.ExpiryPreset {
  case value {
    "1h" -> types.OneHour
    "24h" -> types.OneDay
    "7d" -> types.SevenDays
    _ -> types.Never
  }
}

fn expiry_to_api(preset: types.ExpiryPreset) -> option.Option(String) {
  case preset {
    types.Never -> option.None
    types.OneHour -> option.Some("1h")
    types.OneDay -> option.Some("24h")
    types.SevenDays -> option.Some("7d")
  }
}

fn parsed_click_limit(input: String) -> option.Option(Int) {
  let trimmed = string.trim(input)
  case trimmed {
    "" -> option.None
    _ ->
      case int.parse(trimmed) {
        Ok(n) -> option.Some(n)
        Error(_) -> option.None
      }
  }
}

fn ensure_scheme(input: String) -> String {
  case
    string.starts_with(input, "http://") || string.starts_with(input, "https://")
  {
    True -> input
    False -> "https://" <> input
  }
}

fn error_text(err: api.ApiError) -> String {
  case err {
    api.Network(msg) -> "Network error: " <> msg
    api.Conflict -> "That title is taken — choose another."
    api.BadRequest(msg) -> msg
    api.Forbidden -> "That management key does not match this link."
    api.Server(msg) -> "The realm is briefly indisposed: " <> msg
  }
}

fn auth_error_text(err: api.ApiError) -> String {
  case err {
    api.Conflict -> "That email is already registered."
    api.BadRequest(msg) -> msg
    api.Forbidden -> "Please sign in to continue."
    _ -> error_text(err)
  }
}

fn stats_error_text(err: api.ApiError) -> String {
  case err {
    api.Forbidden ->
      "The management key is missing or incorrect. Open this page from the link you received when the URL was minted."
    _ -> error_text(err)
  }
}

fn after(ms: Int, msg: types.Msg) -> Effect(types.Msg) {
  effect.from(fn(dispatch) { ffi.after(ms, fn() { dispatch(msg) }) })
}

// MAIN ------------------------------------------------------------------------

pub fn main() -> Nil {
  ffi.handoff_short_link_if_needed()
  let app = lustre.application(init, update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
