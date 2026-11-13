## Why

Two requirements pipelines leave competing answers to what governs a change.
OpenSpec will be the sole requirements authority, with finished strategic
artifacts retained as historical evidence rather than a second active pipeline.

## What Changes

- Archive the finished initial-containerfile strategic spec without changing task states.
- Move the constitution to `openspec/constitution.md` and update its workflow wording.
- Retire the previous workflow's commands, scripts, templates, and skill.
- Point repository guidance, agents, and commands only at OpenSpec artifacts.
- Preserve container definitions, shell scripts, deployment behavior, and versions.

## Capabilities

### New Capabilities
- `repository-workflow`: Single requirements authority and historical artifact preservation.

### Modified Capabilities
None. This repository has no canonical capability specs yet.

### Removed Capabilities
None of the container image's capabilities change.

## Impact

Repository development instructions only. The Containerfiles copy shell scripts,
not `.opencode/` assets. Upstream `uf init` behavior is outside this repository;
this change does not delete already-installed files in user workspaces.

## Constitution Alignment

### I. Composability First — PASS
No runtime dependencies or tool installations change.

### II. Security Through Isolation — PASS
No container privileges, mounts, credentials, or resource limits change.

### III. Reproducible Builds — PASS
Build definitions and smoke checks are unchanged; build gates will be attempted.

### IV. Executable Truth — PASS
Repository instructions match the retained workflow. Historical artifacts and
existing task states remain available with source PR evidence.
