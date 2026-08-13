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
import java.util.UUID;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatExceptionOfType;

/**
 * Tests for {@link ClinicAssistantConversation}.
 */
class ClinicAssistantConversationTests {

	@Test
	void createsAUuidConversationWithImmutableTurns() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();

		assertThat(conversation.id()).isInstanceOf(UUID.class);
		assertThat(conversation.turns()).isEmpty();
		assertThatExceptionOfType(UnsupportedOperationException.class).isThrownBy(() -> conversation.turns()
			.add(new ClinicAssistantConversation.Turn("user", "Who owns Leo?", List.of())));
	}

	@Test
	void recordsUserAndAssistantTurnsAndCanClearThem() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		List<ClinicAssistantActivity> activities = List
			.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"));

		conversation.addUser("Who owns Leo?");
		conversation.addAssistant("George Franklin owns Leo.", activities);

		assertThat(conversation.turns()).containsExactly(
				new ClinicAssistantConversation.Turn("user", "Who owns Leo?", List.of()),
				new ClinicAssistantConversation.Turn("assistant", "George Franklin owns Leo.", activities));

		conversation.clear();

		assertThat(conversation.turns()).isEmpty();
	}

}
