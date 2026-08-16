# Clinic Assistant reference evidence

Date: 2026-08-16

## Validated revisions

- `main`: `9d52d5c`
- `origin/main`: `9d52d5c`
- Structured-boundary implementation revision: `97fcda7`
- Deployed smoke validator revision: `97fcda7`
- The implementation classifies workshop attempted-write and medical-advice
  requests before model invocation, returns deterministic fixed refusals, and
  renders typed assistant outcomes.

## Fresh deployed reference smoke

- Live validation date: `2026-08-16`
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
- Conversation marker scenario: PASS
- Reset: PASS — the marker was absent after reset.
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

## Commands

Executed:

```text
./gradlew -q assertJava17Release
./gradlew -q test
scripts/test-reference-validator.sh
scripts/validate-reference.sh
REFERENCE_DEPLOYED_SMOKE=1 scripts/validate-reference.sh
scripts/test-azure-reference-smoke.sh
scripts/azure-preflight.sh
scripts/azure-cleanup.sh
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
- `./gradlew -q test`: PASS — 30 suite reports, 198 tests, 0 failures, 0 errors, 4 skipped
- `scripts/test-reference-validator.sh`: PASS — proves a single-branch reference clone materializes `refs/remotes/origin/main`, enforces the Gradle Spring AI dependency gate before test execution, reaches the `./gradlew -q assertJava17Release compileJava` gate, then proves focused classes still run one-at-a-time with `-Dsurefire.failIfNoSpecifiedTests=true` and `MissingReferenceValidationTest` still stops validation before the full-suite fallback.
- `scripts/validate-reference.sh`: PASS (exit `0`; final line `reference branch is current and validated`)
- `REFERENCE_DEPLOYED_SMOKE=1 scripts/validate-reference.sh`: PASS — final deployed run reported `reference deployed smoke passed (7 scenarios plus reset)` and `reference branch is current and validated`
- Focused assistant suite: PASS — 10 suite reports, 86 tests, 0 failures, 0 errors, 0 skipped
- Full Maven suite (`./mvnw -q test`): PASS — 27 suite reports, 196 tests, 0 failures, 0 errors, 2 skipped
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
- Reset behavior: PASS via `ClinicAssistantModelTests.resetClearsConversationMemory`, `ClinicAssistantModelTests.serializesResetWithAnswerForTheSameConversation`, `ClinicAssistantServiceTests.resetsModelMemoryAndTheVisibleTranscript`, `ClinicAssistantServiceTests.serializesResetAgainstAnInFlightQuestion`, and `ClinicAssistantControllerTests.resetsTheConversation`
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

Historical prototype smoke evidence first proved the live medical-advice
refusal path at revision `ee7397d`. The fresh 2026-08-16 validation above is
the current evidence for the structured-outcome revision.

## Redaction note

This document intentionally excludes credentials, tokens, local `.azure` contents, live resource identifiers, and any other sensitive environment values. The only sample prompts referenced here are PetClinic fixture questions already covered by the local tests above.
