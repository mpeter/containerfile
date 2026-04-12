#!/usr/bin/env bash
# connect.sh — Start a container and attach via opencode attach.
#
# Host-side convenience script for headless server mode (Model B).
# Handles container lifecycle: start if not running, wait for health,
# then attach.
#
# Usage:
#   connect.sh [project-dir] [container-name]
#
# Arguments:
#   $1 (optional): Path to the project directory to mount.
#                  Defaults to the current directory.
#   $2 (optional): Container name. Defaults to "opencode-server".
#
# Environment:
#   OPENCODE_IMAGE: Image to use (default: quay.io/unbound-force/opencode-dev:latest)
#
# Constraints:
#   - Runs on the HOST, not inside the container
#   - Uses Podman (not Docker) — Architecture Constraint
#   - Resource limits: 8G memory, 4 CPUs (FR-020)
#   - SELinux-compatible :Z volume mounts

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
  printf '\033[1;34m[connect]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[connect]\033[0m %s\n' "$*"
}

error() {
  printf '\033[1;31m[connect]\033[0m %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# 1. Pre-flight: verify Podman is installed
# ---------------------------------------------------------------------------

if ! command -v podman &>/dev/null; then
  error "Podman is required but not installed."
  error "Install Podman: https://podman.io/getting-started/installation"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Parse arguments and set defaults
# ---------------------------------------------------------------------------

PROJECT_DIR="${1:-.}"
CONTAINER_NAME="${2:-opencode-server}"
OPENCODE_IMAGE="${OPENCODE_IMAGE:-quay.io/unbound-force/opencode-dev:latest}"
OPENCODE_PORT=4096
HEALTH_TIMEOUT=30

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

info "Project directory: $PROJECT_DIR"
info "Container name: $CONTAINER_NAME"
info "Image: $OPENCODE_IMAGE"

# ---------------------------------------------------------------------------
# 3. Check if container is already running
# ---------------------------------------------------------------------------

if podman ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
  info "Container '$CONTAINER_NAME' is already running."
else
  info "Container '$CONTAINER_NAME' is not running. Starting ..."

  # Check if a podman-compose.yml exists in the project directory
  if [ -f "$PROJECT_DIR/podman-compose.yml" ]; then
    info "Found podman-compose.yml — using podman-compose up -d"
    if command -v podman-compose &>/dev/null; then
      podman-compose -f "$PROJECT_DIR/podman-compose.yml" up -d
    else
      warn "podman-compose not found. Falling back to podman run."
      podman run -d \
        --name "$CONTAINER_NAME" \
        --memory 8g --cpus 4 \
        -p "${OPENCODE_PORT}:${OPENCODE_PORT}" \
        -v "${PROJECT_DIR}:/workspace:ro,Z" \
        -e DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434 \
        "$OPENCODE_IMAGE" \
        server
    fi
  else
    info "No podman-compose.yml found — using podman run"
    podman run -d \
      --name "$CONTAINER_NAME" \
      --memory 8g --cpus 4 \
      -p "${OPENCODE_PORT}:${OPENCODE_PORT}" \
      -v "${PROJECT_DIR}:/workspace:ro,Z" \
      -e DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434 \
      "$OPENCODE_IMAGE" \
      server
  fi
fi

# ---------------------------------------------------------------------------
# 4. Wait for OpenCode health endpoint (30s timeout with retries)
# ---------------------------------------------------------------------------

info "Waiting for OpenCode server at localhost:${OPENCODE_PORT} (timeout: ${HEALTH_TIMEOUT}s) ..."

elapsed=0
while [ "$elapsed" -lt "$HEALTH_TIMEOUT" ]; do
  if curl -sf --max-time 2 "http://localhost:${OPENCODE_PORT}" >/dev/null 2>&1; then
    info "OpenCode server is ready."
    break
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

if [ "$elapsed" -ge "$HEALTH_TIMEOUT" ]; then
  error "OpenCode server did not become ready within ${HEALTH_TIMEOUT}s."
  error "Check container logs: podman logs $CONTAINER_NAME"
  exit 1
fi

# ---------------------------------------------------------------------------
# 5. Attach to the OpenCode server
# ---------------------------------------------------------------------------

info "Attaching to OpenCode server ..."
opencode attach

# ---------------------------------------------------------------------------
# 6. Cleanup guidance (printed after detaching)
# ---------------------------------------------------------------------------

echo ""
info "Detached from OpenCode server."
info ""
info "The container '$CONTAINER_NAME' is still running."
info "To extract changes:  podman exec $CONTAINER_NAME /usr/local/bin/extract-changes.sh"
info "To stop:             podman stop $CONTAINER_NAME && podman rm $CONTAINER_NAME"
if [ -f "$PROJECT_DIR/podman-compose.yml" ]; then
  info "Or:                  podman-compose -f $PROJECT_DIR/podman-compose.yml down"
fi
