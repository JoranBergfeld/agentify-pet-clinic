# Azure Deployment Slice Prototype Design

## Purpose

Answer whether a disposable starter based on canonical Spring PetClinic can deploy reliably to Azure App Service B1 with Spring AI 2.0 and a Microsoft Foundry model, use managed identity for inference, handle representative Clinic Assistant traffic, and clean up without residual cost or quota.

This prototype supports the Workshop Blueprint. It is not production application work or a workshop deliverable.

## Prototype boundary

Use the active `base_subscription` (`9bc0bdaa-0a20-4570-9cae-ef826f5c23a7`). Create a uniquely named resource group and `azd` environment for the experiment. All application and infrastructure changes live on a clearly disposable prototype branch based on the canonical `spring-projects/spring-petclinic` main branch.

The application slice contains only:

- Spring AI 2.0 OpenAI chat integration.
- Managed-identity bearer-token authentication for the Cognitive Services scope.
- One purpose-built, read-only tool backed by existing PetClinic data.
- A minimal HTTP Clinic Assistant endpoint that can demonstrate a known-data query, ambiguity handling, an unsupported request, and tool activity.

No production UI, persistent chat, write tools, authentication, Foundry project, Agent Service, search service, or additional database is included.

## Azure architecture

An `azd` template provisions:

- Azure App Service for Linux using the Java SE runtime and Basic B1 plan.
- A system-assigned managed identity for the web app.
- `Microsoft.CognitiveServices/accounts` with `kind: AIServices`, `allowProjectManagement: true`, and local authentication disabled.
- A chat model deployment, starting with `GlobalStandard`.
- A resource-scoped Foundry User assignment for the App Service identity.
- App settings for the OpenAI-compatible endpoint, deployment name, and managed-identity authentication.

If deployment evidence shows a region, quota, or policy blocker, try `DataZoneStandard` and record why. If Foundry User cannot invoke the OpenAI-compatible endpoint without a project, replace it with Cognitive Services OpenAI User and record the authorization evidence.

## Execution flow

1. Build the disposable PetClinic slice and its `azd` infrastructure.
2. Run a fresh `azd up` into the isolated environment.
3. Deploy the executable JAR and verify application startup.
4. Redeploy once to prove the repeat path.
5. Exercise representative Clinic Assistant requests and capture redacted answers, tool activity, status codes, and logs.
6. Observe App Service memory during startup and chat/tool traffic to judge B1 fit.
7. Query the Azure Retail Prices API for the selected region, model, and deployment type using `serviceName eq 'Foundry Models'`.
8. Run `azd down --force --purge`.
9. Verify resource-group deletion, inspect soft-deleted Cognitive Services accounts, explicitly purge the Foundry resource if needed, and confirm no active resource remains.

## Evidence and verdict

Capture commands, redacted configuration, role assignments, deployment output, runtime and memory observations, smoke results, price data, cleanup output, and any fallback taken. Store the prototype itself on the disposable branch as a primary source and link it from the Wayfinder ticket.

The final verdict states:

- Whether the architecture works in the selected subscription.
- Whether Global Standard and Foundry User remain the baseline.
- Whether B1 has sufficient observed headroom.
- Whether `azd down --force --purge` is sufficient or explicit Cognitive Services purge is required.
- The date-stamped price observation and the recommended attendee Preflight baseline.

## Failure policy

Do not hide quota, policy, authorization, deployment, startup, or cleanup failures behind defaults. Stop at the failed gate, preserve the evidence, apply only the ticket's named fallback when justified, and report any unresolved blocker as the prototype result.
