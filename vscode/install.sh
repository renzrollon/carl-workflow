#!/usr/bin/env bash
#
# install.sh - Install carl-workflow VS Code custom agents into a project.
#
# Installs .agent.md files into <project>/.github/agents/ (VS Code standard
# discovery path for custom agents).
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

Install carl-workflow VS Code custom agents into a project.

Options:
  --target <dir>   Install into <dir> instead of current directory.
  --force          Replace existing files without prompting.
                   Existing files are backed up to <name>.bak.<timestamp>.
  --dry-run        Print actions without making changes.
  -h, --help       Show this help and exit.

Environment:
  VSCODE_TARGET    Same effect as --target.

Behavior:
  For each .agent.md file in the source agents/ directory, the script will:
    - Install if the target does not exist.
    - Skip / backup-and-replace / abort (interactive prompt) if the target exists.
    - Always backup-and-replace if --force is set.

  Target: <project>/.github/agents/

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

log "carl-workflow VS Code agents installer"
log "  source:  $AGENTS_SRC"
log "  target:  $VSCODE_TARGET"
log "  dest:    $AGENTS_DEST"
if [ "$DRY_RUN" -eq 1 ]; then log "  mode:    dry-run"; fi
if [ "$FORCE"   -eq 1 ]; then log "  force:   yes"; fi
log ""

run "mkdir -p \"$AGENTS_DEST\""

# ---------------------------------------------------------------------------
# Main loop — install agents
# ---------------------------------------------------------------------------

for src in "$AGENTS_SRC"/*.agent.md; do
  [ -f "$src" ] || continue
  name="$(basename "$src")"
  dest="$AGENTS_DEST/$name"

  if [ ! -e "$dest" ]; then
    log "install   $name"
    run "cp \"$src\" \"$dest\""
    INSTALLED=$((INSTALLED + 1))
    continue
  fi

  CONFLICTS=$((CONFLICTS + 1))

  if [ "$FORCE" -eq 1 ]; then
    backup="$dest.bak.$(timestamp)"
    log "replace   $name (backup: $(basename "$backup"))"
    run "mv \"$dest\" \"$backup\""
    run "cp \"$src\" \"$dest\""
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
      run "cp \"$src\" \"$dest\""
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
log ""
log "Next steps:"
log "  1. Open the project in VS Code"
log "  2. Open Copilot Chat (Ctrl+Shift+I / Cmd+Shift+I)"
log "  3. Select an agent from the @ dropdown (look for Carl, Review:, Explore, etc.)"
log "  4. Reload VS Code window if agents don't appear immediately"

if [ "$DRY_RUN" -eq 1 ]; then
  log ""
  log "(dry-run: no changes were made)"
fi
