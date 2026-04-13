## Context

The dynamic devfile's `install-tools` command references a local script
at `/projects/scripts/install-uf-tools.sh` which fails when the cloned
project isn't the containerfile repo. The README lacks factory URL
documentation and Red Hat Dev Spaces notes.

See proposal.md for full motivation and constitution alignment.

## Goals / Non-Goals

### Goals
- Make `devfile-dynamic.yaml` work with any cloned project
- Document factory URL patterns for one-click workspace creation
- Document Red Hat Dev Spaces compatibility (honestly — tested or not)

### Non-Goals
- Modifying `devfile.yaml` (custom image variant already works)
- Changing the install script itself (`scripts/install-uf-tools.sh`)
- Adding credential injection documentation (tracked in Issue #4)
- Adding devfile schema validation to CI

## Decisions

### D1: Curl from GitHub raw URL instead of local script

**Decision**: Replace the local file reference with:
```bash
curl -fsSL https://raw.githubusercontent.com/unbound-force/containerfile/main/scripts/install-uf-tools.sh | bash
```

**Rationale**: This is the simplest approach — no external tooling needed,
same pattern already used for OpenCode installation (`curl | bash`).
The URL points to the `main` branch so it always gets the latest script.
If the repo is private, the URL won't work — but this repo is public.

**Alternatives rejected**:
- Inline the script in the devfile: bloats the YAML, duplicates logic,
  maintenance burden
- Download from a release artifact: adds versioning complexity for a
  script that should always be latest

### D2: Factory URL documentation scope

**Decision**: Document the factory URL pattern with examples for both
`devfile.yaml` (default) and `devfile-dynamic.yaml` (explicit path).

**Rationale**: Che uses `devfile.yaml` at repo root by default. To use
`devfile-dynamic.yaml`, the factory URL needs `?devfilePath=devfile-dynamic.yaml`.
Both patterns should be documented.

### D3: Dev Spaces honesty policy

**Decision**: Document Dev Spaces as "expected to be compatible" with
known differences called out, but do not claim "tested" unless actually
verified in a Dev Spaces instance.

**Rationale**: Constitution IV (Executable Truth) requires documentation
to be honest. We haven't tested in Dev Spaces, so we say so.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| GitHub raw URL unavailable (rate limiting, outage) | Medium — postStart fails | Devfile error message tells user what to check |
| Script changes on main break existing workspaces | Low — script is stable | Version pinning via commit SHA available if needed |
| Dev Spaces has undocumented incompatibilities | Low | Honest documentation; users can file issues |
