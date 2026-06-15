//// MaxMind GeoLite2 country lookup via locus.

import envoy
import gleam/option.{type Option, None, Some}
import wisp

pub fn start() -> Nil {
  let _ = start_db(db_path())
  Nil
}

pub fn country(ip: String) -> Option(String) {
  case lookup_country(ip) {
    "" -> None
    code -> Some(code)
  }
}

fn db_path() -> String {
  case envoy.get("GEOIP_DB_PATH") {
    Ok(path) -> path
    Error(_) ->
      case wisp.priv_directory("backend") {
        Ok(priv) -> priv <> "/data/GeoLite2-Country.mmdb"
        Error(_) -> "priv/data/GeoLite2-Country.mmdb"
      }
  }
}

@external(erlang, "backend_geoip_ffi", "start")
fn start_db(path: String) -> Nil

@external(erlang, "backend_geoip_ffi", "country")
fn lookup_country(ip: String) -> String
