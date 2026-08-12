package org.springframework.samples.petclinic.assistant;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/clinic-assistant")
class ClinicAssistantController {

	private final ClinicAssistantService assistant;

	ClinicAssistantController(ClinicAssistantService assistant) {
		this.assistant = assistant;
	}

	@PostMapping
	AssistantResponse ask(@Valid @RequestBody AssistantRequest request) {
		return new AssistantResponse(this.assistant.ask(request.message()));
	}

	record AssistantRequest(@NotBlank String message) {
	}

	record AssistantResponse(String answer) {
	}

}
