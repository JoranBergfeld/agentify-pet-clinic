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

import java.util.Arrays;
import java.util.List;
import java.util.Map;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.messages.Message;
import org.springframework.stereotype.Component;

@Component
class SpringAiClinicAssistantModel implements ClinicAssistantModel {

	private static final int LOCK_STRIPES = 64;

	private final ChatClient chatClient;

	private final ChatMemory chatMemory;

	private final Object[] conversationLocks = createConversationLocks();

	SpringAiClinicAssistantModel(ChatClient chatClient, ChatMemory chatMemory) {
		this.chatClient = chatClient;
		this.chatMemory = chatMemory;
	}

	@Override
	public Reply answer(String conversationId, String message) {
		synchronized (conversationLock(conversationId)) {
			List<Message> priorMessages = snapshotConversation(conversationId);
			ClinicAssistantActivityLog activityLog = new ClinicAssistantActivityLog();
			String answer;
			try {
				answer = this.chatClient.prompt()
					.advisors(advisors -> advisors.param(ChatMemory.CONVERSATION_ID, conversationId))
					.toolContext(Map.of(ClinicAssistantActivityLog.CONTEXT_KEY, activityLog))
					.user(message)
					.call()
					.content();
			}
			catch (RuntimeException | Error ex) {
				restoreConversation(conversationId, priorMessages);
				throw ex;
			}
			if (answer == null) {
				restoreConversation(conversationId, priorMessages);
				throw new IllegalStateException("Clinic Assistant returned no answer");
			}
			return new Reply(answer, activityLog.snapshot());
		}
	}

	@Override
	public void reset(String conversationId) {
		synchronized (conversationLock(conversationId)) {
			this.chatMemory.clear(conversationId);
		}
	}

	private List<Message> snapshotConversation(String conversationId) {
		List<Message> messages = this.chatMemory.get(conversationId);
		return (messages != null) ? List.copyOf(messages) : List.of();
	}

	private void restoreConversation(String conversationId, List<Message> priorMessages) {
		this.chatMemory.clear(conversationId);
		if (!priorMessages.isEmpty()) {
			this.chatMemory.add(conversationId, priorMessages);
		}
	}

	private Object conversationLock(String conversationId) {
		return this.conversationLocks[Math.floorMod(conversationId.hashCode(), this.conversationLocks.length)];
	}

	private static Object[] createConversationLocks() {
		Object[] locks = new Object[LOCK_STRIPES];
		Arrays.setAll(locks, index -> new Object());
		return locks;
	}

}
