#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
azure_yaml="$root/azure.yaml"
main_bicep="$root/infra/main.bicep"
main_parameters="$root/infra/main.parameters.json"
resources_bicep="$root/infra/resources.bicep"
guide="$root/docs/workshop/azure-preflight-and-cleanup.md"
research="$root/docs/research/azure-permission-and-cost-envelope.md"
readme="$root/README.md"
workflow="$root/.github/workflows/validate-template.yml"

test -f "$azure_yaml"
test -f "$main_bicep"
test -f "$main_parameters"
test -f "$resources_bicep"
test -f "$guide"
test -f "$research"
test -f "$workflow"

grep -Fq 'docs/workshop/azure-preflight-and-cleanup.md' "$readme"
grep -Fq 'scripts/azure-readiness.sh' "$guide"
grep -Fq 'scripts/azure-preflight.sh' "$guide"
grep -Fq 'scripts/azure-cleanup.sh' "$guide"
grep -Fq 'Owner' "$guide"
grep -Fq 'Contributor' "$guide"
grep -Fq 'User Access Administrator' "$guide"
grep -Fq 'Role Based Access Control Administrator' "$guide"
grep -Fq 'At subscription scope, the deploying identity needs either:' "$guide"
grep -Fq '**Owner at subscription scope**' "$guide"
grep -Fq '**Contributor at subscription scope** plus either' "$guide"
grep -Fq '**User Access Administrator at subscription scope**' "$guide"
grep -Fq '**Role Based Access Control Administrator at subscription scope**' "$guide"
! grep -Fq 'roles are granted only at resource-group scope' "$guide"
grep -Fq 'research-stage envelope originally considered permissions' "$research"
grep -Fq 'early design option, not the permission' "$research"
grep -Fq 'contract for the implemented attendee path' "$research"
grep -Fq 'requires subscription-scope permissions' "$research"
! grep -Fq 'The simplest workshop requirement is **Owner on the isolated resource group**' "$research"
grep -Fq 'Microsoft.Resources' "$guide"
grep -Fq 'Microsoft.Web' "$guide"
grep -Fq 'Microsoft.CognitiveServices' "$guide"
grep -Fq 'Microsoft.Authorization' "$guide"
grep -Fq 'swedencentral' "$guide"
grep -Fq 'gpt-5.4-mini' "$guide"
grep -Fq '2026-03-17' "$guide"
grep -Fq 'GlobalStandard' "$guide"
grep -Fq 'WORKSHOP_AZURE_CLEANUP_DEADLINE' "$guide"
grep -Fq 'export WORKSHOP_AZURE_CLEANUP_DEADLINE=2026-08-15T17:00:00Z' "$guide"
grep -Fq 'actual UTC date' "$guide"
grep -Fq 'after your workshop ends' "$guide"
! grep -Eq 'date([[:space:]]+-[^[:space:]]+)*[[:space:]]+-d([[:space:]]|$)' "$guide"
grep -Fq 'Preflight intentionally leaves the environment running' "$guide"
grep -Fq '2026-08-12' "$guide"
grep -Fq '$0.75 per 1 million input tokens' "$guide"
grep -Fq '$4.50 per 1 million output tokens' "$guide"
grep -Fq 'Cost Management' "$guide"

python3 - "$workflow" <<'PY'
import re
import sys

workflow = open(sys.argv[1], encoding="utf-8").read()
assert re.search(
    r"(?m)^on:\n  pull_request:\n    branches: \[main\]\n  push:\n    branches: \[main\]$",
    workflow,
), "validate-template must run only for pull requests targeting main and pushes to main"
PY

python3 - "$azure_yaml" <<'PY'
import sys

# The azure-cli image this script runs in does not ship PyYAML, so parse the
# small, fully controlled azure.yaml with the standard library instead. Only
# plain nested mappings with scalar leaves are supported; anything else is a
# hard failure rather than a silent mis-parse.
manifest = {}
stack = [(-1, manifest)]
with open(sys.argv[1], encoding="utf-8") as manifest_file:
    for number, raw_line in enumerate(manifest_file, start=1):
        line = raw_line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        stripped = line.lstrip(" ")
        indent = len(line) - len(stripped)
        assert not stripped.startswith("-"), (
            f"azure.yaml line {number} uses an unsupported sequence: {line!r}"
        )
        assert ":" in stripped, (
            f"azure.yaml line {number} is not a mapping entry: {line!r}"
        )
        key, _, value = stripped.partition(":")
        while stack and indent <= stack[-1][0]:
            stack.pop()
        assert stack, f"azure.yaml line {number} is indented inconsistently: {line!r}"
        parent = stack[-1][1]
        assert isinstance(parent, dict), (
            f"azure.yaml line {number} nests under a scalar: {line!r}"
        )
        value = value.strip()
        if value:
            parent[key.strip()] = value
        else:
            child = {}
            parent[key.strip()] = child
            stack.append((indent, child))

expected_values = {
    ("name",): "agentic-engineering-workshop",
    ("metadata", "template"): "agentic-engineering-workshop@1.0.0",
    ("services", "web", "project"): ".",
    ("services", "web", "language"): "java",
    ("services", "web", "host"): "appservice",
    ("services", "web", "dist"): "target",
    ("services", "web", "hooks", "prepackage", "shell"): "sh",
    ("services", "web", "hooks", "prepackage", "run"): "./mvnw -q -DskipTests package",
    ("infra", "provider"): "bicep",
    ("infra", "path"): "infra",
}

for path, expected in expected_values.items():
    value = manifest
    try:
        for key in path:
            value = value[key]
    except (KeyError, TypeError):
        raise AssertionError(f"azure.yaml is missing {'.'.join(path)}") from None
    assert value == expected, (
        f"azure.yaml {'.'.join(path)} must be {expected!r}, got {value!r}"
    )
PY

python3 - "$main_parameters" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as parameters_file:
    parameters = json.load(parameters_file)["parameters"]

assert parameters["environmentName"]["value"] == "${AZURE_ENV_NAME}"
assert parameters["location"]["value"] == "${AZURE_LOCATION}"
PY

grep -Fqx "targetScope = 'subscription'" "$main_bicep"
grep -Fq '@minLength(1)' "$main_bicep"
grep -Fq 'param environmentName string' "$main_bicep"
grep -Fq 'param location string' "$main_bicep"
grep -Fq "param modelName string = 'gpt-5.4-mini'" "$main_bicep"
grep -Fq "param modelVersion string = '2026-03-17'" "$main_bicep"
grep -Fq "param modelDeploymentName string = 'gpt-5-4-mini'" "$main_bicep"
grep -Fq "param modelDeploymentSku string = 'GlobalStandard'" "$main_bicep"
grep -Fq '@minValue(1)' "$main_bicep"
grep -Fq 'param modelDeploymentCapacity int = 10' "$main_bicep"
grep -Fq "'azd-env-name': environmentName" "$main_bicep"
grep -Fq "purpose: 'agentic-engineering-workshop'" "$main_bicep"
grep -Fq "var resourceGroupName = 'rg-\${environmentName}'" "$main_bicep"
grep -Fq "module resources 'resources.bicep'" "$main_bicep"
grep -Fq 'modelName: modelName' "$main_bicep"
grep -Fq 'modelVersion: modelVersion' "$main_bicep"
grep -Fq 'modelDeploymentName: modelDeploymentName' "$main_bicep"
grep -Fq 'modelDeploymentSku: modelDeploymentSku' "$main_bicep"
grep -Fq 'modelDeploymentCapacity: modelDeploymentCapacity' "$main_bicep"
grep -Fqx 'output AZURE_LOCATION string = location' "$main_bicep"
grep -Fqx 'output AZURE_RESOURCE_GROUP_NAME string = resourceGroup.name' "$main_bicep"
grep -Fqx 'output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId' "$main_bicep"
grep -Fqx 'output AZURE_TENANT_ID string = tenant().tenantId' "$main_bicep"
grep -Fqx 'output SERVICE_WEB_NAME string = resources.outputs.webAppName' "$main_bicep"
grep -Fqx 'output WEB_APP_URL string = resources.outputs.webAppUrl' "$main_bicep"
grep -Fqx 'output AZURE_OPENAI_ACCOUNT_NAME string = resources.outputs.foundryName' "$main_bicep"
grep -Fqx 'output AZURE_OPENAI_ENDPOINT string = resources.outputs.openAiEndpoint' "$main_bicep"
grep -Fqx 'output AZURE_OPENAI_DEPLOYMENT string = modelDeploymentName' "$main_bicep"
grep -Fqx 'output AZURE_OPENAI_MODEL string = modelName' "$main_bicep"
grep -Fqx 'output AZURE_OPENAI_MODEL_VERSION string = modelVersion' "$main_bicep"
grep -Fqx 'output AZURE_OPENAI_DEPLOYMENT_SKU string = modelDeploymentSku' "$main_bicep"
grep -Fqx 'output AZURE_OPENAI_DEPLOYMENT_CAPACITY int = modelDeploymentCapacity' "$main_bicep"

grep -Fq "resource appServicePlan 'Microsoft.Web/serverfarms@" "$resources_bicep"
grep -Fq "name: 'B1'" "$resources_bicep"
grep -Fq 'reserved: true' "$resources_bicep"
grep -Fq 'asyncScalingEnabled: true' "$resources_bicep"
grep -Fq "resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01'" "$resources_bicep"
grep -Fq "kind: 'AIServices'" "$resources_bicep"
grep -Fq 'allowProjectManagement: true' "$resources_bicep"
grep -Fq 'customSubDomainName:' "$resources_bicep"
grep -Fq 'disableLocalAuth: true' "$resources_bicep"
grep -Fq "publicNetworkAccess: 'Enabled'" "$resources_bicep"
grep -Fq "resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@" "$resources_bicep"
grep -Fq 'name: modelName' "$resources_bicep"
grep -Fq 'version: modelVersion' "$resources_bicep"
grep -Fq 'name: modelDeploymentSku' "$resources_bicep"
grep -Fq 'capacity: modelDeploymentCapacity' "$resources_bicep"
grep -Fq "versionUpgradeOption: 'NoAutoUpgrade'" "$resources_bicep"
grep -Fq "resource web 'Microsoft.Web/sites@" "$resources_bicep"
grep -Fq "type: 'SystemAssigned'" "$resources_bicep"
grep -Fq "linuxFxVersion: 'JAVA|21-java21'" "$resources_bicep"
grep -Fq 'alwaysOn: true' "$resources_bicep"
grep -Fq "minTlsVersion: '1.2'" "$resources_bicep"
grep -Fq 'http20Enabled: true' "$resources_bicep"
grep -Fq "ftpsState: 'Disabled'" "$resources_bicep"
grep -Fq "name: 'AZURE_OPENAI_ENDPOINT'" "$resources_bicep"
grep -Fq "name: 'AZURE_OPENAI_MICROSOFT_FOUNDRY'" "$resources_bicep"
grep -Fq "value: 'true'" "$resources_bicep"
grep -Fq "name: 'AZURE_OPENAI_DEPLOYMENT'" "$resources_bicep"
grep -Fq 'value: modelDeploymentName' "$resources_bicep"
grep -Fq "name: 'AZURE_OPENAI_MODEL'" "$resources_bicep"
grep -Fq 'value: modelName' "$resources_bicep"
grep -Fq "value: '-Xms256m -Xmx1024m'" "$resources_bicep"
grep -Fq "value: '8080'" "$resources_bicep"
grep -Fq "'53ca6127-db72-4b80-b1b0-d745d6d5456d'" "$resources_bicep"
grep -Fq 'scope: foundry' "$resources_bicep"
grep -Fq 'guid(foundry.id, web.id, foundryUserRoleDefinitionId)' "$resources_bicep"

grep -Fqx 'output webAppName string = web.name' "$resources_bicep"
grep -Fqx "output webAppUrl string = 'https://\${web.properties.defaultHostName}'" "$resources_bicep"
grep -Fqx 'output foundryName string = foundry.name' "$resources_bicep"
grep -Fqx "output openAiEndpoint string = 'https://\${foundry.name}.openai.azure.com'" "$resources_bicep"

! grep -Rqi 'wayfinder-15\|prototype' "$azure_yaml" "$root/infra"

az bicep build --file "$main_bicep" --stdout >/dev/null
echo "workshop Azure infrastructure contract passed"
