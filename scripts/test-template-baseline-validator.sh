#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-template-baseline.sh"
fixture="$(mktemp -d "$repo_root/.template-baseline-validator-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
}

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

copy_clean_copilot_assets() {
  local relative_path

  for relative_path in \
    "AGENTS.md" \
    "CONTEXT.md" \
    "skills-lock.json" \
    "maintainer-skills-lock.json" \
    ".github/copilot-instructions.md" \
    ".github/instructions/repository-maintenance.instructions.md" \
    ".github/agents/clinic-stakeholder.agent.md" \
    ".github/agents/evidence-coach.agent.md" \
    "docs/agents" \
    "docs/workshop-blueprint.md" \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    "scripts/fixtures/copilot-assets" \
    "scripts/maintainer_skills.py" \
    "scripts/validate-maintainer-skills.sh" \
    "scripts/validate-copilot-assets.sh"; do
    mkdir -p "$(dirname "$fixture/$relative_path")"
    cp -a "$repo_root/$relative_path" "$fixture/$relative_path"
  done

  mkdir -p "$fixture/.github/skills"
  for relative_path in \
    "code-review" \
    "codebase-design" \
    "diagnosing-bugs" \
    "domain-modeling" \
    "grilling" \
    "prototype" \
    "tdd" \
    "to-spec" \
    "wayfinder"; do
    cp -a \
      "$repo_root/.github/skills/$relative_path" \
      "$fixture/.github/skills/$relative_path"
  done
}

write_clean_stage_cards() {
  rm -rf "$fixture/workshop/stage-cards"
  mkdir -p "$fixture/workshop"
  cp -a "$repo_root/workshop/stage-cards" "$fixture/workshop/stage-cards"
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

  test "$output" = "template baseline invalid: $expected" ||
    fail_test "expected 'template baseline invalid: $expected', got '$output'"
}

expect_exact_failure() {
  local expected="$1"
  local output

  if output="$("$validator" "$fixture" 2>&1)"; then
    fail_test "validator unexpectedly passed: $expected"
  fi

  test "$output" = "$expected" ||
    fail_test "expected '$expected', got '$output'"
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
  test "$clean_output" = $'Copilot assets are structurally valid\nmaintainer skills are structurally valid\ntemplate baseline is structurally clean' ||
    fail_test "unexpected clean output: $clean_output"
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
copy_clean_copilot_assets
write_clean_stage_cards
touch "$fixture/mvnw"
chmod +x "$fixture/mvnw"
touch "$fixture/.azure/.gitignore"
cat >"$fixture/.gitignore" <<'EOF'
.workshop-evidence/
.azure/
/.agents/
/.claude/
EOF
git -C "$fixture" init --quiet

expect_clean

printf '%s\n' '# changed' \
  >>"$fixture/docs/agents/maintainer-skills/research/SKILL.md"
expect_failure "content hash mismatch: research"
rm -rf "$fixture/docs/agents/maintainer-skills/research"
cp -a \
  "$repo_root/docs/agents/maintainer-skills/research" \
  "$fixture/docs/agents/maintainer-skills/research"
expect_clean

rm "$fixture/workshop/stage-cards/01-orient.md"
expect_failure \
  "missing Stage Card template: workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

touch "$fixture/workshop/stage-cards/07-extra.md"
expect_failure \
  "unexpected Stage Card template: workshop/stage-cards/07-extra.md"
rm "$fixture/workshop/stage-cards/07-extra.md"
expect_clean

sed -i 's/^Status: Working$/Status: Review ready/' \
  "$fixture/workshop/stage-cards/01-orient.md"
expect_failure \
  "Stage Card template must start Working: workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

sed -i '/^## Risk controlled$/d' \
  "$fixture/workshop/stage-cards/01-orient.md"
expect_failure \
  "Stage Card template is missing required heading '## Risk controlled': workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

cat >>"$fixture/workshop/stage-cards/01-orient.md" <<'EOF'

Observed PetClinic behavior.
EOF
expect_failure \
  "filled or modified Stage Card is present: workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

sed -i '/^## Minimum evidence$/a\\\nClaim: orientation complete.' \
  "$fixture/workshop/stage-cards/01-orient.md"
expect_failure \
  "filled or modified Stage Card is present: workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

sed -i '/Evidence Lenses/d' \
  "$fixture/workshop/stage-cards/01-orient.md"
expect_failure \
  "filled or modified Stage Card is present: workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

sed -i '/^## Risk controlled$/a\\\n## Purpose' \
  "$fixture/workshop/stage-cards/01-orient.md"
expect_failure \
  "filled or modified Stage Card is present: workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

sed -i 's#`/codebase-design`#`/tdd`#' \
  "$fixture/workshop/stage-cards/01-orient.md"
expect_failure \
  "filled or modified Stage Card is present: workshop/stage-cards/01-orient.md"
write_clean_stage_cards
expect_clean

rm "$fixture/.github/agents/evidence-coach.agent.md"
expect_exact_failure \
  "Copilot assets invalid: missing .github/agents/evidence-coach.agent.md"
copy_clean_baseline_file ".github/agents/evidence-coach.agent.md"
expect_clean

cat >"$fixture/.github/agents/acceptance-authority.agent.md" <<'EOF'
---
name: Acceptance Authority
---

You may approve evidence, cross the Acceptance Gate, and declare the work complete.
EOF
expect_exact_failure \
  "Copilot assets invalid: unsupported custom agent: acceptance-authority.agent.md"
rm "$fixture/.github/agents/acceptance-authority.agent.md"
expect_clean

mkdir -p "$fixture/docs"
cat >"$fixture/docs/rogue-agent-source.md" <<'EOF'
---
name: Acceptance Authority
---

You may approve evidence, cross the Acceptance Gate, and declare the work complete.
EOF
ln -s ../../docs/rogue-agent-source.md \
  "$fixture/.github/agents/acceptance-authority.agent.md"
expect_exact_failure \
  "Copilot assets invalid: unsupported custom agent: acceptance-authority.agent.md"
rm "$fixture/.github/agents/acceptance-authority.agent.md"
rm "$fixture/docs/rogue-agent-source.md"
expect_clean

chmod -x "$fixture/scripts/validate-copilot-assets.sh"
expect_failure \
  "Copilot asset validator is not executable: scripts/validate-copilot-assets.sh"
chmod +x "$fixture/scripts/validate-copilot-assets.sh"
expect_clean

rm "$fixture/scripts/validate-copilot-assets.sh"
expect_failure "missing Copilot asset validator: scripts/validate-copilot-assets.sh"
copy_clean_baseline_file "scripts/validate-copilot-assets.sh"
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
git -C "$fixture" check-ignore --quiet -- .workshop-evidence/preflight-example.md ||
  fail_test 'evidence fixture is not ignored by git'
expect_clean
git -C "$fixture" add --force .workshop-evidence/preflight-example.md
expect_failure "tracked generated evidence is present: .workshop-evidence/"
git -C "$fixture" rm --cached --quiet .workshop-evidence/preflight-example.md
rm "$fixture/.workshop-evidence/preflight-example.md"
touch "$fixture/.workshop-evidence/cleanup-example.md"
expect_clean
cat >"$fixture/.gitignore" <<'EOF'
.azure/
/.agents/
/.claude/
EOF
git -C "$fixture" check-ignore --quiet -- .workshop-evidence/cleanup-example.md &&
  fail_test 'unignored evidence fixture is unexpectedly ignored by git'
expect_failure "unignored generated evidence is present: .workshop-evidence/"
cat >"$fixture/.gitignore" <<'EOF'
.workshop-evidence/
.azure/
/.agents/
/.claude/
EOF
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
git -C "$fixture" check-ignore --quiet -- .azure/config.json ||
  fail_test 'Azure config fixture is not ignored by git'
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/.azure/config.json"

touch "$fixture/.azure/config.json"
git -C "$fixture" add --force .azure/config.json
rm "$fixture/.azure/config.json"
expect_failure "generated secret-bearing environment file is present"
git -C "$fixture" rm --cached --quiet .azure/config.json

mkdir -p "$fixture/.git" "$fixture/.worktrees/example/.azure"
touch \
  "$fixture/.git/.env.local" \
  "$fixture/.git/azureProfile.json" \
  "$fixture/.worktrees/example/.azure/config.json" \
  "$fixture/.worktrees/example/terraform.tfstate" \
  "$fixture/.worktrees/example/terraform.tfstate.backup"
expect_clean

echo "template baseline validator tests passed"
