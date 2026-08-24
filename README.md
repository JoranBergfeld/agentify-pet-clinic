# Agentic Engineering Principles Workshop

## Your goal

You are learning a reusable way to work with coding agents that keeps you in
control of intent, scope, risk, and acceptance. You'll practice this method on
a bounded change to Spring PetClinic: adding a small, staff-facing, read-only
**Clinic Assistant** conversational agent.

Completing every feature is not required. A bounded slice with honest evidence
and explicit gaps is a valid outcome.

## The challenge

**Product challenge**: Add the smallest useful evidence-producing, staff-facing,
read-only Clinic Assistant vertical slice to Spring PetClinic.

**Learning goal**: Practice controlled, inspectable agent-assisted engineering
while retaining human authority over intent, scope, risk decisions, and
acceptance.

### Safety envelope

These boundaries apply throughout the workshop:

- **Staff-facing, read-only**: No writes to PetClinic data; no identity
  guessing or claimed mutations.
- **Existing infrastructure**: Keep the solution inside one Spring Boot process
  using the workshop Azure baseline. Do not add another database or new
  infrastructure.
- **Retrieved records only**: Answer only from fetched PetClinic data. Admit
  absent records and unsupported requests. Never provide veterinary diagnosis
  or treatment advice.
- **Intentional ambiguity preserved**: The exact capability family, UI surface,
  wording, and implementation remain your decisions. This README does not
  choose them for you.

## Start the workshop

### Before the workshop (pre-work)

1. Use this template to create your own repository.
2. Clone your repository.
3. Follow the [Azure Preflight and cleanup guide](docs/workshop/azure-preflight-and-cleanup.md)
   to verify your local environment and Azure setup.
4. Verify the inherited application:
   ```bash
   ./mvnw test
   ```

### When the workshop begins

1. Create a solution branch for your work.
2. Open a draft pull request against `main`.
3. Locate your six Stage Cards in `workshop/stage-cards/`:
   - `01-orient.md`
   - `02-clarify.md`
   - `03-shape.md`
   - `04-execute.md`
   - `05-verify.md`
   - `06-learn.md`
4. Begin with **Orient** (see "Work through the six stages" below).
5. As you work, edit each Stage Card in place on your solution branch to record
   evidence. The draft PR diff will show your evidence accumulating. Use the
   [Participant Guide](docs/workshop/participant-guide.md) for detailed
   authority, Stage Card operation, and exception handling.

## Work through the six stages

The Reference Workflow guides you through six stages. Each stage is a concrete
bounded move. Stages are independent: you move on when evidence supports it, not
when a clock expires.

### Stage 1: Orient

**Purpose**: Understand the Inherited System—the application you're changing,
how to run it locally, what tests exist, how to deploy, and where product
decisions will matter.

**Do**:
- Run the application locally and verify `./mvnw test` passes.
- Identify the local run path and test seams (how tests reach the application).
- Map the public application API and public test entry points.
- Explore the Azure deployment topology and how to check status.
- Read `CONTEXT.md` and identify repository constraints that affect product
  decisions.

**Record** (in Stage Card `01-orient.md`):
- Facts you discovered: what you can reproduce, how to run tests, what tests
  exist, deployment topology, constraints.
- Assumptions you made: what you guessed because it was unavailable.
- Unresolved decisions: what consequential questions remain.

**Move on when**:
- You can answer: "How do I run the inherited system? How do I verify it works?
  Where will a new capability fit? What decisions are reserved?"

### Stage 2: Clarify

**Purpose**: Expose what is known, unknown, preferred, or deferred about the
product challenge. Separate your implementation observations from product facts.

**Do**:
- Invoke or ask the repository's **Clinic Stakeholder** what is known, preferred,
  and explicitly unknown. See [Getting product knowledge](docs/workshop/participant-guide.md#getting-product-knowledge)
  in the Participant Guide for guidance.
- Record exactly what the Clinic Stakeholder reports about capability scope, UI,
  integration points, and known gaps.
- Distinguish facts (the Stakeholder confirmed this), assumptions (you guessed
  this), deferrals (will be decided later), and narrowing (you chose to exclude
  this for now).

**Record** (in Stage Card `02-clarify.md`):
- Known product requirements and constraints.
- Preferred but not required capabilities.
- Explicitly unknown or deferred requirements.
- Your assumptions and why you made them.
- Narrowing decisions: what you chose to exclude and why.
- Consequential ambiguity: what could go wrong if you are wrong about this.

**Move on when**:
- You can identify the consequential ambiguity clearly and see a path to resolve
  it with a bounded slice.

### Stage 3: Shape

**Purpose**: Choose the smallest useful vertical slice and write a Work Contract
that makes your intent, scope, boundaries, constraints, agent authority,
public seams, and acceptance evidence legible.

**Do**:
- Using the [Evidence Lenses](docs/workshop/evidence-lenses.md) (Intent,
  Decisions, Evidence), sketch your planned slice:
  - What is the narrowest capability that produces observable value?
  - Which PetClinic data and operations will you use?
  - What will a user see? What won't they see?
  - Where does the Engineering Agent have authority? Where do you remain in
    control?
- Write a Work Contract (record it in Stage Card `03-shape.md`) stating:
  - **Intent**: What learning/evidence will this move produce?
  - **Scope**: What capabilities are in/out?
  - **Constraints**: What cannot change (safety envelope, timeline, Azure
    baseline)?
  - **Assumptions**: What must be true for this to work?
  - **Public seams**: Where will you observe it working (test, demo, smoke
    test)?
  - **Acceptance evidence**: How will you know this succeeded?

**Record** (in Stage Card `03-shape.md`):
- Your Work Contract.
- Decisions you made to narrow scope.
- Evidence-shaped acceptance criteria (not just "feature complete").

**Move on when**: Reach the **Commitment Gate**.

### Commitment Gate

**This is a human-owned decision.** You decide whether:
- Your Work Contract is legible and constraints are clear.
- You and your Engineering Agent have enough authority to move forward.
- Acceptance evidence is observable and focused.
- Assumptions are explicit.

If yes, proceed to Execute. If no, narrow the scope, escalate a constraint, or
gather more information before committing.

### Stage 4: Execute

**Purpose**: Delegate small, bounded, evidence-producing moves to your
Engineering Agent without surrendering human authority.

**Do**:
- Before each move, state its purpose, expected evidence, and scope.
- Make one focused code change (feature, test, or investigation) at a time.
- After each change, inspect the result: Is it what you expected? Is it
  reversible? Do you have enough evidence to decide the next step?
- Adjust assumptions and scope as you learn. If evidence contradicts your
  Contract, update the Card and discuss before continuing.
- Commit focused changes with clear messages.

**Record** (in Stage Card `04-execute.md`):
- What you built and why.
- Evidence observed: what worked, what failed, what surprised you.
- Adjustments to your assumptions or scope.
- Decisions made during execution.
- Honest failures and how you corrected them.

**Move on when**:
- Your implementation is testable locally and ready for verification.
- You have evidence of what you built and what remains uncertain.

### Stage 5: Verify

**Purpose**: Trace each acceptance claim to fresh, focused evidence at the
correct seam. Record residual gaps and make a human-owned judgment: Accepted,
Accepted with residual gap, or Not yet accepted.

**Do**:
- Test locally: Run focused tests for your capability. Record pass/fail.
- Smoke test: Deploy to Azure (or demonstrate locally) and show the feature
  working end-to-end. Record what you see.
- Challenge your own evidence: What could be wrong? What did you not test?
  What depends on assumptions?
- Identify residual gaps: incomplete tests, unverified integrations, unclear
  error handling, performance unknowns, security gaps.
- Record your acceptance judgment and residual risks.

**Record** (in Stage Card `05-verify.md`):
- Test results: what passed, what failed, what was skipped.
- Smoke test evidence: what you observed end-to-end.
- Gaps you discovered: what is incomplete or untested.
- Residual risks: what could fail in production.
- Your acceptance judgment: **Accepted**, **Accepted with residual gap**, or
  **Not yet accepted**, with reasoning.

**Move on when**: Reach the **Acceptance Gate**.

### Acceptance Gate

**This is a human-owned decision.** You decide:
- Have you traced claims to fresh evidence?
- Are residual gaps explicit and acceptable?
- Does the Work Contract match what you built?

Record your judgment and any residual-risk acceptance. Peer review (from your
Auditor) informs this decision but does not make it.

### Stage 6: Learn

**Purpose**: Retain one useful principle, failure mode, or adaptation from your
work—something durable enough to transfer to your next project.

**Do**:
- Review your Stage Cards: What went well? What surprised you? What would you
  do differently?
- Identify one grounded principle you would apply again.
- Identify one risk or failure mode you discovered.
- Identify one adaptation you made to the Reference Workflow and why it was
  necessary.

**Record** (in Stage Card `06-learn.md`):
- One principle: a decision or practice you'll use again.
- One failure mode: a risk you discovered or how to spot it.
- One adaptation: something you changed about the workflow and what risk it
  controlled.

**Finish when:** At the human-owned Learning Gate, you decide which
evidence-grounded learning is durable enough to retain and which would become
stale context or empty ceremony.

### Learning Gate

**This is a human-owned decision.** You decide what is durable enough to retain.
Record your learning and move on.

## Peer review and forward progress

Peer review happens asynchronously using **Stage Cards** as the evidence spine.
You do not need review approval to move forward; review challenges evidence at
natural pauses.

When a Stage Card's evidence is committed and ready for scrutiny, mark it
**Review ready**. Your Auditor (your partner in the workshop) will asynchronously
review your committed card at that named commit revision, using the
[Reciprocal Evidence Review aid](docs/workshop/reciprocal-evidence-review.md)
to structure critique. The statuses **Working**, **Review ready**, and
**Reviewed** reflect review readiness, not stage completion, pass/fail, or Risk
Gate authority.

Review examines:
- **Intent**: Is your purpose clear?
- **Decisions**: Are consequential choices explicit and justified?
- **Evidence**: Is evidence fresh and focused on acceptance criteria?
- **Gaps**: What is missing or untested?
- **Next inspection**: What should be challenged next?

**Review does not**:
- Approve or block your work.
- Prescribe the next move.
- Transfer authority.
- Replace your acceptance judgment.

After review, you may:
- Make adjustments and mark the card **Reviewed**.
- Disagree and mark it **Reviewed** anyway if you are confident.
- Reopen it to **Working** if evidence is weak.

Missing peer review becomes an evidence gap at your Acceptance Gate, not a
blocker.

## Human-owned decisions

You own three **Risk Gates** throughout the workshop:

1. **Commitment Gate** (after Shape, before Execute): You decide whether to
   proceed, narrow scope, or escalate constraints.
2. **Acceptance Gate** (after Verify): You decide whether work is Accepted,
   Accepted with residual gap, or Not yet accepted.
3. **Learning Gate** (during Learn): You decide what principle or adaptation is
   worth retaining.

Tests, deployments, peer review, and agent confidence inform these decisions.
None of them makes the decision for you.

## Adapt the Reference Workflow

The six-stage route is the recommended default. You may combine, skip, or adapt
stages when you can:
- Name the risk normally controlled by the stage you are skipping.
- Explain why your adaptation is appropriate.
- Show equivalent evidence that same risk is managed differently.

Document adaptations and decisions in your Stage Cards.

## Links

- **Participant Guide** (detailed authority, Stage Card operation, exception
  handling): [docs/workshop/participant-guide.md](docs/workshop/participant-guide.md)
- **Stage Cards** (your evidence spine, with guidance for each stage):
  [workshop/stage-cards/](workshop/stage-cards/)
- **Evidence Lenses** (Intent, Decisions, Evidence perspectives for reviewing
  work): [docs/workshop/evidence-lenses.md](docs/workshop/evidence-lenses.md)
- **Reciprocal Evidence Review** (structured peer review mechanics):
  [docs/workshop/reciprocal-evidence-review.md](docs/workshop/reciprocal-evidence-review.md)
- **Azure Preflight and cleanup guide** (environment setup and tear-down):
  [docs/workshop/azure-preflight-and-cleanup.md](docs/workshop/azure-preflight-and-cleanup.md)
- **Workshop Blueprint** (instructor and maintainer reference; not attendee
  action material):
  [docs/workshop-blueprint.md](docs/workshop-blueprint.md)
- **Shared workshop context** (domain language and terminology):
  [CONTEXT.md](CONTEXT.md)

## Baseline and inherited system

The default branch is the clean **Inherited System**: Spring PetClinic plus
workshop assets, without a Clinic Assistant solution.

- **Upstream**: `spring-projects/spring-petclinic`
- **Commit**: `88e37c15cf6fc8490b01bc3e8e2c800cec1ac272`
- **Local verification**: `./mvnw test`

The Reference Challenge (Clinic Assistant) is intentionally not solved on
`main`. The maintainer reference implementation is on `reference/clinic-assistant`.

See [Attendee baseline contract](docs/workshop/attendee-baseline.md) for
baseline expectations.
