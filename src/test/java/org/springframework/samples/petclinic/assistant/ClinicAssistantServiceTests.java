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
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

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
		given(this.model.answer(conversation.id(), "Who owns Leo?")).willReturn(new ClinicAssistantModel.Reply(
				"George Franklin owns Leo.", List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));

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

		verify(this.model).reset(conversation.id());
		assertThat(conversation.turns()).isEmpty();
	}

	@Test
	void doesNotRetainAnOrphanUserTurnWhenTheModelFails() {
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		IllegalStateException failure = new IllegalStateException("tool failure");
		given(this.model.answer(conversation.id(), "Who owns Basil?")).willThrow(failure);

		Throwable thrown = catchThrowable(() -> this.service.ask(conversation, "Who owns Basil?"));

		assertThat(thrown).isSameAs(failure);
		assertThat(conversation.turns()).isEmpty();
	}

	@Test
	void serializesOverlappingQuestionsPerConversation() throws Exception {
		SerializingModel serializingModel = new SerializingModel();
		ClinicAssistantService service = new ClinicAssistantService(serializingModel);
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		ExecutorService executor = Executors.newFixedThreadPool(2);

		try {
			Future<?> firstQuestion = executor.submit(() -> service.ask(conversation, "Who owns Leo?"));
			serializingModel.awaitFirstAnswerStarted();
			Future<?> secondQuestion = executor.submit(() -> service.ask(conversation, "Who owns Basil?"));

			serializingModel.completeFirstAnswer();
			firstQuestion.get(5, TimeUnit.SECONDS);
			secondQuestion.get(5, TimeUnit.SECONDS);
		}
		finally {
			executor.shutdownNow();
		}

		assertThat(conversation.turns()).containsExactly(
				new ClinicAssistantConversation.Turn("user", "Who owns Leo?", List.of()),
				new ClinicAssistantConversation.Turn("assistant", "George Franklin owns Leo.", List.of()),
				new ClinicAssistantConversation.Turn("user", "Who owns Basil?", List.of()),
				new ClinicAssistantConversation.Turn("assistant", "Betty Davis owns Basil.", List.of()));
	}

	@Test
	void serializesResetAgainstAnInFlightQuestion() throws Exception {
		SerializingModel serializingModel = new SerializingModel();
		ClinicAssistantService service = new ClinicAssistantService(serializingModel);
		ClinicAssistantConversation conversation = new ClinicAssistantConversation();
		ExecutorService executor = Executors.newFixedThreadPool(2);

		try {
			Future<?> question = executor.submit(() -> service.ask(conversation, "Who owns Leo?"));
			serializingModel.awaitFirstAnswerStarted();
			Future<?> reset = executor.submit(() -> service.reset(conversation));

			serializingModel.completeFirstAnswer();
			question.get(5, TimeUnit.SECONDS);
			reset.get(5, TimeUnit.SECONDS);
		}
		finally {
			executor.shutdownNow();
		}

		assertThat(conversation.turns()).isEmpty();
	}

	private static final class SerializingModel implements ClinicAssistantModel {

		private final Semaphore modelOperation = new Semaphore(1);

		private final CountDownLatch firstAnswerStarted = new CountDownLatch(1);

		private final CountDownLatch allowFirstAnswerToComplete = new CountDownLatch(1);

		@Override
		public Reply answer(String conversationId, String message) {
			acquireExclusiveOperation("answer");
			try {
				if ("Who owns Leo?".equals(message)) {
					this.firstAnswerStarted.countDown();
					await(this.allowFirstAnswerToComplete, "first answer completion");
					return new Reply("George Franklin owns Leo.", List.of());
				}
				if ("Who owns Basil?".equals(message)) {
					return new Reply("Betty Davis owns Basil.", List.of());
				}
				throw new IllegalArgumentException("Unexpected message: " + message);
			}
			finally {
				this.modelOperation.release();
			}
		}

		@Override
		public void reset(String conversationId) {
			acquireExclusiveOperation("reset");
			this.modelOperation.release();
		}

		void awaitFirstAnswerStarted() {
			await(this.firstAnswerStarted, "first answer started");
		}

		void completeFirstAnswer() {
			this.allowFirstAnswerToComplete.countDown();
		}

		private void acquireExclusiveOperation(String operation) {
			assertThat(this.modelOperation.tryAcquire())
				.as("expected %s to wait for the in-flight conversation operation", operation)
				.isTrue();
		}

		private static void await(CountDownLatch latch, String description) {
			try {
				assertThat(latch.await(5, TimeUnit.SECONDS)).as(description).isTrue();
			}
			catch (InterruptedException ex) {
				Thread.currentThread().interrupt();
				throw new AssertionError("Interrupted while waiting for " + description, ex);
			}
		}

	}

}
