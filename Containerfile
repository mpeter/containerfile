# Containerfile — Unbound Force OpenCode Dev Container
#
# Multi-arch OCI image (linux/arm64, linux/amd64) with the full UF
# toolchain for AI-assisted development inside Podman containers.
#
# Base: Fedora 41 (pinned major version per research R1)
# Strategy: Single-stage build — agents need Go + Node.js at runtime (R2)
# User: Non-root "dev" user (R7)
#
# Build:
#   podman build -t opencode-dev -f Containerfile .
#
# Smoke test:
#   podman run --rm opencode-dev uf --version
#   podman run --rm opencode-dev whoami   # prints "dev"

FROM registry.fedoraproject.org/fedora:41

# ---------------------------------------------------------------------------
# System packages (as root) — Go is installed separately below because
# Fedora 41 ships Go 1.24 but dewey requires Go 1.25+.
# ---------------------------------------------------------------------------

RUN dnf install -y \
      nodejs \
      npm \
      git \
      gh \
      curl \
      findutils \
      procps-ng \
      which \
      tar \
      gzip \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# ---------------------------------------------------------------------------
# Install Go from official tarball (Fedora 41 ships 1.24; dewey needs 1.25+)
# ---------------------------------------------------------------------------

ARG GO_VERSION=1.25.3
RUN ARCH="$(uname -m)" \
    && case "$ARCH" in \
         x86_64)  GOARCH=amd64 ;; \
         aarch64) GOARCH=arm64 ;; \
         *)       echo "Unsupported arch: $ARCH" && exit 1 ;; \
       esac \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" \
       | tar -C /usr/local -xz \
    && ln -s /usr/local/go/bin/go /usr/local/bin/go \
    && ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# ---------------------------------------------------------------------------
# Non-root user setup (R7)
#
# Create the user early so Go/npm tool installs target the user's paths.
# System packages (dnf) are installed above as root.
# ---------------------------------------------------------------------------

RUN useradd -m -s /bin/bash dev

# ---------------------------------------------------------------------------
# Environment — set for all subsequent layers and runtime
# ---------------------------------------------------------------------------

ENV GOROOT=/usr/local/go \
    GOPATH=/home/dev/go \
    NPM_CONFIG_PREFIX=/home/dev/.npm-global \
    PATH="/usr/local/go/bin:/home/dev/go/bin:/home/dev/.npm-global/bin:/home/dev/.local/bin:$PATH" \
    DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434

# ---------------------------------------------------------------------------
# Install UF tools as dev user (go install + npm)
# ---------------------------------------------------------------------------

COPY --chown=dev:dev scripts/install-uf-tools.sh /home/dev/scripts/install-uf-tools.sh
RUN chmod +x /home/dev/scripts/install-uf-tools.sh

USER dev
RUN /home/dev/scripts/install-uf-tools.sh

# ---------------------------------------------------------------------------
# Install OpenCode via official curl installer (R6)
#
# The installer detects architecture automatically and places the binary
# in ~/.local/bin (or /usr/local/bin if running as root). We run as dev
# so it goes to ~/.local/bin which is already in PATH.
# ---------------------------------------------------------------------------

RUN curl -fsSL https://opencode.ai/install | bash

# ---------------------------------------------------------------------------
# Switch back to root briefly to copy entrypoint to a fixed location
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
