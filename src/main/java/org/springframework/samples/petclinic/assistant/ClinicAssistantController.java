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

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

import org.springframework.stereotype.Controller;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.WebDataBinder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.InitBinder;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.SessionAttributes;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

@Controller
@RequestMapping("/clinic-assistant")
@SessionAttributes(ClinicAssistantController.CONVERSATION_ATTRIBUTE)
class ClinicAssistantController {

	static final String CONVERSATION_ATTRIBUTE = "clinicAssistantConversation";

	private static final String VIEWS_CLINIC_ASSISTANT = "assistant/clinicAssistant";

	private final ClinicAssistantService assistant;

	ClinicAssistantController(ClinicAssistantService assistant) {
		this.assistant = assistant;
	}

	@ModelAttribute(CONVERSATION_ATTRIBUTE)
	public ClinicAssistantConversation conversation() {
		return new ClinicAssistantConversation();
	}

	@ModelAttribute("assistantRequest")
	public AssistantRequest request() {
		return new AssistantRequest();
	}

	@InitBinder(CONVERSATION_ATTRIBUTE)
	void disallowConversationBinding(WebDataBinder binder) {
		binder.setDisallowedFields("*");
	}

	@GetMapping
	public String show() {
		return VIEWS_CLINIC_ASSISTANT;
	}

	@PostMapping
	public String ask(@Valid @ModelAttribute("assistantRequest") AssistantRequest request, BindingResult binding,
			@ModelAttribute(CONVERSATION_ATTRIBUTE) ClinicAssistantConversation conversation) {
		if (binding.hasErrors()) {
			return VIEWS_CLINIC_ASSISTANT;
		}
		this.assistant.ask(conversation, request.getMessage());
		return "redirect:/clinic-assistant";
	}

	@PostMapping("/reset")
	public String reset(@ModelAttribute(CONVERSATION_ATTRIBUTE) ClinicAssistantConversation conversation,
			RedirectAttributes redirectAttributes) {
		this.assistant.reset(conversation);
		redirectAttributes.addFlashAttribute("assistantReset", "complete");
		return "redirect:/clinic-assistant";
	}

	public static final class AssistantRequest {

		@NotBlank
		private String message = "";

		public String getMessage() {
			return this.message;
		}

		public void setMessage(String message) {
			this.message = message;
		}

	}

}
