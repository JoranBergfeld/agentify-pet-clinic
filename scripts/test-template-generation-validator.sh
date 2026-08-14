#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-template-generation.sh"
fixture="$(mktemp -d "$repo_root/.template-generation-validator-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

source_repo="JoranBergfeld/agentify-pet-clinic"
owner="test-owner"
bin_dir="$fixture/bin"
gh_log="$fixture/gh.log"
gradle_log="$fixture/gradle.log"
gh_state="$fixture/gh-state"
gh_branch_checks="$fixture/gh-branch-checks"
gh_repo_view_counts="$fixture/gh-repo-view-counts"
gh_repo_delete_counts="$fixture/gh-repo-delete-counts"
uuid_fallback_file="$fixture/random-uuid"

mkdir -p "$bin_dir"
: >"$gh_log"
: >"$gradle_log"
: >"$gh_state"
: >"$gh_branch_checks"
: >"$gh_repo_view_counts"
: >"$gh_repo_delete_counts"

cat >"$bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${GH_LOG:?}"
state_file="${GH_STATE:?}"
branch_checks_file="${GH_BRANCH_CHECKS:?}"
repo_view_counts_file="${GH_REPO_VIEW_COUNTS:?}"
repo_delete_counts_file="${GH_REPO_DELETE_COUNTS:?}"

printf '%s\n' "$*" >>"$log_file"

has_repo() {
  grep -Fxq "$1" "$state_file" 2>/dev/null
}

add_repo() {
  if ! has_repo "$1"; then
    printf '%s\n' "$1" >>"$state_file"
  fi
}

remove_repo() {
  grep -Fxv "$1" "$state_file" >"$state_file.next" || true
  mv "$state_file.next" "$state_file"
}

read_count() {
  if [ -s "$1" ]; then
    cat "$1"
  else
    printf '0\n'
  fi
}

increment_count() {
  local current

  current="$(read_count "$1")"
  current="$((current + 1))"
  printf '%s\n' "$current" >"$1"
  printf '%s\n' "$current"
}

sequence_token() {
  local sequence="$1"
  local index="$2"
  local default_value="$3"
  local tokens=()

  if [ -z "$sequence" ]; then
    printf '%s\n' "$default_value"
    return 0
  fi

  IFS=, read -r -a tokens <<<"$sequence"
  if [ "$index" -le "${#tokens[@]}" ] && [ -n "${tokens[$((index - 1))]}" ]; then
    printf '%s\n' "${tokens[$((index - 1))]}"
    return 0
  fi

  printf '%s\n' "$default_value"
}

branch_check_count() {
  if [ -s "$branch_checks_file" ]; then
    cat "$branch_checks_file"
  else
    printf '0\n'
  fi
}

increment_branch_check_count() {
  local current

  current="$(branch_check_count)"
  printf '%s\n' "$((current + 1))" >"$branch_checks_file"
}

branch_ready() {
  [ "$(branch_check_count)" -ge "${GH_BRANCH_READY_AFTER_ATTEMPTS:-0}" ]
}

if [ "$1" = "api" ] && [ "${2:-}" = "user" ]; then
  printf '%s\n' "${GH_OWNER_LOGIN:-test-owner}"
  exit 0
fi

if [ "$1" = "api" ] && [[ "${2:-}" == repos/*/branches/* ]]; then
  repo_path="${2#repos/}"
  repo="${repo_path%/branches/*}"

  if has_repo "$repo"; then
    increment_branch_check_count
    if branch_ready; then
      printf '{"name":"%s"}\n' "${2##*/}"
      exit 0
    fi
  fi

  exit 1
fi

if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
  repo="$3"
  view_call=0
  view_behavior="state"
  if [ "$repo" = "${GH_SOURCE_REPO:?}" ] && [ "${4:-}" = "--json" ]; then
    printf 'true\tmain\n'
    exit 0
  fi

  view_call="$(increment_count "$repo_view_counts_file")"
  view_behavior="$(sequence_token "${GH_REPO_VIEW_SEQUENCE:-}" "$view_call" "state")"
  case "$view_behavior" in
    state)
      if has_repo "$repo"; then
        exit 0
      fi
      echo "HTTP 404: Not Found" >&2
      exit 1
      ;;
    missing)
      remove_repo "$repo"
      echo "HTTP 404: Not Found" >&2
      exit 1
      ;;
    error)
      echo "${GH_REPO_VIEW_ERROR_MESSAGE:-temporary repo view failure}" >&2
      exit 1
      ;;
    exists)
      exit 0
      ;;
    *)
      echo "unexpected repo view behavior: $view_behavior" >&2
      exit 98
      ;;
  esac
fi

if [ "$1" = "repo" ] && [ "$2" = "create" ]; then
  repo="$3"
  shift 3
  template=""
  is_private=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --private) is_private=true ;;
      --template)
        shift
        template="${1:-}"
        ;;
    esac
    shift || true
  done

  [ "$is_private" = "true" ] || {
    echo "repo create missing --private" >&2
    exit 2
  }
  [ "$template" = "${GH_SOURCE_REPO:?}" ] || {
    echo "repo create missing expected template" >&2
    exit 2
  }

  if [ "${GH_CREATE_PARTIAL_SUCCESS:-false}" = "true" ]; then
    add_repo "$repo"
  fi

  if [ "${GH_CREATE_FAIL:-false}" = "true" ]; then
    exit 1
  fi

  add_repo "$repo"
  exit 0
fi

if [ "$1" = "repo" ] && [ "$2" = "clone" ]; then
  dest="$4"

  if [ "${GH_CLONE_REQUIRES_BRANCH_READY:-false}" = "true" ] && ! branch_ready; then
    mkdir -p "$dest"
    exit 0
  fi

  mkdir -p "$dest/scripts"
  cat >"$dest/scripts/validate-template-baseline.sh" <<'EOF_INNER'
#!/usr/bin/env bash
exit 0
EOF_INNER
  cat >"$dest/gradlew" <<'EOF_INNER'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_GRADLE_LOG:?}"

case "$*" in
  '-q assertJava17Release test' | 'assertJava17Release test')
    exit 0
    ;;
esac

echo "unexpected gradle call: $*" >&2
exit 97
EOF_INNER
  cat >"$dest/mvnw" <<'EOF_INNER'
#!/usr/bin/env bash
exit 0
EOF_INNER
  chmod +x "$dest/scripts/validate-template-baseline.sh" "$dest/gradlew" "$dest/mvnw"
  exit 0
fi

if [ "$1" = "repo" ] && [ "$2" = "delete" ]; then
  delete_call="$(increment_count "$repo_delete_counts_file")"
  delete_behavior="$(sequence_token "${GH_REPO_DELETE_SEQUENCE:-}" "$delete_call" "success")"

  case "$delete_behavior" in
    success)
      remove_repo "$3"
      exit 0
      ;;
    missing)
      remove_repo "$3"
      echo "HTTP 404: Not Found" >&2
      exit 1
      ;;
    error)
      echo "${GH_REPO_DELETE_ERROR_MESSAGE:-temporary repo delete failure}" >&2
      exit 1
      ;;
    error-remove)
      remove_repo "$3"
      echo "${GH_REPO_DELETE_ERROR_MESSAGE:-temporary repo delete failure}" >&2
      exit 1
      ;;
    *)
      echo "unexpected repo delete behavior: $delete_behavior" >&2
      exit 98
      ;;
  esac
fi

echo "unexpected gh call: $*" >&2
exit 99
EOF
chmod +x "$bin_dir/gh"

cat >"$bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" = "branch" ] && [ "$2" = "--show-current" ]; then
  printf 'main\n'
  exit 0
fi

if [ "$1" = "status" ] && [ "$2" = "--short" ]; then
  exit 0
fi

echo "unexpected git call: $*" >&2
exit 99
EOF
chmod +x "$bin_dir/git"

cat >"$bin_dir/uuidgen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${UUIDGEN_SHOULD_FAIL:-false}" = "true" ]; then
  exit 1
fi

printf '%s\n' "${UUIDGEN_OUTPUT:?}"
EOF
chmod +x "$bin_dir/uuidgen"

reset_fake_github() {
  : >"$gh_log"
  : >"$gradle_log"
  : >"$gh_state"
  : >"$gh_branch_checks"
  : >"$gh_repo_view_counts"
  : >"$gh_repo_delete_counts"
}

sanitize_suffix() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cd 'a-z0-9-' \
    | sed 's/^-*//; s/-*$//'
}

run_validator() {
  local output_file="$1"
  shift

  env \
    PATH="$bin_dir:$PATH" \
    GH_BIN="$bin_dir/gh" \
    GIT_BIN="$bin_dir/git" \
    UUIDGEN_BIN="$bin_dir/uuidgen" \
    RANDOM_UUID_FILE="$uuid_fallback_file" \
    GH_LOG="$gh_log" \
    FAKE_GRADLE_LOG="$gradle_log" \
    GH_STATE="$gh_state" \
    GH_BRANCH_CHECKS="$gh_branch_checks" \
    GH_REPO_VIEW_COUNTS="$gh_repo_view_counts" \
    GH_REPO_DELETE_COUNTS="$gh_repo_delete_counts" \
    GH_SOURCE_REPO="$source_repo" \
    GH_OWNER_LOGIN="$owner" \
    "$@" \
    "$validator" "$source_repo" "$owner" \
    >"$output_file" 2>&1
}

logged_created_repo() {
  local line

  while IFS= read -r line; do
    case "$line" in
      repo\ create\ *)
        set -- $line
        printf '%s\n' "$3"
        return 0
        ;;
    esac
  done <"$gh_log"

  return 1
}

expect_cleanup_after_partial_create_failure() {
  local output_file="$fixture/partial-create.log"
  local raw_uuid="ABCDEF12-3456-7890-ABCD-1234567890EF!!!"
  local expected_suffix expected_repo expected_clone_dir

  reset_fake_github

  expected_suffix="$(sanitize_suffix "$raw_uuid")"
  expected_repo="${owner}/agentify-pet-clinic-template-validation-${expected_suffix}"
  expected_clone_dir="$repo_root/.validate-template-generation.${expected_repo##*/}"

  if run_validator "$output_file" \
    "GH_CREATE_FAIL=true" \
    "GH_CREATE_PARTIAL_SUCCESS=true" \
    "UUIDGEN_OUTPUT=$raw_uuid"; then
    echo "validator unexpectedly passed after failed create" >&2
    exit 1
  fi

  test "$(logged_created_repo)" = "$expected_repo"
  grep -Fqx "repo create $expected_repo --private --template $source_repo" "$gh_log"
  grep -Fqx "repo delete $expected_repo --yes" "$gh_log"
  [ ! -s "$gh_state" ]
  [ ! -e "$expected_clone_dir" ]
  ! grep -Fq "validated target:" "$output_file"
}

expect_uuidgen_suffix_and_cleanup() {
  local output_file="$fixture/uuidgen-success.log"
  local raw_uuid="ABCDEF12-3456-7890-ABCD-1234567890EF!!!"
  local expected_suffix expected_repo expected_clone_dir

  reset_fake_github

  expected_suffix="$(sanitize_suffix "$raw_uuid")"
  expected_repo="${owner}/agentify-pet-clinic-template-validation-${expected_suffix}"
  expected_clone_dir="$repo_root/.validate-template-generation.${expected_repo##*/}"

  run_validator "$output_file" \
    "UUIDGEN_OUTPUT=$raw_uuid"

  grep -Fxq -- "-q assertJava17Release test" "$gradle_log"
  grep -Fqx "repo create $expected_repo --private --template $source_repo" "$gh_log"
  grep -Fqx "repo delete $expected_repo --yes" "$gh_log"
  grep -Fxq "validated target: $expected_repo" "$output_file"
  [ ! -e "$expected_clone_dir" ]
}

expect_cleanup_retries_after_transient_delete_and_view_failures() {
  local output_file="$fixture/transient-cleanup.log"
  local raw_uuid="TRANSIENT-CLEANUP-1234"
  local expected_suffix expected_repo

  reset_fake_github

  expected_suffix="$(sanitize_suffix "$raw_uuid")"
  expected_repo="${owner}/agentify-pet-clinic-template-validation-${expected_suffix}"

  run_validator "$output_file" \
    "UUIDGEN_OUTPUT=$raw_uuid" \
    "GH_REPO_DELETE_SEQUENCE=error,success" \
    "GH_REPO_VIEW_SEQUENCE=state,error" \
    "GH_CLEANUP_DELETE_RETRY_INTERVAL=0" \
    "GH_REPO_DELETE_ERROR_MESSAGE=temporary delete api failure" \
    "GH_REPO_VIEW_ERROR_MESSAGE=temporary repo view api failure"

  grep -Fxq -- "-q assertJava17Release test" "$gradle_log"
  [ "$(grep -Fc "repo delete $expected_repo --yes" "$gh_log")" -eq 2 ]
  [ "$(grep -Fc "repo view $expected_repo" "$gh_log")" -eq 2 ]
  grep -Fxq "validated target: $expected_repo" "$output_file"
  [ ! -s "$gh_state" ]
}

expect_cleanup_failure_on_persistent_delete_errors() {
  local output_file="$fixture/persistent-cleanup-failure.log"
  local raw_uuid="PERSISTENT-CLEANUP-1234"
  local expected_suffix expected_repo

  reset_fake_github

  expected_suffix="$(sanitize_suffix "$raw_uuid")"
  expected_repo="${owner}/agentify-pet-clinic-template-validation-${expected_suffix}"

  if run_validator "$output_file" \
    "UUIDGEN_OUTPUT=$raw_uuid" \
    "GH_REPO_DELETE_SEQUENCE=error,error,error" \
    "GH_REPO_VIEW_SEQUENCE=state,error,error,error" \
    "GH_CLEANUP_DELETE_MAX_ATTEMPTS=3" \
    "GH_CLEANUP_DELETE_RETRY_INTERVAL=0" \
    "GH_REPO_DELETE_ERROR_MESSAGE=temporary delete api failure" \
    "GH_REPO_VIEW_ERROR_MESSAGE=temporary repo view api failure"; then
    echo "validator unexpectedly passed despite cleanup failure" >&2
    exit 1
  fi

  [ "$(grep -Fc "repo delete $expected_repo --yes" "$gh_log")" -eq 3 ]
  [ "$(grep -Fc "repo view $expected_repo" "$gh_log")" -eq 4 ]
  grep -Fqx "failed to delete generated repository after 3 attempt(s): $expected_repo" "$output_file"
  grep -Fqx "temporary delete api failure" "$output_file"
  grep -Fqx "temporary repo view api failure" "$output_file"
  [ -s "$gh_state" ]
}

expect_cleanup_accepts_not_found_delete_without_repo_view_probe() {
  local output_file="$fixture/not-found-cleanup.log"
  local raw_uuid="DELETE-NOT-FOUND-1234"
  local expected_suffix expected_repo

  reset_fake_github

  expected_suffix="$(sanitize_suffix "$raw_uuid")"
  expected_repo="${owner}/agentify-pet-clinic-template-validation-${expected_suffix}"

  run_validator "$output_file" \
    "UUIDGEN_OUTPUT=$raw_uuid" \
    "GH_REPO_DELETE_SEQUENCE=missing"

  grep -Fxq -- "-q assertJava17Release test" "$gradle_log"
  [ "$(grep -Fc "repo delete $expected_repo --yes" "$gh_log")" -eq 1 ]
  [ "$(grep -Fc "repo view $expected_repo" "$gh_log")" -eq 1 ]
  grep -Fxq "validated target: $expected_repo" "$output_file"
  [ ! -s "$gh_state" ]
}

expect_proc_uuid_fallback() {
  local output_file="$fixture/proc-fallback.log"
  local raw_uuid="FALLBACK-UUID-1234-ABCD-!!!"
  local expected_suffix expected_repo

  reset_fake_github
  printf '%s\n' "$raw_uuid" >"$uuid_fallback_file"

  expected_suffix="$(sanitize_suffix "$raw_uuid")"
  expected_repo="${owner}/agentify-pet-clinic-template-validation-${expected_suffix}"

  run_validator "$output_file" \
    "UUIDGEN_SHOULD_FAIL=true" \
    "UUIDGEN_OUTPUT=unused"

  grep -Fxq -- "-q assertJava17Release test" "$gradle_log"
  grep -Fqx "repo create $expected_repo --private --template $source_repo" "$gh_log"
  grep -Fqx "repo delete $expected_repo --yes" "$gh_log"
  grep -Fxq "validated target: $expected_repo" "$output_file"
}

expect_waits_for_generated_default_branch() {
  local output_file="$fixture/branch-wait.log"
  local raw_uuid="WAIT-FOR-BRANCH-1234"
  local expected_suffix expected_repo

  reset_fake_github

  expected_suffix="$(sanitize_suffix "$raw_uuid")"
  expected_repo="${owner}/agentify-pet-clinic-template-validation-${expected_suffix}"

  run_validator "$output_file" \
    "UUIDGEN_OUTPUT=$raw_uuid" \
    "GH_CLONE_REQUIRES_BRANCH_READY=true" \
    "GH_BRANCH_READY_AFTER_ATTEMPTS=2" \
    "GH_TEMPLATE_READY_POLL_INTERVAL=0" \
    "GH_TEMPLATE_READY_MAX_ATTEMPTS=3"

  grep -Fxq -- "-q assertJava17Release test" "$gradle_log"
  [ "$(grep -Fc "api repos/$expected_repo/branches/main" "$gh_log")" -eq 2 ]
  grep -Fqx "repo create $expected_repo --private --template $source_repo" "$gh_log"
  grep -Fqx "repo delete $expected_repo --yes" "$gh_log"
  grep -Fxq "validated target: $expected_repo" "$output_file"
}

expect_cleanup_after_partial_create_failure
expect_uuidgen_suffix_and_cleanup
expect_cleanup_retries_after_transient_delete_and_view_failures
expect_cleanup_failure_on_persistent_delete_errors
expect_cleanup_accepts_not_found_delete_without_repo_view_probe
expect_proc_uuid_fallback
expect_waits_for_generated_default_branch

echo "template generation validator tests passed"
