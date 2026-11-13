# Contract: extract-changes.sh

**Path**: `scripts/extract-changes.sh`
**Runs on**: Container (at runtime, invoked by developer)
**Referenced by**: `podman-compose.yml` (documented in README)
**Requirements**: FR-014, FR-021

## Purpose

Export changes made by the AI agent inside the container as
`git format-patch` output. This is the ONLY approved method for
extracting changes from a headless (Model B) container where the
source directory is mounted read-only. The developer reviews the
patches on the host before applying them.

## Interface

**Inputs**:
- Working directory: Must be inside a git repository with uncommitted
  or committed changes relative to the original mount.
- `$1` (optional): Output directory for patch files. If omitted,
  patches are written to stdout.
- `$2` (optional): Base ref to diff against. Defaults to the branch
  that was checked out when the container started (typically `HEAD`
  of the mounted repo's current branch).

**Outputs**:
- Patch files in `git format-patch` format, either:
  - Written to the specified output directory (one file per commit), or
  - Printed to stdout (for piping to the host via `podman exec`)
- Exit code 0 on success, non-zero on failure
- Exit code 0 with informational message if there are no changes

**Side effects**:
- May create patch files in the output directory
- May create temporary commits from staged/unstaged changes

## Behavior

1. **Working directory check**: Verify the current directory is inside
   a git repository. If not, print an error and exit 1.

2. **Detect changes**: Check for uncommitted changes (staged and
   unstaged). If changes exist:
   a. Stage all changes (`git add -A`).
   b. Create a temporary commit with a descriptive message
      (e.g., `"agent: changes from container session"`).

3. **Generate patches**: Run `git format-patch` against the base ref
   to produce patch files.

4. **Output**: Write patches to the output directory or stdout.

5. **No changes**: If there are no changes (no uncommitted changes and
   no new commits since the base ref), print an informational message
   and exit 0.

## Constraints

- MUST work when the source mount is read-only (the script operates
  on the container's internal working copy, not the mounted source).
- MUST NOT modify the host filesystem directly (Constitution II).
- MUST produce standard `git format-patch` output that can be applied
  with `git am` on the host.
- MUST use `set -euo pipefail` for strict error handling.
- MUST handle the case where git user.name/user.email are not
  configured (set defaults if needed for the temporary commit).

## Validation

```bash
# Inside a running container with changes:
/scripts/extract-changes.sh
# Should output patch content to stdout

/scripts/extract-changes.sh /tmp/patches
# Should create patch files in /tmp/patches/

# No changes:
/scripts/extract-changes.sh
# Should print "No changes to extract" and exit 0

# Not a git repo:
cd /tmp && /scripts/extract-changes.sh
# Should print error and exit 1
```
