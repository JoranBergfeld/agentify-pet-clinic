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

require_section_line() {
  local relative_path="$1"
  local heading="$2"
  local contract_kind="$3"
  local expected="$4"

  awk -v heading="$heading" -v expected="$expected" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit 1 }
    in_section && $0 == expected { found = 1; exit }
    END { if (!found) exit 1 }
  ' "$root/$relative_path" ||
    fail "$relative_path does not contain required $contract_kind: $expected"
}

require_frontmatter_contract() {
  local relative_path="$1"
  local key="$2"
  local expected="$3"

  awk -v key="$key" -v expected="$expected" '
    function escaped_key_like(candidate, key, first, last, inner, i, key_index,
                              escape_kind, escape_length, escape_digits, ch) {
      first = substr(candidate, 1, 1)
      last = substr(candidate, length(candidate), 1)
      if ((first == "\"" && last == "\"") ||
          (first == "\047" && last == "\047")) {
        inner = substr(candidate, 2, length(candidate) - 2)
      } else {
        inner = candidate
      }

      if (inner == key && inner != candidate) return 1
      if (index(inner, "\\") == 0) return 0

      i = 1
      key_index = 1
      while (i <= length(inner) && key_index <= length(key)) {
        ch = substr(inner, i, 1)
        if (ch != "\\") {
          if (ch != substr(key, key_index, 1)) return 0
          i += 1
          key_index += 1
          continue
        }

        escape_kind = substr(inner, i + 1, 1)
        escape_length = escape_kind == "x" ? 2 :
                        escape_kind == "u" ? 4 :
                        escape_kind == "U" ? 8 : 0
        if (escape_length == 0) {
          i += 2
        } else {
          escape_digits = substr(inner, i + 2, escape_length)
          if (length(escape_digits) != escape_length ||
              escape_digits !~ /^[[:xdigit:]]+$/) return 0
          i += escape_length + 2
        }
        key_index += 1
      }

      return i > length(inner) && key_index > length(key)
    }

    NR == 1 {
      if ($0 != "---") exit 1
      next
    }
    $0 == "---" {
      closed = 1
      exit
    }
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      separator = index(line, ":")
      if (separator > 0) {
        candidate = substr(line, 1, separator - 1)
        sub(/[[:space:]]*$/, "", candidate)
        if (escaped_key_like(candidate, key)) noncanonical = 1
        if (candidate == key) {
          count += 1
          if ($0 == expected) exact += 1
        }
      }
    }
    END {
      if (!closed || noncanonical || count != 1 || exact != 1) exit 1
    }
  ' "$root/$relative_path" ||
    fail "$relative_path does not contain required contract: $expected"
}

reject_contract_line() {
  local relative_path="$1"
  local prohibited="$2"

  if grep -Fq -- "$prohibited" "$root/$relative_path"; then
    fail "$relative_path contains prohibited contract: $prohibited"
  fi
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

require_frontmatter_contract \
  ".github/agents/clinic-stakeholder.agent.md" \
  "name" \
  "name: Clinic Stakeholder"
require_frontmatter_contract \
  ".github/agents/clinic-stakeholder.agent.md" \
  "description" \
  "description: Clarifies known Clinic Assistant facts, available preferences, and explicit uncertainty without making product decisions."
require_frontmatter_contract \
  ".github/agents/clinic-stakeholder.agent.md" \
  "tools" \
  'tools: ["read", "search"]'
require_frontmatter_contract \
  ".github/agents/clinic-stakeholder.agent.md" \
  "disable-model-invocation" \
  "disable-model-invocation: true"
require_contract \
  ".github/agents/clinic-stakeholder.agent.md" \
  "Do not choose the Driver's bounded slice"
stakeholder_grounding_contracts=(
  "Read [the canonical Clinic Stakeholder knowledge](../../docs/workshop/clinic-stakeholder-knowledge.md) before answering. Answer only from that knowledge and the named Reference Challenge context provided for the current request."
  "Separate **Fixed facts**, **Available preferences**, and **Explicit unknowns** in each answer. Link to the relevant canonical knowledge sections when useful."
  "If the canonical knowledge or named Reference Challenge context is missing, inaccessible, contradictory, or silent on the question, explicitly say that the stakeholder does not know."
  "Do not infer an authoritative product answer from general model knowledge or observed PetClinic implementation details."
)
for contract in "${stakeholder_grounding_contracts[@]}"; do
  require_contract_line ".github/agents/clinic-stakeholder.agent.md" "$contract"
done

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

stakeholder_prohibited_contracts=(
  "You may choose the Driver's bounded slice."
  "You may make consequential product decisions."
  "You may cross the Commitment Gate."
  "You may authorize Engineering Agent scope."
  "You may manufacture certainty."
  "You may infer an authoritative product answer from general model knowledge or observed PetClinic implementation details."
  "You may invent requirements."
  "Choose the Driver's bounded slice"
  "If context is unavailable, provide a best-effort answer."
  "Use general model knowledge or observed implementation details when helpful."
  "Resolve decisions for the human."
)
for prohibited in "${stakeholder_prohibited_contracts[@]}"; do
  reject_contract_line ".github/agents/clinic-stakeholder.agent.md" "$prohibited"
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
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- The chatbot is staff-facing and read-only."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- The Clinic Assistant must never claim to change PetClinic data."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- Answers must come only from retrieved PetClinic records."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- The chatbot must admit when records are absent or a request is unsupported."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- The chatbot must not provide veterinary diagnosis or treatment advice."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- The capability families are owner and pet lookup, Visit summaries, and veterinarian specialties."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- When multiple records match, the chatbot presents candidates and asks a clarifying question."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- The chatbot must not guess identity."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
  "- Staff need an accessible chat option."
require_section_line \
  "docs/workshop/clinic-stakeholder-knowledge.md" \
  "## Fixed facts" \
  "fixed fact" \
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

stakeholder_knowledge_prohibited_contracts=(
  "- Use a dedicated chat page."
  "- Implement owner and pet lookup first."
  "- Use concise wording, a minimal visual design, and a formal conversational tone."
)
for prohibited in "${stakeholder_knowledge_prohibited_contracts[@]}"; do
  reject_contract_line \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    "$prohibited"
done

available_preferences=(
  "- Prefer the smallest evidence-producing vertical slice."
  "- Prefer comparable engineering evidence over identical implementations."
)
for preference in "${available_preferences[@]}"; do
  require_section_line \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    "## Available preferences" \
    "available preference" \
    "$preference"
done

explicit_unknowns=(
  "- The exact UI surface and navigation treatment are unresolved."
  "- The first capability family is unresolved."
  "- Exact wording, visual design, and conversational tone are unresolved."
  "- The bounded assumptions accepted at the Commitment Gate are unresolved until the human records them."
  "- Production authentication, authorization, privacy controls, auditing, prompt-injection hardening, production observability, scheduling, writes, and persistent conversations are outside the workshop slice and unresolved."
  "Unresolved or out-of-slice items must not become invented requirements."
)
for explicit_unknown in "${explicit_unknowns[@]}"; do
  require_section_line \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    "## Explicit unknowns" \
    "explicit unknown" \
    "$explicit_unknown"
done

require_frontmatter_contract \
  ".github/agents/evidence-coach.agent.md" \
  "name" \
  "name: Evidence Coach"
require_frontmatter_contract \
  ".github/agents/evidence-coach.agent.md" \
  "description" \
  "description: Drafts non-authoritative, revision-specific Evidence Lens observations for committed Stage Cards."
require_frontmatter_contract \
  ".github/agents/evidence-coach.agent.md" \
  "tools" \
  'tools: ["read", "search", "execute"]'
require_frontmatter_contract \
  ".github/agents/evidence-coach.agent.md" \
  "disable-model-invocation" \
  "disable-model-invocation: true"

evidence_coach_contracts=(
  "Peer Reciprocal Evidence Review remains the primary independent challenge."
  "Only review committed, Review-ready Stage Cards."
  "Require one or more Stage Card paths and a commit SHA. If either is missing or invalid, request the missing input and produce no review."
  'Verify the named revision and read each committed card with `git show <sha>:<path>`.'
  "Never substitute working-tree content, inspect uncommitted state, or continue if the revision or path is unavailable."
  'Return a clearly labelled `Agent-generated draft — human review required` that names every reviewed Stage Card and the commit SHA.'
  "- **Intent**"
  "- **Decisions**"
  "- **Evidence**"
  "- **Gaps**"
  "- **Next inspection point**"
  "Use the blueprint Evidence Lenses and label each revision-specific observation **Visible**, **Fragile**, or **Missing**."
  "The Evidence Coach does not approve, request changes, certify completion, make an Acceptance judgment, prescribe the next implementation move, replace the human Auditor, or post the draft to GitHub."
  "If required input or committed evidence is missing, request it and produce no review."
)
for contract in "${evidence_coach_contracts[@]}"; do
  require_contract_line \
    ".github/agents/evidence-coach.agent.md" \
    "$contract"
done

evidence_coach_prohibited_contracts=(
  "The Evidence Coach may approve."
  "The Evidence Coach may request changes."
  "The Evidence Coach may certify completion."
  "The Evidence Coach may make an Acceptance judgment."
  "The Evidence Coach may prescribe the next implementation move."
  "The Evidence Coach may replace the human Auditor."
  "The Evidence Coach may post the draft to GitHub."
  "The Evidence Coach may inspect uncommitted state."
  "The Evidence Coach may substitute working-tree content."
)
for prohibited in "${evidence_coach_prohibited_contracts[@]}"; do
  reject_contract_line \
    ".github/agents/evidence-coach.agent.md" \
    "$prohibited"
done

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

evidence_coach_scenario_contracts=(
  "## Missing input"
  "**Expected behavior:** Ask for one or more Stage Card paths and a commit SHA, then produce no review."
  "## Committed review"
  '**Request:** Review `workshop/stage-cards/verify.md` at `abc1234`.'
  '**Expected behavior:** Verify the revision, read the committed card with `git show abc1234:workshop/stage-cards/verify.md`, name the card and SHA, return the exact label `Agent-generated draft — human review required`, use all five headings Intent, Decisions, Evidence, Gaps, and Next inspection point, and label revision-specific Evidence Lens observations Visible, Fragile, or Missing.'
  "## Uncommitted evidence"
  "**Expected behavior:** Refuse to inspect or substitute working-tree content, request a committed revision, and produce no review."
  "## Authority boundary"
  "**Expected behavior:** Refuse approval, certification, an Acceptance judgment, prescription of the next implementation move, replacement of the human Auditor, and posting to GitHub."
)
for contract in "${evidence_coach_scenario_contracts[@]}"; do
  require_contract_line \
    "scripts/fixtures/copilot-assets/evidence-coach-scenarios.md" \
    "$contract"
done

require_contract "AGENTS.md" "The human owns consequential decisions"
require_contract "AGENTS.md" "Orient → Clarify → Shape → Execute → Verify → Learn"
require_contract ".github/copilot-instructions.md" "Work Contract"
require_contract ".github/copilot-instructions.md" "Commitment Gate"
require_contract ".github/copilot-instructions.md" "Acceptance Gate"
require_contract ".github/copilot-instructions.md" "Learning Gate"
require_frontmatter_contract \
  ".github/instructions/repository-maintenance.instructions.md" \
  "applyTo" \
  "applyTo: \".github/skills/**,.github/agents/**,.github/instructions/**,docs/agents/**,docs/superpowers/**,CONTEXT.md\""

echo "Copilot assets are structurally valid"
