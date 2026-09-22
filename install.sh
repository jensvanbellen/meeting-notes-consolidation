#!/usr/bin/env bash
# Install (or uninstall) the /meeting-notes-consolidation skill for Claude Code and Codex.
#
# Both tools read the same SKILL.md, so the skill directory is symlinked into each
# tool's skills directory — one source of truth, edits take effect immediately.
# Codex also gets a thin custom prompt so /meeting-notes-consolidation is a slash
# command there.
#
# omp (Oh My Pi) reads ~/.claude/skills directly when skills.enableClaudeUser is on,
# so the Claude link below is all omp needs — no separate step.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="meeting-notes-consolidation"

CLAUDE_SKILLS_DIR="${CLAUDE_HOME:-$HOME/.claude}/skills"
CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
CODEX_PROMPTS_DIR="${CODEX_HOME:-$HOME/.codex}/prompts"

remove_link() {
  local dest=$1
  if [[ -L "$dest" ]]; then
    rm -- "$dest"
    echo "Removed $dest"
  elif [[ -e "$dest" ]]; then
    echo "SKIP: $dest exists and is not a symlink — leaving it untouched." >&2
  fi
}

if [[ "${1:-}" == "--uninstall" ]]; then
  remove_link "$CLAUDE_SKILLS_DIR/$SKILL_NAME"
  remove_link "$CODEX_SKILLS_DIR/$SKILL_NAME"
  remove_link "$CODEX_PROMPTS_DIR/$SKILL_NAME.md"
  exit 0
fi

link() {
  local target=$1 dest=$2
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    echo "SKIP: $dest exists and is not a symlink — remove it manually first." >&2
    return 1
  fi
  ln -sfn "$target" "$dest"
  echo "Linked $dest -> $target"
}

mkdir -p "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR" "$CODEX_PROMPTS_DIR"

link "$REPO_DIR/skills/$SKILL_NAME" "$CLAUDE_SKILLS_DIR/$SKILL_NAME"
link "$REPO_DIR/skills/$SKILL_NAME" "$CODEX_SKILLS_DIR/$SKILL_NAME"
link "$REPO_DIR/codex/prompts/$SKILL_NAME.md" "$CODEX_PROMPTS_DIR/$SKILL_NAME.md"

echo
echo "Done. Invoke with /$SKILL_NAME in Claude Code and Codex (and via ~/.claude/skills in omp)."
