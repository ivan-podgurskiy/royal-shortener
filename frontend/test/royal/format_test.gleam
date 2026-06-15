import gleeunit/should
import royal/format

pub fn host_from_origin_test() {
  format.host_from_origin("https://localhost:8080")
  |> should.equal("localhost:8080")
}

pub fn short_url_test() {
  format.short_url("https://example.com", "Crown-abc")
  |> should.equal("https://example.com/Crown-abc")
}

pub fn short_prefix_test() {
  format.short_prefix("http://localhost:1234")
  |> should.equal("localhost:1234/")
}
