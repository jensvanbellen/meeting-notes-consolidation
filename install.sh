#!/usr/bin/env bash
# Install (or uninstall) the /meeting-notes-consolidation skill for Claude Code.
#
# The skill directory is symlinked into Claude Code's skills directory, so edits
# to this repo take effect immediately without reinstalling.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="meeting-notes-consolidation"
CLAUDE_SKILLS_DIR="${CLAUDE_HOME:-$HOME/.claude}/skills"
DEST="$CLAUDE_SKILLS_DIR/$SKILL_NAME"

if [[ "${1:-}" == "--uninstall" ]]; then
  if [[ -L "$DEST" ]]; then
    rm -- "$DEST"
    echo "Removed $DEST"
  elif [[ -e "$DEST" ]]; then
    echo "SKIP: $DEST exists and is not a symlink — leaving it untouched." >&2
  fi
  exit 0
fi

if [[ -e "$DEST" && ! -L "$DEST" ]]; then
  echo "SKIP: $DEST exists and is not a symlink — remove it manually first." >&2
  exit 1
fi

mkdir -p "$CLAUDE_SKILLS_DIR"
ln -sfn "$REPO_DIR/skills/$SKILL_NAME" "$DEST"
echo "Linked $DEST -> $REPO_DIR/skills/$SKILL_NAME"
echo
echo "Done. Invoke with /$SKILL_NAME in Claude Code."
