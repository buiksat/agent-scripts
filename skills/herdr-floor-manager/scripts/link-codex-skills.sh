#!/usr/bin/env bash
set -euo pipefail

resolve_dir() {
  CDPATH= cd -- "$1" 2>/dev/null && pwd -P
}

configured_home="${HERDR_FLOOR_MANAGER_HOME:-$HOME}"
if ! install_home=$(resolve_dir "$configured_home"); then
  printf 'unable to resolve HERDR_FLOOR_MANAGER_HOME: %s\n' "$configured_home" >&2
  exit 1
fi

claude_skills="$install_home/.claude/skills"
codex_skills="${CODEX_HOME:-$install_home/.codex}/skills"

mkdir -p "$codex_skills"

link_resolves_to_source() {
  local link_path=$1
  local source_directory=$2
  local resolved_link

  [ -L "$link_path" ] || return 1
  resolved_link=$(resolve_dir "$link_path") || return 1
  [ "$resolved_link" = "$source_directory" ] || return 1
  [ -f "$resolved_link/SKILL.md" ]
}

for name in herdr-floor-manager codex-first; do
  source_path="$claude_skills/$name"
  target_path="$codex_skills/$name"

  if ! source_directory=$(resolve_dir "$source_path") || [ ! -f "$source_directory/SKILL.md" ]; then
    printf 'missing skill source: %s\n' "$source_path" >&2
    exit 1
  fi

  if link_resolves_to_source "$target_path" "$source_directory"; then
    continue
  fi
  if python3 - "$source_path" "$target_path" <<'PY'
import os
import sys

try:
    os.symlink(sys.argv[1], sys.argv[2])
except FileExistsError:
    raise SystemExit(17)
except OSError as error:
    print(f"unable to create symlink: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
  then
    continue
  fi

  # Another invocation may have won the atomic create.
  if link_resolves_to_source "$target_path" "$source_directory"; then
    continue
  fi
  if [ -L "$target_path" ]; then
    printf 'refusing to replace foreign or dangling Codex skill symlink: %s\n' "$target_path" >&2
  elif [ -e "$target_path" ]; then
    printf 'refusing to replace real Codex skill: %s\n' "$target_path" >&2
  else
    printf 'unable to create Codex skill symlink: %s\n' "$target_path" >&2
  fi
  exit 1
done
