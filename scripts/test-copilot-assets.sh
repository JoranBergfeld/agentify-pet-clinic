#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-copilot-assets.sh"
fixture="$(mktemp -d "$repo_root/.copilot-assets-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
}

write_file() {
  local relative_path="$1"
  local content="$2"

  mkdir -p "$(dirname "$fixture/$relative_path")"
  printf '%s\n' "$content" >"$fixture/$relative_path"
}

copy_guidance() {
  local relative_path="$1"

  mkdir -p "$(dirname "$fixture/$relative_path")"
  if test -f "$repo_root/$relative_path"; then
    cp "$repo_root/$relative_path" "$fixture/$relative_path"
  else
    : >"$fixture/$relative_path"
  fi
}

write_valid_fixture() {
  local skill

  copy_guidance "AGENTS.md"
  copy_guidance ".github/copilot-instructions.md"
  write_file \
    ".github/instructions/repository-maintenance.instructions.md" \
    $'---\napplyTo: ".github/skills/**,.github/agents/**,.github/instructions/**,docs/agents/**,docs/superpowers/**,CONTEXT.md"\n---\n\n# Repository maintenance'
  write_file \
    ".github/agents/clinic-stakeholder.agent.md" \
    $'---\nname: Clinic Stakeholder\ndescription: Reports fixed facts and Explicit unknowns\ntools: ["read", "search"]\ndisable-model-invocation: true\n---\n\ndocs/workshop/clinic-stakeholder-knowledge.md\nDo not choose the Driver\'s bounded slice'
  write_file \
    ".github/agents/evidence-coach.agent.md" \
    $'commit SHA\ndoes not approve\ndisable-model-invocation: true'
  write_file \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    $'# Clinic Stakeholder knowledge\n\n## Participant brief\n\nPetClinic staff need a chatbot that helps them answer questions about owners, pets, Visits, and veterinarians. Add a Clinic Assistant to the existing application.\n\n## Fixed facts\n\n- The Clinic Assistant must never claim to change PetClinic data.\n- When multiple records match, the chatbot presents candidates and asks a clarifying question.\n\n## Available preferences\n\n- Keep a concise, visible activity trace of tool calls and their outcomes.\n\n## Explicit unknowns\n\n- Production authentication, authorization, privacy, auditing, prompt-injection hardening, observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved.'
  write_file \
    "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
    "Clinic stakeholder behavior scenarios"
  write_file \
    "scripts/fixtures/copilot-assets/evidence-coach-scenarios.md" \
    "Evidence coach behavior scenarios"

  for skill in \
    code-review \
    codebase-design \
    diagnosing-bugs \
    domain-modeling \
    grilling \
    prototype \
    tdd \
    wayfinder; do
    write_file ".github/skills/$skill/SKILL.md" "$skill skill"
  done
}

expect_failure() {
  local expected="$1"
  local output

  if output="$("$validator" "$fixture" 2>&1)"; then
    fail_test "validator unexpectedly passed: $expected"
  fi

  test "$output" = "Copilot assets invalid: $expected" ||
    fail_test "expected 'Copilot assets invalid: $expected', got '$output'"
}

write_valid_fixture

output="$("$validator" "$fixture")"
test "$output" = "Copilot assets are structurally valid" ||
  fail_test "unexpected success output: $output"

write_file \
  ".github/instructions/repository-maintenance.instructions.md" \
  $'---\napplyTo:\n  - ".github/skills/**"\n  - ".github/agents/**"\n  - ".github/instructions/**"\n  - "docs/agents/**"\n  - "docs/superpowers/**"\n  - "CONTEXT.md"\n---\n\napplyTo: ".github/skills/**,.github/agents/**,.github/instructions/**,docs/agents/**,docs/superpowers/**,CONTEXT.md"'
expect_failure \
  ".github/instructions/repository-maintenance.instructions.md does not contain required contract: applyTo: \".github/skills/**,.github/agents/**,.github/instructions/**,docs/agents/**,docs/superpowers/**,CONTEXT.md\""
write_valid_fixture

rm "$fixture/.github/agents/clinic-stakeholder.agent.md"
expect_failure "missing .github/agents/clinic-stakeholder.agent.md"
write_valid_fixture

rm "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure "missing docs/workshop/clinic-stakeholder-knowledge.md"
write_valid_fixture

sed -i '/Explicit unknowns/d' \
  "$fixture/.github/agents/clinic-stakeholder.agent.md"
expect_failure \
  ".github/agents/clinic-stakeholder.agent.md does not contain required contract: Explicit unknowns"
write_valid_fixture

sed -i '/## Explicit unknowns/d' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: ## Explicit unknowns"
write_valid_fixture

sed -i '/Add a Clinic Assistant to the existing application[.]/d' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: PetClinic staff need a chatbot that helps them answer questions about owners, pets, Visits, and veterinarians. Add a Clinic Assistant to the existing application."
write_valid_fixture

sed -i '/must never claim to change PetClinic data/d' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: - The Clinic Assistant must never claim to change PetClinic data."
write_valid_fixture

sed -i '/presents candidates and asks a clarifying question/d' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: - When multiple records match, the chatbot presents candidates and asks a clarifying question."
write_valid_fixture

sed -i '/activity trace of tool calls and their outcomes/d' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: - Keep a concise, visible activity trace of tool calls and their outcomes."
write_valid_fixture

sed -i 's/prompt-injection hardening/prompt hardening/' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: - Production authentication, authorization, privacy, auditing, prompt-injection hardening, observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved."
write_valid_fixture

sed -i 's/persistent conversations/persistence/' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: - Production authentication, authorization, privacy, auditing, prompt-injection hardening, observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved."
write_valid_fixture

sed -i '/Acceptance Gate/d' "$fixture/.github/copilot-instructions.md"
expect_failure \
  ".github/copilot-instructions.md does not contain required contract: Acceptance Gate"
copy_guidance ".github/copilot-instructions.md"

mkdir -p "$fixture/.github/skills/extra-skill"
expect_failure "unsupported skill directory: extra-skill"

echo "Copilot asset validator tests passed"
