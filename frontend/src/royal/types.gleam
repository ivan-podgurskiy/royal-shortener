//// Royal Shortener — domain types shared by the app and view modules.

import gleam/option.{type Option}

pub type Phase {
  Idle
  Animating
  Done
}

pub type Minted {
  Minted(slug: String, long_text: String, title: String)
}

pub type LedgerItem {
  LedgerItem(slug: String, long_text: String, clicks: Int)
}

pub type Model {
  Model(
    url: String,
    phase: Phase,
    result: Option(Minted),
    ledger: List(LedgerItem),
    copied: Option(String),
  )
}

pub type Msg {
  UrlChanged(String)
  ShortenClicked
  KeyPressed(String)
  AnimationDone
  ResetClicked
  CopyClicked(slug: String, text: String)
  CopyCleared
}
