//// Extract client metadata from wisp requests.

import gleam/http/request
import gleam/option.{type Option, None, Some}
import gleam/string
import wisp.{type Request}

pub fn client_ip(req: Request) -> String {
  case forwarded_for(req) {
    Some(ip) -> ip
    None ->
      case request.get_header(req, "x-real-ip") {
        Ok(ip) -> ip
        Error(_) ->
          case request.get_header(req, "cf-connecting-ip") {
            Ok(ip) -> ip
            Error(_) -> "127.0.0.1"
          }
      }
  }
}

pub fn referrer(req: Request) -> Option(String) {
  case request.get_header(req, "referer") {
    Ok(value) ->
      case string.trim(value) {
        "" -> None
        trimmed -> Some(trimmed)
      }
    Error(_) -> None
  }
}

pub fn user_agent(req: Request) -> String {
  case request.get_header(req, "user-agent") {
    Ok(value) -> value
    Error(_) -> ""
  }
}

fn forwarded_for(req: Request) -> Option(String) {
  case request.get_header(req, "x-forwarded-for") {
    Ok(value) -> Some(first_ip(value))
    Error(_) -> None
  }
}

fn first_ip(value: String) -> String {
  case string.split_once(value, on: ",") {
    Ok(#(left, _)) -> string.trim(left)
    Error(_) -> string.trim(value)
  }
}
