//// QR code generation for short links.

import glqr

pub type Error {
  GenerateFailed
}

/// Render the given URL as an SVG QR code.
pub fn to_svg(url: String) -> Result(String, Error) {
  case glqr.new(url) |> glqr.generate() {
    Ok(code) -> Ok(glqr.to_svg(code))
    Error(_) -> Error(GenerateFailed)
  }
}
