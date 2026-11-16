## Context

The repository contains one finished strategic spec and two existing OpenSpec
changes. No canonical specs exist. Container builds copy only shell scripts;
repository command and agent prompts are not embedded or deployed by the image.

## Goals / Non-Goals

- Make OpenSpec the sole requirements authority.
- Preserve historical content and task states, using neutral terminology.
- Do not modify image contents, upstream scaffold implementations, or user files.
- Do not change versions, publish images, push branches, or open a PR.

## Decisions

- Archive the initial strategic spec under its merged PR date, 2026-04-12.
  Keep its 23 checked tasks checked; do not infer new verification from that state.
  Append PR #2 evidence and distinguish historical assertions from current checks.
- Move the constitution without changing principles or release requirements.
  Only the workflow and paths change, as authorized by the owner.
- Update existing local prompts in place, preserving tool restrictions and review
  limits. Remove instructions that regenerate the retired workflow.
- Preserve the two existing OpenSpec changes' requirements and task states.
- Repair their delta file layout to `specs/<capability>/spec.md` so validation
  actually reads them; add the missing README scenario restating its requirement.
  No existing requirement or scenario is removed, and task states stay unchanged.
- There are no shipped assets to remove, so no stale-user-file deletion path or
  product release entry is required. The local initialization prompt must not
  create or customize retired workflow assets.

## Risks / Trade-offs

An upstream `uf init` may restore old prompts until that tool's owning repository
changes. This repository cannot change upstream behavior. Container build gates
may require registry access and native architecture runners; record actual
failures rather than substituting static checks for runtime acceptance.

Constitution alignment is assessed in the proposal: all four principles remain
unchanged. Image releases remain commit-SHA/`latest` based; no version bump.
