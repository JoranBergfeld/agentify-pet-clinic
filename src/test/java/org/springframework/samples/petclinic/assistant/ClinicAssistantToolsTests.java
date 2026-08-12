package org.springframework.samples.petclinic.assistant;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.PetType;
import org.springframework.samples.petclinic.owner.Visit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class ClinicAssistantToolsTests {

	private final OwnerRepository owners = mock(OwnerRepository.class);

	private final ClinicAssistantTools tools = new ClinicAssistantTools(this.owners);

	@Test
	void returnsPurposeBuiltOwnerAndPetRecords() {
		Owner george = owner(1, "George", "Franklin");
		Pet leo = pet("Leo", "cat");
		Visit visit = new Visit();
		visit.setDate(LocalDate.of(2013, 1, 1));
		visit.setDescription("rabies shot");
		leo.addVisit(visit);
		george.addPet(leo);
		leo.setId(1);
		given(this.owners.findByLastNameStartingWith(eq("Franklin"), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(george)));

		List<ClinicAssistantTools.OwnerSummary> result = this.tools.findOwnersByLastName("Franklin");

		assertThat(result).singleElement().satisfies(owner -> {
			assertThat(owner.ownerId()).isEqualTo(1);
			assertThat(owner.fullName()).isEqualTo("George Franklin");
			assertThat(owner.pets()).singleElement().satisfies(pet -> {
				assertThat(pet.name()).isEqualTo("Leo");
				assertThat(pet.type()).isEqualTo("cat");
				assertThat(pet.visits())
					.containsExactly(new ClinicAssistantTools.VisitSummary(LocalDate.of(2013, 1, 1), "rabies shot"));
			});
		});
	}

	@Test
	void preservesMultipleMatchesSoTheModelCanAskForClarification() {
		given(this.owners.findByLastNameStartingWith(eq("Davis"), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(owner(2, "Betty", "Davis"), owner(4, "Harold", "Davis"))));

		List<ClinicAssistantTools.OwnerSummary> result = this.tools.findOwnersByLastName("Davis");

		assertThat(result).extracting(ClinicAssistantTools.OwnerSummary::fullName)
			.containsExactly("Betty Davis", "Harold Davis");
		verify(this.owners).findByLastNameStartingWith(eq("Davis"), any(Pageable.class));
	}

	private static Owner owner(int id, String firstName, String lastName) {
		Owner owner = new Owner();
		owner.setId(id);
		owner.setFirstName(firstName);
		owner.setLastName(lastName);
		owner.setAddress("Workshop address");
		owner.setCity("Workshop city");
		owner.setTelephone("6085550100");
		return owner;
	}

	private static Pet pet(String name, String typeName) {
		Pet pet = new Pet();
		pet.setName(name);
		pet.setBirthDate(LocalDate.of(2010, 1, 1));
		PetType type = new PetType();
		type.setName(typeName);
		pet.setType(type);
		return pet;
	}

}
