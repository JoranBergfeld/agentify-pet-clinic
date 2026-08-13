# Attendee baseline contract

`main` is the GitHub template and clean Inherited System.

It contains canonical Spring PetClinic, workshop design history, and assets
needed before an attendee begins. It must not contain Clinic Assistant
application code, Spring AI dependencies, completed Work Contracts, completed
Stage Cards, completed Reference Challenge evidence, reference answers,
generated credentials, secrets, or Azure environment state.

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
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
./mvnw test
```

Changes land on `main` first and then merge into
`reference/clinic-assistant`. Reference solution changes never merge back to
`main`.
