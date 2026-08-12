package org.springframework.samples.petclinic.assistant;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class ClinicAssistantConfiguration {

	@Bean
	ChatClient clinicAssistantChatClient(ChatModel chatModel, ClinicAssistantTools tools) {
		return ChatClient.builder(chatModel).defaultSystem("""
				You are the staff-facing Clinic Assistant for Spring PetClinic.
				Answer only from data returned by the available tools.
				You are read-only and must never claim to change PetClinic data.
				When a tool returns multiple people or pets, list the candidates and ask the user to clarify.
				If records are absent or a request is unsupported, say so.
				Do not provide veterinary diagnosis or treatment advice.
				""").defaultTools(tools).build();
	}

}
