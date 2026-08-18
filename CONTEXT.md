# Agentic Development Workshop

This context defines the shared language for a workshop that teaches experienced technical practitioners a reusable way to work with coding agents across projects.

## Language

**Agentic Engineering Principles**:
Portable guidance for making agent-assisted engineering controlled, inspectable, and reusable across tools and repositories.
_Avoid_: Agentic Engineering Standards, compliance rules, prompt tips

**Reference Workflow**:
The recommended route through skills, agents, and evidence-producing practices that demonstrates the Agentic Engineering Principles while remaining adaptable to the situation.
_Avoid_: Mandatory procedure, required toolchain

**Work Contract**:
The smallest explicit agreement that makes intent, scope, constraints, agent authority, and acceptance evidence legible before execution.
_Avoid_: Prompt, mandatory specification

**Risk Gate**:
An explicit pause at a consequential transition where the human decides whether available evidence justifies proceeding.
_Avoid_: Approval ceremony, process checkpoint

**Workshop Blueprint**:
The delivery-ready definition of the workshop's learning outcomes, exercise flow, host cues, participant guidance, take-home principles and workflow, and success criteria.
_Avoid_: Workshop implementation, course materials

**Participant Guide**:
The durable attendee-held reference for operating the workshop.
_Avoid_: workbook, Workshop Blueprint, deck script

**Workshop Package**:
The complete repository-based result required for first delivery: the accepted Workshop Blueprint, delivery materials, participant and host guidance, challenge and Copilot assets, technical environment automation, reference evidence path, and validated dry-run evidence.
_Avoid_: Workshop Blueprint, production Clinic Assistant, future enhancement backlog

**Reference Challenge**:
The shared, intentionally ambiguous Spring PetClinic change used to practice the Agentic Engineering Principles and Reference Workflow without making the product feature the focus.
_Avoid_: Final product, workshop deliverable

**Engineering Agent**:
The coding agent used by participants to understand the Unfamiliar Codebase and execute bounded engineering work.
_Avoid_: Clinic Assistant, application agent

**Clinic Assistant**:
The staff-facing conversational agent added to Spring PetClinic as the Reference Challenge.
_Avoid_: Engineering Agent, public chatbot

**Clinic Stakeholder**:
The product-facing role that answers what is known about the fictional Reference Challenge, makes uncertainty explicit, and may leave consequential gaps that pairs must handle through bounded assumptions or escalation.
_Avoid_: Facilitator, Engineering Agent

**Driver**:
The participant currently directing the coding agent in their own environment and owning the resulting Work Contract, implementation, evidence, and acceptance judgment.
_Avoid_: Implementer, operator

**Auditor**:
The partner currently critiquing how the Driver applies the Agentic Engineering Principles and supports decisions with useful evidence.
_Avoid_: Reviewer, spectator

**Evidence Lens**:
A shared perspective the Driver and Auditor use to inspect whether intent, decisions, authority, execution, verification, and learning are supported by observable evidence rather than agent confidence or feature output alone.
_Avoid_: Score, compliance criterion, checklist item

**Stage Card**:
A living Markdown record for one Reference Workflow stage that combines minimal guidance with the Driver's evolving evidence. Each Stage Card moves independently through Working, Review ready, and Reviewed states, may reopen after feedback, and is reviewed at a named commit revision.
_Avoid_: Gate checklist, immutable stage deliverable, synchronized workshop checkpoint

**Reciprocal Evidence Review**:
A structured, asynchronous PR critique of Review-ready Stage Cards, organized by Intent, Decisions, Evidence, Gaps, and Next inspection point. The Auditor challenges evidence at a named commit revision without approving acceptance, prescribing the next move, or taking over the Driver's implementation.
_Avoid_: Evidence Handoff, role rotation, approval verdict, prescribed next step

**Workshop Host**:
The human who manages logistics, cohort timing, breaks, transitions, and organization of the closing exchange without coaching pair decisions, reviewing engineering evidence, or directing the Reference Workflow.
_Avoid_: Facilitator, instructor, approver

**Evidence Coach**:
The optional repository GitHub Copilot custom agent that reviews committed, Review-ready Stage Cards through the Evidence Lenses and drafts a labelled, revision-specific PR comment the human posts, without replacing peer critique, approving decisions, prescribing the next move, or certifying work.
_Avoid_: Facilitator, Auditor, approver, autonomous reviewer

**Supported Environment**:
The attendee-owned local GitHub Copilot and Azure setup used to demonstrate the Reference Workflow without defining or limiting the Agentic Engineering Principles.
_Avoid_: Required platform, standard tool

**Inherited System**:
The running Spring PetClinic application, local development path, and pre-provisioned Azure environment participants can operate before the workshop but must understand through Orient before changing.
_Avoid_: Starter app, greenfield project, setup exercise

**Preflight**:
Evidence completed before the workshop that an attendee can run and test the Inherited System locally, use the Copilot client, and deploy and reach it in Azure without being taught its architecture.
_Avoid_: Live setup, installation guide

**Workshop Azure Path**:
The workshop-owned, attendee-operated lifecycle for checking Azure readiness, deploying and verifying the Inherited System, capturing redacted evidence, and proving cleanup of the attendee's isolated environment.
_Avoid_: Reference deployment, production platform, one-off prototype

**Unfamiliar Codebase**:
A working application in a technology the participant need not already know deeply, used to practice agent-assisted orientation before changing it.
_Avoid_: Beginner codebase, prerequisite technology
