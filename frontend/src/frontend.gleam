//// Royal Shortener — a faithful Lustre port of the "Royal Shortener UI"
//// React prototype. Renders the full landing page (nav, hero, interactive
//// shortener, privileges, decree, call-to-action and footer) and mints royal
//// links entirely on the client.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute.{type Attribute, attribute} as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import royal/data
import royal/ffi
import royal/icons
import royal/styles

// MODEL -----------------------------------------------------------------------

pub type Phase {
  Idle
  Animating
  Done
}

pub type Minted {
  Minted(slug: String, long_text: String, title: String)
}

pub type LedgerItem {
  LedgerItem(slug: String, long_text: String, clicks: Int)
}

pub type Model {
  Model(
    url: String,
    phase: Phase,
    result: Option(Minted),
    ledger: List(LedgerItem),
    copied: Option(String),
  )
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      url: strip_scheme(data.slides_url),
      phase: Idle,
      result: None,
      ledger: [
        LedgerItem(
          "Sovereign-7qz",
          "annualreport.example-crown.com/2026/q1/full-financial-disclosure",
          12_480,
        ),
        LedgerItem(
          "Coronet-m3x",
          "events.example.com/spring-gala/rsvp?guest=duchess&seat=head-table",
          3921,
        ),
      ],
      copied: None,
    )
  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UrlChanged(String)
  ShortenClicked
  KeyPressed(String)
  AnimationDone
  ResetClicked
  CopyClicked(slug: String, text: String)
  CopyCleared
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UrlChanged(value) -> #(Model(..model, url: strip_scheme(value)), effect.none())

    KeyPressed("Enter") -> shorten(model)
    KeyPressed(_) -> #(model, effect.none())

    ShortenClicked -> shorten(model)

    AnimationDone ->
      case model.result {
        Some(r) -> {
          let entry = LedgerItem(r.slug, r.long_text, 0)
          let ledger = list.take([entry, ..model.ledger], 6)
          #(Model(..model, phase: Done, ledger: ledger), effect.none())
        }
        None -> #(Model(..model, phase: Done), effect.none())
      }

    ResetClicked -> #(
      Model(..model, phase: Idle, result: None, url: ""),
      effect.none(),
    )

    CopyClicked(slug, text) -> {
      ffi.copy_text(text)
      #(Model(..model, copied: Some(slug)), after(1800, CopyCleared))
    }

    CopyCleared -> #(Model(..model, copied: None), effect.none())
  }
}

fn shorten(model: Model) -> #(Model, Effect(Msg)) {
  case model.phase {
    Animating -> #(model, effect.none())
    _ -> {
      let raw = string.trim(model.url)
      case raw {
        "" -> #(model, effect.none())
        _ -> {
          let long_text = strip_scheme(raw)
          let result =
            Minted(
              slug: data.random_slug(),
              long_text: long_text,
              title: derive_title(long_text),
            )
          #(
            Model(..model, phase: Animating, result: Some(result)),
            after(800, AnimationDone),
          )
        }
      }
    }
  }
}

fn after(ms: Int, msg: Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) { ffi.after(ms, fn() { dispatch(msg) }) })
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  html.div(
    [
      attr.class("royal-root"),
      attribute("data-theme", "navy"),
      attribute("data-ornament", "on"),
      attribute("data-glow", "on"),
    ],
    [
      html.style([], styles.css),
      html.style([], extra_css),
      html.div([attr.class("royal-bg")], []),
      html.div([attr.class("royal-shell")], [nav(), hero(model)]),
      features_section(),
      decree(),
      cta(),
      footer(),
    ],
  )
}

fn nav() -> Element(Msg) {
  html.nav([attr.class("nav")], [
    html.div([attr.class("brand")], [
      icons.crown_mark(32),
      html.span([attr.class("wordmark")], [
        element.text("Royal "),
        html.b([], [element.text("Shortener")]),
      ]),
    ]),
    html.div([attr.class("nav-links")], [
      nav_link("#features", "Privileges"),
      nav_link("#ledger", "The Ledger"),
      nav_link("#pricing", "Patronage"),
      nav_link("#signin", "Sign in"),
      html.a(
        [
          attr.href("#start"),
          attr.class("btn btn-ghost"),
          attr.style("padding", "10px 20px"),
        ],
        [element.text("Request Audience")],
      ),
    ]),
  ])
}

fn nav_link(href: String, label: String) -> Element(Msg) {
  html.a([attr.href(href)], [element.text(label)])
}

fn hero(model: Model) -> Element(Msg) {
  html.header([attr.class("hero")], [
    html.div(
      [
        attr.class("watermark"),
        attribute(
          "style",
          "top:8%;left:50%;transform:translateX(-50%);animation:floatY 7s ease-in-out infinite",
        ),
      ],
      [icons.crown_mark(260)],
    ),
    html.div([attr.class("eyebrow")], [element.text("By Appointment to Your Links")]),
    html.h1([], [
      element.text("Long live the "),
      html.span([attr.class("gold-text")], [element.text("short")]),
      element.text(" link."),
    ]),
    html.p([attr.class("sub")], [
      element.text(
        "Royal Shortener takes sprawling, unworthy URLs and crowns them as elegant links — complete with analytics in the royal ledger, scannable wax seals, and titles of your own bestowing.",
      ),
    ]),
    shortener(model),
  ])
}

// SHORTENER -------------------------------------------------------------------

fn shortener(model: Model) -> Element(Msg) {
  html.div([attr.class("shortener")], [
    html.div([attr.class("panel")], [
      html.span([attr.class("corner tl")], []),
      html.span([attr.class("corner tr")], []),
      html.span([attr.class("corner bl")], []),
      html.span([attr.class("corner br")], []),
      html.div([attr.class("input-row")], [
        html.div([attr.class("input-wrap")], [
          html.span([attr.class("leadmark")], [element.text("https://")]),
          html.input([
            attr.class("url-input"),
            attr.value(model.url),
            attribute("spellcheck", "false"),
            attr.placeholder("paste a long, unworthy URL…"),
            event.on_input(UrlChanged),
            event.on_keydown(KeyPressed),
          ]),
        ]),
        html.button(shorten_button_attrs(model), [
          icons.ico_sparkle(),
          element.text(shorten_label(model)),
        ]),
      ]),
      html.div([attr.class("helper-row")], [
        html.span([attr.class("hint")], [
          element.text("Pre-filled with our "),
          html.b([], [element.text("pitch deck")]),
          element.text(" — press Shorten to watch it bow."),
        ]),
        html.span(
          [attr.class("hint mono"), attr.style("opacity", "0.7")],
          [element.text("royal.sh/…")],
        ),
      ]),
      html.div([attr.class(stage_class(model))], stage_children(model)),
    ]),
    ledger_view(model),
  ])
}

fn shorten_button_attrs(model: Model) -> List(Attribute(Msg)) {
  let base = [attr.class("btn btn-gold"), event.on_click(ShortenClicked)]
  case model.phase {
    Animating -> [attr.disabled(True), ..base]
    _ -> base
  }
}

fn shorten_label(model: Model) -> String {
  case model.phase {
    Animating -> "Ennobling…"
    _ -> "Shorten"
  }
}

fn stage_class(model: Model) -> String {
  case model.phase {
    Idle -> "stage"
    _ -> "stage open"
  }
}

fn stage_children(model: Model) -> List(Element(Msg)) {
  case model.phase, model.result {
    Animating, _ -> [
      html.div([attr.class("collapse-track")], [
        html.span([attr.class("long-url collapsing")], [
          element.text(animating_text(model)),
        ]),
        html.span([attr.class("flare popping")], []),
        html.span([attr.class("sweep")], []),
      ]),
    ]
    Done, Some(result) -> [result_card(model, result)]
    _, _ -> []
  }
}

fn animating_text(model: Model) -> String {
  case string.trim(model.url) {
    "" -> "your-very-long-url.example.com/path"
    text -> strip_scheme(text)
  }
}

fn result_card(model: Model, result: Minted) -> Element(Msg) {
  let is_copied = model.copied == Some(result.slug)
  let copy_text = "royal.sh/" <> result.slug
  html.div([attr.class("result rise")], [
    html.div([], [
      html.div([attr.class("short-line")], [
        html.span([attr.class("short mono")], [
          html.span([attr.class("dom")], [element.text("royal.sh/")]),
          html.span([attr.class("slug")], [element.text(result.slug)]),
        ]),
      ]),
      html.div([attr.class("meta")], [
        meta_item("Minted", "Just now"),
        meta_item("Clicks", "0"),
        meta_item("Title", result.title),
      ]),
      html.div([attr.class("result-actions")], [
        html.button(
          [
            attr.class(copy_button_class(is_copied)),
            event.on_click(CopyClicked(result.slug, copy_text)),
          ],
          [
            icons.ico_copy(),
            element.text(case is_copied {
              True -> " Sealed to clipboard"
              False -> " Copy link"
            }),
          ],
        ),
        html.button([attr.class("link-btn"), event.on_click(ResetClicked)], [
          element.text("Shorten another ↺"),
        ]),
      ]),
    ]),
    qr_seal(result.slug),
  ])
}

fn copy_button_class(is_copied: Bool) -> String {
  case is_copied {
    True -> "copy-btn copied"
    False -> "copy-btn"
  }
}

fn meta_item(key: String, value: String) -> Element(Msg) {
  html.div([attr.class("m")], [
    html.span([attr.class("k")], [element.text(key)]),
    html.span([attr.class("v")], [element.text(value)]),
  ])
}

fn qr_seal(seed: String) -> Element(Msg) {
  html.div(
    [attr.class("qr"), attribute("aria-hidden", "true")],
    list.map(data.make_qr(seed), fn(on) {
      case on {
        True -> html.i([], [])
        False -> html.i([attr.class("off")], [])
      }
    }),
  )
}

// LEDGER ----------------------------------------------------------------------

fn ledger_view(model: Model) -> Element(Msg) {
  case model.ledger {
    [] -> element.none()
    items ->
      html.div([attr.class("ledger"), attr.id("ledger")], [
        html.div([attr.class("ledger-head")], [
          html.span([], [element.text("The Royal Ledger")]),
          html.span([attr.class("rule")], []),
        ]),
        ..list.map(items, fn(item) { ledger_row(model, item) })
      ])
  }
}

fn ledger_row(model: Model, item: LedgerItem) -> Element(Msg) {
  let is_copied = model.copied == Some(item.slug)
  let copy_text = "royal.sh/" <> item.slug
  html.div([attr.class("ledger-row rise")], [
    html.div([attr.class("lr-left")], [
      html.span([attr.class("lr-short")], [
        element.text("royal.sh/" <> item.slug),
      ]),
      html.span([attr.class("lr-long")], [element.text(item.long_text)]),
    ]),
    html.div(
      [attribute("style", "display:flex;align-items:center;gap:16px")],
      [
        html.span([attr.class("lr-clicks")], [
          element.text(with_commas(item.clicks) <> " clicks"),
        ]),
        html.button(
          [attr.class("mini-copy"), event.on_click(CopyClicked(item.slug, copy_text))],
          [
            element.text(case is_copied {
              True -> "✓"
              False -> "Copy"
            }),
          ],
        ),
      ],
    ),
  ])
}

// FEATURES --------------------------------------------------------------------

fn features_section() -> Element(Msg) {
  html.section([attr.class("section"), attr.id("features")], [
    html.div([attr.class("royal-shell")], [
      html.div([attr.class("section-head")], [
        html.div(
          [attr.class("eyebrow solo"), attr.style("justify-content", "center")],
          [element.text("Privileges of the Crown")],
        ),
        html.h2([], [element.text("Power befitting a sovereign.")]),
        html.p([], [
          element.text(
            "Every link you mint arrives with the full estate — measured, sealed, titled, and guarded.",
          ),
        ]),
      ]),
      html.div(
        [attr.class("feature-grid")],
        list.map(data.features(), feature_card),
      ),
    ]),
  ])
}

fn feature_card(feature: data.Feature) -> Element(Msg) {
  html.div([attr.class("feature")], [
    html.span([attr.class("fnum")], [element.text(feature.num)]),
    html.div([attr.class("ficon")], [icons.feature_icon(feature.icon)]),
    html.h3([], [element.text(feature.title)]),
    html.p([], [element.text(feature.body)]),
  ])
}

// DECREE ----------------------------------------------------------------------

fn decree() -> Element(Msg) {
  html.section([attr.class("decree")], [
    html.div([attr.class("royal-shell")], [
      icons.flourish(),
      html.p([attr.class("quote")], [
        element.text("“A link, like a monarch, is judged by how it "),
        html.b([attr.class("gold-text")], [element.text("carries itself")]),
        element.text(".”"),
      ]),
      html.div([attr.class("attribution")], [
        element.text("— The Royal Shortener Charter, MMXXVI"),
      ]),
      html.div(
        [attr.class("stats"), attr.style("margin-top", "64px")],
        [
          stat("48", "M", "Links Knighted"),
          stat("1.2", "B", "Clicks Counted"),
          stat("99.99", "%", "Royal Uptime"),
        ],
      ),
    ]),
  ])
}

fn stat(value: String, suffix: String, label: String) -> Element(Msg) {
  html.div([attr.class("stat")], [
    html.div([attr.class("num")], [
      html.span([], [element.text(value)]),
      element.text(suffix),
    ]),
    html.div([attr.class("lab")], [element.text(label)]),
  ])
}

// CTA -------------------------------------------------------------------------

fn cta() -> Element(Msg) {
  html.section([attr.class("cta"), attr.id("start")], [
    html.div([attr.class("royal-shell")], [
      html.div([attr.class("cta-panel")], [
        html.div(
          [
            attr.class("watermark"),
            attribute("style", "top:-30%;right:-4%;opacity:0.06"),
          ],
          [icons.crown_mark(300)],
        ),
        html.div(
          [attr.class("eyebrow solo"), attr.style("justify-content", "center")],
          [element.text("Your Coronation Awaits")],
        ),
        html.h2([], [element.text("Ennoble your first link.")]),
        html.p([], [
          element.text(
            "Free to begin — no royal lineage required. Mint your first hundred links on the house.",
          ),
        ]),
        html.a(
          [
            attr.href("#"),
            attr.class("btn btn-gold"),
            attr.style("padding", "16px 34px"),
          ],
          [icons.ico_sparkle(), element.text(" Claim Your Throne")],
        ),
      ]),
    ]),
  ])
}

// FOOTER ----------------------------------------------------------------------

fn footer() -> Element(Msg) {
  html.footer([attr.class("footer")], [
    html.div([attr.class("royal-shell")], [
      html.div([attr.class("footer-top")], [
        html.div([attr.class("f-brand")], [
          html.div([attr.class("brand"), attr.style("margin-bottom", "4px")], [
            icons.crown_mark(28),
            html.span([attr.class("wordmark")], [
              element.text("Royal "),
              html.b([], [element.text("Shortener")]),
            ]),
          ]),
          html.p([], [
            element.text(
              "Links worthy of a crown. Shortened by royal decree since MMXXVI.",
            ),
          ]),
        ]),
        footer_col("The Realm", ["Shorten", "Analytics", "QR Seals", "Custom Domains"]),
        footer_col("The Court", ["About", "Patronage", "Charter", "Careers"]),
        footer_col("Decrees", ["Terms", "Privacy", "Status", "Contact the Court"]),
      ]),
      html.div([attr.class("footer-bottom")], [
        html.span([attr.class("copy")], [
          element.text("© MMXXVI Royal Shortener — all rights reserved by royal decree."),
        ]),
        html.span([attr.class("fleur")], [
          icons.diamond(6),
          icons.crown_mark(18),
          icons.diamond(6),
        ]),
      ]),
    ]),
  ])
}

fn footer_col(heading: String, links: List(String)) -> Element(Msg) {
  html.div(
    [attr.class("f-col")],
    [
      html.h5([], [element.text(heading)]),
      ..list.map(links, fn(label) {
        html.a([attr.href("#")], [element.text(label)])
      })
    ],
  )
}

// HELPERS ---------------------------------------------------------------------

fn strip_scheme(url: String) -> String {
  case string.starts_with(url, "https://") {
    True -> string.drop_start(url, 8)
    False ->
      case string.starts_with(url, "http://") {
        True -> string.drop_start(url, 7)
        False -> url
      }
  }
}

fn derive_title(host_path: String) -> String {
  let host = take_before(host_path, "/")
  let host = strip_www(host)
  let label = take_before(host, ".")
  capitalize(label)
}

fn take_before(value: String, separator: String) -> String {
  case string.split_once(value, separator) {
    Ok(#(before, _)) -> before
    Error(_) -> value
  }
}

fn strip_www(host: String) -> String {
  case string.starts_with(host, "www.") {
    True -> string.drop_start(host, 4)
    False -> host
  }
}

fn capitalize(value: String) -> String {
  case string.pop_grapheme(value) {
    Ok(#(first, rest)) -> string.uppercase(first) <> rest
    Error(_) -> value
  }
}

fn with_commas(n: Int) -> String {
  let digits = string.to_graphemes(int.to_string(n))
  list.reverse(digits)
  |> list.index_map(fn(digit, index) {
    case index > 0 && index % 3 == 0 {
      True -> digit <> ","
      False -> digit
    }
  })
  |> list.reverse
  |> string.concat
}

const extra_css = "
@keyframes collapseAway {
  0% { transform: scaleX(1); letter-spacing: 0px; filter: blur(0px); opacity: 1; }
  50% { transform: scaleX(0.55); letter-spacing: -1.5px; filter: blur(0.5px); opacity: 0.9; }
  100% { transform: scaleX(0.04); letter-spacing: -5px; filter: blur(4px); opacity: 0.15; }
}
.long-url.collapsing { animation: collapseAway 0.76s cubic-bezier(.7,0,.2,1) forwards; }
@keyframes flarePop {
  0% { transform: translate(-50%,-50%) scale(0); opacity: 0; }
  55% { transform: translate(-50%,-50%) scale(0.6); opacity: 0; }
  80% { transform: translate(-50%,-50%) scale(1.4); opacity: 1; }
  100% { transform: translate(-50%,-50%) scale(2.6); opacity: 0; }
}
.flare.popping { animation: flarePop 0.82s ease-out forwards; }
"

// MAIN ------------------------------------------------------------------------

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
