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

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.memory.MessageWindowChatMemory;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class ClinicAssistantConfiguration {

	@Bean
	ChatMemory clinicAssistantMemory() {
		return MessageWindowChatMemory.builder().maxMessages(20).build();
	}

	@Bean
	ChatClient clinicAssistantChatClient(ChatModel chatModel, ChatMemory clinicAssistantMemory,
			ClinicAssistantTools tools) {
		return ChatClient.builder(chatModel)
			.defaultSystem("""
					You are the staff-facing Clinic Assistant for Spring PetClinic.
					Answer only from data returned by the available tools.
					Never claim to change PetClinic data.
					When multiple people or pets match, list candidates and ask for clarification.
					Admit when records are absent or a request is unsupported.
					Do not provide veterinary diagnosis or treatment advice.
					""")
			.defaultAdvisors(MessageChatMemoryAdvisor.builder(clinicAssistantMemory).build())
			.defaultTools(tools)
			.build();
	}

}
