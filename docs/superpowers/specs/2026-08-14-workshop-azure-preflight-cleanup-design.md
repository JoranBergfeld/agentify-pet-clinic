# Workshop Azure, Preflight, and Cleanup Path Design

## Purpose

Convert the validated Azure deployment prototype into the Workshop Azure Path:
workshop-owned assets that each attendee can use to prove Azure readiness,
deploy and reach the clean Inherited System, preserve redacted Preflight
evidence, and remove every workshop resource and soft-delete record afterward.

The path must remain reusable by the maintained Clinic Assistant reference
implementation without placing reference-only code, scenarios, answers, or
evidence on the attendee template branch.

## Ownership boundary

The clean template `main` branch owns the shared lifecycle:

- an `azd` service definition;
- subscription-scoped Bicep for the isolated resource group and resources;
- readiness, deployment verification, evidence, and cleanup commands;
- tests for the shell behavior and infrastructure contract; and
- attendee-facing Azure, cost, Preflight, troubleshooting, and cleanup
  guidance.

The shared path deploys the application present on the current branch. On
`main`, that is canonical Spring PetClinic without Clinic Assistant code or
Spring AI application dependencies.

After `main` is merged into `reference/clinic-assistant`, the reference branch
adds only Clinic Assistant-specific deployed smoke scenarios and expected
behavioral assertions. It reuses the same provisioning, verification, evidence,
and cleanup lifecycle. Reference smoke behavior must never flow back to
`main`.

## Azure architecture

The permanent Bicep adapts the topology validated by the disposable prototype:

- one uniquely named resource group and `azd` environment per attendee;
- Azure App Service Basic B1 for Linux using Java 21;
- a system-assigned managed identity on the web app;
- a projectless `Microsoft.CognitiveServices/accounts` resource with
  `kind: AIServices`, project management enabled, local authentication
  disabled, and public network access enabled;
- a Global Standard model deployment;
- Foundry User assigned to the web app identity at Foundry resource scope; and
- app settings for the Foundry OpenAI-compatible endpoint, deployment name,
  actual model name, Java memory, and web port.

The validated defaults are:

- model: `gpt-5.4-mini`;
- model version: `2026-03-17`;
- deployment name: `gpt-5-4-mini`;
- deployment SKU: `GlobalStandard`; and
- deployment capacity: `10`.

Region, model, model version, deployment name, SKU, and capacity are explicit
parameters. Defaults are pinned evidence, not silent fallbacks. If a default is
unavailable, the readiness command fails and reports the unsupported parameter;
the attendee or workshop owner must deliberately select and record an
alternative.

Infrastructure names and tags describe the Workshop Azure Path rather than the
prototype or its Wayfinder ticket. Outputs expose only the values required by
deployment, verification, reference smoke scenarios, evidence collection, and
cleanup.

## Readiness checks

The readiness command runs before provisioning and makes no Azure changes. It
fails closed unless it can prove:

1. Required local commands are available, including `az`, `azd`, `curl`, and
   `jq`.
2. Azure CLI and Azure Developer CLI authentication are usable.
3. The intended subscription is explicitly selected.
4. Required resource providers are registered or the attendee has a documented
   administrator path to registration.
5. The selected region has usable Basic App Service quota or capacity for the
   subscription.
6. The selected Foundry model, version, deployment SKU, and required capacity
   are available in that region and subscription.
7. The attendee has the documented resource creation and role-assignment
   authority.

The command distinguishes a failed check from a check that the Azure APIs do
not permit it to perform. Unknown is not success. Each failure names the gate,
the observed fact, and the attendee or administrator action required.

## Preflight flow

Preflight is real deployment evidence, not a static account check.

1. The attendee creates or selects a uniquely named `azd` environment and
   explicitly records the subscription, region, model parameters, and cleanup
   deadline.
2. The attendee runs the readiness command.
3. The deployment command runs `azd up` using the workshop-owned Bicep and
   packages the application from the current branch.
4. Verification waits within a bounded timeout for `/actuator/health` to report
   healthy.
5. Verification inspects the deployed resource topology, model deployment,
   managed identity, Foundry User role assignment, and required non-secret app
   settings.
6. Evidence collection writes a redacted local record and prints its path.
7. The environment remains deployed as the attendee's pre-provisioned Azure
   Inherited System for the workshop.

The template branch does not invoke a Clinic Assistant endpoint or encode
reference responses. Its Azure Preflight proves the clean Inherited System is
deployed and reachable and that the infrastructure needed by the bounded
Reference Challenge exists.

## Evidence contract

Preflight evidence records:

- command and schema version;
- UTC timestamps;
- repository revision;
- selected subscription in redacted form;
- region, model, model version, deployment name, SKU, and capacity;
- resource types and provisioning states;
- the managed-identity presence;
- role names and scopes without principal identifiers;
- required app-setting names without secret values;
- application health result;
- deployed timestamp and cleanup deadline; and
- the strongest truthful verdict for every gate.

Cleanup evidence records:

- UTC timestamps;
- the cleanup command and environment;
- `azd down --force --purge` result;
- resource-group absence;
- active Foundry-resource absence;
- deleted-account inspection and any explicit purge;
- the final residual-resource verdict; and
- the later Cost Management check the attendee must perform after billing data
  catches up.

Generated `azd` state, live resource identifiers, tokens, credentials, private
model inputs, and reusable URLs are never committed. Evidence files are ignored
by default and remain attendee-owned unless a deliberately redacted artifact is
prepared for workshop validation.

## Cleanup flow

Cleanup captures the Foundry account name, resource-group name, region, and
other required values before deleting the `azd` environment.

1. Run `azd down --force --purge`.
2. Verify the resource group no longer exists.
3. Verify no active App Service plan, web app, or Foundry account remains.
4. Query deleted Cognitive Services accounts for the captured account and
   region.
5. If the account remains soft-deleted, run an explicit Cognitive Services
   purge with the captured account, resource group, and region.
6. Recheck soft-delete state with bounded retries to accommodate Azure
   propagation.
7. Write cleanup evidence and exit successfully only when no active or
   soft-deleted workshop resource remains.

A timeout or residual resource exits non-zero and prints the remaining resource
details and escalation action. Delayed Cost Management data is documented as a
later human verification step and is not represented as an immediate automated
pass.

## Reference smoke extension

The `reference/clinic-assistant` branch adds a reference-only deployed smoke
command that reuses the Workshop Azure Path and covers:

1. one known query for each implemented capability family;
2. an ambiguous-name result requiring clarification;
3. an unsupported request or attempted write;
4. a veterinary diagnosis or treatment request; and
5. reset of session-scoped conversation state.

The smoke command fails when the model, deployment, endpoint, application, or
expected behavior is unavailable. It cannot downgrade a missing dependency or
failed scenario into a successful claim.

## Error handling

Commands use strict shell behavior, validate required inputs before mutation,
and preserve the failed gate's evidence. They do not broadly catch errors,
replace failed checks with defaults, or continue into costly provisioning after
a readiness failure.

Failures are grouped by the action needed:

- attendee-local correction;
- subscription administrator action;
- workshop-owner parameter refresh;
- transient Azure propagation with bounded retry; or
- residual-resource escalation after cleanup.

Messages avoid exposing credentials, tokens, principal identifiers, or complete
live resource identifiers.

## Validation

Fixture-driven shell tests stub `az`, `azd`, `curl`, and `jq` and cover:

- successful readiness, Preflight verification, evidence, and cleanup;
- missing local commands;
- missing or inconsistent Azure authentication and subscription selection;
- unregistered providers or insufficient registration authority;
- unavailable Basic quota or capacity;
- unavailable model, version, SKU, or capacity;
- insufficient role-assignment authority;
- unhealthy or timed-out application startup;
- missing resource, identity, role, deployment, or app-setting evidence;
- successful `azd` purge;
- explicit Cognitive Services purge fallback;
- propagation timeout; and
- residual-resource failure.

Infrastructure validation compiles or validates the Bicep with the repository's
available Azure tooling. Repository validation proves the shared assets contain
no Clinic Assistant implementation, reference scenario, secret, generated
environment state, or completed participant evidence. The existing canonical
PetClinic build and template-boundary validation remain required.

Live validation uses a fresh attendee-like environment to run readiness,
deployment, verification, evidence collection, and cleanup. The reference
branch additionally runs its deployed Clinic Assistant scenarios.

## Attendee guidance

A dedicated Azure guide documents:

- required accounts, roles, provider registration, quota, and local tools;
- the tested default region guidance and how to select another proven region;
- every resource created by the Workshop Azure Path;
- readiness, deployment, verification, evidence, and cleanup commands;
- the current price observation date, formulas, rounded scenarios, and refresh
  procedure;
- cost controls and the explicit cleanup deadline;
- the evidence contract and safe redaction rules;
- troubleshooting boundaries and escalation paths; and
- the later Cost Management confirmation.

The guide states that Preflight is completed before the workshop and is not a
live setup exercise.

## Success criteria

This design is implemented when:

- a clean template-generated repository can run readiness checks, deploy the
  Inherited System, reach it in Azure, and capture redacted Preflight evidence;
- the permanent infrastructure matches the validated B1, projectless Foundry,
  managed-identity, and Foundry User baseline;
- unsupported quota, model, permission, health, or cleanup states fail
  explicitly;
- cleanup proves the resource group, active resources, and Foundry soft-delete
  record are absent;
- the attendee guide provides the required permission, cost, troubleshooting,
  and cleanup envelope;
- template validation prevents reference solution leakage and generated Azure
  state from being committed; and
- the reference branch reuses the shared lifecycle and adds the complete
  deployed Clinic Assistant smoke path.

## Out of scope

- Production hardening, private networking, high availability, autoscaling, or
  centralized observability.
- A shared workshop subscription or host-operated attendee environments.
- Azure AI Search, Foundry projects, Foundry Agent Service, persistent chat
  storage, Key Vault, or an additional database unless a later decision
  explicitly changes the accepted Workshop Blueprint.
- Clinic Assistant implementation or expected responses on `main`.
- Treating delayed billing data as immediate automated cleanup proof.
