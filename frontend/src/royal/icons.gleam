//// Royal Shortener — geometric heraldic icons, ported from icons.jsx.
//// Built only from simple SVG shapes so they inherit theme colours via
//// `currentColor` and the shared `--gold-*` custom properties.

import gleam/float
import gleam/int
import lustre/attribute.{attribute} as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg

fn a(name: String, value: String) -> attr.Attribute(msg) {
  attribute(name, value)
}

/// The royal crown, assembled from a polygon, a base band and three jewels.
pub fn crown_mark(size: Int) -> Element(msg) {
  let height = float.to_string(int.to_float(size) *. 30.0 /. 34.0)
  svg.svg(
    [
      attr.class("crown"),
      a("width", int.to_string(size)),
      a("height", height),
      a("viewBox", "0 0 34 30"),
      a("fill", "none"),
    ],
    [
      svg.defs([], [
        svg.linear_gradient(
          [a("id", "goldgrad"), a("x1", "0"), a("y1", "0"), a("x2", "0"), a("y2", "1")],
          [
            svg.stop([a("offset", "0"), a("stop-color", "var(--gold-1)")]),
            svg.stop([a("offset", "1"), a("stop-color", "var(--gold-3)")]),
          ],
        ),
      ]),
      svg.polygon([
        a("points", "3,27 3,10 10,17 17,5 24,17 31,10 31,27"),
        a("fill", "url(#goldgrad)"),
        a("stroke", "var(--gold-3)"),
        a("stroke-width", "0.6"),
        a("stroke-linejoin", "round"),
      ]),
      svg.rect([
        a("x", "3"),
        a("y", "25"),
        a("width", "28"),
        a("height", "3.4"),
        a("rx", "0.6"),
        a("fill", "url(#goldgrad)"),
        a("stroke", "var(--gold-3)"),
        a("stroke-width", "0.4"),
      ]),
      svg.circle([a("cx", "3"), a("cy", "9"), a("r", "2"), a("fill", "var(--gold-1)")]),
      svg.circle([a("cx", "17"), a("cy", "4"), a("r", "2.2"), a("fill", "var(--gold-1)")]),
      svg.circle([a("cx", "31"), a("cy", "9"), a("r", "2"), a("fill", "var(--gold-1)")]),
    ],
  )
}

/// A small rotated square used inside flourishes.
pub fn diamond(size: Int) -> Element(msg) {
  svg.svg(
    [
      a("width", int.to_string(size)),
      a("height", int.to_string(size)),
      a("viewBox", "0 0 10 10"),
      attr.style("display", "block"),
    ],
    [
      svg.rect([
        a("x", "2.2"),
        a("y", "2.2"),
        a("width", "5.6"),
        a("height", "5.6"),
        a("transform", "rotate(45 5 5)"),
        a("fill", "currentColor"),
      ]),
    ],
  )
}

/// Centered rule + diamonds + crown ornament.
pub fn flourish() -> Element(msg) {
  html.div([attr.class("flourish"), attr.style("gap", "10px")], [
    html.span([attr.class("rule")], []),
    diamond(6),
    crown_mark(20),
    diamond(6),
    html.span([attr.class("rule r")], []),
  ])
}

fn icon_svg(children: List(Element(msg))) -> Element(msg) {
  svg.svg(
    [
      a("width", "22"),
      a("height", "22"),
      a("viewBox", "0 0 24 24"),
      a("fill", "none"),
      a("stroke", "currentColor"),
      a("stroke-width", "1.4"),
    ],
    children,
  )
}

pub fn ico_ledger() -> Element(msg) {
  icon_svg([
    svg.line([a("x1", "4"), a("y1", "20"), a("x2", "20"), a("y2", "20"), a("stroke-linecap", "round")]),
    svg.rect([a("x", "5"), a("y", "12"), a("width", "3.2"), a("height", "6"), a("fill", "currentColor"), a("stroke", "none")]),
    svg.rect([a("x", "10.4"), a("y", "8"), a("width", "3.2"), a("height", "10"), a("fill", "currentColor"), a("stroke", "none")]),
    svg.rect([a("x", "15.8"), a("y", "4.5"), a("width", "3.2"), a("height", "13.5"), a("fill", "currentColor"), a("stroke", "none")]),
  ])
}

pub fn ico_crest() -> Element(msg) {
  icon_svg([
    svg.path([
      a("d", "M12 3 L19 6 V12 C19 16.5 15.8 19.5 12 21 C8.2 19.5 5 16.5 5 12 V6 Z"),
      a("stroke-linejoin", "round"),
    ]),
    svg.path([
      a("d", "M12 8.5 L13.1 11 L15.7 11 L13.6 12.7 L14.4 15.2 L12 13.7 L9.6 15.2 L10.4 12.7 L8.3 11 L10.9 11 Z"),
      a("fill", "currentColor"),
      a("stroke", "none"),
    ]),
  ])
}

pub fn ico_seal() -> Element(msg) {
  icon_svg([
    svg.rect([a("x", "4"), a("y", "4"), a("width", "6.5"), a("height", "6.5"), a("rx", "1")]),
    svg.rect([a("x", "13.5"), a("y", "4"), a("width", "6.5"), a("height", "6.5"), a("rx", "1")]),
    svg.rect([a("x", "4"), a("y", "13.5"), a("width", "6.5"), a("height", "6.5"), a("rx", "1")]),
    svg.rect([a("x", "15.4"), a("y", "15.4"), a("width", "2.6"), a("height", "2.6"), a("fill", "currentColor"), a("stroke", "none")]),
    svg.rect([a("x", "6"), a("y", "6"), a("width", "2.5"), a("height", "2.5"), a("fill", "currentColor"), a("stroke", "none")]),
  ])
}

pub fn ico_guard() -> Element(msg) {
  icon_svg([
    svg.rect([a("x", "6"), a("y", "10.5"), a("width", "12"), a("height", "9"), a("rx", "1.5")]),
    svg.path([a("d", "M8.5 10.5 V8 a3.5 3.5 0 0 1 7 0 V10.5")]),
    svg.circle([a("cx", "12"), a("cy", "14.5"), a("r", "1.4"), a("fill", "currentColor"), a("stroke", "none")]),
  ])
}

pub fn ico_sparkle() -> Element(msg) {
  svg.svg(
    [a("width", "16"), a("height", "16"), a("viewBox", "0 0 24 24"), a("fill", "currentColor")],
    [
      svg.path([a("d", "M12 2 L13.8 9.2 L21 11 L13.8 12.8 L12 20 L10.2 12.8 L3 11 L10.2 9.2 Z")]),
    ],
  )
}

pub fn ico_copy() -> Element(msg) {
  svg.svg(
    [
      a("width", "14"),
      a("height", "14"),
      a("viewBox", "0 0 24 24"),
      a("fill", "none"),
      a("stroke", "currentColor"),
      a("stroke-width", "1.6"),
    ],
    [
      svg.rect([a("x", "8"), a("y", "8"), a("width", "11"), a("height", "11"), a("rx", "1.5")]),
      svg.path([a("d", "M5 15 V6 a1.5 1.5 0 0 1 1.5-1.5 H15")]),
    ],
  )
}

/// Look up a feature icon by the identifier used in the data module.
pub fn feature_icon(name: String) -> Element(msg) {
  case name {
    "IcoLedger" -> ico_ledger()
    "IcoCrest" -> ico_crest()
    "IcoSeal" -> ico_seal()
    "IcoGuard" -> ico_guard()
    _ -> ico_seal()
  }
}
