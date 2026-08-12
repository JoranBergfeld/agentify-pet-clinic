package org.springframework.samples.petclinic.assistant;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;

@Service
class ClinicAssistantService {

	private final ChatClient chatClient;

	ClinicAssistantService(ChatClient chatClient) {
		this.chatClient = chatClient;
	}

	String ask(String message) {
		return this.chatClient.prompt().user(message).call().content();
	}

}
