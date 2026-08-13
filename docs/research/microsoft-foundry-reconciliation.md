# Microsoft Foundry Reconciliation

Research for [Reconcile the Clinic Assistant with current Microsoft Foundry](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/16), verified against current Microsoft Foundry, Azure, `azd`, and Spring AI sources on 2026-08-11.

## Correction

Use **Microsoft Foundry** as the platform and resource boundary.

For this workshop, provision:

- A Foundry resource using `Microsoft.CognitiveServices/accounts` with `kind: AIServices`.
- `allowProjectManagement: true`.
- A model deployment under `Microsoft.CognitiveServices/accounts/deployments`.
- The existing OpenAI-compatible endpoint at `https://<resource-name>.openai.azure.com`.

Spring AI 2.0 continues to use `spring-ai-starter-model-openai`. No Foundry-specific Spring AI starter is required.

## Current product model

| Concept | Current meaning |
| --- | --- |
| Microsoft Foundry | Platform umbrella for agents, models, tools, governance, and projects |
| Foundry resource | Top-level Azure resource and security boundary |
| Foundry project | Optional organizational and access scope inside a Foundry resource |
| Foundry Models | Current product and billing category for model inference |
| Azure OpenAI | Supported OpenAI model/API compatibility surface inside Foundry, not the preferred new resource boundary |

The legacy `kind: OpenAI` resource remains supported and can be upgraded, but new infrastructure should use `kind: AIServices`. Existing `.openai.azure.com` endpoints and OpenAI API compatibility are preserved.

## Resource topology

A Foundry project is not required for the Clinic Assistant. The application uses ordinary model inference and local Spring AI tool calling; it does not use Foundry Agent Service, Responses API state, files, evaluations, or project-scoped agent assets.

Recommended Bicep shape:

```bicep
resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    disableLocalAuth: true
  }
}
```

The model deployment remains a `Microsoft.CognitiveServices/accounts/deployments` child resource. For most workloads, current Foundry guidance recommends `GlobalStandard`; use `DataZoneStandard` only when data-zone residency is a deliberate requirement.

## Spring AI integration

Spring AI documentation states that from 2.0.0-M5 onward, its unified OpenAI chat client should access OpenAI models deployed in Azure or Microsoft Foundry.

- Dependency: `spring-ai-starter-model-openai`
- Endpoint: `https://<foundry-resource-name>.openai.azure.com`
- Tool calling: unchanged through `@Tool` or `MethodToolCallback`
- Model option: the deployment name
- Managed identity: requires custom OpenAI client authentication wiring and must be proven by prototype

There is no current Microsoft Foundry-specific Spring AI starter.

## Authentication and RBAC

Current Foundry guidance recommends **Foundry User** for Foundry scenarios and warns against assigning roles whose names start with Cognitive Services.

The Clinic Assistant has one ambiguity that documentation alone does not settle: it uses a Foundry resource without a project and calls the retained OpenAI-compatible endpoint. The upgrade documentation confirms that **Cognitive Services OpenAI User** still works for OpenAI features after upgrading, while the Foundry RBAC documentation recommends **Foundry User** for new Foundry access.

[Validate the Azure deployment slice](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/15) must determine the least-privilege assignment that works for resource-scoped inference:

1. Prefer **Foundry User** on the Foundry resource.
2. If that role does not authorize the OpenAI-compatible inference endpoint without a project, use **Cognitive Services OpenAI User** as the documented compatibility role.
3. Keep `disableLocalAuth: true` only after managed identity succeeds end to end.

## Pricing and quota

The Azure Retail Prices API now reports model meters under:

```text
serviceName = Foundry Models
```

The product name for OpenAI models may still appear as `Azure OpenAI`. Queries filtering on the old service name return no results.

The existing dated Data Zone prices remain visible under the new service name, but the workshop should start with `GlobalStandard` unless data residency requires `DataZoneStandard`. The attendee-facing cost document must query the chosen deployment type immediately before each delivery.

## `azd` and cleanup

- Application host remains `appservice`.
- Infrastructure provider remains `bicep`.
- Do not use the legacy `microsoft.foundry` host.
- A project host such as `azure.ai.project` is unnecessary because this slice has no Foundry project.
- Soft delete and explicit purge continue to use `az cognitiveservices account list-deleted` and `az cognitiveservices account purge` because the ARM resource provider remains `Microsoft.CognitiveServices`.

## Required corrections

- Replace “Azure OpenAI resource” with “Foundry resource” in current architecture and infrastructure decisions.
- Provision `kind: AIServices` with `allowProjectManagement: true`.
- Keep the OpenAI-compatible endpoint and Spring AI unified OpenAI starter.
- Make `GlobalStandard` the default deployment-type candidate; retain Data Zone as an explicit residency choice.
- Query pricing with `serviceName eq 'Foundry Models'`.
- Reopen the exact managed-identity role as a prototype question rather than claiming a role prematurely.
- Update the Azure deployment prototype to validate Foundry Bicep, managed identity, RBAC, memory, deployment, and purge behavior.

## Primary sources

- [What is Microsoft Foundry?](https://learn.microsoft.com/en-us/azure/foundry/what-is-foundry)
- [Upgrade Azure OpenAI to Microsoft Foundry](https://learn.microsoft.com/en-us/azure/foundry/how-to/upgrade-azure-openai)
- [Deploy a Foundry resource with Bicep](https://learn.microsoft.com/en-us/azure/foundry/how-to/create-resource-template)
- [Foundry role-based access control](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry)
- [Foundry model deployment types](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/deployment-types)
- [Foundry model deployments](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/create-model-deployments)
- [Azure Developer CLI schema](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/azd-schema)
- [Spring AI Azure migration note](https://docs.spring.io/spring-ai/reference/api/chat/azure-openai-chat.html)
- [Spring AI OpenAI chat client](https://docs.spring.io/spring-ai/reference/api/chat/openai-chat.html)
- [Azure Retail Prices API](https://prices.azure.com/api/retail/prices)
- [Recover or purge deleted AI resources](https://learn.microsoft.com/en-us/azure/ai-services/recover-purge-resources)
