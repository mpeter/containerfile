# Implementation Plan: Initial Containerfile, Devfile, and Scripts

**Branch**: `001-initial-containerfile` | **Date**: 2026-04-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-initial-containerfile/spec.md`

## Summary

Create the complete container infrastructure for running OpenCode and the
full Unbound Force toolchain inside Podman containers. The deliverables are
two Containerfiles (Fedora-based and UDI-based), two devfiles for Eclipse
Che, four helper scripts (install, entrypoint, extract, connect), a
podman-compose orchestration file, a GitHub Actions CI workflow, and a
README documenting all three deployment models. The technical approach uses
Fedora as the base image with `go install` for Go tools, `curl` for
OpenCode, `npm` for OpenSpec CLI, and `dnf` for system packages — no
Homebrew. All images are multi-arch (arm64 + amd64) and run as a non-root
`dev` user.

## Technical Context

**Language/Version**: Shell scripts (bash), Containerfile (OCI/Docker syntax), YAML (devfile 2.2.0, compose, GitHub Actions)
**Primary Dependencies**: Podman, Go 1.24+, Node.js 20+, npm, Git, gh CLI
**Storage**: N/A (container images, not database)
**Testing**: `podman build` + smoke test commands (`uf --version`, `opencode --version`, `dewey --version`, `replicator --version`, `gaze --version`, `whoami`). No `go test` or `npm test`.
**Target Platform**: linux/arm64 + linux/amd64 (multi-arch OCI images)
**Project Type**: Infrastructure / container definitions (no application code)
**Performance Goals**: Image build < 15 min per arch, container startup < 30 sec
**Constraints**: Non-root user (`dev`), no secrets in image, multi-arch required, Ollama on host only, Podman rootless only, SELinux `:Z` mounts on Fedora
**Scale/Scope**: 2 Containerfiles, 2 devfiles, 4 scripts, 1 compose file, 1 CI workflow, 1 README

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Composability First — PASS

- **Image standalone**: The image delivers its core value (OpenCode + UF
  toolchain) when deployed with only Podman and a project directory. No
  external services are required for primary operation.
- **Ollama on host**: The container connects via
  `DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434`.
  Ollama is NOT installed in the container (FR-005).
- **Graceful degradation**: When Ollama is unavailable, the container
  starts and operates with reduced capability. Dewey embeddings degrade
  but all other tools remain functional (Edge Case 1).
- **Tool independence**: Each tool (uf, OpenCode, Dewey, Replicator,
  Gaze) is independently functional. One tool's failure does not break
  others.

### II. Security Through Isolation — PASS

- **Non-root user**: Container runs as `dev`, not root (FR-004).
- **No secrets**: No SSH keys, git push tokens, or API keys baked into
  the image (FR-019). Secrets injected at runtime.
- **Read-only mounts**: Headless mode (Model B) uses read-only source
  mounts (FR-021). Changes extracted via `git format-patch` only.
- **Resource limits**: 8G memory, 4 CPUs enforced in compose and devfile
  (FR-020).
- **Podman rootless**: Only supported runtime mode. No Docker daemon.

### III. Reproducible Builds — PASS

- **Multi-arch**: All images build for both `linux/arm64` and
  `linux/amd64` (FR-001).
- **Pinned versions**: Go 1.24+, Node.js 20+, Fedora base image version
  pinned. Tool installation via `go install @latest` (latest available
  version at build time; see `contracts/install-uf-tools.md` Version
  Pinning Trade-Off for rationale).
- **Smoke tests**: Every image passes the smoke test suite from
  AGENTS.md (SC-002).
- **CI publishing**: GitHub Actions builds and pushes to
  `quay.io/unbound-force/opencode-dev` on every push to main (FR-017).

### IV. Executable Truth — PASS

- **Containerfile is truth**: When Containerfile and README conflict,
  the README is fixed (Behavioral Constraint).
- **Zero-waste**: Every file serves a purpose traceable to a deliverable.
  No unused scripts, dead configuration, or placeholder files.
- **Build verification**: After any Containerfile change, the image is
  built locally and smoke tests pass before the task is complete.
- **Script traceability**: Every script is referenced by a Containerfile
  or compose file. Unreferenced scripts are removed.

## Project Structure

### Documentation (this feature)

```text
specs/001-initial-containerfile/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (key entities)
├── quickstart.md        # Phase 1 output (deployment guides)
├── contracts/           # Phase 1 output (script contracts)
│   ├── install-uf-tools.md
│   ├── entrypoint.md
│   ├── extract-changes.md
│   └── connect.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (already exists)
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
.
├── Containerfile              # Primary multi-arch image (Fedora base)
├── Containerfile.udi          # CDE variant (UDI base)
├── devfile.yaml               # Eclipse Che workspace (custom image)
├── devfile-dynamic.yaml       # Eclipse Che workspace (UDI + postStart)
├── podman-compose.yml         # Headless server orchestration
├── scripts/
│   ├── install-uf-tools.sh    # Install all UF tools via go install
│   ├── entrypoint.sh          # Container entrypoint
│   ├── extract-changes.sh     # Git format-patch extraction
│   └── connect.sh             # Host-side attach script
├── .github/
│   └── workflows/
│       └── build-push.yml     # CI: multi-arch build + push to quay.io
├── README.md                  # All deployment models, security, prerequisites
├── AGENTS.md                  # Agent context (already exists)
├── LICENSE                    # Apache 2.0 (already exists)
└── opencode.json              # OpenCode config (already exists)
```

**Structure Decision**: Flat layout at repository root. No `src/` or
`tests/` directories — this is an infrastructure project, not an
application. Containerfiles live at the root (OCI convention). Scripts
live in `scripts/` for organization. CI lives in `.github/workflows/`
(GitHub convention). This matches the deliverable table in AGENTS.md.

## Complexity Tracking

> No constitution violations. All four principles pass without exception.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | — | — |
