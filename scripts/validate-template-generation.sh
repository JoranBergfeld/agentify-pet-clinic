#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gh_bin="${GH_BIN:-gh}"
git_bin="${GIT_BIN:-git}"
uuidgen_bin="${UUIDGEN_BIN:-uuidgen}"
random_uuid_file="${RANDOM_UUID_FILE:-/proc/sys/kernel/random/uuid}"
template_ready_max_attempts="${GH_TEMPLATE_READY_MAX_ATTEMPTS:-30}"
template_ready_poll_interval="${GH_TEMPLATE_READY_POLL_INTERVAL:-2}"
source_repo="${1:-JoranBergfeld/agentify-pet-clinic}"
owner="${2:-$("$gh_bin" api user --jq .login)}"
generated_repo=""
clone_dir=""
created_repo=false

fail() {
  echo "template generation validation failed: $*" >&2
  exit 1
}

generate_repo_suffix() {
  local raw_suffix

  if raw_suffix="$("$uuidgen_bin" 2>/dev/null)"; then
    :
  elif [ -r "$random_uuid_file" ]; then
    raw_suffix="$(<"$random_uuid_file")"
  else
    fail "no collision-resistant UUID source is available"
  fi

  raw_suffix="$(
    printf '%s' "$raw_suffix" \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cd 'a-z0-9-' \
      | sed 's/^-*//; s/-*$//'
  )"
  [ -n "$raw_suffix" ] || fail "generated repository suffix is empty"

  printf '%s\n' "$raw_suffix"
}

wait_for_generated_default_branch() {
  local attempt=1

  while [ "$attempt" -le "$template_ready_max_attempts" ]; do
    if "$gh_bin" api "repos/${generated_repo}/branches/${source_default_branch}" \
      >/dev/null 2>&1; then
      return 0
    fi

    if [ "$attempt" -eq "$template_ready_max_attempts" ]; then
      fail \
        "generated repository default branch did not become ready: ${generated_repo}@${source_default_branch}"
    fi

    sleep "$template_ready_poll_interval"
    attempt=$((attempt + 1))
  done
}

cleanup() {
  local status=$?
  local cleanup_status=0

  set +e

  if [ -n "${clone_dir:-}" ] && [ -e "${clone_dir:-}" ]; then
    case "$clone_dir" in
      "$repo_root"/.validate-template-generation.*)
        rm -rf -- "$clone_dir" || cleanup_status=$?
        ;;
      *)
        echo "refusing to delete unexpected clone path: $clone_dir" >&2
        cleanup_status=1
        ;;
    esac
  fi

  if [ "${created_repo:-false}" = "true" ] \
    && [ -n "${generated_repo:-}" ] \
    && "$gh_bin" repo view "$generated_repo" >/dev/null 2>&1; then
    "$gh_bin" repo delete "$generated_repo" --yes >/dev/null || cleanup_status=$?
  fi

  if [ "$status" -eq 0 ] && [ "$cleanup_status" -ne 0 ]; then
    return "$cleanup_status"
  fi

  return "$status"
}

trap cleanup EXIT

case "$source_repo" in
  */*) ;;
  *) fail "source repository must use OWNER/REPO format" ;;
esac

[ -n "$owner" ] || fail "owner must not be empty"

source_metadata="$("$gh_bin" repo view "$source_repo" --json isTemplate,defaultBranchRef --jq '[.isTemplate, (.defaultBranchRef.name // "")] | @tsv')"
IFS=$'\t' read -r source_is_template source_default_branch <<<"$source_metadata"

[ "$source_is_template" = "true" ] \
  || fail "source repository is not a template: $source_repo"
[ "$source_default_branch" = "main" ] \
  || fail "source repository default branch is not main: $source_default_branch"

repo_basename="${source_repo##*/}"
attempt=0

while :; do
  repo_suffix="$(generate_repo_suffix)"
  if [ "$attempt" -gt 0 ]; then
    repo_suffix="${repo_suffix}-${attempt}"
  fi
  repo_name="${repo_basename}-template-validation-${repo_suffix}"
  generated_repo="${owner}/${repo_name}"
  clone_dir="$repo_root/.validate-template-generation.${repo_name}"

  if ! "$gh_bin" repo view "$generated_repo" >/dev/null 2>&1 && [ ! -e "$clone_dir" ]; then
    break
  fi

  attempt=$((attempt + 1))
done

"$gh_bin" repo create "$generated_repo" \
  --private \
  --template "$source_repo" \
  >/dev/null
created_repo=true

wait_for_generated_default_branch

"$gh_bin" repo clone "$generated_repo" "$clone_dir" >/dev/null

(
  cd "$clone_dir"

  current_branch="$("$git_bin" branch --show-current)"
  [ "$current_branch" = "main" ] \
    || fail "generated repository branch is not main: $current_branch"

  status_output="$("$git_bin" status --short)"
  [ -z "$status_output" ] \
    || fail "generated repository working tree is not clean"

  ./scripts/validate-template-baseline.sh
  ./mvnw -q test
)

printf 'validated target: %s\n' "$generated_repo"
