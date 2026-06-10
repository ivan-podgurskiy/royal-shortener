import backend/slug
import gleam/list
import gleam/string
import gleeunit/should

pub fn valid_slug_accepts_typical_input_test() {
  slug.validate_user_slug("Sovereign-7qz")
  |> should.equal(Ok("Sovereign-7qz"))
}

pub fn valid_slug_accepts_lowercase_and_digits_test() {
  slug.validate_user_slug("abc123") |> should.equal(Ok("abc123"))
}

pub fn invalid_slug_rejects_empty_test() {
  slug.validate_user_slug("") |> should.equal(Error(slug.Empty))
}

pub fn invalid_slug_rejects_too_long_test() {
  let long = string.repeat("a", 65)
  slug.validate_user_slug(long) |> should.equal(Error(slug.TooLong))
}

pub fn invalid_slug_rejects_disallowed_chars_test() {
  slug.validate_user_slug("hi there") |> should.equal(Error(slug.BadCharacters))
}

pub fn invalid_slug_rejects_reserved_test() {
  slug.validate_user_slug("api") |> should.equal(Error(slug.Reserved))
  slug.validate_user_slug("health") |> should.equal(Error(slug.Reserved))
  slug.validate_user_slug("dashboard") |> should.equal(Error(slug.Reserved))
}

pub fn random_slug_format_test() {
  let s = slug.random()
  // Royal word + "-" + 3 lowercase alnum chars
  let assert Ok(#(_, tag)) = string.split_once(s, on: "-")
  string.length(tag) |> should.equal(3)
}

fn repeat(n: Int, f: fn() -> a) -> List(a) {
  case n {
    0 -> []
    _ -> [f(), ..repeat(n - 1, f)]
  }
}

pub fn random_slug_avoids_reserved_test() {
  // 200 generations, none reserved
  repeat(200, fn() { slug.random() })
  |> list.all(fn(s) { slug.validate_user_slug(s) != Error(slug.Reserved) })
  |> should.be_true
}
