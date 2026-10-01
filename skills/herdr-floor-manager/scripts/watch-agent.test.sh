#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
watchdog="$script_dir/watch-agent.sh"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
cat > "$tmp_dir/bin/herdr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[ "${1:-}" = agent ] && [ "${2:-}" = get ] || exit 70
if [ "${WATCHDOG_FAKE_FAIL:-0}" = 1 ]; then
  printf '{"error":{"code":"agent_not_found"}}\n' >&2
  exit 1
fi

count=0
[ ! -f "$WATCHDOG_COUNTER_FILE" ] || count=$(cat "$WATCHDOG_COUNTER_FILE")
count=$((count + 1))
printf '%s\n' "$count" > "$WATCHDOG_COUNTER_FILE"
line=$(sed -n "${count}p" "$WATCHDOG_SEQUENCE_FILE")
[ -n "$line" ] || line=$(tail -n 1 "$WATCHDOG_SEQUENCE_FILE")
status=${line%% *}
revision=${line#* }
if [ "$status" = fail ]; then
  printf '{"error":{"code":"temporary"}}\n' >&2
  exit 1
fi
if [ "$status" = hang ]; then
  exec sleep "$revision"
fi
if [ "$status" = invalid ]; then
  printf 'not json\n'
  exit 0
fi
if [ "${WATCHDOG_FAKE_WARN:-0}" = 1 ]; then
  printf 'successful warning on stderr\n' >&2
fi
printf '{"id":"cli:agent:get","result":{"agent":{"agent_status":"%s","revision":%s}}}\n' "$status" "$revision"
EOF
chmod +x "$tmp_dir/bin/herdr"

run_watchdog() {
  sequence=$1
  shift
  printf '%s\n' "$sequence" > "$tmp_dir/sequence"
  : > "$tmp_dir/counter"
  PATH="$tmp_dir/bin:$PATH" \
    WATCHDOG_SEQUENCE_FILE="$tmp_dir/sequence" \
    WATCHDOG_COUNTER_FILE="$tmp_dir/counter" \
    "$watchdog" "$@"
}

expect_exit() {
  local expected_exit=$1
  local actual_exit
  shift

  set +e
  expected_output=$("$@" 2>&1)
  actual_exit=$?
  set -e
  if [ "$actual_exit" -ne "$expected_exit" ]; then
    printf 'expected exit %s, got %s\ncommand: %s\noutput:\n%s\n' \
      "$expected_exit" "$actual_exit" "$*" "$expected_output" >&2
    exit 1
  fi
}

output=$(run_watchdog $'working 1\nworking 1\nworking 2\nworking 2\nworking 2\nidle 3' \
  --after-revision 0 --start-revision 1 --interval-seconds 1 --stall-seconds 4 --timeout-seconds 10 worker)
printf '%s\n' "$output" | grep -Fq 'WATCHDOG_READY target=worker status=idle revision=3'

output=$(run_watchdog $'working 1\nidle 2' \
  --after-revision 0 --start-revision 1 --interval-seconds 5 --stall-seconds 4 --timeout-seconds 2 worker)
printf '%s\n' "$output" | grep -Fq 'WATCHDOG_READY target=worker status=idle revision=2'

output=$(run_watchdog $'idle 5\nworking 6\nidle 7' \
  --after-revision 5 --start-revision 6 --interval-seconds 1 --stall-seconds 4 --timeout-seconds 8 worker)
printf '%s\n' "$output" | grep -Fq 'WATCHDOG_READY target=worker status=idle revision=7'

output=$(run_watchdog 'done 8' \
  --after-revision 7 --start-revision 8 --interval-seconds 1 --stall-seconds 2 --timeout-seconds 4 worker)
printf '%s\n' "$output" | grep -Fq 'WATCHDOG_READY target=worker status=done revision=8'

output=$(WATCHDOG_FAKE_WARN=1 run_watchdog 'done 9' \
  --after-revision 8 --start-revision 9 --interval-seconds 1 --stall-seconds 2 --timeout-seconds 4 worker)
printf '%s\n' "$output" | grep -Fq 'WATCHDOG_READY target=worker status=done revision=9'

expect_exit 2 run_watchdog 'blocked 4' \
  --after-revision 3 --start-revision 4 --interval-seconds 1 --stall-seconds 4 --timeout-seconds 8 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_UNHEALTHY target=worker status=blocked revision=4'

expect_exit 3 run_watchdog 'working 5' \
  --after-revision 4 --start-revision 5 --interval-seconds 1 --stall-seconds 2 --timeout-seconds 8 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_STALLED target=worker status=working revision=5'

expect_exit 3 run_watchdog $'working 40\nunknown 40\nworking 40' \
  --after-revision 39 --start-revision 40 --interval-seconds 1 --stall-seconds 2 --timeout-seconds 8 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_STALLED target=worker status=working revision=40'

expect_exit 4 run_watchdog $'working 10\nworking 11\nworking 12\nworking 13' \
  --after-revision 9 --start-revision 10 --interval-seconds 1 --stall-seconds 8 --timeout-seconds 2 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_TIMEOUT target=worker status=working'

expect_exit 4 run_watchdog 'unknown 14' \
  --after-revision 13 --start-revision 14 --interval-seconds 5 --stall-seconds 8 --timeout-seconds 2 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_TIMEOUT target=worker status=unknown revision=14'

expect_exit 2 run_watchdog 'unknown 14' \
  --after-revision 13 --start-revision 14 --interval-seconds 1 --stall-seconds 8 --timeout-seconds 6 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_UNHEALTHY target=worker status=unknown revision=14 readings=3'

expect_exit 5 run_watchdog 'invalid 0' \
  --after-revision 0 --start-revision 1 --interval-seconds 1 --stall-seconds 8 --timeout-seconds 6 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_ERROR target=worker reason=invalid_herdr_response attempts=3'

output=$(run_watchdog $'fail 0\nfail 0\nworking 20\nfail 0\nfail 0\nidle 21' \
  --after-revision 19 --start-revision 20 --interval-seconds 1 --stall-seconds 8 --timeout-seconds 10 worker 2>&1)
printf '%s\n' "$output" | grep -Fq 'WATCHDOG_READY target=worker status=idle revision=21'

output=$(run_watchdog $'unknown 30\nunknown 30\nworking 31\nunknown 32\nunknown 32\nidle 33' \
  --after-revision 29 --start-revision 30 --interval-seconds 1 --stall-seconds 8 --timeout-seconds 10 worker 2>&1)
printf '%s\n' "$output" | grep -Fq 'WATCHDOG_READY target=worker status=idle revision=33'

expect_exit 5 run_watchdog 'idle "bad"' \
  --after-revision 0 --start-revision 1 --interval-seconds 1 --stall-seconds 8 --timeout-seconds 4 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_ERROR target=worker reason=invalid_revision revision=bad'

expect_exit 2 env PATH="$tmp_dir/bin:$PATH" WATCHDOG_FAKE_FAIL=1 \
  WATCHDOG_SEQUENCE_FILE="$tmp_dir/sequence" WATCHDOG_COUNTER_FILE="$tmp_dir/counter" \
  "$watchdog" --after-revision 0 --start-revision 1 --interval-seconds 1 --stall-seconds 2 --timeout-seconds 8 missing
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_UNHEALTHY target=missing reason=agent_not_found'

expect_exit 5 run_watchdog 'hang 5' \
  --after-revision 0 --start-revision 1 --interval-seconds 1 --stall-seconds 8 \
  --poll-timeout-seconds 1 --timeout-seconds 10 worker
printf '%s\n' "$expected_output" | grep -Fq 'WATCHDOG_ERROR target=worker reason=agent_get_failed attempts=3'

expect_exit 64 env PATH="$tmp_dir/bin:$PATH" "$watchdog" \
  --after-revision 5 --start-revision 5 --timeout-seconds 10 worker
printf '%s\n' "$expected_output" | grep -Fq -- '--start-revision must be greater than --after-revision'

expect_exit 64 env PATH="$tmp_dir/bin:$PATH" "$watchdog" \
  --after-revision 0 --start-revision 1 --timeout-seconds 08 worker
printf '%s\n' "$expected_output" | grep -Fq -- '--timeout-seconds must be a positive integer'

expect_exit 64 env PATH="$tmp_dir/bin:$PATH" "$watchdog" worker
printf '%s\n' "$expected_output" | grep -Fq -- '--timeout-seconds must be a positive integer'

printf 'watch-agent tests passed\n'
