#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-reference.sh"
fixture_root="$repo_root/.reference-validator-fixture-$BASHPID"
stub_fixture="$fixture_root/stub"
single_branch_fixture="$fixture_root/single-branch"
stub_bin_dir="$stub_fixture/bin"
stub_git_log="$stub_fixture/git.log"
stub_gradle_log="$stub_fixture/gradle.log"
stub_mvn_log="$stub_fixture/mvn.log"
stub_output_file="$stub_fixture/output.log"
single_branch_source="$single_branch_fixture/source"
single_branch_origin="$single_branch_fixture/origin.git"
single_branch_clone="$single_branch_fixture/clone"
single_branch_gradle_log="$single_branch_fixture/gradle.log"
single_branch_mvn_log="$single_branch_fixture/mvn.log"
single_branch_output_file="$single_branch_fixture/output.log"
trap 'rm -rf "$fixture_root"' EXIT

write_reference_build_gradle() {
  local root="$1"

  cat >"$root/build.gradle" <<'EOF'
dependencies {
  implementation platform('org.springframework.ai:spring-ai-bom:2.0.0')
  implementation 'org.springframework.ai:spring-ai-starter-model-openai'
  implementation 'com.azure:azure-identity:1.18.2'
}
EOF
}

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

write_fake_gradle_wrapper() {
  local root="$1"

  cat >"$root/gradlew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FAKE_GRADLE_LOG:?}"

printf '%s\n' "$*" >>"$log_file"

case "$*" in
  '-q compileJava' | 'compileJava')
    exit 0
    ;;
  'test')
    exit 0
    ;;
esac

echo "unexpected gradle call: $*" >&2
exit 91
EOF
  chmod +x "$root/gradlew"
}

setup_stub_fixture() {
  rm -rf "$stub_fixture"
  mkdir -p "$stub_bin_dir" "$stub_fixture/src/main/java/org/springframework/samples/petclinic/assistant"
  : >"$stub_git_log"
  : >"$stub_gradle_log"
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
  write_reference_build_gradle "$stub_fixture"

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
  write_fake_gradle_wrapper "$stub_fixture"
  write_fake_maven_wrapper "$stub_fixture"
}

reset_fixture_state() {
  : >"$stub_git_log"
  : >"$stub_gradle_log"
  : >"$stub_mvn_log"
  rm -rf "$stub_fixture/target"
}

run_stubbed_validator() {
  env \
    PATH="$stub_bin_dir:$PATH" \
    FAKE_GIT_LOG="$stub_git_log" \
    FAKE_GRADLE_LOG="$stub_gradle_log" \
    FAKE_MVN_LOG="$stub_mvn_log" \
    REFERENCE_FOCUSED_TEST_CLASSES="$1" \
    "$validator" "$stub_fixture" \
    >"$stub_output_file" 2>&1
}

expect_explicit_fetch_then_gradle_compile_then_individual_runs_then_full_suite() {
  local expected_git_log expected_gradle_log expected_mvn_log

  reset_fixture_state
  run_stubbed_validator "ClinicAssistantToolsTests,I18nPropertiesSyncTest"

  expected_git_log="$(cat <<'EOF'
fetch origin +refs/heads/main:refs/remotes/origin/main
merge-base --is-ancestor refs/remotes/origin/main HEAD
EOF
)"

  expected_gradle_log="$(cat <<'EOF'
-q compileJava
EOF
)"

  expected_mvn_log="$(cat <<'EOF'
FOCUSED ClinicAssistantToolsTests true
FOCUSED I18nPropertiesSyncTest true
FULL_SUITE
EOF
)"

  test "$(cat "$stub_git_log")" = "$expected_git_log"
  test "$(cat "$stub_gradle_log")" = "$expected_gradle_log"
  test "$(cat "$stub_mvn_log")" = "$expected_mvn_log"
  test -f "$stub_fixture/target/surefire-reports/TEST-org.example.ClinicAssistantToolsTests.xml"
  test -f "$stub_fixture/target/surefire-reports/TEST-org.example.I18nPropertiesSyncTest.xml"
  grep -Fxq "reference branch is current and validated" "$stub_output_file"
}

expect_missing_gradle_dependency_failure() {
  reset_fixture_state

  cat >"$stub_fixture/build.gradle" <<'EOF'
dependencies {
  implementation platform('org.springframework.ai:spring-ai-bom:2.0.0')
  implementation 'com.azure:azure-identity:1.18.2'
}
EOF

  if run_stubbed_validator "ClinicAssistantToolsTests"; then
    echo "validator unexpectedly passed without Gradle Spring AI dependency" >&2
    exit 1
  fi

  grep -Fxq "fetch origin +refs/heads/main:refs/remotes/origin/main" "$stub_git_log"
  grep -Fxq "merge-base --is-ancestor refs/remotes/origin/main HEAD" "$stub_git_log"
  test ! -s "$stub_gradle_log"
  test ! -s "$stub_mvn_log"
  grep -Fq "missing spring-ai-starter-model-openai in build.gradle" "$stub_output_file"

  write_reference_build_gradle "$stub_fixture"
}

expect_missing_class_failure() {
  reset_fixture_state

  if run_stubbed_validator "ClinicAssistantToolsTests,MissingReferenceValidationTest"; then
    echo "validator unexpectedly passed for a missing focused test class" >&2
    exit 1
  fi

  grep -Fxq "fetch origin +refs/heads/main:refs/remotes/origin/main" "$stub_git_log"
  grep -Fxq "merge-base --is-ancestor refs/remotes/origin/main HEAD" "$stub_git_log"
  grep -Fxq -- "-q compileJava" "$stub_gradle_log"
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
  write_reference_build_gradle "$single_branch_source"

  cat >"$single_branch_source/mvnw" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$single_branch_source/mvnw"

  cat >"$single_branch_source/gradlew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$single_branch_source/gradlew"

  git -C "$single_branch_source" add pom.xml build.gradle mvnw gradlew
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

  write_fake_gradle_wrapper "$single_branch_clone"
  write_fake_maven_wrapper "$single_branch_clone"
  : >"$single_branch_gradle_log"
  : >"$single_branch_mvn_log"
}

expect_single_branch_clone_fetches_origin_main_and_reaches_test_gate() {
  create_single_branch_remote_fixture

  ! git -C "$single_branch_clone" show-ref --verify --quiet refs/remotes/origin/main

  env \
    FAKE_GRADLE_LOG="$single_branch_gradle_log" \
    FAKE_MVN_LOG="$single_branch_mvn_log" \
    REFERENCE_FOCUSED_TEST_CLASSES="ClinicAssistantToolsTests" \
    "$validator" "$single_branch_clone" \
    >"$single_branch_output_file" 2>&1

  git -C "$single_branch_clone" show-ref --verify --quiet refs/remotes/origin/main
  git -C "$single_branch_clone" merge-base --is-ancestor refs/remotes/origin/main HEAD
  grep -Fxq -- "-q compileJava" "$single_branch_gradle_log"
  grep -Fxq "FOCUSED ClinicAssistantToolsTests true" "$single_branch_mvn_log"
  grep -Fxq "FULL_SUITE" "$single_branch_mvn_log"
  grep -Fxq "reference branch is current and validated" "$single_branch_output_file"
}

setup_stub_fixture
expect_explicit_fetch_then_gradle_compile_then_individual_runs_then_full_suite
expect_missing_gradle_dependency_failure
expect_missing_class_failure
expect_single_branch_clone_fetches_origin_main_and_reaches_test_gate

echo "reference validator regression tests passed"
