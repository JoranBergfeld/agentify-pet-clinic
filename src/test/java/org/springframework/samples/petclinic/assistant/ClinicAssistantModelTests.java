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

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.mockito.ArgumentMatchers;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.api.Advisor;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalStateException;
import static org.assertj.core.api.Assertions.catchThrowable;
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
		TestChatMemory memory = new TestChatMemory();
		memory.add("conversation-1",
				List.of(new UserMessage("Who owns Leo?"), new AssistantMessage("George Franklin owns Leo.")));
		SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(this.chatClient, memory);

		model.reset("conversation-1");

		assertThat(memory.get("conversation-1")).isEmpty();
	}

	@Test
	void resetRejectsMemoryThatStillContainsMessagesAfterClear() {
		TestChatMemory memory = new StubbornChatMemory();
		memory.add("conversation-1",
				List.of(new UserMessage("Who owns Leo?"), new AssistantMessage("George Franklin owns Leo.")));
		SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(this.chatClient, memory);

		assertThatIllegalStateException().isThrownBy(() -> model.reset("conversation-1"))
			.withMessage("Clinic Assistant memory reset could not be verified");
	}

	@Test
	void serializesConcurrentAnswersForTheSameConversation() throws Exception {
		CountDownLatch promptEntered = new CountDownLatch(1);
		CountDownLatch releasePrompt = new CountDownLatch(1);
		AtomicInteger activePrompts = new AtomicInteger();
		AtomicInteger maxActivePrompts = new AtomicInteger();
		AtomicInteger promptExecutions = new AtomicInteger();
		ChatClient chatClient = scriptedChatClient(invocation -> {
			int active = activePrompts.incrementAndGet();
			maxActivePrompts.accumulateAndGet(active, Math::max);
			int execution = promptExecutions.incrementAndGet();
			try {
				if (execution == 1) {
					promptEntered.countDown();
					await(releasePrompt);
					return "George Franklin owns Leo.";
				}
				return "Betty Davis owns Basil.";
			}
			finally {
				activePrompts.decrementAndGet();
			}
		});
		SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(chatClient, new TestChatMemory());
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<ClinicAssistantModel.Reply> first = executor
				.submit(() -> model.answer("conversation-1", "Who owns Leo?"));
			await(promptEntered);
			Future<ClinicAssistantModel.Reply> second = executor
				.submit(() -> model.answer("conversation-1", "Who owns Basil?"));

			assertThat(catchThrowable(() -> second.get(250, TimeUnit.MILLISECONDS)))
				.isInstanceOf(TimeoutException.class);
			assertThat(maxActivePrompts.get()).isEqualTo(1);

			releasePrompt.countDown();

			assertThat(first.get(5, TimeUnit.SECONDS).answer()).isEqualTo("George Franklin owns Leo.");
			assertThat(second.get(5, TimeUnit.SECONDS).answer()).isEqualTo("Betty Davis owns Basil.");
			assertThat(maxActivePrompts.get()).isEqualTo(1);
		}
		finally {
			executor.shutdownNow();
		}
	}

	@Test
	void restoresPriorConversationMemoryWhenPromptFails() {
		TestChatMemory memory = new TestChatMemory();
		List<Message> priorMessages = List.of(new UserMessage("Who owns Leo?"),
				new AssistantMessage("George Franklin owns Leo."));
		memory.add("conversation-1", priorMessages);
		IllegalStateException failure = new IllegalStateException("tool failure");
		ChatClient chatClient = scriptedChatClient(invocation -> {
			memory.add(invocation.conversationId(),
					List.of(new UserMessage(invocation.userMessage()), new AssistantMessage("partial answer")));
			throw failure;
		});
		SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(chatClient, memory);

		Throwable thrown = catchThrowable(() -> model.answer("conversation-1", "Who owns Basil?"));

		assertThat(thrown).isSameAs(failure);
		assertThat(memory.get("conversation-1")).containsExactlyElementsOf(priorMessages);
	}

	@Test
	void restoresPriorConversationMemoryWhenTheModelReturnsNull() {
		TestChatMemory memory = new TestChatMemory();
		List<Message> priorMessages = List.of(new UserMessage("Who owns Leo?"),
				new AssistantMessage("George Franklin owns Leo."));
		memory.add("conversation-1", priorMessages);
		ChatClient chatClient = scriptedChatClient(invocation -> {
			memory.add(invocation.conversationId(),
					List.of(new UserMessage(invocation.userMessage()), new AssistantMessage("partial answer")));
			return null;
		});
		SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(chatClient, memory);

		assertThatIllegalStateException().isThrownBy(() -> model.answer("conversation-1", "Who owns Basil?"))
			.withMessage("Clinic Assistant returned no answer");
		assertThat(memory.get("conversation-1")).containsExactlyElementsOf(priorMessages);
	}

	@Test
	void serializesResetWithAnswerForTheSameConversation() throws Exception {
		ObservableChatMemory memory = new ObservableChatMemory();
		memory.add("conversation-1",
				List.of(new UserMessage("Who owns Leo?"), new AssistantMessage("George Franklin owns Leo.")));
		CountDownLatch promptEntered = new CountDownLatch(1);
		CountDownLatch releasePrompt = new CountDownLatch(1);
		ChatClient chatClient = scriptedChatClient(invocation -> {
			promptEntered.countDown();
			await(releasePrompt);
			return "George Franklin owns Leo.";
		});
		SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(chatClient, memory);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<ClinicAssistantModel.Reply> answer = executor
				.submit(() -> model.answer("conversation-1", "Who owns Leo?"));
			await(promptEntered);
			Future<?> reset = executor.submit(() -> {
				model.reset("conversation-1");
				return null;
			});

			assertThat(memory.clearCalled().await(250, TimeUnit.MILLISECONDS)).isFalse();

			releasePrompt.countDown();

			assertThat(answer.get(5, TimeUnit.SECONDS).answer()).isEqualTo("George Franklin owns Leo.");
			reset.get(5, TimeUnit.SECONDS);
			assertThat(memory.clearCalled().await(5, TimeUnit.SECONDS)).isTrue();
			assertThat(memory.get("conversation-1")).isEmpty();
		}
		finally {
			executor.shutdownNow();
		}
	}

	@Test
	void allowsDifferentConversationStripesToPromptConcurrently() throws Exception {
		SpringAiClinicAssistantModel stripedModel = new SpringAiClinicAssistantModel(scriptedChatClient(invocation -> {
			throw new AssertionError("placeholder");
		}), new TestChatMemory());
		String firstConversationId = "conversation-1";
		String secondConversationId = conversationIdOnDifferentStripe(stripedModel, firstConversationId);
		CountDownLatch firstPromptEntered = new CountDownLatch(1);
		CountDownLatch releaseFirstPrompt = new CountDownLatch(1);
		ChatClient chatClient = scriptedChatClient(invocation -> {
			if (invocation.conversationId().equals(firstConversationId)) {
				firstPromptEntered.countDown();
				await(releaseFirstPrompt);
				return "George Franklin owns Leo.";
			}
			return "Betty Davis owns Basil.";
		});
		SpringAiClinicAssistantModel model = new SpringAiClinicAssistantModel(chatClient, new TestChatMemory());
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<ClinicAssistantModel.Reply> first = executor
				.submit(() -> model.answer(firstConversationId, "Who owns Leo?"));
			await(firstPromptEntered);
			Future<ClinicAssistantModel.Reply> second = executor
				.submit(() -> model.answer(secondConversationId, "Who owns Basil?"));

			assertThat(second.get(5, TimeUnit.SECONDS).answer()).isEqualTo("Betty Davis owns Basil.");

			releaseFirstPrompt.countDown();

			assertThat(first.get(5, TimeUnit.SECONDS).answer()).isEqualTo("George Franklin owns Leo.");
		}
		finally {
			executor.shutdownNow();
		}
	}

	private static ChatClient scriptedChatClient(PromptBehavior behavior) {
		ChatClient chatClient = mock(ChatClient.class);
		given(chatClient.prompt()).willAnswer(invocation -> promptRequest(behavior));
		return chatClient;
	}

	private static ChatClient.ChatClientRequestSpec promptRequest(PromptBehavior behavior) {
		ChatClient.ChatClientRequestSpec request = mock(ChatClient.ChatClientRequestSpec.class);
		ChatClient.CallResponseSpec response = mock(ChatClient.CallResponseSpec.class);
		AtomicReference<String> conversationId = new AtomicReference<>();
		AtomicReference<String> userMessage = new AtomicReference<>();
		AtomicReference<Map<String, Object>> toolContext = new AtomicReference<>(Map.of());
		given(request.advisors(ArgumentMatchers.<Consumer<ChatClient.AdvisorSpec>>any())).willAnswer(invocation -> {
			Consumer<ChatClient.AdvisorSpec> advisors = invocation.getArgument(0);
			advisors.accept(advisorSpec(conversationId));
			return request;
		});
		given(request.toolContext(anyMap())).willAnswer(invocation -> {
			toolContext.set(invocation.getArgument(0));
			return request;
		});
		given(request.user(anyString())).willAnswer(invocation -> {
			userMessage.set(invocation.getArgument(0));
			return request;
		});
		given(request.call()).willReturn(response);
		given(response.content()).willAnswer(invocation -> behavior
			.execute(new PromptInvocation(conversationId.get(), userMessage.get(), toolContext.get())));
		return request;
	}

	private static ChatClient.AdvisorSpec advisorSpec(AtomicReference<String> conversationId) {
		return new ChatClient.AdvisorSpec() {
			@Override
			public ChatClient.AdvisorSpec param(String name, Object value) {
				if (ChatMemory.CONVERSATION_ID.equals(name)) {
					conversationId.set((String) value);
				}
				return this;
			}

			@Override
			public ChatClient.AdvisorSpec params(Map<String, Object> params) {
				params.forEach(this::param);
				return this;
			}

			@Override
			public ChatClient.AdvisorSpec advisors(Advisor... advisors) {
				return this;
			}

			@Override
			public ChatClient.AdvisorSpec advisors(List<Advisor> advisors) {
				return this;
			}
		};
	}

	private static String conversationIdOnDifferentStripe(SpringAiClinicAssistantModel model, String conversationId) {
		Object[] locks = conversationLocks(model);
		int stripe = Math.floorMod(conversationId.hashCode(), locks.length);
		for (int index = 1; index < 256; index++) {
			String candidate = conversationId + "-stripe-" + index;
			if (Math.floorMod(candidate.hashCode(), locks.length) != stripe) {
				return candidate;
			}
		}
		throw new AssertionError("Unable to find conversation on a different stripe");
	}

	private static Object[] conversationLocks(SpringAiClinicAssistantModel model) {
		try {
			Field field = SpringAiClinicAssistantModel.class.getDeclaredField("conversationLocks");
			field.setAccessible(true);
			return (Object[]) field.get(model);
		}
		catch (ReflectiveOperationException ex) {
			throw new AssertionError(ex);
		}
	}

	private static void await(CountDownLatch latch) {
		try {
			assertThat(latch.await(5, TimeUnit.SECONDS)).isTrue();
		}
		catch (InterruptedException ex) {
			Thread.currentThread().interrupt();
			throw new AssertionError(ex);
		}
	}

	@FunctionalInterface
	private interface PromptBehavior {

		String execute(PromptInvocation invocation);

	}

	private record PromptInvocation(String conversationId, String userMessage, Map<String, Object> toolContext) {
	}

	private static class TestChatMemory implements ChatMemory {

		private final Map<String, List<Message>> conversations = new ConcurrentHashMap<>();

		@Override
		public void add(String conversationId, List<Message> messages) {
			this.conversations.compute(conversationId, (key, existing) -> {
				List<Message> updated = new ArrayList<>(existing != null ? existing : List.of());
				updated.addAll(messages);
				return updated;
			});
		}

		@Override
		public List<Message> get(String conversationId) {
			return new ArrayList<>(this.conversations.getOrDefault(conversationId, List.of()));
		}

		@Override
		public void clear(String conversationId) {
			this.conversations.remove(conversationId);
		}

	}

	private static final class ObservableChatMemory extends TestChatMemory {

		private final CountDownLatch clearCalled = new CountDownLatch(1);

		@Override
		public void clear(String conversationId) {
			this.clearCalled.countDown();
			super.clear(conversationId);
		}

		CountDownLatch clearCalled() {
			return this.clearCalled;
		}

	}

	private static final class StubbornChatMemory extends TestChatMemory {

		@Override
		public void clear(String conversationId) {
		}

	}

}
