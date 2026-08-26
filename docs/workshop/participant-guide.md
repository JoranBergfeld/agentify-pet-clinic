# Participant Guide

Use this guide as a checklist. The Workshop Host manages the time and
activities. You own the engineering decisions and evidence in your repository.

## Your challenge

Build a staff-facing, read-only Clinic Assistant inside the existing Spring
PetClinic application. It must use PetClinic records to answer questions about
owners, pets, Visits, or veterinarians.

Choose the smallest useful capability that you can build and test during the
workshop. You do not need to support every question or build a finished
product.

Some requirements are missing on purpose. Ask the **Clinic Stakeholder**, a
custom agent included in this repository. In VS Code, open GitHub Copilot Chat,
open the agent list, and select **Clinic Stakeholder**. Ask what is known,
preferred, or still unknown. The agent may say that an answer is unknown. You
make the product decisions. In another supported Copilot client, select the
same agent from its custom-agent list.

## Work as a pair

Each person builds a separate solution in a separate repository.

- As **Driver**, select and use an AI coding assistant available in your
  environment. You own the Work Contract, code, evidence, and final decisions.
- As **Auditor**, you review your partner's committed Stage Cards when they are
  **Review ready**. Point out questions and gaps. Do not approve the work, tell
  your partner what to do next, or make decisions for them.

Before the workshop, complete the
[partner access proof](local-setup.md#prove-partner-review-access).

## How you will work

A Stage Card is a short working note for one stage. It helps you record what
you decided, what you observed, and what is still missing. Your partner reads
the committed card to understand and question your work without taking over
your code.

Find the six cards in `workshop/stage-cards/`, from `01-orient.md` to
`06-learn.md`. Each card already has a goal, a list of what can go wrong, what
to record, optional Copilot help, and a check before the next step. Work on your
solution branch and open a draft pull request. This is where your partner reads
the cards and leaves review comments. Use a card like this:

1. Open the card for your current stage. Keep its status **Working**.
2. Ask your AI coding assistant to draft the `## Your evidence` section, or edit
  it yourself. Include short facts, your decisions, test or command results,
  links, and gaps. Update it while you work, not only at the end.
3. Check the agent's draft. Remove guesses and fix mistakes. The agent must not
  invent missing evidence, change the status, or make a Risk Gate decision.
4. At a good stopping point, set the status to **Review ready**, then commit and
  push the card to your draft pull request. Share the pull-request link with
  your partner.
5. Your partner opens the pull request, finds cards marked **Review ready**, and
  records the current commit SHA. They review that exact version and leave a
  comment by using the
  [Reciprocal Evidence Review aid](reciprocal-evidence-review.md) and
  [Evidence Lenses](evidence-lenses.md). You keep working while you wait.
6. You decide how to use the feedback. Update the card and set it tod
  **Reviewed**. If new evidence changes the card, move it back to Working.

You can give your AI coding assistant this prompt:

```text
Update `<card path>` under `## Your evidence` with facts, my decisions, results,
links, and gaps from this work. Do not invent evidence or change `Status:`.
Show me the diff so I can check it.
```

The status shows review progress, not pass or fail. This prompt supports the
Stage Card process described above. The six Stage Cards correspond to the
following workshop stages:

1. Orient. Run and test the current application. Look at the code, tests, and
  Azure setup. Record facts, assumptions, and open questions.
2. Clarify. Ask the Clinic Stakeholder about the product. Record what is known,
  unknown, or your assumption.
3. Shape. Choose one small capability. Write a Work Contract with the goal,
  scope, limits, assumptions, agent permissions, test points, and planned
  evidence. At the Commitment Gate, decide to continue, reduce the scope, or
  ask for help.
4. Execute. Ask your AI coding assistant to make small changes. Before each
  change, state what you expect to learn or prove. Check the result and update
  your evidence. At a good stopping point, ask your partner for a review.
5. Verify. Run focused local tests and a short test in the deployed application.
  Connect each claim to evidence and record gaps. At the Acceptance Gate,
  record **Accepted**, **Accepted with residual gap** (a known gap remains), or
  **Not yet accepted**.
6. Learn. Record one useful principle, one risk you found, and one change you
  would make in another project. At the Learning Gate, decide what to keep.
  Choose one lesson with your partner to share with the group.

You can return to an earlier stage when you learn something new. Tests,
deployments, partner comments, and agent summaries help you decide, but only you
make decisions at the [Risk Gates](../workshop-blueprint.md#risk-gates).

## Follow the safety rules

These rules always apply:

- The Clinic Assistant is staff-facing and read-only.
- Do not add write tools or claim that PetClinic data was changed.
- Keep the solution inside the existing Spring Boot process and workshop Azure
  setup. Do not add new infrastructure.
- Use only PetClinic data that the assistant found. Do not guess identity. Say
  when a record is missing or a request is not supported.
- Never give a veterinary diagnosis or advice about treatment.

Stop the affected work at once if a rule may be broken. See the
[fixed safety and architecture envelope](../workshop-blueprint.md#fixed-safety-and-architecture-envelope).

## When things go wrong

Use these [exception paths](../workshop-blueprint.md#exception-paths):

- Your environment fails: try to fix it, keep learning with your partner, and
  never share accounts.
- Partner review is late: keep working and record the missing review as an
  Acceptance Gate evidence gap.
- Product information is missing: make a clear assumption, reduce the scope,
  delay the decision, or ask for help. Record your choice and its effect.
- Your capability is incomplete: stop on time and record the evidence, exact
  unfinished work, and honest acceptance decision.
- Local checks pass but the deployed test fails: investigate briefly, then
  record the unproven deployed claim. Local tests cannot replace it.
- An Evidence Lens is Fragile or Missing: improve the evidence, reduce the
  claim, accept the remaining risk, or ask for help. Do not hide the gap.
- A safety rule may be broken: stop that work. The Host can remind you of the
  rule but cannot choose your solution.

## Adapting the workflow

Orient → Clarify → Shape → Execute → Verify → Learn is a guide, not a fixed
process. You may join, skip, or replace a step. State which risk the original
step controls, why your change fits, and what evidence people can check.
