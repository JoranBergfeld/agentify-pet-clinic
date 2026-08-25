# Participant README Quickstart Design

## Purpose

Make the repository README a self-contained starting point for an attendee
running the workshop, while preserving the product ambiguity and human
authority that the workshop is designed to exercise.

## Problem

The current README explains how to create and preflight a workshop repository,
then delegates the workshop itself to the Participant Guide. The Participant
Guide is written as a lookup aid rather than a linear entry path. An attendee
can therefore understand the workshop vocabulary without knowing:

- what outcome they are trying to produce;
- what to do first after Preflight;
- how to progress from one workflow stage to the next;
- what evidence to record along the way; or
- what constitutes a valid workshop outcome when the feature is incomplete.

## Design

The README will become the canonical attendee entry point and use a linear
quickstart structure.

### Explain the two goals

The opening will distinguish:

- the **product challenge**: add a bounded, staff-facing, read-only Clinic
  Assistant slice to the inherited Spring PetClinic application; and
- the **learning goal**: practice controlled, inspectable agent-assisted
  engineering while retaining human authority over scope, risk, and
  acceptance.

It will state that completing every capability is not required. A bounded
slice with honest evidence and explicit gaps is a valid outcome.

### Separate preparation from workshop work

The existing template creation and Azure Preflight steps remain clearly
identified as pre-work. A new workshop-start section will tell the attendee to:

1. create a solution branch;
2. open a draft pull request;
3. locate the six blank Stage Cards; and
4. begin with Orient rather than implementing immediately.

The README will link to detailed setup and review guidance instead of
duplicating it.

### Provide a concrete six-stage route

For each stage, the README will state:

- **Do**: the concrete participant action;
- **Record**: the evidence to add to that Stage Card; and
- **Move on when**: the evidence-based transition condition.

The route will cover:

1. **Orient**: reconstruct local operation, test seams, application seams,
   Azure topology, and repository constraints.
2. **Clarify**: query the Clinic Stakeholder and separate facts, preferences,
   unknowns, assumptions, and reserved human decisions.
3. **Shape**: choose the smallest useful vertical slice and write the Work
   Contract.
4. **Execute**: delegate small authorized moves, inspect fresh evidence, and
   decide whether to continue, narrow, correct, or escalate.
5. **Verify**: trace each acceptance claim to evidence at the correct seam and
   record residual gaps.
6. **Learn**: retain one grounded principle, one risk or failure mode, and one
   transferable adaptation.

### Make authority and review visible

The route will locate the three human-owned decisions:

- Commitment Gate between Shape and Execute;
- Acceptance Gate after Verify; and
- Learning Gate during Learn.

It will explain that Stage Card status expresses review readiness rather than
stage completion. Peer review happens asynchronously at natural pauses and
does not block progression.

### Preserve intentional ambiguity

The README will not:

- reproduce the canonical Clinic Stakeholder knowledge;
- select a capability family, UI surface, or implementation for the attendee;
- provide a completed Work Contract or Stage Card;
- imply that tests, deployment, peer review, or agent confidence can make a
  Risk Gate decision; or
- make the Reference Workflow mandatory when equivalent risk-shaped evidence
  is available.

## Documentation boundaries

The README owns the high-level attendee journey. Existing documents retain
their focused roles:

- the Participant Guide explains authority, Stage Card operation, peer review,
  exception handling, and adaptation in more depth;
- Stage Cards remain the living evidence templates;
- the Azure Preflight and cleanup guide owns environment commands;
- the Evidence Lenses and Reciprocal Evidence Review aid own review mechanics;
  and
- the Workshop Blueprint remains the canonical design baseline.

## Acceptance evidence

The change is acceptable when a first-time attendee can answer from the README
alone:

1. What am I trying to learn?
2. What product challenge am I using to practice it?
3. What do I do before and during the workshop?
4. What do I do and record at each stage?
5. How do I know when to move on?
6. Which decisions remain mine?
7. How does peer review fit without blocking me?
8. What counts as an honest outcome if implementation is incomplete?

All README links must resolve to existing repository paths, and the content
must remain consistent with the Workshop Blueprint and Participant Guide.
