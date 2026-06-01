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
