#!/usr/bin/env bash
set -euo pipefail

readonly AZURE_LOCATION="${AZURE_LOCATION:-swedencentral}"
readonly AZURE_LOCATION_DISPLAY_NAME="${AZURE_LOCATION_DISPLAY_NAME:-Sweden Central}"
readonly AZURE_OPENAI_MODEL="${AZURE_OPENAI_MODEL:-gpt-5.4-mini}"
readonly AZURE_OPENAI_MODEL_VERSION="${AZURE_OPENAI_MODEL_VERSION:-2026-03-17}"
readonly AZURE_OPENAI_DEPLOYMENT="${AZURE_OPENAI_DEPLOYMENT:-gpt-5-4-mini}"
readonly AZURE_OPENAI_DEPLOYMENT_SKU="${AZURE_OPENAI_DEPLOYMENT_SKU:-GlobalStandard}"
readonly AZURE_OPENAI_DEPLOYMENT_CAPACITY="${AZURE_OPENAI_DEPLOYMENT_CAPACITY:-10}"
readonly WORKSHOP_AZURE_RETRY_SECONDS="${WORKSHOP_AZURE_RETRY_SECONDS:-5}"
readonly WORKSHOP_AZURE_RETRY_ATTEMPTS="${WORKSHOP_AZURE_RETRY_ATTEMPTS:-12}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    fail "required command not found: $1"
}

redact_subscription() {
  local subscription="$1"
  if (( ${#subscription} <= 12 )); then
    printf '%s\n' '[redacted]'
  else
    printf '%s...%s\n' "${subscription:0:8}" "${subscription: -4}"
  fi
}

require_nonempty() {
  local name="$1"
  local value="${2-}"
  [[ -n "$value" ]] || fail "$name must be set"
}

require_positive_integer() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] ||
    fail "$name must be a positive integer"
}

require_nonnegative_integer() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] ||
    fail "$name must be a nonnegative integer"
}

retry_until() {
  local description="$1"
  shift
  local attempt
  for (( attempt = 1; attempt <= WORKSHOP_AZURE_RETRY_ATTEMPTS; attempt++ )); do
    if "$@"; then
      return 0
    fi
    if (( attempt < WORKSHOP_AZURE_RETRY_ATTEMPTS )); then
      sleep "$WORKSHOP_AZURE_RETRY_SECONDS"
    fi
  done
  fail "$description did not succeed after $WORKSHOP_AZURE_RETRY_ATTEMPTS attempts"
}

require_nonempty AZURE_LOCATION "$AZURE_LOCATION"
require_nonempty AZURE_LOCATION_DISPLAY_NAME "$AZURE_LOCATION_DISPLAY_NAME"
require_nonempty AZURE_OPENAI_MODEL "$AZURE_OPENAI_MODEL"
require_nonempty AZURE_OPENAI_MODEL_VERSION "$AZURE_OPENAI_MODEL_VERSION"
require_nonempty AZURE_OPENAI_DEPLOYMENT "$AZURE_OPENAI_DEPLOYMENT"
require_nonempty AZURE_OPENAI_DEPLOYMENT_SKU "$AZURE_OPENAI_DEPLOYMENT_SKU"
require_positive_integer AZURE_OPENAI_DEPLOYMENT_CAPACITY "$AZURE_OPENAI_DEPLOYMENT_CAPACITY"
require_nonnegative_integer WORKSHOP_AZURE_RETRY_SECONDS "$WORKSHOP_AZURE_RETRY_SECONDS"
require_positive_integer WORKSHOP_AZURE_RETRY_ATTEMPTS "$WORKSHOP_AZURE_RETRY_ATTEMPTS"
