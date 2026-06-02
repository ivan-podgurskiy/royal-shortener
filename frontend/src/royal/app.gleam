//// Royal Shortener — entry point: state (Model), logic (init/update/shorten)
//// and wiring (main). The view markup lives in `royal/view`.

import gleam/list
import gleam/option
import gleam/string
import lustre
import lustre/effect.{type Effect}
import royal/data
import royal/ffi
import royal/format
import royal/types
import royal/view

// INIT ------------------------------------------------------------------------

fn init(_flags) -> #(types.Model, Effect(types.Msg)) {
  let model =
    types.Model(
      url: format.strip_scheme(data.slides_url),
      phase: types.Idle,
      result: option.None,
      ledger: [],
      copied: option.None,
    )
  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

fn update(model: types.Model, msg: types.Msg) -> #(types.Model, Effect(types.Msg)) {
  case msg {
    types.UrlChanged(value) -> #(
      types.Model(..model, url: format.strip_scheme(value)),
      effect.none(),
    )

    types.KeyPressed("Enter") -> shorten(model)
    types.KeyPressed(_) -> #(model, effect.none())

    types.ShortenClicked -> shorten(model)

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
      types.Model(..model, phase: types.Idle, result: option.None, url: ""),
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
  }
}

fn shorten(model: types.Model) -> #(types.Model, Effect(types.Msg)) {
  case model.phase {
    types.Animating -> #(model, effect.none())
    _ -> {
      let raw = string.trim(model.url)
      case raw {
        "" -> #(model, effect.none())
        _ -> {
          let long_text = format.strip_scheme(raw)
          let result =
            types.Minted(
              slug: data.random_slug(),
              long_text: long_text,
              title: format.derive_title(long_text),
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
      }
    }
  }
}

fn after(ms: Int, msg: types.Msg) -> Effect(types.Msg) {
  effect.from(fn(dispatch) { ffi.after(ms, fn() { dispatch(msg) }) })
}

// MAIN ------------------------------------------------------------------------

pub fn main() -> Nil {
  let app = lustre.application(init, update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
