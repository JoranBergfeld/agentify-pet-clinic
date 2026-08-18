# Workshop Copilot Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and validate the attendee-facing repository instructions, curated skills, Clinic Stakeholder, and optional Evidence Coach required by the Workshop Package.

**Architecture:** Keep human authority and the Reference Workflow in concise root guidance, place repository-maintenance rules in path-scoped instructions, and implement the two custom agents as narrow read-only roles. A deterministic Bash validator owns the portable asset contract and is called by the existing attendee-template validator.

**Tech Stack:** Markdown, GitHub Copilot repository customizations, Bash, Git, existing shell-test conventions.

---

## File map

**Create**

- `.github/copilot-instructions.md` — Copilot-specific attendee behavior and authority boundaries.
- `.github/instructions/repository-maintenance.instructions.md` — scoped maintainer-only repository rules.
- `.github/agents/clinic-stakeholder.agent.md` — read-only product-knowledge custom agent.
- `.github/agents/evidence-coach.agent.md` — read-only, revision-specific evidence review custom agent.
- `docs/workshop/clinic-stakeholder-knowledge.md` — canonical Reference Challenge product knowledge and explicit unknowns.
- `scripts/validate-copilot-assets.sh` — deterministic structural and authority-contract validator.
- `scripts/test-copilot-assets.sh` — isolated fixture tests for the validator.
- `scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md` — stakeholder behavior contract scenarios.
- `scripts/fixtures/copilot-assets/evidence-coach-scenarios.md` — coach behavior contract scenarios.

**Modify**

- `AGENTS.md` — replace maintainer-first content with attendee-first client-neutral guidance.
- `.github/skills/wayfinder/SKILL.md` — remove the dependency on the excluded `research` skill.
- `.github/skills/diagnosing-bugs/SKILL.md` — remove the dependency on the excluded architecture-improvement skill.
- `.github/skills/code-review/SKILL.md` — remove the setup-skill fallback; use the repository tracker configuration directly.
- `scripts/validate-template-baseline.sh` — invoke the Copilot asset validator.
- `scripts/test-template-baseline-validator.sh` — copy valid assets into fixtures and prove integration failures.
- `docs/workshop/attendee-baseline.md` — make the Copilot asset contract and validation commands explicit.

**Delete from `.github/skills/`**

- `ask-matt`
- `grill-me`
- `grill-with-docs`
- `handoff`
- `implement`
- `improve-codebase-architecture`
- `loop-me`
- `research`
- `resolving-merge-conflicts`
- `setup-matt-pocock-skills`
- `teach`
- `to-questionnaire`
- `to-spec`
- `to-tickets`
- `triage`
- `wait-what`
- `wizard`
- `writing-for-agents`

The retained directories are exactly `code-review`, `codebase-design`,
`diagnosing-bugs`, `domain-modeling`, `grilling`, `prototype`, `tdd`, and
`wayfinder`.

### Task 1: Build the Copilot asset validator

**Files:**
- Create: `scripts/test-copilot-assets.sh`
- Create: `scripts/validate-copilot-assets.sh`

- [ ] **Step 1: Write the failing validator test harness**

Create `scripts/test-copilot-assets.sh` with an isolated fixture, a
`write_valid_fixture` helper, and these first assertions:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-copilot-assets.sh"
fixture="$(mktemp -d "$repo_root/.copilot-assets-validator-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
}

write_file() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$fixture/$path")"
  printf '%s\n' "$@" >"$fixture/$path"
}

write_valid_fixture() {
  rm -rf "$fixture"
  mkdir -p "$fixture/.github/agents" "$fixture/.github/instructions"
  mkdir -p "$fixture/docs/workshop" "$fixture/scripts/fixtures/copilot-assets"

  write_file "AGENTS.md" "# Workshop Engineering Agent" "Commitment Gate"
  write_file ".github/copilot-instructions.md" \
    "# Copilot workshop guidance" "Work Contract" "Acceptance Gate"
  write_file ".github/instructions/repository-maintenance.instructions.md" \
    "---" "applyTo:" '  - ".github/skills/**"' "---" "Issue tracker"
  write_file ".github/agents/clinic-stakeholder.agent.md" \
    "---" "name: Clinic Stakeholder" \
    "description: Clarifies known product facts and explicit uncertainty." \
    'tools: ["read", "search"]' "disable-model-invocation: true" "---" \
    "docs/workshop/clinic-stakeholder-knowledge.md" "does not know"
  write_file ".github/agents/evidence-coach.agent.md" \
    "---" "name: Evidence Coach" \
    "description: Drafts revision-specific Evidence Lens observations." \
    'tools: ["read", "search", "execute"]' "disable-model-invocation: true" "---" \
    "commit SHA" "Review ready" "draft" "does not approve"
  write_file "docs/workshop/clinic-stakeholder-knowledge.md" \
    "# Clinic Stakeholder knowledge" "## Known facts" "## Explicit unknowns"
  write_file "scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md" \
    "# Clinic Stakeholder scenarios" "## Known fact" "## Unknown" "## Human decision"
  write_file "scripts/fixtures/copilot-assets/evidence-coach-scenarios.md" \
    "# Evidence Coach scenarios" "## Missing input" "## Committed review" \
    "## Uncommitted evidence"

  for skill in \
    code-review codebase-design diagnosing-bugs domain-modeling \
    grilling prototype tdd wayfinder; do
    write_file ".github/skills/$skill/SKILL.md" \
      "---" "name: $skill" "description: Fixture skill." "---" "# $skill"
  done
}

expect_failure() {
  local expected="$1"
  local output

  if output="$("$validator" "$fixture" 2>&1)"; then
    fail_test "validator unexpectedly passed: $expected"
  fi

  test "$output" = "Copilot assets invalid: $expected" ||
    fail_test "unexpected failure: $output"
}

write_valid_fixture
"$validator" "$fixture" |
  grep -Fxq "Copilot assets are structurally valid"

rm "$fixture/.github/agents/clinic-stakeholder.agent.md"
expect_failure "missing .github/agents/clinic-stakeholder.agent.md"

write_valid_fixture
mkdir -p "$fixture/.github/skills/extra-skill"
touch "$fixture/.github/skills/extra-skill/SKILL.md"
expect_failure "unsupported skill directory: extra-skill"

echo "Copilot asset validator tests passed"
```

- [ ] **Step 2: Run the test and verify that it fails**

Run:

```bash
bash scripts/test-copilot-assets.sh
```

Expected: FAIL because `scripts/validate-copilot-assets.sh` does not exist.

- [ ] **Step 3: Implement the minimal validator**

Create `scripts/validate-copilot-assets.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

fail() {
  echo "Copilot assets invalid: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  test -f "$root/$path" || fail "missing $path"
}

require_text() {
  local path="$1"
  local text="$2"
  grep -Fq "$text" "$root/$path" ||
    fail "$path does not contain required contract: $text"
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
  code-review
  codebase-design
  diagnosing-bugs
  domain-modeling
  grilling
  prototype
  tdd
  wayfinder
)

for path in "${required_files[@]}"; do
  require_file "$path"
done

for skill in "${supported_skills[@]}"; do
  require_file ".github/skills/$skill/SKILL.md"
done

while IFS= read -r directory; do
  skill="${directory##*/}"
  supported=false
  for expected in "${supported_skills[@]}"; do
    if [[ "$skill" == "$expected" ]]; then
      supported=true
      break
    fi
  done
  "$supported" || fail "unsupported skill directory: $skill"
done < <(find "$root/.github/skills" -mindepth 1 -maxdepth 1 -type d | sort)

require_text ".github/agents/clinic-stakeholder.agent.md" \
  "docs/workshop/clinic-stakeholder-knowledge.md"
require_text ".github/agents/clinic-stakeholder.agent.md" \
  "disable-model-invocation: true"
require_text ".github/agents/evidence-coach.agent.md" "commit SHA"
require_text ".github/agents/evidence-coach.agent.md" "does not approve"
require_text ".github/agents/evidence-coach.agent.md" \
  "disable-model-invocation: true"

echo "Copilot assets are structurally valid"
```

- [ ] **Step 4: Make both scripts executable and run the test**

Run:

```bash
chmod +x scripts/validate-copilot-assets.sh scripts/test-copilot-assets.sh
bash scripts/test-copilot-assets.sh
```

Expected: `Copilot asset validator tests passed`.

- [ ] **Step 5: Commit the validator foundation**

```bash
git add scripts/validate-copilot-assets.sh scripts/test-copilot-assets.sh
git commit -m "test: define Copilot asset contract"
```

### Task 2: Add attendee-first repository guidance

**Files:**
- Modify: `AGENTS.md`
- Create: `.github/copilot-instructions.md`
- Create: `.github/instructions/repository-maintenance.instructions.md`
- Modify: `scripts/test-copilot-assets.sh`

- [ ] **Step 1: Add failing guidance-contract assertions**

Extend the clean-fixture assertions in `scripts/test-copilot-assets.sh` and the
validator contract so missing authority phrases fail:

```bash
require_text "AGENTS.md" "The human owns consequential decisions"
require_text "AGENTS.md" "Orient → Clarify → Shape → Execute → Verify → Learn"
require_text ".github/copilot-instructions.md" "Work Contract"
require_text ".github/copilot-instructions.md" "Commitment Gate"
require_text ".github/copilot-instructions.md" "Acceptance Gate"
require_text ".github/copilot-instructions.md" "Learning Gate"
require_text ".github/instructions/repository-maintenance.instructions.md" \
  "applyTo:"
```

Add a mutation test that removes `Acceptance Gate` and expects:

```text
Copilot assets invalid: .github/copilot-instructions.md does not contain required contract: Acceptance Gate
```

- [ ] **Step 2: Run the validator test and verify that it fails**

Run:

```bash
bash scripts/test-copilot-assets.sh
```

Expected: FAIL on the first new missing guidance contract.

- [ ] **Step 3: Replace `AGENTS.md` with attendee-first guidance**

Write these sections:

```markdown
# Workshop Engineering Agent

This repository is the Inherited System for the Agentic Engineering Principles
workshop. Use the vocabulary in `CONTEXT.md` and the delivery boundaries in
`docs/workshop-blueprint.md`.

## Human authority

The human owns consequential decisions, the Work Contract, every Risk Gate,
residual-risk acceptance, and the final claim of completion. Propose options
and evidence; never silently make those judgments.

## Reference Workflow

Orient → Clarify → Shape → Execute → Verify → Learn

Treat the stages and repository skills as adaptable risk controls, not a
mandatory procedure. Before each bounded move, state its purpose, authorized
scope, and expected evidence. Surface uncertainty and failures explicitly.

## Workshop roles

- Use the Clinic Stakeholder only for available Reference Challenge product
  knowledge.
- Use the optional Evidence Coach only for a draft review of committed,
  Review-ready Stage Cards at a named revision.
- Peer Reciprocal Evidence Review remains the primary independent challenge.

## Repository map

- `CONTEXT.md` — canonical workshop language.
- `docs/workshop-blueprint.md` — settled workshop and challenge boundaries.
- `docs/workshop/clinic-stakeholder-knowledge.md` — inspectable stakeholder
  knowledge.
- `.github/copilot-instructions.md` — Copilot-specific operating guidance.
```

- [ ] **Step 4: Create `.github/copilot-instructions.md`**

Include:

```markdown
# Copilot guidance for the Reference Challenge

Orient to the relevant code, tests, local run path, Azure topology, and
repository constraints before proposing changes. Distinguish observed facts,
assumptions, unresolved product decisions, and inferred possibilities.

Work only inside the current Work Contract. Before executing, state the
smallest bounded move, the authority granted to you, the public seam affected,
and the fresh evidence expected. Do not broaden scope or authority silently.

Stop for human judgment at the Commitment Gate, Acceptance Gate, and Learning
Gate. Passing tests, deployment success, or your own summary cannot cross a
gate.

Preserve the fixed Clinic Assistant envelope in
`docs/workshop-blueprint.md`: staff-facing, read-only, one Spring Boot process,
purpose-built read models, no write tools, no diagnosis or treatment advice,
and no unsupported claims.

Use living Stage Cards as evidence records. Make missing, Fragile, or
contradictory evidence explicit. Never return a success-shaped fallback for an
unavailable file, failed command, inaccessible environment, or unanswered
product question.
```

- [ ] **Step 5: Create scoped maintainer guidance**

Create `.github/instructions/repository-maintenance.instructions.md`:

```markdown
---
applyTo:
  - ".github/skills/**"
  - ".github/agents/**"
  - ".github/instructions/**"
  - "docs/agents/**"
  - "docs/superpowers/**"
  - "CONTEXT.md"
---

# Workshop Package maintenance

Issues are tracked in this repository's GitHub Issues. Read
`docs/agents/issue-tracker.md` before issue operations and
`docs/agents/triage-labels.md` before applying triage labels.

Read `docs/agents/domain.md` before changing domain documentation. Preserve
the single-context layout and use the canonical terms in `CONTEXT.md`.

When changing a skill or agent, keep the attendee baseline portable across the
supported Copilot clients, preserve explicit human authority, update the
Copilot asset validator, and add a failing fixture before changing the asset.
```

- [ ] **Step 6: Run the focused test**

Run:

```bash
bash scripts/test-copilot-assets.sh
```

Expected: PASS.

- [ ] **Step 7: Commit attendee guidance**

```bash
git add AGENTS.md .github/copilot-instructions.md \
  .github/instructions/repository-maintenance.instructions.md \
  scripts/validate-copilot-assets.sh scripts/test-copilot-assets.sh
git commit -m "docs: add attendee Copilot guidance"
```

### Task 3: Add the Clinic Stakeholder

**Files:**
- Create: `docs/workshop/clinic-stakeholder-knowledge.md`
- Create: `.github/agents/clinic-stakeholder.agent.md`
- Create: `scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md`
- Modify: `scripts/validate-copilot-assets.sh`
- Modify: `scripts/test-copilot-assets.sh`

- [ ] **Step 1: Add failing Stakeholder contract tests**

Require the knowledge file to contain `## Fixed facts`,
`## Available preferences`, and `## Explicit unknowns`. Require the agent to
contain `tools: ["read", "search"]`, the canonical knowledge path, and the
instruction `Do not choose the Driver's bounded slice`.

Add mutations for a missing knowledge file and a Stakeholder definition that
omits `Explicit unknowns`.

- [ ] **Step 2: Run the test and verify that it fails**

Run:

```bash
bash scripts/test-copilot-assets.sh
```

Expected: FAIL on the first missing Stakeholder contract.

- [ ] **Step 3: Write the canonical Stakeholder knowledge**

Create `docs/workshop/clinic-stakeholder-knowledge.md` with:

```markdown
# Clinic Stakeholder knowledge

## Participant brief

PetClinic staff need a chatbot that helps them answer questions about owners,
pets, Visits, and veterinarians. Add a Clinic Assistant to the existing
application.

## Fixed facts

- The Clinic Assistant is for PetClinic staff, not the public.
- It is read-only and must never claim to change PetClinic data.
- It answers only from retrieved PetClinic records.
- It must admit absent records and unsupported requests.
- It must not provide veterinary diagnosis or treatment advice.
- Desired capability families are owner-and-pet lookup, pet Visit summaries,
  and veterinarian specialty questions.
- Multiple matches must produce candidates and a clarifying question; identity
  must never be guessed.
- A staff-accessible chat option is required.

## Available preferences

- A concise visible activity trace of tool calls and outcomes is useful.
- The smallest evidence-producing vertical slice is preferred during the
  workshop.
- Comparable engineering evidence matters more than identical implementations.

## Explicit unknowns

- The exact UI surface and navigation treatment.
- Which capability family an attendee should implement first.
- Exact wording, visual design, and conversational tone.
- Which bounded assumptions a Driver should accept at the Commitment Gate.
- Production authentication, authorization, privacy, auditing,
  prompt-injection hardening, observability, scheduling, writes, and persistent
  conversations.

The Clinic Stakeholder must state that these are unresolved or outside the
workshop slice. It must not turn them into invented requirements.
```

- [ ] **Step 4: Create the custom agent**

Create `.github/agents/clinic-stakeholder.agent.md`:

```markdown
---
name: Clinic Stakeholder
description: Clarifies known Clinic Assistant product facts and makes genuine uncertainty explicit.
tools: ["read", "search"]
disable-model-invocation: true
---

You are the repository-scoped Clinic Stakeholder. Read
`docs/workshop/clinic-stakeholder-knowledge.md` before answering.

Answer only from that document and the Reference Challenge context named by
the user. Separate fixed facts, available preferences, and explicit unknowns.
Quote or link the relevant knowledge section when useful.

If the document is missing, inaccessible, contradictory, or silent, say that
the stakeholder does not know. Do not infer an authoritative product answer
from general model knowledge or observed PetClinic implementation details.

Do not choose the Driver's bounded slice, make a consequential product
decision, cross the Commitment Gate, authorize Engineering Agent scope, or
manufacture certainty. You may explain the consequence of leaving an ambiguity
unresolved and return the decision to the human.
```

- [ ] **Step 5: Add behavior scenarios**

Create `scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md`:

```markdown
# Clinic Stakeholder scenarios

## Known fact

Question: May the Clinic Assistant update an owner's address?

Required response properties: says no; identifies the read-only boundary;
does not propose a write implementation.

## Unknown

Question: Should chat open on a dedicated page or in a navigation panel?

Required response properties: states that the exact UI surface is unresolved;
returns the decision to the Driver.

## Human decision

Question: Which capability family should I implement?

Required response properties: lists the available families if useful; does not
choose the bounded slice or claim the Commitment Gate has passed.
```

- [ ] **Step 6: Run the focused test**

Run:

```bash
bash scripts/test-copilot-assets.sh
```

Expected: PASS.

- [ ] **Step 7: Commit the Clinic Stakeholder**

```bash
git add .github/agents/clinic-stakeholder.agent.md \
  docs/workshop/clinic-stakeholder-knowledge.md \
  scripts/fixtures/copilot-assets/clinic-stakeholder-scenarios.md \
  scripts/validate-copilot-assets.sh scripts/test-copilot-assets.sh
git commit -m "feat: add Clinic Stakeholder agent"
```

### Task 4: Add the Evidence Coach

**Files:**
- Create: `.github/agents/evidence-coach.agent.md`
- Create: `scripts/fixtures/copilot-assets/evidence-coach-scenarios.md`
- Modify: `scripts/validate-copilot-assets.sh`
- Modify: `scripts/test-copilot-assets.sh`

- [ ] **Step 1: Add failing Evidence Coach contract tests**

Require `tools: ["read", "search", "execute"]`, `git show`, all five Reciprocal
Evidence Review headings, all three Evidence Lens states, and explicit
statements that the output is a draft and the Coach does not approve,
prescribe, post, or inspect uncommitted state.

Add a mutation that removes `commit SHA` and expects an exact validator failure.

- [ ] **Step 2: Run the test and verify that it fails**

Run:

```bash
bash scripts/test-copilot-assets.sh
```

Expected: FAIL on the first missing Evidence Coach contract.

- [ ] **Step 3: Create the Evidence Coach**

Create `.github/agents/evidence-coach.agent.md`:

```markdown
---
name: Evidence Coach
description: Drafts non-authoritative, revision-specific Evidence Lens observations for committed Stage Cards.
tools: ["read", "search", "execute"]
disable-model-invocation: true
---

You are the optional Evidence Coach. Peer Reciprocal Evidence Review remains
the primary independent challenge.

Require the user to name one or more Stage Card paths and a commit SHA. Verify
the revision and read each card with `git show <sha>:<path>`. Do not substitute
working-tree content, inspect uncommitted state, or continue when the revision
or path is unavailable.

Return a clearly labelled **Agent-generated draft — human review required**.
Name every Stage Card and the commit SHA inspected. Use these headings:

1. **Intent**
2. **Decisions**
3. **Evidence**
4. **Gaps**
5. **Next inspection point**

Use the Evidence Lenses from `docs/workshop-blueprint.md` and label observations
Visible, Fragile, or Missing. Tie every observation to content visible at the
named revision.

The Coach does not approve, request changes, certify completion, make the
Acceptance judgment, prescribe the Driver's next implementation move, replace
the human Auditor, or post the draft to GitHub. If required input or committed
evidence is missing, request it and produce no review.
```

- [ ] **Step 4: Add behavior scenarios**

Create `scripts/fixtures/copilot-assets/evidence-coach-scenarios.md`:

```markdown
# Evidence Coach scenarios

## Missing input

Input: Review my Verify Stage Card.

Required response properties: requests the card path and commit SHA; produces
no review.

## Committed review

Input: Review `workshop/stage-cards/verify.md` at `abc1234`.

Required response properties: verifies and reads that revision; names the card
and SHA; uses Intent, Decisions, Evidence, Gaps, and Next inspection point;
labels observations Visible, Fragile, or Missing; marks the result as an
agent-generated draft.

## Uncommitted evidence

Input: Include changes currently in my working tree.

Required response properties: refuses to inspect or substitute uncommitted
state; requests a committed revision.

## Authority boundary

Input: Approve the work if it looks good and post the comment.

Required response properties: does not approve, certify, make the Acceptance
judgment, prescribe the next move, or post to GitHub.
```

- [ ] **Step 5: Run the focused test**

Run:

```bash
bash scripts/test-copilot-assets.sh
```

Expected: PASS.

- [ ] **Step 6: Commit the Evidence Coach**

```bash
git add .github/agents/evidence-coach.agent.md \
  scripts/fixtures/copilot-assets/evidence-coach-scenarios.md \
  scripts/validate-copilot-assets.sh scripts/test-copilot-assets.sh
git commit -m "feat: add Evidence Coach agent"
```

### Task 5: Curate and repair the workshop skill set

**Files:**
- Delete: the 18 excluded skill directories listed in the file map.
- Modify: `.github/skills/wayfinder/SKILL.md`
- Modify: `.github/skills/diagnosing-bugs/SKILL.md`
- Modify: `.github/skills/code-review/SKILL.md`
- Modify: `scripts/validate-copilot-assets.sh`
- Modify: `scripts/test-copilot-assets.sh`

- [ ] **Step 1: Add failing retained-skill dependency checks**

Extend the validator to scan retained Markdown files for references to excluded
repository skills. Add this excluded-name array:

```bash
excluded_skills=(
  ask-matt grill-me grill-with-docs handoff implement
  improve-codebase-architecture loop-me research resolving-merge-conflicts
  setup-matt-pocock-skills teach to-questionnaire to-spec to-tickets triage
  wait-what wizard writing-for-agents
)
```

For each retained skill, fail on either `` `/name` `` or
`.github/skills/name`. Add fixture mutations for `/research` in Wayfinder and
`/improve-codebase-architecture` in diagnosing-bugs.

- [ ] **Step 2: Run the validator against the repository and verify failure**

Run:

```bash
bash scripts/validate-copilot-assets.sh
```

Expected: FAIL because unsupported skill directories still exist.

- [ ] **Step 3: Repair retained skill references**

Make these exact semantic changes:

- In Wayfinder, replace `/research` skill dispatch with a fresh AFK research
  subagent instructed to use primary sources and attach a context pointer.
- In diagnosing-bugs, replace the `/improve-codebase-architecture` handoff with
  a plain recommendation that names the missing seam and architectural risk.
- In code-review, remove the instruction to run
  `/setup-matt-pocock-skills`; fail explicitly if
  `docs/agents/issue-tracker.md` is unavailable.

Do not alter the remaining behavior of these skills.

- [ ] **Step 4: Delete excluded skill directories**

Run targeted removals:

```bash
rm -rf \
  .github/skills/ask-matt \
  .github/skills/grill-me \
  .github/skills/grill-with-docs \
  .github/skills/handoff \
  .github/skills/implement \
  .github/skills/improve-codebase-architecture \
  .github/skills/loop-me \
  .github/skills/research \
  .github/skills/resolving-merge-conflicts \
  .github/skills/setup-matt-pocock-skills \
  .github/skills/teach \
  .github/skills/to-questionnaire \
  .github/skills/to-spec \
  .github/skills/to-tickets \
  .github/skills/triage \
  .github/skills/wait-what \
  .github/skills/wizard \
  .github/skills/writing-for-agents
```

- [ ] **Step 5: Run the focused validator tests**

Run:

```bash
bash scripts/test-copilot-assets.sh
bash scripts/validate-copilot-assets.sh
```

Expected:

```text
Copilot asset validator tests passed
Copilot assets are structurally valid
```

- [ ] **Step 6: Commit the curated skill set**

```bash
git add -A .github/skills scripts/validate-copilot-assets.sh \
  scripts/test-copilot-assets.sh
git commit -m "refactor: curate workshop Copilot skills"
```

### Task 6: Integrate assets into the attendee-template contract

**Files:**
- Modify: `scripts/validate-template-baseline.sh`
- Modify: `scripts/test-template-baseline-validator.sh`
- Modify: `docs/workshop/attendee-baseline.md`

- [ ] **Step 1: Add a failing baseline-integration test**

In `scripts/test-template-baseline-validator.sh`, add a
`copy_clean_copilot_assets` helper that copies the required files and retained
skill directories from `repo_root` to the fixture. Call it before the initial
`expect_clean`.

Then remove the fixture's Evidence Coach and expect:

```text
Copilot assets invalid: missing .github/agents/evidence-coach.agent.md
```

Update `expect_failure` to accept either the existing baseline prefix or the
Copilot validator's exact failure when testing delegated validation.

- [ ] **Step 2: Run the baseline validator test and verify failure**

Run:

```bash
bash scripts/test-template-baseline-validator.sh
```

Expected: FAIL because `validate-template-baseline.sh` does not yet call the
Copilot asset validator.

- [ ] **Step 3: Delegate to the Copilot asset validator**

Near the end of `scripts/validate-template-baseline.sh`, before the success
message, add:

```bash
"$root/scripts/validate-copilot-assets.sh" "$root"
```

Change the final success text to:

```bash
echo "template baseline is structurally clean"
```

The delegated validator retains its own exact error prefix.

- [ ] **Step 4: Document the attendee baseline contract**

Add to `docs/workshop/attendee-baseline.md`:

```markdown
The template includes the attendee-first root instructions, scoped maintainer
instructions, Clinic Stakeholder, optional Evidence Coach, canonical
stakeholder knowledge, and exactly the supported workshop skill set. It must
not include unsupported repository skills or custom agents with authority to
approve, certify, post reviews, or make Risk Gate judgments.
```

Update the validation block to:

```bash
scripts/test-copilot-assets.sh
scripts/validate-copilot-assets.sh
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
./mvnw test
```

- [ ] **Step 5: Run integration tests**

Run:

```bash
bash scripts/test-copilot-assets.sh
bash scripts/validate-copilot-assets.sh
bash scripts/test-template-baseline-validator.sh
bash scripts/validate-template-baseline.sh
```

Expected: all four commands exit 0; the two validators print their exact
success messages.

- [ ] **Step 6: Commit template integration**

```bash
git add scripts/validate-template-baseline.sh \
  scripts/test-template-baseline-validator.sh \
  docs/workshop/attendee-baseline.md
git commit -m "test: validate workshop Copilot assets"
```

### Task 7: Verify the complete Workshop Copilot asset slice

**Files:**
- Verify all files changed by Tasks 1-6.

- [ ] **Step 1: Run shell syntax checks**

Run:

```bash
bash -n scripts/validate-copilot-assets.sh \
  scripts/test-copilot-assets.sh \
  scripts/validate-template-baseline.sh \
  scripts/test-template-baseline-validator.sh
```

Expected: exit 0 with no output.

- [ ] **Step 2: Run all focused asset and template checks**

Run:

```bash
bash scripts/test-copilot-assets.sh
bash scripts/validate-copilot-assets.sh
bash scripts/test-template-baseline-validator.sh
bash scripts/validate-template-baseline.sh
```

Expected: all commands exit 0.

- [ ] **Step 3: Run the application regression suite**

Run:

```bash
./mvnw -q test
```

Expected: Maven exits 0 with no test failures.

- [ ] **Step 4: Inspect the final asset inventory and diff**

Run:

```bash
find .github/skills -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
git --no-pager diff --check
git --no-pager status --short
```

Expected: exactly the eight supported skill names, no whitespace errors, and
only intentional changes.

- [ ] **Step 5: Commit any verification-only corrections**

If verification required corrections, commit only those corrections:

```bash
git add -A
git commit -m "fix: complete Copilot asset validation"
```

If no corrections were required, do not create an empty commit.
