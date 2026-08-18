# Azure Preflight and Cleanup

Use this guide before the workshop to prove that your Azure subscription can
host the workshop application. **Preflight is not workshop exercise time.** It
performs a real deployment and verifies it so the live workshop can begin from
a known-good Inherited System. Preflight intentionally leaves the environment
running; run cleanup only after the workshop or at the recorded deadline.

## Prove partner review access

The Workshop Host provides pair assignments before Preflight. Each Driver
grants their assigned partner collaborator access to their private workshop
repository:

```bash
gh api --method PUT repos/<driver>/<repository>/collaborators/<partner> -f permission=push
```

Replace the placeholders with GitHub logins and the repository name. The
partner must accept the invitation before the proof step.

Prove access rather than trusting the grant:

1. The Driver creates a temporary repository issue named
   `Preflight partner access proof`.
2. The partner opens that private repository and posts a throwaway comment on
   the issue.
3. The Driver confirms the comment is visible, then the partner deletes their
   throwaway comment.
4. The Driver closes the temporary issue.

If the partner cannot open the repository or comment, correct the invitation,
account, or organization policy and repeat the proof before the workshop.
Do not defer this failure to live exercise time.

## Accounts and local tools

You need:

- a GitHub account with the workshop repository cloned locally;
- an Azure account with access to a subscription that permits App Service and
  Microsoft Foundry model deployments;
- Bash, Git, `curl`, `jq`, and `date`;
- Azure CLI (`az`) and Azure Developer CLI (`azd`); and
- JDK 21. The repository's Maven wrapper packages the application during
  `azd up`.

Authenticate both Azure clients:

```bash
az login
azd auth login
```

## Azure permissions and providers

At subscription scope, the deploying identity needs either:

- **Owner at subscription scope**; or
- **Contributor at subscription scope** plus either
  **User Access Administrator at subscription scope** or
  **Role Based Access Control Administrator at subscription scope**.

Contributor alone cannot create the managed-identity role assignment. If these
qualifying roles are unavailable at subscription scope, this workshop path
cannot pass readiness or deploy its subscription-scoped Bicep.

These providers must be registered:

- `Microsoft.Resources`
- `Microsoft.Web`
- `Microsoft.CognitiveServices`
- `Microsoft.Authorization`

An administrator must complete provider registration and qualifying
subscription-scope role grants before the attendee runs readiness.

## Tested deployment envelope

The tested defaults are:

| Setting | Default |
| --- | --- |
| Region | Sweden Central (`swedencentral`) |
| App Service | Linux Basic B1, Java 21 |
| Model | `gpt-5.4-mini` |
| Model version | `2026-03-17` |
| Deployment name | `gpt-5-4-mini` |
| Deployment SKU | `GlobalStandard` |
| Deployment capacity | `10` |

The scripts read these deliberate shell overrides:

```bash
export AZURE_LOCATION=swedencentral
export AZURE_LOCATION_DISPLAY_NAME='Sweden Central'
export AZURE_OPENAI_MODEL=gpt-5.4-mini
export AZURE_OPENAI_MODEL_VERSION=2026-03-17
export AZURE_OPENAI_DEPLOYMENT=gpt-5-4-mini
export AZURE_OPENAI_DEPLOYMENT_SKU=GlobalStandard
export AZURE_OPENAI_DEPLOYMENT_CAPACITY=10
```

Do not change only one side of this contract. `AZURE_LOCATION` must also be set
in the `azd` environment. Model, version, deployment, SKU, and capacity are
pinned in `infra/main.bicep`; a different model envelope requires a coordinated
template change from the workshop owner, not an attendee-only shell override.

## Create the environment and check readiness

Create one unique `azd` environment per attendee, explicitly select the current
Azure CLI subscription and region, and record a UTC cleanup deadline:

```bash
environment_name="workshop-preflight-$(date -u +%Y%m%d%H%M%S)"
azd env new "$environment_name"
azd env set AZURE_SUBSCRIPTION_ID "$(az account show --query id -o tsv)"
azd env set AZURE_LOCATION swedencentral
export WORKSHOP_AZURE_CLEANUP_DEADLINE=2026-08-15T17:00:00Z
```

The deadline value above is an example. Replace it with the actual UTC date and
time after your workshop ends, using ISO-8601 format (`YYYY-MM-DDTHH:MM:SSZ`).
The deadline is required by Preflight and is recorded in evidence; it does not
automatically delete resources.

Run the read-only readiness gate:

```bash
scripts/azure-readiness.sh
```

It checks tools, both logins, the selected subscription, providers, Basic B1
availability and quota, model/version/SKU availability, model capacity, and
deployment authority. A non-zero exit is not a warning: resolve the named gate
before provisioning.

## Run Preflight

```bash
scripts/azure-preflight.sh
```

This command runs readiness and then exactly `azd up --no-prompt`. It waits for
`/actuator/health` to report `UP`, checks the resource topology, model
deployment, managed identity, Foundry User assignment, and required app
settings, then writes redacted evidence under:

```text
.workshop-evidence/preflight-<UTC timestamp>.md
```

Keep that file locally. It records the Git revision, redacted subscription,
region, model envelope, provisioning states, identity and role facts, health,
deployment time, cleanup deadline, and PASS gates. It intentionally omits live
resource names, principal IDs, credentials, and reusable URLs.

Preflight creates:

- resource group `rg-<azd-environment>`;
- Linux Basic B1 App Service plan;
- Java 21 web app with a system-assigned managed identity;
- projectless Microsoft Foundry `AIServices` account;
- `gpt-5.4-mini` model deployment; and
- Foundry User assignment at the Foundry resource scope.

Preflight intentionally leaves the environment running for the workshop.

## Cost observation and controls

The price observation below is dated **2026-08-12**. For the Sweden Central
`gpt-5.4-mini` Global Standard meters observed during prototype validation:

- **$0.75 per 1 million input tokens**
- **$4.50 per 1 million output tokens**

For example, 25,000 input plus 15,000 output tokens is
`(25,000 / 1,000,000 × $0.75) + (15,000 / 1,000,000 × $4.50) = $0.08625`,
or about **$0.09** for model usage. App Service B1 is a separate continuous
charge while the plan exists.

Refresh prices before every delivery. Query the public Azure Retail Prices API
for the selected region, then inspect all returned pages and retain rows whose
product, SKU, or meter identifies `gpt-5.4-mini` and input or output:

```bash
curl --fail --silent --show-error --get \
  'https://prices.azure.com/api/retail/prices' \
  --data-urlencode "\$filter=serviceName eq 'Foundry Models' and armRegionName eq 'swedencentral'" \
  | jq -r '.Items[] | [.armRegionName, .productName, .skuName, .meterName, .retailPrice, .unitOfMeasure, .currencyCode] | @tsv'
```

If `NextPageLink` is non-null, fetch each following page before selecting
meters. Confirm the deployment type and token unit, convert the meter price to
one million tokens, record the query date, and round planning estimates up.
Retail prices are not a quote: currency, agreement discounts, taxes, regional
availability, retries, token volume, pricing changes, and an environment left
running all affect the bill.

Controls are deliberately simple:

- one isolated resource group and `azd` environment per attendee;
- minimal resources, Basic B1, and model capacity `10`;
- fail-closed quota and availability checks;
- no Search, database, Log Analytics, or Application Insights resources;
- a written cleanup deadline and prompt cleanup; and
- an Azure budget alert when the subscription permits one.

## Cleanup and evidence

Run cleanup from the same repository and `azd` environment:

```bash
scripts/azure-cleanup.sh
```

Cleanup must know the exact Foundry account name so it can inspect and purge
soft-deleted records. If the `azd` environment no longer contains
`AZURE_OPENAI_ACCOUNT_NAME`, recover the name from retained deployment output
or the Azure portal and supply it explicitly:

```bash
WORKSHOP_AZURE_FOUNDRY_NAME='<exact-account-name>' scripts/azure-cleanup.sh
```

Do not guess the name. The script may recover it from an existing resource
group after partial provisioning. If `azd`, that discovery, and the override
cannot provide a safe account name, cleanup stops before `azd down` and writes
no PASS evidence.

The script captures required values, runs exactly `azd down --force --purge`,
verifies that the resource group and active App Service/Foundry resources are
absent, discovers and explicitly purges a soft-deleted Foundry account when
necessary, and waits for deletion propagation. Success writes:

```text
.workshop-evidence/cleanup-<UTC timestamp>.md
```

The cleanup evidence must show PASS for resource-group absence, App Service
plan and web-app absence, active Foundry and model-deployment absence, and
deleted Foundry account absence. A failed command or remaining resource means
cleanup is incomplete; keep the output and escalate rather than treating the
deadline as met.

## Troubleshooting ownership

| Failure | Owner and action |
| --- | --- |
| Missing tool, login, wrong active subscription, or invalid local environment | Attendee corrects the local setup and reruns readiness. |
| Provider registration, role grant, policy denial, zero quota, or deletion permission | Subscription administrator resolves it. |
| Tested model/version/SKU unavailable or a coordinated override is needed | Workshop owner selects, validates, and publishes a new envelope. |
| Azure reports temporary provisioning, role, health, or deletion propagation | Wait, then rerun the same script; the scripts already bound health and cleanup retries. |
| Cleanup reports a residual or soft-deleted resource | Attendee preserves output and asks the subscription administrator to remove it; escalate persistent platform failures through Azure support. |

Do not bypass a failed readiness, Preflight, or cleanup gate manually without
capturing the corrected evidence.

## Later Cost Management confirmation

Azure Cost Management is eventually consistent. After billing data catches up,
filter costs by the workshop subscription, resource group, and deployment
window. Confirm that no charge continues after the cleanup timestamp and retain
that observation with the local cleanup evidence. This later human check
complements, but does not replace, the immediate resource-absence checks.
