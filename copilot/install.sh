#!/usr/bin/env bash
#
# install.sh - Install carl-workflow copilot skills into a project.
#
# Installs into .github/copilot-instructions.md (project-level) or
# ~/.config/github-copilot/apps/<repo>/instructions.md (per-app).
# Also installs individual SKILL.md files into .copilot/skills/ for
# granular skill management.
#
# Defaults to the current directory as the target project root.
# Override with --target <dir> or $COPILOT_TARGET env var.

set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/copilot/skills"

COPILOT_TARGET="${COPILOT_TARGET:-$(pwd)}"
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

Install carl-workflow copilot skills into a project.

Options:
  --target <dir>   Install into <dir> instead of current directory.
  --force          Replace existing files without prompting.
                   Existing files are backed up to <name>.bak.<timestamp>.
  --dry-run        Print actions without making changes.
  -h, --help       Show this help and exit.

Environment:
  COPILOT_TARGET   Same effect as --target.

Behavior:
  For each subdirectory of <repo>/copilot/skills/, the script will:
    - Install if the target does not exist.
    - Skip / backup-and-replace / abort (interactive prompt) if the target exists.
    - Always backup-and-replace if --force is set.

  Additionally, installs GEMINI.md.template as .github/copilot-instructions.md
  in the target project root (if it doesn't already exist).

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
      COPILOT_TARGET="$2"
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

if [ ! -d "$REPO_ROOT/copilot" ]; then
  log "Error: copilot source directory not found: $REPO_ROOT/copilot" >&2
  exit 1
fi

SKILLS_DEST="$COPILOT_TARGET/.copilot/skills"
INSTRUCTIONS_DEST="$COPILOT_TARGET/.github/copilot-instructions.md"

log "carl-workflow copilot installer"
log "  source:      $REPO_ROOT/copilot"
log "  target:      $COPILOT_TARGET"
log "  skills dest: $SKILLS_DEST"
log "  instructions: $INSTRUCTIONS_DEST"
if [ "$DRY_RUN" -eq 1 ]; then log "  mode:        dry-run"; fi
if [ "$FORCE"   -eq 1 ]; then log "  force:       yes"; fi
log ""

run "mkdir -p \"$SKILLS_DEST\""
run "mkdir -p \"$(dirname "$INSTRUCTIONS_DEST")\""

# ---------------------------------------------------------------------------
# Install GEMINI.md.template as copilot-instructions.md
# ---------------------------------------------------------------------------

GEMINI_SRC="$REPO_ROOT/copilot/GEMINI.md.template"

if [ ! -f "$INSTRUCTIONS_DEST" ]; then
  log "install   copilot-instructions.md (from GEMINI.md.template)"
  run "cp \"$GEMINI_SRC\" \"$INSTRUCTIONS_DEST\""
  INSTALLED=$((INSTALLED + 1))
else
  CONFLICTS=$((CONFLICTS + 1))
  if [ "$FORCE" -eq 1 ]; then
    backup="$INSTRUCTIONS_DEST.bak.$(timestamp)"
    log "replace   copilot-instructions.md (backup: $(basename "$backup"))"
    run "mv \"$INSTRUCTIONS_DEST\" \"$backup\""
    run "cp \"$GEMINI_SRC\" \"$INSTRUCTIONS_DEST\""
    REPLACED=$((REPLACED + 1))
  else
    printf '%s exists. [s]kip / [b]ackup-and-replace / [a]bort? (s) ' "$INSTRUCTIONS_DEST"
    if ! read -r choice; then
      choice=""
    fi
    case "${choice:-s}" in
      b|B)
        backup="$INSTRUCTIONS_DEST.bak.$(timestamp)"
        log "  backup -> $(basename "$backup")"
        run "mv \"$INSTRUCTIONS_DEST\" \"$backup\""
        run "cp \"$GEMINI_SRC\" \"$INSTRUCTIONS_DEST\""
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
  fi
fi

# ---------------------------------------------------------------------------
# Main loop — install skills
# ---------------------------------------------------------------------------

for src in "$REPO_ROOT/copilot/skills"/*/; do
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
log ""
log "Next steps:"
log "  1. Edit $INSTRUCTIONS_DEST to customize your project instructions"
log "  2. Add skill-specific guidance to .copilot/skills/<skill>/SKILL.md files"
log "  3. Restart VS Code or reload the window for changes to take effect"

if [ "$DRY_RUN" -eq 1 ]; then
  log ""
  log "(dry-run: no changes were made)"
fi
