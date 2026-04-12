#!/usr/bin/env bash
# install-uf-tools.sh — Install all Unbound Force tools.
#
# Single source of truth for which tools are installed and at what
# versions. Used by both Containerfiles and the dynamic devfile's
# postStart command.
#
# Prerequisites:
#   - Go 1.24+ installed, $GOPATH set, $GOPATH/bin in $PATH
#   - Node.js 20+ and npm installed
#   - Network access
#
# Constraints:
#   - MUST NOT use Homebrew or Linuxbrew (FR-003)
#   - MUST NOT install Ollama (FR-005, Constitution I)
#   - Idempotent — safe to run multiple times
#   - Works on both arm64 and amd64

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

error() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

if ! command -v go &>/dev/null; then
  error "Go is not installed. Go 1.24+ is required."
  exit 1
fi

if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
  error "Node.js and npm are required. Node.js 20+ expected."
  exit 1
fi

GOPATH="${GOPATH:-$HOME/go}"
export GOPATH
export PATH="$GOPATH/bin:$PATH"

# ---------------------------------------------------------------------------
# Go tools — fail-fast on any install failure (Edge Case 3 from spec)
# ---------------------------------------------------------------------------

GO_TOOLS=(
  "github.com/unbound-force/unbound-force/cmd/unbound-force@latest"
  "github.com/unbound-force/dewey@latest"
  "github.com/unbound-force/replicator/cmd/replicator@latest"
  "github.com/unbound-force/gaze/cmd/gaze@latest"
  "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
  "golang.org/x/vuln/cmd/govulncheck@latest"
)

for tool in "${GO_TOOLS[@]}"; do
  info "Installing ${tool} ..."
  go install "${tool}"
done

# Create 'uf' symlink for 'unbound-force' binary
if [ -f "$GOPATH/bin/unbound-force" ] && [ ! -f "$GOPATH/bin/uf" ]; then
  info "Creating uf symlink ..."
  ln -s "$GOPATH/bin/unbound-force" "$GOPATH/bin/uf"
fi

# ---------------------------------------------------------------------------
# OpenSpec CLI via npm
# ---------------------------------------------------------------------------

# Configure npm to install global packages in user home (avoids EACCES on /usr/local)
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
mkdir -p "$NPM_CONFIG_PREFIX"

info "Installing @fission-ai/openspec via npm ..."
npm install -g @fission-ai/openspec

# ---------------------------------------------------------------------------
# Version verification — print each tool for build-log visibility
# ---------------------------------------------------------------------------

info "Verifying installed tools ..."

echo ""
echo "--- Tool Versions ---"
echo ""

uf --version              || { error "uf verification failed"; exit 1; }
dewey version             || { error "dewey verification failed"; exit 1; }
replicator --version      || { error "replicator verification failed"; exit 1; }
gaze --version            || { error "gaze verification failed"; exit 1; }
golangci-lint --version   || { error "golangci-lint verification failed"; exit 1; }
govulncheck -version      || { error "govulncheck verification failed"; exit 1; }
openspec --version 2>/dev/null || openspec --help > /dev/null 2>&1 || { error "openspec verification failed"; exit 1; }

echo ""
info "All tools installed successfully."
