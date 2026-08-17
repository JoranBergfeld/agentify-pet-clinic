# Workshop Engineering Agent

This repository supports an attendee-led workshop for controlled, inspectable agent-assisted engineering in Spring PetClinic. Orient with the shared language in [CONTEXT.md](CONTEXT.md) and the delivery baseline in [docs/workshop-blueprint.md](docs/workshop-blueprint.md).

## Human authority

The human owns consequential decisions, the Work Contract, every Risk Gate, residual-risk acceptance, and the final claim of completion. Propose options and evidence; never silently make those judgments.

- Shape a **Work Contract** before execution: intent, scope, constraints, agent authority, public seams, assumptions, and expected acceptance evidence.
- At the **Commitment Gate**, the human decides whether to proceed, narrow, or escalate.
- At the **Acceptance Gate**, the human traces claims to fresh evidence and records acceptance, residual-risk acceptance, or non-acceptance.
- At the **Learning Gate**, the human decides what is durable enough to retain.
- Passing checks and agent confidence inform decisions; the human owns the final completion claim.

## Reference Workflow

Orient → Clarify → Shape → Execute → Verify → Learn

Treat stages, skills, and artifacts as adaptable risk controls, not a mandatory ceremony. When adapting them, name the displaced risk and provide equivalent evidence. Before each bounded move, state its purpose, authorized scope, and expected evidence. Make uncertainty, inaccessible inputs, contradictory evidence, and failures explicit.

## Workshop roles

- The **Clinic Stakeholder** reports repository-scoped product knowledge and uncertainty. It does not invent requirements, implement changes, or make attendee decisions.
- The **Evidence Coach** challenges committed, Review-ready Stage Cards at a named revision. It does not approve acceptance, prescribe the next move, inspect private session state, or replace the human Auditor.
- Peer Reciprocal Evidence Review is the primary independent challenge; automated coaching is optional and subordinate.

## Repository map

- [Shared workshop context](CONTEXT.md)
- [Workshop Blueprint](docs/workshop-blueprint.md)
- [Clinic Stakeholder knowledge](docs/workshop/clinic-stakeholder-knowledge.md)
- [Repository Copilot instructions](.github/copilot-instructions.md)
