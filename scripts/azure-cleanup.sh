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

azd_value_optional() {
  local value
  if value="$(azd env get-value "$1" 2>/dev/null)"; then
    printf '%s\n' "$value"
  fi
}

foundry="$(azd_value_optional AZURE_OPENAI_ACCOUNT_NAME)"
if [[ -z "$foundry" ]]; then
  foundry="${WORKSHOP_AZURE_FOUNDRY_NAME:-}"
fi
location="$(azd_value AZURE_LOCATION)"
resource_group="$(azd_value_optional AZURE_RESOURCE_GROUP_NAME)"
environment_name="$(azd_value_optional AZURE_ENV_NAME)"
subscription_id="$(azd_value AZURE_SUBSCRIPTION_ID)"
account_subscription_id="$(az account show --query id --output tsv 2>/dev/null)" ||
  fail 'could not read the Azure subscription before cleanup'
require_nonempty 'Azure subscription' "$subscription_id"
require_nonempty 'active Azure CLI subscription' "$account_subscription_id"
[[ "$subscription_id" == "$account_subscription_id" ]] ||
  fail 'azd subscription does not match the active Azure CLI subscription'

if [[ -z "$resource_group" ]]; then
  [[ "$environment_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] ||
    fail 'could not safely derive the resource group after partial provisioning'
  resource_group="rg-$environment_name"
fi

if [[ -z "$foundry" ]]; then
  if ! foundry="$(
    az cognitiveservices account list \
      --resource-group "$resource_group" \
      --subscription "$subscription_id" \
      --query '[0].name' --output tsv 2>/dev/null
  )"; then
    resource_group_exists_before_down="$(
      az group exists --name "$resource_group" \
        --subscription "$subscription_id" --output tsv 2>/dev/null
    )" || fail 'could not inspect the resource group before cleanup'
    [[ "$resource_group_exists_before_down" == false ]] ||
      fail 'could not discover the Foundry account after partial provisioning'
    foundry=''
  fi
fi
[[ "$foundry" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,62}[A-Za-z0-9]$ ]] ||
  fail 'Foundry account name is unavailable; recover it from azd or set WORKSHOP_AZURE_FOUNDRY_NAME before cleanup'

safe_environment='not recorded (unsafe or unavailable)'
if [[ "$environment_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] &&
  [[ "$environment_name" != "$resource_group" ]] &&
  [[ "$environment_name" != "$foundry" ]]; then
  safe_environment="$environment_name"
fi

azd down --force --purge ||
  fail 'azd down --force --purge failed'

resource_group_exists=''
resource_group_query_succeeded='no'
for (( check = 1; check <= WORKSHOP_AZURE_RETRY_ATTEMPTS; check++ )); do
  if resource_group_exists="$(
    az group exists --name "$resource_group" \
      --subscription "$subscription_id" --output tsv 2>/dev/null
  )"; then
    resource_group_query_succeeded='yes'
    break
  fi
  if (( check < WORKSHOP_AZURE_RETRY_ATTEMPTS )); then
    sleep "$WORKSHOP_AZURE_RETRY_SECONDS"
  fi
done
[[ "$resource_group_query_succeeded" == yes ]] ||
  fail 'could not verify resource group deletion after azd down'
[[ "$resource_group_exists" == false ]] ||
  fail 'resource group still exists after azd down: cleanup is incomplete'

active_resources="$(
  az resource list \
    --subscription "$subscription_id" \
    --query "[?resourceGroup=='$resource_group' && (type=='Microsoft.Web/serverfarms' || type=='Microsoft.Web/sites' || type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.CognitiveServices/accounts/deployments')].[type, properties.provisioningState]" \
    --output tsv 2>/dev/null
)" || fail 'could not inspect active App Service and Foundry resources after azd down'
if [[ -n "$active_resources" ]]; then
  printf 'ERROR: active App Service or Foundry resources remain after azd down\n' >&2
  printf 'Remaining active resource types/states:\n' >&2
  while IFS=$'\t' read -r resource_type provisioning_state; do
    printf '  - type=%s state=%s\n' \
      "$resource_type" "${provisioning_state:-unknown}" >&2
  done <<<"$active_resources"
  printf 'Inspect and remove them with:\n' >&2
  printf "  az resource list --resource-group '%s' --query \"[?type=='Microsoft.Web/serverfarms' || type=='Microsoft.Web/sites' || type=='Microsoft.CognitiveServices/accounts' || type=='Microsoft.CognitiveServices/accounts/deployments'].[type, properties.provisioningState]\" --output table\n" \
    "$resource_group" >&2
  printf "  az group delete --name '%s' --yes\n" "$resource_group" >&2
  printf 'Escalate to the subscription administrator if Azure refuses deletion.\n' >&2
  exit 1
fi

deleted_account_id() {
  az cognitiveservices account list-deleted \
    --subscription "$subscription_id" \
    --query "[?name=='${foundry}' && location=='${location}'].id | [0]" \
    --output tsv 2>/dev/null
}

explicit_purge_required='no'
purge_succeeded='no'
deleted_account_present='no'
for (( check = 1; check <= WORKSHOP_AZURE_RETRY_ATTEMPTS; check++ )); do
  deleted_id="$(deleted_account_id)" ||
    fail 'could not inspect deleted Foundry accounts'
  if [[ -n "$deleted_id" ]]; then
    explicit_purge_required='yes'
    if az cognitiveservices account purge \
      --name "$foundry" \
      --resource-group "$resource_group" \
      --location "$location" \
      --subscription "$subscription_id" >/dev/null 2>&1; then
      purge_succeeded='yes'
      break
    fi
    printf 'ERROR: explicit Foundry purge failed; retry cleanup after resolving Azure permissions or service errors\n' >&2
    printf 'Retry the failed command with:\n' >&2
    printf "  az cognitiveservices account purge --name '%s' --resource-group '%s' --location '%s'\n" \
      "$foundry" "$resource_group" "$location" >&2
    exit 1
  fi
  if (( check < WORKSHOP_AZURE_RETRY_ATTEMPTS )); then
    sleep "$WORKSHOP_AZURE_RETRY_SECONDS"
  fi
done

if [[ "$purge_succeeded" == yes ]]; then
  for (( check = 1; check <= WORKSHOP_AZURE_RETRY_ATTEMPTS; check++ )); do
    deleted_id="$(deleted_account_id)" ||
      fail 'could not inspect deleted Foundry accounts'
    if [[ -n "$deleted_id" ]]; then
      deleted_account_present='yes'
    else
      deleted_account_present='no'
    fi
    if (( check < WORKSHOP_AZURE_RETRY_ATTEMPTS )); then
      sleep "$WORKSHOP_AZURE_RETRY_SECONDS"
    fi
  done
fi

if [[ "$deleted_account_present" == yes ]]; then
  printf 'ERROR: Foundry soft-delete record remained after %s checks\n' \
    "$WORKSHOP_AZURE_RETRY_ATTEMPTS" >&2
  printf 'Remaining resource: Microsoft.CognitiveServices/accounts state=soft-deleted\n' >&2
  printf 'Retry cleanup and verify with:\n' >&2
  printf "  az cognitiveservices account purge --name '%s' --resource-group '%s' --location '%s'\n" \
    "$foundry" "$resource_group" "$location" >&2
  printf "  az cognitiveservices account list-deleted --query \"[?name=='%s' && location=='%s'].[type, properties.provisioningState]\" --output table\n" \
    "$foundry" "$location" >&2
  printf 'Escalate to the subscription administrator if the record remains.\n' >&2
  exit 1
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
