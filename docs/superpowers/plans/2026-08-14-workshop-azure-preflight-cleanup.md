# Workshop Azure, Preflight, and Cleanup Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a workshop-owned Azure lifecycle that proves attendee readiness, deploys and verifies the clean Inherited System, captures redacted evidence, reliably purges the isolated environment, and supports reference-only deployed Clinic Assistant smoke evidence.

**Architecture:** `main` owns one parameterized `azd`/Bicep topology and three focused commands: readiness, Preflight verification/evidence, and cleanup. A shared shell library provides strict input, Azure query, retry, redaction, and evidence primitives; command tests replace Azure tools with deterministic stubs. The reference branch merges the shared path and adds only the Clinic Assistant HTTP smoke scenarios.

**Tech Stack:** Bash, Azure CLI, Azure Developer CLI, Bicep, `curl`, `jq`, Maven, GitHub Actions.

---

## File map

### Shared on `main`

- `azure.yaml` — packages the current branch's Maven application and deploys it to App Service.
- `infra/main.bicep` — creates the isolated resource group and publishes `azd` outputs.
- `infra/resources.bicep` — owns App Service, Foundry, model deployment, managed identity, app settings, and RBAC.
- `scripts/lib/workshop-azure.sh` — strict shared functions for configuration, Azure queries, retries, safe output, and evidence.
- `scripts/azure-readiness.sh` — read-only local, authentication, permission, provider, region, quota, and model gates.
- `scripts/azure-preflight.sh` — invokes readiness, deploys, verifies, and writes redacted Preflight evidence.
- `scripts/azure-cleanup.sh` — tears down, purges soft-delete when needed, verifies absence, and writes cleanup evidence.
- `scripts/test-workshop-azure-infra.sh` — validates the static infrastructure contract.
- `scripts/test-azure-readiness.sh` — fixture-driven readiness tests.
- `scripts/test-azure-preflight.sh` — fixture-driven deployment, verification, timeout, and evidence tests.
- `scripts/test-azure-cleanup.sh` — fixture-driven purge, retry, timeout, and residual-resource tests.
- `scripts/fixtures/workshop-azure/fake-command.sh` — dispatches deterministic fake `az`, `azd`, `curl`, and `git` behavior from fixture files.
- `docs/workshop/azure-preflight-and-cleanup.md` — attendee prerequisites, commands, cost envelope, evidence, troubleshooting, and cleanup.
- `README.md` — links the attendee to the Azure guide.
- `.gitignore` — excludes generated `azd` state and attendee evidence.
- `scripts/validate-template-baseline.sh` — rejects generated Azure/evidence state and reference-only smoke assets.
- `scripts/test-template-baseline-validator.sh` — regression tests for the added template boundary.
- `.github/workflows/validate-template.yml` — runs all offline Azure-path tests and Bicep compilation.

### Reference-only after merging `main`

- `scripts/azure-reference-smoke.sh` — cookie-preserving deployed UI scenarios for known data, ambiguity, unsupported/write, medical, and reset behavior.
- `scripts/test-azure-reference-smoke.sh` — deterministic HTTP fixture tests for the smoke assertions.
- `scripts/validate-reference.sh` — runs the reference smoke command only when `REFERENCE_DEPLOYED_SMOKE=1`.
- `docs/reference/clinic-assistant-evidence.md` — records the refreshed deployed evidence without live identifiers.

## Task 1: Add the permanent Azure infrastructure contract

**Files:**
- Create: `azure.yaml`
- Create: `infra/main.bicep`
- Create: `infra/resources.bicep`
- Create: `scripts/test-workshop-azure-infra.sh`

- [ ] **Step 1: Write the failing infrastructure contract test**

Create `scripts/test-workshop-azure-infra.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test -f "$root/azure.yaml"
test -f "$root/infra/main.bicep"
test -f "$root/infra/resources.bicep"

grep -Fq 'host: appservice' "$root/azure.yaml"
grep -Fq 'run: ./mvnw -q -DskipTests package' "$root/azure.yaml"
grep -Fq "targetScope = 'subscription'" "$root/infra/main.bicep"
grep -Fq "param modelName string = 'gpt-5.4-mini'" "$root/infra/main.bicep"
grep -Fq "param modelVersion string = '2026-03-17'" "$root/infra/main.bicep"
grep -Fq "param modelDeploymentName string = 'gpt-5-4-mini'" "$root/infra/main.bicep"
grep -Fq "param modelDeploymentSku string = 'GlobalStandard'" "$root/infra/main.bicep"
grep -Fq "param modelDeploymentCapacity int = 10" "$root/infra/main.bicep"
grep -Fq "name: 'B1'" "$root/infra/resources.bicep"
grep -Fq "linuxFxVersion: 'JAVA|21-java21'" "$root/infra/resources.bicep"
grep -Fq "kind: 'AIServices'" "$root/infra/resources.bicep"
grep -Fq 'allowProjectManagement: true' "$root/infra/resources.bicep"
grep -Fq 'disableLocalAuth: true' "$root/infra/resources.bicep"
grep -Fq "'53ca6127-db72-4b80-b1b0-d745d6d5456d'" "$root/infra/resources.bicep"
grep -Fq "name: 'AZURE_OPENAI_DEPLOYMENT'" "$root/infra/resources.bicep"
grep -Fq "value: modelDeploymentName" "$root/infra/resources.bicep"
grep -Fq "name: 'AZURE_OPENAI_MODEL'" "$root/infra/resources.bicep"
grep -Fq "value: modelName" "$root/infra/resources.bicep"
! grep -Rqi 'wayfinder-15\|prototype' "$root/azure.yaml" "$root/infra"

az bicep build --file "$root/infra/main.bicep" --stdout >/dev/null
echo "workshop Azure infrastructure contract passed"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
chmod +x scripts/test-workshop-azure-infra.sh
scripts/test-workshop-azure-infra.sh
```

Expected: FAIL because `azure.yaml` and `infra/` do not exist.

- [ ] **Step 3: Add the `azd` service definition**

Create `azure.yaml`:

```yaml
name: agentic-engineering-workshop
metadata:
  template: agentic-engineering-workshop@1.0.0
services:
  web:
    project: .
    language: java
    host: appservice
    dist: target
    hooks:
      prepackage:
        shell: sh
        run: ./mvnw -q -DskipTests package
infra:
  provider: bicep
  path: infra
```

- [ ] **Step 4: Add subscription-scoped parameters and outputs**

Create `infra/main.bicep` by adapting the validated prototype, with these exact public parameters:

```bicep
targetScope = 'subscription'

@minLength(1)
param environmentName string

param location string
param modelName string = 'gpt-5.4-mini'
param modelVersion string = '2026-03-17'
param modelDeploymentName string = 'gpt-5-4-mini'
param modelDeploymentSku string = 'GlobalStandard'

@minValue(1)
param modelDeploymentCapacity int = 10

param tags object = {
  'azd-env-name': environmentName
  purpose: 'agentic-engineering-workshop'
}

var resourceGroupName = 'rg-${environmentName}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'workshop-resources'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
    modelName: modelName
    modelVersion: modelVersion
    modelDeploymentName: modelDeploymentName
    modelDeploymentSku: modelDeploymentSku
    modelDeploymentCapacity: modelDeploymentCapacity
    tags: tags
  }
}

output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP_NAME string = resourceGroup.name
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_WEB_NAME string = resources.outputs.webAppName
output WEB_APP_URL string = resources.outputs.webAppUrl
output AZURE_OPENAI_ACCOUNT_NAME string = resources.outputs.foundryName
output AZURE_OPENAI_ENDPOINT string = resources.outputs.openAiEndpoint
output AZURE_OPENAI_DEPLOYMENT string = modelDeploymentName
output AZURE_OPENAI_MODEL string = modelName
output AZURE_OPENAI_MODEL_VERSION string = modelVersion
output AZURE_OPENAI_DEPLOYMENT_SKU string = modelDeploymentSku
output AZURE_OPENAI_DEPLOYMENT_CAPACITY int = modelDeploymentCapacity
```

- [ ] **Step 5: Add the validated resource topology**

Create `infra/resources.bicep` from the prototype but accept every model value as a parameter, retain B1/Java 21/managed identity/Foundry User, and output only the web app and Foundry values consumed by scripts. Use `dependsOn: [modelDeployment]` for the web app and `guid(foundry.id, web.id, foundryUserRoleDefinitionId)` for the role assignment.

- [ ] **Step 6: Run the infrastructure contract**

Run:

```bash
scripts/test-workshop-azure-infra.sh
```

Expected: PASS with `workshop Azure infrastructure contract passed`.

- [ ] **Step 7: Commit the infrastructure**

```bash
git add azure.yaml infra scripts/test-workshop-azure-infra.sh
git commit -m "feat: add workshop Azure infrastructure"
```

## Task 2: Build the shared shell test harness and readiness command

**Files:**
- Create: `scripts/fixtures/workshop-azure/fake-command.sh`
- Create: `scripts/lib/workshop-azure.sh`
- Create: `scripts/azure-readiness.sh`
- Create: `scripts/test-azure-readiness.sh`

- [ ] **Step 1: Write readiness tests with command fixtures**

Create `scripts/test-azure-readiness.sh` with cases that prepend a fixture `bin`
directory to `PATH`, symlink `az`, `azd`, `curl`, `jq`, and `git` to
`fake-command.sh`, and set `WORKSHOP_AZURE_FIXTURE_DIR` per case.

The success fixture must return:

```text
az account show --query id -o tsv
11111111-1111-1111-1111-111111111111
az ad signed-in-user show --query id -o tsv
22222222-2222-2222-2222-222222222222
az provider show --namespace Microsoft.Resources --query registrationState -o tsv
Registered
az provider show --namespace Microsoft.Web --query registrationState -o tsv
Registered
az provider show --namespace Microsoft.CognitiveServices --query registrationState -o tsv
Registered
az provider show --namespace Microsoft.Authorization --query registrationState -o tsv
Registered
az appservice list-locations --sku B1 --linux-workers-enabled --query [?name=='Sweden Central'].name | [0] -o tsv
Sweden Central
az rest --method get --url <web-usage-url> --query <basic-limit-query> -o tsv
-1
az cognitiveservices model list --location swedencentral --query <model-query> -o json
{"name":"gpt-5.4-mini","version":"2026-03-17","skus":["GlobalStandard"]}
az cognitiveservices usage list --location swedencentral --query <quota-query> -o tsv
1000
az role assignment list --assignee 22222222-2222-2222-2222-222222222222 \
  --scope /subscriptions/11111111-1111-1111-1111-111111111111 \
  --include-inherited --include-groups -o json
[{"roleDefinitionName":"Owner","scope":"/subscriptions/11111111-1111-1111-1111-111111111111"}]
azd auth login --check-status
exit 0
```

Assert the success output ends with:

```text
Azure readiness passed for subscription 1111...1111 in swedencentral
```

Add independent failure cases for:

- missing `azd`;
- failed `az account show`;
- failed `azd auth login --check-status`;
- an unregistered provider;
- region missing from `az appservice list-locations`;
- Basic usage limit `0`;
- model/version missing;
- requested SKU missing;
- Cognitive Services quota less than requested capacity; and
- neither Owner nor Contributor plus User Access Administrator/RBAC Administrator at subscription scope.

- [ ] **Step 2: Run the readiness tests to verify they fail**

Run:

```bash
chmod +x scripts/test-azure-readiness.sh
scripts/test-azure-readiness.sh
```

Expected: FAIL because the shared library and readiness command do not exist.

- [ ] **Step 3: Implement the fixture dispatcher**

Create `scripts/fixtures/workshop-azure/fake-command.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

fixture_dir="${WORKSHOP_AZURE_FIXTURE_DIR:?}"
command_name="$(basename "$0")"
key="$(printf '%s %s' "$command_name" "$*" | sha256sum | cut -d' ' -f1)"
response="$fixture_dir/$key.stdout"
status="$fixture_dir/$key.status"

printf '%s %s\n' "$command_name" "$*" >>"${WORKSHOP_AZURE_COMMAND_LOG:?}"
test ! -f "$response" || cat "$response"
test ! -f "$status" || exit "$(cat "$status")"
```

The test helper writes responses by hashing the exact command line through the
same expression. This makes unexpected Azure calls fail visibly because they
have no fixture response and are still recorded in the command log.

- [ ] **Step 4: Implement shared configuration and failure primitives**

Create `scripts/lib/workshop-azure.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKSHOP_AZURE_LOCATION="${WORKSHOP_AZURE_LOCATION:-swedencentral}"
WORKSHOP_AZURE_LOCATION_DISPLAY="${WORKSHOP_AZURE_LOCATION_DISPLAY:-Sweden Central}"
WORKSHOP_AZURE_MODEL="${WORKSHOP_AZURE_MODEL:-gpt-5.4-mini}"
WORKSHOP_AZURE_MODEL_VERSION="${WORKSHOP_AZURE_MODEL_VERSION:-2026-03-17}"
WORKSHOP_AZURE_DEPLOYMENT="${WORKSHOP_AZURE_DEPLOYMENT:-gpt-5-4-mini}"
WORKSHOP_AZURE_DEPLOYMENT_SKU="${WORKSHOP_AZURE_DEPLOYMENT_SKU:-GlobalStandard}"
WORKSHOP_AZURE_DEPLOYMENT_CAPACITY="${WORKSHOP_AZURE_DEPLOYMENT_CAPACITY:-10}"
WORKSHOP_AZURE_RETRY_SECONDS="${WORKSHOP_AZURE_RETRY_SECONDS:-10}"
WORKSHOP_AZURE_MAX_ATTEMPTS="${WORKSHOP_AZURE_MAX_ATTEMPTS:-30}"

fail() {
  printf 'workshop Azure path failed: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

redact_subscription() {
  local value="$1"
  printf '%s...%s\n' "${value:0:4}" "${value: -4}"
}

require_nonempty() {
  local label="$1" value="$2"
  test -n "$value" || fail "$label was empty"
}

retry_until() {
  local description="$1"
  shift
  local attempt
  for ((attempt = 1; attempt <= WORKSHOP_AZURE_MAX_ATTEMPTS; attempt++)); do
    "$@" && return 0
    test "$attempt" -eq "$WORKSHOP_AZURE_MAX_ATTEMPTS" || sleep "$WORKSHOP_AZURE_RETRY_SECONDS"
  done
  fail "$description did not succeed after $WORKSHOP_AZURE_MAX_ATTEMPTS attempts"
}
```

- [ ] **Step 5: Implement readiness gates**

Create `scripts/azure-readiness.sh` that sources the library and performs the
checks in this order:

1. `require_command az`, `azd`, `curl`, `jq`, and `git`.
2. `az account show --query id -o tsv`.
3. `azd auth login --check-status`.
4. Provider registration for `Microsoft.Resources`, `Microsoft.Web`,
   `Microsoft.CognitiveServices`, and `Microsoft.Authorization`.
5. B1 Linux region presence through `az appservice list-locations`.
6. Subscription Basic quota through:

```bash
az rest --method get \
  --url "https://management.azure.com/subscriptions/${subscription_id}/providers/Microsoft.Web/locations/${WORKSHOP_AZURE_LOCATION}/usages?api-version=2024-04-01" \
  --query "value[?name.localizedValue=='Basic'].limit | [0]" -o tsv
```

Treat `-1` as unlimited and reject `0`.

7. Exact model/version/SKU through:

```bash
az cognitiveservices model list \
  --location "$WORKSHOP_AZURE_LOCATION" \
  --query "[?model.name=='${WORKSHOP_AZURE_MODEL}' && model.version=='${WORKSHOP_AZURE_MODEL_VERSION}' && contains(model.skus[].name, '${WORKSHOP_AZURE_DEPLOYMENT_SKU}')].{name:model.name,version:model.version,skus:model.skus[].name} | [0]" \
  -o json
```

8. Quota through `az cognitiveservices usage list`, selecting the localized
   name containing the model and SKU, then require
   `limit - currentValue >= WORKSHOP_AZURE_DEPLOYMENT_CAPACITY`.
9. Subscription-level authority. Accept `Owner`, or accept both `Contributor`
   and one of `User Access Administrator` / `Role Based Access Control
   Administrator`, from `az role assignment list --scope <subscription-scope>
   --include-inherited --include-groups`.

Print only the redacted subscription, region, model/version, SKU, and capacity
on success.

- [ ] **Step 6: Run readiness tests**

Run:

```bash
chmod +x scripts/fixtures/workshop-azure/fake-command.sh scripts/azure-readiness.sh
scripts/test-azure-readiness.sh
```

Expected: PASS with `Azure readiness tests passed`.

- [ ] **Step 7: Commit readiness**

```bash
git add scripts/lib scripts/fixtures scripts/azure-readiness.sh scripts/test-azure-readiness.sh
git commit -m "feat: add Azure readiness gates"
```

## Task 3: Add deployment verification and redacted Preflight evidence

**Files:**
- Create: `scripts/azure-preflight.sh`
- Create: `scripts/test-azure-preflight.sh`

- [ ] **Step 1: Write failing Preflight tests**

Create `scripts/test-azure-preflight.sh` using the fixture dispatcher. Cover:

- success calls readiness before `azd up`;
- `azd env get-value` obtains resource group, web app, URL, Foundry account,
  model, version, deployment, SKU, and capacity;
- health retries until `{"status":"UP"}`;
- resource list contains exactly the expected App Service plan, web app,
  Foundry account, deployment, and role assignment evidence;
- evidence contains the repository revision and redacted subscription but not
  the full subscription, principal id, account name, web app name, URL, token,
  or `.azure` content;
- `azd up` failure stops verification;
- health timeout fails;
- missing Foundry User assignment fails; and
- a missing required app setting fails.

Use a temporary `WORKSHOP_AZURE_EVIDENCE_DIR` and assert the created file name
matches `preflight-YYYYMMDDTHHMMSSZ.md`.

- [ ] **Step 2: Run Preflight tests to verify they fail**

Run:

```bash
chmod +x scripts/test-azure-preflight.sh
scripts/test-azure-preflight.sh
```

Expected: FAIL because `scripts/azure-preflight.sh` does not exist.

- [ ] **Step 3: Implement deployment and bounded health verification**

Create `scripts/azure-preflight.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/lib/workshop-azure.sh"

evidence_dir="${WORKSHOP_AZURE_EVIDENCE_DIR:-$root/.workshop-evidence}"
cleanup_deadline="${WORKSHOP_AZURE_CLEANUP_DEADLINE:?set WORKSHOP_AZURE_CLEANUP_DEADLINE}"

"$root/scripts/azure-readiness.sh"
azd up --no-prompt

resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"
web_app="$(azd env get-value SERVICE_WEB_NAME)"
app_url="$(azd env get-value WEB_APP_URL)"
foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
subscription_id="$(az account show --query id -o tsv)"

health_is_up() {
  test "$(curl --fail --silent --show-error "$app_url/actuator/health" | jq -r .status)" = "UP"
}

retry_until "application health" health_is_up
```

Then query and validate:

- expected resource types from `az resource list --resource-group`;
- model name/version/SKU/capacity from
  `az cognitiveservices account deployment show`;
- web app `principalId`;
- Foundry User at the Foundry resource scope;
- app-setting names `AZURE_OPENAI_ENDPOINT`,
  `AZURE_OPENAI_MICROSOFT_FOUNDRY`, `AZURE_OPENAI_DEPLOYMENT`,
  `AZURE_OPENAI_MODEL`, `JAVA_OPTS`, and `WEBSITES_PORT`.

- [ ] **Step 4: Write Markdown evidence from safe fields only**

Use `git rev-parse HEAD`, `date -u`, `redact_subscription`, the configured
model values, resource *types*, role name, health status, and cleanup deadline.
Do not interpolate resource names, URL, principal id, tenant id, or raw Azure
JSON into the evidence file.

The evidence verdict table must contain these rows:

```markdown
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
```

- [ ] **Step 5: Run Preflight tests**

Run:

```bash
chmod +x scripts/azure-preflight.sh
scripts/test-azure-preflight.sh
```

Expected: PASS with `Azure Preflight tests passed`.

- [ ] **Step 6: Commit Preflight**

```bash
git add scripts/azure-preflight.sh scripts/test-azure-preflight.sh
git commit -m "feat: add Azure Preflight evidence"
```

## Task 4: Add verified cleanup and purge evidence

**Files:**
- Create: `scripts/azure-cleanup.sh`
- Create: `scripts/test-azure-cleanup.sh`

- [ ] **Step 1: Write failing cleanup tests**

Create `scripts/test-azure-cleanup.sh` with fixtures for:

- `azd down --force --purge` removes the group and no deleted account remains;
- a deleted Foundry account triggers one explicit
  `az cognitiveservices account purge`;
- soft-delete propagation succeeds after two retries;
- resource group remains and fails;
- active App Service or Foundry resource remains and fails;
- purge command fails and preserves the failure;
- deleted account remains through the retry limit and fails; and
- evidence excludes resource names and records PASS only after all absence
  checks pass.

- [ ] **Step 2: Run cleanup tests to verify they fail**

Run:

```bash
chmod +x scripts/test-azure-cleanup.sh
scripts/test-azure-cleanup.sh
```

Expected: FAIL because `scripts/azure-cleanup.sh` does not exist.

- [ ] **Step 3: Implement teardown using values captured before deletion**

Create `scripts/azure-cleanup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/lib/workshop-azure.sh"

evidence_dir="${WORKSHOP_AZURE_EVIDENCE_DIR:-$root/.workshop-evidence}"
foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd env get-value AZURE_LOCATION)"
resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"
subscription_id="$(az account show --query id -o tsv)"

azd down --force --purge

test "$(az group exists --name "$resource_group")" = "false" \
  || fail "resource group still exists after azd down"
```

Query active resources by the captured resource group and reject any returned
App Service plan, web app, Cognitive Services account, or deployment.

- [ ] **Step 4: Implement soft-delete purge and bounded propagation**

Add:

```bash
deleted_account_id() {
  az cognitiveservices account list-deleted \
    --query "[?name=='${foundry}' && location=='${location}'].id | [0]" -o tsv
}

deleted_id="$(deleted_account_id)"
if test -n "$deleted_id"; then
  az cognitiveservices account purge \
    --name "$foundry" \
    --resource-group "$resource_group" \
    --location "$location"
fi

soft_delete_absent() {
  test -z "$(deleted_account_id)"
}

retry_until "Foundry soft-delete purge" soft_delete_absent
```

- [ ] **Step 5: Write cleanup evidence**

Write a timestamped Markdown file containing redacted subscription, region,
environment name, whether explicit purge was required, final absence verdicts,
and this exact follow-up:

```markdown
Cost Management is eventually consistent. After billing data catches up,
confirm that this environment has no continuing resource charge.
```

- [ ] **Step 6: Run cleanup tests**

Run:

```bash
chmod +x scripts/azure-cleanup.sh
scripts/test-azure-cleanup.sh
```

Expected: PASS with `Azure cleanup tests passed`.

- [ ] **Step 7: Commit cleanup**

```bash
git add scripts/azure-cleanup.sh scripts/test-azure-cleanup.sh
git commit -m "feat: verify Azure cleanup and purge"
```

## Task 5: Enforce template safety and run offline validation in CI

**Files:**
- Modify: `.gitignore`
- Modify: `scripts/validate-template-baseline.sh`
- Modify: `scripts/test-template-baseline-validator.sh`
- Modify: `.github/workflows/validate-template.yml`

- [ ] **Step 1: Extend failing template-boundary tests**

In `scripts/test-template-baseline-validator.sh`, add fixtures that must fail
for:

```text
.workshop-evidence/preflight-example.md
.workshop-evidence/cleanup-example.md
scripts/azure-reference-smoke.sh
```

Also add a clean fixture containing `azure.yaml`, `infra/main.bicep`,
`infra/resources.bicep`, and the three shared Azure commands to prove these
workshop-owned assets are allowed on `main`.

- [ ] **Step 2: Run the validator tests to verify they fail**

Run:

```bash
scripts/test-template-baseline-validator.sh
```

Expected: FAIL because evidence and reference smoke are not yet rejected.

- [ ] **Step 3: Ignore generated state**

Append to `.gitignore`:

```gitignore

### Workshop Azure Path ###
.azure/
.workshop-evidence/
```

- [ ] **Step 4: Extend the template validator**

In `scripts/validate-template-baseline.sh`:

- reject `.workshop-evidence/`;
- reject `scripts/azure-reference-smoke.sh` and
  `scripts/test-azure-reference-smoke.sh`;
- continue allowing `.azure/.gitignore` only if the repository needs that
  sentinel; and
- keep the existing `.git` and `.worktrees` pruning.

Use the existing `fail "template baseline invalid: ..."` contract.

- [ ] **Step 5: Add offline Azure tests to template CI**

In `.github/workflows/validate-template.yml`, after the baseline validator,
add:

```yaml
      - name: Install Azure CLI
        run: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
      - name: Test workshop Azure infrastructure
        run: scripts/test-workshop-azure-infra.sh
      - name: Test Azure readiness
        run: scripts/test-azure-readiness.sh
      - name: Test Azure Preflight
        run: scripts/test-azure-preflight.sh
      - name: Test Azure cleanup
        run: scripts/test-azure-cleanup.sh
```

Do not authenticate or provision in pull-request CI.

- [ ] **Step 6: Run all offline validation**

Run:

```bash
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
scripts/test-workshop-azure-infra.sh
scripts/test-azure-readiness.sh
scripts/test-azure-preflight.sh
scripts/test-azure-cleanup.sh
./mvnw -q test
```

Expected: all commands pass.

- [ ] **Step 7: Commit safety and CI**

```bash
git add .gitignore scripts/validate-template-baseline.sh \
  scripts/test-template-baseline-validator.sh .github/workflows/validate-template.yml
git commit -m "ci: validate workshop Azure path"
```

## Task 6: Publish attendee Azure, cost, Preflight, and cleanup guidance

**Files:**
- Create: `docs/workshop/azure-preflight-and-cleanup.md`
- Modify: `README.md`

- [ ] **Step 1: Write a documentation contract check**

Add these assertions to `scripts/test-workshop-azure-infra.sh`:

```bash
guide="$root/docs/workshop/azure-preflight-and-cleanup.md"
test -f "$guide"
grep -Fq 'scripts/azure-readiness.sh' "$guide"
grep -Fq 'scripts/azure-preflight.sh' "$guide"
grep -Fq 'scripts/azure-cleanup.sh' "$guide"
grep -Fq 'Contributor' "$guide"
grep -Fq 'User Access Administrator' "$guide"
grep -Fq 'Microsoft.Web' "$guide"
grep -Fq 'Microsoft.CognitiveServices' "$guide"
grep -Fq 'gpt-5.4-mini' "$guide"
grep -Fq '2026-03-17' "$guide"
grep -Fq 'GlobalStandard' "$guide"
grep -Fq '2026-08-12' "$guide"
grep -Fq 'Cost Management' "$guide"
grep -Fq 'WORKSHOP_AZURE_CLEANUP_DEADLINE' "$guide"
```

- [ ] **Step 2: Run the contract to verify it fails**

Run:

```bash
scripts/test-workshop-azure-infra.sh
```

Expected: FAIL because the guide does not exist.

- [ ] **Step 3: Write the attendee guide**

Create `docs/workshop/azure-preflight-and-cleanup.md` with these sections:

1. Purpose and the distinction between Preflight and live workshop work.
2. Required accounts and local tools.
3. Permissions: Owner, or Contributor plus User Access Administrator/RBAC
   Administrator.
4. Required providers.
5. Tested defaults and deliberate environment overrides.
6. Readiness command and failure ownership.
7. `azd env new`, subscription/location settings, cleanup deadline, and
   `scripts/azure-preflight.sh`.
8. Resources created and evidence location.
9. Price observation dated 2026-08-12, the prototype's Sweden Central
   `gpt-5.4-mini` prices, the Retail Prices API refresh command, and rounded
   caveats.
10. Cost controls and cleanup deadline.
11. `scripts/azure-cleanup.sh` and evidence interpretation.
12. Troubleshooting boundaries: local correction, administrator, workshop
    owner, transient propagation, residual-resource escalation.
13. Later Cost Management confirmation.

Explicitly state that Preflight intentionally leaves the environment running.

- [ ] **Step 4: Link the guide from README**

Replace “follow the workshop Preflight instructions when they are published”
with a link to `docs/workshop/azure-preflight-and-cleanup.md`.

- [ ] **Step 5: Run documentation and baseline checks**

Run:

```bash
scripts/test-workshop-azure-infra.sh
scripts/validate-template-baseline.sh
```

Expected: both pass.

- [ ] **Step 6: Commit guidance**

```bash
git add docs/workshop/azure-preflight-and-cleanup.md README.md \
  scripts/test-workshop-azure-infra.sh
git commit -m "docs: publish workshop Azure Preflight guide"
```

## Task 7: Run a fresh live attendee-like lifecycle

**Files:**
- Modify: `docs/workshop/azure-preflight-and-cleanup.md` only if the live result changes a command or documented fact.
- Create locally only: `.workshop-evidence/preflight-*.md`
- Create locally only: `.workshop-evidence/cleanup-*.md`

- [ ] **Step 1: Create an isolated environment**

Run:

```bash
environment_name="workshop-preflight-$(date -u +%Y%m%d%H%M%S)"
azd env new "$environment_name"
azd env set AZURE_SUBSCRIPTION_ID "$(az account show --query id -o tsv)"
azd env set AZURE_LOCATION swedencentral
export WORKSHOP_AZURE_CLEANUP_DEADLINE="$(date -u -d '+24 hours' +%Y-%m-%dT%H:%M:%SZ)"
```

Expected: a new ignored `.azure/<environment>/` directory.

- [ ] **Step 2: Run readiness**

Run:

```bash
scripts/azure-readiness.sh
```

Expected: PASS with a redacted subscription and the selected model envelope.

- [ ] **Step 3: Run Preflight**

Run:

```bash
scripts/azure-preflight.sh
```

Expected: `azd up` succeeds, `/actuator/health` is `UP`, all infrastructure
gates pass, and a redacted Preflight evidence file is created.

- [ ] **Step 4: Inspect the evidence redaction**

Run:

```bash
grep -RFn "$(az account show --query id -o tsv)" .workshop-evidence && exit 1 || true
grep -RFn "$(azd env get-value SERVICE_WEB_NAME)" .workshop-evidence && exit 1 || true
grep -RFn "$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)" .workshop-evidence && exit 1 || true
```

Expected: no matches.

- [ ] **Step 5: Run cleanup**

Run:

```bash
scripts/azure-cleanup.sh
```

Expected: resource group absent, active resources absent, deleted Foundry
account absent, and cleanup evidence PASS.

- [ ] **Step 6: Re-run all offline checks after live findings**

Run:

```bash
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
scripts/test-workshop-azure-infra.sh
scripts/test-azure-readiness.sh
scripts/test-azure-preflight.sh
scripts/test-azure-cleanup.sh
./mvnw -q test
git status --short
```

Expected: tests pass; only deliberate documentation corrections, if any, are
tracked. `.azure/` and `.workshop-evidence/` remain ignored.

- [ ] **Step 7: Commit any evidence-driven corrections**

If no tracked correction was required, do not create an empty commit. Otherwise:

```bash
git add docs/workshop/azure-preflight-and-cleanup.md scripts
git commit -m "fix: align Azure path with live validation"
```

## Task 8: Add the reference-only deployed smoke extension

**Files:**
- Create on `reference/clinic-assistant`: `scripts/azure-reference-smoke.sh`
- Create on `reference/clinic-assistant`: `scripts/test-azure-reference-smoke.sh`
- Modify on `reference/clinic-assistant`: `scripts/validate-reference.sh`
- Modify on `reference/clinic-assistant`: `docs/reference/clinic-assistant-evidence.md`

- [ ] **Step 1: Merge the completed shared path into the reference branch**

Use the execution session's isolated reference worktree, then:

```bash
git switch reference/clinic-assistant
git merge main
```

Expected: the reference branch contains all shared Azure assets and remains a
descendant of `main`.

- [ ] **Step 2: Write failing deployed-smoke fixture tests**

Create `scripts/test-azure-reference-smoke.sh` with a fake `curl` that preserves
a cookie-jar path and returns scenario-specific HTML. Assert the smoke command:

- uses one cookie jar per run;
- GETs `/clinic-assistant` before posting;
- posts URL-encoded `message`;
- follows the redirect and checks rendered transcript content;
- proves an owner/pet answer contains `George Franklin` and `Leo`;
- proves a pet/Visit answer contains `Leo` and a recorded Visit detail;
- proves a veterinarian answer contains at least one known veterinarian and
  specialty;
- proves the Davis ambiguity answer contains both matching owners or explicit
  clarification language;
- proves attempted write contains read-only/refusal language;
- proves medical advice contains veterinarian/refusal language;
- posts `/clinic-assistant/reset`; and
- proves the reset page contains no prior prompt.

- [ ] **Step 3: Run the smoke tests to verify they fail**

Run:

```bash
chmod +x scripts/test-azure-reference-smoke.sh
scripts/test-azure-reference-smoke.sh
```

Expected: FAIL because `scripts/azure-reference-smoke.sh` does not exist.

- [ ] **Step 4: Implement the reference HTTP smoke command**

Create `scripts/azure-reference-smoke.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/lib/workshop-azure.sh"

app_url="${WEB_APP_URL:-$(azd env get-value WEB_APP_URL)}"
cookie_jar="$(mktemp)"
page="$(mktemp)"
trap 'rm -f "$cookie_jar" "$page"' EXIT

fetch_page() {
  curl --fail --silent --show-error \
    --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    "$app_url/clinic-assistant" >"$page"
}

ask() {
  local prompt="$1"
  curl --fail --silent --show-error --location \
    --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    --data-urlencode "message=$prompt" \
    "$app_url/clinic-assistant" >"$page"
}

assert_page_matches() {
  local description="$1" pattern="$2"
  grep -Eiq "$pattern" "$page" || fail "$description was not visible in deployed transcript"
}
```

Implement the seven prompts and assertions described by the tests. For reset,
store a unique prompt marker, POST reset, GET the page, and fail if that marker
remains.

- [ ] **Step 5: Run deterministic smoke tests**

Run:

```bash
chmod +x scripts/azure-reference-smoke.sh
scripts/test-azure-reference-smoke.sh
```

Expected: PASS with `Azure reference smoke tests passed`.

- [ ] **Step 6: Gate live reference smoke in the reference validator**

At the end of `scripts/validate-reference.sh`, before the success line, add:

```bash
if test "${REFERENCE_DEPLOYED_SMOKE:-0}" = "1"; then
  "$root/scripts/azure-reference-smoke.sh"
fi
```

Extend `scripts/test-reference-validator.sh` so the default fixture proves no
live smoke is called and an opt-in fixture proves exactly one smoke call.

- [ ] **Step 7: Deploy the reference branch and run live smoke**

Create a fresh `azd` environment or reuse the still-valid Task 7 environment
only if it was deliberately not cleaned. Then run:

```bash
export WORKSHOP_AZURE_CLEANUP_DEADLINE="$(date -u -d '+4 hours' +%Y-%m-%dT%H:%M:%SZ)"
scripts/azure-preflight.sh
REFERENCE_DEPLOYED_SMOKE=1 scripts/validate-reference.sh
scripts/azure-cleanup.sh
```

Expected: local reference validation, all deployed scenarios, and cleanup pass.

- [ ] **Step 8: Refresh reference evidence**

Update `docs/reference/clinic-assistant-evidence.md` with:

- validated `main` and reference revisions;
- the shared Preflight and cleanup evidence verdicts;
- the deployed scenario names and PASS/FAIL result;
- model/version/SKU and region;
- no live URL, resource name, subscription id, principal id, credentials, or
  raw model transcript.

- [ ] **Step 9: Commit the reference extension**

```bash
git add scripts/azure-reference-smoke.sh scripts/test-azure-reference-smoke.sh \
  scripts/validate-reference.sh scripts/test-reference-validator.sh \
  docs/reference/clinic-assistant-evidence.md
git commit -m "feat: add deployed Clinic Assistant smoke path"
```

## Task 9: Complete end-to-end validation and resolve the Wayfinder ticket

**Files:**
- Modify if needed: only files directly implicated by validation failures.
- Tracker: `Build the workshop Azure, Preflight, and cleanup path`
- Tracker map: `Build the Agentic Engineering Principles workshop`

- [ ] **Step 1: Validate `main`**

Run on `main`:

```bash
scripts/test-template-baseline-validator.sh
scripts/validate-template-baseline.sh
scripts/test-workshop-azure-infra.sh
scripts/test-azure-readiness.sh
scripts/test-azure-preflight.sh
scripts/test-azure-cleanup.sh
./mvnw -q test
```

Expected: all pass.

- [ ] **Step 2: Validate `reference/clinic-assistant`**

Run on the reference branch:

```bash
scripts/test-reference-validator.sh
scripts/test-azure-reference-smoke.sh
scripts/validate-reference.sh
```

Expected: all offline validation passes. The latest live smoke and cleanup
results are recorded in redacted reference evidence.

- [ ] **Step 3: Verify repository cleanliness and branch topology**

Run:

```bash
git status --short
git merge-base --is-ancestor main reference/clinic-assistant
```

Expected: clean working trees and successful ancestry check.

- [ ] **Step 4: Post the ticket resolution**

Comment on
[Build the workshop Azure, Preflight, and cleanup path](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/21)
with:

```markdown
Implemented the Workshop Azure Path.

- `main` now owns parameterized B1/App Service + projectless Foundry infrastructure, read-only readiness gates, real deployment Preflight, redacted evidence, and verified cleanup with soft-delete purge fallback.
- The attendee guide records permissions, providers, tested model defaults, dated cost methodology, cost controls, commands, troubleshooting ownership, and delayed Cost Management confirmation.
- Offline fixture suites cover readiness, deployment verification, evidence redaction, cleanup, purge propagation, residual-resource failure, and template leakage boundaries.
- `reference/clinic-assistant` reuses the shared lifecycle and adds deployed smoke evidence for known data, ambiguity, unsupported/write, medical, and reset behavior.
- Fresh attendee-like deployment and cleanup completed with no active or soft-deleted workshop resource remaining.

[Design](https://github.com/JoranBergfeld/agentify-pet-clinic/blob/main/docs/superpowers/specs/2026-08-14-workshop-azure-preflight-cleanup-design.md) · [Implementation plan](https://github.com/JoranBergfeld/agentify-pet-clinic/blob/main/docs/superpowers/plans/2026-08-14-workshop-azure-preflight-cleanup.md)
```

- [ ] **Step 5: Close the ticket and update the map**

Close the named ticket, then append this named context pointer to the map's
**Decisions so far**:

```markdown
- [Build the workshop Azure, Preflight, and cleanup path](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/21) — Provide one attendee-operated Workshop Azure Path with fail-closed readiness, real deployment Preflight, redacted evidence, verified purge cleanup, and reference-only deployed Clinic Assistant smoke scenarios.
```

- [ ] **Step 6: Commit no tracker-only changes**

Tracker resolution does not require a repository commit. Confirm the ticket is
closed and the map contains the named context pointer.
