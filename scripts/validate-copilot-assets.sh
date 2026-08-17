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
require_text \
  ".github/agents/clinic-stakeholder.agent.md" \
  "disable-model-invocation: true"
require_text ".github/agents/evidence-coach.agent.md" "commit SHA"
require_text ".github/agents/evidence-coach.agent.md" "does not approve"
require_text \
  ".github/agents/evidence-coach.agent.md" \
  "disable-model-invocation: true"

require_contract "AGENTS.md" "The human owns consequential decisions"
require_contract "AGENTS.md" "Orient → Clarify → Shape → Execute → Verify → Learn"
require_contract ".github/copilot-instructions.md" "Work Contract"
require_contract ".github/copilot-instructions.md" "Commitment Gate"
require_contract ".github/copilot-instructions.md" "Acceptance Gate"
require_contract ".github/copilot-instructions.md" "Learning Gate"
require_contract \
  ".github/instructions/repository-maintenance.instructions.md" \
  "applyTo:"

echo "Copilot assets are structurally valid"
