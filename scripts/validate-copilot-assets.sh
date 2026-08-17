#!/usr/bin/env bash
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

fail() {
  echo "Copilot assets invalid: $*" >&2
  exit 1
}

require_file() {
  local relative_path="$1"

  test -f "$root/$relative_path" || fail "missing $relative_path"
}

require_text() {
  local relative_path="$1"
  local expected="$2"

  grep -Fq "$expected" "$root/$relative_path" ||
    fail "missing required text in $relative_path: $expected"
}

require_contract() {
  local relative_path="$1"
  local expected="$2"

  grep -Fq "$expected" "$root/$relative_path" ||
    fail "$relative_path does not contain required contract: $expected"
}

require_contract_line() {
  local relative_path="$1"
  local expected="$2"

  grep -Fxq -- "$expected" "$root/$relative_path" ||
    fail "$relative_path does not contain required contract: $expected"
}

require_fixed_fact() {
  local relative_path="$1"
  local expected="$2"

  awk -v expected="$expected" '
    $0 == "## Fixed facts" { in_fixed_facts = 1; next }
    in_fixed_facts && /^## / { exit 1 }
    in_fixed_facts && $0 == expected { found = 1; exit }
    END { if (!found) exit 1 }
  ' "$root/$relative_path" ||
    fail "$relative_path does not contain required fixed fact: $expected"
}

require_frontmatter_line() {
  local relative_path="$1"
  local expected="$2"
  local line
  local line_number=0
  local found=false

  while IFS= read -r line || test -n "$line"; do
    ((line_number += 1))

    if ((line_number == 1)); then
      test "$line" = "---" ||
        fail "$relative_path does not contain required contract: $expected"
    elif test "$line" = "---"; then
      test "$found" = true ||
        fail "$relative_path does not contain required contract: $expected"
      return
    elif test "$line" = "$expected"; then
      found=true
    fi
  done <"$root/$relative_path"

  fail "$relative_path does not contain required contract: $expected"
}

required_files=(
  "AGENTS.md"
  ".github/copilot-instructions.md"
  ".github/instructions/repository-maintenance.instructions.md"
  ".github/agents/clinic-stakeholder.agent.md"
  ".github/agents/evidence-coach.agent.md"
  "docs/workshop/clinic-stakeholder-knowledge.md"
  "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md"
  "scripts/fixtures/copilot-assets/evidence-coach-scenarios.md"
)

supported_skills=(
  "code-review"
  "codebase-design"
  "diagnosing-bugs"
  "domain-modeling"
  "grilling"
  "prototype"
  "tdd"
  "wayfinder"
)

for relative_path in "${required_files[@]}"; do
  require_file "$relative_path"
done

for skill in "${supported_skills[@]}"; do
  require_file ".github/skills/$skill/SKILL.md"
done

while IFS= read -r skill_dir; do
  skill="${skill_dir##*/}"
  case "$skill" in
    code-review | codebase-design | diagnosing-bugs | domain-modeling | \
      grilling | prototype | tdd | wayfinder)
      ;;
    *)
      fail "unsupported skill directory: $skill"
      ;;
  esac
done < <(find "$root/.github/skills" -mindepth 1 -maxdepth 1 -type d | sort)

require_text \
  ".github/agents/clinic-stakeholder.agent.md" \
  "docs/workshop/clinic-stakeholder-knowledge.md"
require_frontmatter_line \
  ".github/agents/clinic-stakeholder.agent.md" \
  "name: Clinic Stakeholder"
require_frontmatter_line \
  ".github/agents/clinic-stakeholder.agent.md" \
  "description: Clarifies known Clinic Assistant facts, available preferences, and explicit uncertainty without making product decisions."
require_frontmatter_line \
  ".github/agents/clinic-stakeholder.agent.md" \
  'tools: ["read", "search"]'
require_frontmatter_line \
  ".github/agents/clinic-stakeholder.agent.md" \
  "disable-model-invocation: true"
require_contract \
  ".github/agents/clinic-stakeholder.agent.md" \
  "Do not choose the Driver's bounded slice"
require_contract \
  ".github/agents/clinic-stakeholder.agent.md" \
  "Explicit unknowns"

stakeholder_agent_contracts=(
  "Do not make consequential product decisions."
  "Do not cross the Commitment Gate."
  "Do not authorize Engineering Agent scope."
  "Do not manufacture certainty."
  "Do not infer an authoritative product answer from general model knowledge or observed PetClinic implementation details."
  "Return unresolved decisions to the human."
)
for contract in "${stakeholder_agent_contracts[@]}"; do
  require_contract ".github/agents/clinic-stakeholder.agent.md" "$contract"
done

require_contract_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts"
require_contract_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Available preferences"
require_contract_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Explicit unknowns"
require_contract_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "PetClinic staff need a chatbot that helps them answer questions about owners, pets, Visits, and veterinarians. Add a Clinic Assistant to the existing application."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- The chatbot is staff-facing and read-only."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- The Clinic Assistant must never claim to change PetClinic data."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- Answers must come only from retrieved PetClinic records."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- The chatbot must admit when records are absent or a request is unsupported."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- The chatbot must not provide veterinary diagnosis or treatment advice."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- The capability families are owner and pet lookup, Visit summaries, and veterinarian specialties."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- When multiple records match, the chatbot presents candidates and asks a clarifying question."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- The chatbot must not guess identity."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- Staff need an accessible chat option."
require_fixed_fact \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "- Keep a concise, visible activity trace of tool calls and their outcomes."

stakeholder_knowledge_contracts=(
  "- Prefer the smallest evidence-producing vertical slice."
  "- Prefer comparable engineering evidence over identical implementations."
  "- The exact UI surface and navigation treatment are unresolved."
  "- The first capability family is unresolved."
  "- Exact wording, visual design, and conversational tone are unresolved."
  "- The bounded assumptions accepted at the Commitment Gate are unresolved until the human records them."
  "- Production authentication, authorization, privacy controls, auditing, prompt-injection hardening, production observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved."
  "Unresolved or out-of-slice items must not become invented requirements."
)
for contract in "${stakeholder_knowledge_contracts[@]}"; do
  require_contract_line \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    "$contract"
done

require_text ".github/agents/evidence-coach.agent.md" "commit SHA"
require_text ".github/agents/evidence-coach.agent.md" "does not approve"
require_text \
  ".github/agents/evidence-coach.agent.md" \
  "disable-model-invocation: true"

require_contract_line \
  "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
  "## Known fact"
require_contract_line \
  "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
  "## Unknown"
require_contract_line \
  "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
  "## Human decision"
require_contract_line \
  "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
  "**Expected behavior:** No. The Clinic Assistant is read-only. The stakeholder must not authorize or suggest a write implementation."
require_contract_line \
  "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
  "**Expected behavior:** The exact UI and navigation are unresolved. Explain relevant consequences if supported by the named Reference Challenge, then return the decision to the Driver."
require_contract_line \
  "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
  "**Expected behavior:** The stakeholder may list owner and pet lookup, Visit summaries, and veterinarian specialties. It must not choose the Driver's bounded slice or claim that the Commitment Gate has passed."

require_contract "AGENTS.md" "The human owns consequential decisions"
require_contract "AGENTS.md" "Orient → Clarify → Shape → Execute → Verify → Learn"
require_contract ".github/copilot-instructions.md" "Work Contract"
require_contract ".github/copilot-instructions.md" "Commitment Gate"
require_contract ".github/copilot-instructions.md" "Acceptance Gate"
require_contract ".github/copilot-instructions.md" "Learning Gate"
require_frontmatter_line \
  ".github/instructions/repository-maintenance.instructions.md" \
  "applyTo: \".github/skills/**,.github/agents/**,.github/instructions/**,docs/agents/**,docs/superpowers/**,CONTEXT.md\""

echo "Copilot assets are structurally valid"
