//// Classify User-Agent strings into mobile, desktop, or bot.

import gleam/string

pub fn device_class(user_agent: String) -> String {
  let ua = string.lowercase(user_agent)
  case is_bot(ua) {
    True -> "bot"
    False ->
      case is_mobile(ua) {
        True -> "mobile"
        False -> "desktop"
      }
  }
}

fn is_bot(ua: String) -> Bool {
  string.contains(ua, "bot")
  || string.contains(ua, "spider")
  || string.contains(ua, "crawler")
  || string.contains(ua, "slurp")
  || string.contains(ua, "facebookexternalhit")
  || string.contains(ua, "preview")
}

fn is_mobile(ua: String) -> Bool {
  string.contains(ua, "mobile")
  || string.contains(ua, "android")
  || string.contains(ua, "iphone")
  || string.contains(ua, "ipod")
  || string.contains(ua, "ipad")
}
