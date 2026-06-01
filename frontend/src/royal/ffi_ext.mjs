// Royal Shortener — small browser FFI used by the Lustre frontend.

export function randomInt(max) {
  return Math.floor(Math.random() * max);
}

export function copyText(text) {
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text);
      return undefined;
    }
  } catch (_) {}
  try {
    const ta = document.createElement("textarea");
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand("copy");
    document.body.removeChild(ta);
  } catch (_) {}
  return undefined;
}

export function after(ms, callback) {
  setTimeout(() => {
    callback();
  }, ms);
  return undefined;
}
