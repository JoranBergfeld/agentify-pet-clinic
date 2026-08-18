# Agentic Engineering Principles Workshop Blueprint

**Status:** Decision-complete design baseline for the first-delivery Workshop Package

**Duration:** Three hours, excluding Preflight and post-workshop cleanup

**Audience:** Experienced technical practitioners who work across multiple projects and already have practical GitHub Copilot experience

## Purpose

This workshop teaches a reusable way to make agent-assisted engineering controlled, inspectable, and adaptable. Participants practice the **Agentic Engineering Principles** through a concrete **Reference Workflow** while changing an unfamiliar Spring PetClinic application.

The workshop is not general GitHub Copilot training and does not optimize for producing a polished Clinic Assistant. The product change creates consequential ambiguity, technical risk, and evidence needs that make the engineering method observable.

## Learning outcomes

By the end of the workshop, each attendee can:

1. Explain the eight Agentic Engineering Principles in terms of the risks they control.
2. Orient an Engineering Agent in an Unfamiliar Codebase using repository, domain, test, and operational evidence.
3. Expose consequential ambiguity and turn a broad request into a bounded Work Contract.
4. Delegate reversible, inspectable engineering moves without surrendering human authority.
5. Trace acceptance claims to fresh, risk-shaped evidence and make an honest Acceptance Gate judgment.
6. Use the Evidence Lenses to challenge another practitioner's evidence without taking over their implementation or certifying the result.
7. Adapt the Reference Workflow consciously across tools and projects by naming the displaced risk and equivalent evidence.
8. Extract a transferable principle, failure mode, and adaptation from the work.

## Agentic Engineering Principles

1. **Own the intent** — humans retain accountability for intent, boundaries, consequential decisions, and acceptance.
2. **Orient before acting** — load the relevant repository, domain, and operational context.
3. **Make ambiguity visible** — clarify decisions whose consequences matter; do not force certainty where exploration is appropriate.
4. **Shape before committing** — create the smallest Work Contract that makes scope, constraints, authority, and acceptance legible.
5. **Delegate within bounds** — give agents autonomy proportional to reversibility, observability, and risk.
6. **Verify against intent** — require fresh, risk-shaped evidence rather than agent confidence or ritual checklists.
7. **Capture durable learning** — retain context and decisions only when future value exceeds maintenance cost.
8. **Adapt consciously** — stages, skills, and artifacts are recommendations; explain which risk is controlled when adapting them.

The workshop uses five recurring anti-patterns as contrasts:

- **Prompt-and-pray** — delegating before shaping intent and ambiguity.
- **Agent theatre** — adding agents or artifacts without reducing risk.
- **Authority drift** — allowing the agent to make consequential decisions silently.
- **Green-by-proxy** — treating summaries or partial checks as proof.
- **Context sediment** — accumulating stale instructions rather than curating durable learning.

## Reference Workflow

**Orient → Clarify → Shape → Execute → Verify → Learn**

The stages are a recommended route, not a mandatory procedure. An attendee may combine, skip, or replace a stage or Copilot mechanic when they can name the risk normally controlled, explain why the adaptation is appropriate, and show equivalent evidence.

Use **Wayfinder** only when the destination is known but the route contains more decision fog than one bounded session can resolve. A sufficiently understood change moves directly from Clarify to a Work Contract.

### Artifact roles

The workflow defines roles rather than mandatory file types:

- **Context** — relevant facts about the code, domain, environment, and constraints.
- **Decision** — consequential choices, assumptions, deferrals, and their effects.
- **Work Contract** — intent, scope, boundaries, authority, seams, and acceptance evidence.
- **Evidence** — fresh observations supporting or weakening an acceptance claim.
- **Learning** — durable context, decisions, or lessons worth their maintenance cost.

A conversation, issue, Stage Card, specification, plan, test, ADR, or repository instruction may fulfill one or several roles.

### Risk Gates

**Commitment Gate:** Before Execute, the attendee decides whether material ambiguity, scope, Engineering Agent authority, public test seams, acceptance evidence, and consequential assumptions are legible enough to proceed, narrow, or escalate.

**Acceptance Gate:** Before claiming completion, the attendee traces each acceptance claim to fresh evidence, considers independent challenge and residual gaps, and records one of:

- **Accepted**
- **Accepted with residual gap**
- **Not yet accepted**

Passing tests, a successful deployment, or an agent summary alone cannot pass the gate.

**Learning Gate:** Before moving on, the attendee identifies what transfers beyond this solution and retains only learning whose future value exceeds its maintenance cost.

## Participant operating model

Every attendee normally works in their own isolated repository and Azure environment. They own their Work Contract, implementation, evidence, and Acceptance Gate judgment throughout.

Attendees work in pairs but do not share an implementation:

- The **Driver** directs the Engineering Agent in their own environment and owns all consequential decisions and acceptance judgments.
- The **Auditor** asynchronously critiques committed, Review-ready Stage Cards in the Driver's draft pull request.
- Each attendee remains a Driver for their implementation and temporarily acts as Auditor for their partner.
- Review occurs at natural pauses. It is not a synchronized handoff, role-rotation checkpoint, approval, or request-changes verdict.

The **Workshop Host** manages logistics, cohort timing, transitions, the final Learn discussion, and closeout. Breaks are discretionary Workshop Host logistics rather than workshop content, so there is no fixed break time. The Host does not coach engineering decisions, review participant evidence, prescribe a workflow, operate an attendee's Engineering Agent, or certify completion.

The optional **Evidence Coach** may inspect committed, Review-ready Stage Cards and produce clearly labelled, revision-specific Evidence Lens observations. It cannot replace the human Auditor, inspect private uncommitted session state, approve acceptance, prescribe the next move, or certify work.

## Evidence spine: Stage Cards

Each attendee maintains one living Markdown **Stage Card** per Reference Workflow stage in a draft solution pull request. A card combines fixed guidance with participant-owned evidence:

- **Purpose**
- **Risk controlled**
- **Minimum evidence**
- **Optional Copilot example**
- **Exit question**

Each card moves independently through **Working → Review ready → Reviewed**. New evidence or feedback may reopen a Reviewed card to Working. These states express review readiness, not pass/fail status or irreversible stage completion.

| Stage | Minimum evidence | Exit question |
| --- | --- | --- |
| Orient | An inherited-system snapshot covering local run and test paths, a concrete application and public test seam, Azure topology, observed facts, and unresolved product decisions | Do I understand enough to choose the next decision? |
| Clarify | Consequential knowns, unknowns, stakeholder uncertainty, and bounded assumptions | What must a human decide before authority is granted? |
| Shape | A Work Contract covering the chosen slice, boundaries, assumptions, Engineering Agent authority, public seams, and acceptance evidence | Is the next move safe and inspectable? |
| Execute | Stated bounded moves, expected evidence, fresh results, and the resulting continue, narrow, correct, or escalate decisions | What did this evidence change? |
| Verify | Acceptance claims traced to focused tests and real smoke or demo evidence, including residual gaps | What can I honestly accept? |
| Learn | One principle that improved the work, one risk or failure mode noticed, and one adaptation for another project or tool | What transfers beyond this solution? |

## Reciprocal Evidence Review

The Auditor reviews one or more Review-ready Stage Cards at a named commit SHA and leaves a structured pull-request comment:

1. **Intent** — the outcome and slice the evidence appears to support.
2. **Decisions** — consequential choices and assumptions visible at that revision.
3. **Evidence** — observable support for the claims.
4. **Gaps** — missing links, unsupported confidence, or residual risk.
5. **Next inspection point** — where future scrutiny would be valuable, without prescribing the Driver's next implementation move.

Peer critique is the primary independent challenge. If it has not arrived by the Acceptance Gate, the Driver may continue but must record the missing review as an explicit evidence gap.

## Evidence Lenses

The Evidence Lenses are a formative conversation aid, not a score, ranking, certification, or Host assessment.

| Lens | Visible evidence | Auditor prompt |
| --- | --- | --- |
| Intent and context | The intended staff outcome, chosen vertical slice, relevant code and test seams, starter constraints, and distinction between facts and product decisions are legible | What outcome are we owning, and what evidence says this is the right context for the next move? |
| Ambiguity and decisions | Consequential unknowns are surfaced and intentionally resolved, deferred, narrowed around, or accepted with understood consequences | What do we know, what are we assuming, and what consequence follows from that choice? |
| Work Contract and authority | Slice, boundaries, assumptions, Engineering Agent authority, public test seam, acceptance evidence, and reserved human decisions can be restated | What have we authorized the agent to decide and do, and what remains ours? |
| Bounded execution | Moves name a small behavior and expected evidence before delegation; fresh results drive an explicit decision | What is the smallest evidence-producing move, and what did its result change? |
| Verification and learning | Acceptance claims trace to fresh tests and smoke evidence; gaps and residual risks are honest; learning follows from what happened | Which claim does this evidence support, what gap remains, and what would we adapt elsewhere? |

Each lens uses one diagnostic state:

- **Visible** — current evidence supports the control and the attendee can explain it.
- **Fragile** — intent exists, but evidence, ownership, or traceability has a meaningful gap.
- **Missing** — the control cannot be shown or relies on agent confidence or feature output alone.

A Fragile or Missing observation must lead the Driver to repair the evidence, narrow the slice, accept the residual risk explicitly at the relevant gate, or escalate. No Missing lens is silently ignored.

## Reference Challenge

### Initial participant brief

The externally delivered brief deliberately preserves broad customer scope and incomplete requirements. Participants query the repository-scoped **Clinic Stakeholder** for available product knowledge, but the stakeholder may honestly report uncertainty. Different bounded interpretations are valid when they remain inside the fixed safety envelope and produce comparable process evidence.

At the Commitment Gate, each attendee narrows their Work Contract to the smallest evidence-producing vertical slice they can inspect and accept. The desired end state remains broad; only the authorized workshop slice narrows.

### Fixed safety and architecture envelope

- Staff-facing and read-only.
- One Spring Boot process.
- A framework-agnostic read-only query boundary exposes purpose-built records rather than repositories or JPA entities.
- The default, preflight-proven integration is Spring AI 2.0 using a Microsoft Foundry resource through its OpenAI-compatible endpoint.
- An alternative Java integration is valid when the attendee explains the trade-off, preserves the read-only query and tool boundary, and can produce equivalent local and deployed evidence.
- No write tools, RAG, Azure AI Search, Foundry project, Foundry Agent Service, additional database, or persistent transcript store.
- The assistant answers only from retrieved PetClinic data, admits absent records and unsupported requests, never guesses identity, never claims mutation, and never gives veterinary diagnosis or treatment advice.
- Authentication, authorization, privacy controls, auditing, prompt-injection hardening, production observability, persistent conversations, scheduling, writes, and medical advice remain explicit residual risks outside the vertical slice.

### Desired capability families

1. Find owners by name and describe their pets.
2. Find pets and summarize recorded Visits.
3. List veterinarians and answer specialty questions.

The bounded workshop slice need not complete all three families. A staff-accessible chat option is required, while the exact UI surface remains a product decision. Multiple matches must produce candidates and a clarifying question. The UI exposes concise tool-call and outcome activity, never chain-of-thought.

### Reference acceptance evidence

- Direct tests for the read-only query facade and tool contracts.
- Mock-model tests for the endpoint, session memory and reset, tool registration, unsupported behavior, and activity trace.
- Deployed smoke evidence for the capability claims authorized by the attendee's Work Contract.
- Where applicable, smoke coverage includes a known query, ambiguous-name clarification, and an unsupported or medical-advice request.
- Evidence records focused test output, relevant answers and activity traces, the deployed URL, and precise residual gaps.

## Inherited System and Supported Environment

Participants receive a clean, isolated starter based on canonical Spring PetClinic. Before the workshop, Preflight proves operation without teaching the architecture:

- the application and tests run locally;
- repository Copilot assets load in the chosen client;
- `azd up` succeeds;
- the deployed PetClinic URL is reachable; and
- the working tree starts at the named clean baseline.

The pre-work instructions provide exact operational steps but deliberately do not explain the code, App Service, Foundry/model topology, deployment route, or managed-identity boundary. Reconstructing that Inherited System is part of Orient.

### Required attendee baseline

- Comfortable navigating an unfamiliar codebase, using Git and a terminal, and running tests.
- Prior practical GitHub Copilot use.
- Individual GitHub account, repository access, Copilot entitlement, and organization policy permitting agent mode and repository customizations.
- Individual Azure subscription with the documented resource permissions and accepted cost envelope.
- Git, `gh`, `az`, `azd`, Java 17 or newer, and the repository Maven wrapper.

Deep Java and Spring Boot expertise is not required.

### Supported Copilot clients and assets

- **Reference:** VS Code with GitHub Copilot Chat in agent mode.
- **Fully supported alternative:** GitHub Copilot CLI.
- **Preflight-proven alternative:** JetBrains agent mode, acknowledging custom-agent preview status.
- Other clients are attendee-supported only after proving that they consume the workshop repository instructions, custom agents, and skills.

The portable repository asset set is `.github/copilot-instructions.md`, scoped instructions, root `AGENTS.md`, custom agents, and agent skills. Prompt files are not part of the core path.

### Azure baseline

- Azure App Service Basic B1 on Linux with Java 21.
- Executable Spring Boot JAR deployment through a pre-authored `azd` template.
- Projectless Microsoft Foundry `AIServices` resource with local authentication disabled.
- Resource-scoped managed identity using the Foundry User role.
- `gpt-5.4-mini` 2026-03-17 on Global Standard at the validated baseline, subject to delivery-date availability and quota.
- One resource group and one `azd` environment per attendee.

The attendee-facing Azure envelope must be date-stamped and refresh region, model availability, quota, prices, roles, providers, cost controls, and cleanup behavior before each delivery.

## Three-hour learning arc

Stage times are cadence guidance, not per-stage deadlines. The externally delivered opening, start of the final Learn exchange, and workshop close are protected cohort anchors. Attendees flex the middle stages and progress to different implementation depths.

| Time | Block | Participant practice and evidence |
| --- | --- | --- |
| 0:00–0:15 | Opening | Delivered outside the Workshop Package and repository. |
| 0:15–0:35 | Orient | Reconstruct the Inherited System and create the Orient Stage Card using code, test, local, deployed, and agent-client evidence. |
| 0:35–0:55 | Clarify | Query the Clinic Stakeholder, distinguish facts from product decisions, expose uncertainty, and record bounded assumptions without manufacturing certainty. |
| 0:55–1:10 | Shape and Commitment Gate | Create the smallest useful Work Contract, assess the first three Evidence Lenses, and decide to proceed, narrow, or escalate. |
| 1:10–2:25 | Execute with progressive review | Each attendee drives their own bounded evidence loop. Stage Cards become Review ready progressively; partners perform Reciprocal Evidence Review asynchronously at natural pauses without a fixed review window. |
| 2:25–2:40 | Verify and Acceptance Gate | Trace claims to fresh local and deployed evidence, consider peer or Evidence Coach observations, record residual gaps, and make an individual acceptance judgment. |
| 2:40–3:00 | Learn | Record a principle, risk, and adaptation. Each pair selects its strongest or most surprising learning for the room while the Workshop Host clusters themes and closes on time. |

## Exception paths

### One attendee environment fails

This is an exception, not the delivery model. The affected attendee self-remediates while the pair preserves learning through the working environment and asynchronous review. Account sharing is never permitted. The Host protects cohort timing rather than pausing the room.

### Peer review has not arrived

The Driver continues without blocking. At the Acceptance Gate, missing independent challenge is recorded as an explicit evidence gap.

### Product requirements remain incomplete

The Driver may make a bounded assumption, narrow around the uncertainty, defer it, or escalate. The decision and consequence must be legible in the Work Contract and evidence.

### Implementations diverge

Divergent Work Contracts, frameworks, UI surfaces, and implementation depth are acceptable within the fixed safety envelope. Compare disciplined intent, authority, evidence, and adaptation rather than product sameness.

### The vertical slice is incomplete

Stop on time. Record the strongest available evidence, the exact unfinished gap, and an honest acceptance judgment. Incomplete work can demonstrate strong agentic engineering; concealed gaps cannot.

### Local evidence passes but deployed smoke fails

Use a short evidence-led diagnosis. If the failure remains or lies outside the authorized change, record the missing deployed claim and continue to the Acceptance Gate. Local tests do not substitute for deployed evidence.

### An Evidence Lens is Fragile or Missing

Repair the evidence, narrow the claim, accept the residual risk explicitly, or escalate. Do not cosmetically upgrade the state to preserve completion.

### A safety boundary is threatened

The Driver stops the affected work. The Host may intervene only to restore a missed fixed safety boundary, not to choose the implementation.

## Workshop success criteria

The workshop succeeds when:

- attendees can explain the risks controlled by the principles and workflow rather than merely repeat stage names;
- every attendee owns a separate Work Contract, implementation path, evidence trail, and acceptance judgment;
- Stage Cards make intent, decisions, authority, execution evidence, and residual gaps inspectable;
- Reciprocal Evidence Review challenges evidence without transferring ownership or acting as approval;
- adaptations name the displaced risk and equivalent evidence;
- incomplete or failed paths produce precise, honest evidence rather than hidden failure;
- each attendee completes Learn with a transferable principle, risk, and adaptation; and
- protected cohort anchors and the three-hour boundary are maintained.

Feature completion, identical implementations, perfect Evidence Lens profiles, and successful Azure smoke evidence for every attendee are desirable but are not the sole measures of learning success.

## Outcome-to-practice-to-evidence traceability

| Learning outcome | Required participant practice | Observable evidence |
| --- | --- | --- |
| Explain principles through controlled risks | Encounter contrastive anti-patterns and name the control before applying it | Stage Card rationale, gate discussion, and Learn reflection use risk language rather than tool ritual |
| Orient in an Unfamiliar Codebase | Inspect repository guidance, code, public tests, local operation, Azure topology, and client constraints | Orient Stage Card and Evidence Lens observation distinguish facts, seams, and unresolved decisions |
| Turn ambiguity into a Work Contract | Query the Clinic Stakeholder, surface uncertainty, choose a bounded slice, and reserve consequential authority | Clarify and Shape Stage Cards plus Commitment Gate judgment |
| Delegate within bounds | State a small behavior and expected evidence before each Engineering Agent move; inspect fresh results | Execute Stage Card entries show bounded moves and resulting continue, narrow, correct, or escalate decisions |
| Verify against intent | Trace each accepted claim to focused tests and a real smoke or demo path where applicable | Verify Stage Card, test output, activity evidence, deployed URL or explicit missing claim, and Acceptance Gate judgment |
| Critique evidence without taking ownership | Review committed Stage Cards at a named revision using the five review headings and Evidence Lenses | Revision-specific Reciprocal Evidence Review comment and Driver response or recorded unresolved gap |
| Adapt consciously | Replace, combine, or skip a stage or mechanic while naming the controlled risk and equivalent evidence | Work Contract, Stage Card, review comment, or Learn reflection explains the adaptation |
| Capture transferable learning | Reflect on what actually happened and share one principle, risk, and adaptation | Learn Stage Card and final pair contribution |

## Workshop Package handoff contract

This blueprint is the canonical design input for the remaining Workshop Package. Finished delivery assets remain separate and must implement, not duplicate or silently redefine, this document:

- participant guide or workbook;
- Workshop Host runbook;
- attendee starter baseline and reference solution or evidence path;
- repository Copilot instructions, skills, Clinic Stakeholder, and optional Evidence Coach;
- Stage Card, Evidence Lens, and Reciprocal Evidence Review aids;
- Preflight and cleanup automation and checklists;
- Azure deployment assets; and
- full-duration dry-run and acceptance evidence.

All content used to deliver the opening, including the presentation deck and initial participant brief, is outside repository scope.

Any downstream design change must record its rationale, affected learning outcomes and evidence, and the validation scenarios that must be rerun. The two workshop owners jointly accept a versioned Workshop Package baseline only after traceability review, a complete three-hour owner dry run in separate environments, remediation, and targeted reruns of failed slices.

These amendments do not change the learning outcomes or attendee evidence requirements. The complete three-hour owner dry run must verify the Host boundary after the external opening, discretionary break handling, and the 3-5-minute-per-team Learning rate.

## Decision sources

This blueprint consolidates the settled decisions in:

- [Define the Agentic Engineering Principles and Reference Workflow](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/2)
- [Set participant prerequisites and the supported GitHub Copilot environment](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/4)
- [Choose the Reference Challenge](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/5)
- [Map GitHub Copilot workflows to the portable principles](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/6)
- [Design the three-hour learning arc](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/7)
- [Define success evidence and the Driver-Auditor rubric](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/8)
- [Rehearse the compressed workshop loop](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/9)
- [Set blueprint acceptance and handoff criteria](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/10)
- [Define stage guidance, Reciprocal Evidence Review, and Evidence Coach feedback](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/18)

Technical boundaries are supported by the linked research and prototype evidence recorded on the workshop map.
