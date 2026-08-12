# Azure Deployment Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run a disposable canonical Spring PetClinic slice that proves Spring AI 2.0 managed-identity inference on Microsoft Foundry, App Service B1 fit, current pricing, repeat deployment, and complete cleanup.

**Architecture:** Execute in an isolated worktree on `prototype/azure-deployment-slice`, based on canonical `spring-projects/spring-petclinic` commit `88e37c15cf6fc8490b01bc3e8e2c800cec1ac272`. Add one read-only owner lookup tool, a minimal Spring AI chat endpoint, and an `azd` Bicep template that provisions B1 App Service plus an `AIServices` Foundry resource and model deployment. Capture redacted runtime, pricing, RBAC, memory, and cleanup evidence on the prototype branch; leave the planning branch unchanged apart from its existing design and plan.

**Tech Stack:** Java 21, Spring Boot 4.1.0, Spring AI 2.0.0, Azure Identity 1.18.2, Maven, Azure Developer CLI 1.25+, Bicep, Azure App Service Linux B1, Microsoft Foundry `AIServices`, Bash, `curl`, `jq`.

---

## File structure

All paths below are relative to the disposable PetClinic worktree.

- `pom.xml` — imports Spring AI 2.0 and Azure Identity.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantTools.java` — read-only PetClinic query tool and purpose-built records.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantConfiguration.java` — system boundary and `ChatClient` wiring.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantService.java` — one-turn chat orchestration.
- `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantController.java` — minimal JSON endpoint.
- `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantToolsTests.java` — direct read-only tool contract tests.
- `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantControllerTests.java` — HTTP boundary test independent of a live model.
- `src/main/resources/application.properties` — Microsoft Foundry property mapping and safe timeout.
- `azure.yaml` — `azd` service and Bicep entry point.
- `infra/main.bicep` — subscription-scope resource group and output contract.
- `infra/resources.bicep` — App Service, Foundry, model deployment, and RBAC.
- `infra/main.parameters.json` — `azd` parameter binding.
- `scripts/smoke.sh` — deployed health/chat smoke checks.
- `scripts/collect-evidence.sh` — resource, role, memory, price, and log collection.
- `scripts/cleanup.sh` — `azd` cleanup plus explicit soft-delete inspection and purge.
- `docs/prototype/azure-deployment-slice-evidence.md` — redacted evidence and final verdict.

### Task 1: Create the isolated canonical PetClinic worktree

**Files:**
- No project files changed.

- [ ] **Step 1: Load the worktree workflow**

Invoke `superpowers:using-git-worktrees` before running any branch or worktree command.

- [ ] **Step 2: Add and fetch the canonical upstream**

Run from the planning repository:

```bash
git remote get-url petclinic-upstream >/dev/null 2>&1 \
  || git remote add petclinic-upstream https://github.com/spring-projects/spring-petclinic.git
git fetch petclinic-upstream main
git rev-parse petclinic-upstream/main
```

Expected: the final command prints `88e37c15cf6fc8490b01bc3e8e2c800cec1ac272`. If upstream has advanced, create the branch from that printed commit and record it in the evidence document.

- [ ] **Step 3: Create the disposable worktree**

```bash
git worktree add .worktrees/azure-deployment-slice \
  -b prototype/azure-deployment-slice petclinic-upstream/main
cd .worktrees/azure-deployment-slice
git status --short
```

Expected: an empty status on `prototype/azure-deployment-slice`.

- [ ] **Step 4: Establish the baseline**

```bash
./mvnw -q -DskipTests package
./mvnw -q test
```

Expected: both commands exit 0 before prototype changes.

### Task 2: Add the read-only Clinic Assistant tool

**Files:**
- Modify: `pom.xml`
- Create: `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantToolsTests.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantTools.java`

- [ ] **Step 1: Add Spring AI and Azure Identity dependencies**

Add this import to the existing `<dependencyManagement>` section, creating the section immediately before `<dependencies>` if it does not exist:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>org.springframework.ai</groupId>
      <artifactId>spring-ai-bom</artifactId>
      <version>2.0.0</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

Add these dependencies after the Spring web dependencies:

```xml
<dependency>
  <groupId>org.springframework.ai</groupId>
  <artifactId>spring-ai-starter-model-openai</artifactId>
</dependency>
<dependency>
  <groupId>com.azure</groupId>
  <artifactId>azure-identity</artifactId>
  <version>1.18.2</version>
</dependency>
```

- [ ] **Step 2: Write the failing tool contract tests**

Create `ClinicAssistantToolsTests.java`:

```java
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
		Pet leo = pet(1, "Leo", "cat");
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
				assertThat(pet.visits()).containsExactly(new ClinicAssistantTools.VisitSummary(
						LocalDate.of(2013, 1, 1), "rabies shot"));
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

	private static Pet pet(int id, String name, String typeName) {
		Pet pet = new Pet();
		pet.setName(name);
		pet.setBirthDate(LocalDate.of(2010, 1, 1));
		PetType type = new PetType();
		type.setName(typeName);
		pet.setType(type);
		return pet;
	}

}
```

- [ ] **Step 3: Run the tests and confirm the missing class failure**

```bash
./mvnw -q -Dtest=ClinicAssistantToolsTests test
```

Expected: compilation fails because `ClinicAssistantTools` does not exist.

- [ ] **Step 4: Implement the minimal read-only tool**

Create `ClinicAssistantTools.java`:

```java
package org.springframework.samples.petclinic.assistant;

import java.time.LocalDate;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.samples.petclinic.owner.Owner;
import org.springframework.samples.petclinic.owner.OwnerRepository;
import org.springframework.samples.petclinic.owner.Pet;
import org.springframework.samples.petclinic.owner.Visit;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;

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
		return new OwnerSummary(owner.getId(), owner.getFirstName() + " " + owner.getLastName(),
				owner.getCity(), owner.getPets().stream().map(ClinicAssistantTools::toSummary).toList());
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
```

- [ ] **Step 5: Run the focused tests**

```bash
./mvnw -q -Dtest=ClinicAssistantToolsTests test
```

Expected: 2 tests pass.

- [ ] **Step 6: Commit the tool boundary**

```bash
git add pom.xml \
  src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantTools.java \
  src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantToolsTests.java
git commit -m "prototype: add read-only clinic assistant tool"
```

### Task 3: Add the minimal Spring AI chat endpoint

**Files:**
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantConfiguration.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantService.java`
- Create: `src/main/java/org/springframework/samples/petclinic/assistant/ClinicAssistantController.java`
- Create: `src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantControllerTests.java`
- Modify: `src/main/resources/application.properties`

- [ ] **Step 1: Write the failing HTTP boundary test**

Create `ClinicAssistantControllerTests.java`:

```java
package org.springframework.samples.petclinic.assistant;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ClinicAssistantController.class)
class ClinicAssistantControllerTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private ClinicAssistantService assistant;

	@Test
	void returnsTheAssistantAnswerAsJson() throws Exception {
		given(this.assistant.ask("Tell me about George Franklin")).willReturn("George Franklin owns Leo.");

		this.mockMvc.perform(post("/api/clinic-assistant")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"message":"Tell me about George Franklin"}
						"""))
			.andExpect(status().isOk())
			.andExpect(jsonPath("$.answer").value("George Franklin owns Leo."));
	}

	@Test
	void rejectsABlankMessage() throws Exception {
		this.mockMvc.perform(post("/api/clinic-assistant")
				.contentType(MediaType.APPLICATION_JSON)
				.content("""
						{"message":" "}
						"""))
			.andExpect(status().isBadRequest());
	}

}
```

- [ ] **Step 2: Run the test and confirm the missing-class failure**

```bash
./mvnw -q -Dtest=ClinicAssistantControllerTests test
```

Expected: compilation fails because the controller and service do not exist.

- [ ] **Step 3: Implement Spring AI configuration**

Create `ClinicAssistantConfiguration.java`:

```java
package org.springframework.samples.petclinic.assistant;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class ClinicAssistantConfiguration {

	@Bean
	ChatClient clinicAssistantChatClient(ChatModel chatModel, ClinicAssistantTools tools) {
		return ChatClient.builder(chatModel)
			.defaultSystem("""
					You are the staff-facing Clinic Assistant for Spring PetClinic.
					Answer only from data returned by the available tools.
					You are read-only and must never claim to change PetClinic data.
					When a tool returns multiple people or pets, list the candidates and ask the user to clarify.
					If records are absent or a request is unsupported, say so.
					Do not provide veterinary diagnosis or treatment advice.
					""")
			.defaultTools(tools)
			.build();
	}

}
```

- [ ] **Step 4: Implement the service**

Create `ClinicAssistantService.java`:

```java
package org.springframework.samples.petclinic.assistant;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;

@Service
class ClinicAssistantService {

	private final ChatClient chatClient;

	ClinicAssistantService(ChatClient chatClient) {
		this.chatClient = chatClient;
	}

	String ask(String message) {
		return this.chatClient.prompt().user(message).call().content();
	}

}
```

- [ ] **Step 5: Implement the controller**

Create `ClinicAssistantController.java`:

```java
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
```

- [ ] **Step 6: Add Microsoft Foundry configuration**

Append to `application.properties`:

```properties

# Clinic Assistant prototype
spring.ai.openai.chat.base-url=${AZURE_OPENAI_ENDPOINT:https://example.openai.azure.com}
spring.ai.openai.chat.microsoft-foundry=${AZURE_OPENAI_MICROSOFT_FOUNDRY:true}
spring.ai.openai.chat.microsoft-deployment-name=${AZURE_OPENAI_DEPLOYMENT:gpt-4o-mini}
spring.ai.openai.chat.model=${AZURE_OPENAI_MODEL:gpt-4o-mini}
spring.ai.openai.chat.timeout=60s
spring.ai.openai.chat.max-retries=2
```

Spring AI 2.0 detects Microsoft Foundry when `microsoft-foundry=true`, builds a `DefaultAzureCredential`, and supplies bearer tokens for `https://cognitiveservices.azure.com/.default`. No API key is configured.

- [ ] **Step 7: Run the focused and full test suites**

```bash
./mvnw -q -Dtest=ClinicAssistantToolsTests,ClinicAssistantControllerTests test
./mvnw -q test
```

Expected: focused tests and the existing PetClinic suite pass without calling a live model.

- [ ] **Step 8: Commit the chat boundary**

```bash
git add src/main/java/org/springframework/samples/petclinic/assistant \
  src/test/java/org/springframework/samples/petclinic/assistant/ClinicAssistantControllerTests.java \
  src/main/resources/application.properties
git commit -m "prototype: add clinic assistant chat endpoint"
```

### Task 4: Add the `azd` App Service and Foundry infrastructure

**Files:**
- Create: `azure.yaml`
- Create: `infra/main.bicep`
- Create: `infra/resources.bicep`
- Create: `infra/main.parameters.json`

- [ ] **Step 1: Write the `azd` service definition**

Create `azure.yaml`:

```yaml
name: petclinic-ai-prototype
metadata:
  template: petclinic-ai-prototype@0.0.1
services:
  web:
    project: .
    language: java
    host: appservice
    dist: target
    hooks:
      prepackage:
        shell: sh
        run: ./mvnw -q -DskipTests package
infra:
  provider: bicep
  path: infra
```

- [ ] **Step 2: Write the subscription-scope entry point**

Create `infra/main.bicep`:

```bicep
targetScope = 'subscription'

@minLength(1)
param environmentName string

param location string

param modelDeploymentSku string = 'GlobalStandard'

param tags object = {
  'azd-env-name': environmentName
  purpose: 'wayfinder-15-prototype'
}

var resourceGroupName = 'rg-${environmentName}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
    modelDeploymentSku: modelDeploymentSku
    tags: tags
  }
}

output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP_NAME string = resourceGroup.name
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_WEB_NAME string = resources.outputs.webAppName
output WEB_APP_URL string = resources.outputs.webAppUrl
output AZURE_OPENAI_ACCOUNT_NAME string = resources.outputs.foundryName
output AZURE_OPENAI_ENDPOINT string = resources.outputs.openAiEndpoint
output AZURE_OPENAI_DEPLOYMENT string = resources.outputs.modelDeploymentName
output AZURE_OPENAI_MODEL string = resources.outputs.modelName
```

- [ ] **Step 3: Write the resource module**

Create `infra/resources.bicep`:

```bicep
param environmentName string
param location string
param modelDeploymentSku string
param tags object

var token = uniqueString(resourceGroup().id, environmentName)
var planName = 'plan-${token}'
var webAppName = 'petclinic-${token}'
var foundryName = 'foundry-${token}'
var modelName = 'gpt-4o-mini'
var modelVersion = '2024-07-18'
var modelDeploymentName = 'gpt-4o-mini'
var foundryUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '53ca6127-db72-4b80-b1b0-d745d6d5456d'
)

resource plan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: planName
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  kind: 'AIServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: modelDeploymentName
  sku: {
    name: modelDeploymentSku
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

resource web 'Microsoft.Web/sites@2024-11-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  tags: union(tags, {
    'azd-service-name': 'web'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      linuxFxVersion: 'JAVA|21-java21'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: 'https://${foundry.name}.openai.azure.com'
        }
        {
          name: 'AZURE_OPENAI_MICROSOFT_FOUNDRY'
          value: 'true'
        }
        {
          name: 'AZURE_OPENAI_DEPLOYMENT'
          value: modelDeploymentName
        }
        {
          name: 'AZURE_OPENAI_MODEL'
          value: modelName
        }
        {
          name: 'JAVA_OPTS'
          value: '-Xms256m -Xmx1024m'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ]
    }
  }
  dependsOn: [
    modelDeployment
  ]
}

resource foundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, web.identity.principalId, foundryUserRoleDefinitionId)
  scope: foundry
  properties: {
    principalId: web.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: foundryUserRoleDefinitionId
  }
}

output webAppName string = web.name
output webAppUrl string = 'https://${web.properties.defaultHostName}'
output foundryName string = foundry.name
output openAiEndpoint string = 'https://${foundry.name}.openai.azure.com'
output modelDeploymentName string = modelDeploymentName
output modelName string = modelName
```

- [ ] **Step 4: Bind `azd` environment parameters**

Create `infra/main.parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "${AZURE_ENV_NAME}"
    },
    "location": {
      "value": "${AZURE_LOCATION}"
    },
    "modelDeploymentSku": {
      "value": "${MODEL_DEPLOYMENT_SKU=GlobalStandard}"
    }
  }
}
```

- [ ] **Step 5: Validate Bicep and `azd` configuration**

```bash
az bicep build --file infra/main.bicep
azd config show >/dev/null
./mvnw -q -DskipTests package
```

Expected: Bicep compiles, `azd` reads the project, and one executable JAR exists under `target/`.

- [ ] **Step 6: Commit the infrastructure**

```bash
git add azure.yaml infra
git commit -m "prototype: add azd app service and foundry infrastructure"
```

### Task 5: Add repeatable smoke, evidence, and cleanup scripts

**Files:**
- Create: `scripts/smoke.sh`
- Create: `scripts/collect-evidence.sh`
- Create: `scripts/cleanup.sh`

- [ ] **Step 1: Create the deployed smoke script**

Create `scripts/smoke.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

app_url="${WEB_APP_URL:-$(azd env get-value WEB_APP_URL)}"

curl --fail --silent --show-error "${app_url}/actuator/health" | jq .

for message in \
  "Tell me about George Franklin and his pets." \
  "Tell me about the owners named Davis. Do not guess which one I mean." \
  "Should I give Leo a different medication?"
do
  jq -n --arg message "${message}" '{message: $message}' \
    | curl --fail --silent --show-error \
        --header 'Content-Type: application/json' \
        --data @- \
        "${app_url}/api/clinic-assistant" \
    | jq .
done
```

- [ ] **Step 2: Create the evidence collection script**

Create `scripts/collect-evidence.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"
web_app="$(azd env get-value SERVICE_WEB_NAME)"
foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd env get-value AZURE_LOCATION)"
web_id="$(az webapp show --resource-group "${resource_group}" --name "${web_app}" --query id -o tsv)"
foundry_id="$(az cognitiveservices account show --resource-group "${resource_group}" --name "${foundry}" --query id -o tsv)"
principal_id="$(az webapp identity show --resource-group "${resource_group}" --name "${web_app}" --query principalId -o tsv)"

printf '## Resources\n\n'
az resource list --resource-group "${resource_group}" \
  --query '[].{name:name,type:type,location:location}' -o table

printf '\n## App Service identity and Foundry roles\n\n'
printf 'principalId: %s\n' "${principal_id}"
az role assignment list --assignee-object-id "${principal_id}" --scope "${foundry_id}" \
  --query '[].{role:roleDefinitionName,scope:scope}' -o table

printf '\n## App Service memory\n\n'
az monitor metrics list --resource "${web_id}" --metric MemoryWorkingSet \
  --interval PT1M --aggregation Average Maximum -o json \
  | tee /tmp/wf15-memory.json \
  | jq '{timespan: .timespan, value: [.value[].timeseries[].data[] | select(.maximum != null)]}'

printf '\n## Foundry Models retail prices\n\n'
curl --fail --silent --show-error --get 'https://prices.azure.com/api/retail/prices' \
  --data-urlencode "\$filter=serviceName eq 'Foundry Models' and armRegionName eq '${location}'" \
  | jq --arg model 'gpt-4o-mini' \
      '{currencyCode, items: [.Items[] | select((.productName + " " + .skuName + " " + .meterName)
      | ascii_downcase | contains($model)) | {
        armRegionName, productName, skuName, meterName, unitPrice, unitOfMeasure
      }]}'

printf '\n## Recent application logs\n\n'
timeout 20s az webapp log tail --resource-group "${resource_group}" --name "${web_app}" \
  2>&1 | sed -n '1,200p' || true
```

- [ ] **Step 3: Create the cleanup script**

Create `scripts/cleanup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd env get-value AZURE_LOCATION)"
resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"

azd down --force --purge

if az group exists --name "${resource_group}" | grep -q true; then
  printf 'Resource group still exists: %s\n' "${resource_group}" >&2
  exit 1
fi

deleted_id="$(az cognitiveservices account list-deleted \
  --query "[?name=='${foundry}' && location=='${location}'].id | [0]" -o tsv)"

if [[ -n "${deleted_id}" ]]; then
  az cognitiveservices account purge --name "${foundry}" --location "${location}" \
    --resource-group "${resource_group}"
fi

remaining="$(az cognitiveservices account list-deleted \
  --query "[?name=='${foundry}' && location=='${location}'] | length(@)" -o tsv)"
test "${remaining}" = "0"
```

- [ ] **Step 4: Make scripts executable and syntax-check them**

```bash
chmod +x scripts/*.sh
bash -n scripts/smoke.sh scripts/collect-evidence.sh scripts/cleanup.sh
```

Expected: no output and exit 0.

- [ ] **Step 5: Commit the experiment harness**

```bash
git add scripts
git commit -m "prototype: add deployment evidence harness"
```

### Task 6: Run the fresh Azure deployment

**Files:**
- Modify only when evidence requires it: `infra/resources.bicep`

- [ ] **Step 1: Confirm the intended Azure context**

```bash
az account show --query '{name:name,id:id,tenantId:tenantId,user:user.name}' -o json
az provider show --namespace Microsoft.Web --query registrationState -o tsv
az provider show --namespace Microsoft.CognitiveServices --query registrationState -o tsv
```

Expected: subscription ID `9bc0bdaa-0a20-4570-9cae-ef826f5c23a7`; both providers are `Registered`.

- [ ] **Step 2: Create an isolated `azd` environment**

```bash
export AZURE_ENV_NAME="wf15-$(date -u +%Y%m%d%H%M%S)"
azd env new "${AZURE_ENV_NAME}"
azd env set AZURE_LOCATION eastus
azd env set MODEL_DEPLOYMENT_SKU GlobalStandard
```

Expected: an environment under `.azure/${AZURE_ENV_NAME}` with no secrets.

- [ ] **Step 3: Provision and deploy**

```bash
azd up --no-prompt 2>&1 | tee /tmp/wf15-azd-up.log
```

Expected: App Service, Foundry account, model deployment, managed identity role assignment, and application deployment succeed.

If the deployment fails specifically because `GlobalStandard` is unavailable due to region, quota, or policy:

```bash
azd env set MODEL_DEPLOYMENT_SKU DataZoneStandard
azd up --no-prompt 2>&1 | tee /tmp/wf15-azd-up-data-zone.log
```

Do not switch SKU for unrelated failures.

- [ ] **Step 4: Confirm the active role before inference**

```bash
resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"
web_app="$(azd env get-value SERVICE_WEB_NAME)"
foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
principal_id="$(az webapp identity show -g "${resource_group}" -n "${web_app}" --query principalId -o tsv)"
foundry_id="$(az cognitiveservices account show -g "${resource_group}" -n "${foundry}" --query id -o tsv)"
az role assignment list --assignee-object-id "${principal_id}" --scope "${foundry_id}" \
  --query '[].roleDefinitionName' -o tsv
```

Expected: `Foundry User`.

- [ ] **Step 5: Run the smoke suite**

```bash
scripts/smoke.sh 2>&1 | tee /tmp/wf15-smoke-foundry-user.log
```

Expected:

- Health is `UP`.
- George Franklin response mentions his PetClinic data.
- Davis response presents multiple candidates or asks for clarification.
- Medical-advice response declines diagnosis/treatment advice.
- App logs contain `clinic-assistant-tool=findOwnersByLastName`.

- [ ] **Step 6: Apply the compatibility role only if authorization fails**

If inference returns an authorization failure while the Foundry User assignment is active, change only:

```bicep
var foundryUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
)
```

Then run:

```bash
azd provision --no-prompt
scripts/smoke.sh 2>&1 | tee /tmp/wf15-smoke-openai-user.log
```

Expected: the smoke succeeds with Cognitive Services OpenAI User. Record both the failed Foundry User evidence and successful fallback. If Foundry User works, do not test or recommend the broader compatibility role.

- [ ] **Step 7: Redeploy without reprovisioning**

```bash
azd deploy web --no-prompt 2>&1 | tee /tmp/wf15-redeploy.log
scripts/smoke.sh 2>&1 | tee /tmp/wf15-smoke-redeploy.log
```

Expected: redeployment and post-redeploy smoke succeed.

### Task 7: Capture runtime, price, and cleanup evidence

**Files:**
- Create: `docs/prototype/azure-deployment-slice-evidence.md`

- [ ] **Step 1: Collect resource, role, memory, price, and log output**

```bash
scripts/collect-evidence.sh 2>&1 | tee /tmp/wf15-evidence.log
```

Expected: resource table, effective role, non-empty memory datapoints after traffic, Foundry Models price rows, and recent application logs.

- [ ] **Step 2: Calculate B1 memory headroom**

Read the maximum `MemoryWorkingSet` byte value from the raw metrics file and calculate:

```bash
peak_bytes="$(jq '[.value[].timeseries[].data[].maximum | select(. != null)] | max' /tmp/wf15-memory.json)"
jq -n --argjson peak "${peak_bytes}" \
  '{peakBytes:$peak, peakMiB:($peak/1048576), b1Percent:(($peak/1879048192)*100)}'
```

Expected: a numeric peak and percentage of B1's 1.75 GiB memory envelope. Describe observed headroom; do not infer reliability beyond the measured startup and smoke workload.

- [ ] **Step 3: Create the completed evidence document**

Create `docs/prototype/azure-deployment-slice-evidence.md` only after the experiment has produced evidence. Use these headings and place measured facts under every heading:

```markdown
# Azure Deployment Slice Evidence

## Experiment

## Provisioning and role assignment

## Application and model smoke

## B1 memory

## Retail price observation

## Cleanup

## Verdict
```

The completed document must include:

- exact UTC date and canonical commit;
- selected region, model version, and deployment SKU;
- redacted command outputs;
- effective role and any fallback;
- health and three smoke outcomes;
- startup/request memory observations;
- matching Retail Prices API rows;
- cleanup result;
- a direct recommended baseline.

Do not include access tokens, deployment credentials, raw subscription access data, or unredacted principal details.

- [ ] **Step 4: Run cleanup**

```bash
scripts/cleanup.sh 2>&1 | tee /tmp/wf15-cleanup.log
```

Expected: resource group absent and zero matching soft-deleted Cognitive Services accounts. Record whether the script executed explicit purge.

- [ ] **Step 5: Verify cleanup independently**

```bash
resource_group="$(azd env get-value AZURE_RESOURCE_GROUP_NAME)"
foundry="$(azd env get-value AZURE_OPENAI_ACCOUNT_NAME)"
location="$(azd env get-value AZURE_LOCATION)"
az group exists --name "${resource_group}"
az cognitiveservices account list-deleted \
  --query "[?name=='${foundry}' && location=='${location}'] | length(@)" -o tsv
```

Expected: `false` and `0`.

- [ ] **Step 6: Commit and publish the primary-source prototype**

```bash
git add docs/prototype/azure-deployment-slice-evidence.md infra/resources.bicep
git commit -m "prototype: record Azure deployment slice evidence"
git push --set-upstream origin prototype/azure-deployment-slice
```

Expected: the disposable branch is available as the issue's primary-source asset.

### Task 8: Resolve the Wayfinder decision

**Files:**
- GitHub issue: `Validate the Azure deployment slice`
- GitHub issue: `Chart the Agentic Engineering Principles workshop`

- [ ] **Step 1: Run final local verification**

```bash
./mvnw -q -Dtest=ClinicAssistantToolsTests,ClinicAssistantControllerTests test
./mvnw -q test
git status --short
```

Expected: all tests pass and the prototype worktree is clean.

- [ ] **Step 2: Post the named resolution**

Comment on [Validate the Azure deployment slice](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/15) with:

- verdict;
- selected region, deployment SKU, and role;
- B1 observation;
- price observation date and relevant meters;
- cleanup behavior;
- link to `prototype/azure-deployment-slice` and its evidence document;
- any unresolved attendee Preflight risk.

Refer to related issues by title links, not bare issue numbers.

- [ ] **Step 3: Close the ticket**

```bash
gh issue close 15 --repo JoranBergfeld/agentify-pet-clinic
```

- [ ] **Step 4: Append the map context pointer**

Update [Chart the Agentic Engineering Principles workshop](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/1) under `## Decisions so far`. Add one line beginning with the named link [Validate the Azure deployment slice](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/15), followed by a one-sentence gist naming the measured deployment SKU, effective role, B1 verdict, and cleanup result, and ending with the named [Prototype](https://github.com/JoranBergfeld/agentify-pet-clinic/tree/prototype/azure-deployment-slice) link. Do not duplicate the detailed evidence held by the ticket and branch.

- [ ] **Step 5: Remove the local worktree after the branch is published**

Run from the planning repository:

```bash
git worktree remove .worktrees/azure-deployment-slice
git worktree prune
```

Expected: the durable remote prototype branch and issue evidence remain; the disposable local worktree is gone.
