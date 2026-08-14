#!/usr/bin/env bash
set -euo pipefail

: "${WORKSHOP_AZURE_FIXTURE_DIR:?WORKSHOP_AZURE_FIXTURE_DIR must be set}"
: "${WORKSHOP_AZURE_COMMAND_LOG:?WORKSHOP_AZURE_COMMAND_LOG must be set}"

command_name="$(basename "$0")"
mkdir -p "$(dirname "$WORKSHOP_AZURE_COMMAND_LOG")"
call_number=1
if [[ -f "$WORKSHOP_AZURE_COMMAND_LOG" ]]; then
  call_number="$(( $(wc -l <"$WORKSHOP_AZURE_COMMAND_LOG") + 1 ))"
fi

{
  printf '%q' "$command_name"
  printf ' %q' "$@"
  printf '\n'
} >>"$WORKSHOP_AZURE_COMMAND_LOG"

prefix="$WORKSHOP_AZURE_FIXTURE_DIR/$(printf '%03d' "$call_number")-$command_name"
if [[ ! -f "$prefix.args" ]]; then
  echo "unexpected command call $call_number: $command_name $*" >&2
  exit 97
fi

mapfile -t expected_args <"$prefix.args"
actual_args=("$@")
if (( ${#expected_args[@]} != ${#actual_args[@]} )); then
  echo "unexpected arguments for call $call_number: $command_name $*" >&2
  exit 98
fi
for index in "${!expected_args[@]}"; do
  if [[ "${expected_args[$index]}" != "${actual_args[$index]}" ]]; then
    echo "unexpected arguments for call $call_number: $command_name $*" >&2
    exit 98
  fi
done

if [[ -f "$prefix.stdin" ]]; then
  actual_stdin="$(cat)"
  expected_stdin="$(cat "$prefix.stdin")"
  if [[ "$actual_stdin" != "$expected_stdin" ]]; then
    echo "unexpected stdin for call $call_number: $command_name $*" >&2
    exit 99
  fi
fi

[[ ! -f "$prefix.stdout" ]] || cat "$prefix.stdout"
[[ ! -f "$prefix.stderr" ]] || cat "$prefix.stderr" >&2
status=0
[[ ! -f "$prefix.status" ]] || read -r status <"$prefix.status"
exit "$status"
