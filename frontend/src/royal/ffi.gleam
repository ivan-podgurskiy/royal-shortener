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

@external(javascript, "./ffi_ext.mjs", "appPage")
pub fn app_page() -> String

@external(javascript, "./ffi_ext.mjs", "savePendingClaim")
pub fn save_pending_claim(slug: String, secret: String) -> Nil

@external(javascript, "./ffi_ext.mjs", "loadPendingClaimsJson")
pub fn load_pending_claims_json() -> String

@external(javascript, "./ffi_ext.mjs", "clearPendingClaims")
pub fn clear_pending_claims() -> Nil

@external(javascript, "./ffi_ext.mjs", "postJsonCred")
pub fn post_json_cred(
  path: String,
  body: String,
  callback: fn(Int, String) -> Nil,
) -> Nil

@external(javascript, "./ffi_ext.mjs", "getCred")
pub fn get_cred(path: String, callback: fn(Int, String) -> Nil) -> Nil
