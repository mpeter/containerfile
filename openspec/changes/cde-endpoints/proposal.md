## Why

The CDE devfiles (devfile.yaml and devfile-dynamic.yaml) have three
gaps that prevent the full demo workflow in Eclipse Che / Dev Spaces:

1. **Only port 4096 exposed** — engineers cannot demo web apps or
   APIs built by the agent because no public endpoints exist for
   common application ports (3000, 8080, 8443).

2. **Ollama endpoint uses `host.containers.internal`** — this
   hostname is Podman-specific and does not resolve in Kubernetes
   where Che/Dev Spaces runs. Dewey semantic search fails silently.

3. **No auto-start for OpenCode server** — the `start-server`
   command exists but is not in `events.postStart`. Engineers must
   manually start it after workspace creation.

Ref: [Issue #3](https://github.com/unbound-force/containerfile/issues/3),
[Discussion #88 CDE update](https://github.com/orgs/unbound-force/discussions/88#discussioncomment-16545846),
[unbound-force#95](https://github.com/unbound-force/unbound-force/issues/95).

## What Changes

### devfile.yaml + devfile-dynamic.yaml

- Add demo endpoints for agent-built applications (ports 3000,
  8080, 8443) with `exposure: public`.
- Replace hardcoded `host.containers.internal` Ollama endpoint
  with an empty default. Document how to configure per environment.
- Add `start-server` to `events.postStart` so OpenCode starts
  automatically.

### README.md

- Document the demo endpoints and their intended use.
- Add Ollama configuration guidance for CDE vs local Podman.

## Capabilities

### New Capabilities
- `demo-http`: Public endpoint on port 3000 for agent-built web apps
- `demo-api`: Public endpoint on port 8080 for agent-built APIs
- `demo-alt`: Public endpoint on port 8443 for alternate services
- Auto-start OpenCode server on workspace creation

### Modified Capabilities
- `DEWEY_EMBEDDING_ENDPOINT`: Changed from hardcoded Podman hostname
  to empty default with per-environment configuration guidance
- `opencode-server` endpoint: Unchanged (port 4096, internal)

### Removed Capabilities
- None

## Impact

- **devfile.yaml**: 3 new endpoint blocks, env var change, postStart event
- **devfile-dynamic.yaml**: Same changes as devfile.yaml
- **README.md**: New "CDE Endpoints" and "Ollama in CDE" sections
- **entrypoint.sh**: No changes needed — already handles missing Ollama gracefully
- **Containerfile / Containerfile.base**: No changes — endpoints are devfile-level config

## Constitution Alignment

Assessed against the containerfile project constitution (v1.0.0),
which extends the Unbound Force org constitution (v1.1.0).

### I. Composability First

**Assessment**: PASS

Demo endpoints are additive — they expose ports that may or may not
be used. The OpenCode server endpoint remains unchanged. Making
`DEWEY_EMBEDDING_ENDPOINT` empty by default improves composability:
the container starts without requiring any host service, and Ollama
can be provided when available.

### II. Security Through Isolation

**Assessment**: PASS

Demo endpoints use `exposure: public` which is appropriate for CDE
(Che manages ingress and authentication). No secrets are added to
the devfile. The `opencode-server` endpoint stays `internal`. No
changes to the container image or security model.

### III. Reproducible Builds

**Assessment**: N/A

No Containerfile or CI workflow changes. Only devfile YAML and
documentation are modified.

### IV. Executable Truth

**Assessment**: PASS

README documentation will be updated to match the new devfile
configuration. No stale documentation will remain.
