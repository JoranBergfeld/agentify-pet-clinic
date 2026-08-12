package org.springframework.samples.petclinic.assistant;

import java.time.LocalDate;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.data.domain.PageRequest;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.Visit;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
class ClinicAssistantTools {

	private static final Logger logger = LoggerFactory.getLogger(ClinicAssistantTools.class);

	private final OwnerRepository owners;

	ClinicAssistantTools(OwnerRepository owners) {
		this.owners = owners;
	}

	@Tool(description = "Find PetClinic owners whose last name starts with the supplied text. "
			+ "Returns every matching owner with pets and recorded visits. "
			+ "When more than one owner matches, present the candidates and ask the user to clarify.")
	@Transactional(readOnly = true)
	List<OwnerSummary> findOwnersByLastName(
			@ToolParam(description = "The owner's last name or unambiguous starting text") String lastName) {
		List<OwnerSummary> matches = this.owners.findByLastNameStartingWith(lastName, PageRequest.of(0, 20))
			.stream()
			.map(ClinicAssistantTools::toSummary)
			.toList();
		logger.info("clinic-assistant-tool=findOwnersByLastName query={} matches={}", lastName, matches.size());
		return matches;
	}

	private static OwnerSummary toSummary(Owner owner) {
		return new OwnerSummary(owner.getId(), owner.getFirstName() + " " + owner.getLastName(), owner.getCity(),
				owner.getPets().stream().map(ClinicAssistantTools::toSummary).toList());
	}

	private static PetSummary toSummary(Pet pet) {
		return new PetSummary(pet.getId(), pet.getName(), pet.getType().getName(),
				pet.getVisits().stream().map(ClinicAssistantTools::toSummary).toList());
	}

	private static VisitSummary toSummary(Visit visit) {
		return new VisitSummary(visit.getDate(), visit.getDescription());
	}

	record OwnerSummary(Integer ownerId, String fullName, String city, List<PetSummary> pets) {
	}

	record PetSummary(Integer petId, String name, String type, List<VisitSummary> visits) {
	}

	record VisitSummary(LocalDate date, String description) {
	}

}
