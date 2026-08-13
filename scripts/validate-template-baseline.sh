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
! grep -Fq 'spring-ai-' "$root/pom.xml" \
  || fail "Spring AI application dependency is present"

if find "$root" \
  \( -type d \( -name .git -o -name .worktrees \) -prune \) -o \
  \( -type f \( -name '.env' -o -name '*.tfstate' -o -name 'azureProfile.json' \) -print -quit \) \
  | grep -q .; then
  fail "generated secret-bearing environment file is present"
fi

echo "template baseline is structurally clean"
