#!/usr/bin/env bash
set -euo pipefail

default_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "reference validation failed: $*" >&2
  exit 1
}

default_focused_test_classes=(
  ClinicQueryServiceTests
  ClinicAssistantToolsTests
  ClinicAssistantModelTests
  ClinicAssistantConversationTests
  ClinicAssistantBoundaryTests
  ClinicAssistantBoundaryScenarioTests
  ClinicAssistantServiceTests
  ClinicAssistantControllerTests
  ClinicAssistantSessionListenerTests
  I18nPropertiesSyncTest
)

focused_test_classes=()

load_focused_test_classes() {
  if [ -n "${REFERENCE_FOCUSED_TEST_CLASSES:-}" ]; then
    IFS=',' read -r -a focused_test_classes <<<"${REFERENCE_FOCUSED_TEST_CLASSES}"
  else
    focused_test_classes=("${default_focused_test_classes[@]}")
  fi

  local index test_class

  for index in "${!focused_test_classes[@]}"; do
    test_class="${focused_test_classes[$index]//[[:space:]]/}"
    [ -n "$test_class" ] || fail "focused test class list contains an empty entry"
    focused_test_classes[$index]="$test_class"
  done
}

clear_surefire_report_artifacts() {
  local test_class="$1"

  mkdir -p target/surefire-reports
  find target/surefire-reports -maxdepth 1 -type f \
    \( -name "TEST-*${test_class}.xml" -o -name "*${test_class}.txt" \) \
    -delete
}

assert_surefire_report_generated() {
  local test_class="$1"

  find target/surefire-reports -maxdepth 1 -type f -name "TEST-*${test_class}.xml" | grep -q . \
    || fail "missing Surefire report for $test_class"
}

run_focused_test_class() {
  local test_class="$1"

  echo "running focused reference test: $test_class"
  clear_surefire_report_artifacts "$test_class"
  ./mvnw -q -Dtest="$test_class" -Dsurefire.failIfNoSpecifiedTests=true test
  assert_surefire_report_generated "$test_class"
}

run_gradle_compile_validation() {
  echo "running Gradle compile validation"
  ./gradlew -q compileJava
}

refresh_origin_main_tracking_ref() {
  git fetch origin +refs/heads/main:refs/remotes/origin/main
}

main() {
  local root="${1:-$default_root}"

  cd "$root"
  load_focused_test_classes

  refresh_origin_main_tracking_ref
  git merge-base --is-ancestor refs/remotes/origin/main HEAD \
    || fail "refs/remotes/origin/main is not an ancestor of HEAD"
  test -d src/main/java/org/springframework/samples/petclinic/assistant \
    || fail "missing Clinic Assistant source directory"
  grep -Fq '<artifactId>spring-ai-starter-model-openai</artifactId>' pom.xml \
    || fail "missing spring-ai-starter-model-openai in pom.xml"
  grep -Fq "spring-ai-bom:2.0.0" build.gradle \
    || fail "missing spring-ai-bom platform in build.gradle"
  grep -Fq "spring-ai-starter-model-openai" build.gradle \
    || fail "missing spring-ai-starter-model-openai in build.gradle"
  grep -Fq "azure-identity:1.18.2" build.gradle \
    || fail "missing azure-identity in build.gradle"

  run_gradle_compile_validation

  for test_class in "${focused_test_classes[@]}"; do
    run_focused_test_class "$test_class"
  done

  echo "running full Maven test suite"
  ./mvnw -q test

  echo "reference branch is current and validated"
}

main "$@"
