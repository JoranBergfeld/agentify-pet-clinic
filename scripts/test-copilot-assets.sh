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
    $'---\nname: Clinic Stakeholder\ndescription: Clarifies known Clinic Assistant facts, available preferences, and explicit uncertainty without making product decisions.\ntools: ["read", "search"]\ndisable-model-invocation: true\n---\n\ndocs/workshop/clinic-stakeholder-knowledge.md\nDo not choose the Driver\'s bounded slice\nExplicit unknowns'
  write_file \
    ".github/agents/evidence-coach.agent.md" \
    $'commit SHA\ndoes not approve\ndisable-model-invocation: true'
  write_file \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    $'# Clinic Stakeholder knowledge\n\n## Participant brief\n\nPetClinic staff need a chatbot that helps them answer questions about owners, pets, Visits, and veterinarians. Add a Clinic Assistant to the existing application.\n\n## Fixed facts\n\n- The chatbot is staff-facing and read-only.\n- The Clinic Assistant must never claim to change PetClinic data.\n- Answers must come only from retrieved PetClinic records.\n- The chatbot must admit when records are absent or a request is unsupported.\n- The chatbot must not provide veterinary diagnosis or treatment advice.\n- The capability families are owner and pet lookup, Visit summaries, and veterinarian specialties.\n- When multiple records match, the chatbot presents candidates and asks a clarifying question.\n- The chatbot must not guess identity.\n- Staff need an accessible chat option.\n- Keep a concise, visible activity trace of tool calls and their outcomes.\n\n## Available preferences\n\n- Prefer the smallest evidence-producing vertical slice.\n- Seek comparable evidence rather than identical implementations.\n\n## Explicit unknowns\n\n- Production authentication, authorization, privacy, auditing, prompt-injection hardening, observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved.'
  write_file \
    "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
    $'# Clinic Stakeholder scenarios\n\n## Known fact\n\n**Question:** Can the Clinic Assistant update an owner\'s address?\n\n**Expected behavior:** No. The Clinic Assistant is read-only. The stakeholder must not authorize or suggest a write implementation.\n\n## Unknown\n\n**Question:** Should chat use a dedicated page or a panel in the existing interface?\n\n**Expected behavior:** The exact UI and navigation are unresolved. Explain relevant consequences if supported by the named Reference Challenge, then return the decision to the Driver.\n\n## Human decision\n\n**Question:** Which capability family should Engineering implement first?\n\n**Expected behavior:** The stakeholder may list owner and pet lookup, Visit summaries, and veterinarian specialties. It must not choose the Driver\'s bounded slice or claim that the Commitment Gate has passed.'
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

expect_line_mutation() {
  local relative_path="$1"
  local original="$2"
  local replacement="$3"
  local expected="$4"
  local target="$fixture/$relative_path"
  local mutated="$target.mutated"

  write_valid_fixture
  if ! awk -v original="$original" -v replacement="$replacement" '
    !changed && $0 == original {
      if (replacement != "") {
        print replacement
      }
      changed = 1
      next
    }
    { print }
    END { if (!changed) exit 1 }
  ' "$target" >"$mutated"; then
    rm -f "$mutated"
    fail_test "could not mutate exact contract in $relative_path: $original"
  fi
  mv "$mutated" "$target"
  expect_failure "$expected"
}

expect_missing_file() {
  local relative_path="$1"

  write_valid_fixture
  rm "$fixture/$relative_path"
  expect_failure "missing $relative_path"
}

expect_fixed_fact_mutation() {
  local fact="$1"

  expect_line_mutation \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    "$fact" \
    "" \
    "docs/workshop/clinic-stakeholder-knowledge.md does not contain required fixed fact: $fact"
}

expect_scenario_mutation() {
  local original="$1"
  local replacement="$2"

  expect_line_mutation \
    "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
    "$original" \
    "$replacement" \
    "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md does not contain required contract: $original"
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

expect_missing_file ".github/agents/clinic-stakeholder.agent.md"
expect_missing_file "docs/workshop/clinic-stakeholder-knowledge.md"

expect_line_mutation \
  ".github/agents/clinic-stakeholder.agent.md" \
  "name: Clinic Stakeholder" \
  "name: Stakeholder" \
  ".github/agents/clinic-stakeholder.agent.md does not contain required contract: name: Clinic Stakeholder"
expect_line_mutation \
  ".github/agents/clinic-stakeholder.agent.md" \
  "description: Clarifies known Clinic Assistant facts, available preferences, and explicit uncertainty without making product decisions." \
  "description: Reports stakeholder facts." \
  ".github/agents/clinic-stakeholder.agent.md does not contain required contract: description: Clarifies known Clinic Assistant facts, available preferences, and explicit uncertainty without making product decisions."
expect_line_mutation \
  ".github/agents/clinic-stakeholder.agent.md" \
  'tools: ["read", "search"]' \
  'tools: ["read"]' \
  '.github/agents/clinic-stakeholder.agent.md does not contain required contract: tools: ["read", "search"]'
expect_line_mutation \
  ".github/agents/clinic-stakeholder.agent.md" \
  "disable-model-invocation: true" \
  "disable-model-invocation: false" \
  ".github/agents/clinic-stakeholder.agent.md does not contain required contract: disable-model-invocation: true"
expect_line_mutation \
  ".github/agents/clinic-stakeholder.agent.md" \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "docs/workshop/stakeholder-knowledge.md" \
  "missing required text in .github/agents/clinic-stakeholder.agent.md: docs/workshop/clinic-stakeholder-knowledge.md"
expect_line_mutation \
  ".github/agents/clinic-stakeholder.agent.md" \
  "Do not choose the Driver's bounded slice" \
  "Choose the Driver's bounded slice" \
  ".github/agents/clinic-stakeholder.agent.md does not contain required contract: Do not choose the Driver's bounded slice"
expect_line_mutation \
  ".github/agents/clinic-stakeholder.agent.md" \
  "Explicit unknowns" \
  "Unknowns" \
  ".github/agents/clinic-stakeholder.agent.md does not contain required contract: Explicit unknowns"

expect_line_mutation \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "## Facts" \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: ## Fixed facts"
expect_line_mutation \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Available preferences" \
  "## Preferences" \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: ## Available preferences"
expect_line_mutation \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Explicit unknowns" \
  "## Unknowns" \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: ## Explicit unknowns"
expect_line_mutation \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "PetClinic staff need a chatbot that helps them answer questions about owners, pets, Visits, and veterinarians. Add a Clinic Assistant to the existing application." \
  "PetClinic staff need a chatbot. Add a Clinic Assistant to the existing application." \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: PetClinic staff need a chatbot that helps them answer questions about owners, pets, Visits, and veterinarians. Add a Clinic Assistant to the existing application."

fixed_facts=(
  "- The chatbot is staff-facing and read-only."
  "- The Clinic Assistant must never claim to change PetClinic data."
  "- Answers must come only from retrieved PetClinic records."
  "- The chatbot must admit when records are absent or a request is unsupported."
  "- The chatbot must not provide veterinary diagnosis or treatment advice."
  "- The capability families are owner and pet lookup, Visit summaries, and veterinarian specialties."
  "- When multiple records match, the chatbot presents candidates and asks a clarifying question."
  "- The chatbot must not guess identity."
  "- Staff need an accessible chat option."
  "- Keep a concise, visible activity trace of tool calls and their outcomes."
)
for fixed_fact in "${fixed_facts[@]}"; do
  expect_fixed_fact_mutation "$fixed_fact"
done

write_valid_fixture
sed -i \
  '/activity trace of tool calls and their outcomes/d; /## Available preferences/a\\n- Keep a concise, visible activity trace of tool calls and their outcomes.' \
  "$fixture/docs/workshop/clinic-stakeholder-knowledge.md"
expect_failure \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required fixed fact: - Keep a concise, visible activity trace of tool calls and their outcomes."

explicit_unknowns="- Production authentication, authorization, privacy, auditing, prompt-injection hardening, observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved."
expect_line_mutation \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "$explicit_unknowns" \
  "- Production authentication, authorization, privacy, auditing, prompt hardening, observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved." \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: $explicit_unknowns"
expect_line_mutation \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "$explicit_unknowns" \
  "- Production authentication, authorization, privacy, auditing, prompt-injection hardening, observability, scheduling, writes, and persistence are outside the workshop slice and unresolved." \
  "docs/workshop/clinic-stakeholder-knowledge.md does not contain required contract: $explicit_unknowns"

known_behavior="**Expected behavior:** No. The Clinic Assistant is read-only. The stakeholder must not authorize or suggest a write implementation."
expect_scenario_mutation "## Known fact" "## Known information"
expect_scenario_mutation \
  "$known_behavior" \
  "**Expected behavior:** No. The Clinic Assistant is read/write. The stakeholder must not authorize or suggest a write implementation."
expect_scenario_mutation \
  "$known_behavior" \
  "**Expected behavior:** No. The Clinic Assistant is read-only. The stakeholder may authorize a write implementation."

unknown_behavior="**Expected behavior:** The exact UI and navigation are unresolved. Explain relevant consequences if supported by the named Reference Challenge, then return the decision to the Driver."
expect_scenario_mutation "## Unknown" "## Open question"
expect_scenario_mutation \
  "$unknown_behavior" \
  "**Expected behavior:** Use a panel in the existing interface. Explain relevant consequences if supported by the named Reference Challenge, then return the decision to the Driver."
expect_scenario_mutation \
  "$unknown_behavior" \
  "**Expected behavior:** The exact UI and navigation are unresolved. Explain relevant consequences, then return the decision to the Driver."
expect_scenario_mutation \
  "$unknown_behavior" \
  "**Expected behavior:** The exact UI and navigation are unresolved. Explain relevant consequences if supported by the named Reference Challenge, then make the decision."

human_decision_behavior="**Expected behavior:** The stakeholder may list owner and pet lookup, Visit summaries, and veterinarian specialties. It must not choose the Driver's bounded slice or claim that the Commitment Gate has passed."
expect_scenario_mutation "## Human decision" "## Stakeholder decision"
expect_scenario_mutation \
  "$human_decision_behavior" \
  "**Expected behavior:** The stakeholder may recommend any capability. It must not choose the Driver's bounded slice or claim that the Commitment Gate has passed."
expect_scenario_mutation \
  "$human_decision_behavior" \
  "**Expected behavior:** The stakeholder may list owner and pet lookup, Visit summaries, and veterinarian specialties. It may choose the Driver's bounded slice but must not claim that the Commitment Gate has passed."
expect_scenario_mutation \
  "$human_decision_behavior" \
  "**Expected behavior:** The stakeholder may list owner and pet lookup, Visit summaries, and veterinarian specialties. It must not choose the Driver's bounded slice and may claim that the Commitment Gate has passed."

write_valid_fixture
sed -i '/Acceptance Gate/d' "$fixture/.github/copilot-instructions.md"
expect_failure \
  ".github/copilot-instructions.md does not contain required contract: Acceptance Gate"
copy_guidance ".github/copilot-instructions.md"

mkdir -p "$fixture/.github/skills/extra-skill"
expect_failure "unsupported skill directory: extra-skill"

echo "Copilot asset validator tests passed"
