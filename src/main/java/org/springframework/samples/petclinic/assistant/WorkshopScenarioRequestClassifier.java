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

import java.util.Locale;
import java.util.regex.Pattern;

final class WorkshopScenarioRequestClassifier {

	private static final Pattern WRITE_ACTION = Pattern
		.compile("\\b(add|change|create|delete|edit|modify|remove|update)\\b");

	private static final Pattern WRITE_TARGET = Pattern.compile(
			"\\b(owner|owners|pet|pets|petclinic|record|records|vet|vets|veterinarian|veterinarians|visit|visits)\\b");

	private static final Pattern MEDICAL_REQUEST = Pattern
		.compile("\\b(diagnose|diagnosis|dosage|dose|medicine|medication|treat|treatment)\\b");

	ClinicAssistantOutcome classify(String message) {
		String normalized = message.toLowerCase(Locale.ROOT);
		if (MEDICAL_REQUEST.matcher(normalized).find()) {
			return ClinicAssistantOutcome.MEDICAL_REFUSAL;
		}
		if (WRITE_ACTION.matcher(normalized).find() && WRITE_TARGET.matcher(normalized).find()) {
			return ClinicAssistantOutcome.READ_ONLY_REFUSAL;
		}
		return ClinicAssistantOutcome.NORMAL;
	}

}
