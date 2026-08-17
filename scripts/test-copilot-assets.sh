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
    $'docs/workshop/clinic-stakeholder-knowledge.md\ndisable-model-invocation: true'
  write_file \
    ".github/agents/evidence-coach.agent.md" \
    $'commit SHA\ndoes not approve\ndisable-model-invocation: true'
  write_file \
    "docs/workshop/clinic-stakeholder-knowledge.md" \
    "Clinic stakeholder knowledge"
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
write_file \
  ".github/agents/clinic-stakeholder.agent.md" \
  $'docs/workshop/clinic-stakeholder-knowledge.md\ndisable-model-invocation: true'

sed -i '/Acceptance Gate/d' "$fixture/.github/copilot-instructions.md"
expect_failure \
  ".github/copilot-instructions.md does not contain required contract: Acceptance Gate"
copy_guidance ".github/copilot-instructions.md"

mkdir -p "$fixture/.github/skills/extra-skill"
expect_failure "unsupported skill directory: extra-skill"

echo "Copilot asset validator tests passed"
