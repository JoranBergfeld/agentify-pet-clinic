# Java Agent Framework for the Clinic Assistant

Research for [Identify the Java agent framework for the Clinic Assistant](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/13), verified against primary sources on 2026-08-11.

## Recommendation

Use **Spring AI 2.0.0** with its OpenAI chat starter configured for a Microsoft Foundry resource through its OpenAI-compatible endpoint.

Keep the application boundary framework-agnostic:

1. A read-only query facade exposes only the PetClinic information the Clinic Assistant may retrieve.
2. A Spring AI adapter publishes those facade operations as tools.
3. The chat endpoint depends on the assistant service, not directly on PetClinic repositories or Spring AI annotations.

This makes Spring AI the workshop implementation rather than the definition of the Clinic Assistant.

## Candidate comparison

| Candidate | Java support | Spring Boot fit | Tool calling | Workshop fit |
| --- | --- | --- | --- | --- |
| Microsoft Agent Framework | No | None | Not applicable | Disqualified |
| Semantic Kernel Java 1.5.0 | Yes | Manual integration | Native plugins and automatic function calling | Viable, but more framework and reactive wiring |
| Spring AI 2.0.0 | Yes | First-party Spring Boot 4.1 integration | Annotation-based and programmatic tools | Recommended |
| Azure Java SDKs | Yes | Low-level clients | Requires a custom orchestration loop against Foundry APIs | Too much infrastructure or framework code |

## Microsoft Agent Framework

Microsoft's current documentation describes Agent Framework for .NET, Python, and Go. It does not publish a Java runtime or Maven artifact, so it cannot be embedded in Spring PetClinic.

## Why Spring AI

- Spring AI 2.0.0 release notes explicitly include an upgrade to Spring Boot 4.1.0.
- Spring AI provides Spring Boot starters and a fluent `ChatClient`.
- Existing Java methods can be exposed as model tools using `@Tool` or `MethodToolCallback`.
- Tool descriptions and generated JSON schemas make bounded read-only operations explicit.
- The Azure-specific chat integration was consolidated into the OpenAI chat client in Spring AI 2.0.0-M5 for Azure and Microsoft Foundry deployments.
- The implementation remains inside the existing Spring Boot process.

Semantic Kernel Java supports Azure OpenAI, native plugins, and automatic function calling, but it lacks the same first-party Spring Boot integration and would introduce additional concepts that do not serve the workshop's learning goal.

## Recommended boundary

The Clinic Assistant receives only a small read-only query surface, initially shaped around:

- Find owners by name.
- Retrieve an owner and their pets.
- Retrieve a pet and its Visits.
- List veterinarians and specialties.

The tool adapter returns purpose-built result records rather than exposing JPA entities or unrestricted repositories. No write operation, direct database access, arbitrary query, or infrastructure tool is available to the model.

## Azure footprint

The Clinic Assistant requires a Microsoft Foundry resource (`Microsoft.CognitiveServices/accounts`, `kind: AIServices`) and a deployed chat model in addition to the existing PetClinic hosting resources. It does not require a Foundry project, Foundry Agent Service, Azure AI Search, or another database for the workshop slice.

The exact model, region, quota, authentication mode, permissions, and cost controls remain inputs to [Document the Azure permission and cost envelope](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/12).

## Primary sources

- [Microsoft Agent Framework overview](https://learn.microsoft.com/en-us/agent-framework/overview/)
- [Spring AI 2.0.0 release](https://github.com/spring-projects/spring-ai/releases/tag/v2.0.0)
- [Spring AI getting started](https://docs.spring.io/spring-ai/reference/getting-started.html)
- [Spring AI tool calling](https://docs.spring.io/spring-ai/reference/api/tools.html)
- [Spring AI Azure OpenAI migration note](https://docs.spring.io/spring-ai/reference/api/chat/azure-openai-chat.html)
- [Semantic Kernel supported languages and features](https://learn.microsoft.com/en-us/semantic-kernel/get-started/supported-languages)
- [Semantic Kernel Java Maven metadata](https://repo1.maven.org/maven2/com/microsoft/semantic-kernel/semantickernel-api/maven-metadata.xml)
- [Spring AI BOM Maven metadata](https://repo1.maven.org/maven2/org/springframework/ai/spring-ai-bom/maven-metadata.xml)
