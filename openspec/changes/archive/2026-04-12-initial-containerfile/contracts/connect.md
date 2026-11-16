# Contract: connect.sh

**Path**: `scripts/connect.sh`
**Runs on**: Host (developer's machine)
**Referenced by**: README.md (documented for developer use)
**Requirements**: FR-015

## Purpose

Convenience script for the developer to start a container and attach
to it via `opencode attach`. This is the host-side companion to the
headless server mode. It handles container lifecycle (start if not
running) and establishes the OpenCode session.

## Interface

**Inputs**:
- `$1` (optional): Path to the project directory to mount. Defaults
  to the current directory (`.`).
- `$2` (optional): Container name. Defaults to `opencode-server`.
- Environment: `$OPENCODE_IMAGE` (default:
  `quay.io/unbound-force/opencode-dev:latest`) — image to use.

**Outputs**:
- A running container with OpenCode server (if not already running)
- An attached OpenCode session in the terminal
- Exit code from `opencode attach`

**Side effects**:
- May start a new container via `podman run` or `podman-compose up`
- Attaches to the container's OpenCode server

## Behavior

1. **Check if container is running**: Use `podman ps` to check if a
   container with the specified name is already running.

2. **Start if needed**: If the container is not running:
   a. If `podman-compose.yml` exists in the project directory, use
      `podman-compose up -d`.
   b. Otherwise, start with `podman run -d` with appropriate flags
      (resource limits, volume mount, Ollama endpoint, port mapping).

3. **Wait for readiness**: Poll the OpenCode server health endpoint
   (port 4096) until it responds or timeout (30 seconds).

4. **Attach**: Run `opencode attach` to connect to the server.

5. **Cleanup guidance**: After detaching, print a message about how
   to stop the container (`podman-compose down` or `podman stop`).

## Constraints

- MUST run on the host, not inside the container.
- MUST use Podman, not Docker (Architecture Constraint).
- MUST apply resource limits (8G memory, 4 CPUs) when starting a
  new container (FR-020).
- MUST use `:Z` volume mount suffix for SELinux compatibility
  (Architecture Constraint).
- MUST set `DEWEY_EMBEDDING_ENDPOINT` when starting the container.
- MUST use `set -euo pipefail` for strict error handling.
- SHOULD detect if Podman is installed and print a helpful error if
  not.

## Validation

```bash
# Start and connect (project in current directory):
./scripts/connect.sh
# Should start container and attach to OpenCode

# Start with explicit project path:
./scripts/connect.sh /path/to/my-project
# Should mount that directory and connect

# Container already running:
./scripts/connect.sh
# Should skip start and attach directly

# Podman not installed:
# Should print "Podman is required but not installed" and exit 1
```
