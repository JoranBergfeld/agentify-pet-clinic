#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo_root/scripts/validate-template-baseline.sh"
fixture="$(mktemp -d "$repo_root/.template-baseline-validator-fixture.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

write_clean_provenance() {
  cat >"$fixture/workshop/baseline.properties" <<'EOF'
upstream.repository=https://github.com/spring-projects/spring-petclinic.git
upstream.commit=88e37c15cf6fc8490b01bc3e8e2c800cec1ac272
EOF
}

write_clean_pom() {
  cat >"$fixture/pom.xml" <<'EOF'
<project><dependencies></dependencies></project>
EOF
}

expect_failure() {
  local expected="$1"
  local output

  if output="$("$validator" "$fixture" 2>&1)"; then
    echo "validator unexpectedly passed: $expected" >&2
    exit 1
  fi

  test "$output" = "template baseline invalid: $expected"
}

mkdir -p "$fixture/workshop" "$fixture/src/main/java" "$fixture/docs"
write_clean_provenance
write_clean_pom
touch "$fixture/mvnw"
chmod +x "$fixture/mvnw"

clean_output="$("$validator" "$fixture")"
test "$clean_output" = "template baseline is structurally clean"

mkdir -p "$fixture/src/main/java/org/springframework/samples/petclinic/assistant"
expect_failure "Clinic Assistant solution code is present"
rm -rf "$fixture/src/main/java/org/springframework/samples/petclinic/assistant"

printf '<project><artifactId>spring-ai-starter-model-openai</artifactId></project>\n' >"$fixture/pom.xml"
expect_failure "Spring AI application dependency is present"
write_clean_pom

rm "$fixture/mvnw"
expect_failure "missing Maven wrapper"
touch "$fixture/mvnw"
chmod +x "$fixture/mvnw"

rm "$fixture/pom.xml"
expect_failure "missing Maven project"
write_clean_pom

printf '%s\n' \
  'upstream.repository=https://example.com/not-petclinic.git' \
  'upstream.commit=88e37c15cf6fc8490b01bc3e8e2c800cec1ac272' \
  >"$fixture/workshop/baseline.properties"
expect_failure "unexpected upstream repository"
write_clean_provenance

printf '%s\n' \
  'upstream.repository=https://github.com/spring-projects/spring-petclinic.git' \
  'upstream.commit=deadbeef' \
  >"$fixture/workshop/baseline.properties"
expect_failure "unexpected upstream commit"
write_clean_provenance

touch "$fixture/.env"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/.env"

touch "$fixture/terraform.tfstate"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/terraform.tfstate"

touch "$fixture/azureProfile.json"
expect_failure "generated secret-bearing environment file is present"
rm "$fixture/azureProfile.json"

mkdir -p "$fixture/.git" "$fixture/.worktrees/example"
touch "$fixture/.git/azureProfile.json" "$fixture/.worktrees/example/terraform.tfstate"
clean_output="$("$validator" "$fixture")"
test "$clean_output" = "template baseline is structurally clean"

echo "template baseline validator tests passed"
