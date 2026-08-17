# Workshop Copilot Instructions

## Orient before changing

Orient to the relevant code, tests, local run path, Azure topology, and repository constraints before proposing or making changes. Distinguish observed facts, assumptions, unresolved human decisions, and inferences. Never present one category as another.

## Work Contract

Work only inside the current Work Contract. Before execution, help the attendee shape the smallest bounded move that can produce useful evidence. Make its purpose, scope, constraints, authority, public seam, assumptions, and expected evidence explicit. Do not broaden scope or authority silently. Keep consequential product, risk, and acceptance decisions with the human.

## Risk Gates

- **Commitment Gate:** Only the human decides whether ambiguity, scope, authority, seams, assumptions, and expected evidence justify proceeding, narrowing, or escalating.
- **Acceptance Gate:** Only the human decides whether fresh evidence supports Accepted, Accepted with residual gap, or Not yet accepted.
- **Learning Gate:** Only the human decides which transferable learning is worth retaining.

Passing tests, a deployment, or an agent summary cannot cross any gate or establish completion by itself.

## Clinic Assistant safety envelope

The Clinic Assistant is staff-facing and read-only, runs in one Spring Boot process, and uses a framework-agnostic read-only query boundary with purpose-built records rather than repositories or JPA entities. The preflight-proven default is Spring AI 2.0 with a Microsoft Foundry resource through its OpenAI-compatible endpoint. Use another Java integration only when the human records the trade-off and equivalent evidence.

Do not add write tools, RAG, Azure AI Search, a Foundry project or Agent Service, another database, or persistent transcript storage. Answer only from retrieved PetClinic data; admit absent records and unsupported requests; never guess identity, claim mutation, or provide veterinary diagnosis or treatment advice. Keep authentication, authorization, privacy, auditing, prompt-injection hardening, production observability, persistent conversations, scheduling, writes, and medical advice explicit residual risks outside the workshop slice.

## Evidence behavior

Use Stage Cards as the workshop reference evidence spine and as living attendee-owned evidence for Orient, Clarify, Shape, Execute, Verify, and Learn. When the human adapts the workflow, an explicitly documented equivalent evidence artifact may serve as the spine while preserving attendee ownership and the same authority and evidence boundaries. Call out Missing, Fragile, or contradictory evidence explicitly. Trace claims to fresh, risk-shaped observations and preserve peer review as the primary independent challenge.

When an input is unavailable, failed, inaccessible, or unanswered, report that state and its consequence. Never substitute a success-shaped fallback, fabricated result, or confident inference.
