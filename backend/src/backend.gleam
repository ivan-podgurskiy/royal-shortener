import backend/db
import backend/geoip
import backend/router
import envoy
import gleam/erlang/process
import gleam/int
import gleam/result
import mist
import simplifile
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  geoip.start()

  let assert Ok(priv) = wisp.priv_directory("backend")
  let static_directory = priv <> "/static"
  let db_path = db.resolve_path(priv)

  let assert Ok(conn) = open_db(priv)
  let assert Ok(_) = db.run_migrations(conn)

  let secret_key_base = secret_key_base()
  let handler = fn(req) {
    router.handle_request(req, static_directory, db_path, conn)
  }

  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port())
    |> mist.start

  process.sleep_forever()
}

fn open_db(priv: String) -> Result(db.Conn, db.Error) {
  let path = db.resolve_path(priv)
  case envoy.get("DATABASE_URL") {
    Ok(_) -> db.open(path)
    Error(_) -> {
      let dir = priv <> "/data"
      let _ = simplifile.create_directory_all(dir)
      db.open(path)
    }
  }
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
