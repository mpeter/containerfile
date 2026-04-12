# Tasks: Initial Containerfile, Devfile, and Scripts

**Input**: Design documents from `/specs/001-initial-containerfile/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Validation is `podman build` + smoke test commands — there are no Go tests or npm tests.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Create the directory structure and verify prerequisites are in place.

- [x] T001 Create `scripts/` directory at repository root
- [x] T002 Create `.github/workflows/` directory at repository root

**Checkpoint**: Directory structure matches plan.md project layout.

---

## Phase 2: Foundational (Blocking Prerequisite)

**Purpose**: The install script is shared by both Containerfiles and the dynamic devfile's postStart. It MUST be complete before any image can be built.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 [US1] Create `scripts/install-uf-tools.sh` per contract `contracts/install-uf-tools.md` — install all UF Go tools via `go install` (uf, dewey, replicator, gaze, golangci-lint, govulncheck) and OpenSpec CLI via `npm install -g @openspec/cli`; must use `set -euo pipefail`, fail-fast on any install failure, print versions after install, be idempotent, work on arm64 and amd64, and MUST NOT use Homebrew or install Ollama (FR-002, FR-003, FR-005, FR-012)

**Checkpoint**: `install-uf-tools.sh` is executable and syntactically valid (`bash -n scripts/install-uf-tools.sh` passes). Full validation deferred to Phase 3 image build.

---

## Phase 3: User Story 1 — Build and Run Container Image Locally (Priority: P1)

**Goal**: A developer builds the image from the Containerfile, starts a container with their project mounted, and has immediate access to all tools without installing anything on their host besides Podman.

**Independent Test**: Build with `podman build`, run smoke tests (tool versions + `whoami`), verify all tools present and container runs as non-root.

### Implementation

- [x] T004 [US1] Create `scripts/entrypoint.sh` per contract `contracts/entrypoint.md` — handle workspace detection, git repo check, first-run `uf init`, Ollama connectivity check (graceful degradation), and command dispatch (server/bash/pass-through); must use `set -euo pipefail` for init phase, `exec` for final process, handle read-only mounts gracefully (FR-013)
- [x] T005 [US1] Create `Containerfile` at repository root — Fedora 41 base (`registry.fedoraproject.org/fedora:41`), single-stage build per research R2; install system packages via `dnf` (Go 1.24+, Node.js 20+, npm, Git, gh CLI), create non-root `dev` user, COPY and run `scripts/install-uf-tools.sh`, install OpenCode via `curl -fsSL https://opencode.ai/install | bash`, set `DEWEY_EMBEDDING_ENDPOINT`, set `GOPATH` and `PATH`, set `USER dev`, set `WORKDIR /home/dev`, set ENTRYPOINT to `scripts/entrypoint.sh`; must NOT install Ollama, must NOT contain secrets (FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-019)

### Verification

- [x] T006 [US1] Build image and run smoke tests — execute `podman build -t opencode-dev -f Containerfile .`, then verify: `podman run --rm opencode-dev uf --version`, `opencode --version`, `dewey --version`, `replicator --version`, `gaze --version`, `go version`, `golangci-lint --version`, `govulncheck -version`, `node --version`, `npm --version`, `git --version`, `gh --version`; verify `podman run --rm opencode-dev whoami` prints `dev`; verify volume mount read/write: `podman run --rm -v /tmp/uf-smoke:/workspace:Z opencode-dev bash -c "touch /workspace/test-file && rm /workspace/test-file"` (SC-001, SC-002, US1-AC4)

**Checkpoint**: Image builds successfully. All tool version checks pass. Container runs as `dev`. Volume mount read/write verified. User Story 1 acceptance scenarios 1-4 verified.

---

## Phase 4: User Story 2 — Headless Server Mode (Priority: P2)

**Goal**: Maximum isolation — host source mounted read-only, OpenCode runs as headless server, changes extracted via `git format-patch` only after human review (Model B).

**Independent Test**: Start container in headless mode with read-only mount, verify OpenCode serves on port 4096, connect from host, extract changes via format-patch.

### Implementation

- [x] T007 [P] [US2] Create `scripts/extract-changes.sh` per contract `contracts/extract-changes.md` — detect git repo, detect uncommitted changes, stage and create temporary commit, generate `git format-patch` output to stdout or output directory, handle no-changes case gracefully, set git user defaults if not configured; must use `set -euo pipefail`, work with read-only source mount (FR-014, FR-021)
- [x] T008 [P] [US2] Create `scripts/connect.sh` per contract `contracts/connect.md` — check if container is running via `podman ps`, start via `podman-compose up -d` or `podman run -d` if not running, wait for OpenCode health endpoint (30s timeout), attach via `opencode attach`, print cleanup guidance; must use Podman (not Docker), apply resource limits (8G/4CPU), use `:Z` volume mounts, set `DEWEY_EMBEDDING_ENDPOINT`; must use `set -euo pipefail` (FR-015, FR-020)
- [x] T009 [US2] Create `podman-compose.yml` at repository root — define headless server mode with read-only source mount (`./project:/workspace:ro,Z`), writable work directory as a named volume or tmpfs at `/work` (the entrypoint copies source here on startup for agent modifications), resource limits (8G memory, 4 CPUs), `DEWEY_EMBEDDING_ENDPOINT` environment variable, port mapping for 4096, container name `opencode-server`, reference `opencode-dev` image (FR-016, FR-020, FR-021)

### Verification

- [x] T010 [US2] Verify headless mode — build image (if not already built), run `podman-compose up -d`, verify container starts and OpenCode serves on port 4096, verify source mount is read-only, run `podman-compose down` (SC-003, SC-004)

**Checkpoint**: Headless mode starts with read-only mount. Connect script attaches successfully. Extract script produces valid format-patch output. User Story 2 acceptance scenarios verified.

---

## Phase 5: User Story 3 — CDE / Eclipse Che (Priority: P3)

**Goal**: Pre-configured Eclipse Che workspace with the full UF toolchain. Two variants: custom image (fast start) and dynamic (UDI + postStart, no custom image).

**Independent Test**: Build UDI variant, verify tools present. Validate both devfiles parse against Devfile 2.2.0 schema.

### Implementation

- [x] T011 [US3] Create `Containerfile.udi` at repository root — use `quay.io/devfile/universal-developer-image:latest` as base per research R3; install UF tools on top using `scripts/install-uf-tools.sh`, respect UDI's existing `user` user (UID 1001), use `USER 0` temporarily for system installs then switch back, accept UDI's Go/Node.js versions, set `DEWEY_EMBEDDING_ENDPOINT`; must NOT create a `dev` user, must NOT replace UDI's Go/Node.js (FR-007, FR-008)
- [x] T012 [P] [US3] Create `devfile.yaml` at repository root — Devfile 2.2.0 schema, reference `quay.io/unbound-force/opencode-dev:latest` image, set `memoryLimit: 8Gi`, `cpuLimit: "4"`, `mountSources: true`, define OpenCode server endpoint on port 4096 (FR-009, FR-011)
- [x] T013 [P] [US3] Create `devfile-dynamic.yaml` at repository root — Devfile 2.2.0 schema, use `quay.io/devfile/universal-developer-image:latest` as base, define `postStart` command that runs `scripts/install-uf-tools.sh`, set resource limits, define OpenCode endpoint; no custom image dependency (FR-010, FR-011)

### Verification

- [x] T014 [US3] Build UDI variant and run smoke tests — execute `podman build -t opencode-dev-udi -f Containerfile.udi .`, then verify same tool version checks as T006; verify `podman run --rm opencode-dev-udi whoami` prints `user` (not `dev`); validate both devfiles are valid YAML (SC-005, SC-006)

**Checkpoint**: UDI variant builds and passes smoke tests. Both devfiles are valid. User Story 3 acceptance scenarios verified.

---

## Phase 6: User Story 4 — CI Pipeline (Priority: P4)

**Goal**: Automated multi-arch build and push to quay.io on every push to main and on version tags.

**Independent Test**: Push a commit to main and verify CI builds both architectures and pushes to quay.io.

### Implementation

- [x] T015 [US4] Create `.github/workflows/build-push.yml` — GitHub Actions workflow per research R5; install QEMU user-static for cross-arch emulation, use `podman manifest` for multi-arch builds (linux/arm64 + linux/amd64), login to quay.io via secrets, push to `quay.io/unbound-force/opencode-dev`; triggers: push to `main` (tag `latest`), version tag push `v*` (tag with version), pull request (build only, no push); run smoke tests before push (FR-017)

**Checkpoint**: CI workflow file is valid YAML and follows GitHub Actions syntax. Full validation requires a push to main (deferred to merge).

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, AGENTS.md updates, and final validation.

- [x] T016 [P] Create `README.md` at repository root — document all three deployment models (Interactive/Model A, Headless/Model B, CDE/Model C) per quickstart.md, document security model (non-negotiable constraints), document change extraction methods, document prerequisites (Podman, optional Ollama), include smoke test suite, include troubleshooting table (FR-018)
- [x] T017 [P] Update `AGENTS.md` — verify Active Technologies and Recent Changes sections are current for `001-initial-containerfile` branch
- [x] T018 Validate quickstart.md steps — walk through each model's quickstart commands from `specs/001-initial-containerfile/quickstart.md` against the actual built artifacts, verify all commands work as documented

**Checkpoint**: README covers all models. AGENTS.md is current. Quickstart steps verified against real artifacts.

---

## Phase 8: Base Image + Native Runners

**Purpose**: Extract the slow-changing platform foundation into a separate base image rebuilt weekly, and replace QEMU emulation with native arm64 runners. Combined effect: CI wall time drops from ~40 min to ~10 min (SC-001).

**Dependencies**: Phase 6 (US4) must be complete — this phase refactors the CI workflow created in T015 and the Containerfile created in T005.

### Implementation (sequential — strict dependency chain)

- [x] T019 [US4] Create `Containerfile.base` — base image definition: FROM `registry.fedoraproject.org/fedora:41`; `dnf install` system packages (nodejs, npm, git, gh, curl, findutils, procps-ng, which, tar, gzip); Go 1.25.3 tarball install with `ARG GO_VERSION=1.25.3` and arch-detection via `uname -m`; create non-root user `dev` with home at `/home/dev`; set ENV for GOROOT, GOPATH, NPM_CONFIG_PREFIX, PATH (including `.opencode/bin`, `.npm-global/bin`), DEWEY_EMBEDDING_ENDPOINT; must NOT include UF Go tools, OpenCode, OpenSpec CLI, entrypoint, or helper scripts — platform foundation only (FR-022, FR-023, FR-025)
- [x] T020 [US4] Create `.github/workflows/build-base.yml` — base image CI workflow: triggers on `schedule` (weekly, cron `'0 4 * * 1'`) and `workflow_dispatch` (manual); 3 jobs: `build-amd64` (runs-on `ubuntu-latest`), `build-arm64` (runs-on `ubuntu-24.04-arm`), `push-manifest` (needs both build jobs); each build job runs `podman build -t opencode-base-$ARCH -f Containerfile.base .` then smoke tests (`go version`, `node --version`, `git --version`, `--entrypoint whoami` expects `dev`), uploads image as artifact; push job logs in to quay.io, creates manifest list, pushes to `quay.io/unbound-force/opencode-base:latest` (FR-024, FR-027)
- [x] T021 [US4] Refactor `Containerfile` to use base image — change FROM to `quay.io/unbound-force/opencode-base:latest`; remove `dnf install` step, Go tarball download, `ARG GO_VERSION`, `useradd`, and ENV block (GOROOT, GOPATH, NPM_CONFIG_PREFIX, PATH); keep COPY and RUN for `install-uf-tools.sh`, `USER dev`, OpenCode curl installer, script copies, `ENV DEWEY_EMBEDDING_ENDPOINT`, final ENTRYPOINT; resulting Containerfile should be ~30 lines (FR-001a)
- [x] T022 [US4] Refactor `.github/workflows/build-push.yml` to use native runners — replace single QEMU-based job with 3 jobs: `build-amd64` (runs-on `ubuntu-latest`), `build-arm64` (runs-on `ubuntu-24.04-arm`), `push-manifest` (needs both); remove QEMU install step entirely; each build job runs `podman build`, smoke tests natively (tool versions + `--entrypoint whoami` expects `dev`), uploads image artifact; push job creates manifest from both arch images, pushes to `quay.io/unbound-force/opencode-dev`; triggers unchanged (push to main, version tags, PRs) (FR-026)

### Verification

- [x] T023 [US4] Verify base image + dev image build chain — build base image locally (`podman build -t opencode-base -f Containerfile.base .`), then build dev image on top (`podman build -t opencode-dev -f Containerfile .`); run full smoke test suite (all tool version checks + `whoami` prints `dev`); verify dev image build is faster than the pre-refactor single-stage build (SC-001, SC-002)

**Checkpoint**: Base image builds with platform packages + Go only. Dev image builds on top of base with UF tools only. Full smoke test suite passes. Dev image build time is significantly reduced. CI workflows use native runners for both architectures.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 — BLOCKS all user stories
- **Phase 3 (US1 — P1)**: Depends on Phase 2 — foundational image
- **Phase 4 (US2 — P2)**: Depends on Phase 3 — needs a built image
- **Phase 5 (US3 — P3)**: Depends on Phase 2 — needs install script; independent of US2
- **Phase 6 (US4 — P4)**: Depends on Phase 3 — needs a working Containerfile
- **Phase 7 (Polish)**: Depends on Phases 3-6 — documents all artifacts
- **Phase 8 (Base Image + Native Runners)**: Depends on Phase 6 — refactors Containerfile (T005) and CI workflow (T015); strict internal dependency chain (T019 → T020 → T021 → T022 → T023)

### Parallel Opportunities

- **T001 + T002**: Both setup tasks can run in parallel (different directories)
- **T007 + T008**: Extract and connect scripts can be written in parallel (different files, no dependencies)
- **T012 + T013**: Both devfiles can be written in parallel (different files)
- **T016 + T017**: README and AGENTS.md updates can run in parallel
- **Phase 5 (US3) can start after Phase 2**, independent of Phase 4 (US2). If parallelizing across workers, US1 and US3 can overlap after the install script is complete, though US3's Containerfile.udi build verification (T014) benefits from patterns established in US1's Containerfile (T005).

### Within Each Phase

- Implementation tasks before verification tasks
- Scripts before Containerfiles (scripts are COPY'd into images)
- Containerfile before compose/devfiles (compose references the image)

---

## Summary

| Metric | Count |
|--------|-------|
| **Total tasks** | 23 |
| **Phase 1 (Setup)** | 2 |
| **Phase 2 (Foundational)** | 1 |
| **Phase 3 (US1 — P1)** | 3 |
| **Phase 4 (US2 — P2)** | 4 |
| **Phase 5 (US3 — P3)** | 4 |
| **Phase 6 (US4 — P4)** | 1 |
| **Phase 7 (Polish)** | 3 |
| **Phase 8 (Base Image + Native Runners)** | 5 |
| **Parallelizable [P] tasks** | 6 |
| **Files created** | 14 |
| **Files modified** | 3 (AGENTS.md, Containerfile, build-push.yml) |
<!-- spec-review: passed -->
