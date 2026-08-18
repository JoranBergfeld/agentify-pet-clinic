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

echo "maintainer skill tests passed"
