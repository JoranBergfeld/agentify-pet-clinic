#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="${PYTHON_BIN:-python3}"
fixture="$(mktemp -d "$repo_root/.maintainer-skills-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

approved_skills=(
  ask-matt
  grill-me
  grill-with-docs
  handoff
  implement
  improve-codebase-architecture
  research
  resolving-merge-conflicts
  setup-matt-pocock-skills
  teach
  to-questionnaire
  to-tickets
  triage
  wait-what
  wizard
  writing-for-agents
)

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
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
    "$fixture/docs/agents/maintainer-skills" \
    "$fixture/scripts"
  printf '%s\n' '# Code review' \
    >"$fixture/.github/skills/code-review/SKILL.md"
  for name in "${approved_skills[@]}"; do
    mkdir -p "$fixture/docs/agents/maintainer-skills/$name"
    printf '# %s\n' "$name" \
      >"$fixture/docs/agents/maintainer-skills/$name/SKILL.md"
  done
  cat >>"$fixture/docs/agents/maintainer-skills/implement/SKILL.md" <<'EOF'
Require an authorized Work Contract before implementation.
Pause for the human Commitment Gate before execution.
Commit or push only with explicit human authorization.
Commit your work to the current branch only after explicit human authorization.
EOF
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
  "$python_bin" - "$fixture" "${approved_skills[@]}" <<'PY'
from pathlib import Path
import hashlib
import json
import sys

root = Path(sys.argv[1])
names = sys.argv[2:]


def content_hash(skill_root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(path for path in skill_root.rglob("*") if path.is_file()):
        relative = path.relative_to(skill_root).as_posix().encode()
        content = path.read_bytes()
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


catalog = root / "docs/agents/maintainer-skills"
lock = {
    "version": 1,
    "source": {
        "repository": "https://github.com/mattpocock/skills",
        "revision": "9c9f36ccd3995266cd675468af71639c8dde1ec5",
        "license": "MIT",
    },
    "skills": {
        name: {
            "skillPath": f"skills/{name}/SKILL.md",
            "contentHash": content_hash(catalog / name),
        }
        for name in names
    },
}
(root / "maintainer-skills-lock.json").write_text(
    json.dumps(lock, indent=2) + "\n",
    encoding="utf-8",
)
PY
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
cp -a \
  "$fixture/docs/agents/maintainer-skills/research" \
  "$fixture/docs/agents/maintainer-skills/extra"
"$python_bin" - "$fixture/maintainer-skills-lock.json" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
lock = json.loads(path.read_text(encoding="utf-8"))
lock["skills"]["extra"] = {
    "skillPath": "skills/extra/SKILL.md",
    "contentHash": lock["skills"]["research"]["contentHash"],
}
path.write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
PY
expect_failure \
  "approved maintainer inventory mismatch: extra extra" \
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

marker="$fixture/.agents/skills/.maintainer-skills-managed.json"
"$python_bin" - "$marker" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
marker = json.loads(path.read_text(encoding="utf-8"))
marker["skills"].append("../../victim")
path.write_text(json.dumps(marker, indent=2) + "\n", encoding="utf-8")
PY
printf '%s\n' 'preserve' >"$fixture/victim"
expect_failure \
  "invalid managed skill name: ../../victim" \
  "$fixture/scripts/setup-maintainer-skills.sh" "$fixture"
test "$(<"$fixture/victim")" = "preserve" ||
  fail_test "unsafe marker entry modified a path outside the projection"

write_fixture
mkdir -p "$fixture/external-projection"
ln -s "$fixture/external-projection" "$fixture/.agents"
expect_failure \
  "symlinked projection root: .agents/" \
  "$fixture/scripts/setup-maintainer-skills.sh" "$fixture"

write_fixture
"$fixture/scripts/setup-maintainer-skills.sh" "$fixture"
marker="$fixture/.agents/skills/.maintainer-skills-managed.json"
printf '%s\n' 'preserve' >"$fixture/marker-victim"
rm "$marker"
ln -s "$fixture/marker-victim" "$marker"
expect_failure \
  "symlinked projection marker: .agents/skills/.maintainer-skills-managed.json" \
  "$fixture/scripts/setup-maintainer-skills.sh" "$fixture"
test "$(<"$fixture/marker-victim")" = "preserve" ||
  fail_test "symlinked marker modified a path outside the projection"

write_fixture
mkdir -p "$fixture/.agents/skills/research"
printf '%s\n' '# user-owned' >"$fixture/.agents/skills/research/SKILL.md"
expect_failure \
  "refusing to overwrite unmanaged skill: .agents/skills/research" \
  "$fixture/scripts/setup-maintainer-skills.sh" "$fixture"

write_fixture
git -C "$fixture" init --quiet
expect_failure \
  "generated projection is not ignored: .agents/" \
  "$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

cat >"$fixture/.gitignore" <<'EOF'
/.agents/
/.claude/
EOF
"$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

mkdir -p "$fixture/.agents/skills/research"
printf '%s\n' '# tracked' >"$fixture/.agents/skills/research/SKILL.md"
git -C "$fixture" add -f .agents/skills/research/SKILL.md
expect_failure \
  "tracked generated projection: .agents/skills/research/SKILL.md" \
  "$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

write_fixture
sed -i \
  '/Require an authorized Work Contract before implementation/d' \
  "$fixture/docs/agents/maintainer-skills/implement/SKILL.md"
"$python_bin" - "$fixture" <<'PY'
from pathlib import Path
import hashlib
import json
import sys

root = Path(sys.argv[1])
skill_root = root / "docs/agents/maintainer-skills/implement"
digest = hashlib.sha256()
for path in sorted(path for path in skill_root.rglob("*") if path.is_file()):
    relative = path.relative_to(skill_root).as_posix().encode()
    content = path.read_bytes()
    digest.update(len(relative).to_bytes(8, "big"))
    digest.update(relative)
    digest.update(len(content).to_bytes(8, "big"))
    digest.update(content)
lock_path = root / "maintainer-skills-lock.json"
lock = json.loads(lock_path.read_text(encoding="utf-8"))
lock["skills"]["implement"]["contentHash"] = digest.hexdigest()
lock_path.write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
PY
expect_failure \
  "missing maintainer authority contract: implement" \
  "$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

write_fixture
printf '%s\n' \
  "Commit your work to the current branch." \
  >>"$fixture/docs/agents/maintainer-skills/implement/SKILL.md"
"$python_bin" - "$fixture" <<'PY'
from pathlib import Path
import hashlib
import json
import sys

root = Path(sys.argv[1])
skill_root = root / "docs/agents/maintainer-skills/implement"
digest = hashlib.sha256()
for path in sorted(path for path in skill_root.rglob("*") if path.is_file()):
    relative = path.relative_to(skill_root).as_posix().encode()
    content = path.read_bytes()
    digest.update(len(relative).to_bytes(8, "big"))
    digest.update(relative)
    digest.update(len(content).to_bytes(8, "big"))
    digest.update(content)
lock_path = root / "maintainer-skills-lock.json"
lock = json.loads(lock_path.read_text(encoding="utf-8"))
lock["skills"]["implement"]["contentHash"] = digest.hexdigest()
lock_path.write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
PY
expect_failure \
  "conflicting maintainer authority contract: implement" \
  "$fixture/scripts/validate-maintainer-skills.sh" "$fixture"

echo "maintainer skill tests passed"
