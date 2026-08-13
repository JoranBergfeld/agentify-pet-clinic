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

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.domain.PageRequest;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.Visit;
import org.springframework.samples.petclinic.vet.Vet;
import org.springframework.samples.petclinic.vet.VetRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
class ClinicQueryService {

	private final OwnerRepository owners;

	private final VetRepository vets;

	ClinicQueryService(OwnerRepository owners, VetRepository vets) {
		this.owners = owners;
		this.vets = vets;
	}

	@Transactional(readOnly = true)
	List<OwnerSummary> findOwners(String lastName) {
		return this.owners.findByLastNameStartingWith(lastName, PageRequest.of(0, 20))
			.stream()
			.map(ClinicQueryService::ownerSummary)
			.toList();
	}

	@Transactional(readOnly = true)
	List<PetSummary> findPets(String name) {
		return this.owners.findAll()
			.stream()
			.flatMap(owner -> owner.getPets()
				.stream()
				.filter(pet -> pet.getName().equalsIgnoreCase(name))
				.map(pet -> petSummary(owner, pet)))
			.toList();
	}

	@Transactional(readOnly = true)
	List<VeterinarianSummary> listVeterinarians() {
		return this.vets.findAll().stream().map(ClinicQueryService::veterinarianSummary).toList();
	}

	private static OwnerSummary ownerSummary(Owner owner) {
		return new OwnerSummary(owner.getId(), fullName(owner.getFirstName(), owner.getLastName()), owner.getCity(),
				owner.getPets().stream().map(pet -> petSummary(owner, pet)).toList());
	}

	private static PetSummary petSummary(Owner owner, Pet pet) {
		return new PetSummary(pet.getId(), pet.getName(), pet.getType().getName(), owner.getId(),
				fullName(owner.getFirstName(), owner.getLastName()),
				pet.getVisits().stream().map(ClinicQueryService::visitSummary).toList());
	}

	private static VisitSummary visitSummary(Visit visit) {
		return new VisitSummary(visit.getDate(), visit.getDescription());
	}

	private static VeterinarianSummary veterinarianSummary(Vet vet) {
		return new VeterinarianSummary(vet.getId(), fullName(vet.getFirstName(), vet.getLastName()),
				vet.getSpecialties().stream().map(specialty -> specialty.getName()).sorted().toList());
	}

	private static String fullName(String firstName, String lastName) {
		return firstName + " " + lastName;
	}

	record OwnerSummary(Integer ownerId, String fullName, String city, List<PetSummary> pets) {
	}

	record PetSummary(Integer petId, String name, String type, Integer ownerId, String ownerName,
			List<VisitSummary> visits) {
	}

	record VisitSummary(LocalDate date, String description) {
	}

	record VeterinarianSummary(Integer veterinarianId, String fullName, List<String> specialties) {
	}

}
