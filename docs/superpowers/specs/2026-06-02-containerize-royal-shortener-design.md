# Containerizing Royal Shortener — Design

Date: 2026-06-02
Status: Approved (design), pending implementation

## Goal

Package the Royal Shortener as a **single Docker image** that runs the Gleam
(BEAM) backend, which serves the compiled Lustre frontend bundle plus a health
check. This is the first "tidy up" step; the shortener API and storage come
later.

## Scope (this step)

- Minimal `mist` + `wisp` HTTP server in the backend.
- Host `index.html` that boots the Lustre SPA.
- Multi-stage `Dockerfile` + `.dockerignore` at the repo root.

Explicitly **out of scope**: shortener create/redirect API, persistence,
auth, deploy manifests.

## Architecture

Single container, multi-stage build (Approach A):

1. **Frontend build stage** — Gleam image. Build the Lustre app to a JS/CSS
   bundle (`gleam run -m lustre/dev build app --minify` or equivalent),
   producing the bundle under the frontend's `priv/static`.
2. **Backend build stage** — Gleam image. `gleam export erlang-shipment` to
   produce a self-contained Erlang release. Copy the frontend bundle +
   `index.html` into the backend's `priv/static`.
3. **Runtime stage** — slim Erlang image. Contains only the shipment + assets.
   No Gleam toolchain. Runs the release entrypoint.

Rationale: idiomatic Gleam-on-BEAM production pattern; small, reproducible
runtime image; clean build/run separation.

## Backend server design

`backend/src/backend.gleam` (currently a hello-world `main`) becomes the
entrypoint that:

- Reads `PORT` from env, default `8080`; binds `0.0.0.0`.
- Starts `mist` hosting a `wisp` handler, then sleeps the process.

Routing kept in a small `backend/router` module so `backend.gleam` stays
focused on startup:

- `GET /health` → `200 "ok"` (plain text).
- Static assets served from `priv/static` (via `wisp.serve_static`).
- `GET /` and unknown non-asset paths → return `priv/static/index.html` so the
  client-side SPA can boot/route.

The static directory is resolved at runtime via the application's `priv`
directory so it works both locally and inside the release.

## Frontend

- The SPA already works and mounts to `#app`.
- Add `index.html` host page: `<div id="app"></div>` + a
  `<script type="module">` that imports the built bundle and calls the app's
  `main`.
- Confirm the exact Lustre bundle command and output filenames during
  implementation; the Dockerfile copies whatever the bundle step emits into the
  backend `priv/static`.

## Docker

- `Dockerfile` (multi-stage as above) and `.dockerignore` (exclude `build/`,
  `.git`, `node_modules`, editor cruft, the `Royal Shortener UI/` prototype).
- `EXPOSE 8080`; `PORT` overridable at runtime.
- Target: generic — `docker run -p 8080:8080 <image>` works anywhere.

## Verification

- `docker build` succeeds.
- `docker run -p 8080:8080` → `GET /health` returns `ok`; `GET /` returns the
  HTML host page and the SPA renders.

## Risks / open questions

- Exact `lustre_dev_tools` build command/output names and whether it needs
  network access (esbuild download) during the Docker build — resolved during
  implementation; fall back to a non-minified `gleam build` + manual bundle if
  needed.
- Slim Erlang runtime image must match the OTP version used to build the
  shipment (Erlang 29).
