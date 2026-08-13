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

import java.util.ArrayList;
import java.util.List;

import org.springframework.ai.chat.model.ToolContext;

final class ClinicAssistantActivityLog {

	static final String CONTEXT_KEY = ClinicAssistantActivityLog.class.getName();

	private final List<ClinicAssistantActivity> activities = new ArrayList<>();

	void record(String tool, String outcome) {
		this.activities.add(new ClinicAssistantActivity(tool, outcome));
	}

	List<ClinicAssistantActivity> snapshot() {
		return List.copyOf(this.activities);
	}

	static ClinicAssistantActivityLog from(ToolContext context) {
		if (context != null && context.getContext() != null) {
			Object value = context.getContext().get(CONTEXT_KEY);
			if (value instanceof ClinicAssistantActivityLog log) {
				return log;
			}
		}
		throw new IllegalStateException("Clinic Assistant activity log is missing");
	}

}
