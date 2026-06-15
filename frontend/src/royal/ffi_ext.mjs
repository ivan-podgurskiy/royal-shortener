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

const BACKEND_DEV_PORT = "8080";
const FRONTEND_DEV_PORT = "1234";

const reserved_paths = new Set([
  "api",
  "health",
  "dashboard",
  "stats",
  "login",
  "signup",
  "logout",
  "static",
  "assets",
  "favicon.ico",
  "robots.txt",
]);

function backendDevOrigin() {
  const { protocol, hostname } = window.location;
  return `${protocol}//${hostname}:${BACKEND_DEV_PORT}`;
}

/// Origin used when building short links. In dev the UI runs on :1234 but
/// redirects are served by the backend on :8080 (see gleam.toml proxy).
export function shortLinkOrigin() {
  if (window.location.port === FRONTEND_DEV_PORT) {
    return backendDevOrigin();
  }
  return window.location.origin;
}

/// If someone opens localhost:1234/<slug>, hand off to the backend before
/// the SPA renders. Production serves both UI and redirects from one port.
export function handoffShortLinkIfNeeded() {
  if (window.location.port !== FRONTEND_DEV_PORT) {
    return;
  }

  const { pathname, search, hash } = window.location;
  if (pathname === "/" || pathname.includes(".")) {
    return;
  }

  const segment = pathname.replace(/^\/+|\/+$/g, "");
  if (!segment || segment.includes("/") || reserved_paths.has(segment)) {
    return;
  }

  window.location.replace(
    `${backendDevOrigin()}${pathname}${search}${hash}`,
  );
}

export function statsPageSlug() {
  const m = window.location.pathname.match(/^\/stats\/([^/]+)\/?$/);
  return m ? m[1] : "";
}

export function statsPageSecret() {
  const m = window.location.pathname.match(/^\/stats\/([^/]+)\/?$/);
  if (!m) return "";
  const params = new URLSearchParams(window.location.search);
  return params.get("secret") ?? "";
}
