//// Royal Shortener — the full landing-page view and every view helper.

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute.{type Attribute, attribute} as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import royal/data
import royal/format
import royal/icons
import royal/styles
import royal/types

pub fn view(model: types.Model) -> Element(types.Msg) {
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

fn nav() -> Element(types.Msg) {
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
      // nav_link("#ledger", "The Ledger"),
      // nav_link("#pricing", "Patronage"),
      // nav_link("#signin", "Sign in"),
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

fn nav_link(href: String, label: String) -> Element(types.Msg) {
  html.a([attr.href(href)], [element.text(label)])
}

fn hero(model: types.Model) -> Element(types.Msg) {
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

fn shortener(model: types.Model) -> Element(types.Msg) {
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
            event.on_input(types.UrlChanged),
            event.on_keydown(types.KeyPressed),
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
          [element.text(format.short_prefix(model.origin) <> "…")],
        ),
      ]),
      protection_controls(model),
      error_banner(model),
      html.div([attr.class(stage_class(model))], stage_children(model)),
    ]),
    ledger_view(model),
  ])
}

fn shorten_button_attrs(model: types.Model) -> List(Attribute(types.Msg)) {
  let base = [attr.class("btn btn-gold"), event.on_click(types.ShortenClicked)]
  case model.phase {
    types.Animating -> [attr.disabled(True), ..base]
    _ -> base
  }
}

fn shorten_label(model: types.Model) -> String {
  case model.phase {
    types.Animating -> "Ennobling…"
    _ -> "Shorten"
  }
}

fn stage_class(model: types.Model) -> String {
  case model.phase {
    types.Idle -> "stage"
    _ -> "stage open"
  }
}

fn stage_children(model: types.Model) -> List(Element(types.Msg)) {
  case model.phase, model.result {
    types.Animating, _ -> [
      html.div([attr.class("collapse-track")], [
        html.span([attr.class("long-url collapsing")], [
          element.text(animating_text(model)),
        ]),
        html.span([attr.class("flare popping")], []),
        html.span([attr.class("sweep")], []),
      ]),
    ]
    types.Done, option.Some(result) -> [result_card(model, result)]
    _, _ -> []
  }
}

fn animating_text(model: types.Model) -> String {
  case string.trim(model.url) {
    "" -> "your-very-long-url.example.com/path"
    text -> format.strip_scheme(text)
  }
}

fn result_card(model: types.Model, result: types.Minted) -> Element(types.Msg) {
  let is_copied = model.copied == option.Some(result.slug)
  let copy_text = format.short_url(model.origin, result.slug)
  html.div([attr.class("result rise")], [
    html.div([], [
      html.div([attr.class("short-line")], [
        html.span([attr.class("short mono")], [
          html.span([attr.class("dom")], [
            element.text(format.short_prefix(model.origin)),
          ]),
          html.span([attr.class("slug")], [element.text(result.slug)]),
        ]),
      ]),
      html.div([attr.class("meta")], [
        meta_item("Minted", "Just now"),
        meta_item("Clicks", "0"),
        meta_item("Title", result.title),
        meta_item("Expires", expiry_label(result.expiry)),
        meta_item("Click limit", click_limit_label(result.click_limit)),
      ]),
      html.div([attr.class("secret-row")], [
        html.div([attr.class("k")], [element.text("Management key")]),
        html.code([attr.class("secret mono")], [element.text(result.secret)]),
        html.p([attr.class("hint")], [
          element.text(
            "Save this token. It is the only way to manage this link or view its stats without an account.",
          ),
        ]),
      ]),
      html.div([attr.class("result-actions")], [
        html.button(
          [
            attr.class(copy_button_class(is_copied)),
            event.on_click(types.CopyClicked(result.slug, copy_text)),
          ],
          [
            icons.ico_copy(),
            element.text(case is_copied {
              True -> " Sealed to clipboard"
              False -> " Copy link"
            }),
          ],
        ),
        html.a(
          [
            attr.href(qr_url(result.slug)),
            attr.download(result.slug <> "-qr.svg"),
            attr.class("copy-btn"),
          ],
          [element.text("Download QR")],
        ),
        html.button([attr.class("link-btn"), event.on_click(types.ResetClicked)], [
          element.text("Shorten another ↺"),
        ]),
      ]),
    ]),
    qr_image(model, result.slug),
  ])
}

fn copy_button_class(is_copied: Bool) -> String {
  case is_copied {
    True -> "copy-btn copied"
    False -> "copy-btn"
  }
}

fn meta_item(key: String, value: String) -> Element(types.Msg) {
  html.div([attr.class("m")], [
    html.span([attr.class("k")], [element.text(key)]),
    html.span([attr.class("v")], [element.text(value)]),
  ])
}

fn protection_controls(model: types.Model) -> Element(types.Msg) {
  html.div([attr.class("protection-row")], [
    html.label([attr.class("protection-field")], [
      html.span([attr.class("k")], [element.text("Expires in")]),
      html.select(
        [
          attr.class("protection-input"),
          event.on_change(types.ExpiryChanged),
        ],
        [
          expiry_option("never", "Never", model.expiry, types.Never),
          expiry_option("1h", "1 hour", model.expiry, types.OneHour),
          expiry_option("24h", "24 hours", model.expiry, types.OneDay),
          expiry_option("7d", "7 days", model.expiry, types.SevenDays),
        ],
      ),
    ]),
    html.label([attr.class("protection-field")], [
      html.span([attr.class("k")], [element.text("Click limit")]),
      html.input([
        attr.class("protection-input"),
        attr.type_("number"),
        attr.min("1"),
        attr.placeholder("Unlimited"),
        attr.value(model.click_limit),
        event.on_input(types.ClickLimitChanged),
      ]),
    ]),
  ])
}

fn expiry_option(
  value: String,
  label: String,
  selected: types.ExpiryPreset,
  preset: types.ExpiryPreset,
) -> Element(types.Msg) {
  html.option(
    [
      attr.value(value),
      attr.selected(selected == preset),
    ],
    label,
  )
}

fn expiry_label(preset: types.ExpiryPreset) -> String {
  case preset {
    types.Never -> "Never"
    types.OneHour -> "1 hour"
    types.OneDay -> "24 hours"
    types.SevenDays -> "7 days"
  }
}

fn click_limit_label(limit: option.Option(Int)) -> String {
  case limit {
    option.None -> "Unlimited"
    option.Some(n) -> int.to_string(n)
  }
}

fn error_banner(model: types.Model) -> Element(types.Msg) {
  case model.error {
    option.None -> element.none()
    option.Some(msg) ->
      html.div([attr.class("error-banner")], [element.text(msg)])
  }
}

fn qr_url(slug: String) -> String {
  "/api/links/" <> slug <> "/qr"
}

fn qr_image(model: types.Model, slug: String) -> Element(types.Msg) {
  html.div([attr.class("qr-real")], [
    html.img([
      attr.src(qr_url(slug)),
      attr.alt("QR code for " <> format.short_url(model.origin, slug)),
      attr.class("qr-img"),
    ]),
  ])
}

// LEDGER ----------------------------------------------------------------------

fn ledger_view(model: types.Model) -> Element(types.Msg) {
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

fn ledger_row(model: types.Model, item: types.LedgerItem) -> Element(types.Msg) {
  let is_copied = model.copied == option.Some(item.slug)
  let copy_text = format.short_url(model.origin, item.slug)
  let display = format.short_url(model.origin, item.slug)
  html.div([attr.class("ledger-row rise")], [
    html.div([attr.class("lr-left")], [
      html.span([attr.class("lr-short")], [
        element.text(display),
      ]),
      html.span([attr.class("lr-long")], [element.text(item.long_text)]),
    ]),
    html.div(
      [attribute("style", "display:flex;align-items:center;gap:16px")],
      [
        html.span([attr.class("lr-clicks")], [
          element.text(format.with_commas(item.clicks) <> " clicks"),
        ]),
        html.button(
          [attr.class("mini-copy"), event.on_click(types.CopyClicked(item.slug, copy_text))],
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

fn features_section() -> Element(types.Msg) {
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

fn feature_card(feature: data.Feature) -> Element(types.Msg) {
  html.div([attr.class("feature")], [
    html.span([attr.class("fnum")], [element.text(feature.num)]),
    html.div([attr.class("ficon")], [icons.feature_icon(feature.icon)]),
    html.h3([], [element.text(feature.title)]),
    html.p([], [element.text(feature.body)]),
  ])
}

// DECREE ----------------------------------------------------------------------

fn decree() -> Element(types.Msg) {
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

fn stat(value: String, suffix: String, label: String) -> Element(types.Msg) {
  html.div([attr.class("stat")], [
    html.div([attr.class("num")], [
      html.span([], [element.text(value)]),
      element.text(suffix),
    ]),
    html.div([attr.class("lab")], [element.text(label)]),
  ])
}

// CTA -------------------------------------------------------------------------

fn cta() -> Element(types.Msg) {
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

fn footer() -> Element(types.Msg) {
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

fn footer_col(heading: String, links: List(String)) -> Element(types.Msg) {
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
.protection-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 14px; }
.protection-field { display: flex; flex-direction: column; gap: 6px; }
.protection-field .k { font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; opacity: 0.7; }
.protection-input { width: 100%; padding: 10px 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.12); background: rgba(0,0,0,0.2); color: inherit; font: inherit; }
.secret-row { margin-top: 16px; padding: 12px 16px; border: 1px dashed rgba(255,200,80,0.4); border-radius: 8px; background: rgba(255,200,80,0.06); }
.secret-row .k { font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; opacity: 0.7; margin-bottom: 4px; }
.secret-row .secret { display: block; padding: 6px 0; font-size: 13px; word-break: break-all; }
.secret-row .hint { margin-top: 4px; font-size: 12px; opacity: 0.75; }
.error-banner { margin-top: 12px; padding: 10px 14px; border-radius: 8px; background: rgba(255,90,90,0.12); color: #ffd7d7; font-size: 14px; }
"
