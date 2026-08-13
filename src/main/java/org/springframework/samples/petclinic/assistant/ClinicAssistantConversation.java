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

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

final class ClinicAssistantConversation {

	private final String id = UUID.randomUUID().toString();

	private final List<Turn> turns = new ArrayList<>();

	String id() {
		return this.id;
	}

	List<Turn> turns() {
		synchronized (this) {
			return List.copyOf(this.turns);
		}
	}

	public List<Turn> getTurns() {
		return turns();
	}

	void addUser(String content) {
		synchronized (this) {
			this.turns.add(new Turn("user", content, List.of()));
		}
	}

	void addAssistant(String content, List<ClinicAssistantActivity> activities) {
		synchronized (this) {
			this.turns.add(new Turn("assistant", content, activities));
		}
	}

	void clear() {
		synchronized (this) {
			this.turns.clear();
		}
	}

	record Turn(String role, String content, List<ClinicAssistantActivity> activities) {

		public Turn {
			activities = List.copyOf(activities);
		}

	}

}
