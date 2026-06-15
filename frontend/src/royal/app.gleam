//// Royal Shortener — entry point: state (Model), logic (init/update/shorten)
//// and wiring (main). The view markup lives in `royal/view`.

import gleam/int
import gleam/list
import gleam/option
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
      stats_loading: option.is_some(stats_slug),
    )
  #(model, load_stats_effect(stats_slug, stats_secret))
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

    types.KeyPressed("Enter") -> shorten(model)
    types.KeyPressed(_) -> #(model, effect.none())

    types.ShortenClicked -> shorten(model)

    types.MintSucceeded(minted) -> {
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
