#!/usr/bin/env bash
#
# uninstall.sh - Remove carl-workflow VS Code custom agents from a project.
#
# Removes .agent.md files from <project>/.github/agents/ that match
# the agents shipped by this repository.
#
# Defaults to the current directory as the target project root.
# Override with --target <dir> or $VSCODE_TARGET env var.

set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_SRC="$SCRIPT_DIR/agents"

VSCODE_TARGET="${VSCODE_TARGET:-$(pwd)}"
FORCE=0
DRY_RUN=0

REMOVED=0
SKIPPED=0
NOT_FOUND=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: uninstall.sh [options]

Remove carl-workflow VS Code custom agents from a project.

Options:
  --target <dir>   Remove from <dir> instead of current directory.
  --force          Remove without prompting for confirmation.
  --dry-run        Print actions without making changes.
  -h, --help       Show this help and exit.

Environment:
  VSCODE_TARGET    Same effect as --target.

Behavior:
  For each .agent.md file shipped by this repository, the script will:
    - Remove it from <project>/.github/agents/ if it exists.
    - Skip if the file doesn't exist in the target.
    - Prompt for confirmation unless --force is set.

  Only removes files whose names match this repo's agents/ directory.
  Other custom agents in the target are left untouched.

Exit codes:
  0  success
  1  error or user abort
EOF
}

log() {
  printf '%s\n' "$*"
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      if [ $# -lt 2 ]; then
        log "Error: --target requires a directory argument" >&2
        exit 1
      fi
      VSCODE_TARGET="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log "Error: unknown option '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

if [ ! -d "$AGENTS_SRC" ]; then
  log "Error: agents source directory not found: $AGENTS_SRC" >&2
  exit 1
fi

AGENTS_DEST="$VSCODE_TARGET/.github/agents"

if [ ! -d "$AGENTS_DEST" ]; then
  log "No agents directory found at $AGENTS_DEST — nothing to remove."
  exit 0
fi

log "carl-workflow VS Code agents uninstaller"
log "  source:  $AGENTS_SRC"
log "  target:  $AGENTS_DEST"
if [ "$DRY_RUN" -eq 1 ]; then log "  mode:    dry-run"; fi
if [ "$FORCE"   -eq 1 ]; then log "  force:   yes"; fi
log ""

# ---------------------------------------------------------------------------
# Main loop — remove agents
# ---------------------------------------------------------------------------

for src in "$AGENTS_SRC"/*.agent.md; do
  [ -f "$src" ] || continue
  name="$(basename "$src")"
  dest="$AGENTS_DEST/$name"

  if [ ! -e "$dest" ]; then
    NOT_FOUND=$((NOT_FOUND + 1))
    continue
  fi

  if [ "$FORCE" -eq 1 ]; then
    log "remove    $name"
    run "rm \"$dest\""
    REMOVED=$((REMOVED + 1))
    continue
  fi

  printf 'Remove %s? [y]es / [s]kip / [a]bort? (s) ' "$name"
  if ! read -r choice; then
    choice=""
  fi
  case "${choice:-s}" in
    y|Y)
      log "  removed"
      run "rm \"$dest\""
      REMOVED=$((REMOVED + 1))
      ;;
    a|A)
      log "Aborted by user."
      exit 1
      ;;
    *)
      log "  skipped"
      SKIPPED=$((SKIPPED + 1))
      ;;
  esac
done

# Remove the agents directory if empty
if [ "$DRY_RUN" -eq 0 ] && [ -d "$AGENTS_DEST" ] && [ -z "$(ls -A "$AGENTS_DEST")" ]; then
  rmdir "$AGENTS_DEST"
  log ""
  log "Removed empty directory: $AGENTS_DEST"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log ""
log "Summary:"
log "  removed:   $REMOVED"
log "  skipped:   $SKIPPED"
log "  not found: $NOT_FOUND"

if [ "$DRY_RUN" -eq 1 ]; then
  log ""
  log "(dry-run: no changes were made)"
fi
