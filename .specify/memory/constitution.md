<!--
  SYNC IMPACT REPORT
  ==================
  Version change: (none) → 1.0.0 (initial ratification)

  Added principles:
    - I. Composability First (from org constitution + dewey)
    - II. Security Through Isolation (derived from Discussion #88)
    - III. Reproducible Builds (adapted from org Observable Quality)
    - IV. Executable Truth (derived from AGENTS.md behavioral constraints)

  Added sections:
    - Development Workflow
    - Governance

  Removed template sections:
    - [SECTION_2_NAME] (folded into principles)
    - [SECTION_3_NAME] (replaced by Development Workflow)
    - Principle 5 (4 principles sufficient)

  Templates requiring updates:
    ✅ .specify/templates/plan-template.md — no changes needed;
       Constitution Check section is generic and will align at
       plan time using these four principles.
    ✅ .specify/templates/spec-template.md — no changes needed;
       requirements format already uses MUST/SHOULD language.
    ✅ .specify/templates/tasks-template.md — no changes needed;
       task phases are feature-driven, not principle-specific.

  Deferred TODOs: none
-->

# Containerfile Constitution

**Parent Constitution**: unbound-force org constitution v1.1.0

## Core Principles

### I. Composability First

The container image MUST be usable without requiring any
specific host configuration beyond Podman and a project
directory to mount.

- The image MUST deliver its core value (running OpenCode
  with the full UF toolchain) when deployed standalone.
  No external services beyond the host filesystem MUST be
  required for primary operation.
- Ollama MUST remain on the host. The container MUST
  connect via `DEWEY_EMBEDDING_ENDPOINT` to
  `host.containers.internal`. Ollama MUST NOT be installed
  inside the container.
- When optional host services are unavailable (Ollama,
  Dewey embeddings), the container MUST start and operate
  with reduced but functional capability. Failure to reach
  an optional service MUST NOT prevent container startup.
- All tools installed in the image MUST be independently
  functional. A tool's absence from the host MUST NOT
  break other tools in the container.

**Rationale**: The container is a composable unit of the
Unbound Force ecosystem. A developer MUST be able to
`podman run` the image on a fresh machine with only Podman
installed and get a working environment. Hard dependencies
on host services create fragile setups that fail silently.

### II. Security Through Isolation

The container MUST provide a security boundary between AI
agents and the host system. If an agent goes off the rails,
the blast radius MUST be contained.

- The container MUST run as a non-root user (`dev`). No
  Containerfile instruction MAY use `USER root` as the
  final runtime user.
- No SSH keys, git push tokens, API keys, or other
  credentials MUST be baked into the image. Secrets MUST
  be injected at runtime via environment variables or
  mounted files.
- In headless mode (Model B), the source directory MUST
  be mounted read-only. Changes MUST be extracted via
  `git format-patch`, never via direct writes to the
  host filesystem.
- Resource limits (`--memory`, `--cpus`) MUST be
  documented and enforced in all orchestration files
  (`podman-compose.yml`, `devfile.yaml`).
- Podman rootless MUST be the only supported container
  runtime mode. Docker daemon-based workflows MUST NOT
  be documented or supported.

**Rationale**: AI agents executing arbitrary code inside
containers are an attack surface. Rootless containers with
no credentials, read-only mounts, and resource limits
ensure that a misbehaving agent cannot exfiltrate secrets,
exhaust host resources, or modify source code directly.
This is the entire reason the containerfile repo exists.

### III. Reproducible Builds

Every container image MUST build identically on any
supported platform and produce verifiable, inspectable
results.

- All images MUST build for both `linux/arm64` and
  `linux/amd64`. A Containerfile that builds on only
  one architecture MUST NOT be merged.
- Tool installation MUST use pinned versions or
  deterministic methods (`go install` at specific
  versions, `dnf install` with version constraints,
  `curl` with checksum verification where available).
- Every image MUST pass the smoke test suite defined in
  AGENTS.md: tool version checks (`uf --version`,
  `opencode --version`, `dewey --version`,
  `replicator --version`, `gaze --version`) and user
  verification (`whoami` returns `dev`).
- CI MUST build and push images to the registry
  (`quay.io/unbound-force/opencode-dev`) on every push
  to `main`. Manual image publishing MUST NOT be the
  primary distribution method.

**Rationale**: Container images that work on the author's
machine but fail elsewhere are useless. Multi-arch builds,
pinned dependencies, and automated smoke tests ensure that
any developer on any platform gets the same working image.

### IV. Executable Truth

The Containerfile is the source of truth for what the
image contains. All other documentation MUST be derived
from and consistent with the Containerfile.

- When a Containerfile instruction and a README or
  AGENTS.md description conflict, the documentation MUST
  be fixed — never the Containerfile (unless the
  Containerfile is genuinely wrong).
- No unused scripts, dead configuration, commented-out
  instructions, or placeholder files MUST exist in the
  repository. Every file MUST serve a purpose traceable
  to a deliverable.
- After any Containerfile change, the image MUST be
  built locally and the smoke tests MUST pass before
  the task is considered complete.
- Shell scripts MUST be tested by building the image
  that uses them. A script that is not referenced by
  any Containerfile or compose file MUST be removed.

**Rationale**: Infrastructure-as-code only works when the
code is the single source of truth. Stale documentation
that contradicts the actual image definition causes
debugging nightmares. Zero-waste ensures every file earns
its place.

## Development Workflow

- **Spec-First Development**: All non-trivial changes
  MUST be preceded by a spec workflow (Speckit for 3+
  stories, OpenSpec for smaller changes). Exempt:
  constitution amendments, typo fixes, single-line
  config changes.
- **Branching**: All work MUST occur on feature branches.
  Speckit: `NNN-<name>`. OpenSpec: `opsx/<name>`.
- **Code Review**: Every pull request MUST receive at
  least one approving review before merge.
- **Continuous Integration**: The CI pipeline MUST pass
  (build, smoke tests) before a pull request is eligible
  for merge.
- **Releases**: Container images are tagged by git commit
  SHA and `latest`. Breaking changes to the image
  (removed tools, changed base image, changed user)
  require a new image tag.
- **Commit Messages**: Conventional commits
  (`type: description`).
- **Build Verification**: After any Containerfile or
  script change, the image MUST be built locally and
  smoke tests MUST pass before marking the task complete.
  Derive smoke test commands from AGENTS.md, not from
  memory.
- **Website Documentation Sync**: When a change affects
  the container image's public interface (new tools,
  removed tools, changed entrypoint, new deployment
  model), a GitHub issue MUST be created in the
  `unbound-force/website` repository. Exempt: internal
  Containerfile refactoring, CI-only changes, spec
  artifacts.

## Governance

This constitution extends the Unbound Force org
constitution (v1.1.0). On matters where this document and
the org constitution conflict, the org constitution
prevails.

- **Amendments**: Any change to this constitution MUST be
  proposed via pull request, reviewed, and approved
  before merge. The amendment MUST include a migration
  plan if it alters or removes existing principles.
- **Versioning**: Semantic versioning:
  - MAJOR: Principle removal or incompatible redefinition.
  - MINOR: New principle or materially expanded guidance.
  - PATCH: Clarifications, wording, or non-semantic
    refinements.
- **Compliance Review**: At each planning phase (spec,
  plan, tasks), the Constitution Check gate MUST verify
  that the proposed work aligns with all active
  principles. Constitution violations are CRITICAL
  severity and non-negotiable.

**Version**: 1.0.0 | **Ratified**: 2026-04-11 | **Last Amended**: 2026-04-11
