import backend/clicks
import backend/user_agent
import gleeunit/should

pub fn bot_user_agent_test() {
  user_agent.device_class("Googlebot/2.1")
  |> should.equal("bot")
}

pub fn mobile_user_agent_test() {
  user_agent.device_class("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)")
  |> should.equal("mobile")
}

pub fn desktop_user_agent_test() {
  user_agent.device_class("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0)")
  |> should.equal("desktop")
}

pub fn device_class_roundtrip_test() {
  clicks.device_class_from_label("mobile")
  |> should.equal(clicks.Mobile)
}
