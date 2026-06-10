//// Slug generation, validation, and reserved-slug enforcement.
////
//// A slug is a short identifier appearing at the top level of a URL
//// (`royal.sh/<slug>`). It MUST NOT collide with any reserved top-level
//// route. Random slugs are "<RoyalWord>-<3 alnum chars>".

import gleam/int
import gleam/list
import gleam/set
import gleam/string

pub type ValidationError {
  Empty
  TooLong
  BadCharacters
  Reserved
}

const max_length = 64

const royal_words = [
  "Regalia", "Sovereign", "Crowned", "Imperial", "Majesty", "Coronet",
  "Heir", "Throne", "Scepter", "Diadem", "Monarch", "Noble", "Court",
  "Crest", "Royaume", "Sceptre", "Ermine", "Laurel", "Gilded", "Dauphin",
]

const tag_alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

/// Top-level routes that must never be served as a redirect. Update this
/// list whenever a new top-level path is added to the router.
pub const reserved_slugs = [
  "api", "health", "dashboard", "stats", "login", "signup", "logout",
  "static", "assets", "favicon.ico", "robots.txt",
]

/// Validate a user-supplied slug. Returns the slug verbatim on success.
pub fn validate_user_slug(input: String) -> Result(String, ValidationError) {
  case input {
    "" -> Error(Empty)
    _ -> {
      case string.length(input) > max_length {
        True -> Error(TooLong)
        False ->
          case all_allowed(input) {
            False -> Error(BadCharacters)
            True ->
              case is_reserved(input) {
                True -> Error(Reserved)
                False -> Ok(input)
              }
          }
      }
    }
  }
}

/// Mint a random slug, retrying if it collides with a reserved word.
pub fn random() -> String {
  let s = pick(royal_words) <> "-" <> random_tag(3)
  case is_reserved(s) {
    True -> random()
    False -> s
  }
}

pub fn is_reserved(slug: String) -> Bool {
  reserved_slugs
  |> set.from_list
  |> set.contains(string.lowercase(slug))
}

// ------------ helpers ----------------------------------------------------

fn all_allowed(input: String) -> Bool {
  let allowed =
    string.to_graphemes(
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_",
    )
    |> set.from_list
  string.to_graphemes(input)
  |> list.all(fn(c) { set.contains(allowed, c) })
}

fn pick(items: List(String)) -> String {
  let length = list.length(items)
  let index = int.random(length)
  let assert Ok(value) = list.drop(items, index) |> list.first
  value
}

fn random_tag(length: Int) -> String {
  let chars = string.to_graphemes(tag_alphabet)
  case length {
    n if n <= 0 -> ""
    _ -> {
      let index = int.random(list.length(chars))
      let assert Ok(c) = list.drop(chars, index) |> list.first
      c <> random_tag(length - 1)
    }
  }
}
