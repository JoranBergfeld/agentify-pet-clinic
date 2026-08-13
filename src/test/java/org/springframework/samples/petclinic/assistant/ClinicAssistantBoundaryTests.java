/*
 * Copyright 2012-2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.springframework.samples.petclinic.assistant;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for the configured Clinic Assistant system boundary.
 */
class ClinicAssistantBoundaryTests {

	@Test
	void configuresAdmissionsForUnsupportedOrAbsentRequests() {
		assertThat(ClinicAssistantConfiguration.SYSTEM_PROMPT)
			.contains("Admit when records are absent or a request is unsupported.");
	}

	@Test
	void configuresReadOnlyRepliesWithoutMutationClaims() {
		assertThat(ClinicAssistantConfiguration.SYSTEM_PROMPT)
			.contains("You are read-only and must never claim to change PetClinic data.");
	}

	@Test
	void configuresNoVeterinaryDiagnosisOrTreatmentAdvice() {
		assertThat(ClinicAssistantConfiguration.SYSTEM_PROMPT)
			.contains("Do not provide veterinary diagnosis or treatment advice.");
	}

	@Test
	void configuresClarificationForMultipleMatches() {
		assertThat(ClinicAssistantConfiguration.SYSTEM_PROMPT)
			.contains("When multiple people or pets match, list candidates and ask for clarification.");
	}

}
