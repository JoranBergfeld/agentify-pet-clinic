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
subscription_id="$(azd_value AZURE_SUBSCRIPTION_ID)"
account_subscription_id="$(az account show --query id --output tsv 2>/dev/null)" ||
  fail 'could not read the Azure subscription before cleanup'
require_nonempty 'Azure subscription' "$subscription_id"
require_nonempty 'active Azure CLI subscription' "$account_subscription_id"
[[ "$subscription_id" == "$account_subscription_id" ]] ||
  fail 'azd subscription does not match the active Azure CLI subscription'

safe_environment='not recorded (unsafe or unavailable)'
if [[ "$environment_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] &&
  [[ "$environment_name" != "$resource_group" ]] &&
  [[ "$environment_name" != "$foundry" ]]; then
  safe_environment="$environment_name"
fi

azd down --force --purge ||
  fail 'azd down --force --purge failed'

resource_group_exists="$(
  az group exists --name "$resource_group" \
    --subscription "$subscription_id" --output tsv 2>/dev/null
)" || fail 'could not verify resource group deletion after azd down'
[[ "$resource_group_exists" == false ]] ||
  fail 'resource group still exists after azd down: cleanup is incomplete'

active_resources="$(
  az resource list \
    --subscription "$subscription_id" \
    --query "[?resourceGroup=='$resource_group' && (type=='Microsoft.Web/serverfarms' || type=='Microsoft.Web/sites' || type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.CognitiveServices/accounts/deployments')].type" \
    --output tsv 2>/dev/null
)" || fail 'could not inspect active App Service and Foundry resources after azd down'
[[ -z "$active_resources" ]] ||
  fail 'active App Service or Foundry resources remain after azd down'

deleted_account_id() {
  az cognitiveservices account list-deleted \
    --subscription "$subscription_id" \
    --query "[?name=='${foundry}' && location=='${location}'].id | [0]" \
    --output tsv 2>/dev/null
}

explicit_purge_required='no'
consecutive_absent=0
for (( check = 1; check <= WORKSHOP_AZURE_RETRY_ATTEMPTS; check++ )); do
  deleted_id="$(deleted_account_id)" ||
    fail 'could not inspect deleted Foundry accounts'
  if [[ -n "$deleted_id" ]]; then
    consecutive_absent=0
    if [[ "$explicit_purge_required" == no ]]; then
      explicit_purge_required='yes'
      az cognitiveservices account purge \
        --name "$foundry" \
        --resource-group "$resource_group" \
        --location "$location" \
        --subscription "$subscription_id" ||
        fail 'explicit Foundry purge failed'
    fi
  else
    consecutive_absent="$((consecutive_absent + 1))"
    if (( consecutive_absent >= 2 )); then
      break
    fi
  fi
  if (( check < WORKSHOP_AZURE_RETRY_ATTEMPTS )); then
    sleep "$WORKSHOP_AZURE_RETRY_SECONDS"
  fi
done
(( consecutive_absent >= 2 )) ||
  fail "Foundry soft-delete absence did not stabilize after $WORKSHOP_AZURE_RETRY_ATTEMPTS checks"

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
