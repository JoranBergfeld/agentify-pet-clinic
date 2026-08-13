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

import jakarta.servlet.http.HttpSessionEvent;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpSession;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/**
 * Tests for {@link ClinicAssistantSessionListener}.
 */
class ClinicAssistantSessionListenerTests {

	private final ClinicAssistantModel model = mock(ClinicAssistantModel.class);

	private final ClinicAssistantSessionListener listener = new ClinicAssistantSessionListener(
			new ClinicAssistantService(this.model));

	@Test
	void expiresTheConversationWhenTheSessionEnds() {
		MockHttpSession session = new MockHttpSession();
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		conversation.addUser("Who owns Leo?");
		session.setAttribute(ClinicAssistantController.CONVERSATION_ATTRIBUTE, conversation);

		this.listener.sessionDestroyed(new HttpSessionEvent(session));

		verify(this.model).reset(conversation.id());
		assertThat(conversation.turns()).isEmpty();
	}

	@Test
	void ignoresSessionsWithoutTheAssistantConversation() {
		MockHttpSession session = new MockHttpSession();

		this.listener.sessionDestroyed(new HttpSessionEvent(session));

		verifyNoInteractions(this.model);
	}

	@Test
	void ignoresInvalidatedSessionsDuringShutdown() {
		MockHttpSession session = new MockHttpSession();
		session.invalidate();

		assertThatCode(() -> this.listener.sessionDestroyed(new HttpSessionEvent(session))).doesNotThrowAnyException();
		verifyNoInteractions(this.model);
	}

}
