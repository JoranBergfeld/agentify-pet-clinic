# Maintainer Skill Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a pinned, repository-owned maintainer skill catalog with explicit local setup while preserving the exact attendee-facing skill inventory.

**Architecture:** Vendor the 16 approved skills under a non-discovery documentation path and describe them with a separate lock file. A small Python module validates catalog hashes and safely projects the union of attendee and maintainer skills into ignored client directories; Bash wrappers preserve the repository's command conventions.

**Tech Stack:** Bash, Python 3 standard library, JSON, Git, existing shell fixture tests, GitHub Actions

---

## File structure

- `docs/agents/maintainer-skills/` — exact vendored source for the 16
  maintainer-only skills plus upstream license.
- `maintainer-skills-lock.json` — pinned upstream revision, source paths, and
  deterministic hashes.
- `scripts/maintainer_skills.py` — catalog validation and safe projection
  implementation.
- `scripts/validate-maintainer-skills.sh` — stable validation command.
- `scripts/setup-maintainer-skills.sh` — stable explicit setup command.
- `scripts/test-maintainer-skills.sh` — focused regression fixtures.
- `.gitignore` — ignores generated `.agents/` and `.claude/` projections.
- `docs/workshop/attendee-baseline.md` — documents the attendee/maintainer
  boundary.
- `.github/instructions/repository-maintenance.instructions.md` — scopes
  maintenance rules to the new assets.
- `.github/workflows/validate-template.yml` — runs the focused tests and
  validator in CI.
- `scripts/validate-template-baseline.sh` and
  `scripts/test-template-baseline-validator.sh` — include the maintainer
  catalog in the template boundary.

### Task 1: Add failing maintainer catalog tests

**Files:**
- Create: `scripts/test-maintainer-skills.sh`
- Test: `scripts/test-maintainer-skills.sh`

- [ ] **Step 1: Create the focused fixture test**

Create `scripts/test-maintainer-skills.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="${PYTHON_BIN:-python3}"
fixture="$(mktemp -d "$repo_root/.maintainer-skills-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
}

write_skill() {
  local root="$1"
  local name="$2"
  local content="$3"

  mkdir -p "$root/$name"
  printf '%s\n' "$content" >"$root/$name/SKILL.md"
}

content_hash() {
  "$python_bin" - "$1" <<'PY'
from pathlib import Path
import hashlib
import sys

root = Path(sys.argv[1])
digest = hashlib.sha256()
for path in sorted(p for p in root.rglob("*") if p.is_file()):
    relative = path.relative_to(root).as_posix().encode()
    content = path.read_bytes()
    digest.update(len(relative).to_bytes(8, "big"))
    digest.update(relative)
    digest.update(len(content).to_bytes(8, "big"))
    digest.update(content)
print(digest.hexdigest())
PY
}

write_fixture() {
  rm -rf "$fixture"
  mkdir -p \
    "$fixture/.github/skills/code-review" \
    "$fixture/docs/agents/maintainer-skills/research" \
    "$fixture/scripts"
  printf '%s\n' '# Code review' \
    >"$fixture/.github/skills/code-review/SKILL.md"
  printf '%s\n' '# Research' \
    >"$fixture/docs/agents/maintainer-skills/research/SKILL.md"
  cat >"$fixture/skills-lock.json" <<'EOF'
{
  "version": 1,
  "skills": {
    "code-review": {
      "source": "mattpocock/skills"
    }
  }
}
EOF
  cp "$repo_root/scripts/maintainer_skills.py" "$fixture/scripts/"
  cp "$repo_root/scripts/validate-maintainer-skills.sh" "$fixture/scripts/"
  cp "$repo_root/scripts/setup-maintainer-skills.sh" "$fixture/scripts/"
  chmod +x \
    "$fixture/scripts/validate-maintainer-skills.sh" \
    "$fixture/scripts/setup-maintainer-skills.sh"
  cat >"$fixture/maintainer-skills-lock.json" <<EOF
{
  "version": 1,
  "source": {
    "repository": "https://github.com/mattpocock/skills",
    "revision": "9c9f36ccd3995266cd675468af71639c8dde1ec5",
    "license": "MIT"
  },
  "skills": {
    "research": {
      "skillPath": "skills/engineering/research/SKILL.md",
      "contentHash": "$(content_hash "$fixture/docs/agents/maintainer-skills/research")"
    }
  }
}
EOF
}

expect_failure() {
  local expected="$1"
  shift
  local output

  if output="$("$@" 2>&1)"; then
    fail_test "command unexpectedly passed: $*"
  fi
  grep -Fq "$expected" <<<"$output" ||
    fail_test "missing failure '$expected'; output: $output"
}

write_fixture
"$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

printf '%s\n' '# changed' \
  >>"$fixture/docs/agents/maintainer-skills/research/SKILL.md"
expect_failure \
  "content hash mismatch: research" \
  "$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

write_fixture
mkdir -p "$fixture/docs/agents/maintainer-skills/extra"
printf '%s\n' '# Extra' \
  >"$fixture/docs/agents/maintainer-skills/extra/SKILL.md"
expect_failure \
  "catalog inventory mismatch: extra extra" \
  "$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

write_fixture
rm -rf "$fixture/docs/agents/maintainer-skills/research"
expect_failure \
  "catalog inventory mismatch: missing research" \
  "$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

write_fixture
"$fixture/scripts/setup-maintainer-skills.sh" "$fixture"
test -f "$fixture/.agents/skills/code-review/SKILL.md" ||
  fail_test "missing attendee skill in .agents projection"
test -f "$fixture/.agents/skills/research/SKILL.md" ||
  fail_test "missing maintainer skill in .agents projection"
test -f "$fixture/.claude/skills/code-review/SKILL.md" ||
  fail_test "missing attendee skill in .claude projection"
test -f "$fixture/.claude/skills/research/SKILL.md" ||
  fail_test "missing maintainer skill in .claude projection"
diff -qr "$fixture/.agents/skills" "$fixture/.claude/skills" >/dev/null ||
  fail_test "client projections differ"
"$fixture/scripts/setup-maintainer-skills.sh" "$fixture"

write_fixture
mkdir -p "$fixture/.agents/skills/research"
printf '%s\n' '# user-owned' >"$fixture/.agents/skills/research/SKILL.md"
expect_failure \
  "refusing to overwrite unmanaged skill: .agents/skills/research" \
  "$fixture/scripts/setup-maintainer-skills.sh" "$fixture"

echo "maintainer skill tests passed"
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x scripts/test-maintainer-skills.sh
```

- [ ] **Step 3: Run the test to verify it fails**

Run:

```bash
scripts/test-maintainer-skills.sh
```

Expected: FAIL because `scripts/maintainer_skills.py`,
`scripts/validate-maintainer-skills.sh`, and
`scripts/setup-maintainer-skills.sh` do not exist.

- [ ] **Step 4: Commit the red test**

```bash
git add scripts/test-maintainer-skills.sh
git commit -m "test: define maintainer skill catalog contract" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: 536ab509-11e6-42e7-af93-6e48501c28d5"
```

### Task 2: Implement catalog validation and safe projection

**Files:**
- Create: `scripts/maintainer_skills.py`
- Create: `scripts/validate-maintainer-skills.sh`
- Create: `scripts/setup-maintainer-skills.sh`
- Test: `scripts/test-maintainer-skills.sh`

- [ ] **Step 1: Create the Python implementation**

Create `scripts/maintainer_skills.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

CATALOG = Path("docs/agents/maintainer-skills")
LOCK = Path("maintainer-skills-lock.json")
ATTENDEE = Path(".github/skills")
PROJECTIONS = (Path(".agents/skills"), Path(".claude/skills"))
MARKER = ".maintainer-skills-managed.json"


class SkillError(RuntimeError):
    pass


def content_hash(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        relative = path.relative_to(root).as_posix().encode()
        content = path.read_bytes()
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


def directory_names(root: Path) -> set[str]:
    if not root.is_dir():
        raise SkillError(f"missing directory: {root.as_posix()}")
    return {path.name for path in root.iterdir() if path.is_dir()}


def load_lock(root: Path) -> dict:
    path = root / LOCK
    if not path.is_file():
        raise SkillError(f"missing lock file: {LOCK.as_posix()}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SkillError(f"invalid lock file: {error}") from error
    if data.get("version") != 1 or not isinstance(data.get("skills"), dict):
        raise SkillError("invalid lock schema")
    return data


def attendee_names(root: Path) -> list[str]:
    path = root / "skills-lock.json"
    if not path.is_file():
        raise SkillError("missing attendee lock file: skills-lock.json")
    try:
        lock = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SkillError(f"invalid attendee lock file: {error}") from error
    locked = set(lock.get("skills", {}))
    installed = directory_names(root / ATTENDEE)
    missing = sorted(installed - locked)
    extra = sorted(locked - installed)
    if missing:
        raise SkillError(
            f"attendee inventory mismatch: missing {', '.join(missing)}"
        )
    if extra:
        raise SkillError(
            f"attendee inventory mismatch: extra {', '.join(extra)}"
        )
    return sorted(locked)


def validate(root: Path) -> list[str]:
    lock = load_lock(root)
    catalog_root = root / CATALOG
    locked = set(lock["skills"])
    installed = directory_names(catalog_root)
    missing = sorted(locked - installed)
    extra = sorted(installed - locked)
    if missing:
        raise SkillError(f"catalog inventory mismatch: missing {', '.join(missing)}")
    if extra:
        raise SkillError(f"catalog inventory mismatch: extra {', '.join(extra)}")
    for name in sorted(locked):
        skill_root = catalog_root / name
        if not (skill_root / "SKILL.md").is_file():
            raise SkillError(f"missing SKILL.md: {name}")
        expected = lock["skills"][name].get("contentHash")
        actual = content_hash(skill_root)
        if actual != expected:
            raise SkillError(f"content hash mismatch: {name}")
    return sorted(locked)


def load_managed_names(projection: Path) -> set[str]:
    marker = projection / MARKER
    if not marker.exists():
        return set()
    try:
        data = json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SkillError(
            f"invalid projection marker: {marker.as_posix()}"
        ) from error
    names = data.get("skills")
    if not isinstance(names, list) or not all(isinstance(name, str) for name in names):
        raise SkillError(f"invalid projection marker: {marker.as_posix()}")
    return set(names)


def source_skills(root: Path, maintainer_names: list[str]) -> dict[str, Path]:
    sources = {
        name: root / ATTENDEE / name
        for name in attendee_names(root)
    }
    for name in maintainer_names:
        if name in sources:
            raise SkillError(f"duplicate skill across catalogs: {name}")
        sources[name] = root / CATALOG / name
    return sources


def preflight_projection(
    root: Path, projection: Path, expected: set[str]
) -> set[str]:
    absolute = root / projection
    managed = load_managed_names(absolute)
    for name in expected:
        destination = absolute / name
        if destination.exists() and name not in managed:
            raise SkillError(
                f"refusing to overwrite unmanaged skill: "
                f"{(projection / name).as_posix()}"
            )
    return managed


def project(root: Path) -> None:
    maintainer_names = validate(root)
    sources = source_skills(root, maintainer_names)
    expected = set(sources)
    managed_by_projection = {
        projection: preflight_projection(root, projection, expected)
        for projection in PROJECTIONS
    }
    for projection in PROJECTIONS:
        absolute = root / projection
        absolute.mkdir(parents=True, exist_ok=True)
        managed = managed_by_projection[projection]
        for name in sorted(managed | expected):
            destination = absolute / name
            if destination.exists():
                if name not in managed:
                    continue
                if destination.is_dir() and not destination.is_symlink():
                    shutil.rmtree(destination)
                else:
                    destination.unlink()
            if name in sources:
                shutil.copytree(sources[name], destination)
        marker = absolute / MARKER
        marker.write_text(
            json.dumps({"version": 1, "skills": sorted(expected)}, indent=2)
            + "\n",
            encoding="utf-8",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project"))
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.command == "validate":
            validate(root)
            print("maintainer skills are structurally valid")
        else:
            project(root)
            print("maintainer skills projected for local clients")
    except SkillError as error:
        print(f"maintainer skills invalid: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Add the stable Bash wrappers**

Create `scripts/validate-maintainer-skills.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
python3 "$repo_root/scripts/maintainer_skills.py" validate --root "$repo_root"
```

Create `scripts/setup-maintainer-skills.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
python3 "$repo_root/scripts/maintainer_skills.py" project --root "$repo_root"
```

- [ ] **Step 3: Make the commands executable**

Run:

```bash
chmod +x \
  scripts/maintainer_skills.py \
  scripts/validate-maintainer-skills.sh \
  scripts/setup-maintainer-skills.sh
```

- [ ] **Step 4: Run the focused test**

Run:

```bash
scripts/test-maintainer-skills.sh
```

Expected: `maintainer skill tests passed`.

- [ ] **Step 5: Commit the implementation**

```bash
git add \
  scripts/maintainer_skills.py \
  scripts/validate-maintainer-skills.sh \
  scripts/setup-maintainer-skills.sh
git commit -m "feat: validate and project maintainer skills" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: 536ab509-11e6-42e7-af93-6e48501c28d5"
```

### Task 3: Vendor and lock the approved maintainer catalog

**Files:**
- Create: `docs/agents/maintainer-skills/**`
- Create: `docs/agents/maintainer-skills/LICENSE`
- Create: `maintainer-skills-lock.json`
- Test: `scripts/validate-maintainer-skills.sh`

- [ ] **Step 1: Copy only the approved skill directories**

Run:

```bash
mkdir -p docs/agents/maintainer-skills
for name in \
  ask-matt \
  grill-me \
  grill-with-docs \
  handoff \
  implement \
  improve-codebase-architecture \
  research \
  resolving-merge-conflicts \
  setup-matt-pocock-skills \
  teach \
  to-questionnaire \
  to-tickets \
  triage \
  wait-what \
  wizard \
  writing-for-agents; do
  cp -a ".agents/skills/$name" "docs/agents/maintainer-skills/$name"
done
```

- [ ] **Step 2: Add the upstream MIT license**

Run:

```bash
gh api repos/mattpocock/skills/contents/LICENSE \
  --jq .content \
  | base64 --decode \
  > docs/agents/maintainer-skills/LICENSE
```

Verify:

```bash
grep -Fq "MIT License" docs/agents/maintainer-skills/LICENSE
```

Expected: exit 0.

- [ ] **Step 3: Generate the separate lock file**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import hashlib
import json

root = Path("docs/agents/maintainer-skills")
paths = {
    "ask-matt": "skills/engineering/ask-matt/SKILL.md",
    "grill-me": "skills/productivity/grill-me/SKILL.md",
    "grill-with-docs": "skills/engineering/grill-with-docs/SKILL.md",
    "handoff": "skills/productivity/handoff/SKILL.md",
    "implement": "skills/engineering/implement/SKILL.md",
    "improve-codebase-architecture":
        "skills/engineering/improve-codebase-architecture/SKILL.md",
    "research": "skills/engineering/research/SKILL.md",
    "resolving-merge-conflicts":
        "skills/engineering/resolving-merge-conflicts/SKILL.md",
    "setup-matt-pocock-skills":
        "skills/engineering/setup-matt-pocock-skills/SKILL.md",
    "teach": "skills/productivity/teach/SKILL.md",
    "to-questionnaire": "skills/productivity/to-questionnaire/SKILL.md",
    "to-tickets": "skills/engineering/to-tickets/SKILL.md",
    "triage": "skills/engineering/triage/SKILL.md",
    "wait-what": "skills/productivity/wait-what/SKILL.md",
    "wizard": "skills/engineering/wizard/SKILL.md",
    "writing-for-agents":
        "skills/productivity/writing-for-agents/SKILL.md",
}


def content_hash(skill_root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(p for p in skill_root.rglob("*") if p.is_file()):
        relative = path.relative_to(skill_root).as_posix().encode()
        content = path.read_bytes()
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


lock = {
    "version": 1,
    "source": {
        "repository": "https://github.com/mattpocock/skills",
        "revision": "9c9f36ccd3995266cd675468af71639c8dde1ec5",
        "license": "MIT",
    },
    "skills": {
        name: {
            "skillPath": paths[name],
            "contentHash": content_hash(root / name),
        }
        for name in sorted(paths)
    },
}
Path("maintainer-skills-lock.json").write_text(
    json.dumps(lock, indent=2) + "\n",
    encoding="utf-8",
)
PY
```

- [ ] **Step 4: Validate the real catalog**

Run:

```bash
scripts/validate-maintainer-skills.sh
```

Expected: `maintainer skills are structurally valid`.

- [ ] **Step 5: Restore and confirm the attendee inventory**

Run:

```bash
git restore skills-lock.json
git diff --exit-code HEAD -- .github/skills skills-lock.json
```

Expected: exit 0.

- [ ] **Step 6: Commit the catalog**

```bash
git add docs/agents/maintainer-skills maintainer-skills-lock.json
git commit -m "feat: vendor maintainer skill catalog" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: 536ab509-11e6-42e7-af93-6e48501c28d5"
```

### Task 4: Integrate the catalog with repository boundaries

**Files:**
- Modify: `.gitignore`
- Modify: `.github/instructions/repository-maintenance.instructions.md`
- Modify: `.github/workflows/validate-template.yml`
- Modify: `docs/workshop/attendee-baseline.md`
- Modify: `scripts/validate-template-baseline.sh`
- Modify: `scripts/test-template-baseline-validator.sh`
- Test: `scripts/test-maintainer-skills.sh`
- Test: `scripts/test-template-baseline-validator.sh`

- [ ] **Step 1: Add generated projection roots to `.gitignore`**

Append:

```gitignore

### Maintainer skill projections ###
/.agents/
/.claude/
```

- [ ] **Step 2: Extend repository-maintenance scope**

Change the frontmatter `applyTo` value in
`.github/instructions/repository-maintenance.instructions.md` to include:

```text
maintainer-skills-lock.json,docs/agents/maintainer-skills/**,scripts/maintainer_skills.py,scripts/validate-maintainer-skills.sh,scripts/test-maintainer-skills.sh,scripts/setup-maintainer-skills.sh
```

Add this rule:

```markdown
- Keep maintainer-only skills in the non-discovery catalog and generate client projections only through `scripts/setup-maintainer-skills.sh`; never expand the attendee `.github/skills` inventory as a side effect.
```

- [ ] **Step 3: Document the explicit maintainer boundary**

Add after the exact supported workshop skill list in
`docs/workshop/attendee-baseline.md`:

```markdown
Additional maintainer-only skills are stored under
`docs/agents/maintainer-skills/`, outside automatic discovery. Maintainers may
generate ignored local client projections with
`scripts/setup-maintainer-skills.sh`. Those projections and the maintainer
catalog do not expand the supported attendee skill set.
```

Add `scripts/validate-maintainer-skills.sh` and
`scripts/test-maintainer-skills.sh` to the validation command block.

- [ ] **Step 4: Include maintainer validation in the template validator**

In `scripts/validate-template-baseline.sh`, require these files:

```bash
maintainer_lock="$root/maintainer-skills-lock.json"
maintainer_validator="$root/scripts/validate-maintainer-skills.sh"

test -f "$maintainer_lock" ||
  fail "missing maintainer-skills-lock.json"
test -x "$maintainer_validator" ||
  fail "missing executable maintainer skill validator"
"$maintainer_validator" "$root"
```

Place the block immediately before the existing final success message.

- [ ] **Step 5: Copy maintainer assets into the clean baseline fixture**

Add these paths to `copy_clean_copilot_assets` in
`scripts/test-template-baseline-validator.sh`:

```bash
"maintainer-skills-lock.json"
"scripts/maintainer_skills.py"
"scripts/validate-maintainer-skills.sh"
```

Add a mutation after the clean fixture passes:

```bash
printf '%s\n' '# changed' \
  >>"$fixture/docs/agents/maintainer-skills/research/SKILL.md"
expect_failure "content hash mismatch: research"
```

- [ ] **Step 6: Run focused regression tests**

Run:

```bash
scripts/test-maintainer-skills.sh
scripts/validate-maintainer-skills.sh
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
```

Expected:

```text
maintainer skill tests passed
maintainer skills are structurally valid
template baseline validator tests passed
template baseline is structurally clean
```

- [ ] **Step 7: Add CI steps**

In `.github/workflows/validate-template.yml`, after checkout and before the
existing template checks, add:

```yaml
      - name: Test maintainer skill catalog
        run: scripts/test-maintainer-skills.sh
      - name: Validate maintainer skill catalog
        run: scripts/validate-maintainer-skills.sh
```

- [ ] **Step 8: Commit the repository integration**

```bash
git add \
  .gitignore \
  .github/instructions/repository-maintenance.instructions.md \
  .github/workflows/validate-template.yml \
  docs/workshop/attendee-baseline.md \
  scripts/validate-template-baseline.sh \
  scripts/test-template-baseline-validator.sh
git commit -m "chore: isolate maintainer skill projections" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: 536ab509-11e6-42e7-af93-6e48501c28d5"
```

### Task 5: Migrate local projections and verify the complete change

**Files:**
- Generate ignored: `.agents/skills/**`
- Generate ignored: `.claude/skills/**`
- Verify: all files changed by Tasks 1–4

- [ ] **Step 1: Remove only the current generated projections**

Run:

```bash
rm -rf -- .agents/skills .claude/skills
rmdir .agents .claude 2>/dev/null || true
```

The resolved paths are the two generated projection directories named in the
approved Work Contract; do not broaden either deletion target.

- [ ] **Step 2: Regenerate local projections**

Run:

```bash
scripts/setup-maintainer-skills.sh
```

Expected: `maintainer skills projected for local clients`.

- [ ] **Step 3: Verify generated state is ignored and untracked**

Run:

```bash
git check-ignore -q .agents/skills/research/SKILL.md
git check-ignore -q .claude/skills/research/SKILL.md
test -z "$(git ls-files -- .agents .claude)"
```

Expected: exit 0.

- [ ] **Step 4: Run the complete focused validation**

Run:

```bash
scripts/test-maintainer-skills.sh
scripts/validate-maintainer-skills.sh
scripts/test-copilot-assets.sh
scripts/validate-copilot-assets.sh
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
git diff --check
```

Expected: every command exits 0; the Copilot validator still reports the exact
attendee inventory as structurally valid.

- [ ] **Step 5: Verify the application baseline**

Run:

```bash
./mvnw -B verify
```

Expected: `BUILD SUCCESS` with 0 failures and 0 errors.

- [ ] **Step 6: Verify repository cleanliness**

Run:

```bash
git status --short
```

Expected: no output after all intended commits; ignored `.agents/` and
`.claude/` projections do not appear.

- [ ] **Step 7: Push the completed implementation**

Run:

```bash
git push origin main
```

Expected: `main` advances on `origin` with the implementation commits.
