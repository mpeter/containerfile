# AGENTS.md

## Project Overview

Container image definitions and orchestration for running
OpenCode and the full Unbound Force toolchain inside
Podman containers. Security through isolation — if an
agent goes off the rails, the blast radius is contained.

- **Type**: Infrastructure / container definitions (no application code)
- **Artifacts**: Containerfiles, devfiles, shell scripts, CI workflows, compose files
- **Platforms**: macOS arm64, Fedora amd64, Eclipse Che / Red Hat Dev Spaces
- **Image registry**: `quay.io/unbound-force/opencode-dev`
- **License**: Apache 2.0

## What This Repo Contains

No Go code, no compiled binaries, no test suites. The
deliverables are:

| File | Purpose |
|------|---------|
| `Containerfile` | Multi-arch OCI image (Fedora base) |
| `Containerfile.udi` | CDE variant (UDI base) |
| `devfile.yaml` | Eclipse Che workspace (custom image) |
| `devfile-dynamic.yaml` | Eclipse Che workspace (UDI + postStart) |
| `scripts/install-uf-tools.sh` | Install all UF tools via `go install` |
| `scripts/entrypoint.sh` | Container entrypoint |
| `scripts/extract-changes.sh` | Git format-patch extraction |
| `scripts/connect.sh` | Host-side attach script |
| `podman-compose.yml` | Headless server orchestration |
| `.github/workflows/build-push.yml` | CI: multi-arch build + push to quay.io |

## Validation

There is no `go test` or `npm test`. Validation is:

```bash
# Build the image locally
podman build -t opencode-dev -f Containerfile .

# Verify tools are present
podman run --rm opencode-dev uf --version
podman run --rm opencode-dev opencode --version
podman run --rm opencode-dev dewey --version
podman run --rm opencode-dev replicator --version
podman run --rm opencode-dev gaze --version

# Verify non-root user
podman run --rm opencode-dev whoami   # should print "dev"
```

For the UDI variant:
```bash
podman build -t opencode-dev-udi -f Containerfile.udi .
```

## Architecture Constraints

- **Ollama stays on host** — container connects via
  `DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434`.
  Do NOT install Ollama in the container.
- **Tools via `go install`** — no Homebrew/Linuxbrew in container.
  Use `dnf` for system packages, `go install` for Go tools,
  `curl` for OpenCode, `npm` for OpenSpec CLI.
- **Non-root user** — container runs as `dev`, not root.
- **Multi-arch** — all images must build for both
  `linux/arm64` and `linux/amd64`.
- **SELinux** — volume mounts on Fedora use `:Z` relabeling.

## Security Model

These constraints are non-negotiable:

1. No SSH keys or git push tokens inside the container
2. Podman rootless (no daemon, user namespace isolation)
3. Resource limits: `--memory 8g --cpus 4`
4. Read-only source mount for headless mode (Model B)
5. Change extraction via `git format-patch`, not direct writes

## Behavioral Constraints

- **Zero-Waste Mandate**: No unused scripts, dead
  configuration, or placeholder files.
- **Executable Truth**: If a Containerfile instruction
  and a README description conflict, fix the README.
  The Containerfile is the source of truth.
- **Verify Builds**: After any Containerfile change,
  build and run the smoke test commands above before
  considering the task complete.

## Specification Framework

This project uses a two-tier specification framework:

| Tier | Tool | When to Use | Location |
|------|------|-------------|----------|
| Strategic | Speckit | 3+ stories, architecture | `specs/NNN-*/` |
| Tactical | OpenSpec | <3 stories, bug fix | `openspec/changes/` |

### Branch Conventions

- **Speckit**: `NNN-<short-name>` (e.g., `001-initial-containerfile`)
- **OpenSpec**: `opsx/<change-name>` (e.g., `opsx/fix-entrypoint`)

### Ordering Constraints

1. Constitution must exist before specs.
2. Spec before plan. Plan before tasks.
3. Tasks before implementation.

## Knowledge Retrieval

Dewey MCP server is configured in `opencode.json` and
indexes all sibling repos (dewey, gaze, replicator,
unbound-force, website) plus GitHub issues/PRs.

Prefer Dewey tools over grep for cross-repo context:

| Query Intent | Dewey Tool |
|-------------|-----------|
| Conceptual search | `dewey_semantic_search` |
| Keyword lookup | `dewey_search` |
| Read specific page | `dewey_get_page` |
| Relationship discovery | `dewey_find_connections` |
| Filtered search | `dewey_semantic_search_filtered` |

**3-Tier Degradation**: Full Dewey > graph-only (no
embeddings) > direct file reads. All tiers produce
valid results.

## Git & Workflow

- **Commit format**: Conventional Commits —
  `type: description` (feat, fix, docs, chore).
- **Branching**: Feature branches required.
- **Code review**: Required before merge.

## Sibling Repositories

| Repo | Purpose |
|------|---------|
| `unbound-force/unbound-force` | Meta repo: specs, constitution, scaffold CLI |
| `unbound-force/dewey` | Semantic knowledge layer (MCP server) |
| `unbound-force/replicator` | Multi-agent coordination (MCP server) |
| `unbound-force/gaze` | Go static analysis |
| `unbound-force/website` | Public website (Hugo + Doks) |
| `unbound-force/homebrew-tap` | Homebrew formula distribution |

## Design Reference

- [Discussion #88](https://github.com/orgs/unbound-force/discussions/88) — full architecture and design rationale
- [Issue #1](https://github.com/unbound-force/containerfile/issues/1) — implementation issue with all deliverables
