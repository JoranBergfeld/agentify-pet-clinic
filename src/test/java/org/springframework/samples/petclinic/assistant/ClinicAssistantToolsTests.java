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
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.springframework.ai.chat.model.ToolContext;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalStateException;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;

/**
 * Tests for {@link ClinicAssistantTools}.
 */
@DisabledInNativeImage
class ClinicAssistantToolsTests {

	private final ClinicQueryService queries = mock(ClinicQueryService.class);

	private final ClinicAssistantTools tools = new ClinicAssistantTools(this.queries);

	@Test
	void returnsPurposeBuiltRecordsAndVisibleActivity() {
		ClinicQueryService.OwnerSummary owner = new ClinicQueryService.OwnerSummary(2, "Betty Davis", "Madison",
				List.of());
		ClinicQueryService.PetSummary pet = new ClinicQueryService.PetSummary(2, "Basil", "hamster", 2, "Betty Davis",
				List.of());
		ClinicQueryService.VeterinarianSummary vet = new ClinicQueryService.VeterinarianSummary(2, "Helen Leary",
				List.of("radiology"));
		given(this.queries.findOwners("Davis")).willReturn(List.of(owner));
		given(this.queries.findPets("Basil")).willReturn(List.of(pet));
		given(this.queries.listVeterinarians()).willReturn(List.of(vet));
		ClinicAssistantActivityLog log = new ClinicAssistantActivityLog();
		ToolContext context = new ToolContext(Map.of(ClinicAssistantActivityLog.CONTEXT_KEY, log));

		assertThat(this.tools.findOwnersByLastName("Davis", context)).containsExactly(owner);
		assertThat(this.tools.findPetsByName("Basil", context)).containsExactly(pet);
		assertThat(this.tools.listVeterinarians(context)).containsExactly(vet);
		assertThat(log.snapshot()).containsExactly(
				new ClinicAssistantActivity("findOwnersByLastName", "1 owner matches"),
				new ClinicAssistantActivity("findPetsByName", "1 pet matches"),
				new ClinicAssistantActivity("listVeterinarians", "1 veterinarians"));
	}

	@Test
	void rejectsARequestWithoutTheActivityCollector() {
		ToolContext context = new ToolContext(Map.of());

		assertThatIllegalStateException().isThrownBy(() -> this.tools.listVeterinarians(context))
			.withMessage("Clinic Assistant activity log is missing");
	}

}
