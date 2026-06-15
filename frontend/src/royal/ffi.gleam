//// Thin Gleam bindings over the browser FFI in `ffi.mjs`.

/// A uniformly random integer in the range `[0, max)`.
@external(javascript, "./ffi_ext.mjs", "randomInt")
pub fn random_int(max: Int) -> Int

/// Copy the given text to the clipboard (with a textarea fallback).
@external(javascript, "./ffi_ext.mjs", "copyText")
pub fn copy_text(text: String) -> Nil

/// Invoke `callback` after `ms` milliseconds.
@external(javascript, "./ffi_ext.mjs", "after")
pub fn after(ms: Int, callback: fn() -> Nil) -> Nil

/// Origin for short links — in dev points at the backend port where redirects
/// are handled, not the Lustre dev-server port.
@external(javascript, "./ffi_ext.mjs", "shortLinkOrigin")
pub fn short_link_origin() -> String

/// Dev-only: redirect `localhost:1234/<slug>` to the backend before SPA boot.
@external(javascript, "./ffi_ext.mjs", "handoffShortLinkIfNeeded")
pub fn handoff_short_link_if_needed() -> Nil

@external(javascript, "./ffi_ext.mjs", "statsPageSlug")
pub fn stats_page_slug() -> String

@external(javascript, "./ffi_ext.mjs", "statsPageSecret")
pub fn stats_page_secret() -> String
