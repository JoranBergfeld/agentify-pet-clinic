#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
preflight="$root/scripts/azure-preflight.sh"
library="$root/scripts/lib/workshop-azure.sh"
fake_command="$root/scripts/fixtures/workshop-azure/fake-command.sh"
scratch="$root/scripts/.test-azure-preflight.$$"
subscription_id="11111111-2222-3333-4444-555555555555"
principal_id="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
resource_group="rg-workshop"
web_app="workshop-web-secret"
app_url="https://workshop-web-secret.azurewebsites.net"
foundry="workshop-foundry-secret"
foundry_scope="/subscriptions/$subscription_id/resourceGroups/$resource_group/providers/Microsoft.CognitiveServices/accounts/$foundry"
health_filter='.status // empty'
resources_filter='["microsoft.cognitiveservices/accounts","microsoft.web/serverfarms","microsoft.web/sites"] as $requiredTypes | [.[]? | {type, normalizedType: (.type | ascii_downcase), state: (.provisioningState // empty)}] as $resources | [$resources[] | select(.normalizedType as $type | $requiredTypes | index($type))] as $required | [$resources[] | select(.normalizedType as $type | ($requiredTypes + ["microsoft.insights/diagnosticsettings"]) | index($type) | not)] as $unexpected | ($required | length) == 3 and ($required | map(.normalizedType) | sort) == ($requiredTypes | sort) and all($required[]; .state == "Succeeded") and ($unexpected | length) == 0 | if . then $required | sort_by(.normalizedType) | map("- Resource: `\(.type)`; provisioningState: `\(.state)`") | join("\n") else error("invalid resource provisioning evidence") end'
deployment_filter='.properties.model.name == $model and .properties.model.version == $version and .sku.name == $sku and .sku.capacity == $capacity'
identity_filter='select(.type == "SystemAssigned") | .principalId | select(type == "string" and length > 0)'
role_filter='any(.[]; .roleDefinitionName == "Foundry User" and .principalId == $principal and ((.scope | ascii_downcase) == ($scope | ascii_downcase)))'
setting_filter='[.[]? | select(.name == $name and .value == $value)] | length == 1'

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

add_jq_call() {
  local fixture_dir="$1"
  local number="$2"
  local stdout="$3"
  local stdin="$4"
  shift 4
  add_call "$fixture_dir" "$number" jq "$stdout" "$@"
  printf '%s' "$stdin" >"$fixture_dir/$(printf '%03d' "$number")-jq.stdin"
}

make_success_fixture() {
  local name="$1"
  local case_dir="$scratch/$name"
  local fixture_dir="$case_dir/fixtures"
  local bin_dir="$case_dir/bin"
  local project_dir="$case_dir/project"
  local evidence_dir="$case_dir/evidence"
  local command

  test -f "$preflight" || fail_test "$preflight does not exist"
  mkdir -p "$fixture_dir" "$bin_dir" "$project_dir/scripts/lib" "$evidence_dir"
  cp "$preflight" "$project_dir/scripts/azure-preflight.sh"
  cp "$library" "$project_dir/scripts/lib/workshop-azure.sh"
  ln -s "$fake_command" "$project_dir/scripts/azure-readiness.sh"

  for command in az azd curl git date sleep jq; do
    ln -s "$fake_command" "$bin_dir/$command"
  done
  for command in bash basename cat dirname mkdir mv rm wc; do
    ln -s "$(command -v "$command")" "$bin_dir/$command"
  done

  add_call "$fixture_dir" 1 azure-readiness.sh ''
  add_call "$fixture_dir" 2 azd '' up --no-prompt
  add_call "$fixture_dir" 3 azd "$resource_group" env get-value AZURE_RESOURCE_GROUP_NAME
  add_call "$fixture_dir" 4 azd "$web_app" env get-value SERVICE_WEB_NAME
  add_call "$fixture_dir" 5 azd "$app_url" env get-value WEB_APP_URL
  add_call "$fixture_dir" 6 azd "$foundry" env get-value AZURE_OPENAI_ACCOUNT_NAME
  add_call "$fixture_dir" 7 azd 'swedencentral' env get-value AZURE_LOCATION
  add_call "$fixture_dir" 8 azd 'gpt-5.4-mini' env get-value AZURE_OPENAI_MODEL
  add_call "$fixture_dir" 9 azd '2026-03-17' env get-value AZURE_OPENAI_MODEL_VERSION
  add_call "$fixture_dir" 10 azd 'gpt-5-4-mini' env get-value AZURE_OPENAI_DEPLOYMENT
  add_call "$fixture_dir" 11 azd 'GlobalStandard' env get-value AZURE_OPENAI_DEPLOYMENT_SKU
  add_call "$fixture_dir" 12 azd '10' env get-value AZURE_OPENAI_DEPLOYMENT_CAPACITY
  add_call "$fixture_dir" 13 az "$subscription_id" account show --query id --output tsv
  add_call "$fixture_dir" 14 curl '{"status":"STARTING"}' \
    --fail --silent --show-error "$app_url/actuator/health"
  add_jq_call "$fixture_dir" 15 'STARTING' '{"status":"STARTING"}' \
    -r "$health_filter"
  add_call "$fixture_dir" 16 sleep '' 1
  add_call "$fixture_dir" 17 curl '{"status":"UP"}' \
    --fail --silent --show-error "$app_url/actuator/health"
  add_jq_call "$fixture_dir" 18 'UP' '{"status":"UP"}' \
    -r "$health_filter"
  resources_json='[{"type":"Microsoft.Web/serverfarms","name":"plan-secret","provisioningState":"Succeeded"},{"type":"Microsoft.Web/sites","name":"workshop-web-secret","provisioningState":"Succeeded"},{"type":"Microsoft.CognitiveServices/accounts","name":"workshop-foundry-secret","provisioningState":"Succeeded"}]'
  resource_evidence='- Resource: `Microsoft.CognitiveServices/accounts`; provisioningState: `Succeeded`
- Resource: `Microsoft.Web/serverfarms`; provisioningState: `Succeeded`
- Resource: `Microsoft.Web/sites`; provisioningState: `Succeeded`'
  add_call "$fixture_dir" 19 az "$resources_json" \
    resource list --resource-group "$resource_group" --output json
  add_jq_call "$fixture_dir" 20 "$resource_evidence" "$resources_json" \
    -er "$resources_filter"
  deployment_json='{"properties":{"model":{"name":"gpt-5.4-mini","version":"2026-03-17"}},"sku":{"name":"GlobalStandard","capacity":10}}'
  add_call "$fixture_dir" 21 az "$deployment_json" \
    cognitiveservices account deployment show --name "$foundry" \
    --resource-group "$resource_group" --deployment-name gpt-5-4-mini --output json
  add_jq_call "$fixture_dir" 22 'true' "$deployment_json" \
    -e --arg model gpt-5.4-mini --arg version 2026-03-17 \
    --arg sku GlobalStandard --argjson capacity 10 "$deployment_filter"
  identity_json="{\"type\":\"SystemAssigned\",\"principalId\":\"$principal_id\",\"tenantId\":\"ffffffff-1111-2222-3333-444444444444\"}"
  add_call "$fixture_dir" 23 az "$identity_json" \
    webapp identity show --name "$web_app" --resource-group "$resource_group" --output json
  add_jq_call "$fixture_dir" 24 "$principal_id" "$identity_json" \
    -er "$identity_filter"
  add_call "$fixture_dir" 25 az "$foundry_scope" \
    cognitiveservices account show --name "$foundry" --resource-group "$resource_group" \
    --query id --output tsv
  role_scope="${foundry_scope/Microsoft.CognitiveServices/microsoft.cognitiveservices}"
  roles_json="[{\"roleDefinitionName\":\"Foundry User\",\"scope\":\"$role_scope\",\"principalId\":\"$principal_id\"}]"
  add_call "$fixture_dir" 26 az "$roles_json" \
    role assignment list --assignee-object-id "$principal_id" --scope "$foundry_scope" --output json
  add_jq_call "$fixture_dir" 27 'true' "$roles_json" \
    -e --arg principal "$principal_id" --arg scope "$foundry_scope" "$role_filter"
  settings_json="[{\"name\":\"AZURE_OPENAI_ENDPOINT\",\"value\":\"https://$foundry.openai.azure.com\"},{\"name\":\"AZURE_OPENAI_MICROSOFT_FOUNDRY\",\"value\":\"true\"},{\"name\":\"AZURE_OPENAI_DEPLOYMENT\",\"value\":\"gpt-5-4-mini\"},{\"name\":\"AZURE_OPENAI_MODEL\",\"value\":\"gpt-5.4-mini\"},{\"name\":\"JAVA_OPTS\",\"value\":\"-Xms256m -Xmx1024m\"},{\"name\":\"WEBSITES_PORT\",\"value\":\"8080\"}]"
  add_call "$fixture_dir" 28 az "$settings_json" \
    webapp config appsettings list --name "$web_app" --resource-group "$resource_group" --output json
  add_jq_call "$fixture_dir" 29 'true' "$settings_json" \
    -e --arg name AZURE_OPENAI_ENDPOINT --arg value "https://$foundry.openai.azure.com" "$setting_filter"
  add_jq_call "$fixture_dir" 30 'true' "$settings_json" \
    -e --arg name AZURE_OPENAI_MICROSOFT_FOUNDRY --arg value true "$setting_filter"
  add_jq_call "$fixture_dir" 31 'true' "$settings_json" \
    -e --arg name AZURE_OPENAI_DEPLOYMENT --arg value gpt-5-4-mini "$setting_filter"
  add_jq_call "$fixture_dir" 32 'true' "$settings_json" \
    -e --arg name AZURE_OPENAI_MODEL --arg value gpt-5.4-mini "$setting_filter"
  add_jq_call "$fixture_dir" 33 'true' "$settings_json" \
    -e --arg name JAVA_OPTS --arg value '-Xms256m -Xmx1024m' "$setting_filter"
  add_jq_call "$fixture_dir" 34 'true' "$settings_json" \
    -e --arg name WEBSITES_PORT --arg value 8080 "$setting_filter"
  add_call "$fixture_dir" 35 git '0123456789abcdef0123456789abcdef01234567' \
    -C "$project_dir" rev-parse HEAD
  add_call "$fixture_dir" 36 date '20260814T090548Z' -u +%Y%m%dT%H%M%SZ
  add_call "$fixture_dir" 37 date '2026-08-14T09:05:48Z' -u +%Y-%m-%dT%H:%M:%SZ
}

add_failure_metadata() {
  local name="$1"
  local next_call="$2"
  local fixture_dir="$scratch/$name/fixtures"

  find "$fixture_dir" -maxdepth 1 -type f \
    -regextype posix-extended \
    -regex ".*/([0-9]{3})-.*" \
    -printf '%f\n' |
    while read -r fixture; do
      if (( 10#${fixture:0:3} >= next_call )); then
        rm -f "$fixture_dir/$fixture"
      fi
    done
  add_call "$fixture_dir" "$next_call" git \
    '0123456789abcdef0123456789abcdef01234567' \
    -C "$scratch/$name/project" rev-parse HEAD
  add_call "$fixture_dir" "$((next_call + 1))" date \
    '20260814T090548Z' -u +%Y%m%dT%H%M%SZ
  add_call "$fixture_dir" "$((next_call + 2))" date \
    '2026-08-14T09:05:48Z' -u +%Y-%m-%dT%H:%M:%SZ
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
    WORKSHOP_AZURE_CLEANUP_DEADLINE='2026-08-14T16:00:00Z' \
    WORKSHOP_AZURE_RETRY_SECONDS=1 \
    WORKSHOP_AZURE_RETRY_ATTEMPTS=3 \
    PATH="$case_dir/bin" \
    "$case_dir/project/scripts/azure-preflight.sh" \
    >"$case_dir/stdout" 2>"$case_dir/stderr" || status=$?
  [[ "$status" -eq "$expected_status" ]] ||
    fail_test "$name exited $status, expected $expected_status: $(cat "$case_dir/stderr")"
  if [[ -n "$expected_message" ]]; then
    grep -Fqx "$expected_message" "$case_dir/stderr" ||
      fail_test "$name did not emit exact failure: $expected_message; got: $(cat "$case_dir/stderr")"
  fi
}

assert_failure_evidence() {
  local name="$1"
  local failed_gate="$2"
  shift 2
  local evidence_dir="$scratch/$name/evidence"
  local evidence_files=()
  local evidence
  local expected

  mapfile -t evidence_files < <(find "$evidence_dir" -maxdepth 1 -type f -name 'preflight-*.md')
  [[ "${#evidence_files[@]}" -eq 1 ]] ||
    fail_test "$name created ${#evidence_files[@]} evidence files, expected exactly one"
  evidence="${evidence_files[0]}"

  for expected in \
    '# Azure Preflight Evidence' \
    'Outcome: `FAILED`' \
    'Command version: `1.0.0`' \
    'Evidence schema version: `1.0`' \
    'UTC: `2026-08-14T09:05:48Z`' \
    'Git revision: `0123456789abcdef0123456789abcdef01234567`' \
    'Subscription: `11111111...5555`' \
    'Region: `swedencentral`' \
    'Model: `gpt-5.4-mini`' \
    'Model version: `2026-03-17`' \
    'Deployment: `gpt-5-4-mini`' \
    'SKU: `GlobalStandard`' \
    'Capacity: `10`' \
    'Cleanup deadline: `2026-08-14T16:00:00Z`' \
    "Failed gate: \`$failed_gate\`" \
    'Observed safe error: `' \
    "| $failed_gate | FAIL |" \
    'This environment may remain billable.' \
    'Cleanup is required: `scripts/azure-cleanup.sh`'; do
    grep -Fq "$expected" "$evidence" ||
      fail_test "$name evidence omitted expected field: $expected"
  done

  ! grep -Fq "| $failed_gate | PASS |" "$evidence" ||
    fail_test "$name evidence falsely marked $failed_gate PASS"
  grep -Fq \
    'WARNING: Azure Preflight failed after deployment; this environment may remain billable.' \
    "$scratch/$name/stderr" ||
    fail_test "$name did not warn that the deployment may remain billable"
  grep -Fq 'Cleanup is required: scripts/azure-cleanup.sh' "$scratch/$name/stderr" ||
    fail_test "$name did not require cleanup on stderr"
  for expected in "$@"; do
    grep -Fq "| $expected | PASS |" "$evidence" ||
      fail_test "$name evidence did not truthfully preserve prior gate: $expected"
  done
  for secret in "$subscription_id" "$principal_id" "$foundry" "$web_app" "$app_url" \
    "$resource_group" "$foundry_scope" 'plan-secret' \
    'ffffffff-1111-2222-3333-444444444444' 'token'; do
    ! grep -Fq "$secret" "$evidence" ||
      fail_test "$name evidence disclosed forbidden value: $secret"
  done
}

make_success_fixture success
run_case success 0

mapfile -t commands <"$scratch/success/commands.log"
[[ "${commands[0]}" == "azure-readiness.sh ''" ]] ||
  fail_test 'readiness was not called first'
[[ "${commands[1]}" == 'azd up --no-prompt' ]] ||
  fail_test 'azd up did not follow readiness'
[[ "$(wc -l <"$scratch/success/commands.log")" -eq 37 ]] ||
  fail_test 'success did not execute every expected verification'

evidence="$scratch/success/evidence/preflight-20260814T090548Z.md"
test -f "$evidence" || fail_test 'timestamped Preflight evidence was not created'
grep -Fq 'Git revision: `0123456789abcdef0123456789abcdef01234567`' "$evidence"
grep -Fq 'Subscription: `11111111...5555`' "$evidence"
grep -Fq 'Application health: `UP`' "$evidence"
for expected in \
  'Command version: `1.0.0`' \
  'Evidence schema version: `1.0`' \
  'UTC: `2026-08-14T09:05:48Z`' \
  'Region: `swedencentral`' \
  'Model: `gpt-5.4-mini`' \
  'Model version: `2026-03-17`' \
  'Deployment: `gpt-5-4-mini`' \
  'SKU: `GlobalStandard`' \
  'Capacity: `10`' \
  'Resource: `Microsoft.Web/serverfarms`; provisioningState: `Succeeded`' \
  'Resource: `Microsoft.Web/sites`; provisioningState: `Succeeded`' \
  'Resource: `Microsoft.CognitiveServices/accounts`; provisioningState: `Succeeded`' \
  'Managed identity: `present (SystemAssigned)`' \
  'Role: `Foundry User`' \
  'Role scope category: `Foundry resource`' \
  'Required app settings: `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_MICROSOFT_FOUNDRY`, `AZURE_OPENAI_DEPLOYMENT`, `AZURE_OPENAI_MODEL`, `JAVA_OPTS`, `WEBSITES_PORT`' \
  'Deployed time: `2026-08-14T09:05:48Z`' \
  'Cleanup deadline: `2026-08-14T16:00:00Z`' \
  '| Readiness | PASS |' \
  '| Provisioning | PASS |' \
  '| Resource topology | PASS |' \
  '| Managed identity | PASS |' \
  '| Foundry User assignment | PASS |' \
  '| Model deployment | PASS |' \
  '| Required app settings | PASS |' \
  '| Application health | PASS |'; do
  grep -Fq "$expected" "$evidence" ||
    fail_test "evidence omitted expected field: $expected"
done
for secret in "$subscription_id" "$principal_id" "$foundry" "$web_app" "$app_url" \
  'plan-secret' \
  'ffffffff-1111-2222-3333-444444444444' 'token'; do
  ! grep -Fq "$secret" "$evidence" ||
    fail_test "evidence disclosed forbidden value: $secret"
done

make_success_fixture azd-failure
printf '%s\n' 1 >"$scratch/azd-failure/fixtures/002-azd.status"
add_failure_metadata azd-failure 3
add_call "$scratch/azd-failure/fixtures" 6 az "$subscription_id" \
  account show --query id --output tsv
run_case azd-failure 1 'ERROR: azd up failed'
[[ "$(wc -l <"$scratch/azd-failure/commands.log")" -eq 6 ]] ||
  fail_test 'azd up failure did not stop verification'
assert_failure_evidence azd-failure 'Provisioning' Readiness

make_success_fixture evidence-write-failure
printf '%s\n' 1 >"$scratch/evidence-write-failure/fixtures/002-azd.status"
add_failure_metadata evidence-write-failure 3
add_call "$scratch/evidence-write-failure/fixtures" 6 az "$subscription_id" \
  account show --query id --output tsv
rm -rf "$scratch/evidence-write-failure/evidence"
printf '%s\n' 'not a directory' >"$scratch/evidence-write-failure/evidence"
run_case evidence-write-failure 1 'ERROR: azd up failed'
grep -Fq 'WARNING: could not write Azure Preflight failure evidence' \
  "$scratch/evidence-write-failure/stderr" ||
  fail_test 'evidence write failure did not emit a secondary warning'
! grep -Fq 'Failure evidence:' "$scratch/evidence-write-failure/stderr" ||
  fail_test 'evidence write failure falsely reported an evidence path'
[[ "$(cat "$scratch/evidence-write-failure/evidence")" == 'not a directory' ]] ||
  fail_test 'evidence write failure changed the blocking evidence path'

make_success_fixture readiness-failure
printf '%s\n' 1 >"$scratch/readiness-failure/fixtures/001-azure-readiness.sh.status"
run_case readiness-failure 1
[[ "$(wc -l <"$scratch/readiness-failure/commands.log")" -eq 1 ]] ||
  fail_test 'readiness failure did not stop before azd up'
if find "$scratch/readiness-failure/evidence" -maxdepth 1 -type f \
  -name 'preflight-*.md' | grep -q .; then
  fail_test 'readiness failure wrote deployment failure evidence'
fi

make_success_fixture health-timeout
printf '%s' '{"status":"STARTING"}' \
  >"$scratch/health-timeout/fixtures/017-curl.stdout"
printf '%s' '{"status":"STARTING"}' \
  >"$scratch/health-timeout/fixtures/018-jq.stdin"
printf '%s' 'STARTING' >"$scratch/health-timeout/fixtures/018-jq.stdout"
rm -f "$scratch/health-timeout/fixtures"/0{19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37}-*
add_call "$scratch/health-timeout/fixtures" 19 sleep '' 1
add_call "$scratch/health-timeout/fixtures" 20 curl '{"status":"STARTING"}' \
  --fail --silent --show-error "$app_url/actuator/health"
add_jq_call "$scratch/health-timeout/fixtures" 21 'STARTING' '{"status":"STARTING"}' \
  -r "$health_filter"
add_failure_metadata health-timeout 22
run_case health-timeout 1 \
  'ERROR: application health did not succeed after 3 attempts'
assert_failure_evidence health-timeout 'Application health' \
  Readiness Provisioning

make_success_fixture missing-resource
missing_resources='[{"type":"Microsoft.Web/serverfarms","provisioningState":"Succeeded"},{"type":"Microsoft.Web/sites","provisioningState":"Succeeded"}]'
printf '%s' "$missing_resources" >"$scratch/missing-resource/fixtures/019-az.stdout"
printf '%s' "$missing_resources" >"$scratch/missing-resource/fixtures/020-jq.stdin"
printf '%s\n' 1 >"$scratch/missing-resource/fixtures/020-jq.status"
add_failure_metadata missing-resource 21
run_case missing-resource 1 \
  'ERROR: deployed resources are missing, unexpected, or not successfully provisioned'
assert_failure_evidence missing-resource 'Resource topology' \
  Readiness Provisioning 'Application health'

make_success_fixture failed-provisioning
failed_resources='[{"type":"Microsoft.Web/serverfarms","provisioningState":"Succeeded"},{"type":"Microsoft.Web/sites","provisioningState":"Failed"},{"type":"Microsoft.CognitiveServices/accounts","provisioningState":"Succeeded"}]'
printf '%s' "$failed_resources" >"$scratch/failed-provisioning/fixtures/019-az.stdout"
printf '%s' "$failed_resources" >"$scratch/failed-provisioning/fixtures/020-jq.stdin"
printf '%s\n' 1 >"$scratch/failed-provisioning/fixtures/020-jq.status"
add_failure_metadata failed-provisioning 21
run_case failed-provisioning 1 \
  'ERROR: deployed resources are missing, unexpected, or not successfully provisioned'
assert_failure_evidence failed-provisioning 'Resource topology' \
  Readiness Provisioning 'Application health'

make_success_fixture missing-model
missing_model_deployment='{"properties":{"model":{"version":"2026-03-17"}},"sku":{"name":"GlobalStandard","capacity":10}}'
printf '%s' "$missing_model_deployment" >"$scratch/missing-model/fixtures/021-az.stdout"
printf '%s' "$missing_model_deployment" >"$scratch/missing-model/fixtures/022-jq.stdin"
printf '%s\n' 1 >"$scratch/missing-model/fixtures/022-jq.status"
add_failure_metadata missing-model 23
run_case missing-model 1 \
  'ERROR: model deployment values do not exactly match the azd outputs'
assert_failure_evidence missing-model 'Model deployment' \
  Readiness Provisioning 'Application health' 'Resource topology'

make_success_fixture missing-identity
missing_identity='{"type":"None","principalId":null}'
printf '%s' "$missing_identity" >"$scratch/missing-identity/fixtures/023-az.stdout"
printf '%s' "$missing_identity" >"$scratch/missing-identity/fixtures/024-jq.stdin"
printf '%s\n' 1 >"$scratch/missing-identity/fixtures/024-jq.status"
add_failure_metadata missing-identity 25
run_case missing-identity 1 \
  'ERROR: web app system-assigned managed identity is missing'
assert_failure_evidence missing-identity 'Managed identity' \
  Readiness Provisioning 'Application health' 'Resource topology' 'Model deployment'

make_success_fixture missing-role
printf '%s' '[]' >"$scratch/missing-role/fixtures/026-az.stdout"
printf '%s' '[]' >"$scratch/missing-role/fixtures/027-jq.stdin"
printf '%s\n' 1 >"$scratch/missing-role/fixtures/027-jq.status"
add_failure_metadata missing-role 28
run_case missing-role 1 \
  'ERROR: Foundry User assignment is missing at the Foundry resource scope'
assert_failure_evidence missing-role 'Foundry User assignment' \
  Readiness Provisioning 'Application health' 'Resource topology' 'Model deployment' \
  'Managed identity'

make_success_fixture missing-app-setting
missing_settings="[{\"name\":\"AZURE_OPENAI_ENDPOINT\",\"value\":\"https://$foundry.openai.azure.com\"},{\"name\":\"AZURE_OPENAI_MICROSOFT_FOUNDRY\",\"value\":\"true\"},{\"name\":\"AZURE_OPENAI_DEPLOYMENT\",\"value\":\"gpt-5-4-mini\"},{\"name\":\"AZURE_OPENAI_MODEL\",\"value\":\"gpt-5.4-mini\"},{\"name\":\"JAVA_OPTS\",\"value\":\"-Xms256m -Xmx1024m\"}]"
printf '%s' "$missing_settings" >"$scratch/missing-app-setting/fixtures/028-az.stdout"
for number in 29 30 31 32 33 34; do
  printf '%s' "$missing_settings" \
    >"$scratch/missing-app-setting/fixtures/$(printf '%03d' "$number")-jq.stdin"
done
printf '%s\n' 1 >"$scratch/missing-app-setting/fixtures/034-jq.status"
add_failure_metadata missing-app-setting 35
run_case missing-app-setting 1 \
  'ERROR: required app setting WEBSITES_PORT is missing or has an unexpected value'
assert_failure_evidence missing-app-setting 'Required app settings' \
  Readiness Provisioning 'Application health' 'Resource topology' 'Model deployment' \
  'Managed identity' 'Foundry User assignment'

make_success_fixture missing-deadline
status=0
env -u WORKSHOP_AZURE_CLEANUP_DEADLINE \
  WORKSHOP_AZURE_FIXTURE_DIR="$scratch/missing-deadline/fixtures" \
  WORKSHOP_AZURE_COMMAND_LOG="$scratch/missing-deadline/commands.log" \
  WORKSHOP_AZURE_EVIDENCE_DIR="$scratch/missing-deadline/evidence" \
  WORKSHOP_AZURE_RETRY_SECONDS=1 \
  WORKSHOP_AZURE_RETRY_ATTEMPTS=3 \
  PATH="$scratch/missing-deadline/bin" \
  "$scratch/missing-deadline/project/scripts/azure-preflight.sh" \
  >"$scratch/missing-deadline/stdout" 2>"$scratch/missing-deadline/stderr" || status=$?
[[ "$status" -eq 1 ]] || fail_test 'missing cleanup deadline did not fail'
grep -Fqx 'ERROR: WORKSHOP_AZURE_CLEANUP_DEADLINE must be set' \
  "$scratch/missing-deadline/stderr" ||
  fail_test 'missing cleanup deadline did not emit the expected failure'
[[ ! -e "$scratch/missing-deadline/commands.log" ]] ||
  fail_test 'missing cleanup deadline invoked external commands'

echo "Azure Preflight tests passed"
