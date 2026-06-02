# syntax=docker/dockerfile:1

# Royal Shortener runs as a single image: the Gleam (BEAM) backend serves the
# compiled Lustre frontend bundle plus the API/health routes.
#
# The same Gleam image is used for every stage on purpose: the Erlang shipment
# produced in the backend stage must be run on the same Erlang/OTP major version
# it was built with, otherwise the release fails to boot.

ARG GLEAM_VERSION=v1.17.0
ARG GLEAM_IMAGE=ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-erlang-alpine

# ---- Stage 1: build the Lustre frontend into a JS bundle + index.html --------
FROM ${GLEAM_IMAGE} AS frontend

WORKDIR /build/frontend

# Download dependencies first so they stay cached across source changes.
COPY frontend/gleam.toml frontend/manifest.toml ./
RUN gleam deps download

COPY frontend/ ./
# Produces ./dist/{frontend.js,index.html}. The outdir is resolved relative to
# the project root by lustre_dev_tools. lustre_dev_tools fetches the Bun bundler
# over the network during this step.
RUN gleam run -m lustre/dev build --minify --outdir=dist

# ---- Stage 2: build the backend Erlang release ------------------------------
FROM ${GLEAM_IMAGE} AS backend

WORKDIR /build/backend

COPY backend/gleam.toml backend/manifest.toml ./
RUN gleam deps download

COPY backend/ ./
RUN gleam export erlang-shipment

# ---- Stage 3: runtime -------------------------------------------------------
FROM ${GLEAM_IMAGE} AS runtime

WORKDIR /app

# The self-contained Erlang release.
COPY --from=backend /build/backend/build/erlang-shipment ./

# Static assets are served from the backend app's priv/static. In the shipment
# the backend app lives at ./backend, so priv resolves to ./backend/priv.
COPY --from=frontend /build/frontend/dist/ ./backend/priv/static/

# Run as an unprivileged user.
RUN addgroup -S royal && adduser -S royal -G royal \
  && chown -R royal:royal /app
USER royal

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider "http://127.0.0.1:${PORT}/health" || exit 1

CMD ["./entrypoint.sh", "run"]
