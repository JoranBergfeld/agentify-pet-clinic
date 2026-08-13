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

import org.springframework.stereotype.Service;

@Service
class ClinicAssistantService {

	private final ClinicAssistantModel model;

	ClinicAssistantService(ClinicAssistantModel model) {
		this.model = model;
	}

	void ask(ClinicAssistantConversation conversation, String message) {
		ClinicAssistantModel.Reply reply = this.model.answer(conversation.id(), message);
		conversation.addUser(message);
		conversation.addAssistant(reply.answer(), reply.activities());
	}

	void reset(ClinicAssistantConversation conversation) {
		this.model.reset(conversation.id());
		conversation.clear();
	}

}
