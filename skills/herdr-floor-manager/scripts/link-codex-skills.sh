#!/usr/bin/env bash
set -euo pipefail

install_home="${HERDR_FLOOR_MANAGER_HOME:-$HOME}"
claude_skills="$install_home/.claude/skills"
codex_skills="${CODEX_HOME:-$install_home/.codex}/skills"

mkdir -p "$codex_skills"

for name in herdr-floor-manager codex-first; do
  source_path="$claude_skills/$name"
  target_path="$codex_skills/$name"

  [ -f "$source_path/SKILL.md" ] || {
    printf 'missing skill source: %s\n' "$source_path" >&2
    exit 1
  }

  if [ -L "$target_path" ]; then
    [ "$(readlink "$target_path")" = "$source_path" ] || ln -sfn "$source_path" "$target_path"
  elif [ -e "$target_path" ]; then
    printf 'refusing to replace real Codex skill: %s\n' "$target_path" >&2
    exit 1
  else
    ln -s "$source_path" "$target_path"
  fi
done
