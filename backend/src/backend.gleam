import backend/db
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

  let assert Ok(priv) = wisp.priv_directory("backend")
  let static_directory = priv <> "/static"

  let assert Ok(conn) = open_db(priv)
  let assert Ok(_) = db.run_migrations(conn)

  let secret_key_base = secret_key_base()
  let handler = fn(req) { router.handle_request(req, static_directory, conn) }

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
  let path = case envoy.get("DATABASE_URL") {
    Ok(p) -> p
    Error(_) -> {
      let dir = priv <> "/data"
      let _ = simplifile.create_directory_all(dir)
      dir <> "/royal.sqlite3"
    }
  }
  db.open(path)
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
