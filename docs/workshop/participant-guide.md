# Participant Guide

Use this guide as a lookup while you work. The workshop is attendee-led: the
Workshop Host manages logistics, while you own the engineering decisions,
evidence, and judgments in your repository.

## What you own

You alternate between two roles without sharing an implementation:

- As **Driver**, direct the Engineering Agent in your environment and own the
  Work Contract, implementation, evidence, and acceptance judgment.
- As **Auditor**, asynchronously challenge a partner's committed, Review-ready
  Stage Cards. Do not approve their work, prescribe their next move, or take
  over their decisions.

Only you cross your three [Risk Gates](../workshop-blueprint.md#risk-gates):

- At the **Commitment Gate**, decide whether intent, scope, constraints, agent
  authority, assumptions, public seams, and expected evidence justify
  proceeding, narrowing, or escalating.
- At the **Acceptance Gate**, trace claims to fresh evidence and record
  **Accepted**, **Accepted with residual gap**, or **Not yet accepted**.
- At the **Learning Gate**, retain only learning worth its maintenance cost.

Tests, deployments, peer comments, and agent summaries inform these decisions;
none makes the decision for you.

## Fixed safety boundaries

These boundaries are known before product discovery and always apply:

- The Clinic Assistant is staff-facing and read-only.
- Do not add write tools or claim that PetClinic data was changed.
- Keep the solution inside the existing Spring Boot process and workshop Azure
  baseline; do not add infrastructure.
- Answer only from retrieved PetClinic data and admit absent records or
  unsupported requests.
- Never provide veterinary diagnosis or treatment advice.

Stop affected work immediately if a boundary is threatened. See
[Workshop Blueprint — Fixed safety and architecture envelope](../workshop-blueprint.md#fixed-safety-and-architecture-envelope).

## Your six Stage Cards

Your evidence spine is in `workshop/stage-cards/`, with one card for Orient,
Clarify, Shape, Execute, Verify, and Learn. Edit these files in place on your
solution branch so the draft pull-request diff shows evidence accumulating.

Each card starts **Working**. Change its `Status:` to **Review ready** when its
evidence is committed and ready for scrutiny, then to **Reviewed** after review.
New evidence or feedback may reopen a Reviewed card to Working; these states
show review readiness, not pass/fail stage completion.

Use the [Evidence Lenses](evidence-lenses.md) while working and the
[Reciprocal Evidence Review aid](reciprocal-evidence-review.md) when a card is
Review ready. The card's exit question supports your judgment; it does not
grant authority automatically.

Source:
[Workshop Blueprint — Evidence spine: Stage Cards](../workshop-blueprint.md#evidence-spine-stage-cards).

## Getting product knowledge

The initial product brief is deliberately incomplete. Missing requirements are
decisions to expose, not permission to guess.

Ask the repository's **Clinic Stakeholder** what is known, preferred, or
explicitly unknown. The stakeholder may honestly report uncertainty. Record
the resulting facts, assumptions, deferrals, narrowing choices, and
consequences in your Stage Cards and Work Contract.

`docs/workshop/clinic-stakeholder-knowledge.md` grounds the Clinic Stakeholder;
it is not an attendee brief to read around the discovery exercise.

Source:
[Workshop Blueprint — Initial participant brief](../workshop-blueprint.md#initial-participant-brief).

## Reviewing your partner's evidence

Before the workshop, each Driver grants their assigned partner collaborator
access and the partner proves they can comment. Follow the
[Preflight access proof](azure-preflight-and-cleanup.md#prove-partner-review-access).
The grant command is:

```bash
gh api --method PUT repos/<driver>/<repository>/collaborators/<partner> -f permission=push
```

At a natural pause, ask which committed Stage Card is Review ready. Inspect it
at the named commit SHA and post the structured block from the
[Reciprocal Evidence Review aid](reciprocal-evidence-review.md) as a
pull-request comment. Review is asynchronous and never blocks either Driver.

## When things go wrong

Use these attendee-owned
[exception paths](../workshop-blueprint.md#exception-paths):

- **Your environment fails:** self-remediate while the pair preserves learning
  through the working environment and asynchronous review. Never share
  accounts.
- **Peer review has not arrived:** continue working and record missing
  independent challenge as an explicit Acceptance Gate evidence gap.
- **Product requirements remain incomplete:** make a bounded assumption,
  narrow around the uncertainty, defer it, or escalate; record the decision
  and consequence.
- **The vertical slice is incomplete:** stop at the workshop boundary, record
  the strongest evidence and exact unfinished gap, and make an honest
  acceptance judgment.
- **Local evidence passes but deployed smoke fails:** diagnose briefly from
  evidence; if the failure remains, record the missing deployed claim. Local
  checks do not substitute for deployed evidence.
- **An Evidence Lens is Fragile or Missing:** repair the evidence, narrow the
  claim, accept the residual risk explicitly, or escalate. Do not relabel it
  cosmetically.
- **A safety boundary is threatened:** stop the affected work immediately.
  The Host may restore a missed boundary but does not choose your solution.

## Adapting the workflow

Orient → Clarify → Shape → Execute → Verify → Learn is a recommended route, not
a mandatory ceremony. You may combine, skip, or replace a stage, artifact, or
Copilot mechanic when you name the risk it normally controls, explain why the
adaptation fits, and provide equivalent inspectable evidence.

Source: [Workshop Blueprint — Reference Workflow](../workshop-blueprint.md#reference-workflow).
