# Quickstart: Initial Containerfile

**Phase**: 1 — Design & Contracts
**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

> Step-by-step instructions for each deployment model. These will
> inform the README.md content during implementation.

## Prerequisites

All models require:
- **Podman** installed and configured for rootless operation
- **A project directory** with a git repository to mount into the container

Optional (for enhanced functionality):
- **Ollama** running on the host at `localhost:11434` (enables Dewey
  semantic embeddings)

## Model A: Interactive (Read-Write Mount)

The simplest deployment. The agent has direct read-write access to
your project files. Use when you trust the agent and want immediate
file changes.

```bash
# 1. Build the image
podman build -t opencode-dev -f Containerfile .

# 2. Verify the build
podman run --rm opencode-dev uf --version
podman run --rm opencode-dev opencode --version
podman run --rm opencode-dev dewey --version
podman run --rm opencode-dev replicator --version
podman run --rm opencode-dev gaze --version
podman run --rm opencode-dev whoami   # should print "dev"

# 3. Run interactively with your project mounted
podman run -it --rm \
  --memory 8g --cpus 4 \
  -v ./my-project:/workspace:Z \
  -e DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434 \
  opencode-dev
```

**Security properties**: Agent can read and write host files directly.
Resource limits enforced. No secrets in image.

## Model B: Headless (Read-Only Mount + Format-Patch)

Maximum isolation. The source directory is mounted read-only. The agent
works on an internal writable copy. Changes are extracted via
`git format-patch` for human review before applying to the host.

**How it works**: The `podman-compose.yml` mounts the host project
directory as read-only at `/workspace` and provides a separate writable
volume (the work directory) where the agent operates. The entrypoint
creates a working copy from the read-only source into the writable
area. The agent makes changes in the writable copy, and
`extract-changes.sh` generates patches from that copy. The host source
is never modified directly.

```bash
# 1. Build the image (same as Model A)
podman build -t opencode-dev -f Containerfile .

# 2. Start the headless server
podman-compose up -d

# 3. Connect from the host
./scripts/connect.sh

# 4. After the agent makes changes, extract them
podman exec opencode-server /scripts/extract-changes.sh

# 5. Review and apply patches on the host
git am < patches/*.patch

# 6. Stop the server
podman-compose down
```

**Security properties**: Agent CANNOT modify host files. Read-only
source mount. Changes require human review via format-patch. Resource
limits enforced. No secrets in image.

## Model C: CDE (Eclipse Che / Dev Spaces)

Cloud development environment. Use when working in Eclipse Che or
Red Hat Dev Spaces.

### Option 1: Custom Image (fast startup)

```yaml
# Use devfile.yaml — references the pre-built custom image
# Create workspace in Eclipse Che pointing to this repo
# All tools are immediately available
```

### Option 2: Dynamic (UDI + postStart, no custom image)

```yaml
# Use devfile-dynamic.yaml — uses UDI base image
# Tools are installed via postStart commands at workspace creation
# Slower startup, but no custom image dependency
```

**Security properties**: Workspace-level isolation managed by Eclipse
Che. Resource limits set in devfile. No secrets in image.

## Smoke Test Suite

After building any image variant, run the full smoke test:

```bash
IMAGE=opencode-dev  # or opencode-dev-udi

# Tool version checks
podman run --rm $IMAGE uf --version
podman run --rm $IMAGE opencode --version
podman run --rm $IMAGE dewey --version
podman run --rm $IMAGE replicator --version
podman run --rm $IMAGE gaze --version

# Non-root verification
podman run --rm $IMAGE whoami   # must print "dev" (or "user" for UDI)

# Go toolchain
podman run --rm $IMAGE go version
podman run --rm $IMAGE golangci-lint --version
podman run --rm $IMAGE govulncheck -version

# Node.js toolchain
podman run --rm $IMAGE node --version
podman run --rm $IMAGE npm --version

# Git and GitHub CLI
podman run --rm $IMAGE git --version
podman run --rm $IMAGE gh --version
```

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `host.containers.internal` not resolving | Podman version or platform limitation | Set `DEWEY_EMBEDDING_ENDPOINT` to host IP manually |
| SELinux denying volume access | Missing `:Z` relabel | Add `:Z` suffix to volume mount |
| `go install` fails during build | Network access required | Ensure build environment has internet access |
| OpenCode not starting | Port 4096 already in use | Stop conflicting process or change port mapping |
| `whoami` returns `root` | Containerfile `USER` instruction missing | Verify `USER dev` is the final user instruction |
