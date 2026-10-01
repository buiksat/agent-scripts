#!/usr/bin/env bash
set -euo pipefail

skill_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
skills_root=$(cd "$skill_dir/.." && pwd)
install_home="${HERDR_FLOOR_MANAGER_HOME:-$HOME}"
claude_skills="$install_home/.claude/skills"
bashrc="$install_home/.bashrc"
start_marker='# [herdr-floor-manager-sync]'
end_marker='# [/herdr-floor-manager-sync]'

[ -f "$skills_root/herdr-floor-manager/SKILL.md" ] || {
  printf 'missing herdr-floor-manager beside installer: %s\n' "$skills_root" >&2
  exit 1
}
[ -f "$skills_root/codex-first/SKILL.md" ] || {
  printf 'missing codex-first dependency beside installer: %s\n' "$skills_root" >&2
  exit 1
}

mkdir -p "$claude_skills"
for name in herdr-floor-manager codex-first; do
  source_path="$skills_root/$name"
  target_path="$claude_skills/$name"
  if [ "$source_path" -ef "$target_path" ] 2>/dev/null; then
    continue
  fi
  if [ -L "$target_path" ]; then
    printf 'refusing to replace Claude skill symlink: %s\n' "$target_path" >&2
    exit 1
  fi
  mkdir -p "$target_path"
  rsync -a "$source_path/" "$target_path/"
done

"$claude_skills/herdr-floor-manager/scripts/link-codex-skills.sh"

touch "$bashrc"
if ! grep -Fq "$start_marker" "$bashrc"; then
  {
    printf '\n%s\n' "$start_marker"
    printf 'if [ -x "$HOME/.claude/skills/herdr-floor-manager/scripts/link-codex-skills.sh" ]; then\n'
    printf '  "$HOME/.claude/skills/herdr-floor-manager/scripts/link-codex-skills.sh" >/dev/null 2>&1 || printf '\''[herdr-floor-manager] skill link failed\\n'\'' >&2\n'
    printf 'fi\n'
    printf '%s\n' "$end_marker"
  } >> "$bashrc"
fi

printf 'installed herdr-floor-manager and codex-first for Claude and Codex\n'
