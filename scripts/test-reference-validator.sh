#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-reference.sh"
fixture_root="$repo_root/.reference-validator-fixture-$BASHPID"
stub_fixture="$fixture_root/stub"
single_branch_fixture="$fixture_root/single-branch"
stub_bin_dir="$stub_fixture/bin"
stub_git_log="$stub_fixture/git.log"
stub_mvn_log="$stub_fixture/mvn.log"
stub_output_file="$stub_fixture/output.log"
single_branch_source="$single_branch_fixture/source"
single_branch_origin="$single_branch_fixture/origin.git"
single_branch_clone="$single_branch_fixture/clone"
single_branch_mvn_log="$single_branch_fixture/mvn.log"
single_branch_output_file="$single_branch_fixture/output.log"
trap 'rm -rf "$fixture_root"' EXIT

write_fake_maven_wrapper() {
  local root="$1"

  cat >"$root/mvnw" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FAKE_MVN_LOG:?}"
report_dir="target/surefire-reports"
test_class=""
fail_if_no_specified="unset"

mkdir -p "$report_dir"

for arg in "$@"; do
  case "$arg" in
    -Dtest=*)
      test_class="${arg#-Dtest=}"
      ;;
    -Dsurefire.failIfNoSpecifiedTests=*)
      fail_if_no_specified="${arg#*=}"
      ;;
  esac
done

if [ -n "$test_class" ]; then
  printf 'FOCUSED %s %s\n' "$test_class" "$fail_if_no_specified" >>"$log_file"

  if [[ "$test_class" == *","* ]]; then
    echo "combined test selectors are not allowed" >&2
    exit 90
  fi

  if [ "$test_class" = "MissingReferenceValidationTest" ] && [ "$fail_if_no_specified" = "true" ]; then
    echo "No tests matching pattern \"$test_class\" were executed!" >&2
    exit 1
  fi

  touch "$report_dir/TEST-org.example.${test_class}.xml"
  exit 0
fi

printf 'FULL_SUITE\n' >>"$log_file"
exit 0
EOF
  chmod +x "$root/mvnw"
}

setup_stub_fixture() {
  rm -rf "$stub_fixture"
  mkdir -p "$stub_bin_dir" "$stub_fixture/src/main/java/org/springframework/samples/petclinic/assistant"
  : >"$stub_git_log"
  : >"$stub_mvn_log"

  cat >"$stub_fixture/pom.xml" <<'EOF'
<project>
  <dependencies>
    <dependency>
      <artifactId>spring-ai-starter-model-openai</artifactId>
    </dependency>
  </dependencies>
</project>
EOF

  cat >"$stub_bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_GIT_LOG:?}"

if [ "$1" = "fetch" ] && [ "${2:-}" = "origin" ] \
  && [ "${3:-}" = "+refs/heads/main:refs/remotes/origin/main" ]; then
  exit 0
fi

if [ "$1" = "merge-base" ] && [ "${2:-}" = "--is-ancestor" ] \
  && [ "${3:-}" = "refs/remotes/origin/main" ] && [ "${4:-}" = "HEAD" ]; then
  exit 0
fi

echo "unexpected git call: $*" >&2
exit 99
EOF
  chmod +x "$stub_bin_dir/git"
  write_fake_maven_wrapper "$stub_fixture"
}

reset_fixture_state() {
  : >"$stub_git_log"
  : >"$stub_mvn_log"
  rm -rf "$stub_fixture/target"
}

run_stubbed_validator() {
  env \
    PATH="$stub_bin_dir:$PATH" \
    FAKE_GIT_LOG="$stub_git_log" \
    FAKE_MVN_LOG="$stub_mvn_log" \
    REFERENCE_FOCUSED_TEST_CLASSES="$1" \
    "$validator" "$stub_fixture" \
    >"$stub_output_file" 2>&1
}

expect_explicit_fetch_then_individual_runs_then_full_suite() {
  local expected_git_log expected_mvn_log

  reset_fixture_state
  run_stubbed_validator "ClinicAssistantToolsTests,I18nPropertiesSyncTest"

  expected_git_log="$(cat <<'EOF'
fetch origin +refs/heads/main:refs/remotes/origin/main
merge-base --is-ancestor refs/remotes/origin/main HEAD
EOF
)"

  expected_mvn_log="$(cat <<'EOF'
FOCUSED ClinicAssistantToolsTests true
FOCUSED I18nPropertiesSyncTest true
FULL_SUITE
EOF
)"

  test "$(cat "$stub_git_log")" = "$expected_git_log"
  test "$(cat "$stub_mvn_log")" = "$expected_mvn_log"
  test -f "$stub_fixture/target/surefire-reports/TEST-org.example.ClinicAssistantToolsTests.xml"
  test -f "$stub_fixture/target/surefire-reports/TEST-org.example.I18nPropertiesSyncTest.xml"
  grep -Fxq "reference branch is current and validated" "$stub_output_file"
}

expect_missing_class_failure() {
  reset_fixture_state

  if run_stubbed_validator "ClinicAssistantToolsTests,MissingReferenceValidationTest"; then
    echo "validator unexpectedly passed for a missing focused test class" >&2
    exit 1
  fi

  grep -Fxq "fetch origin +refs/heads/main:refs/remotes/origin/main" "$stub_git_log"
  grep -Fxq "merge-base --is-ancestor refs/remotes/origin/main HEAD" "$stub_git_log"
  grep -Fxq "FOCUSED ClinicAssistantToolsTests true" "$stub_mvn_log"
  grep -Fxq "FOCUSED MissingReferenceValidationTest true" "$stub_mvn_log"
  ! grep -Fxq "FULL_SUITE" "$stub_mvn_log"
  grep -Fq 'No tests matching pattern "MissingReferenceValidationTest" were executed!' "$stub_output_file"
}

create_single_branch_remote_fixture() {
  rm -rf "$single_branch_fixture"
  mkdir -p "$single_branch_fixture"

  git init -b main "$single_branch_source" >/dev/null
  git -C "$single_branch_source" config user.name "Copilot Test"
  git -C "$single_branch_source" config user.email "copilot-test@example.com"

  mkdir -p "$single_branch_source/src/main/java/org/springframework/samples/petclinic/assistant"

  cat >"$single_branch_source/pom.xml" <<'EOF'
<project>
  <dependencies>
    <dependency>
      <artifactId>spring-ai-starter-model-openai</artifactId>
    </dependency>
  </dependencies>
</project>
EOF

  cat >"$single_branch_source/mvnw" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$single_branch_source/mvnw"

  git -C "$single_branch_source" add pom.xml mvnw
  git -C "$single_branch_source" commit -m "main base" >/dev/null

  git -C "$single_branch_source" switch -c reference/clinic-assistant >/dev/null 2>&1

  cat >"$single_branch_source/src/main/java/org/springframework/samples/petclinic/assistant/Placeholder.java" <<'EOF'
package org.springframework.samples.petclinic.assistant;

class Placeholder {
}
EOF

  git -C "$single_branch_source" add \
    src/main/java/org/springframework/samples/petclinic/assistant/Placeholder.java
  git -C "$single_branch_source" commit -m "reference branch" >/dev/null

  git clone --bare "$single_branch_source" "$single_branch_origin" >/dev/null 2>&1
  git clone --single-branch --branch reference/clinic-assistant \
    "$single_branch_origin" "$single_branch_clone" >/dev/null 2>&1

  write_fake_maven_wrapper "$single_branch_clone"
  : >"$single_branch_mvn_log"
}

expect_single_branch_clone_fetches_origin_main_and_reaches_test_gate() {
  create_single_branch_remote_fixture

  ! git -C "$single_branch_clone" show-ref --verify --quiet refs/remotes/origin/main

  env \
    FAKE_MVN_LOG="$single_branch_mvn_log" \
    REFERENCE_FOCUSED_TEST_CLASSES="ClinicAssistantToolsTests" \
    "$validator" "$single_branch_clone" \
    >"$single_branch_output_file" 2>&1

  git -C "$single_branch_clone" show-ref --verify --quiet refs/remotes/origin/main
  git -C "$single_branch_clone" merge-base --is-ancestor refs/remotes/origin/main HEAD
  grep -Fxq "FOCUSED ClinicAssistantToolsTests true" "$single_branch_mvn_log"
  grep -Fxq "FULL_SUITE" "$single_branch_mvn_log"
  grep -Fxq "reference branch is current and validated" "$single_branch_output_file"
}

setup_stub_fixture
expect_explicit_fetch_then_individual_runs_then_full_suite
expect_missing_class_failure
expect_single_branch_clone_fetches_origin_main_and_reaches_test_gate

echo "reference validator regression tests passed"
