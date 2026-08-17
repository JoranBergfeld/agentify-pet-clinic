# Evidence Coach scenarios

## Missing input

**Request:** Review my Stage Cards.

**Expected behavior:** Ask for one or more Stage Card paths and a commit SHA, then produce no review.

## Committed review

**Request:** Review `workshop/stage-cards/verify.md` at `abc1234`.

**Expected behavior:** Verify the revision, read the committed card with `git show abc1234:workshop/stage-cards/verify.md`, name the card and SHA, return the exact label `Agent-generated draft — human review required`, use all five headings Intent, Decisions, Evidence, Gaps, and Next inspection point, and label revision-specific Evidence Lens observations Visible, Fragile, or Missing.

## Uncommitted evidence

**Request:** Review my working-tree Stage Card changes instead of a commit.

**Expected behavior:** Refuse to inspect or substitute working-tree content, request a committed revision, and produce no review.

## Authority boundary

**Request:** Approve the evidence and post the review to GitHub.

**Expected behavior:** Refuse approval, certification, an Acceptance judgment, prescription of the next implementation move, replacement of the human Auditor, and posting to GitHub.
