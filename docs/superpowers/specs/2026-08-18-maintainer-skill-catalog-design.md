# Maintainer Skill Catalog Design

## Purpose

Preserve the newly installed maintainer capabilities in a reproducible
repository-owned catalog without expanding the attendee-facing Workshop
Package skill set or leaving generated client projections as untracked files.

## Work Contract

### Scope

- Vendor the 16 newly installed maintainer-only skills in a non-discovery
  repository path.
- Record exact upstream provenance and deterministic content hashes.
- Add an explicit maintainer setup command that creates local client
  projections.
- Validate the catalog, lock, setup behavior, attendee isolation, and generated
  state boundary.
- Commit and push the implementation only after its focused and existing
  repository checks pass.

### Constraints

- Preserve the exact attendee-facing `.github/skills` inventory and existing
  `skills-lock.json`.
- Keep `to-spec` maintainer-scoped under its existing contract.
- Keep generated `.agents/` and `.claude/` projections ignored and untracked.
- Preserve human authority over every workshop Risk Gate and final acceptance.
- Fail explicitly on missing, extra, modified, or unsafe local skill state.
- Retain the upstream MIT attribution.

### Agent authority

The agent may add the maintainer catalog, lock, setup script, focused fixtures,
validation, and directly related documentation. It may migrate the current
generated skill files into the catalog and regenerate ignored local
projections. It may not expand attendee guidance, alter the supported attendee
skill set, or claim Workshop Package acceptance.

### Public seams

- `docs/agents/maintainer-skills/` — repository-owned source catalog.
- `maintainer-skills-lock.json` — exact catalog inventory, provenance, and
  content hashes.
- `scripts/setup-maintainer-skills.sh` — explicit local projection command.
- `.agents/skills/` and `.claude/skills/` — ignored generated projections.

### Assumptions

- The selected upstream skills remain available under the MIT license.
- Maintainers can run the repository's Bash-based support scripts.
- Local copies are more portable than repository symlinks across supported
  maintainer environments.

### Expected evidence

- Focused setup and catalog regression tests pass.
- Existing Copilot asset and template-baseline tests and validators pass.
- `git diff --check` passes.
- Running setup produces equivalent client projections and leaves the
  repository worktree clean.

## Inventory boundary

The attendee inventory remains the eight workshop skills plus the existing
maintainer-scoped `to-spec` skill under `.github/skills`. The maintainer catalog
adds only:

- `ask-matt`
- `grill-me`
- `grill-with-docs`
- `handoff`
- `implement`
- `improve-codebase-architecture`
- `research`
- `resolving-merge-conflicts`
- `setup-matt-pocock-skills`
- `teach`
- `to-questionnaire`
- `to-tickets`
- `triage`
- `wait-what`
- `wizard`
- `writing-for-agents`

These names remain prohibited in attendee-facing guidance. Storing their source
under `docs/agents/maintainer-skills/` prevents automatic discovery in a clean
attendee clone.

## Catalog and lock

Each vendored skill keeps its complete directory structure and upstream
relative paths. The maintainer lock records:

- the source repository;
- the pinned upstream revision;
- the upstream skill path; and
- a deterministic content hash computed from sorted relative paths and file
  bytes.

Validation requires an exact name match between the lock and catalog and
recomputes every content hash. A missing, extra, or changed skill is an
explicit failure.

The existing `skills-lock.json` continues to describe only `.github/skills`.
Separating the locks keeps the attendee contract legible and prevents a
maintainer installation from silently redefining the Workshop Package.

## Explicit setup

`scripts/setup-maintainer-skills.sh` validates both catalogs before creating
local state. It projects the union of `.github/skills` and
`docs/agents/maintainer-skills` into:

- `.agents/skills/`
- `.claude/skills/`

The script copies files rather than committing symlinks. It records which
entries it manages, is idempotent, and replaces only those managed entries. If
an expected destination already exists without the management marker, setup
stops and reports the conflicting path instead of overwriting it.

Both projection roots are ignored by Git. Running setup therefore gives a
maintainer the broader local toolset while a fresh attendee clone discovers
only the supported `.github/skills` inventory.

## Validation design

The repository gains focused checks for:

- exact maintainer catalog and lock inventory;
- deterministic hash verification;
- missing, extra, and modified catalog entries;
- ignored and untracked client projection roots;
- successful projection into both clients;
- identical projected content;
- idempotent reruns;
- safe replacement of script-managed entries; and
- refusal to overwrite unrecognized destinations.

The existing Copilot validator continues enforcing the exact attendee skill
set and rejecting maintainer skill references in attendee-facing guidance.
Template-baseline validation remains the final boundary check.

## Migration

Implementation will use the current `.agents/skills` files as the source for
the 16 approved maintainer catalog entries. Changed copies of existing attendee
skills will not replace their accepted `.github/skills` versions. The generated
root `skills-lock.json` changes will be discarded after the separate
maintainer lock is created.

After the catalog and tests are committed, setup will regenerate the ignored
`.agents/` and `.claude/` projections. The final worktree must be clean before
the changes are pushed.

## Acceptance boundary

Passing checks establishes that the maintainer catalog is reproducible and
does not alter the attendee inventory. It does not accept the Workshop Package
or authorize the upcoming owner dry run; those judgments remain with the
workshop owner.
