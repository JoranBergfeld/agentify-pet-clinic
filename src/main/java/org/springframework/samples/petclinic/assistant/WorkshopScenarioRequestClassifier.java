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

/**
 * Recognizes only the explicit PetClinic mutation and medical-advice phrases used by the
 * workshop safety scenarios. This is intentionally a conservative deterministic boundary,
 * not a general natural-language intent classifier; other requests remain model-driven.
 */
final class WorkshopScenarioRequestClassifier {

	private static final Pattern RECORD_MUTATION_REQUEST = Pattern.compile(
			"\\b(?:add|change|create|delete|edit|modify|remove|set|update)\\s+(?:(?:an?|the)\\s+)?(?:owner|pet|visit|vet|veterinarian)(?:\\s+record)?\\b");

	private static final Pattern VISIT_SCHEDULING_REQUEST = Pattern
		.compile("\\b(?:book|cancel|schedule)\\s+(?:(?:an?|the)\\s+)?visit\\b");

	private static final Pattern DIRECT_FIELD_ASSIGNMENT = Pattern.compile(
			"\\b(?:change|edit|modify|set|update)\\s+[^.!?]{0,60}\\b(?:address|birth\\s+date|birthdate|city|date|description|first\\s+name|last\\s+name|name|owner|specialt(?:y|ies)|telephone|type)\\s+to\\b");

	private static final Pattern DIRECT_COLLECTION_FIELD_MUTATION = Pattern.compile(
			"\\b(?:add|remove)\\s+[^.!?]{1,60}\\s+(?:from|to)\\s+[^.!?]{0,60}\\b(?:pets?|visits?|specialt(?:y|ies))\\b");

	private static final Pattern MEDICAL_REQUEST = Pattern
		.compile("\\b(diagnose|diagnosis|dosage|dose|medicine|medication|treat|treatment)\\b");

	ClinicAssistantOutcome classify(String message) {
		String normalized = message.toLowerCase(Locale.ROOT);
		if (MEDICAL_REQUEST.matcher(normalized).find()) {
			return ClinicAssistantOutcome.MEDICAL_REFUSAL;
		}
		if (RECORD_MUTATION_REQUEST.matcher(normalized).find() || VISIT_SCHEDULING_REQUEST.matcher(normalized).find()
				|| DIRECT_FIELD_ASSIGNMENT.matcher(normalized).find()
				|| DIRECT_COLLECTION_FIELD_MUTATION.matcher(normalized).find()) {
			return ClinicAssistantOutcome.READ_ONLY_REFUSAL;
		}
		return ClinicAssistantOutcome.NORMAL;
	}

}
