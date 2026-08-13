#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
  echo "reference validation failed: $*" >&2
  exit 1
}

focused_tests='ClinicQueryServiceTests,ClinicAssistantToolsTests,ClinicAssistantModelTests,ClinicAssistantConversationTests,ClinicAssistantBoundaryTests,ClinicAssistantBoundaryScenarioTests,ClinicAssistantServiceTests,ClinicAssistantControllerTests,ClinicAssistantSessionListenerTests,I18nPropertiesSyncTest'

git fetch origin main
git merge-base --is-ancestor origin/main HEAD \
  || fail "origin/main is not an ancestor of HEAD"
test -d src/main/java/org/springframework/samples/petclinic/assistant \
  || fail "missing Clinic Assistant source directory"
grep -Fq '<artifactId>spring-ai-starter-model-openai</artifactId>' pom.xml \
  || fail "missing spring-ai-starter-model-openai in pom.xml"

./mvnw -q -Dtest="$focused_tests" test
./mvnw -q test

echo "reference branch is current and validated"
