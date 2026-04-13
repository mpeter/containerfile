## ADDED Requirements

### Requirement: Demo HTTP Endpoint

Both devfiles MUST expose port 3000 as a public endpoint named
`demo-http` with `protocol: https` for agent-built web applications.

#### Scenario: Agent builds a web app on port 3000
- **GIVEN** a Che workspace running with devfile.yaml
- **WHEN** the agent starts a web server on port 3000
- **THEN** the engineer can access it via the `demo-http` public URL
  provided by Che's ingress

### Requirement: Demo API Endpoint

Both devfiles MUST expose port 8080 as a public endpoint named
`demo-api` with `protocol: https` for agent-built API services.

#### Scenario: Agent builds an API server on port 8080
- **GIVEN** a Che workspace running with devfile.yaml
- **WHEN** the agent starts an API server on port 8080
- **THEN** the engineer can curl the `demo-api` public URL from
  outside the workspace

### Requirement: Demo Alt Endpoint

Both devfiles MUST expose port 8443 as a public endpoint named
`demo-alt` with `protocol: https` for alternate services.

#### Scenario: Agent uses a non-standard port
- **GIVEN** a Che workspace running with devfile.yaml
- **WHEN** the agent starts a service on port 8443
- **THEN** the engineer can access it via the `demo-alt` public URL

### Requirement: Auto-Start OpenCode Server

Both devfiles MUST include `start-server` in `events.postStart`
so the OpenCode server starts automatically after workspace creation.

#### Scenario: Workspace starts with OpenCode ready
- **GIVEN** an engineer creating a new Che workspace from devfile.yaml
- **WHEN** the workspace finishes initializing
- **THEN** the OpenCode server is running on port 4096 without
  manual intervention

#### Scenario: Dynamic devfile installs tools then starts server
- **GIVEN** an engineer creating a workspace from devfile-dynamic.yaml
- **WHEN** the postStart events complete
- **THEN** tools are installed, workspace initialized, and OpenCode
  server is running (in that order)

## MODIFIED Requirements

### Requirement: Ollama Endpoint Configuration

`DEWEY_EMBEDDING_ENDPOINT` MUST be set to an empty string in both
devfiles. The devfile SHOULD include a comment documenting how to
configure it per environment.

Previously: `DEWEY_EMBEDDING_ENDPOINT` was set to
`http://host.containers.internal:11434` which only resolves in
Podman, not Kubernetes.

#### Scenario: CDE workspace starts without Ollama configured
- **GIVEN** a Che workspace with default (empty) DEWEY_EMBEDDING_ENDPOINT
- **WHEN** Dewey initializes
- **THEN** semantic search is unavailable but keyword search works
  and the workspace is fully functional

#### Scenario: Engineer configures Ollama via Che preferences
- **GIVEN** an engineer who sets DEWEY_EMBEDDING_ENDPOINT in Che user preferences
- **WHEN** the workspace starts
- **THEN** Dewey connects to the configured Ollama endpoint and
  semantic search is available

### Requirement: README CDE Documentation

README.md MUST document the demo endpoints (ports, names, intended
use) and Ollama configuration guidance for CDE environments.

Previously: README documented only local Podman Ollama setup.

## REMOVED Requirements

None.
