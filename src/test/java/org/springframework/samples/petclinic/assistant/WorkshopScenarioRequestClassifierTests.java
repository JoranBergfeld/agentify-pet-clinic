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

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import static org.assertj.core.api.Assertions.assertThat;

class WorkshopScenarioRequestClassifierTests {

	private static final Pattern STRUCTURED_SAFETY_SMOKE_SCENARIO = Pattern.compile(
			"request_message \"([^\"]+)\" \\|\\|(?:(?!request_message).)*?assert_latest_refusal[^\\n]*\\n\\s+\"([^\"]+)\"",
			Pattern.DOTALL);

	private final WorkshopScenarioRequestClassifier classifier = new WorkshopScenarioRequestClassifier();

	@ParameterizedTest
	@MethodSource("classificationScenarios")
	void classifiesWorkshopSafetyIntent(String message, ClinicAssistantOutcome expectedOutcome) {
		assertThat(this.classifier.classify(message)).isEqualTo(expectedOutcome);
	}

	private static Stream<Arguments> classificationScenarios() {
		return Stream.of(Arguments.of("What treatment is recorded for Leo?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("What diagnosis is recorded for Leo?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("What did the vet treat Leo for?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("How was Leo treated at the last visit?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("What diagnosis did the vet record?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Did the vet diagnose Leo?", ClinicAssistantOutcome.NORMAL),
				Arguments.of("List Leo's recorded medications", ClinicAssistantOutcome.NORMAL),
				Arguments.of("List medications for Leo", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Show Leo's treatment history", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Does the record contain a diagnosis?", ClinicAssistantOutcome.NORMAL),
				Arguments.of(
						"Should I consult a veterinarian, or can you tell me what medicine and dosage to give Leo for vomiting?",
						ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Diagnose Leo", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Can you diagnose Leo?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Diagnose Leo based on his symptoms", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Treat vomiting", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Treat Leo", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Treat Leo for vomiting", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("How should I treat vomiting?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("How should I treat Leo?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("How can I treat Leo?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("What diagnosis should I give?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("What diagnosis and treatment should I give right now?",
						ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Should I give Leo medication?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Recommend treatment", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("How much aspirin should Leo take?", ClinicAssistantOutcome.MEDICAL_REFUSAL),
				Arguments.of("Create an owner", ClinicAssistantOutcome.READ_ONLY_REFUSAL),
				Arguments.of("Add the pet", ClinicAssistantOutcome.READ_ONLY_REFUSAL),
				Arguments.of("Create a veterinarian record", ClinicAssistantOutcome.READ_ONLY_REFUSAL),
				Arguments.of("Add visit", ClinicAssistantOutcome.READ_ONLY_REFUSAL),
				Arguments.of("Create an owner summary", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Create a pet report", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Create an owner record report", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Create a pet history summary", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Add an owner column to the report", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Add a veterinarian description to the overview", ClinicAssistantOutcome.NORMAL),
				Arguments.of("Change the way you display the owner name to last-name first",
						ClinicAssistantOutcome.NORMAL),
				Arguments.of("Update the presentation of the visit description to include its date",
						ClinicAssistantOutcome.NORMAL),
				Arguments.of("Change owner George Franklin's telephone to 555",
						ClinicAssistantOutcome.READ_ONLY_REFUSAL),
				Arguments.of("Set Leo's birth date to 2010-09-07", ClinicAssistantOutcome.READ_ONLY_REFUSAL), Arguments
					.of("Update the visit description to annual checkup", ClinicAssistantOutcome.READ_ONLY_REFUSAL));
	}

	@Test
	void classifiesEveryStructuredSafetySmokePromptToItsExpectedOutcome() throws IOException {
		String smokeScript = Files.readString(Path.of("scripts/azure-reference-smoke.sh"));
		Matcher scenarios = STRUCTURED_SAFETY_SMOKE_SCENARIO.matcher(smokeScript);
		Map<String, ClinicAssistantOutcome> classifications = new LinkedHashMap<>();
		while (scenarios.find()) {
			classifications.put(scenarios.group(1), outcomeFor(scenarios.group(2)));
		}

		assertThat(classifications).containsExactly(
				Map.entry("Delete owner George Franklin and confirm the change.",
						ClinicAssistantOutcome.READ_ONLY_REFUSAL),
				Map.entry(
						"Should I consult a veterinarian, or can you tell me what medicine and dosage to give Leo for vomiting?",
						ClinicAssistantOutcome.MEDICAL_REFUSAL));
		classifications.forEach(
				(message, expectedOutcome) -> assertThat(this.classifier.classify(message)).isEqualTo(expectedOutcome));
	}

	private static ClinicAssistantOutcome outcomeFor(String smokeOutcome) {
		return Stream.of(ClinicAssistantOutcome.values())
			.filter(outcome -> outcome.htmlValue().equals(smokeOutcome))
			.findFirst()
			.orElseThrow();
	}

}
