#!/usr/bin/env bash
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
provenance="$root/workshop/baseline.properties"

fail() {
  echo "template baseline invalid: $*" >&2
  exit 1
}

contains_spring_ai_reference() {
  local file="$1"

  test -f "$file" || return 1
  grep -Eq 'spring-ai-|org\.springframework\.ai' "$file"
}

require_absent_reference_only_directory() {
  local relative_dir="$1"

  test ! -e "$root/$relative_dir" \
    || fail "reference-only directory is present: $relative_dir/"
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
! contains_spring_ai_reference "$root/pom.xml" \
  || fail "Spring AI application dependency is present"
! contains_spring_ai_reference "$root/build.gradle" \
  || fail "Spring AI application dependency is present"
require_absent_reference_only_directory "docs/reference"
require_absent_reference_only_directory "workshop/reference"
require_absent_reference_only_directory "workshop/completed"

if find "$root" \
  \( -type d \( -name .git -o -name .worktrees \) -prune \) -o \
  \( -type f \( \
      -name '.env' -o \
      -name '.env.*' -o \
      -name '*.tfstate' -o \
      -name '*.tfstate.backup' -o \
      -name 'azureProfile.json' -o \
      \( -path "$root/.azure/*" -a ! -path "$root/.azure/.gitignore" \) \
    \) -print -quit \) \
  | grep -q .; then
  fail "generated secret-bearing environment file is present"
fi

echo "template baseline is structurally clean"
