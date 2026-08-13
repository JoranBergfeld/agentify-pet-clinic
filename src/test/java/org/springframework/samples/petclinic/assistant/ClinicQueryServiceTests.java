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

import java.lang.reflect.RecordComponent;
import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledInNativeImage;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.PetType;
import org.springframework.samples.petclinic.owner.Visit;
import org.springframework.samples.petclinic.vet.Specialty;
import org.springframework.samples.petclinic.vet.Vet;
import org.springframework.samples.petclinic.vet.VetRepository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;

/**
 * Tests for {@link ClinicQueryService}.
 */
@ExtendWith(MockitoExtension.class)
@DisabledInNativeImage
class ClinicQueryServiceTests {

	@Mock
	private OwnerRepository owners;

	@Mock
	private VetRepository vets;

	private ClinicQueryService service;

	@BeforeEach
	void setUp() {
		this.service = new ClinicQueryService(this.owners, this.vets);
	}

	@Test
	void findsOwnersWithPurposeBuiltPetAndVisitRecords() {
		Owner george = owner(1, "George", "Franklin").inCity("Madison")
			.withPet(1, pet("Leo", "cat").withVisit("rabies shot").build())
			.build();
		given(this.owners.findByLastNameStartingWith(eq("Franklin"), any(Pageable.class)))
			.willReturn(new PageImpl<>(List.of(george)));

		assertThat(this.service.findOwners("Franklin")).singleElement().satisfies(owner -> {
			assertThat(owner.ownerId()).isEqualTo(1);
			assertThat(owner.fullName()).isEqualTo("George Franklin");
			assertThat(owner.city()).isEqualTo("Madison");
			assertThat(owner.pets()).singleElement().satisfies(pet -> {
				assertThat(pet.petId()).isEqualTo(1);
				assertThat(pet.name()).isEqualTo("Leo");
				assertThat(pet.type()).isEqualTo("cat");
				assertThat(pet.ownerId()).isEqualTo(1);
				assertThat(pet.ownerName()).isEqualTo("George Franklin");
				assertThat(pet.visits()).singleElement().satisfies(visit -> {
					assertThat(visit.date()).isEqualTo(LocalDate.of(2013, 1, 1));
					assertThat(visit.description()).isEqualTo("rabies shot");
				});
			});
		});
		then(this.owners).should().findByLastNameStartingWith("Franklin", PageRequest.of(0, 20));
	}

	@Test
	void findsPetsByExactCaseInsensitiveNameAcrossOwnersWithOwnerIdentity() {
		Owner betty = owner(2, "Betty", "Davis").inCity("Madison")
			.withPet(2, pet("Basil", "hamster").withVisit("checkup").build())
			.build();
		Owner george = owner(3, "George", "Franklin").inCity("Madison")
			.withPet(3, pet("BASIL", "lizard").withVisit("x-ray").build())
			.withPet(4, pet("Basilisk", "snake").withVisit("observation").build())
			.build();
		given(this.owners.findAll()).willReturn(List.of(betty, george));

		assertThat(this.service.findPets("basil")).satisfiesExactly(pet -> {
			assertThat(pet.petId()).isEqualTo(2);
			assertThat(pet.name()).isEqualTo("Basil");
			assertThat(pet.type()).isEqualTo("hamster");
			assertThat(pet.ownerId()).isEqualTo(2);
			assertThat(pet.ownerName()).isEqualTo("Betty Davis");
			assertThat(pet.visits()).extracting(ClinicQueryService.VisitSummary::description)
				.containsExactly("checkup");
		}, pet -> {
			assertThat(pet.petId()).isEqualTo(3);
			assertThat(pet.name()).isEqualTo("BASIL");
			assertThat(pet.type()).isEqualTo("lizard");
			assertThat(pet.ownerId()).isEqualTo(3);
			assertThat(pet.ownerName()).isEqualTo("George Franklin");
			assertThat(pet.visits()).extracting(ClinicQueryService.VisitSummary::description).containsExactly("x-ray");
		});
		then(this.owners).should().findAll();
	}

	@Test
	void listsVeterinariansWithExactRecordContractAndSortedSpecialtyNames() {
		Vet helen = vet(2, "Helen", "Leary").withSpecialty("surgery").withSpecialty("radiology").build();
		given(this.vets.findAll()).willReturn(List.of(helen));

		assertThat(ClinicQueryService.VeterinarianSummary.class.getRecordComponents())
			.extracting(RecordComponent::getName)
			.containsExactly("veterinarianId", "fullName", "specialties");

		assertThat(this.service.listVeterinarians()).singleElement().satisfies(vet -> {
			assertThat(vet.veterinarianId()).isEqualTo(2);
			assertThat(vet.fullName()).isEqualTo("Helen Leary");
			assertThat(vet.specialties()).containsExactly("radiology", "surgery");
		});
	}

	private static OwnerBuilder owner(int id, String firstName, String lastName) {
		return new OwnerBuilder(id, firstName, lastName);
	}

	private static PetBuilder pet(String name, String typeName) {
		return new PetBuilder(name, typeName);
	}

	private static Visit visit(String description) {
		Visit visit = new Visit();
		visit.setDate(LocalDate.of(2013, 1, 1));
		visit.setDescription(description);
		return visit;
	}

	private static VetBuilder vet(int id, String firstName, String lastName) {
		return new VetBuilder(id, firstName, lastName);
	}

	private static final class OwnerBuilder {

		private final Owner owner = new Owner();

		private OwnerBuilder(int id, String firstName, String lastName) {
			this.owner.setId(id);
			this.owner.setFirstName(firstName);
			this.owner.setLastName(lastName);
			this.owner.setAddress("Workshop address");
			this.owner.setCity("Workshop city");
			this.owner.setTelephone("6085550100");
		}

		private OwnerBuilder inCity(String city) {
			this.owner.setCity(city);
			return this;
		}

		private OwnerBuilder withPet(int petId, Pet pet) {
			this.owner.addPet(pet);
			pet.setId(petId);
			return this;
		}

		private Owner build() {
			return this.owner;
		}

	}

	private static final class PetBuilder {

		private final Pet pet = new Pet();

		private PetBuilder(String name, String typeName) {
			this.pet.setName(name);
			this.pet.setBirthDate(LocalDate.of(2010, 1, 1));
			PetType type = new PetType();
			type.setName(typeName);
			this.pet.setType(type);
		}

		private PetBuilder withVisit(String description) {
			this.pet.addVisit(visit(description));
			return this;
		}

		private Pet build() {
			return this.pet;
		}

	}

	private static final class VetBuilder {

		private final Vet vet = new Vet();

		private VetBuilder(int id, String firstName, String lastName) {
			this.vet.setId(id);
			this.vet.setFirstName(firstName);
			this.vet.setLastName(lastName);
		}

		private VetBuilder withSpecialty(String specialtyName) {
			Specialty specialty = new Specialty();
			specialty.setName(specialtyName);
			this.vet.addSpecialty(specialty);
			return this;
		}

		private Vet build() {
			return this.vet;
		}

	}

}
