# Agentic Engineering Principles Workshop

This repository is the attendee template for a three-hour workshop on making
agent-assisted engineering controlled, inspectable, and adaptable.

## Your challenge

Add a Clinic Assistant to the existing Spring PetClinic application. The
assistant will help clinic staff find information about owners, pets, Visits,
and veterinarians.

The requirements are not complete. During the workshop, ask the Clinic
Stakeholder what is known and what is still unclear. Then choose one small
capability that you can build, test, and review within the available time.

Read the [Participant Guide](docs/workshop/participant-guide.md) for the safety
boundaries, workflow, and evidence you need to collect.

## Setup

1. Select **Use this template**.
2. Create a repository you control.
3. Complete the local and Azure setup below.

### Local setup

Choose one environment:

- [Run on your computer](docs/workshop/local-setup.md#option-1-run-on-your-computer)
- [Run in a Codespace](docs/workshop/local-setup.md#option-2-run-in-a-codespace)

Both options verify the inherited application locally before the workshop.

### Azure setup

After completing local setup, follow the
[Azure Preflight and cleanup guide](docs/workshop/azure-preflight-and-cleanup.md).
Then read the [Participant Guide](docs/workshop/participant-guide.md).

The `main` branch has the starting application. It does not include the
completed Clinic Assistant.

## Baseline

- Upstream: `spring-projects/spring-petclinic`
- Commit: `88e37c15cf6fc8490b01bc3e8e2c800cec1ac272`

The example solution is on the `reference/clinic-assistant` branch.

## Maintainer documentation

- [Workshop Blueprint](docs/workshop-blueprint.md)
- [Attendee baseline contract](docs/workshop/attendee-baseline.md)
- [Domain language](CONTEXT.md)
