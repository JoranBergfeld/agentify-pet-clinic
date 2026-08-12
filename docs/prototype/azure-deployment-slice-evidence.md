# Azure deployment slice evidence

Date: 2026-08-12

## Result

The canonical Spring PetClinic application plus Spring AI 2.0 works on Azure
App Service B1 with a system-assigned managed identity and a projectless
Microsoft Foundry resource. The validated baseline is:

- App Service B1 on Linux with Java 21
- `Microsoft.CognitiveServices/accounts` with `kind: AIServices`
- local authentication disabled and project management enabled
- `gpt-5.4-mini` version `2026-03-17`
- Global Standard deployment named `gpt-5-4-mini`
- Foundry User assigned to the web app identity at Foundry resource scope

Data Zone Standard was not required.

## Environment

The disposable environment used the approved attendee-like subscription and
the resource group `rg-wf15-20260812192712`.

East US could not create a Basic App Service plan because that subscription's
regional Basic quota was `0`. A second available subscription had the same
East US constraint. Sweden Central reported Basic capacity as available and
successfully provisioned the B1 plan. Free F1 capacity did not demonstrate B1
availability because Free and Basic use separate quota buckets.

The initially planned `gpt-4o-mini` deployment was rejected for new deployment
because the model was deprecating. The current deployable replacement selected
for the prototype was `gpt-5.4-mini`.

## Provisioning

The fresh deployment used:

```text
azd up
```

Provisioned resources:

```text
foundry-lncikdqsyr4sw    Microsoft.CognitiveServices/accounts
plan-lncikdqsyr4sw       Microsoft.Web/serverfarms
petclinic-lncikdqsyr4sw  Microsoft.Web/sites
```

The final Bicep configuration provisioned the model and role assignment
idempotently with:

```text
model:      gpt-5.4-mini
version:    2026-03-17
deployment: gpt-5-4-mini
sku:        GlobalStandard
capacity:   10
role:       Foundry User
scope:      Foundry account resource
```

Re-running `azd provision --no-prompt` completed successfully in 1 minute
44 seconds and retained the same resource topology.

## Managed identity and Spring AI

Spring AI 2.0 created a `DefaultAzureCredential` bearer-token client and
requested the expected Cognitive Services scope:

```text
https://cognitiveservices.azure.com/.default
```

The deployed app settings contained the Foundry endpoint, deployment name,
model name, and `microsoft-foundry=true`; no API key was configured.

Spring AI 2.0's OpenAI SDK uses the chat request's `model` value as the Azure
deployment path. Supplying the Foundry model name caused:

```text
POST .../openai/deployments/gpt-5.4-mini/chat/completions
404 DeploymentNotFound
```

Setting `spring.ai.openai.model` and `spring.ai.openai.chat.model` to the
deployment name changed the path to `gpt-5-4-mini` and inference succeeded.
`AZURE_OPENAI_MODEL` remains the actual model name for infrastructure and
pricing evidence.

## RBAC

The resource-scoped Cognitive Services OpenAI User role was temporarily tested
while diagnosing inference. After the deployment-path defect was corrected, it
was removed and Foundry User was assigned alone.

With only Foundry User at the Foundry account scope, all deployed smoke queries
succeeded. A Cognitive Services OpenAI User compatibility fallback is therefore
not required for this projectless OpenAI-compatible endpoint.

## Runtime and redeployment

The B1 plan has one Linux worker and 1.75 GiB memory. During repeated startups,
redeployments, health checks, and chat/tool traffic, Azure Monitor reported:

```text
maximum MemoryWorkingSet: 522,815,487 bytes (498.6 MiB)
latest MemoryWorkingSet:  482,226,176 bytes (459.9 MiB)
```

The application consistently reached `UP`. Direct JAR redeployment with
`az webapp deploy` completed in approximately 2 to 3 minutes; the final run
reported the site started after 127 seconds. The same health and assistant
smoke suite passed after redeployment.

Representative results:

- George Franklin returned Leo and the recorded PetClinic details.
- The two Davis owners were both returned and the user was asked to clarify.
- The medication question was declined without treatment advice.

## Retail prices

The Retail Prices API query used:

```text
serviceName eq 'Foundry Models'
productName eq 'Azure OpenAI GPT5'
armRegionName eq 'swedencentral'
```

For `gpt-5.4-mini` Global Standard, the applicable USD consumption meters were:

| Meter | Unit price | Unit |
| --- | ---: | --- |
| `5.4 mini Inp Gl` | $0.75 | 1M tokens |
| `5.4 mini Opt Gl` | $4.50 | 1M tokens |

The Retail Prices API abbreviates Global as `Gl` and output as `Opt`; searching
for the literal model identifier `gpt-5.4-mini` does not match those meter
names.

## Cleanup

`azd down --force --purge` deleted the resource group and explicitly reported
purging the Cognitive Services account in 2 minutes 26 seconds.

Independent checks after the command completed returned:

```text
resourceGroupExists=false
softDeletedFoundryAccounts=0
```

No explicit follow-up `az cognitiveservices account purge` was required because
this version of `azd down --purge` removed the soft-deleted Foundry account.

## Recommendation

Use Sweden Central as the tested workshop baseline when the subscription has no
East US Basic quota. Keep the region configurable and preflight the Basic quota
before provisioning.

Use the current `gpt-5.4-mini` model with a separately named
`gpt-5-4-mini` deployment. Configure Spring AI's request model with the
deployment name, retain the actual model name separately for provisioning and
pricing, and assign Foundry User at resource scope.
