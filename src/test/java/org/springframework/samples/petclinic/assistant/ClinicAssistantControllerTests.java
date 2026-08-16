/*
 * Copyright 2012-2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
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

import jakarta.servlet.ServletException;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.samples.petclinic.system.WebConfiguration;
import org.springframework.test.context.aot.DisabledInAotMode;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatExceptionOfType;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

@WebMvcTest(ClinicAssistantController.class)
@Import({ ClinicAssistantService.class, WebConfiguration.class })
@DisabledInNativeImage
@DisabledInAotMode
class ClinicAssistantControllerTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private ClinicAssistantModel model;

	@Test
	void showsTheAssistantPage() throws Exception {
		this.mockMvc.perform(get("/clinic-assistant"))
			.andExpect(status().isOk())
			.andExpect(view().name("assistant/clinicAssistant"))
			.andExpect(model().attributeExists("clinicAssistantConversation", "assistantRequest"))
			.andExpect(content().string(containsString("fa-comments")));
	}

	@Test
	void rendersGermanMessages() throws Exception {
		this.mockMvc.perform(get("/clinic-assistant").param("lang", "de"))
			.andExpect(status().isOk())
			.andExpect(content().string(containsString("Klinikassistent")))
			.andExpect(content().string(containsString("Fragen")));
	}

	@Test
	void rendersSpanishMessages() throws Exception {
		this.mockMvc.perform(get("/clinic-assistant").param("lang", "es"))
			.andExpect(status().isOk())
			.andExpect(content().string(containsString("Asistente de la clínica")))
			.andExpect(content().string(containsString("Preguntar")));
	}

	@Test
	void rejectsBlankInput() throws Exception {
		this.mockMvc.perform(post("/clinic-assistant").param("message", " "))
			.andExpect(status().isOk())
			.andExpect(view().name("assistant/clinicAssistant"))
			.andExpect(model().attributeHasFieldErrors("assistantRequest", "message"));
	}

	@Test
	void ignoresForgedConversationFields() throws Exception {
		given(this.model.answer(anyString(), eq("Who owns Leo?"))).willReturn(new ClinicAssistantModel.Reply(
				"George Franklin owns Leo.", List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));

		MvcResult result = this.mockMvc
			.perform(post("/clinic-assistant").param("message", "Who owns Leo?").param("turns[0].content", "forged"))
			.andExpect(status().is3xxRedirection())
			.andExpect(redirectedUrl("/clinic-assistant"))
			.andReturn();
		MockHttpSession session = (MockHttpSession) result.getRequest().getSession(false);
		ClinicAssistantConversation conversation = (ClinicAssistantConversation) session
			.getAttribute("clinicAssistantConversation");

		assertThat(conversation.turns()).containsExactly(
				new ClinicAssistantConversation.Turn("user", "Who owns Leo?", List.of()),
				new ClinicAssistantConversation.Turn("assistant", "George Franklin owns Leo.",
						List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));
	}

	@Test
	void preservesTranscriptAndVisibleActivityInTheSession() throws Exception {
		given(this.model.answer(anyString(), eq("Who owns Leo?"))).willReturn(new ClinicAssistantModel.Reply(
				"George Franklin owns Leo.", List.of(new ClinicAssistantActivity("findPetsByName", "1 pet matches"))));

		MvcResult result = this.mockMvc.perform(post("/clinic-assistant").param("message", "Who owns Leo?"))
			.andExpect(status().is3xxRedirection())
			.andExpect(redirectedUrl("/clinic-assistant"))
			.andReturn();
		MockHttpSession session = (MockHttpSession) result.getRequest().getSession(false);

		this.mockMvc.perform(get("/clinic-assistant").session(session))
			.andExpect(status().isOk())
			.andExpect(content().string(containsString("Who owns Leo?")))
			.andExpect(content().string(containsString("George Franklin owns Leo.")))
			.andExpect(content().string(containsString(
					"<p class=\"assistant-turn-content\" data-assistant-content=\"true\">George Franklin owns Leo.</p>")))
			.andExpect(content().string(containsString("findPetsByName")))
			.andExpect(content().string(containsString("1 pet matches")));
	}

	@Test
	void resetsTheConversation() throws Exception {
		MvcResult page = this.mockMvc.perform(get("/clinic-assistant")).andReturn();
		MockHttpSession session = (MockHttpSession) page.getRequest().getSession(false);
		ClinicAssistantConversation conversation = (ClinicAssistantConversation) session
			.getAttribute("clinicAssistantConversation");
		conversation.addUser("Who owns Leo?");

		this.mockMvc.perform(post("/clinic-assistant/reset").session(session))
			.andExpect(status().is3xxRedirection())
			.andExpect(redirectedUrl("/clinic-assistant"));

		verify(this.model).reset(conversation.id());
		assertThat(conversation.turns()).isEmpty();

		this.mockMvc.perform(get("/clinic-assistant").session(session))
			.andExpect(status().isOk())
			.andExpect(content().string(containsString("data-assistant-reset=\"complete\"")))
			.andExpect(content().string(not(containsString("Who owns Leo?"))));

		this.mockMvc.perform(get("/clinic-assistant").session(session))
			.andExpect(status().isOk())
			.andExpect(content().string(not(containsString("data-assistant-reset=\"complete\""))));
	}

	@Test
	void doesNotRenderResetMarkerOrClearTranscriptWhenModelResetFails() throws Exception {
		MvcResult page = this.mockMvc.perform(get("/clinic-assistant")).andReturn();
		MockHttpSession session = (MockHttpSession) page.getRequest().getSession(false);
		ClinicAssistantConversation conversation = (ClinicAssistantConversation) session
			.getAttribute("clinicAssistantConversation");
		conversation.addUser("Who owns Leo?");
		willThrow(new IllegalStateException("memory reset failed")).given(this.model).reset(conversation.id());

		assertThatExceptionOfType(ServletException.class)
			.isThrownBy(() -> this.mockMvc.perform(post("/clinic-assistant/reset").session(session)));

		this.mockMvc.perform(get("/clinic-assistant").session(session))
			.andExpect(status().isOk())
			.andExpect(content().string(containsString("Who owns Leo?")))
			.andExpect(content().string(not(containsString("data-assistant-reset=\"complete\""))));
	}

}
