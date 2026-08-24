# Workshop Devcontainer Design

## Purpose

Provide one feature-based development container that supports the complete
attendee workshop path in both GitHub Codespaces and local VS Code Dev
Containers.

## Current state

The inherited Spring PetClinic devcontainer already selects Java 21 and
includes Azure CLI, Docker-in-Docker, and GitHub CLI. It does not install Azure
Developer CLI (`azd`), configure the application port for Codespaces, include
the supported Copilot extension, or verify the workshop toolchain after the
container is created.

The checked-in `.devcontainer/Dockerfile` is not used by
`devcontainer.json`. Its Java 17 and legacy image configuration contradict the
workshop's Java 21 environment and creates a second environment definition
that can drift.

## Design

### Feature-based environment

Keep `mcr.microsoft.com/devcontainers/base:ubuntu` and use maintained Dev
Container Features for:

- Java 21;
- Azure CLI;
- Azure Developer CLI (`azd`);
- GitHub CLI;
- Docker-in-Docker; and
- common command-line utilities, including `curl` and `jq`.

Use the current official feature identifiers:

- `ghcr.io/devcontainers/features/java:1`;
- `ghcr.io/devcontainers/features/azure-cli:1`;
- `ghcr.io/azure/azd-devcontainer-feature/azd:1`;
- `ghcr.io/devcontainers/features/github-cli:1`;
- `ghcr.io/devcontainers/features/docker-in-docker:4`; and
- `ghcr.io/devcontainers/features/common-utils:2`.

Retain the non-root `vscode` remote user. Remove the unused Dockerfile so
`devcontainer.json` remains the single environment definition.

### Editor and Codespaces behavior

Install:

- `GitHub.copilot-chat`;
- `vscjava.vscode-java-pack`; and
- `redhat.vscode-xml`.

Forward application port `8080`, label it `Spring PetClinic`, and open it in
the browser once the application begins listening. Do not configure public
port visibility.

### Creation-time verification

Add `.devcontainer/verify-workshop-tools.sh`. It must:

- run without Azure, GitHub, or Docker authentication;
- verify that `git`, `java`, `gh`, `az`, `azd`, `docker`, `curl`, and `jq`
  are executable;
- verify that Java's major version is 21;
- report every missing or invalid requirement before failing;
- print tool versions without exposing credentials; and
- return non-zero when the toolchain is incomplete.

Run the script from `postCreateCommand`, followed by a Maven dependency
warm-up using the repository wrapper. Container creation must fail visibly if
tool verification or dependency warm-up fails; no success-shaped fallback is
allowed.

### Authority and security boundaries

The devcontainer installs tools but does not:

- authenticate GitHub or Azure clients;
- persist, request, or generate credentials;
- select an Azure subscription;
- create an `azd` environment;
- run workshop readiness, Preflight, deployment, or cleanup;
- provision any resource; or
- change application behavior.

Authentication and all consequential Azure actions remain explicit,
attendee-owned steps in the Azure Preflight and cleanup guide.

### Documentation boundary

Do not edit `README.md` or add a separate usage document in this change.
PR #46 already owns the participant README path, and the user explicitly chose
configuration-only delivery for this tweak.

## Files

- Modify `.devcontainer/devcontainer.json`.
- Add `.devcontainer/verify-workshop-tools.sh`.
- Delete `.devcontainer/Dockerfile`.

No application, infrastructure, workflow, or participant-guide files change.

## Validation

The implementation must provide fresh evidence that:

1. `devcontainer.json` is valid JSON.
2. Every required feature, extension, port attribute, and command is present.
3. The verification script passes shell syntax checking.
4. A fixture-based tool-path test proves the script reports all missing tools,
   rejects a non-Java-21 runtime, and accepts a complete Java 21 toolchain
   without requiring actual cloud authentication.
5. The configured `postCreateCommand` invokes verification before Maven
   dependency warm-up.
6. `.devcontainer/Dockerfile` is absent.
7. The repository's existing validation and application tests remain green.

Building the container is the strongest end-to-end evidence when a compatible
Docker/devcontainer CLI is locally available. If it is unavailable, that gap
must be reported rather than replaced with a claimed build result.
