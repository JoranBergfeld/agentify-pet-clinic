# Clinic Assistant reference evidence

Date: 2026-08-16

## Current validation status

- Current tested offline reference implementation revision: this document's
  commit.
- Final live implementation and validator revision:
  `af3da483c11ca31889b66ac65c3b14f5f1f638d5`.
- Local shared/template branch merged into this reference branch through
  `main` at `9375f1124d97dee3a965637206e498e036dc5994`.
- Final live Azure validation: PASS at the exact implementation and validator
  revision above.
- The deployed smoke now requires an ordered one-line `Samantha:` response
  linking the exact `2013-01-01 - rabies shot` and
  `2013-01-04 - spayed` fixture facts to Samantha.
- Reset validation now creates an ordinary in-scope transcript, posts reset,
  and requires the structured reset-success marker with no visible transcript.
  The application emits that marker only after `ChatMemory.clear` has been
  followed by an empty readback under the conversation lock and the visible
  transcript has then been cleared. The marker therefore attests the verified
  reset postcondition; reset proof does not depend on model prose or follow-up
  recall behavior.
- Offline fixture and local application validation are current at the tested
  offline implementation revision above.
- The final live run proved the strengthened visit-attribution and
  reset-memory assertions.
- The implementation classifies workshop attempted-write and medical-advice
  requests before model invocation, returns deterministic fixed refusals, and
  renders typed assistant outcomes.

## Final deployed reference smoke

- Live validation date: `2026-08-16`
- Status: PASS at implementation and validator revision `af3da48`.
- Region: `swedencentral`
- Model: `gpt-5.4-mini`
- Model version: `2026-03-17`
- Deployment SKU: `GlobalStandard`
- Deployment capacity: `10`
- Azure Preflight: PASS
- Pet and recorded-visit scenario: PASS
- Owner and pet scenario: PASS
- Veterinarian and specialty scenario: PASS
- Ambiguous owner scenario: PASS
- Attempted-write scenario: PASS — structured outcome
  `read-only-refusal`; rendered response exactly matched the deterministic
  fixed read-only refusal.
- Medical-advice scenario: PASS — structured outcome `medical-refusal`;
  rendered response exactly matched the deterministic fixed medical refusal.
- Reset setup scenario: PASS — an ordinary in-scope transcript was present.
- Reset: PASS — the structured reset-success marker attested that
  `ChatMemory.clear` was followed by an empty readback; the visible transcript
  and setup prompt were absent afterward.
- Overall deployed smoke: PASS — seven scenarios plus reset.
- The smoke used one cookie jar, fetched `/clinic-assistant` before posting, submitted URL-encoded messages while following redirects, isolated model scenarios through the UI reset endpoint, and failed closed on transport or semantic assertion failures.
- Evidence intentionally excludes environment and resource names, URLs, full subscription or tenant identifiers, credentials, and raw model transcripts.

## Cleanup proof

- Implemented cleanup command: PASS
- Resource group absent: PASS
- App Service plan and web app absent: PASS
- Active Foundry account and model deployment absent: PASS
- Deleted Foundry account absent: PASS
- Independent post-cleanup resource-group query: PASS
- Independent active-account query: PASS
- Independent deleted-account query: PASS
- Cleanup completed: `2026-08-16T20:49:42Z`
- Independent absence verification: `2026-08-16T20:49:56Z` — resource group
  absent, active App Service/Foundry resource count `0`, and deleted Foundry
  account count `0`.

## Commands

Executed:

```text
./gradlew -q assertJava17Release
./gradlew -q test
scripts/test-reference-validator.sh
scripts/validate-reference.sh
scripts/test-azure-reference-smoke.sh
scripts/test-azure-cleanup.sh
scripts/test-azure-preflight.sh
scripts/test-azure-readiness.sh
scripts/test-workshop-azure-infra.sh
scripts/test-template-baseline-validator.sh
scripts/test-template-generation-validator.sh
./mvnw -q test
```

Validator internals:

```text
git fetch origin +refs/heads/main:refs/remotes/origin/main
git merge-base --is-ancestor refs/remotes/origin/main HEAD
test -d src/main/java/org/springframework/samples/petclinic/assistant
grep -Fq '<artifactId>spring-ai-starter-model-openai</artifactId>' pom.xml
grep -Fq 'spring-ai-bom:2.0.0' build.gradle
grep -Fq 'spring-ai-starter-model-openai' build.gradle
grep -Fq 'azure-identity:1.18.2' build.gradle
./gradlew -q assertJava17Release compileJava
./mvnw -q -Dtest='ClinicQueryServiceTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantToolsTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantModelTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantConversationTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantBoundaryTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantBoundaryScenarioTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantServiceTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantControllerTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='ClinicAssistantSessionListenerTests' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q -Dtest='I18nPropertiesSyncTest' -Dsurefire.failIfNoSpecifiedTests=true test
./mvnw -q test
```

## Results

- `./gradlew -q assertJava17Release`: PASS — every `JavaCompile` task reports `options.release = 17`
- `./gradlew -q test`: PASS — 30 suite reports, 202 tests, 0 failures, 0 errors, 4 skipped
- `scripts/test-reference-validator.sh`: PASS — proves a single-branch reference clone materializes `refs/remotes/origin/main`, enforces the Gradle Spring AI dependency gate before test execution, reaches the `./gradlew -q assertJava17Release compileJava` gate, then proves focused classes still run one-at-a-time with `-Dsurefire.failIfNoSpecifiedTests=true` and `MissingReferenceValidationTest` still stops validation before the full-suite fallback.
- `scripts/validate-reference.sh`: PASS (exit `0`; final line `reference branch is current and validated`)
- `scripts/test-azure-reference-smoke.sh`: PASS — the stateful curl fixture
  proves an ordinary in-scope transcript exists before reset, requires the
  structured reset-success marker and transcript absence afterward, and fails
  closed when the reset request fails, the marker is absent, or the transcript
  remains. The HTTP fixture cannot inject retained internal `ChatMemory`; that
  failure is covered by the real model test.
- Shared Azure and template contract tests: PASS —
  `scripts/test-azure-cleanup.sh`, `scripts/test-azure-preflight.sh`,
  `scripts/test-azure-readiness.sh`, `scripts/test-workshop-azure-infra.sh`,
  `scripts/test-template-baseline-validator.sh`, and
  `scripts/test-template-generation-validator.sh`.
- `REFERENCE_DEPLOYED_SMOKE=1 scripts/validate-reference.sh`: PASS — exact
  Samantha visit facts and attribution, owner/pet, veterinarian/specialty,
  ambiguous owner handling, deterministic structured write and medical
  refusals, and verified reset with transcript absence all passed.
- Focused assistant suite: PASS — 10 suite reports, 90 tests, 0 failures, 0 errors, 0 skipped
- Full Maven suite (`./mvnw -q test`): PASS — 27 suite reports, 200 tests, 0 failures, 0 errors, 2 skipped
- Current Java 21 run emitted non-failing Mockito/Byte Buddy dynamic-agent warnings during test startup

## Focused coverage claims

- Owner coverage: PASS via `ClinicQueryServiceTests.findsOwnersWithPurposeBuiltPetAndVisitRecords`
- Pet coverage: PASS via `ClinicQueryServiceTests.findsPetsByExactCaseInsensitiveNameAcrossOwnersWithOwnerIdentity`
- Veterinarian coverage: PASS via `ClinicQueryServiceTests.listsVeterinariansWithExactRecordContractAndSortedSpecialtyNames`
- Ambiguity-preserving multi-results: PASS for preserving multiple exact pet matches with owner identity via `ClinicQueryServiceTests.findsPetsByExactCaseInsensitiveNameAcrossOwnersWithOwnerIdentity`; the configured clarification boundary is PASS via `ClinicAssistantBoundaryTests.configuresClarificationForMultipleMatches`.
- Deterministic refusal boundary: PASS locally via `ClinicAssistantServiceTests.refusesAttemptedWritesWithoutInvokingTheModel`, `ClinicAssistantServiceTests.refusesWorkshopRecordMutationRequests`, `ClinicAssistantServiceTests.refusesVeterinaryDiagnosisAndTreatmentWithoutInvokingTheModel`, `ClinicAssistantServiceTests.sendsNormalKnownDataQuestionsToTheModel`, and `ClinicAssistantServiceTests.sendsPresentationRequestsToTheModel`
- Endpoint refusal transcript flow and structured outcomes: PASS locally via `ClinicAssistantBoundaryScenarioTests.rendersReadOnlyRefusalForAttemptedWriteRequestsWithoutFabricatedActivity`, `ClinicAssistantBoundaryScenarioTests.rendersMedicalAdviceRefusalWithoutFabricatedActivity`, and `ClinicAssistantBoundaryScenarioTests.rendersNormalOutcomeForModelAnswers`
- Conversation transcript model: PASS via `ClinicAssistantConversationTests.createsAStringConversationWithPackagePrivateTypesAndImmutableTurns` and `ClinicAssistantConversationTests.recordsUserAndAssistantTurnsAndCanClearThem`
- Activity visibility: PASS via `ClinicAssistantToolsTests.returnsPurposeBuiltRecordsAndVisibleActivity`, `ClinicAssistantServiceTests.recordsTheUserAnswerAndVisibleActivity`, and `ClinicAssistantControllerTests.preservesTranscriptAndVisibleActivityInTheSession`
- Memory behavior: PASS via `ClinicAssistantModelTests.passesConversationIdAndActivityLogToTheChatClient`, `ClinicAssistantModelTests.restoresPriorConversationMemoryWhenPromptFails`, `ClinicAssistantModelTests.restoresPriorConversationMemoryWhenTheModelReturnsNull`, `ClinicAssistantModelTests.serializesConcurrentAnswersForTheSameConversation`, and `ClinicAssistantModelTests.allowsDifferentConversationStripesToPromptConcurrently`
- Reset behavior: PASS via `ClinicAssistantModelTests.resetClearsConversationMemory`, `ClinicAssistantModelTests.resetRejectsMemoryThatStillContainsMessagesAfterClear`, `ClinicAssistantModelTests.serializesResetWithAnswerForTheSameConversation`, `ClinicAssistantServiceTests.resetsModelMemoryAndTheVisibleTranscript`, `ClinicAssistantServiceTests.preservesTheVisibleTranscriptWhenModelResetFails`, `ClinicAssistantServiceTests.serializesResetAgainstAnInFlightQuestion`, `ClinicAssistantControllerTests.resetsTheConversation`, and `ClinicAssistantControllerTests.doesNotRenderResetMarkerOrClearTranscriptWhenModelResetFails`
- UI behavior: PASS via `ClinicAssistantControllerTests.showsTheAssistantPage`, `ClinicAssistantControllerTests.rejectsBlankInput`, `ClinicAssistantControllerTests.ignoresForgedConversationFields`, and `ClinicAssistantControllerTests.preservesTranscriptAndVisibleActivityInTheSession`
- Session cleanup: PASS via `ClinicAssistantSessionListenerTests.expiresTheConversationWhenTheSessionEnds`, `ClinicAssistantSessionListenerTests.ignoresSessionsWithoutTheAssistantConversation`, and `ClinicAssistantSessionListenerTests.ignoresInvalidatedSessionsDuringShutdown`
- I18n coverage: PASS via `ClinicAssistantControllerTests.rendersGermanMessages`, `ClinicAssistantControllerTests.rendersSpanishMessages`, `I18nPropertiesSyncTest.checkNonInternationalizedStrings`, and `I18nPropertiesSyncTest.checkI18nPropertyFilesAreInSync`
- Configuration safety boundary: PASS via `ClinicAssistantBoundaryTests.configuresAdmissionsForUnsupportedOrAbsentRequests`, `ClinicAssistantBoundaryTests.configuresReadOnlyRepliesWithoutMutationClaims`, `ClinicAssistantBoundaryTests.configuresNoVeterinaryDiagnosisOrTreatmentAdvice`, and `ClinicAssistantBoundaryTests.configuresClarificationForMultipleMatches`

## Unsupported and medical boundaries

The focused local suite now proves obvious workshop attempted-write and
veterinary diagnosis/treatment requests are classified before
`ClinicAssistantModel.answer`, receive fixed responses with no activity, and
render typed outcomes. A normal known-data prompt still invokes the model.
The deterministic classifier is intentionally limited to explicit workshop
phrases for PetClinic record mutations, visit scheduling, known record-field
changes, and medical advice. It is not presented as general natural-language
intent recognition; presentation-oriented reads and other unmatched requests
remain model-driven.
`ClinicAssistantBoundaryTests` retains the system-prompt defense in depth, but
the fixed refusal contract no longer depends on free-text model compliance.

The final 2026-08-16 live run proved the strengthened visit-set, attribution,
structured refusal, and reset-memory contracts at revision `af3da48`.

## Redaction note

This document intentionally excludes credentials, tokens, local `.azure` contents, live resource identifiers, and any other sensitive environment values. The only sample prompts referenced here are PetClinic fixture questions already covered by the local tests above.
