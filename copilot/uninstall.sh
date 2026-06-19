#!/usr/bin/env bash
#
# uninstall.sh - Remove carl-workflow copilot skills from a project.
#
# Removes .copilot/skills/ directories and optionally the
# .github/copilot-instructions.md file.
# Refuses to delete unless --force. With --force, prompts confirmation per dir.

set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COPILOT_TARGET="${COPILOT_TARGET:-$(pwd)}"
FORCE=0
DRY_RUN=0
REMOVE_INSTRUCTIONS=0

REMOVED_SKILLS=0
REMOVED_INSTRUCTIONS=0
SKIPPED=0
MISSING=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: uninstall.sh [options]

Remove carl-workflow copilot skills from a project.

Options:
  --target <dir>     Uninstall from <dir> instead of current directory.
  --force            Required to actually delete. Still prompts per-directory.
  --instructions     Also remove .github/copilot-instructions.md (if installed by this tool).
  --dry-run          Print actions without making changes.
  -h, --help         Show this help and exit.

Environment:
  COPILOT_TARGET     Same effect as --target.

Without --force, the script lists what it would remove and exits without
deleting anything.
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
      COPILOT_TARGET="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --instructions)
      REMOVE_INSTRUCTIONS=1
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

SKILLS_SRC="$REPO_ROOT/copilot/skills"
SKILLS_DEST="$COPILOT_TARGET/.copilot/skills"
INSTRUCTIONS_DEST="$COPILOT_TARGET/.github/copilot-instructions.md"

log "carl-workflow copilot uninstaller"
log "  target:      $COPILOT_TARGET"
log "  skills dest: $SKILLS_DEST"
if [ "$DRY_RUN" -eq 1 ]; then log "  mode:        preview (use --force to delete)"; fi
if [ "$REMOVE_INSTRUCTIONS" -eq 1 ]; then log "  instructions: will be removed"; fi
log ""

# ---------------------------------------------------------------------------
# Uninstall skills
# ---------------------------------------------------------------------------

if [ ! -d "$SKILLS_DEST" ]; then
  log "No skills directory at $SKILLS_DEST. Nothing to do."
else
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
        log "removing $name"
        run "rm -rf \"$dest\""
        REMOVED_SKILLS=$((REMOVED_SKILLS + 1))
        ;;
      *)
        log "  skipped"
        SKIPPED=$((SKIPPED + 1))
        ;;
    esac
  done

  # Clean up empty .copilot/skills/ directory if all skills were removed
  if [ "$REMOVED_SKILLS" -gt 0 ] && [ -d "$SKILLS_DEST" ]; then
    remaining="$(find "$SKILLS_DEST" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)"
    if [ -z "$remaining" ]; then
      log "cleaning up empty directory: $SKILLS_DEST"
      run "rmdir \"$SKILLS_DEST\""
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Uninstall instructions file (optional)
# ---------------------------------------------------------------------------

if [ "$REMOVE_INSTRUCTIONS" -eq 1 ]; then
  if [ ! -f "$INSTRUCTIONS_DEST" ]; then
    log "missing   copilot-instructions.md (not found)"
    MISSING=$((MISSING + 1))
  else
    if [ "$FORCE" -eq 0 ]; then
      log "would-rm  copilot-instructions.md"
    else
      printf 'Remove %s? [y/N] ' "$INSTRUCTIONS_DEST"
      if ! read -r choice; then
        choice=""
      fi
      case "${choice:-n}" in
        y|Y)
          log "removing $INSTRUCTIONS_DEST"
          run "rm -f \"$INSTRUCTIONS_DEST\""
          REMOVED_INSTRUCTIONS=$((REMOVED_INSTRUCTIONS + 1))
          # Clean up empty .github/ directory if it exists
          github_dir="$(dirname "$INSTRUCTIONS_DEST")"
          if [ -d "$github_dir" ]; then
            remaining_github="$(find "$github_dir" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)"
            if [ -z "$remaining_github" ]; then
              log "cleaning up empty directory: $github_dir"
              run "rmdir \"$github_dir\""
            fi
          fi
          ;;
        *)
          log "  skipped"
          SKIPPED=$((SKIPPED + 1))
          ;;
      esac
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log ""
log "Summary:"
log "  skills removed: $REMOVED_SKILLS"
log "  instructions removed: $REMOVED_INSTRUCTIONS"
log "  skipped:      $SKIPPED"
log "  missing:      $MISSING"

if [ "$DRY_RUN" -eq 1 ]; then
  log ""
  log "(dry-run: no changes were made)"
fi
