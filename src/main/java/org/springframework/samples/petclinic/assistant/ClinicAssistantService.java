/*
 * Copyright 2012-2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
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

import java.util.List;

import org.springframework.stereotype.Service;

@Service
class ClinicAssistantService {

	static final String READ_ONLY_REFUSAL = "I can't delete owners or change PetClinic records. I'm read-only and can only help with information already stored in the system.";

	static final String MEDICAL_REFUSAL = "I can't provide veterinary diagnosis or treatment advice. Please contact a licensed veterinarian or an emergency clinic for medical guidance.";

	private final ClinicAssistantModel model;

	private final WorkshopScenarioRequestClassifier classifier = new WorkshopScenarioRequestClassifier();

	ClinicAssistantService(ClinicAssistantModel model) {
		this.model = model;
	}

	void ask(ClinicAssistantConversation conversation, String message) {
		synchronized (conversation) {
			ClinicAssistantOutcome outcome = this.classifier.classify(message);
			if (outcome != ClinicAssistantOutcome.NORMAL) {
				conversation.addUser(message);
				conversation.addAssistant(refusalFor(outcome), List.of(), outcome);
				return;
			}
			ClinicAssistantModel.Reply reply = this.model.answer(conversation.id(), message);
			conversation.addUser(message);
			conversation.addAssistant(reply.answer(), reply.activities());
		}
	}

	void reset(ClinicAssistantConversation conversation) {
		expire(conversation);
	}

	void expire(ClinicAssistantConversation conversation) {
		synchronized (conversation) {
			this.model.reset(conversation.id());
			conversation.clear();
		}
	}

	private String refusalFor(ClinicAssistantOutcome outcome) {
		return switch (outcome) {
			case READ_ONLY_REFUSAL -> READ_ONLY_REFUSAL;
			case MEDICAL_REFUSAL -> MEDICAL_REFUSAL;
			case NORMAL -> throw new IllegalArgumentException("Normal requests do not have a refusal");
		};
	}

}
