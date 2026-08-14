#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cleanup_command="$root/scripts/azure-cleanup.sh"
library="$root/scripts/lib/workshop-azure.sh"
fake_command="$root/scripts/fixtures/workshop-azure/fake-command.sh"
scratch="$root/scripts/.test-azure-cleanup.$$"
subscription_id="11111111-2222-3333-4444-555555555555"
resource_group="rg-workshop-secret"
foundry="foundry-workshop-secret"
location="swedencentral"
environment_name="workshop-safe"
deleted_id="/subscriptions/$subscription_id/providers/Microsoft.CognitiveServices/locations/$location/resourceGroups/$resource_group/deletedAccounts/$foundry"
deleted_query="[?name=='$foundry' && location=='$location'].id | [0]"
active_query="[?resourceGroup=='$resource_group' && (type=='Microsoft.Web/serverfarms' || type=='Microsoft.Web/sites' || type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.CognitiveServices/accounts/deployments')].type"

cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT
mkdir -p "$scratch"

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
}

add_call() {
  local fixture_dir="$1"
  local number="$2"
  local command="$3"
  local stdout="${4-}"
  shift 4
  local prefix="$fixture_dir/$(printf '%03d' "$number")-$command"
  : >"$prefix.args"
  if (( $# > 0 )); then
    printf '%s\n' "$@" >"$prefix.args"
  fi
  printf '%s' "$stdout" >"$prefix.stdout"
}

set_status() {
  local fixture_dir="$1"
  local number="$2"
  local command="$3"
  printf '%s\n' "$4" >"$fixture_dir/$(printf '%03d' "$number")-$command.status"
}

start_fixture() {
  local name="$1"
  local case_dir="$scratch/$name"
  local fixture_dir="$case_dir/fixtures"
  local bin_dir="$case_dir/bin"
  local project_dir="$case_dir/project"
  local command

  test -f "$cleanup_command" ||
    fail_test "$cleanup_command does not exist"
  mkdir -p "$fixture_dir" "$bin_dir" "$project_dir/scripts/lib" "$case_dir/evidence"
  cp "$cleanup_command" "$project_dir/scripts/azure-cleanup.sh"
  cp "$library" "$project_dir/scripts/lib/workshop-azure.sh"

  for command in az azd date sleep; do
    ln -s "$fake_command" "$bin_dir/$command"
  done
  for command in bash basename cat dirname mkdir rm wc; do
    ln -s "$(command -v "$command")" "$bin_dir/$command"
  done

  add_call "$fixture_dir" 1 azd "$foundry" env get-value AZURE_OPENAI_ACCOUNT_NAME
  add_call "$fixture_dir" 2 azd "$location" env get-value AZURE_LOCATION
  add_call "$fixture_dir" 3 azd "$resource_group" env get-value AZURE_RESOURCE_GROUP_NAME
  add_call "$fixture_dir" 4 azd "$environment_name" env get-value AZURE_ENV_NAME
  add_call "$fixture_dir" 5 az "$subscription_id" \
    account show --query id --output tsv
}

add_down_and_absence_checks() {
  local name="$1"
  local group_exists="${2-false}"
  local active_resources="${3-}"
  local fixture_dir="$scratch/$name/fixtures"

  add_call "$fixture_dir" 6 azd '' down --force --purge
  add_call "$fixture_dir" 7 az "$group_exists" \
    group exists --name "$resource_group" --output tsv
  [[ "$group_exists" == false ]] || return 0
  add_call "$fixture_dir" 8 az "$active_resources" \
    resource list --query "$active_query" --output tsv
}

add_success_dates() {
  local fixture_dir="$1"
  local number="$2"
  add_call "$fixture_dir" "$number" date '20260814T092537Z' -u +%Y%m%dT%H%M%SZ
  add_call "$fixture_dir" "$((number + 1))" date \
    '2026-08-14T09:25:37Z' -u +%Y-%m-%dT%H:%M:%SZ
}

run_case() {
  local name="$1"
  local expected_status="$2"
  local expected_message="${3-}"
  local case_dir="$scratch/$name"
  local status=0

  WORKSHOP_AZURE_FIXTURE_DIR="$case_dir/fixtures" \
    WORKSHOP_AZURE_COMMAND_LOG="$case_dir/commands.log" \
    WORKSHOP_AZURE_EVIDENCE_DIR="$case_dir/evidence" \
    WORKSHOP_AZURE_RETRY_SECONDS=1 \
    WORKSHOP_AZURE_RETRY_ATTEMPTS=3 \
    PATH="$case_dir/bin" \
    "$case_dir/project/scripts/azure-cleanup.sh" \
    >"$case_dir/stdout" 2>"$case_dir/stderr" || status=$?

  [[ "$status" -eq "$expected_status" ]] ||
    fail_test "$name exited $status, expected $expected_status: $(cat "$case_dir/stderr")"
  if [[ -n "$expected_message" ]]; then
    grep -Fqx "$expected_message" "$case_dir/stderr" ||
      fail_test "$name did not emit exact failure: $expected_message; got: $(cat "$case_dir/stderr")"
  fi
}

start_fixture normal-purge
add_down_and_absence_checks normal-purge
add_call "$scratch/normal-purge/fixtures" 9 az '' \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_success_dates "$scratch/normal-purge/fixtures" 10
run_case normal-purge 0
[[ "$(wc -l <"$scratch/normal-purge/commands.log")" -eq 11 ]] ||
  fail_test 'normal purge executed unexpected commands'
! grep -Fq 'cognitiveservices account purge' "$scratch/normal-purge/commands.log" ||
  fail_test 'normal purge unexpectedly issued an explicit purge'

evidence="$scratch/normal-purge/evidence/cleanup-20260814T092537Z.md"
test -f "$evidence" || fail_test 'timestamped cleanup evidence was not created'
for expected in \
  'Command version: `1.0.0`' \
  'Evidence schema version: `1.0`' \
  'UTC: `2026-08-14T09:25:37Z`' \
  'Subscription: `11111111...5555`' \
  'Region: `swedencentral`' \
  'Environment: `workshop-safe`' \
  'Explicit Foundry purge required: `no`' \
  'Resource group absent: `PASS`' \
  'App Service plans absent: `PASS`' \
  'Web apps absent: `PASS`' \
  'Active Foundry resources absent: `PASS`' \
  'Model deployments absent: `PASS`' \
  'Deleted Foundry accounts absent: `PASS`' \
  'Cost Management is eventually consistent. After billing data catches up,' \
  'confirm that this environment has no continuing resource charge.'; do
  grep -Fq "$expected" "$evidence" ||
    fail_test "cleanup evidence omitted expected field: $expected"
done
for forbidden in "$subscription_id" "$resource_group" "$foundry" "$deleted_id" \
  '[]' '{"'; do
  ! grep -Fq "$forbidden" "$evidence" ||
    fail_test "cleanup evidence disclosed forbidden value: $forbidden"
done

start_fixture explicit-purge
add_down_and_absence_checks explicit-purge
add_call "$scratch/explicit-purge/fixtures" 9 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/explicit-purge/fixtures" 10 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location"
add_call "$scratch/explicit-purge/fixtures" 11 az '' \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_success_dates "$scratch/explicit-purge/fixtures" 12
run_case explicit-purge 0
grep -Fq 'Explicit Foundry purge required: `yes`' \
  "$scratch/explicit-purge/evidence/cleanup-20260814T092537Z.md"

start_fixture two-retries
add_down_and_absence_checks two-retries
add_call "$scratch/two-retries/fixtures" 9 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/two-retries/fixtures" 10 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location"
add_call "$scratch/two-retries/fixtures" 11 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/two-retries/fixtures" 12 sleep '' 1
add_call "$scratch/two-retries/fixtures" 13 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/two-retries/fixtures" 14 sleep '' 1
add_call "$scratch/two-retries/fixtures" 15 az '' \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_success_dates "$scratch/two-retries/fixtures" 16
run_case two-retries 0
[[ "$(grep -c '^sleep ' "$scratch/two-retries/commands.log")" -eq 2 ]] ||
  fail_test 'soft-delete propagation did not retry twice'

start_fixture remaining-rg
add_down_and_absence_checks remaining-rg true
run_case remaining-rg 1 \
  'ERROR: resource group still exists after azd down: cleanup is incomplete'
[[ "$(wc -l <"$scratch/remaining-rg/commands.log")" -eq 7 ]] ||
  fail_test 'remaining resource group did not stop cleanup'

start_fixture active-resources
add_down_and_absence_checks active-resources false \
  $'Microsoft.Web/serverfarms\nMicrosoft.Web/sites\nMicrosoft.CognitiveServices/accounts\nMicrosoft.CognitiveServices/accounts/deployments'
run_case active-resources 1 \
  'ERROR: active App Service or Foundry resources remain after azd down'
[[ "$(wc -l <"$scratch/active-resources/commands.log")" -eq 8 ]] ||
  fail_test 'active resources did not stop before soft-delete inspection'

start_fixture down-failure
add_down_and_absence_checks down-failure
set_status "$scratch/down-failure/fixtures" 6 azd 1
run_case down-failure 1 'ERROR: azd down --force --purge failed'
[[ "$(wc -l <"$scratch/down-failure/commands.log")" -eq 6 ]] ||
  fail_test 'azd down failure did not stop cleanup'

start_fixture purge-failure
add_down_and_absence_checks purge-failure
add_call "$scratch/purge-failure/fixtures" 9 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/purge-failure/fixtures" 10 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location"
set_status "$scratch/purge-failure/fixtures" 10 az 1
run_case purge-failure 1 'ERROR: explicit Foundry purge failed'
[[ "$(wc -l <"$scratch/purge-failure/commands.log")" -eq 10 ]] ||
  fail_test 'purge failure did not stop propagation checks'

start_fixture timeout
add_down_and_absence_checks timeout
add_call "$scratch/timeout/fixtures" 9 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/timeout/fixtures" 10 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location"
add_call "$scratch/timeout/fixtures" 11 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/timeout/fixtures" 12 sleep '' 1
add_call "$scratch/timeout/fixtures" 13 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_call "$scratch/timeout/fixtures" 14 sleep '' 1
add_call "$scratch/timeout/fixtures" 15 az "$deleted_id" \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
run_case timeout 1 \
  'ERROR: Foundry soft-delete absence did not succeed after 3 attempts'
test ! -e "$scratch/timeout/evidence/cleanup-20260814T092537Z.md" ||
  fail_test 'timeout wrote passing cleanup evidence'

start_fixture unsafe-environment
printf '%s' "$resource_group" >"$scratch/unsafe-environment/fixtures/004-azd.stdout"
add_down_and_absence_checks unsafe-environment
add_call "$scratch/unsafe-environment/fixtures" 9 az '' \
  cognitiveservices account list-deleted --query "$deleted_query" --output tsv
add_success_dates "$scratch/unsafe-environment/fixtures" 10
run_case unsafe-environment 0
grep -Fq 'Environment: `not recorded (unsafe or unavailable)`' \
  "$scratch/unsafe-environment/evidence/cleanup-20260814T092537Z.md"
! grep -Fq "$resource_group" \
  "$scratch/unsafe-environment/evidence/cleanup-20260814T092537Z.md"

echo 'Azure cleanup tests passed'
