#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
linker="$script_dir/link-codex-skills.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Keep every default linker destination inside this fixture.
HOME="$tmp_dir/default-home"
export HOME
unset CODEX_HOME

fail() {
  printf 'link-codex-skills test failed: %s\n' "$1" >&2
  exit 1
}

make_home() {
  local install_home=$1
  local name

  mkdir -p "$install_home/.codex/skills"
  for name in herdr-floor-manager codex-first; do
    mkdir -p "$install_home/.claude/skills/$name"
    printf '%s\n' "# $name" > "$install_home/.claude/skills/$name/SKILL.md"
  done
}

assert_skill_link() {
  local link_path=$1
  local source_path=$2
  local resolved_link
  local resolved_source

  [ -L "$link_path" ] || fail "expected symlink at $link_path"
  [ -f "$link_path/SKILL.md" ] || fail "link does not resolve to a skill: $link_path"
  resolved_link=$(CDPATH= cd -- "$link_path" && pwd -P)
  resolved_source=$(CDPATH= cd -- "$source_path" && pwd -P)
  [ "$resolved_link" = "$resolved_source" ] || fail "link resolves to the wrong source: $link_path"
}

idempotent_home="$tmp_dir/idempotent"
make_home "$idempotent_home"
relative_target='../../.claude/skills/herdr-floor-manager'
ln -s "$relative_target" "$idempotent_home/.codex/skills/herdr-floor-manager"
HERDR_FLOOR_MANAGER_HOME="$idempotent_home" "$linker"
[ "$(readlink "$idempotent_home/.codex/skills/herdr-floor-manager")" = "$relative_target" ] || \
  fail 'correct link text changed during an idempotent run'
assert_skill_link \
  "$idempotent_home/.codex/skills/herdr-floor-manager" \
  "$idempotent_home/.claude/skills/herdr-floor-manager"
herdr_link_before=$(readlink "$idempotent_home/.codex/skills/herdr-floor-manager")
codex_link_before=$(readlink "$idempotent_home/.codex/skills/codex-first")
HERDR_FLOOR_MANAGER_HOME="$idempotent_home" "$linker"
[ "$(readlink "$idempotent_home/.codex/skills/herdr-floor-manager")" = "$herdr_link_before" ] || \
  fail 'existing herdr-floor-manager link changed on rerun'
[ "$(readlink "$idempotent_home/.codex/skills/codex-first")" = "$codex_link_before" ] || \
  fail 'existing codex-first link changed on rerun'

foreign_home="$tmp_dir/foreign"
foreign_source="$tmp_dir/foreign-source"
make_home "$foreign_home"
mkdir -p "$foreign_source"
printf '%s\n' '# foreign' > "$foreign_source/SKILL.md"
ln -s "$foreign_source" "$foreign_home/.codex/skills/herdr-floor-manager"
if HERDR_FLOOR_MANAGER_HOME="$foreign_home" "$linker" >"$tmp_dir/foreign.out" 2>&1; then
  fail 'foreign link was accepted'
fi
[ "$(readlink "$foreign_home/.codex/skills/herdr-floor-manager")" = "$foreign_source" ] || \
  fail 'foreign link changed after refusal'

dangling_home="$tmp_dir/dangling"
dangling_source="$tmp_dir/missing-source"
make_home "$dangling_home"
ln -s "$dangling_source" "$dangling_home/.codex/skills/herdr-floor-manager"
if HERDR_FLOOR_MANAGER_HOME="$dangling_home" "$linker" >"$tmp_dir/dangling.out" 2>&1; then
  fail 'dangling link was accepted'
fi
[ "$(readlink "$dangling_home/.codex/skills/herdr-floor-manager")" = "$dangling_source" ] || \
  fail 'dangling link changed after refusal'

directory_home="$tmp_dir/real-directory"
directory_target="$directory_home/.codex/skills/herdr-floor-manager"
race_bin="$tmp_dir/race-bin"
real_python=$(command -v python3)
make_home "$directory_home"
mkdir -p "$race_bin"
cat > "$race_bin/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

target_path=$3
mkdir -p "$target_path"
printf 'preserve me\n' > "$target_path/sentinel"
exec "$REAL_PYTHON" "$@"
EOF
chmod +x "$race_bin/python3"
if PATH="$race_bin:$PATH" REAL_PYTHON="$real_python" \
  HERDR_FLOOR_MANAGER_HOME="$directory_home" \
  "$linker" >"$tmp_dir/real-directory.out" 2>&1; then
  fail 'real destination directory was accepted'
fi
[ -d "$directory_target" ] || fail 'real destination directory was replaced'
[ "$(cat "$directory_target/sentinel")" = 'preserve me' ] || \
  fail 'real destination directory contents changed'
[ ! -e "$directory_target/herdr-floor-manager" ] && \
  [ ! -L "$directory_target/herdr-floor-manager" ] || \
  fail 'link creation followed the real destination directory'

concurrent_home="$tmp_dir/concurrent"
make_home "$concurrent_home"
pids=()
run_number=1
while [ "$run_number" -le 24 ]; do
  HERDR_FLOOR_MANAGER_HOME="$concurrent_home" "$linker" \
    >"$tmp_dir/concurrent-$run_number.out" 2>&1 &
  pids+=("$!")
  run_number=$((run_number + 1))
done
concurrent_failure=0
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    concurrent_failure=1
  fi
done
if [ "$concurrent_failure" -ne 0 ]; then
  cat "$tmp_dir"/concurrent-*.out >&2
  fail 'a concurrent invocation failed'
fi
for name in herdr-floor-manager codex-first; do
  assert_skill_link \
    "$concurrent_home/.codex/skills/$name" \
    "$concurrent_home/.claude/skills/$name"
  [ ! -e "$concurrent_home/.claude/skills/$name/$name" ] && \
    [ ! -L "$concurrent_home/.claude/skills/$name/$name" ] || \
    fail "concurrent run created a nested link for $name"
done

relative_root="$tmp_dir/relative-root"
relative_home="$relative_root/install-home"
mkdir -p "$relative_root"
make_home "$relative_home"
(
  cd "$relative_root"
  HERDR_FLOOR_MANAGER_HOME=install-home "$linker"
)
for name in herdr-floor-manager codex-first; do
  assert_skill_link \
    "$relative_home/.codex/skills/$name" \
    "$relative_home/.claude/skills/$name"
  case "$(readlink "$relative_home/.codex/skills/$name")" in
    /*) ;;
    *) fail "relative home produced a relative link for $name" ;;
  esac
done

if HERDR_FLOOR_MANAGER_HOME="$tmp_dir/not-present" "$linker" >"$tmp_dir/unresolved.out" 2>&1; then
  fail 'unresolvable home was accepted'
fi

printf 'link-codex-skills tests passed\n'
