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

contains_clinic_assistant_ui_marker() {
  local file="$1"

  test -f "$file" || return 1
  grep -Eq 'clinic-assistant|clinicAssistant' "$file"
}

contains_spring_ai_application_property() {
  local file="$1"

  test -f "$file" || return 1
  grep -Fq 'spring.ai.' "$file"
}

require_absent_reference_only_directory() {
  local relative_dir="$1"

  test ! -e "$root/$relative_dir" \
    || fail "reference-only directory is present: $relative_dir/"
}

require_absent_reference_only_file() {
  local relative_path="$1"

  test ! -e "$root/$relative_path" \
    || fail "reference-only file is present: $relative_path"
}

require_safe_generated_evidence() {
  local evidence_file
  local relative_path
  local tracked_evidence

  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tracked_evidence="$(
      git -C "$root" ls-files -- '.workshop-evidence' '.workshop-evidence/**'
    )"
    [[ -z "$tracked_evidence" ]] ||
      fail "tracked generated evidence is present: .workshop-evidence/"
    if [[ -d "$root/.workshop-evidence" ]]; then
      while IFS= read -r -d '' evidence_file; do
        relative_path="${evidence_file#"$root/"}"
        git -C "$root" check-ignore --quiet -- "$relative_path" ||
          fail "unignored generated evidence is present: .workshop-evidence/"
      done < <(
        find "$root/.workshop-evidence" \( -type f -o -type l \) -print0
      )
    fi
  else
    test ! -e "$root/.workshop-evidence" ||
      fail "generated evidence directory is present: .workshop-evidence/"
  fi
}

is_secret_bearing_path() {
  local relative_path="$1"
  local filename="${relative_path##*/}"

  case "$relative_path" in
    .azure/.gitignore)
      return 1
      ;;
    .azure/*)
      return 0
      ;;
  esac

  case "$filename" in
    .env* | *.tfstate* | azureProfile.json)
      return 0
      ;;
  esac

  return 1
}

require_absent_secret_bearing_files() {
  local relative_path

  if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' relative_path; do
      ! is_secret_bearing_path "$relative_path" ||
        fail "generated secret-bearing environment file is present"
    done < <(git -C "$root" ls-files -z)
  fi

  while IFS= read -r -d '' _; do
    fail "generated secret-bearing environment file is present"
  done < <(
    find "$root" \
      \( -type d \( -name .git -o -name .worktrees \) -prune \) -o \
      \( -type f \( \
          -name '.env*' -o \
          -name '*.tfstate*' -o \
          -name 'azureProfile.json' -o \
          \( -path "$root/.azure/*" -a ! -path "$root/.azure/.gitignore" \) \
        \) -print0 \)
  )
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
require_absent_reference_only_directory "src/main/resources/templates/assistant"
require_safe_generated_evidence
require_absent_reference_only_file "scripts/azure-reference-smoke.sh"
require_absent_reference_only_file "scripts/test-azure-reference-smoke.sh"
! contains_clinic_assistant_ui_marker \
  "$root/src/main/resources/templates/fragments/layout.html" \
  || fail "Clinic Assistant UI marker is present in src/main/resources/templates/fragments/layout.html"
! contains_clinic_assistant_ui_marker \
  "$root/src/main/resources/messages/messages.properties" \
  || fail "Clinic Assistant UI marker is present in src/main/resources/messages/messages.properties"
! contains_clinic_assistant_ui_marker "$root/src/main/scss/petclinic.scss" \
  || fail "Clinic Assistant UI marker is present in src/main/scss/petclinic.scss"
! contains_spring_ai_application_property \
  "$root/src/main/resources/application.properties" \
  || fail "Spring AI application property is present in src/main/resources/application.properties"

require_absent_secret_bearing_files

copilot_validator="$root/scripts/validate-copilot-assets.sh"
test -f "$copilot_validator" ||
  fail "missing Copilot asset validator: scripts/validate-copilot-assets.sh"
test -x "$copilot_validator" ||
  fail "Copilot asset validator is not executable: scripts/validate-copilot-assets.sh"
"$copilot_validator" "$root"

echo "template baseline is structurally clean"
