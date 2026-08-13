#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_repo="${1:-JoranBergfeld/agentify-pet-clinic}"
owner="${2:-$(gh api user --jq .login)}"
generated_repo=""
clone_dir=""

fail() {
  echo "template generation validation failed: $*" >&2
  exit 1
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

  if [ -n "${generated_repo:-}" ] && gh repo view "$generated_repo" >/dev/null 2>&1; then
    gh repo delete "$generated_repo" --yes >/dev/null || cleanup_status=$?
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

source_metadata="$(gh repo view "$source_repo" --json isTemplate,defaultBranchRef --jq '[.isTemplate, (.defaultBranchRef.name // "")] | @tsv')"
IFS=$'\t' read -r source_is_template source_default_branch <<<"$source_metadata"

[ "$source_is_template" = "true" ] \
  || fail "source repository is not a template: $source_repo"
[ "$source_default_branch" = "main" ] \
  || fail "source repository default branch is not main: $source_default_branch"

repo_basename="${source_repo##*/}"
attempt=0

while :; do
  repo_suffix="$(date -u +%Y%m%d%H%M%S)-$$-$attempt"
  repo_name="${repo_basename}-template-validation-${repo_suffix}"
  generated_repo="${owner}/${repo_name}"
  clone_dir="$repo_root/.validate-template-generation.${repo_name}"

  if ! gh repo view "$generated_repo" >/dev/null 2>&1 && [ ! -e "$clone_dir" ]; then
    break
  fi

  attempt=$((attempt + 1))
done

gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "repos/$source_repo/generate" \
  -f owner="$owner" \
  -f name="$repo_name" \
  -F private=true \
  >/dev/null

gh repo clone "$generated_repo" "$clone_dir" >/dev/null

(
  cd "$clone_dir"

  current_branch="$(git branch --show-current)"
  [ "$current_branch" = "main" ] \
    || fail "generated repository branch is not main: $current_branch"

  status_output="$(git status --short)"
  [ -z "$status_output" ] \
    || fail "generated repository working tree is not clean"

  ./scripts/validate-template-baseline.sh
  ./mvnw -q test
)

printf 'validated target: %s\n' "$generated_repo"
