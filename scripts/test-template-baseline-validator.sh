#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-template-baseline.sh"
fixture="$(mktemp -d "$repo_root/.template-baseline-validator-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

write_clean_provenance() {
  cat >"$fixture/workshop/baseline.properties" <<'EOF'
upstream.repository=https://github.com/spring-projects/spring-petclinic.git
upstream.commit=88e37c15cf6fc8490b01bc3e8e2c800cec1ac272
EOF
}

write_clean_pom() {
  cat >"$fixture/pom.xml" <<'EOF'
<project><dependencies></dependencies></project>
EOF
}

write_clean_gradle() {
  cat >"$fixture/build.gradle" <<'EOF'
plugins {}
EOF
}

copy_clean_baseline_file() {
  local relative_path="$1"

  mkdir -p "$(dirname "$fixture/$relative_path")"
  cp "$repo_root/$relative_path" "$fixture/$relative_path"
}

write_clean_ui_resources() {
  copy_clean_baseline_file "src/main/resources/templates/fragments/layout.html"
  copy_clean_baseline_file "src/main/resources/messages/messages.properties"
  copy_clean_baseline_file "src/main/scss/petclinic.scss"
  copy_clean_baseline_file "src/main/resources/application.properties"
}

expect_failure() {
  local expected="$1"
  local output

  if output="$("$validator" "$fixture" 2>&1)"; then
    echo "validator unexpectedly passed: $expected" >&2
    exit 1
  fi

  test "$output" = "template baseline invalid: $expected"
}

expect_reference_only_directory_failure() {
  local relative_dir="$1"

  mkdir -p "$fixture/$relative_dir"
  expect_failure "reference-only directory is present: $relative_dir/"
  rmdir "$fixture/$relative_dir"
}

expect_reference_only_file_failure() {
  local relative_path="$1"

  mkdir -p "$(dirname "$fixture/$relative_path")"
  touch "$fixture/$relative_path"
  expect_failure "reference-only file is present: $relative_path"
  rm "$fixture/$relative_path"
}

expect_clean() {
  local clean_output

  clean_output="$("$validator" "$fixture")"
  test "$clean_output" = "template baseline is structurally clean"
}

expect_file_append_failure() {
  local relative_path="$1"
  local appended_line="$2"
  local expected="$3"

  printf '%s\n' "$appended_line" >>"$fixture/$relative_path"
  expect_failure "$expected"
  copy_clean_baseline_file "$relative_path"
  expect_clean
}

mkdir -p "$fixture/workshop" "$fixture/src/main/java" "$fixture/docs" "$fixture/.azure"
write_clean_provenance
write_clean_pom
write_clean_gradle
write_clean_ui_resources
touch "$fixture/mvnw"
chmod +x "$fixture/mvnw"
touch "$fixture/.azure/.gitignore"

expect_clean

mkdir -p "$fixture/docs/workshop" "$fixture/workshop/templates"
touch \
  "$fixture/docs/workshop/work-contract-template.md" \
  "$fixture/workshop/stage-card-template.md" \
  "$fixture/workshop/reference-answer-template.md" \
  "$fixture/workshop/reference-challenge-template.md"
expect_clean

copy_clean_baseline_file "azure.yaml"
copy_clean_baseline_file "infra/main.bicep"
copy_clean_baseline_file "infra/resources.bicep"
copy_clean_baseline_file "scripts/azure-readiness.sh"
copy_clean_baseline_file "scripts/azure-preflight.sh"
copy_clean_baseline_file "scripts/azure-cleanup.sh"
expect_clean

mkdir -p "$fixture/src/main/java/org/springframework/samples/petclinic/assistant"
expect_failure "Clinic Assistant solution code is present"
rm -rf "$fixture/src/main/java/org/springframework/samples/petclinic/assistant"

printf '<project><artifactId>spring-ai-starter-model-openai</artifactId></project>\n' >"$fixture/pom.xml"
expect_failure "Spring AI application dependency is present"
write_clean_pom

printf "implementation 'org.springframework.ai:spring-ai-starter-model-openai'\n" >"$fixture/build.gradle"
expect_failure "Spring AI application dependency is present"
write_clean_gradle

expect_reference_only_directory_failure "docs/reference"
expect_reference_only_directory_failure "workshop/reference"
expect_reference_only_directory_failure "workshop/completed"

mkdir -p "$fixture/.workshop-evidence"
touch "$fixture/.workshop-evidence/preflight-example.md"
expect_failure "generated evidence directory is present: .workshop-evidence/"
rm "$fixture/.workshop-evidence/preflight-example.md"
touch "$fixture/.workshop-evidence/cleanup-example.md"
expect_failure "generated evidence directory is present: .workshop-evidence/"
rm -rf "$fixture/.workshop-evidence"

expect_reference_only_file_failure "scripts/azure-reference-smoke.sh"
expect_reference_only_file_failure "scripts/test-azure-reference-smoke.sh"

mkdir -p "$fixture/src/main/resources/templates/assistant"
expect_failure "reference-only directory is present: src/main/resources/templates/assistant/"
rmdir "$fixture/src/main/resources/templates/assistant"
expect_clean

expect_file_append_failure \
  "src/main/resources/templates/fragments/layout.html" \
  "<!-- clinic-assistant navigation -->" \
  "Clinic Assistant UI marker is present in src/main/resources/templates/fragments/layout.html"

expect_file_append_failure \
  "src/main/resources/messages/messages.properties" \
  "clinicAssistant=Clinic Assistant" \
  "Clinic Assistant UI marker is present in src/main/resources/messages/messages.properties"

expect_file_append_failure \
  "src/main/scss/petclinic.scss" \
  ".clinic-assistant-panel { color: #000; }" \
  "Clinic Assistant UI marker is present in src/main/scss/petclinic.scss"

expect_file_append_failure \
  "src/main/resources/application.properties" \
  "spring.ai.openai.api-key=test-key" \
  "Spring AI application property is present in src/main/resources/application.properties"

expect_file_append_failure \
  "src/main/resources/application.properties" \
  "# spring.ai.openai.api-key=test-key" \
  "Spring AI application property is present in src/main/resources/application.properties"

rm "$fixture/mvnw"
expect_failure "missing Maven wrapper"
touch "$fixture/mvnw"
chmod +x "$fixture/mvnw"

rm "$fixture/pom.xml"
expect_failure "missing Maven project"
write_clean_pom

printf '%s\n' \
  'upstream.repository=https://example.com/not-petclinic.git' \
  'upstream.commit=88e37c15cf6fc8490b01bc3e8e2c800cec1ac272' \
  >"$fixture/workshop/baseline.properties"
expect_failure "unexpected upstream repository"
write_clean_provenance

printf '%s\n' \
  'upstream.repository=https://github.com/spring-projects/spring-petclinic.git' \
  'upstream.commit=deadbeef' \
  >"$fixture/workshop/baseline.properties"
expect_failure "unexpected upstream commit"
write_clean_provenance

touch "$fixture/.env"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/.env"

touch "$fixture/.env.local"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/.env.local"

touch "$fixture/terraform.tfstate"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/terraform.tfstate"

touch "$fixture/terraform.tfstate.backup"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/terraform.tfstate.backup"

touch "$fixture/azureProfile.json"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/azureProfile.json"

touch "$fixture/.azure/config.json"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/.azure/config.json"

mkdir -p "$fixture/.git" "$fixture/.worktrees/example/.azure"
touch \
  "$fixture/.git/.env.local" \
  "$fixture/.git/azureProfile.json" \
  "$fixture/.worktrees/example/.azure/config.json" \
  "$fixture/.worktrees/example/terraform.tfstate" \
  "$fixture/.worktrees/example/terraform.tfstate.backup"
expect_clean

echo "template baseline validator tests passed"
