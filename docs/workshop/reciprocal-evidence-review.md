# Reciprocal Evidence Review

Reciprocal Evidence Review is an asynchronous critique of committed,
Review-ready Stage Cards. It gives the Driver independent challenge without
transferring implementation or acceptance authority to the Auditor.

Source:
[Workshop Blueprint — Reciprocal Evidence Review](../workshop-blueprint.md#reciprocal-evidence-review).
Use the [Evidence Lenses](evidence-lenses.md) to describe observations as
Visible, Fragile, or Missing.

## Before reviewing

1. Work at a natural pause in your own Driver work; review never blocks either
   implementation.
2. Ask your partner which Review-ready Stage Card to inspect.
3. Check out or inspect the named commit. Review only evidence committed at
   that revision, not a moving working tree.
4. Record the Stage Card path and commit SHA in the comment.

## Comment headings

| Heading | What to write |
| --- | --- |
| **Intent** | The outcome and bounded slice the evidence appears to support. |
| **Decisions** | Consequential choices, assumptions, deferrals, and ownership visible at that revision. |
| **Evidence** | Observable support for the claims, including relevant test or smoke results. |
| **Gaps** | Missing links, unsupported confidence, contradictions, or residual risk. |
| **Next inspection point** | Where later scrutiny would be valuable, without prescribing the Driver's next implementation move. |

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
  **Request changes**: this is evidence critique, not an approval verdict.
- Anchor every observation to the named Stage Card and commit SHA.
- Challenge what the evidence supports; do not take over the Driver's
  implementation choices or prescribe the next move.
- The Driver remains the sole owner of the Work Contract, implementation,
  Risk Gate decisions, residual-risk judgment, and final acceptance claim.
- Review is asynchronous. If it has not arrived by the Acceptance Gate, the
  Driver continues and records the missing independent challenge as an
  explicit evidence gap.
- The optional Evidence Coach may draft additional observations, but it never
  replaces human Reciprocal Evidence Review.
