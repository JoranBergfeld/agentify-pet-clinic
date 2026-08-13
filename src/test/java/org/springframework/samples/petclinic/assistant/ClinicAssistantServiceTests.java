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

import java.util.List;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowable;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

/**
 * Tests for {@link ClinicAssistantService}.
 */
class ClinicAssistantServiceTests {

	private final ClinicAssistantModel model = mock(ClinicAssistantModel.class);

	private final ClinicAssistantService service = new ClinicAssistantService(this.model);

	@Test
	void recordsTheUserAnswerAndVisibleActivity() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		given(this.model.answer(conversation.id().toString(), "Who owns Leo?"))
			.willReturn(new ClinicAssistantModel.Reply("George Franklin owns Leo.",
					List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));

		this.service.ask(conversation, "Who owns Leo?");

		assertThat(conversation.turns()).containsExactly(
				new ClinicAssistantConversation.Turn("user", "Who owns Leo?", List.of()),
				new ClinicAssistantConversation.Turn("assistant", "George Franklin owns Leo.",
						List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));
	}

	@Test
	void resetsModelMemoryAndTheVisibleTranscript() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		conversation.addUser("Who owns Leo?");

		this.service.reset(conversation);

		verify(this.model).reset(conversation.id().toString());
		assertThat(conversation.turns()).isEmpty();
	}

	@Test
	void doesNotRetainAnOrphanUserTurnWhenTheModelFails() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		IllegalStateException failure = new IllegalStateException("tool failure");
		given(this.model.answer(conversation.id().toString(), "Who owns Basil?")).willThrow(failure);

		Throwable thrown = catchThrowable(() -> this.service.ask(conversation, "Who owns Basil?"));

		assertThat(thrown).isSameAs(failure);
		assertThat(conversation.turns()).isEmpty();
	}

}
