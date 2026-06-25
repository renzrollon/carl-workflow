#!/usr/bin/env bash
#
# uninstall.sh - Remove carl-workflow skills from a Claude Code home directory.
#
# Only removes skill directories whose names match this repo's skills/ subdirs.
# Refuses to delete unless --force. With --force, prompts confirmation per dir.

set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
WORKFLOWS_SRC="$REPO_ROOT/workflows"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
FORCE=0
DRY_RUN=0

REMOVED=0
SKIPPED=0
MISSING=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: uninstall.sh [options]

Remove carl-workflow skills from a Claude Code home directory.

Only directories whose names match this repo's skills/ subdirs are touched.
Other skills in the destination are left alone.

Options:
  --prefix <dir>   Uninstall from <dir> instead of $CLAUDE_HOME (default: ~/.claude).
  --force          Required to actually delete. Still prompts per-directory.
  --dry-run        Print actions without making changes.
  -h, --help       Show this help and exit.

Environment:
  CLAUDE_HOME      Same effect as --prefix.

Without --force, the script lists what it would remove and exits without
deleting anything.

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
    --prefix)
      if [ $# -lt 2 ]; then
        log "Error: --prefix requires a directory argument" >&2
        exit 1
      fi
      CLAUDE_HOME="$2"
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

if [ ! -d "$SKILLS_SRC" ]; then
  log "Error: skills source directory not found: $SKILLS_SRC" >&2
  exit 1
fi

SKILLS_DEST="$CLAUDE_HOME/skills"

log "carl-workflow uninstaller"
log "  source:      $SKILLS_SRC"
log "  destination: $SKILLS_DEST"
if [ "$DRY_RUN" -eq 1 ]; then log "  mode:        dry-run"; fi
if [ "$FORCE"   -eq 0 ]; then log "  mode:        preview (use --force to delete)"; fi
log ""

if [ ! -d "$SKILLS_DEST" ]; then
  log "No skills directory at $SKILLS_DEST. Nothing to do."
  exit 0
fi

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

for src in "$SKILLS_SRC"/*/; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  dest="$SKILLS_DEST/$name"

  if [ ! -e "$dest" ]; then
    log "missing   $name"
    MISSING=$((MISSING + 1))
    continue
  fi

  if [ "$FORCE" -eq 0 ]; then
    log "would-rm  $name"
    continue
  fi

  printf 'Remove %s? [y/N] ' "$name"
  if ! read -r choice; then
    choice=""
  fi
  case "${choice:-n}" in
    y|Y)
      log "remove    $name"
      run "rm -rf \"$dest\""
      REMOVED=$((REMOVED + 1))
      ;;
    *)
      log "skip      $name"
      SKIPPED=$((SKIPPED + 1))
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Workflows
# ---------------------------------------------------------------------------

WORKFLOWS_DEST="$CLAUDE_HOME/workflows"
WF_REMOVED=0
WF_MISSING=0

if [ -d "$WORKFLOWS_SRC" ] && [ -d "$WORKFLOWS_DEST" ]; then
  for src in "$WORKFLOWS_SRC"/*.js; do
    [ -f "$src" ] || continue
    name="$(basename "$src")"
    dest="$WORKFLOWS_DEST/$name"

    if [ ! -e "$dest" ]; then
      log "missing   workflow: $name"
      WF_MISSING=$((WF_MISSING + 1))
      continue
    fi

    if [ "$FORCE" -eq 0 ]; then
      log "would-rm  workflow: $name"
      continue
    fi

    printf 'Remove workflow %s? [y/N] ' "$name"
    if ! read -r choice; then
      choice=""
    fi
    case "${choice:-n}" in
      y|Y)
        log "remove    workflow: $name"
        run "rm -f \"$dest\""
        WF_REMOVED=$((WF_REMOVED + 1))
        ;;
      *)
        log "skip      workflow: $name"
        SKIPPED=$((SKIPPED + 1))
        ;;
    esac
  done
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log ""
log "Summary:"
log "  skills removed:    $REMOVED"
log "  skills skipped:    $SKIPPED"
log "  skills missing:    $MISSING"
log "  workflows removed: $WF_REMOVED"
log "  workflows missing: $WF_MISSING"

if [ "$FORCE" -eq 0 ]; then
  log ""
  log "(preview: re-run with --force to actually remove)"
elif [ "$DRY_RUN" -eq 1 ]; then
  log ""
  log "(dry-run: no changes were made)"
fi
