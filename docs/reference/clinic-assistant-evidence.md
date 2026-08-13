# Clinic Assistant reference evidence

Date: 2026-08-13

## Validated revisions

- `main`: `9a9825951cedb66dad1b4b700ba5591a0ada69c5`
- `origin/main`: `9a9825951cedb66dad1b4b700ba5591a0ada69c5`
- `reference/clinic-assistant` validator base `HEAD`: `0e12601e9990023637e24e634e02107274781d65`

## Commands

Executed:

```text
chmod +x scripts/validate-reference.sh
scripts/validate-reference.sh
git rev-parse main
git rev-parse origin/main
git rev-parse HEAD
```

Validator internals:

```text
git fetch origin main
git merge-base --is-ancestor origin/main HEAD
test -d src/main/java/org/springframework/samples/petclinic/assistant
grep -Fq '<artifactId>spring-ai-starter-model-openai</artifactId>' pom.xml
./mvnw -q -Dtest='ClinicQueryServiceTests,ClinicAssistantToolsTests,ClinicAssistantModelTests,ClinicAssistantConversationTests,ClinicAssistantBoundaryTests,ClinicAssistantBoundaryScenarioTests,ClinicAssistantServiceTests,ClinicAssistantControllerTests,ClinicAssistantSessionListenerTests,I18nPropertiesSyncTest' test
./mvnw -q test
```

## Results

- `scripts/validate-reference.sh`: PASS (exit `0`; final line `reference branch is current and validated`)
- Focused assistant suite: PASS — 10 suite reports, 38 tests, 0 failures, 0 errors, 0 skipped
- Full Maven suite (`./mvnw -q test`): PASS — 26 suite reports, 107 tests, 0 failures, 0 errors, 2 skipped
- Current Java 21 run emitted non-failing Mockito/Byte Buddy dynamic-agent warnings during test startup

## Focused coverage claims

- Owner coverage: PASS via `ClinicQueryServiceTests.findsOwnersWithPurposeBuiltPetAndVisitRecords`
- Pet coverage: PASS via `ClinicQueryServiceTests.findsPetsByExactCaseInsensitiveNameAcrossOwnersWithOwnerIdentity`
- Veterinarian coverage: PASS via `ClinicQueryServiceTests.listsVeterinariansWithExactRecordContractAndSortedSpecialtyNames`
- Ambiguity-preserving multi-results: PASS for preserving multiple exact pet matches with owner identity via `ClinicQueryServiceTests.findsPetsByExactCaseInsensitiveNameAcrossOwnersWithOwnerIdentity`; the configured clarification boundary is PASS via `ClinicAssistantBoundaryTests.configuresClarificationForMultipleMatches`.
- Endpoint refusal transcript flow: PASS via `ClinicAssistantBoundaryScenarioTests.rendersReadOnlyRefusalForAttemptedWriteRequestsWithoutFabricatedActivity` and `ClinicAssistantBoundaryScenarioTests.rendersMedicalAdviceRefusalWithoutFabricatedActivity`
- Conversation transcript model: PASS via `ClinicAssistantConversationTests.createsAStringConversationWithPackagePrivateTypesAndImmutableTurns` and `ClinicAssistantConversationTests.recordsUserAndAssistantTurnsAndCanClearThem`
- Activity visibility: PASS via `ClinicAssistantToolsTests.returnsPurposeBuiltRecordsAndVisibleActivity`, `ClinicAssistantServiceTests.recordsTheUserAnswerAndVisibleActivity`, and `ClinicAssistantControllerTests.preservesTranscriptAndVisibleActivityInTheSession`
- Memory behavior: PASS via `ClinicAssistantModelTests.passesConversationIdAndActivityLogToTheChatClient`, `ClinicAssistantModelTests.restoresPriorConversationMemoryWhenPromptFails`, `ClinicAssistantModelTests.restoresPriorConversationMemoryWhenTheModelReturnsNull`, `ClinicAssistantModelTests.serializesConcurrentAnswersForTheSameConversation`, and `ClinicAssistantModelTests.allowsDifferentConversationStripesToPromptConcurrently`
- Reset behavior: PASS via `ClinicAssistantModelTests.resetClearsConversationMemory`, `ClinicAssistantModelTests.serializesResetWithAnswerForTheSameConversation`, `ClinicAssistantServiceTests.resetsModelMemoryAndTheVisibleTranscript`, `ClinicAssistantServiceTests.serializesResetAgainstAnInFlightQuestion`, and `ClinicAssistantControllerTests.resetsTheConversation`
- UI behavior: PASS via `ClinicAssistantControllerTests.showsTheAssistantPage`, `ClinicAssistantControllerTests.rejectsBlankInput`, `ClinicAssistantControllerTests.ignoresForgedConversationFields`, and `ClinicAssistantControllerTests.preservesTranscriptAndVisibleActivityInTheSession`
- Session cleanup: PASS via `ClinicAssistantSessionListenerTests.expiresTheConversationWhenTheSessionEnds`, `ClinicAssistantSessionListenerTests.ignoresSessionsWithoutTheAssistantConversation`, and `ClinicAssistantSessionListenerTests.ignoresInvalidatedSessionsDuringShutdown`
- I18n coverage: PASS via `ClinicAssistantControllerTests.rendersGermanMessages`, `ClinicAssistantControllerTests.rendersSpanishMessages`, `I18nPropertiesSyncTest.checkNonInternationalizedStrings`, and `I18nPropertiesSyncTest.checkI18nPropertyFilesAreInSync`
- Configuration safety boundary: PASS via `ClinicAssistantBoundaryTests.configuresAdmissionsForUnsupportedOrAbsentRequests`, `ClinicAssistantBoundaryTests.configuresReadOnlyRepliesWithoutMutationClaims`, `ClinicAssistantBoundaryTests.configuresNoVeterinaryDiagnosisOrTreatmentAdvice`, and `ClinicAssistantBoundaryTests.configuresClarificationForMultipleMatches`

## Unsupported and medical boundaries

The focused local suite now carries two layers of deterministic local evidence for unsupported and medical boundaries. `ClinicAssistantBoundaryScenarioTests` drives the `/clinic-assistant` endpoint through MockMvc with the real `ClinicAssistantService` and a mocked `ClinicAssistantModel`, then proves the rendered transcript preserves the staff request and explicit refusal without fabricating activity. `ClinicAssistantBoundaryTests` continues to assert the configured `ClinicAssistantConfiguration.SYSTEM_PROMPT` boundary for unsupported or absent requests, read-only/no-mutation claims, veterinary diagnosis or treatment refusal, and multi-match clarification. This is PASS as mock-model endpoint-flow and configuration-boundary evidence only; it does **not** claim live-model compliance.

Historical prototype smoke evidence for those boundary responses remains linked at commit [`ee7397dbe3f15846ff7ba98139fee11ac21d4cb2`](https://github.com/JoranBergfeld/agentify-pet-clinic/blob/ee7397dbe3f15846ff7ba98139fee11ac21d4cb2/docs/prototype/azure-deployment-slice-evidence.md).

Deployed smoke refresh belongs to `Build the workshop Azure, Preflight, and cleanup path`.

## Redaction note

This document intentionally excludes credentials, tokens, local `.azure` contents, live resource identifiers, and any other sensitive environment values. The only sample prompts referenced here are PetClinic fixture questions already covered by the local tests above.
