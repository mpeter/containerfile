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

## Addendum: Base Image + Native Runners

**Date**: 2026-04-12 | **Requirements**: FR-022 through FR-027, SC-001 updated
**Status**: Planned — extends the original plan with 3 new deliverables

### Motivation

The current CI workflow builds the full image (system packages + Go
tarball + UF tools) on every push, using QEMU emulation for the arm64
architecture. This results in ~40 minute CI runs dominated by
QEMU-emulated `go install` commands. Two changes eliminate this:

1. **Base image layer** — Extract the slow-changing foundation (Fedora
   packages, Go tarball, user setup) into a separate base image rebuilt
   weekly. The dev image then only installs UF Go tools on top, cutting
   build time from ~15 min to ~3 min per arch.

2. **Native runners** — Replace QEMU emulation with GitHub's native
   arm64 runners (`ubuntu-24.04-arm`). Native arm64 builds are 5–10×
   faster than QEMU-emulated builds.

Combined effect: CI wall time drops from ~40 min to ~10 min (SC-001).

### New Deliverables

Three new or modified files are added to the repository:

```text
.
├── Containerfile.base             # NEW: Base image definition
├── Containerfile                  # MODIFIED: FROM opencode-base
├── .github/
│   └── workflows/
│       ├── build-base.yml         # NEW: Weekly base image CI
│       └── build-push.yml         # MODIFIED: Native runners
```

#### 1. `Containerfile.base` — Base Image Definition (FR-022, FR-023, FR-025)

A new Containerfile that produces the `opencode-base` foundation image.
Contains everything that changes infrequently:

| Layer | Contents | Rationale |
|-------|----------|-----------|
| System packages | `dnf install` — nodejs, npm, git, gh, curl, findutils, procps-ng, which, tar, gzip | Same package set currently in Containerfile lines 24–36 |
| Go 1.25+ | Official tarball, arch-detected (`uname -m`) | Same logic currently in Containerfile lines 42–52 |
| Non-root user | `useradd -m -s /bin/bash dev` | Same as Containerfile line 61 |
| Environment | GOROOT, GOPATH, NPM_CONFIG_PREFIX, PATH | Same as Containerfile lines 67–71 |

**What it does NOT contain** (FR-023):
- No UF Go tools (uf, dewey, replicator, gaze, golangci-lint, govulncheck)
- No OpenCode binary
- No OpenSpec CLI
- No entrypoint or helper scripts
- No DEWEY_EMBEDDING_ENDPOINT (that's a dev image concern)

**Image coordinates**: `quay.io/unbound-force/opencode-base:latest`

**Structure**:
```dockerfile
FROM registry.fedoraproject.org/fedora:41

# System packages (dnf)
RUN dnf install -y <packages> && dnf clean all

# Go from official tarball (arch-detected)
ARG GO_VERSION=1.25.3
RUN <arch-detect + curl + tar>

# Non-root user + environment
RUN useradd -m -s /bin/bash dev
ENV GOROOT=... GOPATH=... NPM_CONFIG_PREFIX=... PATH=...

USER dev
WORKDIR /home/dev
```

#### 2. `.github/workflows/build-base.yml` — Base Image CI (FR-024, FR-027)

A new workflow that builds and pushes the base image on a weekly
schedule and on manual dispatch. Uses native runners for both
architectures (FR-026).

**Triggers**:
- `schedule: cron: '0 6 * * 1'` — every Monday at 06:00 UTC
- `workflow_dispatch` — manual trigger for ad-hoc rebuilds

**Job structure** (3 jobs):

| Job | Runner | Purpose |
|-----|--------|---------|
| `build-amd64` | `ubuntu-latest` | Build + smoke test amd64 base image |
| `build-arm64` | `ubuntu-24.04-arm` | Build + smoke test arm64 base image |
| `push-manifest` | `ubuntu-latest` | Create manifest list + push to quay.io |

**Smoke tests for base image** (subset — no UF tools):
```bash
podman run --rm opencode-base go version
podman run --rm opencode-base node --version
podman run --rm opencode-base git --version
podman run --rm opencode-base gh --version
USER_OUTPUT=$(podman run --rm --entrypoint whoami opencode-base)
# Must print "dev"
```

**Push strategy**: The `push-manifest` job depends on both build jobs.
It downloads the per-arch images (via artifact upload/download or
registry staging), creates a manifest list, and pushes to
`quay.io/unbound-force/opencode-base:latest`. On manual dispatch, an
optional `tag` input allows pushing a specific version tag.

#### 3. Updated `.github/workflows/build-push.yml` — Native Runners (FR-026)

The existing workflow is refactored from a single-job QEMU approach to
a parallel native-runner strategy.

**Current structure** (single job):
```
build (ubuntu-latest)
  → Install QEMU
  → Build amd64 natively
  → Smoke test amd64
  → Build arm64 under QEMU
  → Create manifest + push
```

**New structure** (3 jobs, no QEMU):
```
build-amd64 (ubuntu-latest)          build-arm64 (ubuntu-24.04-arm)
  → Checkout                            → Checkout
  → Build from opencode-base            → Build from opencode-base
  → Smoke test natively                 → Smoke test natively
  → Upload image artifact               → Upload image artifact
          ↓                                       ↓
                    push-manifest (ubuntu-latest)
                      → Download both artifacts
                      → Create manifest list
                      → Push to quay.io
```

**Key changes from current workflow**:

| Aspect | Current | New |
|--------|---------|-----|
| Runner for arm64 | `ubuntu-latest` + QEMU | `ubuntu-24.04-arm` (native) |
| QEMU step | Required (`apt-get install qemu-user-static`) | Removed entirely |
| Build jobs | 1 sequential job | 2 parallel jobs + 1 manifest job |
| Base image | `registry.fedoraproject.org/fedora:41` | `quay.io/unbound-force/opencode-base:latest` |
| Build time (arm64) | ~25 min (QEMU emulated) | ~3 min (native) |
| Smoke tests | amd64 only | Both architectures natively |
| Triggers | Unchanged | Unchanged (push to main, version tags, PRs) |

**Artifact transfer**: Each build job uploads its image as a GitHub
Actions artifact (OCI archive via `podman save`). The `push-manifest`
job downloads both, loads them into Podman, creates the manifest list,
and pushes.

### Containerfile Changes

The primary `Containerfile` is simplified by rebasing onto `opencode-base`:

**Lines removed** (moved to `Containerfile.base`):
- Lines 24–36: `dnf install` block
- Lines 42–52: Go tarball download and symlink
- Lines 61: `useradd -m -s /bin/bash dev`
- Lines 67–71: `ENV GOROOT GOPATH NPM_CONFIG_PREFIX PATH` (partially — DEWEY_EMBEDDING_ENDPOINT stays)

**Lines changed**:
- Line 17: `FROM registry.fedoraproject.org/fedora:41` → `FROM quay.io/unbound-force/opencode-base:latest`

**Lines kept** (remain in Containerfile):
- `COPY` and `RUN` for `install-uf-tools.sh`
- `USER dev` + `RUN /home/dev/scripts/install-uf-tools.sh`
- OpenCode curl installer
- Entrypoint and extract-changes script copies
- `ENV DEWEY_EMBEDDING_ENDPOINT=...`
- Final `USER dev`, `WORKDIR`, `ENTRYPOINT`

**Containerfile.udi**: No changes. It continues to use
`quay.io/devfile/universal-developer-image:latest` as its base (per
clarification: UDI base stays for Eclipse Che compatibility).

### Build Time Analysis

| Scenario | amd64 | arm64 | Manifest + Push | Total Wall Time |
|----------|-------|-------|-----------------|-----------------|
| **Current** (QEMU) | ~8 min | ~25 min (emulated) | ~2 min | **~35–40 min** |
| **New** (native + base) | ~3 min | ~3 min | ~2 min | **~8 min** |
| **SC-001 target** | — | — | — | **≤ 10 min** |

The ~3 min per-arch estimate assumes:
- Base image pull: ~30 sec (cached after first run)
- `go install` for 6 UF tools: ~90 sec (native compilation)
- OpenCode curl install: ~10 sec
- Smoke tests: ~30 sec
- Image save + artifact upload: ~30 sec

### Constitution Re-Check

The addendum introduces no new constitution violations:

- **Composability**: Base image is independently useful (Fedora + Go +
  Node.js). Dev image layers on top. Each layer is self-contained.
- **Security**: No secrets in base image. Same non-root user model.
  Native runners don't change the security posture of the built images.
- **Reproducible Builds**: Weekly base rebuild picks up security patches
  while keeping the dev image build fast. Both images are multi-arch.
- **Executable Truth**: `Containerfile.base` is the source of truth for
  the base image. `Containerfile` is the source of truth for the dev
  image. No duplication between them.

### Dependency Order

The new deliverables have a strict dependency chain:

```
Containerfile.base
  → build-base.yml (needs Containerfile.base to exist)
  → opencode-base image pushed to quay.io
    → Containerfile (FROM opencode-base:latest)
    → build-push.yml (needs opencode-base available in registry)
```

**Implementation sequence**:
1. `Containerfile.base` — define the base image
2. `.github/workflows/build-base.yml` — CI to build and push it
3. Build and push the base image (manual dispatch of build-base.yml)
4. Update `Containerfile` — change FROM + remove duplicated layers
5. Update `.github/workflows/build-push.yml` — native runners + matrix
6. Verify: full CI run with native runners pulling from opencode-base

### Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `ubuntu-24.04-arm` runner unavailable or slow | arm64 builds fail or regress | Fallback: keep QEMU path as commented-out alternative |
| Base image stale (weekly rebuild missed) | Dev image inherits unpatched Fedora | `workflow_dispatch` allows manual rebuild; CI logs show base image age |
| Base image registry pull fails | Dev image build fails | Pin base image digest in Containerfile for reproducibility; CI retries |
| Artifact transfer between jobs adds overhead | Manifest job slow | OCI archives are compressed; expect ~500MB per arch, ~30 sec transfer |
