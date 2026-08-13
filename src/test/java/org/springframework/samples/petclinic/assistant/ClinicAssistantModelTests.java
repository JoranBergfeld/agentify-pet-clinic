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

import java.util.Map;
import java.util.function.Consumer;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.mockito.ArgumentMatchers;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.memory.ChatMemory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalStateException;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

/**
 * Tests for {@link SpringAiClinicAssistantModel}.
 */
@DisabledInNativeImage
class ClinicAssistantModelTests {

	private final ChatClient chatClient = mock(ChatClient.class);

	private final ChatMemory memory = mock(ChatMemory.class);

	private final ChatClient.ChatClientRequestSpec request = mock(ChatClient.ChatClientRequestSpec.class);

	private final ChatClient.CallResponseSpec response = mock(ChatClient.CallResponseSpec.class);

	private final ChatClient.AdvisorSpec advisorSpec = mock(ChatClient.AdvisorSpec.class);

	private final SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(this.chatClient, this.memory);

	@BeforeEach
	void setUp() {
		given(this.chatClient.prompt()).willReturn(this.request);
		given(this.request.advisors(ArgumentMatchers.<Consumer<ChatClient.AdvisorSpec>>any()))
			.willAnswer(invocation -> {
				Consumer<ChatClient.AdvisorSpec> advisors = invocation.getArgument(0);
				advisors.accept(this.advisorSpec);
				return this.request;
			});
		given(this.request.toolContext(anyMap())).willReturn(this.request);
		given(this.request.user(anyString())).willReturn(this.request);
		given(this.request.call()).willReturn(this.response);
	}

	@Test
	void passesConversationIdAndActivityLogToTheChatClient() {
		given(this.response.content()).willReturn("George Franklin owns Leo.");

		ClinicAssistantModel.Reply reply = this.model.answer("conversation-1", "Who owns Leo?");

		assertThat(reply.answer()).isEqualTo("George Franklin owns Leo.");
		assertThat(reply.activities()).isEmpty();
		verify(this.advisorSpec).param(ChatMemory.CONVERSATION_ID, "conversation-1");
		verify(this.request).toolContext(ArgumentMatchers.<Map<String, Object>>argThat(
				context -> context.get(ClinicAssistantActivityLog.CONTEXT_KEY) instanceof ClinicAssistantActivityLog));
	}

	@Test
	void rejectsANullModelAnswer() {
		given(this.response.content()).willReturn(null);

		assertThatIllegalStateException().isThrownBy(() -> this.model.answer("conversation-1", "Who owns Leo?"))
			.withMessage("Clinic Assistant returned no answer");
	}

	@Test
	void resetClearsConversationMemory() {
		this.model.reset("conversation-1");

		verify(this.memory).clear("conversation-1");
	}

}
