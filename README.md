# Agentic Engineering Principles Workshop

This repository is the attendee template for a three-hour workshop on making
agent-assisted engineering controlled, inspectable, and adaptable.

## Create your workshop repository

1. Select **Use this template**.
2. Create a repository you control.
3. Clone that repository and follow the
   [Azure Preflight and cleanup guide](docs/workshop/azure-preflight-and-cleanup.md).
4. Read the [Participant Guide](docs/workshop/participant-guide.md) for the
   attendee-owned workflow, Stage Cards, and peer-review path.

The default branch is the clean **Inherited System**: canonical Spring
PetClinic plus workshop assets, without a Clinic Assistant solution.

## Baseline

- Upstream: `spring-projects/spring-petclinic`
- Commit: `88e37c15cf6fc8490b01bc3e8e2c800cec1ac272`
- Local verification: `./mvnw test`

The ambiguous Reference Challenge is intentionally not solved on `main`.
Maintainers keep the public reference implementation on
`reference/clinic-assistant`.

## Maintainer documentation

- [Workshop Blueprint](docs/workshop-blueprint.md)
- [Attendee baseline contract](docs/workshop/attendee-baseline.md)
- [Domain language](CONTEXT.md)
