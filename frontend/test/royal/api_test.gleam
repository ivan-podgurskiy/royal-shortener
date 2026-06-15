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
