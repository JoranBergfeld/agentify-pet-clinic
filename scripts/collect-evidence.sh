#!/usr/bin/env bash
set -euo pipefail

resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"
web_app="$(azd env get-value SERVICE_WEB_NAME)"
foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd env get-value AZURE_LOCATION)"
web_id="$(az webapp show --resource-group "${resource_group}" --name "${web_app}" --query id -o tsv)"
foundry_id="$(az cognitiveservices account show --resource-group "${resource_group}" --name "${foundry}" --query id -o tsv)"
principal_id="$(az webapp identity show --resource-group "${resource_group}" --name "${web_app}" --query principalId -o tsv)"

printf '## Resources\n\n'
az resource list --resource-group "${resource_group}" \
  --query '[].{name:name,type:type,location:location}' -o table

printf '\n## App Service identity and Foundry roles\n\n'
printf 'principalId: %s\n' "${principal_id}"
az role assignment list --assignee-object-id "${principal_id}" --scope "${foundry_id}" \
  --query '[].{role:roleDefinitionName,scope:scope}' -o table

printf '\n## App Service memory\n\n'
az monitor metrics list --resource "${web_id}" --metric MemoryWorkingSet \
  --interval PT1M --aggregation Average Maximum -o json \
  | tee /tmp/wf15-memory.json \
  | jq '{timespan: .timespan, value: [.value[].timeseries[].data[] | select(.maximum != null)]}'

printf '\n## Foundry Models retail prices\n\n'
curl --fail --silent --show-error --get 'https://prices.azure.com/api/retail/prices' \
  --data-urlencode "\$filter=serviceName eq 'Foundry Models' and armRegionName eq '${location}'" \
  | jq --arg model 'gpt-4o-mini' \
      '{currencyCode, items: [.Items[] | select((.productName + " " + .skuName + " " + .meterName)
      | ascii_downcase | contains($model)) | {
        armRegionName, productName, skuName, meterName, unitPrice, unitOfMeasure
      }]}'

printf '\n## Recent application logs\n\n'
timeout 20s az webapp log tail --resource-group "${resource_group}" --name "${web_app}" \
  2>&1 | sed -n '1,200p' || true
