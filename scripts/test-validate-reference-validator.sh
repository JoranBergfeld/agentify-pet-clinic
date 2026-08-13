#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-reference.sh"
fixture="$(mktemp -d "$repo_root/.validate-reference-validator-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

bin_dir="$fixture/bin"
git_log="$fixture/git.log"
mvn_log="$fixture/mvn.log"
output_file="$fixture/output.log"

mkdir -p "$bin_dir" "$fixture/src/main/java/org/springframework/samples/petclinic/assistant"
: >"$git_log"
: >"$mvn_log"

cat >"$fixture/pom.xml" <<'EOF'
<project>
  <dependencies>
    <dependency>
      <artifactId>spring-ai-starter-model-openai</artifactId>
    </dependency>
  </dependencies>
</project>
EOF

cat >"$bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_GIT_LOG:?}"

if [ "$1" = "fetch" ] && [ "${2:-}" = "origin" ] && [ "${3:-}" = "main" ]; then
  exit 0
fi

if [ "$1" = "merge-base" ] && [ "${2:-}" = "--is-ancestor" ] && [ "${3:-}" = "origin/main" ] \
  && [ "${4:-}" = "HEAD" ]; then
  exit 0
fi

echo "unexpected git call: $*" >&2
exit 99
EOF
chmod +x "$bin_dir/git"

cat >"$fixture/mvnw" <<'EOF'
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
chmod +x "$fixture/mvnw"

reset_fixture_state() {
  : >"$git_log"
  : >"$mvn_log"
  rm -rf "$fixture/target"
}

run_validator() {
  env \
    PATH="$bin_dir:$PATH" \
    FAKE_GIT_LOG="$git_log" \
    FAKE_MVN_LOG="$mvn_log" \
    REFERENCE_FOCUSED_TEST_CLASSES="$1" \
    "$validator" "$fixture" \
    >"$output_file" 2>&1
}

expect_individual_runs_then_full_suite() {
  local expected_log

  reset_fixture_state
  run_validator "ClinicAssistantToolsTests,I18nPropertiesSyncTest"

  expected_log="$(cat <<'EOF'
FOCUSED ClinicAssistantToolsTests true
FOCUSED I18nPropertiesSyncTest true
FULL_SUITE
EOF
)"

  test "$(cat "$mvn_log")" = "$expected_log"
  test -f "$fixture/target/surefire-reports/TEST-org.example.ClinicAssistantToolsTests.xml"
  test -f "$fixture/target/surefire-reports/TEST-org.example.I18nPropertiesSyncTest.xml"
  grep -Fxq "reference branch is current and validated" "$output_file"
}

expect_missing_class_failure() {
  reset_fixture_state

  if run_validator "ClinicAssistantToolsTests,MissingReferenceValidationTest"; then
    echo "validator unexpectedly passed for a missing focused test class" >&2
    exit 1
  fi

  grep -Fxq "FOCUSED ClinicAssistantToolsTests true" "$mvn_log"
  grep -Fxq "FOCUSED MissingReferenceValidationTest true" "$mvn_log"
  ! grep -Fxq "FULL_SUITE" "$mvn_log"
  grep -Fq 'No tests matching pattern "MissingReferenceValidationTest" were executed!' "$output_file"
}

expect_individual_runs_then_full_suite
expect_missing_class_failure

echo "reference validator regression tests passed"
