#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/workshop-azure.sh
source "$root/scripts/lib/workshop-azure.sh"

for required_command in az azd curl jq git; do
  require_command "$required_command"
done

account_subscription="$(az account show --query id --output tsv 2>/dev/null)" ||
  fail 'Azure CLI authentication required; run: az login'
[[ -n "$account_subscription" ]] ||
  fail 'Azure CLI account response was invalid; run: az account show'
principal="$(az account show --query user.name --output tsv 2>/dev/null)" ||
  fail 'Azure CLI account response was invalid; run: az account show'
[[ -n "$principal" ]] ||
  fail 'Azure CLI account has no deployable principal; run: az account show'

azd auth login --check-status >/dev/null 2>&1 ||
  fail 'Azure Developer CLI authentication required; run: azd auth login'

expected_subscription="${AZURE_SUBSCRIPTION_ID-}"
if [[ -z "$expected_subscription" ]]; then
  expected_subscription="$(azd env get-value AZURE_SUBSCRIPTION_ID 2>/dev/null || true)"
fi
[[ -n "$expected_subscription" ]] ||
  fail 'select a subscription explicitly by setting AZURE_SUBSCRIPTION_ID or in the azd environment'
if [[ "$account_subscription" != "$expected_subscription" ]]; then
  fail "Azure CLI selected subscription does not match the expected subscription; run: az account set --subscription $expected_subscription"
fi
subscription_scope="/subscriptions/$expected_subscription"

providers=(
  Microsoft.Resources
  Microsoft.Web
  Microsoft.CognitiveServices
  Microsoft.Authorization
)
for provider in "${providers[@]}"; do
  registration="$(
    az provider show --namespace "$provider" \
      --query registrationState --output tsv 2>/dev/null
  )" || fail "could not check provider $provider; verify Azure access and retry"
  [[ "$registration" == 'Registered' ]] ||
    fail "Azure provider $provider is not registered; run: az provider register --namespace $provider"
done

locations_json="$(
  az appservice list-locations --sku B1 --linux-workers-enabled --output json 2>/dev/null
)" || fail 'could not check B1 Linux App Service locations; verify Microsoft.Web access and retry'
jq -e 'type == "array"' >/dev/null 2>&1 <<<"$locations_json" ||
  fail 'B1 Linux App Service location response was invalid; verify Microsoft.Web access and retry'
jq -e --arg location "$AZURE_LOCATION_DISPLAY_NAME" \
  'any(.[]; ((.name // "") | ascii_downcase) == ($location | ascii_downcase))' \
  >/dev/null 2>&1 <<<"$locations_json" ||
  fail "B1 Linux App Service is unavailable in $AZURE_LOCATION_DISPLAY_NAME ($AZURE_LOCATION)"

web_usage_url="https://management.azure.com$subscription_scope/providers/Microsoft.Web/locations/$AZURE_LOCATION/usages?api-version=2024-04-01"
web_usage_json="$(
  az rest --method get --url "$web_usage_url" --output json 2>/dev/null
)" || fail "could not check Basic App Service quota in $AZURE_LOCATION_DISPLAY_NAME; verify Microsoft.Web access and retry"
basic_limit="$(jq -er '
  [.value[]? | select(.name.localizedValue == "Basic") | .limit]
  | if length == 1 and (.[0] | type) == "number" then .[0] else empty end
' <<<"$web_usage_json" 2>/dev/null)" ||
  fail "Basic App Service quota was not reported for $AZURE_LOCATION_DISPLAY_NAME; check quota in the Azure portal"
basic_current="$(jq -er '
  [.value[]? | select(.name.localizedValue == "Basic") | .currentValue]
  | if length == 1 and (.[0] | type) == "number" then .[0] else empty end
' <<<"$web_usage_json" 2>/dev/null)" ||
  fail "Basic App Service usage was not reported for $AZURE_LOCATION_DISPLAY_NAME; check quota in the Azure portal"
if (( basic_limit == 0 )); then
  fail "Basic App Service quota is zero in $AZURE_LOCATION_DISPLAY_NAME; request quota or choose another subscription"
fi
if (( basic_limit < -1 )); then
  fail "Basic App Service quota is unknown in $AZURE_LOCATION_DISPLAY_NAME; check quota in the Azure portal"
fi
if (( basic_limit > 0 && basic_current >= basic_limit )); then
  fail "Basic App Service quota is exhausted in $AZURE_LOCATION_DISPLAY_NAME; request quota or remove an existing plan"
fi

models_json="$(
  az cognitiveservices model list --location "$AZURE_LOCATION" --output json 2>/dev/null
)" || fail "could not check model availability in $AZURE_LOCATION_DISPLAY_NAME; verify Microsoft.CognitiveServices access and retry"
model_matches="$(jq -c \
  --arg model "$AZURE_OPENAI_MODEL" \
  --arg version "$AZURE_OPENAI_MODEL_VERSION" \
  '[.[] | select(.model.name == $model and .model.version == $version)]' \
  <<<"$models_json" 2>/dev/null)" ||
  fail "model availability response was invalid for $AZURE_LOCATION_DISPLAY_NAME; retry or check Azure model catalog"
[[ "$(jq 'length' <<<"$model_matches")" -gt 0 ]] ||
  fail "model $AZURE_OPENAI_MODEL version $AZURE_OPENAI_MODEL_VERSION is unavailable in $AZURE_LOCATION_DISPLAY_NAME"
jq -e --arg sku "$AZURE_OPENAI_DEPLOYMENT_SKU" \
  'any(.[]; any(.model.skus[]?; .name == $sku))' >/dev/null 2>&1 <<<"$model_matches" ||
  fail "model $AZURE_OPENAI_MODEL version $AZURE_OPENAI_MODEL_VERSION does not offer SKU $AZURE_OPENAI_DEPLOYMENT_SKU in $AZURE_LOCATION_DISPLAY_NAME"

usage_json="$(
  az cognitiveservices usage list --location "$AZURE_LOCATION" --output json 2>/dev/null
)" || fail "could not check model quota in $AZURE_LOCATION_DISPLAY_NAME; verify Microsoft.CognitiveServices access and retry"
quota_values="$(jq -er \
  --arg model "$AZURE_OPENAI_MODEL" \
  --arg sku "$AZURE_OPENAI_DEPLOYMENT_SKU" '
  def integral_quota_count:
    try tonumber catch empty
    | select(type == "number" and floor == .)
    | floor;
  [.[]
    | select(
        (.name.localizedValue // "" | contains($model))
        and (.name.localizedValue // "" | contains($sku))
      )
    | (.currentValue | integral_quota_count) as $current
    | (.limit | integral_quota_count) as $limit
    | [$current, $limit]]
  | if length == 1 then .[0] | @tsv else empty end
' <<<"$usage_json" 2>/dev/null)" ||
  fail "model quota was not reported for $AZURE_OPENAI_MODEL $AZURE_OPENAI_DEPLOYMENT_SKU in $AZURE_LOCATION_DISPLAY_NAME"
read -r model_current model_limit <<<"$quota_values"
if (( model_limit != -1 )); then
  model_remaining=$(( model_limit - model_current ))
  (( model_remaining >= AZURE_OPENAI_DEPLOYMENT_CAPACITY )) ||
    fail "model quota has $model_remaining capacity remaining, but $AZURE_OPENAI_DEPLOYMENT_CAPACITY is required"
fi

roles_json="$(
  az role assignment list --assignee "$principal" --scope "$subscription_scope" \
    --include-inherited --include-groups --output json 2>/dev/null
)" || fail 'could not check deployment authority; verify Microsoft.Authorization access and retry'
has_owner="$(jq -r 'any(.[];
  .roleDefinitionName == "Owner"
  and (.condition == null or .condition == "")
)' <<<"$roles_json" 2>/dev/null)" ||
  fail 'role assignment response was invalid; retry the deployment authority check'
has_contributor="$(jq -r 'any(.[]; .roleDefinitionName == "Contributor")' <<<"$roles_json")"
has_role_admin="$(jq -r 'any(.[];
  (
    .roleDefinitionName == "User Access Administrator"
    or .roleDefinitionName == "Role Based Access Control Administrator"
  )
  and (.condition == null or .condition == "")
)' <<<"$roles_json")"
[[ "$has_owner" == 'true' || ( "$has_contributor" == 'true' && "$has_role_admin" == 'true' ) ]] ||
  fail 'deployment authority requires Owner, or Contributor plus User Access Administrator or Role Based Access Control Administrator'

cat <<EOF
Azure readiness checks passed
subscription: $(redact_subscription "$expected_subscription")
location: $AZURE_LOCATION_DISPLAY_NAME ($AZURE_LOCATION)
model: $AZURE_OPENAI_MODEL
model version: $AZURE_OPENAI_MODEL_VERSION
deployment: $AZURE_OPENAI_DEPLOYMENT
SKU: $AZURE_OPENAI_DEPLOYMENT_SKU
capacity: $AZURE_OPENAI_DEPLOYMENT_CAPACITY
EOF
