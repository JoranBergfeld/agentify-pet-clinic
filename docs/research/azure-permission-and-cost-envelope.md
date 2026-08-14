# Azure Permission and Cost Envelope

Research for [Document the Azure permission and cost envelope](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/12), verified against official Azure and Spring AI sources on 2026-08-11.

Prices are a dated planning snapshot in USD, not a quote. The attendee-facing document must refresh prices and model availability before each workshop delivery.

## Recommended envelope

- **Hosting:** Azure App Service Basic B1 for Linux, Java SE.
- **Model:** `gpt-4o-mini` deployed in a Microsoft Foundry resource.
- **Deployment type:** start with `GlobalStandard`; use `DataZoneStandard` only for a deliberate data-residency requirement.
- **Benchmark region:** East US for the published price example.
- **Regional policy:** parameterize the template and preflight the chosen region, model availability, and quota. Sweden Central is a reasonable European candidate; East US remains the benchmark and fallback.
- **Isolation:** one resource group and one `azd` environment per attendee.
- **Authentication:** prefer App Service managed identity, but validate Spring AI 2.0 integration and resource-scoped Foundry RBAC empirically before publishing. If it is unreliable, use an App Service Key Vault reference and include the additional resource and permissions.

## Resources created

| Resource | Billing behavior |
| --- | --- |
| Resource group | No charge |
| App Service Basic B1 Linux plan | Continuous hourly charge while present |
| Java App Service | Included in the plan charge |
| System-assigned managed identity | No charge |
| Foundry resource (`Microsoft.CognitiveServices/accounts`, `kind: AIServices`) | No base charge for the selected pay-as-you-go deployment |
| `gpt-4o-mini` model deployment | Charged per input and output token |
| Key Vault, if authentication fallback is needed | Low operation-based charge; adds configuration and permissions |

The starter should omit Azure AI Search, Foundry projects, persistent chat storage, Log Analytics, and Application Insights unless a later decision demonstrates they are necessary.

## Required permissions

This research-stage envelope originally considered permissions limited to an
isolated resource group. That was an early design option, not the permission
contract for the implemented attendee path. The implemented workshop path
requires subscription-scope permissions because `infra/main.bicep` creates the
resource group at subscription scope and readiness validates deployment
authority at that scope.

- **Owner at subscription scope**; or
- **Contributor at subscription scope** plus **User Access Administrator at
  subscription scope** or **Role Based Access Control Administrator at
  subscription scope**.

Contributor alone cannot create role assignments.

Current Foundry guidance prefers the **Foundry User** role for new Foundry scenarios. Because this workshop uses no Foundry project and calls the retained OpenAI-compatible endpoint, the deployment prototype must verify whether Foundry User at resource scope is sufficient. **Cognitive Services OpenAI User** remains the compatibility fallback documented for OpenAI features.

Resource providers:

- `Microsoft.Resources`
- `Microsoft.Web`
- `Microsoft.CognitiveServices` for the Foundry resource and model deployment
- `Microsoft.Authorization` for role assignments
- `Microsoft.KeyVault` only if the fallback authentication path is selected

Provider registration also operates at subscription scope. Resource-group-only
permissions do not qualify for the implemented readiness and deployment path.

## Price snapshot

The official Azure Retail Prices API returned the following East US Data Zone retail meters under `serviceName = Foundry Models` on 2026-08-11:

- App Service Basic B1 Linux: **$0.017 per hour**
- `gpt-4o-mini` 2024-07-18 Data Zone input: **$0.000165 per 1,000 tokens**
- `gpt-4o-mini` 2024-07-18 Data Zone output: **$0.000660 per 1,000 tokens**

These values are a dated Data Zone benchmark, not the guaranteed price of the recommended `GlobalStandard` deployment. Refresh the selected deployment type before publishing.

Planning assumption per attendee:

- 25,000 input tokens
- 15,000 output tokens
- Estimated model cost: about **$0.014**

| Deployment window | App Service | Model use | Planning total |
| --- | ---: | ---: | ---: |
| 4 hours | $0.068 | $0.014 | about **$0.08** |
| 24 hours | $0.408 | $0.014 | about **$0.42** |
| 7 days | $2.856 | $0.028, assuming double workshop use | about **$2.88** |

Round attendee-facing estimates upward and state that region, taxes, price changes, quota, retries, and accidental continued deployment change the actual bill.

## Cost and quota controls

- Keep the Bicep resource set minimal.
- Set a low model deployment capacity suitable for the exercise.
- Require a successful quota and model-availability check during Preflight.
- Use globally unique resource names so soft-deleted accounts do not block retries.
- Recommend a resource-group budget alert where the attendee's subscription permits it.
- Display the deployment timestamp and cleanup deadline in the workshop instructions.
- Treat cleanup evidence as part of the Acceptance gate.

New, trial, or organization-managed subscriptions may have no usable Azure OpenAI quota or may block model deployment. Preflight must prove the actual deployment, not merely account access.

## Cleanup

Run:

```bash
azd down --force --purge
```

Then verify whether the Foundry resource remains soft-deleted:

```bash
az cognitiveservices account list-deleted
```

If it remains, purge it explicitly using the account name, original resource group, and location:

```bash
az cognitiveservices account purge \
  --name <account-name> \
  --resource-group <resource-group> \
  --location <location>
```

Post-cleanup evidence:

1. The resource group no longer exists.
2. No App Service plan or web app remains.
3. The Foundry resource is absent from active resources.
4. The account is absent from the deleted-accounts list.
5. The model quota is released.
6. Cost Management shows no continuing resource charge after billing data catches up.

## Validation required before publishing

[Validate the Azure deployment slice](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/15) must prove:

- Spring AI 2.0 can authenticate to the Foundry resource through its OpenAI-compatible endpoint.
- `kind: AIServices`, `allowProjectManagement: true`, and the selected model deployment provision correctly.
- The selected resource-scoped Foundry role authorizes inference, with the compatibility role documented if required.
- The B1 memory envelope runs PetClinic plus Spring AI reliably.
- `azd up`, redeployment, and the configured model work in a fresh attendee-like subscription.
- `azd down --force --purge` plus any explicit Cognitive Services purge leaves no chargeable or quota-holding resources.

If managed identity cannot be wired reliably, the prototype must validate the Key Vault reference fallback and this cost envelope must be updated.

## Required attendee-facing artifact

The Workshop Blueprint must require a dedicated Azure setup document containing:

1. Prerequisite accounts, roles, providers, and quota.
2. Region and model checks.
3. Resources created by `azd up`.
4. Current price date, formulas, and rounded scenarios.
5. Cost controls.
6. Cleanup commands and evidence checklist.
7. Troubleshooting boundaries and escalation path.

## Primary sources

- [Azure Retail Prices API](https://prices.azure.com/api/retail/prices)
- [Azure built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Azure AI and machine-learning roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/ai-machine-learning)
- [Azure resource providers](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types)
- [Managed identities for App Service](https://learn.microsoft.com/en-us/azure/app-service/overview-managed-identity)
- [Azure OpenAI quota management](https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/quota)
- [Azure Cognitive Services account purge CLI](https://learn.microsoft.com/en-us/cli/azure/cognitiveservices/account)
- [Spring AI Azure OpenAI migration note](https://docs.spring.io/spring-ai/reference/api/chat/azure-openai-chat.html)
- [Spring AI OpenAI chat client](https://docs.spring.io/spring-ai/reference/api/chat/openai-chat.html)
- [`azd down` Cognitive Services purge limitation](https://github.com/Azure/azure-dev/issues/1941)
