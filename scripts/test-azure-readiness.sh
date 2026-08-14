#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readiness="$root/scripts/azure-readiness.sh"
fake_command="$root/scripts/fixtures/workshop-azure/fake-command.sh"
scratch="$root/scripts/.test-azure-readiness.$$"
subscription_id="11111111-2222-3333-4444-555555555555"

cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT

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
  local fixture_dir="$scratch/$name/fixtures"
  local bin_dir="$scratch/$name/bin"
  mkdir -p "$fixture_dir" "$bin_dir"
  for command in az azd curl git; do
    ln -s "$fake_command" "$bin_dir/$command"
  done
  ln -s "$(command -v jq)" "$bin_dir/jq"

  add_call "$fixture_dir" 1 az \
    '{"id":"11111111-2222-3333-4444-555555555555","user":{"name":"user@example.com"}}' \
    account show --output json
  add_call "$fixture_dir" 2 azd '' auth login --check-status
  add_call "$fixture_dir" 3 az 'Registered' \
    provider show --namespace Microsoft.Resources --query registrationState --output tsv
  add_call "$fixture_dir" 4 az 'Registered' \
    provider show --namespace Microsoft.Web --query registrationState --output tsv
  add_call "$fixture_dir" 5 az 'Registered' \
    provider show --namespace Microsoft.CognitiveServices --query registrationState --output tsv
  add_call "$fixture_dir" 6 az 'Registered' \
    provider show --namespace Microsoft.Authorization --query registrationState --output tsv
  add_call "$fixture_dir" 7 az \
    '[{"name":"swedencentral","displayName":"Sweden Central"}]' \
    appservice list-locations --sku B1 --linux-workers-enabled --output json
  add_call "$fixture_dir" 8 az \
    '{"value":[{"name":{"localizedValue":"Basic"},"currentValue":0,"limit":-1}]}' \
    rest --method get --url \
    "https://management.azure.com/subscriptions/$subscription_id/providers/Microsoft.Web/locations/swedencentral/usages?api-version=2024-04-01" \
    --output json
  add_call "$fixture_dir" 9 az \
    '[{"model":{"name":"gpt-5.4-mini","version":"2026-03-17"},"skus":[{"name":"GlobalStandard"}]}]' \
    cognitiveservices model list --location swedencentral --output json
  add_call "$fixture_dir" 10 az \
    '{"value":[{"name":{"localizedValue":"One Thousand Tokens Per Minute - gpt-5.4-mini - GlobalStandard"},"currentValue":20,"limit":100}]}' \
    cognitiveservices usage list --location swedencentral --output json
  add_call "$fixture_dir" 11 az \
    '[{"roleDefinitionName":"Owner","scope":"/subscriptions/11111111-2222-3333-4444-555555555555"}]' \
    role assignment list --assignee user@example.com \
    --scope "/subscriptions/$subscription_id" --include-inherited --output json
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
  local case_dir="$scratch/$name"
  local status=0
  WORKSHOP_AZURE_FIXTURE_DIR="$case_dir/fixtures" \
    WORKSHOP_AZURE_COMMAND_LOG="$case_dir/commands.log" \
    AZURE_SUBSCRIPTION_ID="$subscription_id" \
    PATH="$case_dir/bin:/usr/bin:/bin" \
    "$readiness" >"$case_dir/stdout" 2>"$case_dir/stderr" || status=$?

  [[ "$status" -eq "$expected_status" ]] ||
    fail_test "$name exited $status, expected $expected_status: $(cat "$case_dir/stderr")"
  if [[ -n "$expected_message" ]]; then
    grep -Fqx "$expected_message" "$case_dir/stderr" ||
      fail_test "$name did not emit exact failure: $expected_message"
  fi
}

make_fixture success
run_case success 0
grep -Fq 'subscription: 11111111...5555' "$scratch/success/stdout"
! grep -Fq "$subscription_id" "$scratch/success/stdout"
[[ "$(wc -l <"$scratch/success/commands.log")" -eq 11 ]]

make_fixture missing-azd
rm "$scratch/missing-azd/bin/azd"
run_case missing-azd 1 'ERROR: required command not found: azd'
[[ ! -s "$scratch/missing-azd/commands.log" ]]

make_fixture failed-az-login
set_status failed-az-login 1 az 1
run_case failed-az-login 1 'ERROR: Azure CLI authentication required; run: az login'
[[ "$(wc -l <"$scratch/failed-az-login/commands.log")" -eq 1 ]]

make_fixture failed-azd-auth
set_status failed-azd-auth 2 azd 1
run_case failed-azd-auth 1 'ERROR: Azure Developer CLI authentication required; run: azd auth login'
[[ "$(wc -l <"$scratch/failed-azd-auth/commands.log")" -eq 2 ]]

make_fixture unregistered-provider
replace_stdout unregistered-provider 4 az 'NotRegistered'
run_case unregistered-provider 1 \
  'ERROR: Azure provider Microsoft.Web is not registered; run: az provider register --namespace Microsoft.Web'
[[ "$(wc -l <"$scratch/unregistered-provider/commands.log")" -eq 4 ]]

make_fixture absent-b1-region
replace_stdout absent-b1-region 7 az '[]'
run_case absent-b1-region 1 \
  'ERROR: B1 Linux App Service is unavailable in Sweden Central (swedencentral)'

make_fixture invalid-b1-response
replace_stdout invalid-b1-response 7 az '{}'
run_case invalid-b1-response 1 \
  'ERROR: B1 Linux App Service location response was invalid; verify Microsoft.Web access and retry'

make_fixture basic-limit-zero
replace_stdout basic-limit-zero 8 az \
  '{"value":[{"name":{"localizedValue":"Basic"},"currentValue":0,"limit":0}]}'
run_case basic-limit-zero 1 \
  'ERROR: Basic App Service quota is zero in Sweden Central; request quota or choose another subscription'

make_fixture missing-model
replace_stdout missing-model 9 az \
  '[{"model":{"name":"gpt-5.4-mini","version":"2025-01-01"},"skus":[{"name":"GlobalStandard"}]}]'
run_case missing-model 1 \
  'ERROR: model gpt-5.4-mini version 2026-03-17 is unavailable in Sweden Central'

make_fixture missing-sku
replace_stdout missing-sku 9 az \
  '[{"model":{"name":"gpt-5.4-mini","version":"2026-03-17"},"skus":[{"name":"Standard"}]}]'
run_case missing-sku 1 \
  'ERROR: model gpt-5.4-mini version 2026-03-17 does not offer SKU GlobalStandard in Sweden Central'

make_fixture insufficient-model-quota
replace_stdout insufficient-model-quota 10 az \
  '{"value":[{"name":{"localizedValue":"One Thousand Tokens Per Minute - gpt-5.4-mini - GlobalStandard"},"currentValue":95,"limit":100}]}'
run_case insufficient-model-quota 1 \
  'ERROR: model quota has 5 capacity remaining, but 10 is required'

make_fixture insufficient-rbac
replace_stdout insufficient-rbac 11 az \
  '[{"roleDefinitionName":"Contributor","scope":"/subscriptions/11111111-2222-3333-4444-555555555555"}]'
run_case insufficient-rbac 1 \
  'ERROR: deployment authority requires Owner, or Contributor plus User Access Administrator or Role Based Access Control Administrator'

echo "Azure readiness fixture tests passed"
