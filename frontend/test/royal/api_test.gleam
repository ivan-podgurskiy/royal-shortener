import gleam/json
import gleeunit/should
import royal/api

pub fn decoder_parses_full_response_test() {
  let payload =
    "{\"slug\":\"Sovereign-7qz\",\"short_url\":\"/Sovereign-7qz\",\"secret\":\"abc123\"}"
  let assert Ok(parsed) = json.parse(payload, api.minted_decoder())
  parsed.slug |> should.equal("Sovereign-7qz")
  parsed.short_url |> should.equal("/Sovereign-7qz")
  parsed.secret |> should.equal("abc123")
}

pub fn decoder_rejects_missing_field_test() {
  let payload = "{\"slug\":\"Sovereign-7qz\"}"
  let result = json.parse(payload, api.minted_decoder())
  case result {
    Error(_) -> Nil
    Ok(_) -> panic as "expected decoder to fail on missing fields"
  }
}
