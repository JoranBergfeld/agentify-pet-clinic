package org.springframework.samples.petclinic.assistant;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ClinicAssistantController.class)
class ClinicAssistantControllerTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private ClinicAssistantService assistant;

	@Test
	void returnsTheAssistantAnswerAsJson() throws Exception {
		given(this.assistant.ask("Tell me about George Franklin")).willReturn("George Franklin owns Leo.");

		this.mockMvc.perform(post("/api/clinic-assistant").contentType(MediaType.APPLICATION_JSON).content("""
				{"message":"Tell me about George Franklin"}
				""")).andExpect(status().isOk()).andExpect(jsonPath("$.answer").value("George Franklin owns Leo."));
	}

	@Test
	void rejectsABlankMessage() throws Exception {
		this.mockMvc.perform(post("/api/clinic-assistant").contentType(MediaType.APPLICATION_JSON).content("""
				{"message":" "}
				""")).andExpect(status().isBadRequest());
	}

}
