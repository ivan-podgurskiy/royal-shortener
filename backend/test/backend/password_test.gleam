import backend/password
import gleeunit/should

pub fn hash_password_test() {
  let assert Ok(hash) = password.hash("swordfish1")
  password.verify(hash, "swordfish1") |> should.be_true
  password.verify(hash, "wrong") |> should.be_false
}
