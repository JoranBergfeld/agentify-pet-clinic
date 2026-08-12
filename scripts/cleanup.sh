#!/usr/bin/env bash
set -euo pipefail

foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd env get-value AZURE_LOCATION)"
resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"

azd down --force --purge

if az group exists --name "${resource_group}" | grep -q true; then
  printf 'Resource group still exists: %s\n' "${resource_group}" >&2
  exit 1
fi

deleted_id="$(az cognitiveservices account list-deleted \
  --query "[?name=='${foundry}' && location=='${location}'].id | [0]" -o tsv)"

if [[ -n "${deleted_id}" ]]; then
  az cognitiveservices account purge --name "${foundry}" --location "${location}" \
    --resource-group "${resource_group}"
fi

remaining="$(az cognitiveservices account list-deleted \
  --query "[?name=='${foundry}' && location=='${location}'] | length(@)" -o tsv)"
test "${remaining}" = "0"
