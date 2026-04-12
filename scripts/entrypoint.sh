#!/usr/bin/env bash
# entrypoint.sh — Container entrypoint for OpenCode dev containers.
#
# Handles first-run initialization and command dispatch:
#   - No args or "server": start OpenCode in server mode
#   - "bash" or "sh": start an interactive shell
#   - Anything else: exec the command directly (pass-through)
#
# Constraints:
#   - MUST NOT fail if Ollama is unreachable (Constitution I)
#   - MUST NOT fail if workspace has no git repo (Edge Case 2)
#   - MUST handle read-only workspace mounts gracefully (Model B)
#   - MUST use exec for final process (PID 1 signal handling)

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
  printf '\033[1;34m[entrypoint]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[entrypoint]\033[0m %s\n' "$*"
}

# ---------------------------------------------------------------------------
# 1. Workspace detection
# ---------------------------------------------------------------------------

WORKSPACE="${WORKSPACE:-/workspace}"
OPENCODE_PORT="${OPENCODE_PORT:-4096}"

if [ -d "$WORKSPACE" ]; then
  info "Workspace: $WORKSPACE"
elif [ -d "/projects" ]; then
  # Eclipse Che / Dev Spaces mount sources at /projects
  WORKSPACE="/projects"
  info "Workspace (Che fallback): $WORKSPACE"
elif [ -d "$HOME" ]; then
  WORKSPACE="$HOME"
  warn "No /workspace or /projects found. Using \$HOME: $WORKSPACE"
else
  WORKSPACE="$HOME"
  warn "Falling back to \$HOME: $WORKSPACE"
fi

cd "$WORKSPACE" || cd "$HOME"

# ---------------------------------------------------------------------------
# 2. Git repository check + first-run initialization
# ---------------------------------------------------------------------------

if [ -d "$WORKSPACE/.git" ]; then
  info "Git repository detected in $WORKSPACE"

  # First-run: initialize UF workspace if .uf/ doesn't exist yet
  if [ ! -d "$WORKSPACE/.uf" ]; then
    info "First run — initializing UF workspace with 'uf init' ..."
    if uf init 2>/dev/null; then
      info "UF workspace initialized."
    else
      # Graceful degradation: log but don't block startup.
      # This handles read-only mounts (Model B) and other failures.
      warn "uf init failed (read-only mount or other issue). Continuing without UF workspace."
    fi
  fi
else
  info "No git repository in $WORKSPACE — skipping uf init."
fi

# ---------------------------------------------------------------------------
# 3. Ollama connectivity check (graceful degradation per Constitution I)
# ---------------------------------------------------------------------------

if [ -n "${DEWEY_EMBEDDING_ENDPOINT:-}" ]; then
  info "Checking Ollama connectivity at $DEWEY_EMBEDDING_ENDPOINT ..."
  if curl -sf --max-time 2 "$DEWEY_EMBEDDING_ENDPOINT" >/dev/null 2>&1; then
    info "Ollama is reachable."
  else
    warn "Ollama is not reachable at $DEWEY_EMBEDDING_ENDPOINT. Dewey will run without embeddings."
  fi
else
  info "DEWEY_EMBEDDING_ENDPOINT not set — skipping Ollama check."
fi

# ---------------------------------------------------------------------------
# 4. Command dispatch — use exec for proper PID 1 signal handling
# ---------------------------------------------------------------------------

# Disable strict mode before exec — the executed process handles its own
# error semantics. set -e would cause the shell to exit on non-zero from
# the exec'd process before it can handle signals properly.
set +euo pipefail

case "${1:-}" in
  ""|server)
    info "Starting OpenCode server on port $OPENCODE_PORT ..."
    exec opencode serve --port "$OPENCODE_PORT" --hostname 0.0.0.0
    ;;
  bash|sh)
    info "Starting interactive shell ..."
    exec "$1"
    ;;
  *)
    info "Executing: $*"
    exec "$@"
    ;;
esac
