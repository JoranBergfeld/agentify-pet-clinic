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
active_query="[?resourceGroup=='$resource_group' && (type=='Microsoft.Web/serverfarms' || type=='Microsoft.Web/sites' || type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.CognitiveServices/accounts/deployments')].[type, properties.provisioningState]"

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
  add_call "$fixture_dir" 5 azd "$subscription_id" env get-value AZURE_SUBSCRIPTION_ID
  add_call "$fixture_dir" 6 az "$subscription_id" \
    account show --query id --output tsv
}

add_down_and_absence_checks() {
  local name="$1"
  local group_exists="${2-false}"
  local active_resources="${3-}"
  local fixture_dir="$scratch/$name/fixtures"

  add_call "$fixture_dir" 7 azd '' down --force --purge
  add_call "$fixture_dir" 8 az "$group_exists" \
    group exists --name "$resource_group" --subscription "$subscription_id" --output tsv
  [[ "$group_exists" == false ]] || return 0
  add_call "$fixture_dir" 9 az "$active_resources" \
    resource list --subscription "$subscription_id" --query "$active_query" --output tsv
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
  local foundry_override="${4-}"
  local case_dir="$scratch/$name"
  local status=0

  WORKSHOP_AZURE_FIXTURE_DIR="$case_dir/fixtures" \
    WORKSHOP_AZURE_COMMAND_LOG="$case_dir/commands.log" \
    WORKSHOP_AZURE_EVIDENCE_DIR="$case_dir/evidence" \
    WORKSHOP_AZURE_FOUNDRY_NAME="$foundry_override" \
    WORKSHOP_AZURE_RETRY_SECONDS=0 \
    WORKSHOP_AZURE_RETRY_ATTEMPTS=5 \
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

assert_stderr_contains() {
  local name="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$scratch/$name/stderr" ||
    fail_test "$name stderr omitted: $expected; got: $(cat "$scratch/$name/stderr")"
}

start_fixture subscription-mismatch
printf '%s' 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' \
  >"$scratch/subscription-mismatch/fixtures/006-az.stdout"
run_case subscription-mismatch 1 \
  'ERROR: azd subscription does not match the active Azure CLI subscription'
[[ "$(wc -l <"$scratch/subscription-mismatch/commands.log")" -eq 6 ]] ||
  fail_test 'subscription mismatch did not fail before azd down'

start_fixture partial-provision
set_status "$scratch/partial-provision/fixtures" 1 azd 1
set_status "$scratch/partial-provision/fixtures" 3 azd 1
printf '%s\n' 'ERROR: environment value was not found' \
  >"$scratch/partial-provision/fixtures/001-azd.stdout"
printf '%s\n' 'ERROR: environment value was not found' \
  >"$scratch/partial-provision/fixtures/003-azd.stdout"
printf '%s' 'workshop-secret' \
  >"$scratch/partial-provision/fixtures/004-azd.stdout"
add_call "$scratch/partial-provision/fixtures" 7 az "$foundry" \
  cognitiveservices account list --resource-group "$resource_group" \
  --subscription "$subscription_id" --query '[0].name' --output tsv
add_call "$scratch/partial-provision/fixtures" 8 azd '' down --force --purge
add_call "$scratch/partial-provision/fixtures" 9 az false \
  group exists --name "$resource_group" --subscription "$subscription_id" --output tsv
add_call "$scratch/partial-provision/fixtures" 10 az '' \
  resource list --subscription "$subscription_id" --query "$active_query" --output tsv
for number in 11 13 15 17 19; do
  add_call "$scratch/partial-provision/fixtures" "$number" az '' \
    cognitiveservices account list-deleted --subscription "$subscription_id" \
    --query "$deleted_query" --output tsv
done
for number in 12 14 16 18; do
  add_call "$scratch/partial-provision/fixtures" "$number" sleep '' 0
done
add_success_dates "$scratch/partial-provision/fixtures" 20
run_case partial-provision 0
grep -Fq 'Azure cleanup passed' "$scratch/partial-provision/stdout" ||
  fail_test 'partial provision cleanup did not pass'

start_fixture already-absent
set_status "$scratch/already-absent/fixtures" 1 azd 1
set_status "$scratch/already-absent/fixtures" 3 azd 1
printf '%s\n' 'ERROR: environment value was not found' \
  >"$scratch/already-absent/fixtures/001-azd.stdout"
printf '%s\n' 'ERROR: environment value was not found' \
  >"$scratch/already-absent/fixtures/003-azd.stdout"
printf '%s' 'workshop-secret' \
  >"$scratch/already-absent/fixtures/004-azd.stdout"
add_call "$scratch/already-absent/fixtures" 7 az '' \
  cognitiveservices account list --resource-group "$resource_group" \
  --subscription "$subscription_id" --query '[0].name' --output tsv
set_status "$scratch/already-absent/fixtures" 7 az 1
add_call "$scratch/already-absent/fixtures" 8 az false \
  group exists --name "$resource_group" --subscription "$subscription_id" --output tsv
run_case already-absent 1 \
  'ERROR: Foundry account name is unavailable; recover it from azd or set WORKSHOP_AZURE_FOUNDRY_NAME before cleanup'
[[ "$(wc -l <"$scratch/already-absent/commands.log")" -eq 8 ]] ||
  fail_test 'missing Foundry name did not fail before azd down'
test -z "$(find "$scratch/already-absent/evidence" -type f -print -quit)" ||
  fail_test 'missing Foundry name wrote passing cleanup evidence'

start_fixture override-purge
set_status "$scratch/override-purge/fixtures" 1 azd 1
printf '%s\n' 'ERROR: environment value was not found' \
  >"$scratch/override-purge/fixtures/001-azd.stdout"
add_down_and_absence_checks override-purge
add_call "$scratch/override-purge/fixtures" 10 az "$deleted_id" \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/override-purge/fixtures" 11 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location" \
  --subscription "$subscription_id"
for number in 12 14 16 18 20; do
  add_call "$scratch/override-purge/fixtures" "$number" az '' \
    cognitiveservices account list-deleted --subscription "$subscription_id" \
    --query "$deleted_query" --output tsv
done
for number in 13 15 17 19; do
  add_call "$scratch/override-purge/fixtures" "$number" sleep '' 0
done
add_success_dates "$scratch/override-purge/fixtures" 21
run_case override-purge 0 '' "$foundry"
grep -Fq 'cognitiveservices account list-deleted' \
  "$scratch/override-purge/commands.log" ||
  fail_test 'Foundry override did not inspect soft-deleted accounts'
grep -Fq "cognitiveservices account purge --name $foundry" \
  "$scratch/override-purge/commands.log" ||
  fail_test 'Foundry override did not purge the soft-deleted account'

start_fixture transient-group-query
add_call "$scratch/transient-group-query/fixtures" 7 azd '' down --force --purge
add_call "$scratch/transient-group-query/fixtures" 8 az '' \
  group exists --name "$resource_group" --subscription "$subscription_id" --output tsv
set_status "$scratch/transient-group-query/fixtures" 8 az 1
add_call "$scratch/transient-group-query/fixtures" 9 sleep '' 0
add_call "$scratch/transient-group-query/fixtures" 10 az false \
  group exists --name "$resource_group" --subscription "$subscription_id" --output tsv
add_call "$scratch/transient-group-query/fixtures" 11 az '' \
  resource list --subscription "$subscription_id" --query "$active_query" --output tsv
for number in 12 14 16 18 20; do
  add_call "$scratch/transient-group-query/fixtures" "$number" az '' \
    cognitiveservices account list-deleted --subscription "$subscription_id" \
    --query "$deleted_query" --output tsv
done
for number in 13 15 17 19; do
  add_call "$scratch/transient-group-query/fixtures" "$number" sleep '' 0
done
add_success_dates "$scratch/transient-group-query/fixtures" 21
run_case transient-group-query 0

start_fixture normal-purge
add_down_and_absence_checks normal-purge
add_call "$scratch/normal-purge/fixtures" 10 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/normal-purge/fixtures" 11 sleep '' 0
add_call "$scratch/normal-purge/fixtures" 12 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/normal-purge/fixtures" 13 sleep '' 0
add_call "$scratch/normal-purge/fixtures" 14 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/normal-purge/fixtures" 15 sleep '' 0
add_call "$scratch/normal-purge/fixtures" 16 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/normal-purge/fixtures" 17 sleep '' 0
add_call "$scratch/normal-purge/fixtures" 18 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_success_dates "$scratch/normal-purge/fixtures" 19
run_case normal-purge 0
[[ "$(wc -l <"$scratch/normal-purge/commands.log")" -eq 20 ]] ||
  fail_test 'normal purge executed unexpected commands'
! grep -Fq 'cognitiveservices account purge' "$scratch/normal-purge/commands.log" ||
  fail_test 'normal purge unexpectedly issued an explicit purge'
[[ "$(grep -c -- "--subscription $subscription_id" "$scratch/normal-purge/commands.log")" -eq 7 ]] ||
  fail_test 'Azure verification/list calls did not use the exact azd subscription'

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
add_call "$scratch/explicit-purge/fixtures" 10 az "$deleted_id" \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/explicit-purge/fixtures" 11 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location" \
  --subscription "$subscription_id"
add_call "$scratch/explicit-purge/fixtures" 12 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/explicit-purge/fixtures" 13 sleep '' 0
add_call "$scratch/explicit-purge/fixtures" 14 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/explicit-purge/fixtures" 15 sleep '' 0
add_call "$scratch/explicit-purge/fixtures" 16 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/explicit-purge/fixtures" 17 sleep '' 0
add_call "$scratch/explicit-purge/fixtures" 18 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/explicit-purge/fixtures" 19 sleep '' 0
add_call "$scratch/explicit-purge/fixtures" 20 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_success_dates "$scratch/explicit-purge/fixtures" 21
run_case explicit-purge 0
grep -Fq 'Explicit Foundry purge required: `yes`' \
  "$scratch/explicit-purge/evidence/cleanup-20260814T092537Z.md"

start_fixture delayed-appearance
add_down_and_absence_checks delayed-appearance
add_call "$scratch/delayed-appearance/fixtures" 10 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/delayed-appearance/fixtures" 11 sleep '' 0
add_call "$scratch/delayed-appearance/fixtures" 12 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/delayed-appearance/fixtures" 13 sleep '' 0
add_call "$scratch/delayed-appearance/fixtures" 14 az "$deleted_id" \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/delayed-appearance/fixtures" 15 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location" \
  --subscription "$subscription_id"
add_call "$scratch/delayed-appearance/fixtures" 16 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/delayed-appearance/fixtures" 17 sleep '' 0
add_call "$scratch/delayed-appearance/fixtures" 18 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/delayed-appearance/fixtures" 19 sleep '' 0
add_call "$scratch/delayed-appearance/fixtures" 20 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/delayed-appearance/fixtures" 21 sleep '' 0
add_call "$scratch/delayed-appearance/fixtures" 22 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/delayed-appearance/fixtures" 23 sleep '' 0
add_call "$scratch/delayed-appearance/fixtures" 24 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_success_dates "$scratch/delayed-appearance/fixtures" 25
run_case delayed-appearance 0
grep -Fq 'cognitiveservices account purge' \
  "$scratch/delayed-appearance/commands.log" ||
  fail_test 'delayed deleted-account appearance was not purged'

start_fixture final-attempt-appearance
add_down_and_absence_checks final-attempt-appearance
for number in 10 12 14 16; do
  add_call "$scratch/final-attempt-appearance/fixtures" "$number" az '' \
    cognitiveservices account list-deleted --subscription "$subscription_id" \
    --query "$deleted_query" --output tsv
done
for number in 11 13 15 17; do
  add_call "$scratch/final-attempt-appearance/fixtures" "$number" sleep '' 0
done
add_call "$scratch/final-attempt-appearance/fixtures" 18 az "$deleted_id" \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/final-attempt-appearance/fixtures" 19 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location" \
  --subscription "$subscription_id"
for number in 20 22 24 26; do
  add_call "$scratch/final-attempt-appearance/fixtures" "$number" az '' \
    cognitiveservices account list-deleted --subscription "$subscription_id" \
    --query "$deleted_query" --output tsv
  add_call "$scratch/final-attempt-appearance/fixtures" "$((number + 1))" sleep '' 0
done
add_call "$scratch/final-attempt-appearance/fixtures" 28 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_success_dates "$scratch/final-attempt-appearance/fixtures" 29
run_case final-attempt-appearance 0
[[ "$(grep -c 'cognitiveservices account list-deleted' \
  "$scratch/final-attempt-appearance/commands.log")" -eq 10 ]] ||
  fail_test 'final-attempt purge did not start a fresh verification window'
grep -Fq 'Explicit Foundry purge required: `yes`' \
  "$scratch/final-attempt-appearance/evidence/cleanup-20260814T092537Z.md"

start_fixture remaining-rg
add_down_and_absence_checks remaining-rg true
run_case remaining-rg 1 \
  'ERROR: resource group still exists after azd down: cleanup is incomplete'
[[ "$(wc -l <"$scratch/remaining-rg/commands.log")" -eq 8 ]] ||
  fail_test 'remaining resource group did not stop cleanup'

start_fixture active-resources
add_down_and_absence_checks active-resources false \
  $'Microsoft.Web/serverfarms\tSucceeded\nMicrosoft.Web/sites\tDeleting\nMicrosoft.CognitiveServices/accounts\tFailed\nMicrosoft.CognitiveServices/accounts/deployments\tDeleting'
run_case active-resources 1
assert_stderr_contains active-resources \
  'Remaining active resource types/states:'
assert_stderr_contains active-resources \
  'type=Microsoft.Web/serverfarms state=Succeeded'
assert_stderr_contains active-resources \
  'type=Microsoft.Web/sites state=Deleting'
assert_stderr_contains active-resources \
  "az resource list --resource-group '$resource_group'"
assert_stderr_contains active-resources \
  "az group delete --name '$resource_group' --yes"
! grep -Fq "$subscription_id" "$scratch/active-resources/stderr" ||
  fail_test 'active residual failure disclosed the full subscription ID'
[[ "$(wc -l <"$scratch/active-resources/commands.log")" -eq 9 ]] ||
  fail_test 'active resources did not stop before soft-delete inspection'

start_fixture down-failure
add_down_and_absence_checks down-failure
set_status "$scratch/down-failure/fixtures" 7 azd 1
run_case down-failure 1 'ERROR: azd down --force --purge failed'
[[ "$(wc -l <"$scratch/down-failure/commands.log")" -eq 7 ]] ||
  fail_test 'azd down failure did not stop cleanup'

start_fixture purge-failure
add_down_and_absence_checks purge-failure
add_call "$scratch/purge-failure/fixtures" 10 az "$deleted_id" \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/purge-failure/fixtures" 11 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location" \
  --subscription "$subscription_id"
set_status "$scratch/purge-failure/fixtures" 11 az 1
add_call "$scratch/purge-failure/fixtures" 12 sleep '' 0
add_call "$scratch/purge-failure/fixtures" 13 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/purge-failure/fixtures" 14 sleep '' 0
add_call "$scratch/purge-failure/fixtures" 15 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/purge-failure/fixtures" 16 sleep '' 0
add_call "$scratch/purge-failure/fixtures" 17 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/purge-failure/fixtures" 18 sleep '' 0
add_call "$scratch/purge-failure/fixtures" 19 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_success_dates "$scratch/purge-failure/fixtures" 20
run_case purge-failure 1 \
  'ERROR: explicit Foundry purge failed; retry cleanup after resolving Azure permissions or service errors'
assert_stderr_contains purge-failure \
  "az cognitiveservices account purge --name '$foundry' --resource-group '$resource_group' --location '$location'"
[[ "$(wc -l <"$scratch/purge-failure/commands.log")" -eq 11 ]] ||
  fail_test 'purge failure did not stop cleanup immediately'
! grep -Fq 'Azure cleanup passed' "$scratch/purge-failure/stdout" ||
  fail_test 'purge failure emitted passing cleanup output'
test -z "$(find "$scratch/purge-failure/evidence" -type f -print -quit)" ||
  fail_test 'purge failure wrote passing cleanup evidence'

start_fixture timeout
add_down_and_absence_checks timeout
add_call "$scratch/timeout/fixtures" 10 az "$deleted_id" \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/timeout/fixtures" 11 az '' \
  cognitiveservices account purge --name "$foundry" \
  --resource-group "$resource_group" --location "$location" \
  --subscription "$subscription_id"
for number in 12 14 16 18 20; do
  add_call "$scratch/timeout/fixtures" "$number" az "$deleted_id" \
    cognitiveservices account list-deleted --subscription "$subscription_id" \
    --query "$deleted_query" --output tsv
done
for number in 13 15 17 19; do
  add_call "$scratch/timeout/fixtures" "$number" sleep '' 0
done
run_case timeout 1
assert_stderr_contains timeout \
  'Remaining resource: Microsoft.CognitiveServices/accounts state=soft-deleted'
assert_stderr_contains timeout \
  "az cognitiveservices account purge --name '$foundry'"
assert_stderr_contains timeout "--resource-group '$resource_group'"
assert_stderr_contains timeout "--location '$location'"
! grep -Fq "$deleted_id" "$scratch/timeout/stderr" ||
  fail_test 'soft-delete timeout disclosed the deleted account ID'
! grep -Fq "$subscription_id" "$scratch/timeout/stderr" ||
  fail_test 'soft-delete timeout disclosed the full subscription ID'
test ! -e "$scratch/timeout/evidence/cleanup-20260814T092537Z.md" ||
  fail_test 'timeout wrote passing cleanup evidence'

start_fixture unsafe-environment
printf '%s' "$resource_group" >"$scratch/unsafe-environment/fixtures/004-azd.stdout"
add_down_and_absence_checks unsafe-environment
add_call "$scratch/unsafe-environment/fixtures" 10 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/unsafe-environment/fixtures" 11 sleep '' 0
add_call "$scratch/unsafe-environment/fixtures" 12 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/unsafe-environment/fixtures" 13 sleep '' 0
add_call "$scratch/unsafe-environment/fixtures" 14 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/unsafe-environment/fixtures" 15 sleep '' 0
add_call "$scratch/unsafe-environment/fixtures" 16 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_call "$scratch/unsafe-environment/fixtures" 17 sleep '' 0
add_call "$scratch/unsafe-environment/fixtures" 18 az '' \
  cognitiveservices account list-deleted --subscription "$subscription_id" \
  --query "$deleted_query" --output tsv
add_success_dates "$scratch/unsafe-environment/fixtures" 19
run_case unsafe-environment 0
grep -Fq 'Environment: `not recorded (unsafe or unavailable)`' \
  "$scratch/unsafe-environment/evidence/cleanup-20260814T092537Z.md"
! grep -Fq "$resource_group" \
  "$scratch/unsafe-environment/evidence/cleanup-20260814T092537Z.md"

echo 'Azure cleanup tests passed'
