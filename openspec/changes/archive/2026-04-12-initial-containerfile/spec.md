# Feature Specification: Initial Containerfile, Devfile, and Scripts

**Feature Branch**: `001-initial-containerfile`
**Created**: 2026-04-11
**Status**: In Review
**Input**: Issue #1 and Discussion #88 — multi-arch container image with the full UF toolchain, devfiles for Eclipse Che, helper scripts, orchestration, CI, and documentation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Build and Run the Container Image Locally (Priority: P1)

A developer wants to run OpenCode and the full Unbound Force
toolchain inside an isolated container on their local machine.
They build the image from the Containerfile, start a container
with their project directory mounted, and have immediate access
to all tools (uf, OpenCode, Dewey, Replicator, Gaze) without
installing anything on their host besides Podman.

**Why this priority**: This is the foundational deliverable.
Every other story depends on a working container image. Without
it, nothing else in this repo has value.

**Independent Test**: Build the image with `podman build`, run
the smoke test commands (tool version checks + `whoami`), and
verify all tools are present and the container runs as non-root.

**Acceptance Scenarios**:

1. **Given** a developer with Podman installed, **When** they
   run `podman build -t opencode-dev -f Containerfile .`,
   **Then** the image builds successfully on both arm64 and
   amd64 architectures.
2. **Given** a built image, **When** they run
   `podman run --rm opencode-dev uf --version`, **Then** the
   command succeeds and prints a version string. Same for
   `opencode`, `dewey`, `replicator`, and `gaze`.
3. **Given** a built image, **When** they run
   `podman run --rm opencode-dev whoami`, **Then** the output
   is `dev` (not `root`).
4. **Given** a built image, **When** they run the container
   with a project directory mounted (`-v ./project:/workspace:Z`),
   **Then** the tools can read and write files in the mounted
   directory.

---

### User Story 2 — Run OpenCode in Headless Server Mode (Priority: P2)

A developer wants maximum isolation: the host source directory
is mounted read-only, OpenCode runs as a headless server, and
changes are extracted via `git format-patch` only after human
review. This is the "Model B" deployment from Discussion #88.

**Why this priority**: Headless mode is the primary security
use case — the reason this repo exists. It depends on a
working image (US1) but delivers the core isolation promise.

**Independent Test**: Start the container in headless mode
with read-only mount, verify OpenCode serves on port 4096,
connect from the host, make a change inside the container,
and extract it via format-patch.

**Acceptance Scenarios**:

1. **Given** a built image and a local project, **When** the
   developer runs the compose file (`podman-compose up`),
   **Then** OpenCode starts as a server on port 4096 with the
   source directory mounted read-only.
2. **Given** a running headless container, **When** the
   developer connects via `opencode attach`, **Then** they can
   interact with the AI agent inside the container.
3. **Given** a headless container with agent-made changes,
   **When** the developer runs the extract script, **Then**
   changes are exported as `git format-patch` output for human
   review before applying to the host.
4. **Given** a headless container, **When** the container
   exceeds resource limits (8G memory, 4 CPUs), **Then** the
   container runtime enforces the limits.

---

### User Story 3 — Use the CDE Variant in Eclipse Che (Priority: P3)

A developer working in Eclipse Che or Red Hat Dev Spaces wants
a pre-configured workspace with the full UF toolchain. They
create a workspace from the devfile and immediately have access
to all tools without manual setup.

**Why this priority**: CDE support expands the audience beyond
local Podman users but is not required for the core isolation
use case. It depends on a working image (US1).

**Independent Test**: Build the UDI variant, verify tools are
present. Validate both devfiles parse correctly against the
Devfile 2.2.0 schema.

**Acceptance Scenarios**:

1. **Given** a developer using Eclipse Che, **When** they
   create a workspace from `devfile.yaml`, **Then** the
   workspace starts with all UF tools available.
2. **Given** the UDI-based image, **When** it is built with
   `podman build -f Containerfile.udi .`, **Then** all UF tools
   are present and functional (same smoke tests as US1).
3. **Given** a developer using the dynamic devfile, **When**
   they create a workspace from `devfile-dynamic.yaml`,
   **Then** tools are installed via postStart commands using
   the UDI base image (no custom image required).

---

### User Story 4 — CI Builds and Publishes the Image (Priority: P4)

An image maintainer wants the container image to be
automatically built and pushed to the registry on every push
to main, so consumers always have access to the latest image
without manual publishing.

**Why this priority**: Automation is important but can be
deferred until the image definition is stable. Manual builds
work in the interim.

**Independent Test**: Push a commit to main and verify the
CI workflow builds both architectures and pushes to quay.io.

**Acceptance Scenarios**:

1. **Given** a push to the main branch, **When** the CI
   workflow runs, **Then** it builds the image for both
   `linux/arm64` and `linux/amd64`.
2. **Given** a successful CI build, **When** the workflow
   completes, **Then** the image is pushed to
   `quay.io/unbound-force/opencode-dev` with `latest` tag.
3. **Given** a version tag push, **When** the CI workflow
   runs, **Then** the image is additionally tagged with the
   version number.

---

### Edge Cases

- What happens when Ollama is not running on the host? The
  container MUST start successfully; Dewey embedding features
  degrade but all other tools remain functional.
- What happens when the mounted project directory has no git
  repository? The entrypoint MUST handle this gracefully
  (skip `uf init` git operations, still start OpenCode).
- What happens when `go install` fails for one tool during
  image build? The build MUST fail immediately — partial
  tool installation is not acceptable.
- What happens when the developer is on Fedora with SELinux
  enforcing? Volume mounts MUST use `:Z` relabeling to work
  correctly.
- What happens when the container runs on a platform where
  `host.containers.internal` does not resolve? The container
  MUST start; Dewey embeddings are unavailable but the
  container remains functional.

## Requirements *(mandatory)*

### Functional Requirements

**Base Image (Containerfile.base)**:

- **FR-022**: A multi-arch base image MUST be published to
  `quay.io/unbound-force/opencode-base` containing Fedora 41,
  system packages (Node.js 20+, npm, Git, gh CLI, curl), and
  Go 1.25+ installed from the official tarball.
- **FR-023**: The base image MUST NOT include UF-specific Go
  tools (uf, dewey, replicator, gaze). These are installed in
  the dev image layer to allow tool updates without rebuilding
  the base.
- **FR-024**: The base image MUST be rebuilt weekly via a
  scheduled CI workflow to pick up Fedora security patches and
  Go minor version updates.
- **FR-025**: The base image MUST create the non-root `dev`
  user and configure GOPATH, PATH, and NPM_CONFIG_PREFIX
  environment variables.

**Container Image (Containerfile)**:

- **FR-001**: The Containerfile MUST produce a multi-arch
  image that builds for both `linux/arm64` and `linux/amd64`.
- **FR-001a**: The Containerfile MUST use
  `quay.io/unbound-force/opencode-base:latest` as its base
  image (not raw Fedora).
- **FR-002**: The image MUST include these tools: `uf`,
  OpenCode, Dewey, Replicator, Gaze, Go 1.25+, Node.js 20+,
  npm, Git, gh CLI, golangci-lint, govulncheck, OpenSpec CLI.
- **FR-003**: Go tools MUST be installed via `go install`.
  No Homebrew or Linuxbrew in the container.
- **FR-004**: The image MUST run as a non-root user named
  `dev`.
- **FR-005**: Ollama MUST NOT be installed in the image.
- **FR-006**: The image MUST set
  `DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434`
  as a default environment variable.

**CDE Variant (Containerfile.udi)**:

- **FR-007**: A UDI-based Containerfile variant MUST exist
  for Eclipse Che / Dev Spaces, using
  `quay.io/devfile/universal-developer-image:latest` as the
  base image.
- **FR-008**: The UDI variant MUST install the same set of
  UF tools as the primary Containerfile.

**Devfiles**:

- **FR-009**: A `devfile.yaml` MUST exist that references the
  custom container image with memory limit (8G), CPU limit
  (4), source mounting, and an OpenCode server endpoint.
- **FR-010**: A `devfile-dynamic.yaml` MUST exist that uses
  the UDI base image with postStart commands to install tools
  (no custom image dependency).
- **FR-011**: Both devfiles MUST conform to the Devfile 2.2.0
  specification.

**Scripts**:

- **FR-012**: An install script (`scripts/install-uf-tools.sh`)
  MUST install all UF Go tools via `go install`, usable in
  both Containerfiles and devfile postStart.
- **FR-013**: An entrypoint script (`scripts/entrypoint.sh`)
  MUST handle first-run initialization (e.g., `uf init`) and
  start OpenCode in server mode when requested.
- **FR-014**: An extraction script
  (`scripts/extract-changes.sh`) MUST export container changes
  as `git format-patch` output.
- **FR-015**: A connect script (`scripts/connect.sh`) MUST
  start the container and attach via `opencode attach`.

**Orchestration**:

- **FR-016**: A `podman-compose.yml` MUST define the headless
  server mode with read-only source mount, writable work
  directory, resource limits (8G memory, 4 CPUs), and Ollama
  endpoint configuration.

**CI**:

- **FR-017**: A GitHub Actions workflow MUST build the image
  for both architectures and push to
  `quay.io/unbound-force/opencode-dev` on push to main and
  on version tags.
- **FR-026**: The CI workflow MUST use native runners for each
  architecture (`ubuntu-latest` for amd64,
  `ubuntu-24.04-arm` for arm64) instead of QEMU emulation.
- **FR-027**: A separate CI workflow MUST build and push the
  base image (`opencode-base`) on a weekly schedule and on
  manual dispatch. This workflow MUST also use native runners
  for each architecture.

**Documentation**:

- **FR-018**: A `README.md` MUST document all three deployment
  models (interactive, headless, CDE), the security model,
  change extraction methods, and prerequisites.

**Security (non-negotiable)**:

- **FR-019**: No SSH keys, git push tokens, API keys, or
  other secrets MUST be present in the image.
- **FR-020**: Resource limits MUST be enforced in all
  orchestration files.
- **FR-021**: Headless mode MUST use read-only source mounts.

### Key Entities

- **Base Image**: A multi-arch foundation image
  (`quay.io/unbound-force/opencode-base`) containing Fedora 41,
  system packages, and Go 1.25+. Rebuilt weekly. Used as the
  FROM for the primary Containerfile only (not UDI variant).
- **Container Image**: The primary OCI artifact published to
  quay.io. Two variants: Fedora-based (primary, built on
  opencode-base) and UDI-based (CDE). Contains the full UF
  toolchain.
- **Devfile**: Eclipse Che workspace definition (Devfile 2.2.0
  schema). Two variants: custom image (fast start) and dynamic
  (UDI + postStart, no custom image).
- **Deployment Model**: One of three modes: Interactive (rw
  mount), Headless (ro mount + format-patch), CDE (Dev Spaces
  workspace). Each has different security properties.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The dev image builds successfully on both arm64
  and amd64 with a total CI wall time of 10 minutes or less
  (both architectures combined, using native runners and the
  pre-built base image).
- **SC-002**: All 5 tool version checks pass (`uf`, `opencode`,
  `dewey`, `replicator`, `gaze`) after building the image.
- **SC-003**: Container starts and OpenCode serves within
  30 seconds of `podman run` or `podman-compose up`.
- **SC-004**: Headless mode with read-only mount prevents
  direct host filesystem modification — changes extractable
  only via `git format-patch`.
- **SC-005**: The UDI variant passes the same smoke tests
  as the primary Containerfile.
- **SC-006**: Both devfiles validate against the Devfile 2.2.0
  schema without errors.
- **SC-007**: CI workflow successfully builds and pushes to
  quay.io on the first attempt after merging to main.

## Assumptions

- Podman is installed on the developer's machine. Docker is
  not a supported runtime.
- Ollama runs on the host and is accessible at
  `host.containers.internal:11434`. When unavailable, Dewey
  embeddings degrade gracefully.
- The developer has network access during image build to
  download Go modules and npm packages.
- quay.io registry credentials are configured in the CI
  environment (GitHub Actions secrets).
- All UF tool repos (dewey, gaze, replicator, unbound-force)
  have tagged releases available for `go install @latest`.

## Clarifications

### Session 2026-04-12

- Q: Where should the base image be published? → A: Same quay.io namespace (`quay.io/unbound-force/opencode-base`)
- Q: How should the base image be rebuilt? → A: Weekly scheduled CI workflow
- Q: What should the total CI build time target be? → A: 10 minutes total (both architectures combined)
- Q: What should the base image contain? → A: System packages + Go only (UF tools in dev image layer)
- Q: Should Containerfile.udi also use the base image? → A: No, keep UDI base for Eclipse Che compatibility

## Dependencies

- [Discussion #88](https://github.com/orgs/unbound-force/discussions/88) — architecture and design rationale
- [Issue #1](https://github.com/unbound-force/containerfile/issues/1) — implementation requirements
- dewey#36 (startup timeout) — closed, fixed
- dewey#40 (relative path fix) — closed, fixed
- replicator#5 (init command) — closed, done
- `uf sandbox` CLI command — tracked separately in the meta
  repo; will consume the image this spec produces
