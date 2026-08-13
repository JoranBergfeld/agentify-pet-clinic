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
import org.springframework.web.util.HtmlUtils;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ClinicAssistantController.class)
@Import({ ClinicAssistantService.class, WebConfiguration.class })
@DisabledInNativeImage
@DisabledInAotMode
class ClinicAssistantBoundaryScenarioTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private ClinicAssistantModel model;

	@Test
	void rendersReadOnlyRefusalForAttemptedWriteRequestsWithoutFabricatedActivity() throws Exception {
		assertTranscriptWithoutFabricatedActivity("Delete owner George Franklin from PetClinic.",
				"I can't delete owners or change PetClinic records. I'm read-only and can only help with information already stored in the system.");
	}

	@Test
	void rendersMedicalAdviceRefusalWithoutFabricatedActivity() throws Exception {
		assertTranscriptWithoutFabricatedActivity(
				"My dog has bloody diarrhea. What diagnosis and treatment should I give right now?",
				"I can't provide veterinary diagnosis or treatment advice. Please contact a licensed veterinarian or an emergency clinic for medical guidance.");
	}

	private void assertTranscriptWithoutFabricatedActivity(String userMessage, String assistantReply) throws Exception {
		given(this.model.answer(anyString(), eq(userMessage)))
			.willReturn(new ClinicAssistantModel.Reply(assistantReply, List.of()));

		MvcResult postResult = this.mockMvc.perform(post("/clinic-assistant").param("message", userMessage))
			.andExpect(status().is3xxRedirection())
			.andExpect(redirectedUrl("/clinic-assistant"))
			.andReturn();
		MockHttpSession session = (MockHttpSession) postResult.getRequest().getSession(false);
		ClinicAssistantConversation conversation = (ClinicAssistantConversation) session
			.getAttribute(ClinicAssistantController.CONVERSATION_ATTRIBUTE);

		assertThat(conversation.turns()).containsExactly(
				new ClinicAssistantConversation.Turn("user", userMessage, List.of()),
				new ClinicAssistantConversation.Turn("assistant", assistantReply, List.of()));

		MvcResult transcriptResult = this.mockMvc.perform(get("/clinic-assistant").session(session))
			.andExpect(status().isOk())
			.andReturn();

		assertThat(transcriptResult.getResponse().getContentAsString()).contains(HtmlUtils.htmlEscape(userMessage))
			.contains(HtmlUtils.htmlEscape(assistantReply))
			.doesNotContain("assistant-activity");
	}

}
