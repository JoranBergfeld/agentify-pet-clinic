#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/workshop-azure.sh
source "$root/scripts/lib/workshop-azure.sh"

readonly PREFLIGHT_COMMAND_VERSION='1.0.0'
readonly PREFLIGHT_EVIDENCE_SCHEMA_VERSION='1.0'

evidence_dir="${WORKSHOP_AZURE_EVIDENCE_DIR:-$root/.workshop-evidence}"
cleanup_deadline="${WORKSHOP_AZURE_CLEANUP_DEADLINE-}"
require_nonempty WORKSHOP_AZURE_CLEANUP_DEADLINE "$cleanup_deadline"

readonly gates=(
  'Readiness'
  'Provisioning'
  'Deployment outputs'
  'Application health'
  'Resource topology'
  'Model deployment'
  'Managed identity'
  'Foundry User assignment'
  'Required app settings'
)
declare -A gate_status=()
for gate in "${gates[@]}"; do
  gate_status["$gate"]='NOT RUN'
done

deployment_started=0
evidence_written=0
current_gate=''
observed_error=''
revision=''
timestamp=''
deployed_time=''
subscription_id=''
resource_evidence=''
evidence_file=''

begin_gate() {
  current_gate="$1"
  observed_error="$2"
  gate_status["$current_gate"]='FAIL'
}

pass_gate() {
  gate_status["$1"]='PASS'
  current_gate=''
  observed_error=''
}

verification_fail() {
  begin_gate "$1" "$2"
  fail "$2"
}

collect_evidence_metadata() {
  if [[ -z "$revision" ]]; then
    revision="$(git -C "$root" rev-parse HEAD 2>/dev/null)" ||
      revision='unavailable'
  fi
  if [[ -z "$timestamp" ]]; then
    timestamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null)" ||
      timestamp='unknown-utc'
  fi
  if [[ -z "$deployed_time" ]]; then
    deployed_time="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" ||
      deployed_time='unavailable'
  fi
  if [[ -z "$subscription_id" ]]; then
    subscription_id="$(az account show --query id --output tsv 2>/dev/null)" ||
      subscription_id='unavailable'
  fi
}

write_evidence() {
  local outcome="$1"
  local region="$AZURE_LOCATION"
  local model_name="$AZURE_OPENAI_MODEL"
  local version="$AZURE_OPENAI_MODEL_VERSION"
  local deployment_name="$AZURE_OPENAI_DEPLOYMENT"
  local sku="$AZURE_OPENAI_DEPLOYMENT_SKU"
  local capacity="$AZURE_OPENAI_DEPLOYMENT_CAPACITY"
  local gate
  local pending_evidence_file
  local write_failed=0

  evidence_file="$evidence_dir/preflight-$timestamp.md"
  pending_evidence_file="$evidence_file.tmp.$$"
  if [[ "$outcome" == 'PASSED' ]]; then
    region="$location"
    model_name="$model"
    version="$model_version"
    deployment_name="$deployment"
    sku="$deployment_sku"
    capacity="$deployment_capacity"
  fi

  if ! mkdir -p "$evidence_dir" || [[ ! -d "$evidence_dir" ]]; then
    evidence_file=''
    return 1
  fi
  if ! exec 3>"$pending_evidence_file"; then
    evidence_file=''
    return 1
  fi
  cat >&3 <<EOF || write_failed=1
# Azure Preflight Evidence

- Outcome: \`$outcome\`
- Command version: \`$PREFLIGHT_COMMAND_VERSION\`
- Evidence schema version: \`$PREFLIGHT_EVIDENCE_SCHEMA_VERSION\`
- UTC: \`$deployed_time\`
- Git revision: \`$revision\`
- Subscription: \`$(redact_subscription "$subscription_id")\`
- Region: \`$region\`
- Model: \`$model_name\`
- Model version: \`$version\`
- Deployment: \`$deployment_name\`
- SKU: \`$sku\`
- Capacity: \`$capacity\`
- Cleanup deadline: \`$cleanup_deadline\`
EOF
  if [[ "$outcome" == 'PASSED' ]]; then
    printf '%s\n' "$resource_evidence" >&3 || write_failed=1
    cat >&3 <<EOF || write_failed=1
- Managed identity: \`present (SystemAssigned)\`
- Role: \`Foundry User\`
- Role scope category: \`Foundry resource\`
- Required app settings: \`AZURE_OPENAI_ENDPOINT\`, \`AZURE_OPENAI_MICROSOFT_FOUNDRY\`, \`AZURE_OPENAI_DEPLOYMENT\`, \`AZURE_OPENAI_MODEL\`, \`JAVA_OPTS\`, \`WEBSITES_PORT\`
- Application health: \`UP\`
- Deployed time: \`$deployed_time\`
EOF
  else
    cat >&3 <<EOF || write_failed=1
- Failed gate: \`$current_gate\`
- Observed safe error: \`$observed_error\`

> **WARNING:** This environment may remain billable.
> Cleanup is required: \`scripts/azure-cleanup.sh\`
EOF
  fi
  cat >&3 <<'EOF' || write_failed=1

| Gate | Result |
| --- | --- |
EOF
  for gate in "${gates[@]}"; do
    printf '| %s | %s |\n' "$gate" "${gate_status[$gate]}" >&3 ||
      write_failed=1
  done
  exec 3>&- || write_failed=1
  if (( write_failed != 0 )); then
    rm -f "$pending_evidence_file"
    evidence_file=''
    return 1
  fi
  if ! mv -f -- "$pending_evidence_file" "$evidence_file"; then
    rm -f "$pending_evidence_file"
    evidence_file=''
    return 1
  fi
  if [[ ! -r "$evidence_file" || ! -s "$evidence_file" ]]; then
    rm -f "$evidence_file"
    evidence_file=''
    return 1
  fi
  evidence_written=1
}

on_exit() {
  local status="$?"
  (( status != 0 && deployment_started == 1 && evidence_written == 0 )) || return
  trap - EXIT
  set +e
  collect_evidence_metadata
  if write_evidence FAILED; then
    printf 'Failure evidence: %s\n' "$evidence_file" >&2
  else
    printf 'WARNING: could not write Azure Preflight failure evidence; no evidence path is available.\n' >&2
  fi
  printf 'WARNING: Azure Preflight failed after deployment; this environment may remain billable.\n' >&2
  printf 'Cleanup is required: scripts/azure-cleanup.sh\n' >&2
  exit "$status"
}

for required_command in az azd curl jq git date; do
  require_command "$required_command"
done

begin_gate 'Readiness' 'Azure readiness failed'
"$root/scripts/azure-readiness.sh"
pass_gate 'Readiness'
begin_gate 'Provisioning' 'azd up failed'
trap on_exit EXIT
deployment_started=1
azd up --no-prompt || fail 'azd up failed'
pass_gate 'Provisioning'

azd_value() {
  local name="$1"
  local value
  value="$(azd env get-value "$name" 2>/dev/null)" ||
    verification_fail 'Deployment outputs' "could not read azd output $name"
  [[ -n "$value" ]] ||
    verification_fail 'Deployment outputs' "azd output $name must be set"
  printf '%s\n' "$value"
}

begin_gate 'Deployment outputs' 'deployed values do not match the configured workshop values'
resource_group="$(azd_value AZURE_RESOURCE_GROUP_NAME)"
web_app="$(azd_value SERVICE_WEB_NAME)"
app_url="$(azd_value WEB_APP_URL)"
foundry="$(azd_value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd_value AZURE_LOCATION)"
model="$(azd_value AZURE_OPENAI_MODEL)"
model_version="$(azd_value AZURE_OPENAI_MODEL_VERSION)"
deployment="$(azd_value AZURE_OPENAI_DEPLOYMENT)"
deployment_sku="$(azd_value AZURE_OPENAI_DEPLOYMENT_SKU)"
deployment_capacity="$(azd_value AZURE_OPENAI_DEPLOYMENT_CAPACITY)"

[[ "$location" == "$AZURE_LOCATION" ]] ||
  verification_fail 'Deployment outputs' "deployed region does not match expected region $AZURE_LOCATION"
[[ "$model" == "$AZURE_OPENAI_MODEL" ]] ||
  verification_fail 'Deployment outputs' "deployed model does not match expected model $AZURE_OPENAI_MODEL"
[[ "$model_version" == "$AZURE_OPENAI_MODEL_VERSION" ]] ||
  verification_fail 'Deployment outputs' "deployed model version does not match expected version $AZURE_OPENAI_MODEL_VERSION"
[[ "$deployment" == "$AZURE_OPENAI_DEPLOYMENT" ]] ||
  verification_fail 'Deployment outputs' "deployed model deployment does not match expected deployment $AZURE_OPENAI_DEPLOYMENT"
[[ "$deployment_sku" == "$AZURE_OPENAI_DEPLOYMENT_SKU" ]] ||
  verification_fail 'Deployment outputs' "deployed model SKU does not match expected SKU $AZURE_OPENAI_DEPLOYMENT_SKU"
[[ "$deployment_capacity" == "$AZURE_OPENAI_DEPLOYMENT_CAPACITY" ]] ||
  verification_fail 'Deployment outputs' "deployed model capacity does not match expected capacity $AZURE_OPENAI_DEPLOYMENT_CAPACITY"
pass_gate 'Deployment outputs'

subscription_id="$(az account show --query id --output tsv 2>/dev/null)" ||
  verification_fail 'Deployment outputs' 'could not read the deployed Azure subscription'
[[ -n "$subscription_id" ]] ||
  verification_fail 'Deployment outputs' 'deployed Azure subscription must be set'

health_is_up() {
  local health_json
  health_json="$(curl --fail --silent --show-error "$app_url/actuator/health" 2>/dev/null)" ||
    return 1
  [[ "$(jq -r '.status // empty' <<<"$health_json" 2>/dev/null)" == 'UP' ]]
}

begin_gate 'Application health' \
  "application health did not succeed after $WORKSHOP_AZURE_RETRY_ATTEMPTS attempts"
retry_until 'application health' health_is_up
pass_gate 'Application health'

begin_gate 'Resource topology' \
  'deployed resources are missing, unexpected, or not successfully provisioned'
resources_json="$(
  az resource list --resource-group "$resource_group" --output json 2>/dev/null
)" || verification_fail 'Resource topology' 'could not list deployed resources'
resource_evidence="$(jq -er '["microsoft.cognitiveservices/accounts","microsoft.web/serverfarms","microsoft.web/sites"] as $requiredTypes | [.[]? | {type, normalizedType: (.type | ascii_downcase), state: (.provisioningState // empty)}] as $resources | [$resources[] | select(.normalizedType as $type | $requiredTypes | index($type))] as $required | [$resources[] | select(.normalizedType as $type | ($requiredTypes + ["microsoft.insights/diagnosticsettings"]) | index($type) | not)] as $unexpected | ($required | length) == 3 and ($required | map(.normalizedType) | sort) == ($requiredTypes | sort) and all($required[]; .state == "Succeeded") and ($unexpected | length) == 0 | if . then $required | sort_by(.normalizedType) | map("- Resource: `\(.type)`; provisioningState: `\(.state)`") | join("\n") else error("invalid resource provisioning evidence") end' <<<"$resources_json" 2>/dev/null)" ||
  verification_fail 'Resource topology' \
    'deployed resources are missing, unexpected, or not successfully provisioned'
pass_gate 'Resource topology'

begin_gate 'Model deployment' \
  'model deployment values do not exactly match the azd outputs'
deployment_json="$(
  az cognitiveservices account deployment show \
    --name "$foundry" \
    --resource-group "$resource_group" \
    --deployment-name "$deployment" \
    --output json 2>/dev/null
)" || verification_fail 'Model deployment' 'could not inspect the model deployment'
jq -e \
  --arg model "$model" \
  --arg version "$model_version" \
  --arg sku "$deployment_sku" \
  --argjson capacity "$deployment_capacity" \
  '.properties.model.name == $model and .properties.model.version == $version and .sku.name == $sku and .sku.capacity == $capacity' \
  >/dev/null 2>&1 <<<"$deployment_json" ||
  verification_fail 'Model deployment' \
    'model deployment values do not exactly match the azd outputs'
pass_gate 'Model deployment'

begin_gate 'Managed identity' 'web app system-assigned managed identity is missing'
identity_json="$(
  az webapp identity show \
    --name "$web_app" \
    --resource-group "$resource_group" \
    --output json 2>/dev/null
)" || verification_fail 'Managed identity' 'could not inspect the web app managed identity'
principal_id="$(jq -er 'select(.type == "SystemAssigned") | .principalId | select(type == "string" and length > 0)' <<<"$identity_json" 2>/dev/null)" ||
  verification_fail 'Managed identity' \
    'web app system-assigned managed identity is missing'
pass_gate 'Managed identity'

begin_gate 'Foundry User assignment' \
  'Foundry User assignment is missing at the Foundry resource scope'
foundry_scope="$(
  az cognitiveservices account show \
    --name "$foundry" \
    --resource-group "$resource_group" \
    --query id \
    --output tsv 2>/dev/null
)" || verification_fail 'Foundry User assignment' \
  'could not inspect the Foundry resource scope'
[[ -n "$foundry_scope" ]] ||
  verification_fail 'Foundry User assignment' 'Foundry resource scope must be set'

roles_json="$(
  az role assignment list \
    --assignee-object-id "$principal_id" \
    --scope "$foundry_scope" \
    --output json 2>/dev/null
)" || verification_fail 'Foundry User assignment' \
  'could not inspect the Foundry role assignment'
jq -e \
  --arg principal "$principal_id" \
  --arg scope "$foundry_scope" \
  'any(.[]; .roleDefinitionName == "Foundry User" and .principalId == $principal and ((.scope | ascii_downcase) == ($scope | ascii_downcase)))' \
  >/dev/null 2>&1 <<<"$roles_json" ||
  verification_fail 'Foundry User assignment' \
    'Foundry User assignment is missing at the Foundry resource scope'
pass_gate 'Foundry User assignment'

begin_gate 'Required app settings' \
  'one or more required app settings are missing or unexpected'
settings_json="$(
  az webapp config appsettings list \
    --name "$web_app" \
    --resource-group "$resource_group" \
    --output json 2>/dev/null
)" || verification_fail 'Required app settings' 'could not inspect web app settings'

require_app_setting() {
  local name="$1"
  local expected_value="$2"
  jq -e --arg name "$name" --arg value "$expected_value" \
    '[.[]? | select(.name == $name and .value == $value)] | length == 1' \
    >/dev/null 2>&1 <<<"$settings_json" ||
    verification_fail 'Required app settings' \
      "required app setting $name is missing or has an unexpected value"
}

require_app_setting AZURE_OPENAI_ENDPOINT "https://$foundry.openai.azure.com"
require_app_setting AZURE_OPENAI_MICROSOFT_FOUNDRY true
require_app_setting AZURE_OPENAI_DEPLOYMENT "$deployment"
require_app_setting AZURE_OPENAI_MODEL "$model"
require_app_setting JAVA_OPTS '-Xms256m -Xmx1024m'
require_app_setting WEBSITES_PORT 8080
pass_gate 'Required app settings'

revision="$(git -C "$root" rev-parse HEAD 2>/dev/null)" ||
  verification_fail 'Required app settings' 'could not read the repository revision'
[[ -n "$revision" ]] ||
  verification_fail 'Required app settings' 'repository revision must be set'
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
deployed_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_evidence PASSED
printf 'Azure Preflight passed; evidence: %s\n' "$evidence_file"
