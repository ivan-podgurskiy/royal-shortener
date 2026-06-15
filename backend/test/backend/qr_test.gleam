import backend/qr
import gleam/string
import gleeunit/should

pub fn to_svg_returns_markup_test() {
  let assert Ok(svg) = qr.to_svg("https://example.com/test")
  svg |> string.contains("<svg") |> should.be_true
}

pub fn to_svg_encodes_url_test() {
  let assert Ok(svg) = qr.to_svg("https://royal.sh/Sovereign-abc")
  svg |> string.contains("<svg") |> should.be_true
}
