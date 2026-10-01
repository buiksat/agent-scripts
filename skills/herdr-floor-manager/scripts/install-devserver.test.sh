#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../../.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  printf 'install-devserver test failed: %s\n' "$1" >&2
  exit 1
}

source_skills="$tmp_dir/source/skills"
install_home="$tmp_dir/home"
mkdir -p "$source_skills" "$install_home"
cp -R "$repo_root/skills/herdr-floor-manager" "$source_skills/herdr-floor-manager"
cp -R "$repo_root/skills/codex-first" "$source_skills/codex-first"

printf 'old name\n' > "$source_skills/herdr-floor-manager/stale-name.txt"
HERDR_FLOOR_MANAGER_HOME="$install_home" \
  CODEX_HOME="$install_home/.codex" \
  "$source_skills/herdr-floor-manager/scripts/install-devserver.sh" \
  >"$tmp_dir/first-install.out"
[ -f "$install_home/.claude/skills/herdr-floor-manager/stale-name.txt" ] || \
  fail 'initial source file was not installed'

mv \
  "$source_skills/herdr-floor-manager/stale-name.txt" \
  "$source_skills/herdr-floor-manager/current-name.txt"
HERDR_FLOOR_MANAGER_HOME="$install_home" \
  CODEX_HOME="$install_home/.codex" \
  "$source_skills/herdr-floor-manager/scripts/install-devserver.sh" \
  >"$tmp_dir/second-install.out"

[ ! -e "$install_home/.claude/skills/herdr-floor-manager/stale-name.txt" ] || \
  fail 'renamed source file remained in the installed copy'
[ -f "$install_home/.claude/skills/herdr-floor-manager/current-name.txt" ] || \
  fail 'renamed source file was not installed'
diff -r \
  "$source_skills/herdr-floor-manager" \
  "$install_home/.claude/skills/herdr-floor-manager" \
  >"$tmp_dir/herdr.diff" || fail 'installed herdr-floor-manager differs from its source'
diff -r \
  "$source_skills/codex-first" \
  "$install_home/.claude/skills/codex-first" \
  >"$tmp_dir/codex-first.diff" || fail 'installed codex-first differs from its source'

printf 'install-devserver tests passed\n'
