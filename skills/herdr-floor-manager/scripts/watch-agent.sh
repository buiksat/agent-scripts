#!/usr/bin/env bash
set -euo pipefail

interval_seconds=15
stall_seconds=600
timeout_seconds=''
after_revision=''
start_revision=''
poll_timeout_seconds=10
max_poll_failures=3

usage() {
  printf 'usage: %s --after-revision N --start-revision N --timeout-seconds N [--interval-seconds N] [--stall-seconds N] [--poll-timeout-seconds N] <agent-name-or-pane>\n' "${0##*/}" >&2
}

require_positive_integer() {
  case "$2" in
    ''|*[!0-9]*|0*)
      printf '%s must be a positive integer: %s\n' "$1" "$2" >&2
      exit 64
      ;;
  esac
}

require_nonnegative_integer() {
  case "$2" in
    ''|*[!0-9]*|0[0-9]*)
      printf '%s must be a nonnegative integer: %s\n' "$1" "$2" >&2
      exit 64
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --interval-seconds)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      interval_seconds=$2
      shift 2
      ;;
    --stall-seconds)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      stall_seconds=$2
      shift 2
      ;;
    --timeout-seconds)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      timeout_seconds=$2
      shift 2
      ;;
    --after-revision)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      after_revision=$2
      shift 2
      ;;
    --poll-timeout-seconds)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      poll_timeout_seconds=$2
      shift 2
      ;;
    --start-revision)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      start_revision=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 64
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -eq 1 ] || { usage; exit 64; }
target=$1

require_positive_integer --interval-seconds "$interval_seconds"
require_positive_integer --stall-seconds "$stall_seconds"
require_positive_integer --timeout-seconds "$timeout_seconds"
require_nonnegative_integer --after-revision "$after_revision"
require_nonnegative_integer --start-revision "$start_revision"
require_positive_integer --poll-timeout-seconds "$poll_timeout_seconds"
[ "$start_revision" -gt "$after_revision" ] || {
  printf '%s\n' '--start-revision must be greater than --after-revision' >&2
  exit 64
}

command -v herdr >/dev/null 2>&1 || {
  printf 'WATCHDOG_ERROR target=%s reason=herdr_not_found\n' "$target" >&2
  exit 5
}
command -v python3 >/dev/null 2>&1 || {
  printf 'WATCHDOG_ERROR target=%s reason=python3_not_found\n' "$target" >&2
  exit 5
}
python3 -c 'import json' >/dev/null 2>&1 || {
  printf 'WATCHDOG_ERROR target=%s reason=python3_unusable\n' "$target" >&2
  exit 5
}

started_at=$(date +%s)
last_revision_at=$started_at
last_revision=''
last_status=''
poll_failures=0
unknown_readings=0
now=$started_at
elapsed=0
remaining=$timeout_seconds

refresh_deadline() {
  now=$(date +%s)
  elapsed=$((now - started_at))
  remaining=$((timeout_seconds - elapsed))
  if [ "$remaining" -le 0 ]; then
    printf 'WATCHDOG_TIMEOUT target=%s status=%s revision=%s elapsed_seconds=%s\n' \
      "$target" "${last_status:-not_observed}" "${last_revision:-none}" "$elapsed" >&2
    exit 4
  fi
}

sleep_until_next_poll() {
  local delay maximum_delay
  refresh_deadline
  maximum_delay=$((remaining - 1))
  if [ "$maximum_delay" -le 0 ]; then
    sleep "$remaining"
    refresh_deadline
    return
  fi
  delay=$interval_seconds
  if [ "$maximum_delay" -lt "$delay" ]; then
    delay=$maximum_delay
  fi
  sleep "$delay"
}

finish_final_poll_if_due() {
  refresh_deadline
  if [ "$remaining" -le 1 ]; then
    sleep "$remaining"
    refresh_deadline
  fi
}

record_poll_failure() {
  local reason=$1
  local detail=${2:-}

  finish_final_poll_if_due
  poll_failures=$((poll_failures + 1))
  if [ "$poll_failures" -ge "$max_poll_failures" ]; then
    if [ "$reason" = agent_get_failed ]; then
      printf 'WATCHDOG_ERROR target=%s reason=agent_get_failed attempts=%s detail=%s\n' \
        "$target" "$poll_failures" "$detail" >&2
    else
      printf 'WATCHDOG_ERROR target=%s reason=invalid_herdr_response attempts=%s\n' \
        "$target" "$poll_failures" >&2
    fi
    exit 5
  fi
  printf 'WATCHDOG_RETRY target=%s reason=%s attempt=%s\n' \
    "$target" "$reason" "$poll_failures" >&2
  sleep_until_next_poll
}

while :; do
  refresh_deadline
  effective_poll_timeout=$poll_timeout_seconds
  if [ "$remaining" -lt "$effective_poll_timeout" ]; then
    effective_poll_timeout=$remaining
  fi

  if parsed=$(python3 - "$target" "$effective_poll_timeout" <<'PY'
import json
import subprocess
import sys

try:
    completed = subprocess.run(
        ["herdr", "agent", "get", sys.argv[1]],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=int(sys.argv[2]),
    )
except subprocess.TimeoutExpired:
    print("watchdog poll timed out")
    raise SystemExit(1)

if completed.returncode != 0:
    sys.stdout.write(completed.stdout)
    sys.stdout.write(completed.stderr)
    raise SystemExit(1)

try:
    agent = json.loads(completed.stdout)["result"]["agent"]
except (KeyError, TypeError, ValueError):
    raise SystemExit(65)

print(f"{agent.get('agent_status', 'unknown')}\t{agent.get('revision', '')}")
PY
  ); then
    :
  else
    poll_result=$?
    case "$parsed" in
      *'"code":"agent_not_found"'*)
        printf 'WATCHDOG_UNHEALTHY target=%s reason=agent_not_found\n' "$target" >&2
        exit 2
        ;;
    esac
    if [ "$poll_result" -eq 65 ]; then
      record_poll_failure invalid_herdr_response
    else
      record_poll_failure agent_get_failed "$parsed"
    fi
    continue
  fi

  IFS=$'\t' read -r status revision <<< "$parsed"
  case "$revision" in
    ''|*[!0-9]*)
      printf 'WATCHDOG_ERROR target=%s reason=invalid_revision revision=%s\n' "$target" "${revision:-none}" >&2
      exit 5
      ;;
  esac
  poll_failures=0
  now=$(date +%s)

  if [ "$revision" != "$last_revision" ]; then
    last_revision_at=$now
  fi
  if [ "$status" != "$last_status" ] || [ "$revision" != "$last_revision" ]; then
    printf 'WATCHDOG_PROGRESS target=%s status=%s revision=%s\n' "$target" "$status" "${revision:-none}"
    last_status=$status
    last_revision=$revision
  fi
  case "$status" in
    working)
      unknown_readings=0
      if [ $((now - last_revision_at)) -ge "$stall_seconds" ]; then
        printf 'WATCHDOG_STALLED target=%s status=%s revision=%s redraw_silent_seconds=%s\n' \
          "$target" "$status" "${revision:-none}" "$((now - last_revision_at))" >&2
        exit 3
      fi
      ;;
    idle|done)
      unknown_readings=0
      if [ "$revision" -ge "$start_revision" ]; then
        printf 'WATCHDOG_READY target=%s status=%s revision=%s\n' "$target" "$status" "${revision:-none}"
        exit 0
      fi
      ;;
    blocked)
      printf 'WATCHDOG_UNHEALTHY target=%s status=%s revision=%s\n' "$target" "$status" "${revision:-none}" >&2
      exit 2
      ;;
    unknown)
      finish_final_poll_if_due
      unknown_readings=$((unknown_readings + 1))
      if [ "$unknown_readings" -ge "$max_poll_failures" ]; then
        printf 'WATCHDOG_UNHEALTHY target=%s status=%s revision=%s readings=%s\n' \
          "$target" "$status" "${revision:-none}" "$unknown_readings" >&2
        exit 2
      fi
      printf 'WATCHDOG_RETRY target=%s reason=unknown_state reading=%s\n' "$target" "$unknown_readings" >&2
      ;;
    *)
      printf 'WATCHDOG_UNHEALTHY target=%s reason=unexpected_status status=%s revision=%s\n' \
        "$target" "$status" "${revision:-none}" >&2
      exit 2
      ;;
  esac

  sleep_until_next_poll
done
