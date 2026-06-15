//// Fire-and-forget click recording after redirects.

import backend/clicks
import backend/db
import backend/geoip
import backend/request_info
import backend/user_agent
import gleam/erlang/process
import wisp.{type Request}

pub fn record_after_redirect(
  req: Request,
  link_id: Int,
  db_path: String,
) -> Nil {
  let ip = request_info.client_ip(req)
  let country = geoip.country(ip)
  let ua = request_info.user_agent(req)
  let device = user_agent.device_class(ua) |> clicks.device_class_from_label
  let event =
    clicks.ClickEvent(
      link_id: link_id,
      at: system_seconds(),
      referrer: request_info.referrer(req),
      country:,
      device_class: device,
    )

  process.spawn_unlinked(fn() {
    case db.open(db_path) {
      Ok(conn) -> {
        let _ = clicks.record(event, conn)
        let _ = db.close(conn)
        Nil
      }
      Error(_) -> Nil
    }
  })

  Nil
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
