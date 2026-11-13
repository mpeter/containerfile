# Contract: entrypoint.sh

**Path**: `scripts/entrypoint.sh`
**Runs on**: Container (at runtime, as the ENTRYPOINT)
**Referenced by**: `Containerfile`, `Containerfile.udi`
**Requirements**: FR-013

## Purpose

Container entrypoint that handles first-run initialization and starts
OpenCode in server mode when requested. Provides a clean startup
experience whether the container is run interactively or as a headless
server.

## Interface

**Inputs**:
- `$1` (optional): Command to execute. If empty or `server`, starts
  OpenCode in server mode. If `bash` or `sh`, starts a shell. Any
  other value is executed directly via `exec "$@"`.
- Environment: `$WORKSPACE` (default: `/workspace`) — path to the
  mounted project directory.
- Environment: `$DEWEY_EMBEDDING_ENDPOINT` — Ollama endpoint URL.
- Environment: `$OPENCODE_PORT` (default: `4096`) — server listen port.

**Outputs**:
- Running OpenCode server process (server mode), or
- Interactive shell (shell mode), or
- Executed command (pass-through mode)
- Exit code from the executed process

**Side effects**:
- May run `uf init` on first startup if the workspace has a git repo
  but no `.uf/` directory.
- Creates `.uf/` directory in the workspace if `uf init` runs.

## Behavior

1. **Workspace detection**: Check if `$WORKSPACE` exists and is a
   directory. If not, print a warning and use `$HOME` as fallback.

2. **Git repository check**: If `$WORKSPACE` contains a `.git`
   directory, proceed with initialization. If not, skip `uf init`
   (Edge Case 2 from spec — no git repo).

3. **First-run initialization**: If `$WORKSPACE/.uf/` does not exist
   and a git repo is present, run `uf init` to set up the UF
   workspace. If `uf init` fails, log the error but continue — do
   not block container startup.

4. **Ollama connectivity check**: If `$DEWEY_EMBEDDING_ENDPOINT` is
   set, attempt a health check (curl with 2-second timeout). Log the
   result but do NOT fail if Ollama is unreachable (Constitution I —
   graceful degradation, Edge Case 1).

5. **Command dispatch**:
   - No arguments or `server`: Start OpenCode in server mode on
     `$OPENCODE_PORT`.
   - `bash` or `sh`: Start an interactive shell.
   - Anything else: `exec "$@"` (pass-through).

## Constraints

- MUST NOT fail if Ollama is unreachable (Constitution I).
- MUST NOT fail if the workspace has no git repo (Edge Case 2).
- MUST handle read-only workspace mounts gracefully (Model B). If
  `uf init` fails due to read-only filesystem, log and continue.
- MUST use `exec` for the final process to ensure proper signal
  handling (PID 1 behavior).
- MUST use `set -euo pipefail` for strict error handling in the
  initialization phase, but NOT for the final `exec` (which replaces
  the shell process).

## Validation

```bash
# Server mode
podman run -d --name test opencode-dev
# Verify OpenCode is listening on port 4096
podman exec test curl -s http://localhost:4096/health || true
podman rm -f test

# Shell mode
podman run --rm -it opencode-dev bash
# Should get a bash prompt

# Pass-through mode
podman run --rm opencode-dev whoami
# Should print "dev"

# No git repo
podman run --rm -v /tmp/empty:/workspace:Z opencode-dev bash -c "echo ok"
# Should not error about missing git repo
```
