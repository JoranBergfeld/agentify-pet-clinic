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

import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.HttpSessionEvent;
import jakarta.servlet.http.HttpSessionListener;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.stereotype.Component;

@Component
class ClinicAssistantSessionListener implements HttpSessionListener {

	private static final Log log = LogFactory.getLog(ClinicAssistantSessionListener.class);

	private final ClinicAssistantService assistant;

	ClinicAssistantSessionListener(ClinicAssistantService assistant) {
		this.assistant = assistant;
	}

	@Override
	public void sessionDestroyed(HttpSessionEvent event) {
		ClinicAssistantConversation conversation = conversation(event.getSession());
		if (conversation == null) {
			return;
		}
		try {
			this.assistant.expire(conversation);
		}
		catch (RuntimeException ex) {
			log.warn("Failed to expire Clinic Assistant conversation " + conversation.id(), ex);
		}
	}

	private ClinicAssistantConversation conversation(HttpSession session) {
		try {
			Object attribute = session.getAttribute(ClinicAssistantController.CONVERSATION_ATTRIBUTE);
			return (attribute instanceof ClinicAssistantConversation conversation) ? conversation : null;
		}
		catch (IllegalStateException ex) {
			log.debug("Skipping Clinic Assistant session cleanup during shutdown", ex);
			return null;
		}
	}

}
