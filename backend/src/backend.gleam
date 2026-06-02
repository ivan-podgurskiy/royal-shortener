import backend/router
import envoy
import gleam/erlang/process
import gleam/int
import gleam/result
import mist
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  // Compiled frontend bundle + index.html live in the app's priv/static.
  let assert Ok(priv) = wisp.priv_directory("backend")
  let static_directory = priv <> "/static"

  let secret_key_base = secret_key_base()
  let handler = fn(req) { router.handle_request(req, static_directory) }

  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port())
    |> mist.start

  process.sleep_forever()
}

fn port() -> Int {
  envoy.get("PORT")
  |> result.try(int.parse)
  |> result.unwrap(8080)
}

fn secret_key_base() -> String {
  case envoy.get("SECRET_KEY_BASE") {
    Ok(key) -> key
    Error(_) -> wisp.random_string(64)
  }
}
