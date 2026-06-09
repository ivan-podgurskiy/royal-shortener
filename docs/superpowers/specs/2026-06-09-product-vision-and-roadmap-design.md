# Royal Shortener — Product Vision & Roadmap

Date: 2026-06-09
Status: Approved (design), pending implementation

This document is the single source of truth for *what* Royal Shortener is, who
it's for, and *in what order* we build it. It supersedes any implicit scope
hidden in the landing page copy and complements the containerization spec
(`2026-06-02-containerize-royal-shortener-design.md`), which is now done (M0).

---

## 1. Vision

Royal Shortener is a portfolio project that demonstrates the Gleam/BEAM stack
can deliver a publishable product end-to-end: a Lustre SPA frontend, a
wisp/mist OTP backend, a single-image build, non-decorative analytics, and
modest link protection. The aesthetic is a "royal" landing page that does not
lie — every promise on the landing is backed by a working endpoint. Evolution
into a SaaS is not a design driver for the MVP, but the MVP does not preclude
it either.

## 2. Target users

- **Guest (anonymous).** Shortens a URL, optionally with a custom slug,
  expiry, and click limit; gets a QR. The creation response returns a `secret`
  token — the only way to manage the link or view its stats without an
  account.
- **Logged-in user.** Sees a dashboard listing their links and aggregate
  analytics. Anonymous links the frontend remembered in `localStorage` are
  automatically claimed on login.

## 3. Success criteria ("portfolio ready")

1. `docker compose up` locally stands the whole stack up; everything works.
2. All four landing-page features are functional, not decorative:
   shorten/redirect, vanity slug, real QR, expiry + click limit.
3. Anonymous mode works via the `secret` token; optional login gives a
   dashboard.
4. Analytics shows real clicks with geo (country) and device class
   (`mobile` | `desktop` | `bot`).
5. Tests cover the critical paths: link creation, redirect under expiry /
   click-limit conditions, analytics ingestion.
6. README plus a short demo video/GIF in the repo.

Public deploy is **not** part of "portfolio ready" — it is M6, a separate
milestone.

## 4. Non-goals (out of MVP scope)

- Custom domains (`brand.example.com`) — multi-tenant DNS + ACME.
- Password-protected links (hashing, separate prompt page, error handling).
- Billing, pricing tiers, quotas.
- Email digests, exported reports.
- Postgres migration.
- Mobile app.

These live in the Backlog (§ 8) and are explicitly deferred so the MVP stays
finishable.

---

## 5. Architecture

- **Frontend** — the existing Lustre SPA, extended with `/dashboard`,
  `/stats/:slug`, `/login`, `/signup`. The SPA persists `{slug, secret}` pairs
  for anonymous links in `localStorage` so they can be claimed on login.
- **Backend** — wisp + mist (as today), gaining:
  - **storage** — SQLite via `sqlight`, file lives in a mounted volume.
  - **router** — grows to host `/api/*` (CRUD), `/:slug` (redirect, top-level
    so slugs don't collide with `/api`, `/health`, `/dashboard`, `/stats`,
    `/login`, `/signup`), plus HTML pages and static assets as today.
  - **OTP supervisor** — a `gleam_otp` worker runs a periodic purge for
    expired links (soft-delete or hard-delete TBD in M2's plan).
  - **GeoIP** — MaxMind GeoLite2-Country (mmdb), bundled in the image or
    mounted via volume.
  - **UA classification** — simple pattern matching to `mobile` / `desktop` /
    `bot`. No full UA-parser dependency.
- **Redirect — the hot path.** Expiry and click-limit are enforced by a single
  atomic SQL statement:

  ```sql
  UPDATE links
  SET click_count = click_count + 1
  WHERE slug = ?
    AND (click_limit IS NULL OR click_count < click_limit)
    AND (expires_at IS NULL OR expires_at > unixepoch())
  RETURNING target_url
  ```

  Zero rows ⇒ `410 Gone`. One row ⇒ `302` to `target_url`.

- **Analytics — off the hot path.** The `click` event is written *after* the
  redirect response is sent, in a separate process (fire-and-forget). The
  redirect never waits for geo/UA lookups.

## 6. Data model (SQLite)

```sql
CREATE TABLE links (
  id            INTEGER PRIMARY KEY,
  slug          TEXT NOT NULL UNIQUE,
  target_url    TEXT NOT NULL,
  secret        TEXT NOT NULL,            -- 32 hex chars; anonymous management token
  owner_user_id INTEGER NULL REFERENCES users(id),
  expires_at    INTEGER NULL,             -- unix seconds
  click_limit   INTEGER NULL,
  click_count   INTEGER NOT NULL DEFAULT 0,
  created_at    INTEGER NOT NULL
);

CREATE TABLE clicks (
  id           INTEGER PRIMARY KEY,
  link_id      INTEGER NOT NULL REFERENCES links(id),
  at           INTEGER NOT NULL,          -- unix seconds
  referrer     TEXT NULL,
  country      TEXT NULL,                 -- ISO 3166-1 alpha-2
  device_class TEXT NOT NULL              -- 'mobile' | 'desktop' | 'bot'
);

CREATE TABLE users (
  id            INTEGER PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,            -- argon2
  created_at    INTEGER NOT NULL
);

CREATE TABLE sessions (
  token       TEXT PRIMARY KEY,            -- httpOnly cookie value
  user_id     INTEGER NOT NULL REFERENCES users(id),
  expires_at  INTEGER NOT NULL
);
```

Indexes: `links(slug)` is unique (the `UNIQUE` constraint creates this
automatically), `clicks(link_id, at)`, `links(owner_user_id) WHERE
owner_user_id IS NOT NULL`.

## 7. Roadmap

Each milestone is a **vertical slice** — backend + frontend together, shippable
and demo-able on its own. Not "all backend first, then all frontend".

### M0 — Containerization ✅

Single multi-stage Docker image serving SPA + `/health`. Done in
`2026-06-02-containerize-royal-shortener-design.md`.

### M1 — Core: shorten + redirect + SQLite (anonymous)

The minimum honest path from the landing form to a `302`.

Acceptance:
- SQLite + initial migrations; `links` table with `slug, target_url, secret,
  click_count, created_at`.
- `POST /api/links {url, slug?}` → `201 {slug, short_url, secret}`. Slug
  conflict ⇒ `409`. URL is validated. Reserved slugs (`api`, `health`,
  `dashboard`, `stats`, `login`, `signup`, plus any future top-level routes)
  are rejected on both random generation and user input.
- `GET /:slug` → `302` to `target_url`. Unknown slug ⇒ `404`.
- The landing-page form calls the real API (currently UI-only).
- After creation the UI shows the `short_url` *and* the `secret`, framed as
  "this is your management key — save it".
- Tests: shorten happy path, slug collision, redirect, 404 on unknown slug.

### M2 — Protection: expiry + click limit

Delivers the "Guarded by Decree" promise minus passwords (Backlog).

Acceptance:
- `expires_at` and `click_limit` columns added to `links`.
- Creation form takes "expires in" (presets: 1h / 24h / 7d / never) and
  "click limit".
- Redirect uses the **single atomic SQL** from § 5 to check + increment.
- An expired or exhausted link returns `410 Gone` with a dedicated HTML page
  ("this link has been revoked").
- Test: N concurrent redirects against a link with `click_limit = 1` —
  exactly one succeeds.
- Tests on the expiry boundary.

### M3 — Real QR

Replaces the faux QR seal in `frontend/src/royal/data.gleam`.

Acceptance:
- `GET /api/links/:slug/qr` → PNG (or SVG) for the short URL. Public — it's a
  link, after all.
- "Download QR" button on the post-creation result page.
- The faux seal stays on the landing as decorative pattern, but the creation
  result shows a real QR.
- Library choice (Gleam-side `gleam_qr` if it exists, JS-side `qrcode-svg`,
  or hand-rolled) is decided in M3's implementation plan.

### M4 — Analytics

The "Royal Ledger" promise, non-decoratively.

Acceptance:
- `clicks` table; redirect handler writes events fire-and-forget (does not
  block the `302`).
- GeoIP via MaxMind GeoLite2-Country mmdb; country resolved from the request
  IP (taking `X-Forwarded-For` into account when behind a proxy).
- UA → `device_class` (`mobile` | `desktop` | `bot`) via pattern matching.
- `GET /api/links/:slug/stats?secret=...` → aggregates: total clicks,
  breakdown by country, breakdown by device class, hourly buckets for the
  last 24h, daily buckets for the last 30d.
- Page `/stats/:slug` — table + minimal charts (start text/SVG-based; full
  chart library only if cheap).
- Tests: event ingest, aggregation correctness, `secret` enforcement.

### M5 — Accounts + dashboard (MVP complete after this)

The optional-login half.

Acceptance:
- `POST /api/auth/signup` (email + password); argon2 hash.
- `POST /api/auth/login` → `Set-Cookie` httpOnly session.
- `POST /api/auth/logout`.
- `GET /api/me/links` — current user's links.
- `POST /api/me/claim-links {pairs: [{slug, secret}]}` — verifies each secret
  and sets `owner_user_id` to the current user. Wrong secrets are silently
  skipped (don't leak existence).
- Frontend: `/login`, `/signup`, `/dashboard` with link list + per-link
  summary stats.
- On successful login, the frontend reads `{slug, secret}` pairs from
  `localStorage` and calls `claim-links` automatically.
- Tests: signup, login, session middleware, claim flow.

**MVP is done after M5.** `docker compose up` locally → all four landing
features real.

### M6 (post-MVP) — Public deploy on VPS

Acceptance:
- `docker-compose.yml` with reverse proxy (Caddy → automatic Let's Encrypt) +
  the shortener service + a volume for SQLite + a volume (or baked layer) for
  the mmdb.
- Deploy instructions in the README.
- Demo domain.

## 8. Backlog (post-MVP, priority order)

1. Password-protected links.
2. Per-IP rate limiting on the creation API.
3. Bulk export of one's own links (CSV).
4. API keys (programmatic creation).
5. Custom domains (multi-tenant + ACME).
6. Postgres migration.
7. Billing / pricing tiers.

## 9. Open questions for later milestones

- **Expired-link purge policy** — soft-delete (keep rows for stats history)
  vs hard-delete (free the slug). Decided in M2's plan.
- **QR library choice** — see M3 acceptance.
- **Chart rendering on `/stats/:slug`** — pure SVG vs a small JS library.
  Decided in M4's plan.
- **Email verification on signup** — currently out of MVP scope (no SMTP
  dependency). Revisit if/when the project pivots toward SaaS.
