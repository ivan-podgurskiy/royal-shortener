//// Click event persistence and stats aggregation.

import backend/db
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import sqlight

pub type DeviceClass {
  Mobile
  Desktop
  Bot
}

pub type ClickEvent {
  ClickEvent(
    link_id: Int,
    at: Int,
    referrer: Option(String),
    country: Option(String),
    device_class: DeviceClass,
  )
}

pub type CountRow {
  CountRow(label: String, count: Int)
}

pub type BucketRow {
  BucketRow(at: Int, count: Int)
}

pub type Stats {
  Stats(
    total: Int,
    by_country: List(CountRow),
    by_device: List(CountRow),
    hourly: List(BucketRow),
    daily: List(BucketRow),
  )
}

pub type Error {
  StorageError(String)
}

pub fn record(event: ClickEvent, conn: db.Conn) -> Result(Nil, Error) {
  let sql =
    "INSERT INTO clicks (link_id, at, referrer, country, device_class)
     VALUES (?, ?, ?, ?, ?)"

  sqlight.query(
    sql,
    on: conn,
    with: [
      sqlight.int(event.link_id),
      sqlight.int(event.at),
      nullable_text(event.referrer),
      nullable_text(event.country),
      sqlight.text(device_class_label(event.device_class)),
    ],
    expecting: decode.success(Nil),
  )
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
}

pub fn stats_for_link(link_id: Int, conn: db.Conn) -> Result(Stats, Error) {
  use total <- result.try(total_clicks(link_id, conn))
  use by_country <- result.try(by_country(link_id, conn))
  use by_device <- result.try(by_device(link_id, conn))
  use hourly <- result.try(hourly_buckets(link_id, conn))
  use daily <- result.try(daily_buckets(link_id, conn))
  Ok(Stats(
    total:,
    by_country:,
    by_device:,
    hourly:,
    daily:,
  ))
}

pub fn device_class_from_label(label: String) -> DeviceClass {
  case label {
    "mobile" -> Mobile
    "bot" -> Bot
    _ -> Desktop
  }
}

pub fn stats_json(stats: Stats) -> json.Json {
  json.object([
    #("total", json.int(stats.total)),
    #("by_country", count_rows_json(stats.by_country)),
    #("by_device", count_rows_json(stats.by_device)),
    #("hourly", bucket_rows_json(stats.hourly)),
    #("daily", bucket_rows_json(stats.daily)),
  ])
}

// ------------ internals --------------------------------------------------

fn total_clicks(link_id: Int, conn: db.Conn) -> Result(Int, Error) {
  sqlight.query(
    "SELECT COUNT(*) FROM clicks WHERE link_id = ?",
    on: conn,
    with: [sqlight.int(link_id)],
    expecting: decode.at([0], decode.int),
  )
  |> result.map(fn(rows) {
    case rows {
      [n, ..] -> n
      [] -> 0
    }
  })
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
}

fn by_country(link_id: Int, conn: db.Conn) -> Result(List(CountRow), Error) {
  sqlight.query(
    "SELECT COALESCE(country, '??') AS label, COUNT(*) AS n
     FROM clicks WHERE link_id = ?
     GROUP BY country ORDER BY n DESC",
    on: conn,
    with: [sqlight.int(link_id)],
    expecting: count_row_decoder(),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
}

fn by_device(link_id: Int, conn: db.Conn) -> Result(List(CountRow), Error) {
  sqlight.query(
    "SELECT device_class AS label, COUNT(*) AS n
     FROM clicks WHERE link_id = ?
     GROUP BY device_class ORDER BY n DESC",
    on: conn,
    with: [sqlight.int(link_id)],
    expecting: count_row_decoder(),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
}

fn hourly_buckets(link_id: Int, conn: db.Conn) -> Result(List(BucketRow), Error) {
  let since = system_seconds() - 86_400
  sqlight.query(
    "SELECT (at / 3600) * 3600 AS bucket, COUNT(*) AS n
     FROM clicks
     WHERE link_id = ? AND at >= ?
     GROUP BY bucket ORDER BY bucket",
    on: conn,
    with: [sqlight.int(link_id), sqlight.int(since)],
    expecting: bucket_row_decoder(),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
}

fn daily_buckets(link_id: Int, conn: db.Conn) -> Result(List(BucketRow), Error) {
  let since = system_seconds() - 2_592_000
  sqlight.query(
    "SELECT (at / 86400) * 86400 AS bucket, COUNT(*) AS n
     FROM clicks
     WHERE link_id = ? AND at >= ?
     GROUP BY bucket ORDER BY bucket",
    on: conn,
    with: [sqlight.int(link_id), sqlight.int(since)],
    expecting: bucket_row_decoder(),
  )
  |> result.map_error(fn(e) { StorageError(error_message(e)) })
}

fn count_row_decoder() -> decode.Decoder(CountRow) {
  use label <- decode.field(0, decode.string)
  use count <- decode.field(1, decode.int)
  decode.success(CountRow(label:, count:))
}

fn bucket_row_decoder() -> decode.Decoder(BucketRow) {
  use at <- decode.field(0, decode.int)
  use count <- decode.field(1, decode.int)
  decode.success(BucketRow(at:, count:))
}

fn count_rows_json(rows: List(CountRow)) -> json.Json {
  json.array(rows, fn(row) {
    json.object([
      #("label", json.string(row.label)),
      #("count", json.int(row.count)),
    ])
  })
}

fn bucket_rows_json(rows: List(BucketRow)) -> json.Json {
  json.array(rows, fn(row) {
    json.object([
      #("at", json.int(row.at)),
      #("count", json.int(row.count)),
    ])
  })
}

fn device_class_label(device: DeviceClass) -> String {
  case device {
    Mobile -> "mobile"
    Desktop -> "desktop"
    Bot -> "bot"
  }
}

fn nullable_text(value: Option(String)) -> sqlight.Value {
  case value {
    Some(text) -> sqlight.text(text)
    None -> sqlight.null()
  }
}

fn error_message(e: sqlight.Error) -> String {
  case e {
    sqlight.SqlightError(message: message, ..) -> message
  }
}

@external(erlang, "backend_system_time_ffi", "seconds")
fn system_seconds() -> Int
