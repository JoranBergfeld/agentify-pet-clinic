# Workshop Copilot Assets Design

## Purpose

Provide a portable, attendee-facing Copilot asset set that supports the
Reference Workflow without turning it into a mandatory procedure or allowing
an agent to replace human judgment.

The assets must work in the reference VS Code agent-mode client and the fully
supported Copilot CLI alternative. They must remain inspectable as repository
content, load in generated attendee repositories, and preserve peer critique as
the primary independent challenge.

## Guidance architecture

The root guidance is optimized for workshop attendees:

- `AGENTS.md` provides client-neutral authority boundaries, the Reference
  Workflow entry points, and links to the relevant workshop guidance.
- `.github/copilot-instructions.md` adds Copilot-specific operating guidance,
  including Work Contract boundaries, Risk Gate behavior, Stage Card evidence
  expectations, and explicit failure behavior.
- `.github/instructions/repository-maintenance.instructions.md` contains
  scoped issue-tracker, Workshop Package maintenance, and skill-authoring rules
  that should not distract an attendee working on the Reference Challenge.

The root files share concepts through links rather than duplicating long
instructions. They use the domain vocabulary in `CONTEXT.md` and make clear
that stages, skills, and artifacts are adaptable risk controls rather than
compliance steps.

## Engineering Agent authority

Repository guidance requires the Engineering Agent to:

- orient to the Inherited System before proposing changes;
- make facts, assumptions, uncertainty, and consequential decisions legible;
- operate only inside the current Work Contract and stated bounded move;
- name expected evidence before execution;
- expose failures and missing evidence rather than supplying a
  success-shaped fallback;
- preserve the fixed safety and architecture envelope for the Clinic
  Assistant; and
- stop at the Commitment, Acceptance, and Learning Gates for a human judgment.

The Engineering Agent may propose options, implementation moves, tests, and
evidence. It may not silently narrow the intended outcome, expand its
authority, accept residual risk, certify completion, or decide that a Risk
Gate has passed.

## Clinic Stakeholder

Add `.github/agents/clinic-stakeholder.agent.md` as a repository-scoped custom
agent. Its authoritative product knowledge lives in the separate,
human-inspectable `docs/workshop/clinic-stakeholder-knowledge.md`.

The knowledge document distinguishes:

- the broad participant brief;
- fixed product and safety facts;
- available stakeholder preferences or examples;
- deliberately unresolved product decisions; and
- facts the stakeholder does not know.

The Clinic Stakeholder answers only from that document and the named Reference
Challenge context. It separates known facts from uncertainty, states when the
available knowledge does not answer a question, and may explain the consequence
of leaving an ambiguity unresolved. It does not invent requirements, choose a
bounded slice, cross the Commitment Gate, or make a consequential product
decision for the Driver.

If the knowledge document is missing, inaccessible, contradictory, or silent
on the question, the agent reports that limitation explicitly. It does not
infer an authoritative answer from general PetClinic behavior or model
knowledge.

## Evidence Coach

Add `.github/agents/evidence-coach.agent.md` as an optional custom agent. It
accepts explicit Stage Card paths and a commit SHA, then inspects only committed
content at that revision.

Its output is a clearly labelled draft for the attendee to inspect and
optionally post. It uses:

1. **Intent**
2. **Decisions**
3. **Evidence**
4. **Gaps**
5. **Next inspection point**

The draft may add Visible, Fragile, or Missing observations through the five
Evidence Lenses. Every observation identifies the Stage Card and revision it
used.

The Evidence Coach does not post to GitHub, inspect uncommitted private session
state, replace the human Auditor, issue an approval or request-changes verdict,
make the Acceptance judgment, prescribe the Driver's next implementation move,
or certify work. If the card path, revision, committed content, or relevant
evidence is unavailable, it requests the missing input and produces no review.

## Curated workshop skill set

The attendee baseline exposes only these capability-oriented skills:

- `grilling`
- `domain-modeling`
- `wayfinder`
- `codebase-design`
- `prototype`
- `tdd`
- `diagnosing-bugs`
- `code-review`

The guidance maps these skills to risks and situations, not to mandatory
workflow stages. Orient and ordinary bounded implementation use the Engineering
Agent directly. Shape may be expressed as a Work Contract in the Stage Card
without requiring a specification skill. Learn remains a human reflection and
does not require a retained agent artifact.

Skills outside this set are excluded from the attendee baseline rather than
left discoverable but unsupported. The retained skills must remain internally
coherent: links and skill references may point only to retained assets or
clearly optional external capabilities.

## Validation

Add `scripts/validate-copilot-assets.sh` and focused automated tests. The
validator checks:

- every required instruction, custom-agent, and knowledge file exists;
- custom-agent frontmatter and names follow the supported GitHub Copilot
  structure;
- internal links and referenced repository paths resolve;
- `.github/skills/` contains exactly the supported skill set;
- retained skills do not depend on removed repository skills;
- the Clinic Stakeholder is grounded in the canonical knowledge document;
- the Evidence Coach requires committed Stage Cards and a named revision; and
- prohibited authority claims such as agent approval, certification,
  acceptance, automatic posting, or silent decision-making are absent.

Behavior fixtures cover:

- a Clinic Stakeholder answer grounded in a known fact;
- an explicit stakeholder uncertainty;
- a request that would require the stakeholder to make a human decision;
- missing or invalid Evidence Coach card and revision inputs;
- the revision-specific review structure;
- non-authoritative Evidence Lens wording; and
- refusal to inspect uncommitted evidence.

The existing template validators invoke the Copilot asset validator so a
generated attendee repository cannot silently omit, broaden, or break the
supported asset set.

Validation failures name the exact asset and broken contract. Unknown or
uncheckable conditions are failures, not warnings that permit a green result.

## Out of scope

- A single conductor agent that drives the entire Reference Workflow.
- One wrapper skill per Reference Workflow stage.
- Prompt files in `.github/prompts/`.
- Automatic pull-request comments from the Evidence Coach.
- Agent approval, scoring, certification, or replacement of Reciprocal
  Evidence Review.
- Teaching every available Copilot customization or preserving the current
  development-time skill library in the attendee baseline.
