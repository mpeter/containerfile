# Containerfile — Unbound Force OpenCode Dev Container
#
# Multi-arch OCI image (linux/arm64, linux/amd64) with the full UF
# toolchain for AI-assisted development inside Podman containers.
#
# Base: opencode-base (Fedora 41 + Go 1.25 + system packages + dev user)
# Strategy: Single-stage build — agents need Go + Node.js at runtime
# User: Non-root "dev" user (inherited from base)
#
# Build:
#   podman build -t opencode-dev -f Containerfile .
#
# Smoke test:
#   podman run --rm opencode-dev uf --version
#   podman run --rm --entrypoint whoami opencode-dev   # prints "dev"

FROM quay.io/unbound-force/opencode-base:latest

# ---------------------------------------------------------------------------
# Install UF tools as dev user (go install + npm)
# ---------------------------------------------------------------------------

COPY --chown=dev:dev scripts/install-uf-tools.sh /home/dev/scripts/install-uf-tools.sh
RUN chmod +x /home/dev/scripts/install-uf-tools.sh
RUN /home/dev/scripts/install-uf-tools.sh

# ---------------------------------------------------------------------------
# Install OpenCode via official curl installer
# ---------------------------------------------------------------------------

RUN curl -fsSL https://opencode.ai/install | bash

# ---------------------------------------------------------------------------
# Copy entrypoint and helper scripts
# ---------------------------------------------------------------------------

USER root
COPY --chown=dev:dev scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=dev:dev scripts/extract-changes.sh /usr/local/bin/extract-changes.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/extract-changes.sh

# ---------------------------------------------------------------------------
# Final runtime configuration
# ---------------------------------------------------------------------------

USER dev
WORKDIR /home/dev

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
