# GitHub Copilot Client Support for the Reference Workflow

Research for [Verify GitHub Copilot client support for the Reference Workflow](https://github.com/JoranBergfeld/agentify-pet-clinic/issues/11), verified against official GitHub and VS Code documentation on 2026-08-11.

## Recommendation

Use **VS Code with GitHub Copilot Chat in agent mode** as the reference client. Fully support **GitHub Copilot CLI** as an alternative. Allow **JetBrains agent mode** with an explicit preview caveat.

Other clients may be used only when the attendee has proven during preflight that they can consume the repository assets required by the exercise. Workshop time is not used to adapt or repair unsupported clients.

## Portable repository assets

The smallest documented common set across VS Code agent mode, Copilot CLI, JetBrains agent mode, and the GitHub Copilot cloud agent is:

1. Repository instructions in `.github/copilot-instructions.md`
2. Scoped instructions in `.github/instructions/*.instructions.md`
3. Root agent instructions such as `AGENTS.md`
4. Custom agents in `.github/agents/*.agent.md`
5. Agent skills in `.github/skills/<name>/SKILL.md`

Do not make prompt files in `.github/prompts/*.prompt.md` part of the core workshop path. They are not supported by Copilot CLI and are not consumed by the VS Code Agent Host; skills are the portable replacement.

## Support matrix

| Workshop asset | VS Code agent mode | Copilot CLI | JetBrains agent mode | GitHub cloud agent |
| --- | --- | --- | --- | --- |
| Repository instructions | Supported | Supported | Supported | Supported |
| Scoped instructions | Supported | Supported | Supported | Supported |
| Root `AGENTS.md` | Supported | Supported | Supported through cloud-agent flows | Supported |
| Custom agents | Supported | Supported | Public preview | Supported |
| Agent skills | Supported | Supported | Supported | Supported |
| Prompt files | Preview; unavailable to Agent Host | Not supported | Preview | Not supported |

Support in Eclipse, Xcode, and Visual Studio does not cover the full portable asset set consistently enough for them to be supported workshop clients.

## Authentication and policy prerequisites

- An active GitHub Copilot subscription with sufficient agent usage is required; do not rely on Copilot Free allowances.
- VS Code participants need GitHub Copilot Chat, agent mode, a trusted workspace, and repository access.
- Copilot CLI participants need the CLI installed and authenticated.
- Organization-managed accounts must permit the chosen agent mode, Copilot CLI where used, and repository customizations.
- Each participant must prove access independently before the workshop; paired work never relies on account sharing.

## Attendee policy

> The reference client is VS Code with GitHub Copilot Chat in agent mode. GitHub Copilot CLI is a fully supported alternative. JetBrains may be used after successful preflight, with the understanding that custom agents remain in public preview. Other clients are attendee-supported and must demonstrate the repository instructions, custom agents, and skills before attendance.

## Primary sources

- [Custom instructions support](https://docs.github.com/en/copilot/reference/custom-instructions-support)
- [Adding repository instructions in an IDE](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions-in-your-ide/add-repository-instructions-in-your-ide)
- [Custom agents](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-custom-agents)
- [Custom agent configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
- [Agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)
- [Adding skills to Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
- [Response customization and prompt files](https://docs.github.com/en/copilot/concepts/prompting/response-customization)
- [VS Code prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files)
- [Copilot CLI setup](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)
- [Copilot plans](https://docs.github.com/en/copilot/get-started/plans)
