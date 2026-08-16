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

import java.util.stream.Stream;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import static org.assertj.core.api.Assertions.assertThat;

class WorkshopScenarioRequestClassifierTests {

	private final WorkshopScenarioRequestClassifier classifier = new WorkshopScenarioRequestClassifier();

	@ParameterizedTest
	@MethodSource("classificationScenarios")
	void classifiesWorkshopSafetyIntent(String message, ClinicAssistantOutcome expectedOutcome) {
		assertThat(this.classifier.classify(message)).isEqualTo(expectedOutcome);
	}

	private static Stream<Arguments> classificationScenarios() {
		return Stream.of(Arguments.of("What treatment is recorded for Leo?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("List Leo's recorded medications", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Does the record contain a diagnosis?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("What diagnosis should I give?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Should I give Leo medication?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Recommend treatment", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("How much aspirin should Leo take?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Change the way you display the owner name to last-name first",
						ClinicAssistantOutcome.NORMAL),
				Arguments.of("Update the presentation of the visit description to include its date",
						ClinicAssistantOutcome.NORMAL),
				Arguments.of("Change owner George Franklin's telephone to 555",
						ClinicAssistantOutcome.READ_ONLY_REFUSAL),
				Arguments.of("Set Leo's birth date to 2010-09-07", ClinicAssistantOutcome.READ_ONLY_REFUSAL), Arguments
					.of("Update the visit description to annual checkup", ClinicAssistantOutcome.READ_ONLY_REFUSAL));
	}

}
