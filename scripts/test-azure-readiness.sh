#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readiness="$root/scripts/azure-readiness.sh"
library="$root/scripts/lib/workshop-azure.sh"
fake_command="$root/scripts/fixtures/workshop-azure/fake-command.sh"
scratch="$root/scripts/.test-azure-readiness.$$"
subscription_id="11111111-2222-3333-4444-555555555555"

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
  local prefix
  prefix="$fixture_dir/$(printf '%03d' "$number")-$command"
  printf '%s\n' "$@" >"$prefix.args"
  printf '%s' "$stdout" >"$prefix.stdout"
}

make_fixture() {
  local name="$1"
  local subscription_source="${2-caller}"
  local fixture_dir="$scratch/$name/fixtures"
  local bin_dir="$scratch/$name/bin"
  local call_number=1
  local command
  mkdir -p "$fixture_dir" "$bin_dir"
  for command in az azd curl git; do
    ln -s "$fake_command" "$bin_dir/$command"
  done
  ln -s "$(command -v jq)" "$bin_dir/jq"
  for command in bash basename cat dirname mkdir wc; do
    ln -s "$(command -v "$command")" "$bin_dir/$command"
  done

  add_call "$fixture_dir" "$call_number" az "$subscription_id" \
    account show --query id --output tsv
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az 'user@example.com' \
    account show --query user.name --output tsv
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" azd '' auth login --check-status
  ((call_number += 1))
  if [[ "$subscription_source" == 'azd' ]]; then
    add_call "$fixture_dir" "$call_number" azd "$subscription_id" \
      env get-value AZURE_SUBSCRIPTION_ID
    ((call_number += 1))
  fi
  add_call "$fixture_dir" "$call_number" az 'Registered' \
    provider show --namespace Microsoft.Resources --query registrationState --output tsv
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az 'Registered' \
    provider show --namespace Microsoft.Web --query registrationState --output tsv
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az 'Registered' \
    provider show --namespace Microsoft.CognitiveServices --query registrationState --output tsv
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az 'Registered' \
    provider show --namespace Microsoft.Authorization --query registrationState --output tsv
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az \
    '[{"name":"Sweden Central"}]' \
    appservice list-locations --sku B1 --linux-workers-enabled --output json
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az \
    '{"value":[{"name":{"localizedValue":"Basic"},"currentValue":0,"limit":-1}]}' \
    rest --method get --url \
    "https://management.azure.com/subscriptions/$subscription_id/providers/Microsoft.Web/locations/swedencentral/usages?api-version=2024-04-01" \
    --output json
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az \
    '[{"kind":"OpenAI","model":{"name":"gpt-5.4-mini","version":"2026-03-17","skus":[{"name":"GlobalStandard"}]}},{"kind":"AIServices","model":{"name":"gpt-5.4-mini","version":"2026-03-17","skus":[{"name":"GlobalStandard"}]}}]' \
    cognitiveservices model list --location swedencentral --output json
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az \
    '[{"name":{"localizedValue":"One Thousand Tokens Per Minute - gpt-5.4-mini - GlobalStandard"},"currentValue":"0.0","limit":"1000.0"}]' \
    cognitiveservices usage list --location swedencentral --output json
  ((call_number += 1))
  add_call "$fixture_dir" "$call_number" az \
    '[{"roleDefinitionName":"Owner","scope":"/subscriptions/11111111-2222-3333-4444-555555555555"}]' \
    role assignment list --assignee user@example.com \
    --scope "/subscriptions/$subscription_id" --include-inherited --include-groups \
    --output json
}

replace_stdout() {
  local name="$1"
  local number="$2"
  local command="$3"
  printf '%s' "$4" >"$scratch/$name/fixtures/$(printf '%03d' "$number")-$command.stdout"
}

set_status() {
  local name="$1"
  local number="$2"
  local command="$3"
  printf '%s\n' "$4" >"$scratch/$name/fixtures/$(printf '%03d' "$number")-$command.status"
}

run_case() {
  local name="$1"
  local expected_status="$2"
  local expected_message="${3-}"
  local explicit_subscription="${4-$subscription_id}"
  local case_dir="$scratch/$name"
  local status=0
  if [[ "$explicit_subscription" == 'unset' ]]; then
    env -u AZURE_SUBSCRIPTION_ID \
      WORKSHOP_AZURE_FIXTURE_DIR="$case_dir/fixtures" \
      WORKSHOP_AZURE_COMMAND_LOG="$case_dir/commands.log" \
      PATH="$case_dir/bin" \
      "$readiness" >"$case_dir/stdout" 2>"$case_dir/stderr" || status=$?
  else
    WORKSHOP_AZURE_FIXTURE_DIR="$case_dir/fixtures" \
      WORKSHOP_AZURE_COMMAND_LOG="$case_dir/commands.log" \
      AZURE_SUBSCRIPTION_ID="$explicit_subscription" \
      PATH="$case_dir/bin" \
      "$readiness" >"$case_dir/stdout" 2>"$case_dir/stderr" || status=$?
  fi

  [[ "$status" -eq "$expected_status" ]] ||
    fail_test "$name exited $status, expected $expected_status: $(cat "$case_dir/stderr")"
  if [[ -n "$expected_message" ]]; then
    grep -Fqx "$expected_message" "$case_dir/stderr" ||
      fail_test "$name did not emit exact failure: $expected_message"
  fi
}

bash -c 'set +e +u +o pipefail; source "$1"; [[ $- == *e* && $- == *u* ]] && set -o | grep -Eq "^pipefail[[:space:]]+on$"' \
  bash "$library" || fail_test 'shared library did not enable strict shell behavior'
library_fail_output="$scratch/library-fail-output"
status=0
bash -c 'source "$1"; fail "sentinel failure"; echo reached' bash "$library" \
  >"$library_fail_output" 2>&1 || status=$?
[[ "$status" -ne 0 ]] || fail_test 'fail returned success'
grep -Fqx 'ERROR: sentinel failure' "$library_fail_output"
! grep -Fqx 'reached' "$library_fail_output"

make_fixture success
run_case success 0
grep -Fq 'subscription: 11111111...5555' "$scratch/success/stdout"
! grep -Fq "$subscription_id" "$scratch/success/stdout"
[[ ! -s "$scratch/success/stderr" ]] ||
  fail_test "success emitted stderr: $(cat "$scratch/success/stderr")"
[[ "$(wc -l <"$scratch/success/commands.log")" -eq 12 ]]

make_fixture success-with-azd-subscription azd
run_case success-with-azd-subscription 0 '' unset
[[ "$(wc -l <"$scratch/success-with-azd-subscription/commands.log")" -eq 13 ]]

make_fixture missing-azd
rm "$scratch/missing-azd/bin/azd"
run_case missing-azd 1 'ERROR: required command not found: azd'
[[ ! -s "$scratch/missing-azd/commands.log" ]]

for command in az curl jq git; do
  name="missing-$command"
  make_fixture "$name"
  rm "$scratch/$name/bin/$command"
  run_case "$name" 1 "ERROR: required command not found: $command"
  [[ ! -s "$scratch/$name/commands.log" ]]
done

make_fixture failed-az-login
set_status failed-az-login 1 az 1
run_case failed-az-login 1 'ERROR: Azure CLI authentication required; run: az login'
[[ "$(wc -l <"$scratch/failed-az-login/commands.log")" -eq 1 ]]

make_fixture empty-selected-subscription
replace_stdout empty-selected-subscription 1 az ''
run_case empty-selected-subscription 1 \
  'ERROR: Azure CLI account response was invalid; run: az account show'
[[ "$(wc -l <"$scratch/empty-selected-subscription/commands.log")" -eq 1 ]]

make_fixture failed-azd-auth
set_status failed-azd-auth 3 azd 1
run_case failed-azd-auth 1 'ERROR: Azure Developer CLI authentication required; run: azd auth login'
[[ "$(wc -l <"$scratch/failed-azd-auth/commands.log")" -eq 3 ]]

make_fixture unset-subscription azd
replace_stdout unset-subscription 4 azd ''
run_case unset-subscription 1 \
  'ERROR: select a subscription explicitly by setting AZURE_SUBSCRIPTION_ID or in the azd environment' unset

make_fixture mismatched-azd-subscription azd
replace_stdout mismatched-azd-subscription 1 az \
  'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
run_case mismatched-azd-subscription 1 \
  "ERROR: Azure CLI selected subscription does not match the expected subscription; run: az account set --subscription $subscription_id" \
  unset

make_fixture mismatched-subscription
run_case mismatched-subscription 1 \
  'ERROR: Azure CLI selected subscription does not match the expected subscription; run: az account set --subscription aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' \
  'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'

make_fixture unregistered-provider
replace_stdout unregistered-provider 5 az 'NotRegistered'
run_case unregistered-provider 1 \
  'ERROR: Azure provider Microsoft.Web is not registered; run: az provider register --namespace Microsoft.Web'
[[ "$(wc -l <"$scratch/unregistered-provider/commands.log")" -eq 5 ]]

make_fixture absent-b1-region
replace_stdout absent-b1-region 8 az '[]'
run_case absent-b1-region 1 \
  'ERROR: B1 Linux App Service is unavailable in Sweden Central (swedencentral)'

make_fixture invalid-b1-response
replace_stdout invalid-b1-response 8 az '{}'
run_case invalid-b1-response 1 \
  'ERROR: B1 Linux App Service location response was invalid; verify Microsoft.Web access and retry'

make_fixture basic-limit-zero
replace_stdout basic-limit-zero 9 az \
  '{"value":[{"name":{"localizedValue":"Basic"},"currentValue":0,"limit":0}]}'
run_case basic-limit-zero 1 \
  'ERROR: Basic App Service quota is zero in Sweden Central; request quota or choose another subscription'

make_fixture basic-limit-unknown
replace_stdout basic-limit-unknown 9 az \
  '{"value":[{"name":{"localizedValue":"Basic"},"currentValue":0,"limit":-2}]}'
run_case basic-limit-unknown 1 \
  'ERROR: Basic App Service quota is unknown in Sweden Central; check quota in the Azure portal'

make_fixture basic-limit-empty
replace_stdout basic-limit-empty 9 az \
  '{"value":[{"name":{"localizedValue":"Basic"},"currentValue":0,"limit":null}]}'
run_case basic-limit-empty 1 \
  'ERROR: Basic App Service quota was not reported for Sweden Central; check quota in the Azure portal'

make_fixture missing-model
replace_stdout missing-model 10 az \
  '[{"model":{"name":"gpt-5.4-mini","version":"2025-01-01"},"skus":[{"name":"GlobalStandard"}]}]'
run_case missing-model 1 \
  'ERROR: model gpt-5.4-mini version 2026-03-17 is unavailable in Sweden Central'

make_fixture missing-sku
replace_stdout missing-sku 10 az \
  '[{"model":{"name":"gpt-5.4-mini","version":"2026-03-17"},"skus":[{"name":"Standard"}]}]'
run_case missing-sku 1 \
  'ERROR: model gpt-5.4-mini version 2026-03-17 does not offer SKU GlobalStandard in Sweden Central'

make_fixture insufficient-model-quota
replace_stdout insufficient-model-quota 11 az \
  '[{"name":{"localizedValue":"One Thousand Tokens Per Minute - gpt-5.4-mini - GlobalStandard"},"currentValue":"995.0","limit":"1000.0"}]'
run_case insufficient-model-quota 1 \
  'ERROR: model quota has 5 capacity remaining, but 10 is required'

make_fixture unknown-model-quota
replace_stdout unknown-model-quota 11 az \
  '[{"name":{"localizedValue":"One Thousand Tokens Per Minute - gpt-5.4-mini - GlobalStandard"},"currentValue":"unknown","limit":"1000.0"}]'
run_case unknown-model-quota 1 \
  'ERROR: model quota was not reported for gpt-5.4-mini GlobalStandard in Sweden Central'

make_fixture non-integral-model-quota
replace_stdout non-integral-model-quota 11 az \
  '[{"name":{"localizedValue":"One Thousand Tokens Per Minute - gpt-5.4-mini - GlobalStandard"},"currentValue":"995.5","limit":"1000.0"}]'
run_case non-integral-model-quota 1 \
  'ERROR: model quota was not reported for gpt-5.4-mini GlobalStandard in Sweden Central'

make_fixture insufficient-rbac
replace_stdout insufficient-rbac 12 az \
  '[{"roleDefinitionName":"Contributor","scope":"/subscriptions/11111111-2222-3333-4444-555555555555"}]'
run_case insufficient-rbac 1 \
  'ERROR: deployment authority requires Owner, or Contributor plus User Access Administrator or Role Based Access Control Administrator'

make_fixture contributor-user-access-admin
replace_stdout contributor-user-access-admin 12 az \
  '[{"roleDefinitionName":"Contributor"},{"roleDefinitionName":"User Access Administrator","condition":""}]'
run_case contributor-user-access-admin 0

make_fixture contributor-rbac-admin
replace_stdout contributor-rbac-admin 12 az \
  '[{"roleDefinitionName":"Contributor"},{"roleDefinitionName":"Role Based Access Control Administrator"}]'
run_case contributor-rbac-admin 0

make_fixture group-owner
replace_stdout group-owner 12 az \
  '[{"roleDefinitionName":"Owner","principalType":"Group"}]'
run_case group-owner 0

make_fixture group-contributor-user-access-admin
replace_stdout group-contributor-user-access-admin 12 az \
  '[{"roleDefinitionName":"Contributor","principalType":"Group"},{"roleDefinitionName":"User Access Administrator","principalType":"Group"}]'
run_case group-contributor-user-access-admin 0

make_fixture constrained-owner
replace_stdout constrained-owner 12 az \
  '[{"roleDefinitionName":"Owner","condition":"@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEqualsIgnoreCase \u0027constrained\u0027"}]'
run_case constrained-owner 1 \
  'ERROR: deployment authority requires Owner, or Contributor plus User Access Administrator or Role Based Access Control Administrator'

make_fixture constrained-role-admin
replace_stdout constrained-role-admin 12 az \
  '[{"roleDefinitionName":"Contributor"},{"roleDefinitionName":"Role Based Access Control Administrator","condition":"@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {00000000-0000-0000-0000-000000000000}"}]'
run_case constrained-role-admin 1 \
  'ERROR: deployment authority requires Owner, or Contributor plus User Access Administrator or Role Based Access Control Administrator'

echo "Azure readiness fixture tests passed"
