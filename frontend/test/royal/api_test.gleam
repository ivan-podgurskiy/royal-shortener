import gleam/json
import gleeunit/should
import royal/api

pub fn minted_decoder_test() {
  let body =
    "{\"slug\":\"Sovereign-7qz\",\"short_url\":\"/Sovereign-7qz\",\"secret\":\"abc123\"}"
  let assert Ok(parsed) = json.parse(body, api.minted_decoder())
  parsed.slug |> should.equal("Sovereign-7qz")
  parsed.short_url |> should.equal("/Sovereign-7qz")
}

pub fn stats_decoder_test() {
  let body =
    "{\"total\":3,\"by_country\":[{\"label\":\"US\",\"count\":2},{\"label\":\"??\",\"count\":1}],\"by_device\":[{\"label\":\"desktop\",\"count\":2},{\"label\":\"mobile\",\"count\":1}],\"hourly\":[{\"at\":1710000000,\"count\":1}],\"daily\":[{\"at\":1710000000,\"count\":3}]}"

  let assert Ok(stats) = json.parse(body, api.stats_decoder())
  stats.total |> should.equal(3)
  stats.by_country |> should.equal([api.CountRow("US", 2), api.CountRow("??", 1)])
}

pub fn user_decoder_test() {
  let body = "{\"id\":1,\"email\":\"knight@example.com\"}"
  let assert Ok(user) = json.parse(body, api.user_decoder())
  user.email |> should.equal("knight@example.com")
}

pub fn dashboard_link_decoder_test() {
  let body =
    "{\"slug\":\"Royal-abc\",\"target_url\":\"https://example.com\",\"click_count\":2,\"created_at\":1710000000,\"short_url\":\"/Royal-abc\"}"
  let assert Ok(link) = json.parse(body, api.dashboard_link_decoder())
  link.slug |> should.equal("Royal-abc")
  link.click_count |> should.equal(2)
}
