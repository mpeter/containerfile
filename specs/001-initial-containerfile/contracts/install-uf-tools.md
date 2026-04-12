# Contract: install-uf-tools.sh

**Path**: `scripts/install-uf-tools.sh`
**Runs on**: Container (during image build or devfile postStart)
**Referenced by**: `Containerfile`, `Containerfile.udi`, `devfile-dynamic.yaml`
**Requirements**: FR-002, FR-003, FR-012

## Purpose

Install all Unbound Force Go tools via `go install`. This script is
the single source of truth for which tools are installed and at what
versions. It is used by both Containerfiles and the dynamic devfile's
postStart command.

## Interface

**Inputs**:
- Environment: `$GOPATH` must be set (defaults to `$HOME/go`)
- Environment: `$PATH` must include `$GOPATH/bin`
- Prerequisite: Go 1.24+ must be installed
- Prerequisite: Node.js 20+ and npm must be installed (for OpenSpec CLI)
- Prerequisite: Network access (downloads Go modules and npm packages)

**Outputs**:
- Binaries in `$GOPATH/bin`: `uf`, `dewey`, `replicator`, `gaze`,
  `golangci-lint`, `govulncheck`
- Binary via npm: `openspec` (OpenSpec CLI)
- Exit code 0 on success, non-zero on any failure

**Side effects**:
- Downloads Go modules to `$GOPATH/pkg/mod`
- Downloads npm packages globally

## Behavior

1. Install each Go tool via `go install`:
   - `github.com/unbound-force/unbound-force/cmd/uf@latest`
   - `github.com/unbound-force/dewey/cmd/dewey@latest`
   - `github.com/unbound-force/replicator/cmd/replicator@latest`
   - `github.com/unbound-force/gaze/cmd/gaze@latest`
   - `github.com/golangci/golangci-lint/cmd/golangci-lint@latest`
   - `golang.org/x/vuln/cmd/govulncheck@latest`

2. Install OpenSpec CLI via npm:
   - `npm install -g @openspec/cli`

3. **Fail-fast**: If any `go install` or `npm install` fails, the
   script MUST exit immediately with a non-zero exit code. Partial
   tool installation is not acceptable (Edge Case 3 from spec).

4. Print each tool name and version after successful installation
   for build log visibility.

## Constraints

- MUST NOT use Homebrew or Linuxbrew (FR-003, Architecture Constraint).
- MUST NOT install Ollama (FR-005, Constitution I).
- MUST be idempotent — safe to run multiple times.
- MUST work on both arm64 and amd64 architectures.
- MUST use `set -euo pipefail` for strict error handling.

## Version Pinning Trade-Off

All Go tools use `@latest` rather than pinned versions. This is a
conscious trade-off: UF tools do not yet have a stable release cadence,
and pinning to specific versions would require manual bumps for every
upstream release. The `@latest` approach ensures the container image
always includes the most recent tool versions. This means builds are
not perfectly reproducible across time — two builds on different days
may install different tool versions. This trade-off is acceptable
because:

1. The smoke test suite (tool `--version` checks) validates that all
   tools are present and functional after every build.
2. CI builds are triggered on every push to main, so version drift is
   detected quickly.
3. Once UF tools reach v1.0 with stable release cadences, this script
   SHOULD be updated to pin specific versions (e.g.,
   `@v1.2.3` instead of `@latest`).

## Validation

```bash
# After running the script:
uf --version          # must succeed
dewey --version       # must succeed
replicator --version  # must succeed
gaze --version        # must succeed
golangci-lint --version  # must succeed
govulncheck -version  # must succeed
openspec --version    # must succeed (or openspec --help)
```
