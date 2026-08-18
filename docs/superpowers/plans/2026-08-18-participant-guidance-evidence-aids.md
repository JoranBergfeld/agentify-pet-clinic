# Participant Guidance and Evidence Aids Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Reference Workflow operable without coaching through the Evidence Lens aid, Reciprocal Evidence Review aid, protected Stage Cards, Participant Guide, and peer-access Preflight path.

**Architecture:** Keep each attendee-facing fact in one authoritative artifact and cross-link from the others. Implement the four approved tracer bullets in dependency order, with the existing build issue remaining the human Acceptance Gate. Extend the existing template-baseline validator test-first so blank Stage Cards are permitted and filled evidence is rejected on `main`.

**Tech Stack:** Markdown, Bash, GitHub Issues, existing repository validators.

---

### Task 1: Publish the Evidence Lens aid

**Files:**
- Create: `docs/workshop/evidence-lenses.md`

- [ ] **Step 1: Write the aid**

Create a concise page with:

```markdown
# Evidence Lenses

The Evidence Lenses are a formative conversation aid, not a score,
certification, or acceptance decision.

## Diagnostic states

- **Visible** — current evidence supports the control.
- **Fragile** — intent exists, but evidence, ownership, or traceability has a meaningful gap.
- **Missing** — the control cannot be shown or relies on agent confidence or feature output alone.

## Intent and context
...
**Auditor prompt:** ...
```

Include all five Blueprint lenses and prompts. Cite `Workshop Blueprint — Evidence Lenses` and keep Reciprocal Evidence Review headings out of this file.

- [ ] **Step 2: Check the external contract**

Run:

```bash
test "$(wc -w < docs/workshop/evidence-lenses.md)" -le 500
grep -c '^## ' docs/workshop/evidence-lenses.md
```

Expected: the word-budget check passes and the headings cover diagnostic states plus five lenses.

- [ ] **Step 3: Validate repository structure**

Run:

```bash
scripts/validate-copilot-assets.sh
scripts/validate-template-baseline.sh
```

Expected: both validators pass.

### Task 2: Make Reciprocal Evidence Review operable

**Files:**
- Create: `docs/workshop/reciprocal-evidence-review.md`

- [ ] **Step 1: Write the review aid**

Create a concise page that requires a Stage Card and commit SHA, links to the Evidence Lens aid, explains non-authoritative asynchronous review, and includes this copy-paste block:

```markdown
Stage Card: `<path>`
Commit: `<full or unambiguous commit SHA>`

## Intent

## Decisions

## Evidence

## Gaps

## Next inspection point
```

State that Auditors post a PR comment, never an Approve or Request-changes verdict; the Driver retains implementation and Acceptance authority; and Next inspection point identifies scrutiny without prescribing a move. Cite `Workshop Blueprint — Reciprocal Evidence Review`.

- [ ] **Step 2: Check the external contract**

Run:

```bash
test "$(wc -w < docs/workshop/reciprocal-evidence-review.md)" -le 500
test ! -e .github/PULL_REQUEST_TEMPLATE.md
```

Expected: both checks pass.

- [ ] **Step 3: Validate repository structure**

Run:

```bash
scripts/validate-copilot-assets.sh
scripts/validate-template-baseline.sh
```

Expected: both validators pass.

### Task 3: Ship the protected Stage Card evidence spine

**Files:**
- Create: `workshop/stage-cards/01-orient.md`
- Create: `workshop/stage-cards/02-clarify.md`
- Create: `workshop/stage-cards/03-shape.md`
- Create: `workshop/stage-cards/04-execute.md`
- Create: `workshop/stage-cards/05-verify.md`
- Create: `workshop/stage-cards/06-learn.md`
- Modify: `scripts/test-template-baseline-validator.sh`
- Modify: `scripts/validate-template-baseline.sh`

- [ ] **Step 1: Add the failing validator fixture**

Copy `workshop/stage-cards/` into the clean fixture. Append content below an `## Evidence` heading in one fixture card and expect:

```text
template baseline invalid: filled Stage Card is present: workshop/stage-cards/01-orient.md
```

Run:

```bash
scripts/test-template-baseline-validator.sh
```

Expected: FAIL because the validator does not yet enforce blank Stage Cards.

- [ ] **Step 2: Implement blank-card validation**

Add a validator function that requires exactly the six expected Markdown files, validates each required heading and `Status: Working`, and rejects content beneath the `## Evidence` heading other than the placeholder instruction.

- [ ] **Step 3: Create the six blank cards**

Each card must contain:

```markdown
Status: Working

## Purpose
## Risk controlled
## Minimum evidence
## Optional Copilot example
## Exit question
## Evidence

_Replace this line with your evidence._
```

Use the Blueprint's stage-specific minimum evidence and exit question. Name exactly one replaceable repository skill per card. Link to both attendee aids. Any illustrative fragment must be unrelated to the Clinic Assistant.

- [ ] **Step 4: Run the focused validator tests**

Run:

```bash
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
```

Expected: both pass.

### Task 4: Make the Participant Guide and peer-access path usable

**Files:**
- Create: `docs/workshop/participant-guide.md`
- Modify: `docs/workshop/azure-preflight-and-cleanup.md`
- Modify: `README.md`
- Modify: `docs/workshop/attendee-baseline.md`
- Modify: `CONTEXT.md`

- [ ] **Step 1: Write the Participant Guide**

Use exactly these sections in order:

```markdown
## What you own
## Fixed safety boundaries
## Your six Stage Cards
## Getting product knowledge
## Reviewing your partner's evidence
## When things go wrong
## Adapting the workflow
```

Keep it at or below 1200 words. Include human authority and Risk Gates, only the fixed safety boundaries, Clinic Stakeholder discovery, Stage Card status and reopening, links to the aids, all seven attendee exception paths, and the displaced-risk/equivalent-evidence adaptation rule. Include the exact collaborator command:

```bash
gh api --method PUT repos/<driver>/<repository>/collaborators/<partner> -f permission=push
```

Do not include timings, the learning arc, per-client mechanics, Host coaching, or Reference Challenge answers.

- [ ] **Step 2: Add the Preflight access proof**

Before Azure readiness, require each Driver to grant their assigned partner collaborator access and require the partner to post and then delete a proof comment before the workshop.

- [ ] **Step 3: Integrate navigation and vocabulary**

Link the Participant Guide from the README, inventory the four artifact groups in the attendee baseline, and add only:

```markdown
**Participant Guide**:
The durable attendee-held reference for operating the workshop.
_Avoid_: workbook, Workshop Blueprint, deck script
```

to the domain glossary.

- [ ] **Step 4: Check the external contract**

Run:

```bash
test "$(wc -w < docs/workshop/participant-guide.md)" -le 1200
grep -n '^## ' docs/workshop/participant-guide.md
grep -F 'gh api --method PUT repos/<driver>/<repository>/collaborators/<partner> -f permission=push' docs/workshop/participant-guide.md
```

Expected: the budget passes, seven headings appear in order, and the exact command is present.

### Task 5: Verify and record issue evidence

**Files:**
- Verify all files above.

- [ ] **Step 1: Run the required validation suite**

Run:

```bash
scripts/test-copilot-assets.sh
scripts/validate-copilot-assets.sh
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
scripts/validate-template-generation.sh
./mvnw test
```

Expected: all checks pass. If live template generation cannot run because of GitHub permissions or network access, report that failed input explicitly; do not substitute a local success.

- [ ] **Step 2: Inspect conformance and diff scope**

Run:

```bash
git diff --check
git status --short
git diff -- README.md CONTEXT.md docs/workshop scripts/validate-template-baseline.sh scripts/test-template-baseline-validator.sh workshop/stage-cards
```

Expected: no whitespace errors; only approved participant-guidance files are changed, apart from pre-existing unrelated worktree changes.

- [ ] **Step 3: Resolve the four implementation issues**

Post each issue's focused evidence, close it, and leave **Build participant guidance and Reciprocal Evidence Review aids** open for the workshop owner's Acceptance Gate.
