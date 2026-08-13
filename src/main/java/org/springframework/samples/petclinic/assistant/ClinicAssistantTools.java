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

import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

@Component
class ClinicAssistantTools {

	private final ClinicQueryService queries;

	ClinicAssistantTools(ClinicQueryService queries) {
		this.queries = queries;
	}

	@Tool(description = "Find owners whose last name starts with the supplied text. "
			+ "If more than one owner matches, list candidates and ask for clarification.")
	List<ClinicQueryService.OwnerSummary> findOwnersByLastName(
			@ToolParam(description = "Owner last name or starting text") String lastName, ToolContext context) {
		List<ClinicQueryService.OwnerSummary> matches = this.queries.findOwners(lastName);
		ClinicAssistantActivityLog.from(context).record("findOwnersByLastName", matches.size() + " owner matches");
		return matches;
	}

	@Tool(description = "Find pets by name and return their owner and recorded Visits. "
			+ "If more than one pet matches, list candidates and ask for clarification.")
	List<ClinicQueryService.PetSummary> findPetsByName(@ToolParam(description = "Pet name") String name,
			ToolContext context) {
		List<ClinicQueryService.PetSummary> matches = this.queries.findPets(name);
		ClinicAssistantActivityLog.from(context).record("findPetsByName", matches.size() + " pet matches");
		return matches;
	}

	@Tool(description = "List PetClinic veterinarians and their recorded specialties.")
	List<ClinicQueryService.VeterinarianSummary> listVeterinarians(ToolContext context) {
		List<ClinicQueryService.VeterinarianSummary> matches = this.queries.listVeterinarians();
		ClinicAssistantActivityLog.from(context).record("listVeterinarians", matches.size() + " veterinarians");
		return matches;
	}

}
