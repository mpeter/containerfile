# Data Model: Initial Containerfile

**Phase**: 1 — Design & Contracts
**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

> **Note**: This is an infrastructure project, not an application. There
> are no database tables, API schemas, or domain objects. The "data model"
> describes the key entities that the container infrastructure produces
> and consumes.

## Entities

### Container Image

The primary OCI artifact published to quay.io. Two variants exist.

| Field | Type | Description |
|-------|------|-------------|
| name | string | `opencode-dev` (primary) or `opencode-dev-udi` (CDE) |
| registry | URL | `quay.io/unbound-force/opencode-dev` |
| base_image | string | `registry.fedoraproject.org/fedora:41` (primary) or `quay.io/devfile/universal-developer-image:latest` (UDI) |
| architectures | list | `[linux/arm64, linux/amd64]` |
| user | string | `dev` (primary) or `user` (UDI, inherited) |
| tools | list | `[uf, opencode, dewey, replicator, gaze, go, node, npm, git, gh, golangci-lint, govulncheck, openspec]` |
| env.DEWEY_EMBEDDING_ENDPOINT | URL | `http://host.containers.internal:11434` |
| env.GOPATH | path | `/home/dev/go` (primary) |
| env.PATH | path | Includes `$GOPATH/bin`, `/usr/local/go/bin`, node bin |

**Invariants**:
- Ollama is NEVER installed in the image.
- No secrets (SSH keys, tokens, API keys) are present.
- The final `USER` instruction is always non-root.
- All tools pass `--version` smoke tests.

### Devfile

Eclipse Che workspace definition conforming to Devfile 2.2.0.

| Field | Type | Description |
|-------|------|-------------|
| schemaVersion | string | `2.2.0` |
| metadata.name | string | `opencode-dev` or `opencode-dev-dynamic` |
| components[].container.image | string | Custom image or UDI |
| components[].container.memoryLimit | string | `8Gi` |
| components[].container.cpuLimit | string | `4` |
| components[].container.mountSources | bool | `true` |
| components[].container.endpoints[] | object | OpenCode server on port 4096 |
| commands[] | object | postStart hooks (dynamic variant only) |
| events.postStart | list | Command IDs to run at workspace start |

**Variants**:
- `devfile.yaml`: Uses custom image. Fast startup, no postStart install.
- `devfile-dynamic.yaml`: Uses UDI. Slower startup, installs tools via
  postStart. No custom image dependency.

### Deployment Model

One of three modes for running the container. Each has different
security properties and use cases.

| Model | Mount | Security | Use Case |
|-------|-------|----------|----------|
| Interactive (Model A) | Read-write (`-v ./project:/workspace:Z`) | Agent can modify host files directly | Local development, trusted agent |
| Headless (Model B) | Read-only (`-v ./project:/workspace:ro,Z`) | Agent cannot modify host files; changes via `git format-patch` | Maximum isolation, untrusted agent |
| CDE (Model C) | Eclipse Che managed | Workspace-level isolation | Cloud development, team environments |

**Invariants**:
- All models enforce resource limits (8G memory, 4 CPUs).
- All models set `DEWEY_EMBEDDING_ENDPOINT` for host Ollama.
- Model B MUST use read-only source mount.
- Model B extracts changes via `git format-patch` only.

### Script

Shell scripts that support container lifecycle operations.

| Script | Runs On | Purpose | Inputs | Outputs |
|--------|---------|---------|--------|---------|
| `install-uf-tools.sh` | Container (build or postStart) | Install all UF Go tools | None (uses env vars) | Tools in `$GOPATH/bin` |
| `entrypoint.sh` | Container (runtime) | First-run init + OpenCode server start | `$1` (command), env vars | Running OpenCode server or shell |
| `extract-changes.sh` | Container (runtime) | Export agent changes as patches | Working directory with git repo | Patch files on stdout or in output dir |
| `connect.sh` | Host | Start container and attach via OpenCode | Project path argument | Running container + attached session |

## Relationships

```text
Container Image
├── uses → install-uf-tools.sh (during build)
├── uses → entrypoint.sh (at runtime)
├── referenced by → devfile.yaml (custom image variant)
├── referenced by → podman-compose.yml (headless mode)
└── published to → quay.io (via CI workflow)

Devfile
├── devfile.yaml → references Container Image
└── devfile-dynamic.yaml → references UDI + install-uf-tools.sh

Deployment Model
├── Interactive → podman run (manual)
├── Headless → podman-compose.yml
└── CDE → devfile.yaml or devfile-dynamic.yaml

CI Workflow
├── builds → Container Image (both architectures)
├── runs → smoke tests
└── pushes → quay.io registry
```
