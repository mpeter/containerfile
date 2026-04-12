#!/usr/bin/env bash
# extract-changes.sh — Export agent changes as git format-patch output.
#
# The ONLY approved method for extracting changes from a headless
# (Model B) container where the source directory is mounted read-only.
# The developer reviews the patches on the host before applying them.
#
# Usage:
#   extract-changes.sh [output-dir] [base-ref]
#
# Arguments:
#   $1 (optional): Output directory for patch files. If omitted,
#                  patches are written to stdout.
#   $2 (optional): Base ref to diff against. Defaults to the branch
#                  HEAD when the container started.
#
# Constraints:
#   - Operates on the container's internal working copy, NOT the
#     read-only source mount (FR-014, FR-021)
#   - Produces standard git format-patch output (apply with git am)
#   - MUST NOT modify the host filesystem (Constitution II)

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
  printf '\033[1;34m[extract-changes]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[extract-changes]\033[0m %s\n' "$*"
}

error() {
  printf '\033[1;31m[extract-changes]\033[0m %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# 1. Working directory check — must be inside a git repository
# ---------------------------------------------------------------------------

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error "Not inside a git repository. Run this script from a git working tree."
  exit 1
fi

# Move to the repository root for consistent operation
cd "$(git rev-parse --show-toplevel)"

# ---------------------------------------------------------------------------
# 2. Parse arguments
# ---------------------------------------------------------------------------

OUTPUT_DIR="${1:-}"
BASE_REF="${2:-}"

# If no base ref provided, use the current branch's upstream or initial
# commit. The entrypoint copies the source into the writable area, so
# HEAD at that point is the base.
if [ -z "$BASE_REF" ]; then
  # Use the merge-base with the first commit as a fallback — this
  # captures all commits made during the container session.
  # If there's an upstream tracking branch, diff against that.
  if git rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
    BASE_REF='@{upstream}'
  else
    # No upstream — diff against the initial commit that was present
    # when the container started. Use the first commit on the branch.
    BASE_REF="HEAD"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Set git user defaults if not configured (needed for temporary commits)
# ---------------------------------------------------------------------------

if ! git config user.name >/dev/null 2>&1; then
  git config user.name "OpenCode Agent"
fi

if ! git config user.email >/dev/null 2>&1; then
  git config user.email "agent@opencode.ai"
fi

# ---------------------------------------------------------------------------
# 4. Detect and handle uncommitted changes
# ---------------------------------------------------------------------------

TEMP_COMMIT_CREATED=false

# Check for any uncommitted changes (staged + unstaged + untracked)
if ! git diff --quiet HEAD 2>/dev/null || \
   ! git diff --cached --quiet 2>/dev/null || \
   [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then

  info "Uncommitted changes detected — creating temporary commit ..."
  git add -A
  git commit -m "agent: changes from container session" --no-verify >/dev/null 2>&1
  TEMP_COMMIT_CREATED=true
fi

# ---------------------------------------------------------------------------
# 5. Check if there are any commits to extract
# ---------------------------------------------------------------------------

# Count commits between base ref and HEAD
if [ "$BASE_REF" = "HEAD" ]; then
  # BASE_REF is HEAD — check if the temp commit was created
  if [ "$TEMP_COMMIT_CREATED" = true ]; then
    # We just created a commit, so diff HEAD~1..HEAD
    PATCH_BASE="HEAD~1"
  else
    info "No changes to extract."
    exit 0
  fi
else
  PATCH_BASE="$BASE_REF"
fi

# Verify there are actually commits to extract
COMMIT_COUNT=$(git rev-list --count "${PATCH_BASE}..HEAD" 2>/dev/null || echo "0")

if [ "$COMMIT_COUNT" -eq 0 ]; then
  info "No changes to extract."
  exit 0
fi

info "Found $COMMIT_COUNT commit(s) to extract."

# ---------------------------------------------------------------------------
# 6. Generate patches
# ---------------------------------------------------------------------------

if [ -n "$OUTPUT_DIR" ]; then
  # Write patch files to the output directory
  mkdir -p "$OUTPUT_DIR"
  git format-patch "${PATCH_BASE}..HEAD" -o "$OUTPUT_DIR"
  info "Patches written to $OUTPUT_DIR/"
else
  # Write patches to stdout (for piping via podman exec)
  git format-patch "${PATCH_BASE}..HEAD" --stdout
fi
