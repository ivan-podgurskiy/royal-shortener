//// Royal Shortener — data, slug minting and the faux QR-seal pattern.
//// Ported from data.jsx.

import gleam/int
import gleam/list
import gleam/string
import royal/ffi

/// A single privilege shown in the feature grid.
pub type Feature {
  Feature(icon: String, num: String, title: String, body: String)
}

pub const slides_url = "https://docs.google.com/presentation/d/1aXk9Qv7RmZ2-RoyalShortener-Pitch-Deck-2026/edit#slide=id.g2f8c41ad7b_0_142"

const royal_words = [
  "Regalia", "Sovereign", "Crowned", "Imperial", "Majesty", "Coronet", "Heir",
  "Throne", "Scepter", "Diadem", "Monarch", "Noble", "Court", "Crest",
  "Royaume", "Sceptre", "Ermine", "Laurel", "Gilded", "Dauphin",
]

const tag_alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

pub fn features() -> List(Feature) {
  [
    Feature(
      "IcoLedger",
      "I",
      "The Royal Ledger",
      "Every click recorded in a sovereign analytics dashboard — sources, regions, and the hour each subject arrived.",
    ),
    Feature(
      "IcoCrest",
      "II",
      "Bestow a Title",
      "Grant any link a vanity name worthy of its station — royal.sh/your-decree — and brand it as your own domain.",
    ),
    Feature(
      "IcoSeal",
      "III",
      "QR Wax Seals",
      "Every link is minted with a scannable seal, ready to press onto print, packaging, or a royal invitation.",
    ),
    Feature(
      "IcoGuard",
      "IV",
      "Guarded by Decree",
      "Protect links like the crown jewels — passwords, expiry dates, and click limits, all by your command.",
    ),
  ]
}

/// Mint a random royal slug, e.g. `Sovereign-7qz`.
pub fn random_slug() -> String {
  let word = pick(royal_words, "Sovereign")
  word <> "-" <> random_tag(3)
}

fn pick(items: List(String), fallback: String) -> String {
  let length = list.length(items)
  case length {
    0 -> fallback
    _ -> {
      let index = ffi.random_int(length)
      case list_at(items, index) {
        Ok(value) -> value
        Error(_) -> fallback
      }
    }
  }
}

fn list_at(items: List(String), index: Int) -> Result(String, Nil) {
  list.drop(items, index)
  |> list.first
}

fn random_tag(length: Int) -> String {
  case length {
    n if n <= 0 -> ""
    _ -> random_char() <> random_tag(length - 1)
  }
}

fn random_char() -> String {
  let chars = string.to_graphemes(tag_alphabet)
  pick(chars, "x")
}

// ---------------------------------------------------------------------------
// Faux QR seal
// ---------------------------------------------------------------------------

const qr_size = 11

/// Produce 121 booleans describing an 11×11 faux QR seal that is stable for a
/// given seed. Finder corners are drawn deterministically; the field is filled
/// from a hash of the seed so each link gets its own distinct pattern.
pub fn make_qr(seed: String) -> List(Bool) {
  let hash = seed_hash(seed)
  let coords = upto(qr_size)
  list.flat_map(coords, fn(r) {
    list.map(coords, fn(c) { cell(hash, r, c) })
  })
}

fn upto(n: Int) -> List(Int) {
  upto_loop(n - 1, [])
}

fn upto_loop(i: Int, acc: List(Int)) -> List(Int) {
  case i < 0 {
    True -> acc
    False -> upto_loop(i - 1, [i, ..acc])
  }
}

fn cell(hash: Int, r: Int, c: Int) -> Bool {
  case is_finder(r, c) {
    True ->
      r == 0
      || r == 2
      || c == 0
      || c == 2
      || r == qr_size - 1
      || r == qr_size - 3
      || c == qr_size - 1
      || c == qr_size - 3
      || { r == 1 && c == 1 }
      || { r == 1 && c == qr_size - 2 }
      || { r == qr_size - 2 && c == 1 }
    False -> {
      let mixed = int.bitwise_exclusive_or(hash, r * 31 + c)
      let scrambled =
        int.bitwise_exclusive_or(mixed, int.bitwise_shift_left(mixed, 7))
      let shift = r % 5 + 1
      int.bitwise_and(int.bitwise_shift_right(scrambled, shift), 1) == 1
    }
  }
}

fn is_finder(r: Int, c: Int) -> Bool {
  let n = qr_size
  { r < 3 && c < 3 } || { r < 3 && c > n - 4 } || { r > n - 4 && c < 3 }
}

fn seed_hash(seed: String) -> Int {
  string.to_utf_codepoints(seed)
  |> list.fold(2_166_136_261, fn(h, cp) {
    let code = string.utf_codepoint_to_int(cp)
    int.absolute_value(int.bitwise_exclusive_or(h, code) * 16_777_619 % 2_147_483_647)
  })
}
