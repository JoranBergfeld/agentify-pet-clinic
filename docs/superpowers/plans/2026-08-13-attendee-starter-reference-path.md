# Attendee Starter and Reference Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert this repository into the canonical Spring PetClinic workshop template on `main` and add a complete, maintained Clinic Assistant implementation on `reference/clinic-assistant`.

**Architecture:** Merge the canonical Spring PetClinic baseline into the existing workshop history, then enforce the attendee/reference boundary with executable guards and a disposable template-generation check. Build the reference implementation on a branch from `main`, with a read-only query facade, thin Spring AI tools, session-scoped conversation state, a Thymeleaf UI, focused tests, and redacted evidence.

Keep `prototype/azure-deployment-slice` unchanged at its validated evidence
revision; reuse ideas selectively rather than merging that disposable branch
into either maintained branch.

**Tech Stack:** Git/GitHub templates, Java 17+, Spring Boot 4.1.0, Spring AI 2.0.0, Thymeleaf, Maven, Bash, GitHub Actions, GitHub CLI.

---

## File structure

### Template `main`

- `README.md` — attendee entry point and template creation route.
- `workshop/baseline.properties` — machine-readable canonical baseline provenance.
- `docs/workshop/attendee-baseline.md` — maintainer contract for what belongs on `main`.
- `scripts/validate-template-baseline.sh` — structural solution-leakage guard.
- `scripts/test-template-baseline-validator.sh` — shell regression tests for the guard.
- `scripts/validate-template-generation.sh` — manual disposable-template validation.
- `.github/workflows/validate-template.yml` — baseline build and isolation CI.
- `.gitignore` — canonical PetClinic ignores plus `.worktrees/`.

### `reference/clinic-assistant`

- `pom.xml` — Spring AI and Azure Identity dependencies.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicQueryService.java` — framework-agnostic read-only application boundary.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantActivity.java` — concise activity record.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantActivityLog.java` — request-local tool activity collector.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantTools.java` — Spring AI tool adapters.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantModel.java` — model boundary.
- `src/main/java/org/springframework/samples/petclinic/assistant/SpringAiClinicAssistantModel.java` — ChatClient, tools, and memory adapter.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantConfiguration.java` — ChatClient and memory wiring.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantConversation.java` — HTTP-session transcript state.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantService.java` — conversation orchestration.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantController.java` — staff-facing MVC routes.
- `src/main/resources/templates/assistant/clinicAssistant.html` — chat form, transcript, reset, and activity display.
- `src/main/resources/templates/fragments/layout.html` — Clinic Assistant navigation entry.
- `src/main/resources/messages/messages.properties` — English navigation labels.
- `src/main/resources/application.properties` — Foundry-compatible Spring AI settings.
- `src/main/scss/petclinic.scss` — minimal chat presentation styles.
- `src/test/java/org/springframework/samples/petclinic/assistant/ClinicQueryServiceTests.java` — query facade contracts.
- `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantToolsTests.java` — tool and activity contracts.
- `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantServiceTests.java` — memory/reset orchestration.
- `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantControllerTests.java` — UI and validation behavior.
- `scripts/validate-reference.sh` — branch drift and focused test guard.
- `docs/reference/clinic-assistant-evidence.md` — reproducible redacted reference evidence.
- `.github/workflows/validate-reference.yml` — reference-only validation.

### Task 1: Import canonical Spring PetClinic without losing workshop history

**Files:**
- Add existing untracked workshop assets under `.github/`, `docs/`, `AGENTS.md`, `CONTEXT.md`, and `skills-lock.json`
- Merge canonical files from `petclinic-upstream/main`
- Modify: `.gitignore`

- [ ] **Step 1: Invoke the isolated-worktree workflow**

Invoke `superpowers:using-git-worktrees`. The current checkout owns `main`, so first preserve the approved workshop artifacts on `main`; create implementation worktrees only after that commit.

- [ ] **Step 2: Verify the canonical baseline**

Run:

```bash
git fetch petclinic-upstream main
test "$(git rev-parse petclinic-upstream/main)" = "88e37c15cf6fc8490b01bc3e8e2c800cec1ac272"
git status --short
```

Expected: the SHA assertion exits 0 and status lists only the known workshop assets.

- [ ] **Step 3: Commit the approved workshop assets**

Run:

```bash
git add .github AGENTS.md CONTEXT.md docs/agents docs/research \
  docs/workshop-blueprint.md skills-lock.json
git commit -m "docs: add workshop blueprint and agent guidance" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: aa0df48a-70dd-4525-83f4-17ec678805e2"
```

Expected: only the named assets are committed; the existing design and plan commits remain intact.

- [ ] **Step 4: Merge the canonical application history**

Run:

```bash
git merge --no-ff --allow-unrelated-histories petclinic-upstream/main \
  -m "chore: import canonical Spring PetClinic baseline"
```

Expected: `.gitignore` is the only content conflict.

- [ ] **Step 5: Resolve `.gitignore` with the canonical file plus worktree isolation**

Keep the upstream `.gitignore` content unchanged and append:

```gitignore

### Agent worktrees ###
.worktrees/
```

Run:

```bash
git add .gitignore
git commit --no-edit
```

- [ ] **Step 6: Establish the imported baseline**

Run:

```bash
./mvnw -q -DskipTests package
./mvnw -q test
git status --short
```

Expected: both Maven commands exit 0 and the worktree is clean.

### Task 2: Add the machine-checkable attendee baseline contract

**Files:**
- Create: `workshop/baseline.properties`
- Create: `docs/workshop/attendee-baseline.md`
- Replace: `README.md`
- Create: `scripts/validate-template-baseline.sh`
- Create: `scripts/test-template-baseline-validator.sh`

- [ ] **Step 1: Write the failing validator regression test**

Create `scripts/test-template-baseline-validator.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-template-baseline.sh"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/workshop" "$fixture/src/main/java" "$fixture/docs"
cat >"$fixture/workshop/baseline.properties" <<'EOF'
upstream.repository=https://github.com/spring-projects/spring-petclinic.git
upstream.commit=88e37c15cf6fc8490b01bc3e8e2c800cec1ac272
EOF
cat >"$fixture/pom.xml" <<'EOF'
<project><dependencies></dependencies></project>
EOF
touch "$fixture/mvnw"
chmod +x "$fixture/mvnw"

"$validator" "$fixture"

mkdir -p "$fixture/src/main/java/org/springframework/samples/petclinic/assistant"
if "$validator" "$fixture"; then
  echo "validator accepted leaked reference code" >&2
  exit 1
fi
rm -rf "$fixture/src/main/java/org/springframework/samples/petclinic/assistant"

printf '<project><artifactId>spring-ai-starter-model-openai</artifactId></project>\n' >"$fixture/pom.xml"
if "$validator" "$fixture"; then
  echo "validator accepted Spring AI on the attendee baseline" >&2
  exit 1
fi

echo "template baseline validator tests passed"
```

- [ ] **Step 2: Run the test and verify the validator is missing**

Run:

```bash
chmod +x scripts/test-template-baseline-validator.sh
scripts/test-template-baseline-validator.sh
```

Expected: FAIL because `scripts/validate-template-baseline.sh` does not exist.

- [ ] **Step 3: Add the provenance file**

Create `workshop/baseline.properties`:

```properties
upstream.repository=https://github.com/spring-projects/spring-petclinic.git
upstream.commit=88e37c15cf6fc8490b01bc3e8e2c800cec1ac272
```

- [ ] **Step 4: Implement the structural validator**

Create `scripts/validate-template-baseline.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
provenance="$root/workshop/baseline.properties"

fail() {
  echo "template baseline invalid: $*" >&2
  exit 1
}

test -f "$provenance" || fail "missing workshop/baseline.properties"
grep -Fxq \
  'upstream.repository=https://github.com/spring-projects/spring-petclinic.git' \
  "$provenance" || fail "unexpected upstream repository"
grep -Fxq \
  'upstream.commit=88e37c15cf6fc8490b01bc3e8e2c800cec1ac272' \
  "$provenance" || fail "unexpected upstream commit"
test -f "$root/mvnw" || fail "missing Maven wrapper"
test -f "$root/pom.xml" || fail "missing Maven project"
test ! -d "$root/src/main/java/org/springframework/samples/petclinic/assistant" \
  || fail "Clinic Assistant solution code is present"
! grep -q 'spring-ai-' "$root/pom.xml" \
  || fail "Spring AI application dependency is present"

if find "$root" -type f \
  \( -name '.env' -o -name '*.tfstate' -o -name 'azureProfile.json' \) \
  -not -path '*/.git/*' -not -path '*/.worktrees/*' -print -quit | grep -q .; then
  fail "generated secret-bearing environment file is present"
fi

echo "template baseline is structurally clean"
```

- [ ] **Step 5: Make scripts executable and run their tests**

Run:

```bash
chmod +x scripts/validate-template-baseline.sh
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
```

Expected: both scripts exit 0.

- [ ] **Step 6: Replace the upstream README with the workshop template entry point**

Replace `README.md` with:

```markdown
# Agentic Engineering Principles Workshop

This repository is the attendee template for a three-hour workshop on making
agent-assisted engineering controlled, inspectable, and adaptable.

## Create your workshop repository

1. Select **Use this template**.
2. Create a repository you control.
3. Clone that repository and follow the workshop Preflight instructions when
   they are published.

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
```

- [ ] **Step 7: Add the maintainer contract**

Create `docs/workshop/attendee-baseline.md`:

````markdown
# Attendee baseline contract

`main` is the GitHub template and clean Inherited System.

It contains canonical Spring PetClinic, workshop design history, and assets
needed before an attendee begins. It must not contain Clinic Assistant
application code, Spring AI dependencies, completed Work Contracts, completed
Stage Cards, reference answers, generated credentials, or Azure environment
state.

Baseline provenance is recorded in `workshop/baseline.properties`.
Run:

```bash
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
./mvnw test
```

Changes land on `main` first and then merge into
`reference/clinic-assistant`. Reference solution changes never merge back to
`main`.
````

- [ ] **Step 8: Commit the baseline contract**

Run:

```bash
git add README.md workshop/baseline.properties docs/workshop/attendee-baseline.md \
  scripts/validate-template-baseline.sh scripts/test-template-baseline-validator.sh
git commit -m "feat: define the attendee template baseline" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: aa0df48a-70dd-4525-83f4-17ec678805e2"
```

### Task 3: Add template CI and disposable generation validation

**Files:**
- Create: `.github/workflows/validate-template.yml`
- Create: `scripts/validate-template-generation.sh`

- [ ] **Step 1: Add baseline CI**

Create `.github/workflows/validate-template.yml`:

```yaml
name: Validate attendee template

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
          cache: maven
      - run: scripts/test-template-baseline-validator.sh
      - run: scripts/validate-template-baseline.sh
      - run: ./mvnw -q test
```

- [ ] **Step 2: Add the manual disposable-template validator**

Create `scripts/validate-template-generation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

source_repo="${1:-JoranBergfeld/agentify-pet-clinic}"
owner="${2:-$(gh api user --jq .login)}"
name="agentify-pet-clinic-template-check-$(date -u +%Y%m%d%H%M%S)"
target="$owner/$name"
clone_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$clone_dir"
  if gh repo view "$target" >/dev/null 2>&1; then
    gh repo delete "$target" --yes
  fi
}
trap cleanup EXIT

test "$(gh repo view "$source_repo" --json isTemplate --jq .isTemplate)" = true
test "$(gh repo view "$source_repo" --json defaultBranchRef --jq .defaultBranchRef.name)" = main

gh repo create "$target" --private --template "$source_repo"
gh repo clone "$target" "$clone_dir/repo"

cd "$clone_dir/repo"
test "$(git branch --show-current)" = main
test -z "$(git status --short)"
scripts/validate-template-baseline.sh
./mvnw -q test

echo "template generation validated with $target"
```

- [ ] **Step 3: Make the script executable and lint shell syntax**

Run:

```bash
chmod +x scripts/validate-template-generation.sh
bash -n scripts/validate-template-generation.sh
bash -n scripts/validate-template-baseline.sh
bash -n scripts/test-template-baseline-validator.sh
```

Expected: all commands exit 0.

- [ ] **Step 4: Commit CI and generation validation**

Run:

```bash
git add .github/workflows/validate-template.yml scripts/validate-template-generation.sh
git commit -m "ci: validate the attendee template boundary" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: aa0df48a-70dd-4525-83f4-17ec678805e2"
```

### Task 4: Publish `main` and configure the GitHub template

**Files:**
- No source files changed.

- [ ] **Step 1: Run the complete local baseline gate**

Run:

```bash
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
./mvnw -q test
git status --short
```

Expected: all commands exit 0 and status is clean.

- [ ] **Step 2: Push `main`**

Run:

```bash
git push -u origin main
```

Expected: `origin/main` is created or updated without force.

- [ ] **Step 3: Set the repository default and template flags**

Run:

```bash
gh repo edit JoranBergfeld/agentify-pet-clinic \
  --default-branch main \
  --template
gh repo view JoranBergfeld/agentify-pet-clinic \
  --json defaultBranchRef,isTemplate \
  --jq '{defaultBranch:.defaultBranchRef.name,isTemplate}'
```

Expected:

```json
{"defaultBranch":"main","isTemplate":true}
```

- [ ] **Step 4: Validate real template generation**

Ensure `gh auth status` shows `delete_repo`; if not, run:

```bash
gh auth refresh -s delete_repo
```

Then run:

```bash
scripts/validate-template-generation.sh
```

Expected: a disposable private repository is generated, passes baseline tests, and is deleted by the trap.

### Task 5: Create the maintained reference branch

**Files:**
- No source files changed.

- [ ] **Step 1: Create the isolated reference worktree**

Run from the repository root:

```bash
git worktree add .worktrees/reference-clinic-assistant \
  -b reference/clinic-assistant main
cd .worktrees/reference-clinic-assistant
git status --short
```

Expected: a clean worktree on `reference/clinic-assistant`.

- [ ] **Step 2: Establish the reference baseline**

Run:

```bash
scripts/validate-template-baseline.sh
./mvnw -q test
```

Expected: both commands exit 0 before reference-only changes.

### Task 6: Add the read-only Clinic query boundary

**Files:**
- Create: `src/test/java/org/springframework/samples/petclinic/assistant/ClinicQueryServiceTests.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicQueryService.java`

- [ ] **Step 1: Write failing query contract tests**

Create `ClinicQueryServiceTests.java` with mocked `OwnerRepository` and
`VetRepository`, the following test methods, and the fixture builders below:

```java
@Test
void findsOwnersWithPurposeBuiltPetAndVisitRecords() {
	Owner george = owner(1, "George", "Franklin");
	Pet leo = pet("Leo", "cat", visit("rabies shot"));
	george.addPet(leo);
	leo.setId(1);
	given(this.owners.findByLastNameStartingWith(eq("Franklin"), any(Pageable.class)))
		.willReturn(new PageImpl<>(List.of(george)));

	assertThat(this.service.findOwners("Franklin")).singleElement().satisfies(owner -> {
		assertThat(owner.fullName()).isEqualTo("George Franklin");
		assertThat(owner.pets()).singleElement().satisfies(pet -> {
			assertThat(pet.name()).isEqualTo("Leo");
			assertThat(pet.visits()).extracting(ClinicQueryService.VisitSummary::description)
				.containsExactly("rabies shot");
		});
	});
}

@Test
void findsPetsAcrossOwnersWithoutExposingEntities() {
	Owner owner = owner(2, "Betty", "Davis");
	Pet basil = pet("Basil", "hamster", visit("checkup"));
	owner.addPet(basil);
	basil.setId(2);
	given(this.owners.findAll()).willReturn(List.of(owner));

	assertThat(this.service.findPets("basil")).singleElement().satisfies(pet -> {
		assertThat(pet.ownerName()).isEqualTo("Betty Davis");
		assertThat(pet.visits()).extracting(ClinicQueryService.VisitSummary::description)
			.containsExactly("checkup");
	});
}

@Test
void listsVeterinariansAndSortedSpecialties() {
	Vet helen = vet(2, "Helen", "Leary", "surgery", "radiology");
	given(this.vets.findAll()).willReturn(List.of(helen));

	assertThat(this.service.listVeterinarians()).containsExactly(
		new ClinicQueryService.VeterinarianSummary(2, "Helen Leary",
			List.of("radiology", "surgery")));
}
```

Use these fixture builders in the same test class:

```java
private static Owner owner(int id, String firstName, String lastName) {
	Owner owner = new Owner();
	owner.setId(id);
	owner.setFirstName(firstName);
	owner.setLastName(lastName);
	owner.setAddress("Workshop address");
	owner.setCity("Workshop city");
	owner.setTelephone("6085550100");
	return owner;
}

private static Pet pet(String name, String typeName, Visit... visits) {
	Pet pet = new Pet();
	pet.setName(name);
	pet.setBirthDate(LocalDate.of(2010, 1, 1));
	PetType type = new PetType();
	type.setName(typeName);
	pet.setType(type);
	for (Visit visit : visits) {
		pet.addVisit(visit);
	}
	return pet;
}

private static Visit visit(String description) {
	Visit visit = new Visit();
	visit.setDate(LocalDate.of(2013, 1, 1));
	visit.setDescription(description);
	return visit;
}

private static Vet vet(int id, String firstName, String lastName, String... specialties) {
	Vet vet = new Vet();
	vet.setId(id);
	vet.setFirstName(firstName);
	vet.setLastName(lastName);
	for (String name : specialties) {
		Specialty specialty = new Specialty();
		specialty.setName(name);
		vet.addSpecialty(specialty);
	}
	return vet;
}
```

- [ ] **Step 2: Run the tests and verify the missing class failure**

Run:

```bash
./mvnw -q -Dtest=ClinicQueryServiceTests test
```

Expected: compilation fails because `ClinicQueryService` does not exist.

- [ ] **Step 3: Implement the query service**

Create `ClinicQueryService.java` with:

```java
package org.springframework.samples.petclinic.assistant;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.domain.PageRequest;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.Visit;
import org.springframework.samples.petclinic.vet.Vet;
import org.springframework.samples.petclinic.vet.VetRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
class ClinicQueryService {

	private final OwnerRepository owners;
	private final VetRepository vets;

	ClinicQueryService(OwnerRepository owners, VetRepository vets) {
		this.owners = owners;
		this.vets = vets;
	}

	@Transactional(readOnly = true)
	List<OwnerSummary> findOwners(String lastName) {
		return this.owners.findByLastNameStartingWith(lastName, PageRequest.of(0, 20))
			.stream()
			.map(ClinicQueryService::ownerSummary)
			.toList();
	}

	@Transactional(readOnly = true)
	List<PetSummary> findPets(String name) {
		return this.owners.findAll()
			.stream()
			.flatMap(owner -> owner.getPets().stream().map(pet -> petSummary(owner, pet)))
			.filter(pet -> pet.name().equalsIgnoreCase(name))
			.toList();
	}

	@Transactional(readOnly = true)
	List<VeterinarianSummary> listVeterinarians() {
		return this.vets.findAll().stream().map(ClinicQueryService::veterinarianSummary).toList();
	}

	private static OwnerSummary ownerSummary(Owner owner) {
		return new OwnerSummary(owner.getId(), fullName(owner.getFirstName(), owner.getLastName()),
				owner.getCity(), owner.getPets().stream().map(pet -> petSummary(owner, pet)).toList());
	}

	private static PetSummary petSummary(Owner owner, Pet pet) {
		return new PetSummary(pet.getId(), pet.getName(), pet.getType().getName(), owner.getId(),
				fullName(owner.getFirstName(), owner.getLastName()),
				pet.getVisits().stream().map(ClinicQueryService::visitSummary).toList());
	}

	private static VisitSummary visitSummary(Visit visit) {
		return new VisitSummary(visit.getDate(), visit.getDescription());
	}

	private static VeterinarianSummary veterinarianSummary(Vet vet) {
		return new VeterinarianSummary(vet.getId(), fullName(vet.getFirstName(), vet.getLastName()),
				vet.getSpecialties().stream().map(specialty -> specialty.getName()).toList());
	}

	private static String fullName(String firstName, String lastName) {
		return firstName + " " + lastName;
	}

	record OwnerSummary(Integer ownerId, String fullName, String city, List<PetSummary> pets) {
	}

	record PetSummary(Integer petId, String name, String type, Integer ownerId, String ownerName,
			List<VisitSummary> visits) {
	}

	record VisitSummary(LocalDate date, String description) {
	}

	record VeterinarianSummary(Integer veterinarianId, String fullName, List<String> specialties) {
	}

}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
./mvnw -q -Dtest=ClinicQueryServiceTests test
```

Expected: PASS.

- [ ] **Step 5: Commit the query boundary**

Run:

```bash
git add src/main/java/org/springframework/samples/petclinic/assistant/ClinicQueryService.java \
  src/test/java/org/springframework/samples/petclinic/assistant/ClinicQueryServiceTests.java
git commit -m "feat: add read-only Clinic Assistant queries"
```

### Task 7: Add Spring AI tools with visible activity

**Files:**
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantActivity.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantActivityLog.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantTools.java`
- Create: `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantToolsTests.java`

- [ ] **Step 1: Write failing tool tests**

Create `ClinicAssistantToolsTests.java` with a mocked `ClinicQueryService`.
Use this test for the three tool routes:

```java
@Test
void returnsPurposeBuiltRecordsAndVisibleActivity() {
	ClinicQueryService.OwnerSummary owner = new ClinicQueryService.OwnerSummary(
			2, "Betty Davis", "Madison", List.of());
	ClinicQueryService.PetSummary pet = new ClinicQueryService.PetSummary(
			2, "Basil", "hamster", 2, "Betty Davis", List.of());
	ClinicQueryService.VeterinarianSummary vet =
		new ClinicQueryService.VeterinarianSummary(
				2, "Helen Leary", List.of("radiology"));
	given(this.queries.findOwners("Davis")).willReturn(List.of(owner));
	given(this.queries.findPets("Basil")).willReturn(List.of(pet));
	given(this.queries.listVeterinarians()).willReturn(List.of(vet));
	ClinicAssistantActivityLog log = new ClinicAssistantActivityLog();
	ToolContext context = new ToolContext(
			Map.of(ClinicAssistantActivityLog.CONTEXT_KEY, log));

	assertThat(this.tools.findOwnersByLastName("Davis", context))
		.containsExactly(owner);
	assertThat(this.tools.findPetsByName("Basil", context))
		.containsExactly(pet);
	assertThat(this.tools.listVeterinarians(context)).containsExactly(vet);
	assertThat(log.snapshot()).containsExactly(
			new ClinicAssistantActivity("findOwnersByLastName", "1 owner matches"),
			new ClinicAssistantActivity("findPetsByName", "1 pet matches"),
			new ClinicAssistantActivity("listVeterinarians", "1 veterinarians"));
}

@Test
void rejectsARequestWithoutTheActivityCollector() {
	ToolContext context = new ToolContext(Map.of());

	assertThatIllegalStateException()
		.isThrownBy(() -> this.tools.listVeterinarians(context))
		.withMessage("Clinic Assistant activity log is missing");
}
```

Use fields initialized as:

```java
private final ClinicQueryService queries = mock(ClinicQueryService.class);

private final ClinicAssistantTools tools = new ClinicAssistantTools(this.queries);
```

- [ ] **Step 2: Run the tests and verify missing classes**

Run:

```bash
./mvnw -q -Dtest=ClinicAssistantToolsTests test
```

Expected: compilation fails for the new activity and tool types.

- [ ] **Step 3: Implement activity types**

Create `ClinicAssistantActivity.java`:

```java
package org.springframework.samples.petclinic.assistant;

record ClinicAssistantActivity(String tool, String outcome) {
}
```

Create `ClinicAssistantActivityLog.java`:

```java
package org.springframework.samples.petclinic.assistant;

import java.util.ArrayList;
import java.util.List;

import org.springframework.ai.chat.model.ToolContext;

final class ClinicAssistantActivityLog {

	static final String CONTEXT_KEY = ClinicAssistantActivityLog.class.getName();

	private final List<ClinicAssistantActivity> activities = new ArrayList<>();

	void record(String tool, String outcome) {
		this.activities.add(new ClinicAssistantActivity(tool, outcome));
	}

	List<ClinicAssistantActivity> snapshot() {
		return List.copyOf(this.activities);
	}

	static ClinicAssistantActivityLog from(ToolContext context) {
		Object value = context.getContext().get(CONTEXT_KEY);
		if (value instanceof ClinicAssistantActivityLog log) {
			return log;
		}
		throw new IllegalStateException("Clinic Assistant activity log is missing");
	}

}
```

- [ ] **Step 4: Implement the tools**

Create `ClinicAssistantTools.java` with three `@Tool` methods:

```java
package org.springframework.samples.petclinic.assistant;

import java.util.List;

import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

@Component
class ClinicAssistantTools {

	private final ClinicQueryService queries;

	ClinicAssistantTools(ClinicQueryService queries) {
		this.queries = queries;
	}

	@Tool(description = "Find owners whose last name starts with the supplied text. "
			+ "If more than one owner matches, list candidates and ask for clarification.")
	List<ClinicQueryService.OwnerSummary> findOwnersByLastName(
			@ToolParam(description = "Owner last name or starting text") String lastName,
			ToolContext context) {
		List<ClinicQueryService.OwnerSummary> matches = this.queries.findOwners(lastName);
		ClinicAssistantActivityLog.from(context)
			.record("findOwnersByLastName", matches.size() + " owner matches");
		return matches;
	}

	@Tool(description = "Find pets by name and return their owner and recorded Visits. "
			+ "If more than one pet matches, list candidates and ask for clarification.")
	List<ClinicQueryService.PetSummary> findPetsByName(
			@ToolParam(description = "Pet name") String name, ToolContext context) {
		List<ClinicQueryService.PetSummary> matches = this.queries.findPets(name);
		ClinicAssistantActivityLog.from(context)
			.record("findPetsByName", matches.size() + " pet matches");
		return matches;
	}

	@Tool(description = "List PetClinic veterinarians and their recorded specialties.")
	List<ClinicQueryService.VeterinarianSummary> listVeterinarians(ToolContext context) {
		List<ClinicQueryService.VeterinarianSummary> matches = this.queries.listVeterinarians();
		ClinicAssistantActivityLog.from(context)
			.record("listVeterinarians", matches.size() + " veterinarians");
		return matches;
	}

}
```

- [ ] **Step 5: Run focused tests and commit**

Run:

```bash
./mvnw -q -Dtest=ClinicAssistantToolsTests test
git add src/main/java/org/springframework/samples/petclinic/assistant \
  src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantToolsTests.java
git commit -m "feat: add Clinic Assistant tools and activity"
```

### Task 8: Add Spring AI model integration and session memory

**Files:**
- Modify: `pom.xml`
- Modify: `src/main/resources/application.properties`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantModel.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/SpringAiClinicAssistantModel.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantConfiguration.java`
- Create: `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantModelTests.java`

- [ ] **Step 1: Add Spring AI dependency management and dependencies**

Import `spring-ai-bom` version `2.0.0`. Add:

```xml
<dependency>
  <groupId>org.springframework.ai</groupId>
  <artifactId>spring-ai-starter-model-openai</artifactId>
</dependency>
<dependency>
  <groupId>com.azure</groupId>
  <artifactId>azure-identity</artifactId>
  <version>1.18.2</version>
</dependency>
```

- [ ] **Step 2: Define the model boundary**

Create `ClinicAssistantModel.java`:

```java
package org.springframework.samples.petclinic.assistant;

import java.util.List;

interface ClinicAssistantModel {

	Reply answer(String conversationId, String message);

	void reset(String conversationId);

	record Reply(String answer, List<ClinicAssistantActivity> activities) {
	}

}
```

- [ ] **Step 3: Write model adapter tests**

Create `ClinicAssistantModelTests.java` with mocked fluent interfaces:

```java
private final ChatClient chatClient = mock(ChatClient.class);
private final ChatMemory memory = mock(ChatMemory.class);
private final ChatClient.ChatClientRequestSpec request =
		mock(ChatClient.ChatClientRequestSpec.class);
private final ChatClient.CallResponseSpec response =
		mock(ChatClient.CallResponseSpec.class);
private final SpringAiClinicAssistantModel model =
		new SpringAiClinicAssistantModel(this.chatClient, this.memory);

@BeforeEach
void setUp() {
	given(this.chatClient.prompt()).willReturn(this.request);
	given(this.request.advisors(any())).willReturn(this.request);
	given(this.request.toolContext(anyMap())).willReturn(this.request);
	given(this.request.user(anyString())).willReturn(this.request);
	given(this.request.call()).willReturn(this.response);
}

@Test
void passesConversationAndActivityContext() {
	given(this.response.content()).willReturn("George Franklin owns Leo.");

	ClinicAssistantModel.Reply reply =
		this.model.answer("conversation-1", "Who owns Leo?");

	assertThat(reply.answer()).isEqualTo("George Franklin owns Leo.");
	ArgumentCaptor<Consumer<ChatClient.AdvisorSpec>> advisors =
		ArgumentCaptor.forClass(Consumer.class);
	verify(this.request).advisors(advisors.capture());
	ChatClient.AdvisorSpec advisorSpec = mock(ChatClient.AdvisorSpec.class);
	advisors.getValue().accept(advisorSpec);
	verify(advisorSpec).param(ChatMemory.CONVERSATION_ID, "conversation-1");

	ArgumentCaptor<Map<String, Object>> context =
		ArgumentCaptor.forClass(Map.class);
	verify(this.request).toolContext(context.capture());
	assertThat(context.getValue().get(ClinicAssistantActivityLog.CONTEXT_KEY))
		.isInstanceOf(ClinicAssistantActivityLog.class);
}

@Test
void rejectsAnEmptyModelResult() {
	given(this.response.content()).willReturn(null);

	assertThatIllegalStateException()
		.isThrownBy(() -> this.model.answer("conversation-1", "Who owns Leo?"))
		.withMessage("Clinic Assistant returned no answer");
}

@Test
void clearsConversationMemory() {
	this.model.reset("conversation-1");

	verify(this.memory).clear("conversation-1");
}
```

- [ ] **Step 4: Implement ChatClient and memory configuration**

Create `ClinicAssistantConfiguration.java`:

```java
package org.springframework.samples.petclinic.assistant;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.memory.MessageWindowChatMemory;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class ClinicAssistantConfiguration {

	@Bean
	ChatMemory clinicAssistantMemory() {
		return MessageWindowChatMemory.builder().maxMessages(20).build();
	}

	@Bean
	ChatClient clinicAssistantChatClient(ChatModel chatModel, ChatMemory clinicAssistantMemory,
			ClinicAssistantTools tools) {
		return ChatClient.builder(chatModel)
			.defaultSystem("""
					You are the staff-facing Clinic Assistant for Spring PetClinic.
					Answer only from data returned by the available tools.
					Never claim to change PetClinic data.
					When multiple people or pets match, list candidates and ask for clarification.
					Admit when records are absent or a request is unsupported.
					Do not provide veterinary diagnosis or treatment advice.
					""")
			.defaultAdvisors(MessageChatMemoryAdvisor.builder(clinicAssistantMemory).build())
			.defaultTools(tools)
			.build();
	}

}
```

- [ ] **Step 5: Implement the model adapter**

Create `SpringAiClinicAssistantModel.java`:

```java
package org.springframework.samples.petclinic.assistant;

import java.util.Map;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.stereotype.Component;

@Component
class SpringAiClinicAssistantModel implements ClinicAssistantModel {

	private final ChatClient chatClient;
	private final ChatMemory chatMemory;

	SpringAiClinicAssistantModel(ChatClient chatClient, ChatMemory clinicAssistantMemory) {
		this.chatClient = chatClient;
		this.chatMemory = clinicAssistantMemory;
	}

	@Override
	public Reply answer(String conversationId, String message) {
		ClinicAssistantActivityLog activity = new ClinicAssistantActivityLog();
		String answer = this.chatClient.prompt()
			.advisors(advisors -> advisors.param(ChatMemory.CONVERSATION_ID, conversationId))
			.toolContext(Map.of(ClinicAssistantActivityLog.CONTEXT_KEY, activity))
			.user(message)
			.call()
			.content();
		if (answer == null) {
			throw new IllegalStateException("Clinic Assistant returned no answer");
		}
		return new Reply(answer, activity.snapshot());
	}

	@Override
	public void reset(String conversationId) {
		this.chatMemory.clear(conversationId);
	}

}
```

- [ ] **Step 6: Add Foundry-compatible properties**

Append to `application.properties`:

```properties
# Clinic Assistant reference
spring.ai.model.audio.speech=none
spring.ai.model.audio.transcription=none
spring.ai.model.embedding=none
spring.ai.model.image=none
spring.ai.model.moderation=none
spring.ai.openai.base-url=${AZURE_OPENAI_ENDPOINT:https://example.openai.azure.com}
spring.ai.openai.microsoft-foundry=${AZURE_OPENAI_MICROSOFT_FOUNDRY:true}
spring.ai.openai.microsoft-deployment-name=${AZURE_OPENAI_DEPLOYMENT:gpt-5-4-mini}
spring.ai.openai.model=${AZURE_OPENAI_DEPLOYMENT:gpt-5-4-mini}
spring.ai.openai.chat.model=${AZURE_OPENAI_DEPLOYMENT:gpt-5-4-mini}
spring.ai.openai.timeout=60s
spring.ai.openai.max-retries=2
```

- [ ] **Step 7: Run focused tests and commit**

Run:

```bash
./mvnw -q -Dtest=ClinicAssistantModelTests test
git add pom.xml src/main/resources/application.properties \
  src/main/java/org/springframework/samples/petclinic/assistant \
  src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantModelTests.java
git commit -m "feat: add Spring AI conversation integration"
```

### Task 9: Add the staff-facing chat flow

**Files:**
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantConversation.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantService.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantController.java`
- Create: `src/main/resources/templates/assistant/clinicAssistant.html`
- Modify: `src/main/resources/templates/fragments/layout.html`
- Modify: `src/main/resources/messages/messages.properties`
- Modify: `src/main/scss/petclinic.scss`
- Create: `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantServiceTests.java`
- Create: `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantControllerTests.java`

- [ ] **Step 1: Write service tests**

Create `ClinicAssistantServiceTests.java`:

```java
package org.springframework.samples.petclinic.assistant;

import java.util.List;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class ClinicAssistantServiceTests {

	private final ClinicAssistantModel model = mock(ClinicAssistantModel.class);

	private final ClinicAssistantService service = new ClinicAssistantService(this.model);

	@Test
	void recordsTheUserAnswerAndVisibleActivity() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		given(this.model.answer(conversation.id(), "Who owns Leo?"))
			.willReturn(new ClinicAssistantModel.Reply("George Franklin owns Leo.",
					List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));

		this.service.ask(conversation, "Who owns Leo?");

		assertThat(conversation.turns()).containsExactly(
				new ClinicAssistantConversation.Turn("user", "Who owns Leo?", List.of()),
				new ClinicAssistantConversation.Turn("assistant", "George Franklin owns Leo.",
						List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));
	}

	@Test
	void resetsModelMemoryAndTheVisibleTranscript() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		conversation.addUser("Who owns Leo?");

		this.service.reset(conversation);

		verify(this.model).reset(conversation.id());
		assertThat(conversation.turns()).isEmpty();
	}

}
```

- [ ] **Step 2: Implement conversation state**

Create `ClinicAssistantConversation.java`:

```java
package org.springframework.samples.petclinic.assistant;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

final class ClinicAssistantConversation {

	private final String id = UUID.randomUUID().toString();
	private final List<Turn> turns = new ArrayList<>();

	String id() {
		return this.id;
	}

	List<Turn> turns() {
		return List.copyOf(this.turns);
	}

	void addUser(String content) {
		this.turns.add(new Turn("user", content, List.of()));
	}

	void addAssistant(String content, List<ClinicAssistantActivity> activities) {
		this.turns.add(new Turn("assistant", content, List.copyOf(activities)));
	}

	void clear() {
		this.turns.clear();
	}

	record Turn(String role, String content, List<ClinicAssistantActivity> activities) {
	}

}
```

- [ ] **Step 3: Implement service orchestration**

Create `ClinicAssistantService.java`:

```java
package org.springframework.samples.petclinic.assistant;

import org.springframework.stereotype.Service;

@Service
class ClinicAssistantService {

	private final ClinicAssistantModel model;

	ClinicAssistantService(ClinicAssistantModel model) {
		this.model = model;
	}

	void ask(ClinicAssistantConversation conversation, String message) {
		conversation.addUser(message);
		ClinicAssistantModel.Reply reply = this.model.answer(conversation.id(), message);
		conversation.addAssistant(reply.answer(), reply.activities());
	}

	void reset(ClinicAssistantConversation conversation) {
		this.model.reset(conversation.id());
		conversation.clear();
	}

}
```

- [ ] **Step 4: Write MVC tests**

Create `ClinicAssistantControllerTests.java` using
`@WebMvcTest(ClinicAssistantController.class)`,
`@Import(ClinicAssistantService.class)`, `@MockitoBean ClinicAssistantModel`,
and these tests:

```java
@Test
void showsTheAssistantPage() throws Exception {
	this.mockMvc.perform(get("/clinic-assistant"))
		.andExpect(status().isOk())
		.andExpect(view().name("assistant/clinicAssistant"))
		.andExpect(model().attributeExists("clinicAssistantConversation",
				"assistantRequest"));
}

@Test
void rejectsBlankInput() throws Exception {
	this.mockMvc.perform(post("/clinic-assistant").param("message", " "))
		.andExpect(status().isOk())
		.andExpect(view().name("assistant/clinicAssistant"))
		.andExpect(model().attributeHasFieldErrors("assistantRequest", "message"));
}

@Test
void preservesTranscriptAndVisibleActivityInTheSession() throws Exception {
	given(this.model.answer(anyString(), eq("Who owns Leo?")))
		.willReturn(new ClinicAssistantModel.Reply("George Franklin owns Leo.",
				List.of(new ClinicAssistantActivity(
						"findPetsByName", "1 pet matches"))));

	MvcResult result = this.mockMvc.perform(
			post("/clinic-assistant").param("message", "Who owns Leo?"))
		.andExpect(status().is3xxRedirection())
		.andExpect(redirectedUrl("/clinic-assistant"))
		.andReturn();
	MockHttpSession session =
		(MockHttpSession) result.getRequest().getSession(false);

	this.mockMvc.perform(get("/clinic-assistant").session(session))
		.andExpect(status().isOk())
		.andExpect(content().string(containsString("Who owns Leo?")))
		.andExpect(content().string(containsString("George Franklin owns Leo.")))
		.andExpect(content().string(containsString("findPetsByName")))
		.andExpect(content().string(containsString("1 pet matches")));
}

@Test
void resetsTheConversation() throws Exception {
	MvcResult page = this.mockMvc.perform(get("/clinic-assistant")).andReturn();
	MockHttpSession session =
		(MockHttpSession) page.getRequest().getSession(false);
	ClinicAssistantConversation conversation =
		(ClinicAssistantConversation) session
			.getAttribute("clinicAssistantConversation");

	this.mockMvc.perform(post("/clinic-assistant/reset").session(session))
		.andExpect(status().is3xxRedirection())
		.andExpect(redirectedUrl("/clinic-assistant"));

	verify(this.model).reset(conversation.id());
	assertThat(conversation.turns()).isEmpty();
}
```

- [ ] **Step 5: Implement the controller**

Create `ClinicAssistantController.java`:

```java
package org.springframework.samples.petclinic.assistant;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

import org.springframework.stereotype.Controller;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.SessionAttributes;

@Controller
@RequestMapping("/clinic-assistant")
@SessionAttributes("clinicAssistantConversation")
class ClinicAssistantController {

	private final ClinicAssistantService assistant;

	ClinicAssistantController(ClinicAssistantService assistant) {
		this.assistant = assistant;
	}

	@ModelAttribute("clinicAssistantConversation")
	ClinicAssistantConversation conversation() {
		return new ClinicAssistantConversation();
	}

	@ModelAttribute("assistantRequest")
	AssistantRequest request() {
		return new AssistantRequest();
	}

	@GetMapping
	String show() {
		return "assistant/clinicAssistant";
	}

	@PostMapping
	String ask(@Valid @ModelAttribute("assistantRequest") AssistantRequest request,
			BindingResult binding, @ModelAttribute("clinicAssistantConversation")
			ClinicAssistantConversation conversation) {
		if (binding.hasErrors()) {
			return "assistant/clinicAssistant";
		}
		this.assistant.ask(conversation, request.getMessage());
		return "redirect:/clinic-assistant";
	}

	@PostMapping("/reset")
	String reset(@ModelAttribute("clinicAssistantConversation")
			ClinicAssistantConversation conversation) {
		this.assistant.reset(conversation);
		return "redirect:/clinic-assistant";
	}

	static final class AssistantRequest {

		@NotBlank
		private String message = "";

		public String getMessage() {
			return this.message;
		}

		public void setMessage(String message) {
			this.message = message;
		}

	}

}
```

- [ ] **Step 6: Add the Thymeleaf page**

Create `src/main/resources/templates/assistant/clinicAssistant.html`:

```html
<!DOCTYPE html>

<html xmlns:th="https://www.thymeleaf.org"
      th:replace="~{fragments/layout :: layout (~{::body},'assistant')}">

<body>

  <h2>Clinic Assistant</h2>
  <p class="text-muted">Read-only answers from PetClinic records.</p>

  <div th:each="turn : ${clinicAssistantConversation.turns}" class="assistant-turn"
       th:classappend="${turn.role == 'user'} ? ' assistant-turn-user' : ' assistant-turn-assistant'">
    <strong th:text="${turn.role == 'user'} ? 'You' : 'Clinic Assistant'"></strong>
    <p th:text="${turn.content}"></p>
    <ul th:if="${!turn.activities.empty}" class="assistant-activity">
      <li th:each="activity : ${turn.activities}">
        <code th:text="${activity.tool}"></code>
        <span th:text="${activity.outcome}"></span>
      </li>
    </ul>
  </div>

  <form th:action="@{/clinic-assistant}" th:object="${assistantRequest}" method="post">
    <div class="mb-3">
      <label for="message" class="form-label">Ask about owners, pets, Visits, or veterinarians</label>
      <textarea id="message" class="form-control" rows="3" th:field="*{message}"></textarea>
      <span class="help-block" th:if="${#fields.hasErrors('message')}" th:errors="*{message}"></span>
    </div>
    <button type="submit" class="btn btn-primary">Ask</button>
  </form>

  <form th:action="@{/clinic-assistant/reset}" method="post">
    <button type="submit" class="btn btn-secondary">Reset conversation</button>
  </form>

</body>

</html>
```

- [ ] **Step 7: Wire navigation and styles**

Add this menu item before the error link in `layout.html`:

```html
<li th:replace="~{::menuItem ('/clinic-assistant','assistant','clinic assistant','comments',#{clinicAssistant})}">
  <span class="fa fa-comments" aria-hidden="true"></span>
  <span th:text="#{clinicAssistant}">Clinic Assistant</span>
</li>
```

Append to `messages.properties`:

```properties
clinicAssistant=Clinic Assistant
```

Append to `petclinic.scss`:

```scss
.assistant-turn {
  margin-bottom: 16px;
  padding: 12px;
  border-left: 4px solid $spring-grey;
  background: white;
}

.assistant-turn-user {
  border-left-color: $spring-brown;
}

.assistant-turn-assistant {
  border-left-color: $spring-green;
}

.assistant-activity {
  margin-bottom: 0;
  color: $spring-grey;
}
```

- [ ] **Step 8: Run focused and regression tests**

Run:

```bash
./mvnw -q -Dtest=ClinicAssistantServiceTests,ClinicAssistantControllerTests test
./mvnw -q test
```

Expected: both commands pass.

- [ ] **Step 9: Commit the staff-facing flow**

Run:

```bash
git add src/main/java/org/springframework/samples/petclinic/assistant \
  src/main/resources/templates/assistant/clinicAssistant.html \
  src/main/resources/templates/fragments/layout.html \
  src/main/resources/messages/messages.properties \
  src/main/scss/petclinic.scss \
  src/test/java/org/springframework/samples/petclinic/assistant
git commit -m "feat: add the staff-facing Clinic Assistant"
```

### Task 10: Add reference guards and evidence

**Files:**
- Create: `scripts/validate-reference.sh`
- Create: `.github/workflows/validate-reference.yml`
- Create: `docs/reference/clinic-assistant-evidence.md`

- [ ] **Step 1: Add the reference validator**

Create `scripts/validate-reference.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

git fetch origin main
git merge-base --is-ancestor origin/main HEAD
test -d src/main/java/org/springframework/samples/petclinic/assistant
grep -q 'spring-ai-starter-model-openai' pom.xml

./mvnw -q -Dtest='ClinicQueryServiceTests,ClinicAssistantToolsTests,ClinicAssistantModelTests,ClinicAssistantServiceTests,ClinicAssistantControllerTests' test
./mvnw -q test

echo "reference branch is current and validated"
```

- [ ] **Step 2: Add reference CI**

Create `.github/workflows/validate-reference.yml`:

```yaml
name: Validate Clinic Assistant reference

on:
  pull_request:
    branches: [reference/clinic-assistant]
  push:
    branches: [reference/clinic-assistant]

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
          cache: maven
      - run: scripts/validate-reference.sh
```

- [ ] **Step 3: Run the evidence commands**

Run:

```bash
chmod +x scripts/validate-reference.sh
scripts/validate-reference.sh
REFERENCE_SHA="$(git rev-parse HEAD)"
MAIN_SHA="$(git rev-parse main)"
printf '%s\n' "$MAIN_SHA" "$REFERENCE_SHA"
```

Expected: validation passes and both revisions are printed.

- [ ] **Step 4: Record redacted evidence**

Create `docs/reference/clinic-assistant-evidence.md` containing:

- the validated `main` and reference SHAs from Step 3;
- the exact focused and full Maven commands;
- PASS results for owner, pet, veterinarian, ambiguity, unsupported/medical
  boundary, activity, memory, and reset tests;
- the prototype evidence link for the already-proven managed-identity Azure
  seam; and
- an explicit note that deployed smoke evidence will be refreshed by **Build
  the workshop Azure, Preflight, and cleanup path**.

Do not paste credentials, tokens, `.azure` content, model inputs containing
sensitive data, or live resource identifiers.

- [ ] **Step 5: Commit the reference validation**

Run:

```bash
git add scripts/validate-reference.sh .github/workflows/validate-reference.yml \
  docs/reference/clinic-assistant-evidence.md
git commit -m "test: add Clinic Assistant reference evidence"
```

### Task 11: Publish and verify the reference branch

**Files:**
- No source files changed.

- [ ] **Step 1: Run the final reference gate**

Run:

```bash
scripts/validate-reference.sh
git status --short
```

Expected: validation passes and status is clean.

- [ ] **Step 2: Push the reference branch**

Run:

```bash
git push -u origin reference/clinic-assistant
```

- [ ] **Step 3: Re-run real template generation after the reference branch exists**

Run from the `main` worktree:

```bash
scripts/validate-template-generation.sh
```

Expected: generated repository starts on clean `main` and contains no
`src/main/java/org/springframework/samples/petclinic/assistant` directory.

- [ ] **Step 4: Confirm both remote branches**

Run:

```bash
gh api repos/JoranBergfeld/agentify-pet-clinic/branches/main --jq .commit.sha
gh api repos/JoranBergfeld/agentify-pet-clinic/branches/reference%2Fclinic-assistant --jq .commit.sha
test "$(git rev-parse prototype/azure-deployment-slice)" = \
  "ee7397dbe3f15846ff7ba98139fee11ac21d4cb2"
gh repo view JoranBergfeld/agentify-pet-clinic \
  --json defaultBranchRef,isTemplate \
  --jq '{defaultBranch:.defaultBranchRef.name,isTemplate}'
```

Expected: both branch calls return SHAs, default branch is `main`, and
`isTemplate` is true.

### Task 12: Resolve the Wayfinder ticket and update the map

**Files:**
- GitHub issue **Build the attendee starter and reference evidence path**
- GitHub issue **Build the Agentic Engineering Principles workshop**

- [ ] **Step 1: Capture durable branch pointers**

Run:

```bash
MAIN_SHA="$(gh api repos/JoranBergfeld/agentify-pet-clinic/branches/main --jq .commit.sha)"
REFERENCE_SHA="$(gh api repos/JoranBergfeld/agentify-pet-clinic/branches/reference%2Fclinic-assistant --jq .commit.sha)"
MAIN_URL="https://github.com/JoranBergfeld/agentify-pet-clinic/tree/$MAIN_SHA"
REFERENCE_URL="https://github.com/JoranBergfeld/agentify-pet-clinic/tree/$REFERENCE_SHA"
```

- [ ] **Step 2: Post the resolution and close the ticket**

Run:

```bash
gh issue comment 20 --body "$(cat <<EOF
## Resolution

Converted this repository into the attendee GitHub template on
[\`main\`]($MAIN_URL), rooted in canonical Spring PetClinic commit
\`88e37c15cf6fc8490b01bc3e8e2c800cec1ac272\`. The template preserves the
Workshop Blueprint and planning history while executable guards prove that the
Clinic Assistant solution and Spring AI dependencies are absent.

Added the complete maintained Clinic Assistant on
[\`reference/clinic-assistant\`]($REFERENCE_URL): read-only owner, pet, Visit,
veterinarian, and specialty queries; clarification-preserving tools;
Foundry-compatible Spring AI integration; session memory and reset; a
staff-facing UI; visible tool activity; focused and regression tests; and a
redacted evidence path.

Real GitHub template generation was validated with a disposable repository.
The Azure prototype remains historical evidence; deployment, Preflight, and
cleanup automation remain owned by **Build the workshop Azure, Preflight, and
cleanup path**.
EOF
)"
gh issue close 20
```

- [ ] **Step 3: Append the named context pointer to the map**

Fetch the current map body, insert this line at the end of **Decisions so far**
without changing concurrent edits, and update the issue:

```markdown
- [Build the attendee starter and reference evidence path](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/20) — Use this repository's clean canonical PetClinic `main` as the attendee template and maintain the complete Clinic Assistant plus reproducible evidence on `reference/clinic-assistant`.
```

Use `gh issue view 1 --json body --jq .body`, edit a temporary body file, then
run `gh issue edit 1 --body-file <file>`. Re-read the map immediately before
editing so another Wayfinder session's changes are preserved.

- [ ] **Step 4: Verify the frontier**

Run:

```bash
gh api --paginate repos/JoranBergfeld/agentify-pet-clinic/issues/1/sub_issues \
  --jq '.[] | select(.state=="open") | [.number,.title,([.assignees[].login] | join(",")),(.issue_dependencies_summary.blocked_by // 0)] | @tsv'
```

Expected: **Build the attendee starter and reference evidence path** is closed,
and the remaining frontier reflects current dependency and claim state.
