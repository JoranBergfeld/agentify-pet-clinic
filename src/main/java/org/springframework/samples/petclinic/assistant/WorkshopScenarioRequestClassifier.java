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
 * Implements the limited grammar used by the PetClinic workshop safety scenarios. This is
 * not a universal natural-language classifier; requests outside the explicit workshop
 * grammar remain model-driven.
 */
final class WorkshopScenarioRequestClassifier {

	private static final Pattern CREATE_OR_ADD_RECORD = Pattern
		.compile("\\b(?:add|create)\\s+(?:(?:an?|the)\\s+)?(?:owner|pet|visit|vet|veterinarian|record)\\b"
				+ "(?!\\s+(?:(?:history|record)\\s+){0,2}(?:column|description|list|overview|report|summary|table|view)\\b)");

	private static final Pattern OTHER_RECORD_MUTATION = Pattern.compile(
			"\\b(?:change|delete|edit|modify|remove|set|update)\\s+(?:(?:an?|the)\\s+)?(?:owner|pet|visit|vet|veterinarian|record)(?:\\s+record)?\\b");

	private static final Pattern VISIT_SCHEDULING_REQUEST = Pattern
		.compile("\\b(?:book|cancel|schedule)\\s+(?:(?:an?|the)\\s+)?visit\\b");

	private static final Pattern DIRECT_FIELD_ASSIGNMENT = Pattern.compile(
			"\\b(?:change|edit|modify|set|update)\\s+(?:(?:the\\s+)?(?:owner|pet|visit|vet|veterinarian)(?:\\s+[\\p{L}\\d][\\p{L}\\d-]*){0,4}(?:'s)?\\s+|(?:[\\p{L}\\d][\\p{L}\\d-]*\\s+){0,3}[\\p{L}\\d][\\p{L}\\d-]*'s\\s+)(?:address|birth\\s+date|birthdate|city|date|description|first\\s+name|last\\s+name|name|owner|specialt(?:y|ies)|telephone|type)\\s+to\\b");

	private static final Pattern DIRECT_COLLECTION_FIELD_MUTATION = Pattern.compile(
			"\\b(?:add|remove)\\s+[^.!?]{1,60}\\s+(?:from|to)\\s+[^.!?]{0,60}\\b(?:pets?|visits?|specialt(?:y|ies))\\b");

	private static final Pattern DIRECT_MEDICAL_ACTION = Pattern
		.compile("(?:^|[.!?]\\s*)\\s*(?:please\\s+)?(?:diagnose|treat)\\s+(?:(?:an?|the)\\s+)?[\\p{L}\\d][\\p{L}\\d'-]*"
				+ "|\\b(?:can|could|should|would|will)\\s+(?:i|we|you)\\s+(?:diagnose|treat)\\b");

	private static final Pattern MEDICAL_ADVICE_REQUEST = Pattern.compile(
			"\\b(?:recommend|suggest|prescribe)\\s+(?:(?:a|the)\\s+)?(?:diagnosis|medicine|medication|treatment)\\b"
					+ "|\\b(?:diagnosis|medicine|medication|treatment)(?:\\s+and\\s+(?:diagnosis|medicine|medication|treatment))?\\s+should\\b"
					+ "|\\b(?:what|which)\\s+(?:diagnosis|medicine|medication|treatment)(?:\\s+and\\s+(?:diagnosis|medicine|medication|treatment|dosage|dose))?\\s+to\\s+(?:give|administer|use)\\b"
					+ "|\\bshould\\s+i\\s+(?:give|administer|prescribe|use)\\s+[^.!?]{0,40}\\b(?:medicine|medication|treatment)\\b"
					+ "|\\bhow\\s+much\\s+[^.!?]{1,60}\\bshould\\s+[^.!?]{1,40}\\btake\\b"
					+ "|\\b(?:what|which)\\s+(?:dosage|dose)\\b");

	ClinicAssistantOutcome classify(String message) {
		String normalized = message.toLowerCase(Locale.ROOT);
		if (isMedicalAdviceRequest(normalized)) {
			return ClinicAssistantOutcome.MEDICAL_REFUSAL;
		}
		if (isWriteRequest(normalized)) {
			return ClinicAssistantOutcome.READ_ONLY_REFUSAL;
		}
		return ClinicAssistantOutcome.NORMAL;
	}

	private boolean isMedicalAdviceRequest(String message) {
		return DIRECT_MEDICAL_ACTION.matcher(message).find() || MEDICAL_ADVICE_REQUEST.matcher(message).find();
	}

	private boolean isWriteRequest(String message) {
		return CREATE_OR_ADD_RECORD.matcher(message).find() || OTHER_RECORD_MUTATION.matcher(message).find()
				|| VISIT_SCHEDULING_REQUEST.matcher(message).find() || DIRECT_FIELD_ASSIGNMENT.matcher(message).find()
				|| DIRECT_COLLECTION_FIELD_MUTATION.matcher(message).find();
	}

}
