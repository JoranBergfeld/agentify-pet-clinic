# Attendee baseline contract

`main` is the GitHub template and clean Inherited System.

It contains canonical Spring PetClinic, workshop design history, and assets
needed before an attendee begins. It must not contain Clinic Assistant
application code, Spring AI dependencies, completed Work Contracts, completed
Stage Cards, completed Reference Challenge evidence, reference answers,
generated credentials, secrets, or Azure environment state.

The template includes `AGENTS.md`, `CONTEXT.md`, attendee-first Copilot
instructions, scoped maintainer instructions, `docs/agents/` guidance, the
Clinic Stakeholder, the optional Evidence Coach, their scenario fixtures,
canonical Clinic Stakeholder knowledge, the Workshop Blueprint, and
`skills-lock.json`.

The attendee-facing operating material consists of:

- the Participant Guide;
- the Evidence Lens aid;
- the Reciprocal Evidence Review aid; and
- six blank Stage Cards, one for each Reference Workflow stage.

The Stage Cards are working templates: attendees edit them in place on their
solution branches. They must remain blank and `Status: Working` on template
`main`.

The exact supported workshop skill set is:

- `code-review`
- `codebase-design`
- `diagnosing-bugs`
- `domain-modeling`
- `grilling`
- `prototype`
- `tdd`
- `wayfinder`

Additional maintainer-only skills are stored under
`docs/agents/maintainer-skills/`, outside automatic discovery. Maintainers may
generate ignored local client projections with
`scripts/setup-maintainer-skills.sh`. Those projections and the maintainer
catalog do not expand the supported attendee skill set.

The template must not include unsupported skills or agents authorized to
approve, certify, post reviews, or make Commitment, Acceptance, Learning, or
other Risk Gate judgments.

That exclusion also covers reference-only Clinic Assistant UI assets:
`src/main/resources/templates/assistant/`, Clinic Assistant markers in the
shared layout/messages/styles baseline files, and `spring.ai.*` application
properties in `src/main/resources/application.properties`.

Completed Work Contracts, completed Stage Cards, reference answers, and worked
Reference Challenge evidence are reference-only artifacts. They must live only
under `docs/reference/`, `workshop/reference/`, or `workshop/completed/`.
Those directories are reserved for reference material and must stay absent on
template `main`. Blank templates may live elsewhere.

Baseline provenance is recorded in `workshop/baseline.properties`:

- Upstream: `https://github.com/spring-projects/spring-petclinic.git`
- Commit: `88e37c15cf6fc8490b01bc3e8e2c800cec1ac272`

Validate the boundary with:

```bash
scripts/test-maintainer-skills.sh
scripts/validate-maintainer-skills.sh
scripts/test-copilot-assets.sh
scripts/validate-copilot-assets.sh
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
./mvnw test
```

Changes land on `main` first and then merge into
`reference/clinic-assistant`. Reference solution changes never merge back to
`main`.
