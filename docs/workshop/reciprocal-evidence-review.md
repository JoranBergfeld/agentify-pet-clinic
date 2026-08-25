# Reciprocal Evidence Review

Use Reciprocal Evidence Review to check your partner's committed Stage Cards.
The cards must have `Status: Review ready`. Your questions can help the Driver
find gaps, but the Driver still owns the code and all decisions.

Source:
[Workshop Blueprint: Reciprocal Evidence Review](../workshop-blueprint.md#reciprocal-evidence-review).
Use the [Evidence Lenses](evidence-lenses.md) to label each observation
**Visible**, **Fragile**, or **Missing**.

## Before reviewing

1. Review at a good stopping point in your own work. Do not stop your work while
  you wait for your partner.
2. Open your partner's draft pull request. Find one or more committed Stage
  Cards with `Status: Review ready`.
3. Copy the pull request's current commit SHA. Review the cards at that exact
  commit so the evidence cannot change during your review.
4. Put the Stage Card path and commit SHA in your comment.

## Comment headings

| Heading                   | What to write                                              |
|---------------------------|------------------------------------------------------------|
| **Intent**                | The result and small capability the card supports          |
| **Decisions**             | Choices, assumptions, delayed items, and who owns them     |
| **Evidence**              | Facts, tests, or deployed checks that support the claims   |
| **Gaps**                  | Missing proof, conflicting results, or remaining risks     |
| **Next inspection point** | A useful place to check later, without telling what to do  |

## Copy-paste PR comment

```markdown
Stage Card: `<repository-relative path>`
Commit: `<full or unambiguous commit SHA>`

## Intent

## Decisions

## Evidence

## Gaps

## Next inspection point
```

## Rules of engagement

- Post the block as a pull-request comment. Do not use GitHub **Approve** or
  **Request changes**. This review asks questions; it does not approve work.
- Link every observation to the Stage Card and commit SHA.
- Check what the evidence supports. Do not take over the Driver's code or tell
  the Driver what to build next.
- The Driver owns the Work Contract, code, Risk Gate decisions, remaining-risk
  decision, and final acceptance claim.
- You and your partner do not need to review at the same time. If review is
  still missing at the Acceptance Gate, record it as an evidence gap.
- The optional Evidence Coach can draft more observations. It does not replace
  the human review.
