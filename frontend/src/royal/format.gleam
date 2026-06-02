//// Royal Shortener — pure string helpers. No Lustre, no Msg, no side effects.

import gleam/int
import gleam/list
import gleam/string

pub fn strip_scheme(url: String) -> String {
  case string.starts_with(url, "https://") {
    True -> string.drop_start(url, 8)
    False ->
      case string.starts_with(url, "http://") {
        True -> string.drop_start(url, 7)
        False -> url
      }
  }
}

pub fn derive_title(host_path: String) -> String {
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

pub fn with_commas(n: Int) -> String {
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
