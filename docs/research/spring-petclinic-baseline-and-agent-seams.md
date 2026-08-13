# Spring PetClinic Baseline and Candidate Agent Seams

Research for [Identify the Spring PetClinic baseline and candidate agent seams](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/3), verified against official sources at commit [`88e37c15`](https://github.com/spring-projects/spring-petclinic/commit/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272).

## Recommendation

Use [`spring-projects/spring-petclinic`](https://github.com/spring-projects/spring-petclinic) on its canonical `main` branch.

The project identifies this repository as the canonical Spring Boot and Thymeleaf implementation. It is a single-module application with an in-memory H2 default, a bundled Maven wrapper, a GitHub Codespaces entry point, and existing controller tests. These properties keep infrastructure and framework novelty out of a three-hour workshop.

Do not use a microservices or other community variant for the initial workshop. Their additional topology and setup would compete with the workshop's focus on the Agentic Engineering Principles and Reference Workflow.

## Setup constraints

| Constraint | Verified baseline |
| --- | --- |
| Java | Java 17 minimum; the devcontainer selects Java 21 Oracle |
| Spring Boot | Parent version 4.1.0 |
| Build | `./mvnw spring-boot:run` or `./gradlew bootRun` |
| Database | H2 by default; no external database is required |
| Browser environment | Official README links directly to GitHub Codespaces |
| Quality gates | Spring Java Format and Checkstyle are configured in Maven |
| Verification | Existing controller tests cover owners, pets, visits, and vets |

A Codespaces-first setup is the lowest-risk workshop default. A local fallback needs Java 17 or newer and a working Git environment.

## Candidate agent-assisted seams

### 1. Visit booking lead-time rule

**Prompt shape:** "Visits must be booked sufficiently in advance."

The current controller exposes tomorrow as the minimum date and rejects dates that are not after today. "Sufficiently in advance" creates useful ambiguity around calendar days, business days, time zones, and emergency exceptions.

- **Size:** Small; controller, tests, and possibly a focused policy abstraction.
- **Verification:** Existing `VisitControllerTests` provide a natural surface.
- **Pedagogical value:** High. It requires clarification and edge-case specification before implementation.
- **Distraction risk:** Low. No new infrastructure or integration is necessary.

**Recommended Reference Challenge candidate.**

### 2. Visit description quality

**Prompt shape:** "Visit descriptions must be clinically meaningful."

The model currently requires only a non-blank description. "Clinically meaningful" is intentionally subjective and forces participants to turn vague language into a bounded, testable rule.

- **Size:** Small after clarification.
- **Verification:** Boundary tests can be added around the selected rule.
- **Pedagogical value:** Very high for ambiguity handling.
- **Distraction risk:** Low, provided participants reject unnecessary AI classification.

### 3. Owner telephone validation

**Prompt shape:** "Owner telephone numbers must be valid."

The current model accepts exactly ten digits. "Valid" raises questions about countries, formatting, normalization, and whether a specialist library belongs in scope.

- **Size:** Very small.
- **Verification:** Straightforward validation tests.
- **Pedagogical value:** Good, although discussion can become domain bikeshedding.
- **Distraction risk:** Moderate if participants introduce a dependency.

### 4. Owner search page-size preference

**Prompt shape:** "Owner search should remember the preferred page size."

The controller currently hard-codes a page size of five. "Remember" implies identity and persistence, which the application does not currently provide.

- **Size:** Small only if bounded to a request parameter or session.
- **Verification:** Existing owner controller tests are suitable.
- **Pedagogical value:** Good for exposing hidden scope.
- **Distraction risk:** Moderate because authentication and persistence can expand the work.

### 5. Vet endpoint availability

**Prompt shape:** "The vets endpoint should include availability."

The current vets endpoint returns a JSON representation, but the domain has no scheduling or availability model.

- **Size:** Potentially large.
- **Verification:** Requires defining a new contract and tests.
- **Pedagogical value:** Good for discovering missing domain concepts.
- **Distraction risk:** High because scheduling and external calendar concerns can dominate.

## Ranked shortlist

1. **Visit booking lead-time rule** - best ambiguity-to-size ratio and strongest existing verification surface.
2. **Visit description quality** - strongest deliberate ambiguity with minimal technical scope.
3. **Owner telephone validation** - compact and testable, with manageable dependency risk.
4. **Owner search page-size preference** - useful hidden-scope exercise but prone to persistence expansion.
5. **Vet endpoint availability** - valuable domain discussion, but too likely to exceed the workshop envelope.

## Implications for the map

- [Choose the Reference Challenge](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/5) should compare the first two candidates against the emerging Agentic Engineering Principles and Reference Workflow.
- [Set participant prerequisites and the supported GitHub Copilot environment](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/4) should decide whether Codespaces is the primary path and define the local fallback.
- The exact participant-facing wording of the Reference Challenge remains downstream of selecting the seam and deciding how much ambiguity the learning arc can support.

## Primary sources

- [Canonical repository README](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/README.md)
- [Maven build and Java requirements](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/pom.xml)
- [Default H2 configuration](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/src/main/resources/application.properties)
- [Development container](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/.devcontainer/devcontainer.json)
- [Visit controller date rule](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/src/main/java/org/springframework/samples/petclinic/owner/VisitController.java)
- [Visit model description](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/src/main/java/org/springframework/samples/petclinic/owner/Visit.java)
- [Owner telephone validation](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/src/main/java/org/springframework/samples/petclinic/owner/Owner.java)
- [Owner search pagination](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/src/main/java/org/springframework/samples/petclinic/owner/OwnerController.java)
- [Vet JSON endpoint](https://github.com/spring-projects/spring-petclinic/blob/88e37c15cf6fc8490b01bc3e8e2c800cec1ac272/src/main/java/org/springframework/samples/petclinic/vet/VetController.java)
- [Official PetClinic variants index](https://spring-petclinic.github.io/docs/forks.html)
