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

for required_command in az azd curl jq git date; do
  require_command "$required_command"
done

"$root/scripts/azure-readiness.sh"
azd up --no-prompt || fail 'azd up failed'

azd_value() {
  local name="$1"
  local value
  value="$(azd env get-value "$name" 2>/dev/null)" ||
    fail "could not read azd output $name"
  require_nonempty "azd output $name" "$value"
  printf '%s\n' "$value"
}

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
  fail "deployed region does not match expected region $AZURE_LOCATION"
[[ "$model" == "$AZURE_OPENAI_MODEL" ]] ||
  fail "deployed model does not match expected model $AZURE_OPENAI_MODEL"
[[ "$model_version" == "$AZURE_OPENAI_MODEL_VERSION" ]] ||
  fail "deployed model version does not match expected version $AZURE_OPENAI_MODEL_VERSION"
[[ "$deployment" == "$AZURE_OPENAI_DEPLOYMENT" ]] ||
  fail "deployed model deployment does not match expected deployment $AZURE_OPENAI_DEPLOYMENT"
[[ "$deployment_sku" == "$AZURE_OPENAI_DEPLOYMENT_SKU" ]] ||
  fail "deployed model SKU does not match expected SKU $AZURE_OPENAI_DEPLOYMENT_SKU"
[[ "$deployment_capacity" == "$AZURE_OPENAI_DEPLOYMENT_CAPACITY" ]] ||
  fail "deployed model capacity does not match expected capacity $AZURE_OPENAI_DEPLOYMENT_CAPACITY"

subscription_id="$(az account show --query id --output tsv 2>/dev/null)" ||
  fail 'could not read the deployed Azure subscription'
require_nonempty 'deployed Azure subscription' "$subscription_id"

health_is_up() {
  local health_json
  health_json="$(curl --fail --silent --show-error "$app_url/actuator/health" 2>/dev/null)" ||
    return 1
  [[ "$(jq -r '.status // empty' <<<"$health_json" 2>/dev/null)" == 'UP' ]]
}

retry_until 'application health' health_is_up

resources_json="$(
  az resource list --resource-group "$resource_group" --output json 2>/dev/null
)" || fail 'could not list deployed resources'
resource_evidence="$(jq -er '[.[]? | {type, normalizedType: (.type | ascii_downcase), state: (.properties.provisioningState // empty)}] as $resources | ($resources | length) == 4 and ($resources | map(.normalizedType) | sort) == (["microsoft.cognitiveservices/accounts","microsoft.cognitiveservices/accounts/deployments","microsoft.web/serverfarms","microsoft.web/sites"] | sort) and all($resources[]; .state == "Succeeded") | if . then $resources | sort_by(.normalizedType) | map("- Resource: `\(.type)`; provisioningState: `\(.state)`") | join("\n") else error("invalid resource provisioning evidence") end' <<<"$resources_json" 2>/dev/null)" ||
  fail 'deployed resources are missing, unexpected, or not successfully provisioned'

deployment_json="$(
  az cognitiveservices account deployment show \
    --name "$foundry" \
    --resource-group "$resource_group" \
    --deployment-name "$deployment" \
    --output json 2>/dev/null
)" || fail 'could not inspect the model deployment'
jq -e \
  --arg model "$model" \
  --arg version "$model_version" \
  --arg sku "$deployment_sku" \
  --argjson capacity "$deployment_capacity" \
  '.properties.model.name == $model and .properties.model.version == $version and .sku.name == $sku and .sku.capacity == $capacity' \
  >/dev/null 2>&1 <<<"$deployment_json" ||
  fail 'model deployment values do not exactly match the azd outputs'

identity_json="$(
  az webapp identity show \
    --name "$web_app" \
    --resource-group "$resource_group" \
    --output json 2>/dev/null
)" || fail 'could not inspect the web app managed identity'
principal_id="$(jq -er 'select(.type == "SystemAssigned") | .principalId | select(type == "string" and length > 0)' <<<"$identity_json" 2>/dev/null)" ||
  fail 'web app system-assigned managed identity is missing'

foundry_scope="$(
  az cognitiveservices account show \
    --name "$foundry" \
    --resource-group "$resource_group" \
    --query id \
    --output tsv 2>/dev/null
)" || fail 'could not inspect the Foundry resource scope'
require_nonempty 'Foundry resource scope' "$foundry_scope"

roles_json="$(
  az role assignment list \
    --assignee-object-id "$principal_id" \
    --scope "$foundry_scope" \
    --output json 2>/dev/null
)" || fail 'could not inspect the Foundry role assignment'
jq -e \
  --arg principal "$principal_id" \
  --arg scope "$foundry_scope" \
  'any(.[]; .roleDefinitionName == "Foundry User" and .principalId == $principal and .scope == $scope)' \
  >/dev/null 2>&1 <<<"$roles_json" ||
  fail 'Foundry User assignment is missing at the Foundry resource scope'

settings_json="$(
  az webapp config appsettings list \
    --name "$web_app" \
    --resource-group "$resource_group" \
    --output json 2>/dev/null
)" || fail 'could not inspect web app settings'

require_app_setting() {
  local name="$1"
  local expected_value="$2"
  jq -e --arg name "$name" --arg value "$expected_value" \
    '[.[]? | select(.name == $name and .value == $value)] | length == 1' \
    >/dev/null 2>&1 <<<"$settings_json" ||
    fail "required app setting $name is missing or has an unexpected value"
}

require_app_setting AZURE_OPENAI_ENDPOINT "https://$foundry.openai.azure.com"
require_app_setting AZURE_OPENAI_MICROSOFT_FOUNDRY true
require_app_setting AZURE_OPENAI_DEPLOYMENT "$deployment"
require_app_setting AZURE_OPENAI_MODEL "$model"
require_app_setting JAVA_OPTS '-Xms256m -Xmx1024m'
require_app_setting WEBSITES_PORT 8080

revision="$(git -C "$root" rev-parse HEAD 2>/dev/null)" ||
  fail 'could not read the repository revision'
require_nonempty 'repository revision' "$revision"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
deployed_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
evidence_file="$evidence_dir/preflight-$timestamp.md"
mkdir -p "$evidence_dir"

cat >"$evidence_file" <<EOF
# Azure Preflight Evidence

- Command version: \`$PREFLIGHT_COMMAND_VERSION\`
- Evidence schema version: \`$PREFLIGHT_EVIDENCE_SCHEMA_VERSION\`
- UTC: \`$deployed_time\`
- Git revision: \`$revision\`
- Subscription: \`$(redact_subscription "$subscription_id")\`
- Region: \`$location\`
- Model: \`$model\`
- Model version: \`$model_version\`
- Deployment: \`$deployment\`
- SKU: \`$deployment_sku\`
- Capacity: \`$deployment_capacity\`
$resource_evidence
- Managed identity: \`present (SystemAssigned)\`
- Role: \`Foundry User\`
- Role scope category: \`Foundry resource\`
- Required app settings: \`AZURE_OPENAI_ENDPOINT\`, \`AZURE_OPENAI_MICROSOFT_FOUNDRY\`, \`AZURE_OPENAI_DEPLOYMENT\`, \`AZURE_OPENAI_MODEL\`, \`JAVA_OPTS\`, \`WEBSITES_PORT\`
- Application health: \`UP\`
- Deployed time: \`$deployed_time\`
- Cleanup deadline: \`$cleanup_deadline\`

| Gate | Result |
| --- | --- |
| Readiness | PASS |
| Provisioning | PASS |
| Resource topology | PASS |
| Managed identity | PASS |
| Foundry User assignment | PASS |
| Model deployment | PASS |
| Required app settings | PASS |
| Application health | PASS |
EOF

printf 'Azure Preflight passed; evidence: %s\n' "$evidence_file"
