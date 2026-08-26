#!/usr/bin/env bash

set -u

status=0
required_tools=(git java python3 gh az azd docker curl jq)

for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Missing required tool: %s\n' "$tool" >&2
    status=1
    continue
  fi

  version_output=$("$tool" --version 2>&1)
  printf '%s: %s\n' "$tool" "${version_output%%$'\n'*}"
done

if command -v java >/dev/null 2>&1; then
  java_version=$(java -version 2>&1)
  if [[ $java_version =~ version\ \"([0-9]+) ]]; then
    java_major=${BASH_REMATCH[1]}
    if [[ $java_major != 21 ]]; then
      printf 'Java 21 is required; found Java %s.\n' "$java_major" >&2
      status=1
    fi
  else
    printf 'Unable to determine the Java major version.\n' >&2
    status=1
  fi
fi

if ((status != 0)); then
  printf 'Workshop tool verification failed.\n' >&2
  exit "$status"
fi

printf 'Workshop tool verification passed.\n'
