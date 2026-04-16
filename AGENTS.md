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

## Core Mission

- **Strategic Architecture**: Engineers shift from manual
  coding to directing an "infinite supply of junior
  developers" (AI agents).
- **Outcome Orientation**: Focus on conveying business
  value and user intent rather than low-level technical
  sub-tasks.
- **Intent-to-Context**: Treat specs and rules as the
  medium through which human intent is manifested into
  code.

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

### Gatekeeping Value Protection

Agents MUST NOT modify values that serve as quality or
governance gates to make an implementation pass. The
following categories are protected:

1. **Coverage thresholds and CRAP scores** — minimum
   coverage percentages, CRAP score limits, coverage
   ratchets
2. **Severity definitions and auto-fix policies** —
   CRITICAL/HIGH/MEDIUM/LOW boundaries, auto-fix
   eligibility rules
3. **Convention pack rule classifications** —
   MUST/SHOULD/MAY designations on convention pack rules
   (downgrading MUST to SHOULD is prohibited)
4. **CI flags and linter configuration** — `-race`,
   `-count=1`, `govulncheck`, `golangci-lint` rules,
   pinned action SHAs
5. **Agent temperature and tool-access settings** —
   frontmatter `temperature`, `tools.write`, `tools.edit`,
   `tools.bash` restrictions
6. **Constitution MUST rules** — any MUST rule in
   `.specify/memory/constitution.md` or hero constitutions
7. **Review iteration limits and worker concurrency** —
   max review iterations, max concurrent Swarm workers,
   retry limits
8. **Workflow gate markers** — `<!-- spec-review: passed
   -->`, task completion checkboxes used as gates, phase
   checkpoint requirements

**What to do instead**: When an implementation cannot
meet a gate, the agent MUST stop, report which gate is
blocking and why, and let the human decide whether to
adjust the gate or rework the implementation. Modifying
a gate without explicit human authorization is a
constitution violation (CRITICAL severity).

### Workflow Phase Boundaries

Agents MUST NOT cross workflow phase boundaries:

- **Specify/Clarify/Plan/Tasks/Analyze/Checklist** phases:
  spec artifacts ONLY (`specs/NNN-*/` directory). No
  source code, test, agent, command, or config changes.
- **Implement** phase: source code changes allowed,
  guided by spec artifacts.
- **Review** phase: findings and minor fixes only. No new
  features.

A phase boundary violation is treated as a process error.
The agent MUST stop and report the violation rather than
proceeding with out-of-phase changes.

### CI Parity Gate

Before marking any implementation task complete or
declaring a PR ready, agents MUST replicate the CI checks
locally. Read `.github/workflows/` to identify the exact
commands CI runs, then execute those same commands. Any
failure is a blocking error — a task is not complete
until all CI-equivalent checks pass locally. Do not rely
on a memorized list of commands; always derive them from
the workflow files, which are the source of truth.

### Review Council as PR Prerequisite

Before submitting a pull request, agents **must** run
`/review-council` and resolve all REQUEST CHANGES
findings until all reviewers return APPROVE. There must
be **minimal to no code changes** between the council's
APPROVE verdict and the PR submission — the council
reviews the final code, not a draft that changes
afterward.

Workflow:

1. Complete all implementation tasks
2. Run CI checks locally (build, test, vet)
3. Run `/review-council` — fix any findings, re-run
   until APPROVE
4. Commit, push, and submit PR immediately after council
   APPROVE
5. Do NOT make further code changes between APPROVE and
   PR submission

Exempt from council review:

- Constitution amendments (governance documents, not code)
- Documentation-only changes (README, AGENTS.md, spec
  artifacts)
- Emergency hotfixes (must be retroactively reviewed)

## Spec-First Development

All changes that modify production code, test code, agent
prompts, embedded assets, or CI configuration **must** be
preceded by a spec workflow. The constitution
(`.specify/memory/constitution.md`) is the highest-
authority document in this project — all work must align
with it.

Two spec workflows are available:

| Workflow | Location | Best For |
|----------|----------|----------|
| **Speckit** | `specs/NNN-name/` | Numbered feature specs with the full pipeline |
| **OpenSpec** | `openspec/changes/name/` | Targeted changes with lightweight artifacts |

**What requires a spec** (no exceptions without explicit
user override):

- New features or capabilities
- Refactoring that changes function signatures, extracts
  helpers, or moves code between packages
- Test additions or assertion strengthening across
  multiple functions
- Agent prompt changes
- CI workflow modifications
- Data model changes (new struct fields, schema updates)

**What is exempt** (may be done directly):

- Constitution amendments (governed by the constitution's
  own Governance section)
- Typo corrections, comment-only changes, single-line
  formatting fixes
- Emergency hotfixes for critical production bugs (must
  be retroactively documented)

When an agent is unsure whether a change is trivial, it
**must** ask the user rather than proceeding without a
spec. The cost of an unnecessary spec is minutes; the
cost of an unplanned change is rework, drift, and broken
CI.

### Website Documentation Gate

When a change affects user-facing behavior, hero
capabilities, CLI commands, or workflows, a GitHub issue
**MUST** be created in the `unbound-force/website`
repository to track required documentation or website
updates. The issue must be created before the
implementing PR is merged.

```bash
gh issue create --repo unbound-force/website \
  --title "docs: <brief description of what changed>" \
  --body "<what changed, why it matters, which pages
          need updating>"
```

**Exempt changes** (no website issue needed):
- Internal refactoring with no user-facing behavior
  change
- Test-only changes
- CI/CD pipeline changes
- Spec artifacts (specs are internal planning documents)

**Examples requiring a website issue**:
- New CLI command or flag added
- Hero capabilities changed (new agent, removed feature)
- Installation steps changed (`uf setup` flow)
- New convention pack added
- Breaking changes to any user-facing workflow

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

## Active Technologies
- Shell scripts (bash), Containerfile (OCI/Docker syntax), YAML (devfile 2.2.0, compose, GitHub Actions) + Podman, Go 1.24+, Node.js 20+, npm, Git, gh CLI (001-initial-containerfile)

## Recent Changes
- 001-initial-containerfile: Added initial Containerfile, Containerfile.udi, devfiles, helper scripts, podman-compose, CI workflow, README
