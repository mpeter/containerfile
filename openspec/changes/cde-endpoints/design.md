## Context

The CDE devfiles expose only port 4096 (OpenCode server, internal),
hardcode `host.containers.internal` for Ollama (Podman-only hostname),
and don't auto-start the OpenCode server. These gaps prevent the
iterative demo loop in Eclipse Che / Dev Spaces.

See proposal.md for full motivation and constitution alignment.

## Goals / Non-Goals

### Goals
- Expose demo endpoints (3000, 8080, 8443) for agent-built apps
- Make Ollama endpoint configurable (empty default, per-env setup)
- Auto-start OpenCode server via postStart event
- Document CDE endpoint and Ollama configuration in README

### Non-Goals
- Installing Ollama inside the container (Constitution II violation)
- Changing the Containerfile or base image
- Adding credential injection (tracked in Issue #4)
- Changing the OpenCode server port or exposure level

## Decisions

### D1: Demo endpoint port selection (3000, 8080, 8443)

**Decision**: Expose ports 3000 (HTTP), 8080 (API), and 8443
(HTTPS/alt) as public endpoints.

**Rationale**: These are the most common default ports for web
frameworks (Next.js/Vite → 3000, Go/Spring → 8080, HTTPS → 8443).
Covering these three handles the majority of agent-built demo apps
without requiring devfile edits. If an agent builds on a non-standard
port, the engineer can add a temporary endpoint via Che's UI.

### D2: Empty DEWEY_EMBEDDING_ENDPOINT default

**Decision**: Set `DEWEY_EMBEDDING_ENDPOINT` to empty string in
devfiles. Document per-environment configuration.

**Rationale**: An empty value causes Dewey to skip embeddings
gracefully (keyword search still works). This is better than a
hostname that fails to resolve in K8s, which causes confusing
connection timeouts. The engineer sets the correct value for their
environment via Che user preferences or K8s secret.

For local Podman, the value is still set in podman-compose.yml and
the Containerfile ENV — those are not changed.

### D3: postStart event ordering

**Decision**: Add `start-server` after `init-workspace` in
`events.postStart`.

**Rationale**: `init-workspace` runs `uf init` which sets up the
project. The OpenCode server should start after initialization so
it can discover the project configuration. For the dynamic devfile,
`install-tools` must run before both.

Ordering:
- **devfile.yaml**: `init-workspace` → `start-server`
- **devfile-dynamic.yaml**: `install-tools` → `init-workspace` → `start-server`

### D4: Keep opencode-server as internal

**Decision**: The OpenCode server endpoint (4096) stays
`exposure: internal`.

**Rationale**: The OpenCode server is accessed via `opencode attach`,
not via browser. Making it public would expose it to anyone with the
Che ingress URL. Per Constitution II (Security Through Isolation),
internal exposure is appropriate.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| Port conflicts if agent uses 3000/8080/8443 for something else | Low — unlikely, standard ports | Engineer can modify devfile |
| Empty Ollama endpoint means no semantic search by default in CDE | Medium — keyword search still works | Document setup steps clearly in README |
| postStart `start-server` may fail if OpenCode binary missing | Low — only affects broken images | entrypoint.sh already handles gracefully |
| Adding 3 public endpoints increases attack surface in CDE | Low — Che manages ingress + auth | Standard practice for Che workspaces |
