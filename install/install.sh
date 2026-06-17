#!/usr/bin/env bash
#
# install.sh - Install carl-workflow skills into a Claude Code home directory.
#
# Defaults to ~/.claude. Override with --prefix <dir> or $CLAUDE_HOME env var.
# Compatible with macOS bash 3.2 and modern Linux bash.

set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
FORCE=0
DRY_RUN=0

INSTALLED=0
REPLACED=0
SKIPPED=0
CONFLICTS=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Install carl-workflow skills into a Claude Code home directory.

Options:
  --prefix <dir>   Install into <dir> instead of $CLAUDE_HOME (default: ~/.claude).
  --force          Replace existing skill directories without prompting.
                   Existing dirs are backed up to <name>.bak.<timestamp>.
  --dry-run        Print actions without making changes.
  -h, --help       Show this help and exit.

Environment:
  CLAUDE_HOME      Same effect as --prefix.

Behavior:
  For each subdirectory of <repo>/skills/, the script will:
    - Install if the target does not exist.
    - Skip / backup-and-replace / abort (interactive prompt) if the target exists.
    - Always backup-and-replace if --force is set.

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

timestamp() {
  date +%Y%m%d-%H%M%S
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

log "carl-workflow installer"
log "  source:      $SKILLS_SRC"
log "  destination: $SKILLS_DEST"
if [ "$DRY_RUN" -eq 1 ]; then log "  mode:        dry-run"; fi
if [ "$FORCE"   -eq 1 ]; then log "  force:       yes"; fi
log ""

run "mkdir -p \"$SKILLS_DEST\""

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

for src in "$SKILLS_SRC"/*/; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  dest="$SKILLS_DEST/$name"

  if [ ! -e "$dest" ]; then
    log "install   $name"
    run "cp -R \"$src\" \"$dest\""
    INSTALLED=$((INSTALLED + 1))
    continue
  fi

  CONFLICTS=$((CONFLICTS + 1))

  if [ "$FORCE" -eq 1 ]; then
    backup="$dest.bak.$(timestamp)"
    log "replace   $name (backup: $(basename "$backup"))"
    run "mv \"$dest\" \"$backup\""
    run "cp -R \"$src\" \"$dest\""
    REPLACED=$((REPLACED + 1))
    continue
  fi

  printf '%s exists. [s]kip / [b]ackup-and-replace / [a]bort? (s) ' "$name"
  if ! read -r choice; then
    choice=""
  fi
  case "${choice:-s}" in
    b|B)
      backup="$dest.bak.$(timestamp)"
      log "  backup -> $(basename "$backup")"
      run "mv \"$dest\" \"$backup\""
      run "cp -R \"$src\" \"$dest\""
      REPLACED=$((REPLACED + 1))
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

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

log ""
log "Summary:"
log "  installed: $INSTALLED"
log "  replaced:  $REPLACED"
log "  skipped:   $SKIPPED"
log "  conflicts: $CONFLICTS"

if [ "$DRY_RUN" -eq 1 ]; then
  log ""
  log "(dry-run: no changes were made)"
fi
