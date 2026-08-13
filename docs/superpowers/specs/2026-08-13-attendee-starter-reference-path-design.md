# Attendee Starter and Reference Path Design

## Purpose

Turn this repository into the GitHub template for the Agentic Engineering
Principles workshop while preserving a complete, maintained Clinic Assistant
reference implementation on a separate branch.

The template must give each attendee a clean, isolated Inherited System based
on canonical Spring PetClinic. It must preserve the Reference Challenge's
ambiguity while making the proven technical seams and acceptance evidence
available to workshop maintainers.

## Repository topology

### Template branch

`main` is the attendee template and the repository's default branch. It is
rooted in canonical Spring PetClinic commit
`88e37c15cf6fc8490b01bc3e8e2c800cec1ac272` and retains the Workshop Blueprint
and historical planning and design artifacts.

The repository is configured as a GitHub template. Attendees select **Use this
template** to create repositories they control. A generated repository starts
from `main` with a clean working tree and without the Clinic Assistant
implementation.

Later Workshop Package tickets add participant guidance, Copilot assets,
Azure and Preflight automation, cleanup support, and delivery materials to
`main`. This design establishes the application baseline and branch boundary;
it does not duplicate those tickets' responsibilities.

### Reference branch

`reference/clinic-assistant` branches from `main` and contains the complete
maintained Clinic Assistant reference implementation and its evidence.

The branch is publicly discoverable in the source template repository. That is
an accepted trade-off: the reference is a maintainer and recovery aid, not a
secret answer key. GitHub template generation uses `main` by default, so the
reference implementation is not copied into attendee repositories unless the
attendee deliberately includes or fetches it.

### Prototype branch

`prototype/azure-deployment-slice` remains immutable historical evidence for
the Azure and Spring AI feasibility decision. It is not renamed or merged
wholesale into the permanent reference branch.

Reusable application ideas may be adapted from the prototype. Prototype-only
shortcuts, disposable infrastructure, and evidence harnesses must not define
the maintained reference architecture.

## Attendee baseline

The attendee baseline on `main` contains:

- the canonical Spring PetClinic application and its existing tests;
- an explicit provenance record naming the upstream repository and commit;
- the Workshop Blueprint;
- historical planning, research, prototype design, and implementation-plan
  artifacts already retained by the workshop repository; and
- a maintainer-facing baseline contract describing the attendee/reference
  separation and its validation rules.

The baseline contains none of the following:

- Clinic Assistant application code or Spring AI application dependencies;
- a completed Work Contract for the Reference Challenge;
- completed Stage Cards or worked Reference Challenge evidence;
- reference model responses or expected participant conclusions;
- generated credentials, tokens, Azure environment files, or live resource
  identifiers.

The initial participant brief remains:

> PetClinic staff need a chatbot that helps them answer questions about owners,
> pets, Visits, and veterinarians. Add a Clinic Assistant to the existing
> application.

Participant-facing instructions may expose fixed safety and architecture
boundaries settled by the Workshop Blueprint, but must not pre-solve product
decisions that participants are expected to Clarify and Shape.

## Reference implementation

The reference branch implements the complete bounded Clinic Assistant path
defined by the Workshop Blueprint:

- a framework-agnostic, read-only query facade returning purpose-built records
  rather than repositories or JPA entities;
- tools for finding owners and describing their pets, finding pets and
  summarizing recorded Visits, and listing veterinarians and specialties;
- explicit multiple-match results that support clarification rather than
  guessed identity;
- Spring AI chat orchestration using configuration compatible with the
  preflight-proven Microsoft Foundry endpoint;
- session-scoped in-memory conversation state and reset;
- a staff-accessible UI integrated with PetClinic navigation;
- concise tool-call and outcome activity without chain-of-thought;
- explicit handling for absent records, unsupported requests, attempted
  mutation, and veterinary diagnosis or treatment requests; and
- no write tools, RAG, Azure AI Search, Foundry project, Foundry Agent Service,
  additional database, or persistent transcript store.

The implementation preserves one Spring Boot process and keeps Spring AI
behind the read-only application boundary. Azure deployment, Preflight, and
cleanup automation are owned by **Build the workshop Azure, Preflight, and
cleanup path** and are integrated into the reference branch after that work
lands on `main`.

## Evidence path

The reference branch provides reproducible evidence for the claims authorized
by the Workshop Blueprint:

- direct tests for the read-only query facade and tool contracts;
- mock-model tests for endpoint behavior, session memory and reset, tool
  registration, unsupported behavior, and activity reporting;
- UI-boundary tests for the staff-accessible chat path;
- full canonical PetClinic regression tests;
- scripted local reference scenarios;
- deployed smoke scenarios once the shared Azure path is available; and
- a redacted evidence record naming commands, commit revisions, relevant
  outputs, observed gaps, and the deployed URL where applicable.

The evidence scenarios cover at least:

1. a known query for each implemented capability family;
2. an ambiguous-name result requiring clarification;
3. an unsupported or attempted-write request;
4. a veterinary diagnosis or treatment request; and
5. reset of session-scoped conversation state.

Evidence must not contain credentials, access tokens, private model inputs,
sensitive data, generated Azure environment files, or reusable live resource
identifiers.

## Isolation validation

The attendee/reference separation is enforced by executable validation rather
than repository convention alone.

Validation on `main` proves:

- the provenance record names the intended canonical baseline;
- the Maven build and canonical PetClinic test suite pass;
- no reference-only application package or Spring AI application dependency is
  present;
- no completed participant evidence or generated secret-bearing files are
  tracked; and
- the repository is configured as a GitHub template.

Template validation creates a disposable repository from this template,
clones it, confirms the expected initial branch and clean working tree, and
runs the baseline build and tests. The disposable repository is deleted after
the validation result is captured.

Validation on `reference/clinic-assistant` proves:

- the branch contains current `main`;
- canonical PetClinic regression tests pass;
- focused Clinic Assistant tests pass;
- scripted local acceptance scenarios pass; and
- deployed smoke evidence passes when the Azure path is available.

No validation fallback may turn a missing model, failed test, unavailable
deployment, or incomplete smoke scenario into a successful claim. The
evidence must identify which gate failed and preserve the strongest truthful
result.

## Maintenance flow

Baseline and Workshop Package changes flow one way:

1. Land canonical baseline and workshop asset changes on `main`.
2. Merge current `main` into `reference/clinic-assistant`.
3. Resolve reference conflicts without moving solved Clinic Assistant content
   back to `main`.
4. Run baseline, focused reference, and applicable deployed validation.
5. Record the validated revisions in the reference evidence.

Reference implementation changes never merge back into `main`. If a useful
generic improvement is discovered on the reference branch, it must be
re-authored as an explicit attendee-baseline change and reviewed against the
ambiguity boundary before landing on `main`.

## Success criteria

This design is implemented when:

- this repository is a GitHub template whose default `main` branch is a clean
  canonical PetClinic attendee baseline;
- a newly generated attendee repository builds, tests, and starts from the
  named clean baseline without Clinic Assistant solution code;
- `reference/clinic-assistant` contains a runnable complete reference
  implementation aligned with the Workshop Blueprint;
- the baseline and reference branches have executable guards against solution
  leakage and reference drift;
- the reference evidence path is reproducible and redacted; and
- the historical Azure prototype remains available as decision evidence
  without becoming the permanent reference architecture.

## Out of scope

- Participant guidance, Stage Card templates, and Reciprocal Evidence Review
  aids owned by **Author participant guidance and Reciprocal Evidence Review
  aids**.
- Repository Copilot instructions, skills, Clinic Stakeholder, and Evidence
  Coach assets owned by **Create the workshop Copilot agents and repository
  guidance**.
- Azure deployment, Preflight, cleanup, and cost-envelope automation owned by
  **Build the workshop Azure, Preflight, and cleanup path**.
- Workshop Host guidance, presentation materials, full Workshop Package
  integration, and the three-hour owner dry run.
- Production hardening of the Clinic Assistant beyond the Workshop Blueprint's
  fixed safety and architecture envelope.
