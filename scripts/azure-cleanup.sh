#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/workshop-azure.sh
source "$root/scripts/lib/workshop-azure.sh"

readonly CLEANUP_COMMAND_VERSION='1.0.0'
readonly CLEANUP_EVIDENCE_SCHEMA_VERSION='1.0'

evidence_dir="${WORKSHOP_AZURE_EVIDENCE_DIR:-$root/.workshop-evidence}"

for required_command in az azd date; do
  require_command "$required_command"
done

azd_value() {
  local name="$1"
  local value
  value="$(azd env get-value "$name" 2>/dev/null)" ||
    fail "could not read azd value $name before cleanup"
  require_nonempty "azd value $name" "$value"
  printf '%s\n' "$value"
}

foundry="$(azd_value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd_value AZURE_LOCATION)"
resource_group="$(azd_value AZURE_RESOURCE_GROUP_NAME)"
environment_name="$(azd env get-value AZURE_ENV_NAME 2>/dev/null || true)"
subscription_id="$(az account show --query id --output tsv 2>/dev/null)" ||
  fail 'could not read the Azure subscription before cleanup'
require_nonempty 'Azure subscription' "$subscription_id"

safe_environment='not recorded (unsafe or unavailable)'
if [[ "$environment_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] &&
  [[ "$environment_name" != "$resource_group" ]] &&
  [[ "$environment_name" != "$foundry" ]]; then
  safe_environment="$environment_name"
fi

azd down --force --purge ||
  fail 'azd down --force --purge failed'

resource_group_exists="$(
  az group exists --name "$resource_group" --output tsv 2>/dev/null
)" || fail 'could not verify resource group deletion after azd down'
[[ "$resource_group_exists" == false ]] ||
  fail 'resource group still exists after azd down: cleanup is incomplete'

active_resources="$(
  az resource list \
    --query "[?resourceGroup=='$resource_group' && (type=='Microsoft.Web/serverfarms' || type=='Microsoft.Web/sites' || type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.CognitiveServices/accounts/deployments')].type" \
    --output tsv 2>/dev/null
)" || fail 'could not inspect active App Service and Foundry resources after azd down'
[[ -z "$active_resources" ]] ||
  fail 'active App Service or Foundry resources remain after azd down'

deleted_account_id() {
  az cognitiveservices account list-deleted \
    --query "[?name=='${foundry}' && location=='${location}'].id | [0]" \
    --output tsv 2>/dev/null
}

deleted_id="$(deleted_account_id)" ||
  fail 'could not inspect deleted Foundry accounts'
explicit_purge_required='no'
if [[ -n "$deleted_id" ]]; then
  explicit_purge_required='yes'
  az cognitiveservices account purge \
    --name "$foundry" \
    --resource-group "$resource_group" \
    --location "$location" ||
    fail 'explicit Foundry purge failed'

  soft_delete_absent() {
    local remaining_id
    remaining_id="$(deleted_account_id)" || return 1
    [[ -z "$remaining_id" ]]
  }

  retry_until 'Foundry soft-delete absence' soft_delete_absent
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
cleanup_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
evidence_file="$evidence_dir/cleanup-$timestamp.md"
mkdir -p "$evidence_dir"

cat >"$evidence_file" <<EOF
# Azure Cleanup Evidence

- Command version: \`$CLEANUP_COMMAND_VERSION\`
- Evidence schema version: \`$CLEANUP_EVIDENCE_SCHEMA_VERSION\`
- UTC: \`$cleanup_time\`
- Subscription: \`$(redact_subscription "$subscription_id")\`
- Region: \`$location\`
- Environment: \`$safe_environment\`
- Explicit Foundry purge required: \`$explicit_purge_required\`
- Resource group absent: \`PASS\`
- App Service plans absent: \`PASS\`
- Web apps absent: \`PASS\`
- Active Foundry resources absent: \`PASS\`
- Model deployments absent: \`PASS\`
- Deleted Foundry accounts absent: \`PASS\`

Cost Management is eventually consistent. After billing data catches up,
confirm that this environment has no continuing resource charge.
EOF

printf 'Azure cleanup passed; evidence: %s\n' "$evidence_file"
