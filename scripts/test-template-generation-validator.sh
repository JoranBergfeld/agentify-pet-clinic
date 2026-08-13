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
gh_state="$fixture/gh-state"
uuid_fallback_file="$fixture/random-uuid"

mkdir -p "$bin_dir"
: >"$gh_log"
: >"$gh_state"

cat >"$bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${GH_LOG:?}"
state_file="${GH_STATE:?}"

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

if [ "$1" = "api" ] && [ "${2:-}" = "user" ]; then
  printf '%s\n' "${GH_OWNER_LOGIN:-test-owner}"
  exit 0
fi

if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
  repo="$3"
  if [ "$repo" = "${GH_SOURCE_REPO:?}" ] && [ "${4:-}" = "--json" ]; then
    printf 'true\tmain\n'
    exit 0
  fi

  if has_repo "$repo"; then
    exit 0
  fi

  exit 1
fi

if [ "$1" = "api" ]; then
  owner=""
  name=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -f)
        shift
        case "$1" in
          owner=*) owner="${1#owner=}" ;;
          name=*) name="${1#name=}" ;;
        esac
        ;;
    esac
    shift || true
  done

  repo="${owner}/${name}"

  if [ "${GH_CREATE_PARTIAL_SUCCESS:-false}" = "true" ]; then
    add_repo "$repo"
  fi

  if [ "${GH_CREATE_FAIL:-false}" = "true" ]; then
    exit 1
  fi

  add_repo "$repo"
  exit 0
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
  mkdir -p "$dest/scripts"
  cat >"$dest/scripts/validate-template-baseline.sh" <<'EOF_INNER'
#!/usr/bin/env bash
exit 0
EOF_INNER
  cat >"$dest/mvnw" <<'EOF_INNER'
#!/usr/bin/env bash
exit 0
EOF_INNER
  chmod +x "$dest/scripts/validate-template-baseline.sh" "$dest/mvnw"
  exit 0
fi

if [ "$1" = "repo" ] && [ "$2" = "delete" ]; then
  remove_repo "$3"
  exit 0
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
  : >"$gh_state"
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
    GH_STATE="$gh_state" \
    GH_SOURCE_REPO="$source_repo" \
    GH_OWNER_LOGIN="$owner" \
    "$@" \
    "$validator" "$source_repo" "$owner" \
    >"$output_file" 2>&1
}

logged_created_repo() {
  local line owner_arg name_arg

  while IFS= read -r line; do
    case "$line" in
      repo\ create\ *)
        set -- $line
        printf '%s\n' "$3"
        return 0
        ;;
      api\ *repos/*/generate*)
        owner_arg="$(printf '%s\n' "$line" | sed -n 's/.*-f owner=\([^ ]*\).*/\1/p')"
        name_arg="$(printf '%s\n' "$line" | sed -n 's/.*-f name=\([^ ]*\).*/\1/p')"
        if [ -n "$owner_arg" ] && [ -n "$name_arg" ]; then
          printf '%s/%s\n' "$owner_arg" "$name_arg"
          return 0
        fi
        ;;
    esac
  done <"$gh_log"

  return 1
}

expect_no_repo_delete_after_failed_create() {
  local output_file="$fixture/failed-create.log"
  local created_repo

  reset_fake_github

  if run_validator "$output_file" \
    "GH_CREATE_FAIL=true" \
    "GH_CREATE_PARTIAL_SUCCESS=true" \
    "UUIDGEN_OUTPUT=ABCDEF12-3456-7890-ABCD-1234567890EF!!!"; then
    echo "validator unexpectedly passed after failed create" >&2
    exit 1
  fi

  created_repo="$(logged_created_repo)"
  if grep -Fq "repo delete $created_repo --yes" "$gh_log"; then
    echo "validator should not delete a repo after create fails" >&2
    exit 1
  fi
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

  grep -Fqx "repo create $expected_repo --private --template $source_repo" "$gh_log"
  grep -Fqx "repo delete $expected_repo --yes" "$gh_log"
  grep -Fxq "validated target: $expected_repo" "$output_file"
  [ ! -e "$expected_clone_dir" ]
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

  grep -Fqx "repo create $expected_repo --private --template $source_repo" "$gh_log"
  grep -Fqx "repo delete $expected_repo --yes" "$gh_log"
  grep -Fxq "validated target: $expected_repo" "$output_file"
}

expect_no_repo_delete_after_failed_create
expect_uuidgen_suffix_and_cleanup
expect_proc_uuid_fallback

echo "template generation validator tests passed"
