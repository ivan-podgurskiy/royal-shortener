//// Royal Shortener — domain types shared by the app and view modules.

import gleam/option.{type Option}
import royal/api

pub type Phase {
  Idle
  Animating
  Done
}

pub type ExpiryPreset {
  Never
  OneHour
  OneDay
  SevenDays
}

pub type Minted {
  Minted(
    slug: String,
    short_url: String,
    secret: String,
    long_text: String,
    title: String,
    expiry: ExpiryPreset,
    click_limit: Option(Int),
  )
}

pub type LedgerItem {
  LedgerItem(slug: String, long_text: String, clicks: Int)
}

pub type Model {
  Model(
    origin: String,
    url: String,
    phase: Phase,
    result: Option(Minted),
    ledger: List(LedgerItem),
    copied: Option(String),
    error: Option(String),
    expiry: ExpiryPreset,
    click_limit: String,
  )
}

pub type Msg {
  UrlChanged(String)
  ExpiryChanged(String)
  ClickLimitChanged(String)
  ShortenClicked
  KeyPressed(String)
  MintSucceeded(api.Minted)
  MintFailed(api.ApiError)
  AnimationDone
  ResetClicked
  CopyClicked(slug: String, text: String)
  CopyCleared
}
