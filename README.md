# Royal Shortener

A URL shortener with a Lustre (Gleam → JS) frontend and a Gleam (BEAM)
backend. In production the backend serves the compiled frontend bundle, the
API, and short-link redirects from a **single Docker image**.

```
royal_shortener/
├── frontend/   # Lustre SPA (Gleam, compiles to JavaScript)
├── backend/    # wisp + mist HTTP server (Gleam, runs on the BEAM)
└── Dockerfile  # multi-stage build → one production image
```

## Development

Day-to-day work does **not** use Docker. Run the two projects natively for fast feedback and live-reload.

### Frontend (primary loop)

```sh
cd frontend
gleam run -m lustre/dev start
```

Starts the Lustre dev server on http://localhost:1234 with file watching,
on-the-fly bundling, and live-reload. The UI is fully client-side, so this is
usually all you need while working on the interface.

Requests to `/api/*` are proxied to the backend on port 8080 (configured under
`[tools.lustre.dev.proxy]` in `frontend/gleam.toml`), so you develop against a
single origin once the API exists.

### Backend

```sh
cd backend
gleam run
```

Starts the wisp/mist server on http://localhost:8080. Re-running `gleam run`
recompiles incrementally. Useful environment variables:

- `PORT` — port to bind (default `8080`)
- `SECRET_KEY_BASE` — signing/encryption key (a random one is generated if unset)

### Tests

```sh
cd backend  && gleam test
cd frontend && gleam test
```

## Production (Docker)

Build and run the single image. From the repo root:

```sh
# Build
docker build -t royal-shortener:dev .

# Run (container port 8080 → host 8080)
docker run --rm -p 8080:8080 royal-shortener:dev
```

Then open http://localhost:8080 (health check at `/health`).

Useful variants:

```sh
# Different host port (8090 → 8080)
docker run --rm -p 8090:8080 royal-shortener:dev

# Override the in-container port
docker run --rm -e PORT=3000 -p 3000:3000 royal-shortener:dev

# Detached, with logs / stop
docker run -d --name royal -p 8080:8080 royal-shortener:dev
docker logs -f royal
docker stop royal && docker rm royal

# Pin the Gleam toolchain version used for the build
docker build --build-arg GLEAM_VERSION=v1.17.0 -t royal-shortener:dev .
```

### How the image is built

Multi-stage (`Dockerfile`), all stages on the same Gleam Alpine image so the
Erlang release runs on the OTP version it was compiled with:

1. Build the Lustre frontend → JS bundle + `index.html`.
2. `gleam export erlang-shipment` → self-contained Erlang release for the backend.
3. Runtime: copy the shipment + frontend bundle into `backend/priv/static`, run
   as a non-root user, expose `8080`, with a `/health` `HEALTHCHECK`.
