# containerfile

Container image for running [OpenCode](https://opencode.ai) and the full
[Unbound Force](https://github.com/unbound-force) toolchain inside Podman
containers. Security through isolation.

## Prerequisites

- **Podman** installed and configured for rootless operation
- **A project directory** with a git repository to mount into the container

Optional:

- **Ollama** running on the host at `localhost:11434` (enables Dewey
  semantic embeddings). The container connects via
  `DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434`.
  Ollama is never installed inside the container.

## Quick Start

```bash
# Build the image
podman build -t opencode-dev -f Containerfile .

# Run interactively with your project mounted
podman run -it --rm \
  --memory 8g --cpus 4 \
  -v ./my-project:/workspace:Z \
  -e DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434 \
  opencode-dev
```

## Deployment Models

### Model A: Interactive Development

Read-write volume mount with shell access. The agent has direct access
to your project files. Use when you trust the agent and want immediate
file changes.

```bash
podman run -it --rm \
  --memory 8g --cpus 4 \
  -v ./my-project:/workspace:Z \
  -e DEWEY_EMBEDDING_ENDPOINT=http://host.containers.internal:11434 \
  opencode-dev
```

**Security properties**: Agent can read and write host files directly.
Resource limits enforced. No secrets in image.

### Model B: Headless Server

Maximum isolation. The source directory is mounted read-only. The agent
works on an internal writable copy. Changes are extracted via
`git format-patch` for human review before applying to the host.

```bash
# Start the headless server
podman-compose up -d

# Connect from the host
./scripts/connect.sh

# After the agent makes changes, extract them
podman exec opencode-server /usr/local/bin/extract-changes.sh

# Review and apply patches on the host
git am < patches/*.patch

# Stop the server
podman-compose down
```

The `podman-compose.yml` mounts the host project directory as read-only
at `/workspace` and provides a separate writable volume where the agent
operates. The entrypoint creates a working copy from the read-only
source. The host source is never modified directly.

**Security properties**: Agent cannot modify host files. Read-only source
mount. Changes require human review via format-patch. Resource limits
enforced. No secrets in image.

### Model C: CDE / Eclipse Che

Cloud development environment for Eclipse Che or Red Hat Dev Spaces.

**Option 1 — Custom image (fast startup)**: Use `devfile.yaml`, which
references the pre-built `quay.io/unbound-force/opencode-dev:latest`
image. All tools are immediately available.

**Option 2 — Dynamic (no custom image)**: Use `devfile-dynamic.yaml`,
which uses the Universal Developer Image and installs tools via
`postStart` commands. Slower startup, but no custom image dependency.

**Security properties**: Workspace-level isolation managed by Eclipse
Che. Resource limits set in devfile. No secrets in image.

## Security Model

These constraints are non-negotiable:

1. **Podman rootless** — no daemon, user namespace isolation
2. **Non-root user** — container runs as `dev` (or `user` for UDI variant)
3. **No secrets in image** — no SSH keys or git push tokens
4. **Read-only mounts** — headless mode (Model B) mounts source read-only
5. **Resource limits** — `--memory 8g --cpus 4`
6. **SELinux** — volume mounts use `:Z` relabeling on Fedora
7. **Ollama on host** — never installed in the container; connects via
   `DEWEY_EMBEDDING_ENDPOINT`

## Change Extraction

In headless mode (Model B), the agent cannot write to the host
filesystem. Changes are extracted using `git format-patch`:

```bash
# Extract patches to stdout
podman exec opencode-server /usr/local/bin/extract-changes.sh

# Extract patches to a directory
podman exec opencode-server /usr/local/bin/extract-changes.sh /tmp/patches

# Apply patches on the host after review
git am < patches/*.patch
```

The extract script detects uncommitted changes, creates a temporary
commit if needed, and generates standard `git format-patch` output.
In interactive mode (Model A), the agent writes directly to the
mounted project directory — no extraction needed.

## Smoke Test Suite

After building any image variant, run the full smoke test:

```bash
IMAGE=opencode-dev  # or opencode-dev-udi for the UDI variant

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

Build the UDI variant:

```bash
podman build -t opencode-dev-udi -f Containerfile.udi .
```

## Repository Structure

```
Containerfile              Multi-arch OCI image (Fedora base)
Containerfile.udi          CDE variant (UDI base)
devfile.yaml               Eclipse Che workspace (custom image)
devfile-dynamic.yaml       Eclipse Che workspace (UDI + postStart)
podman-compose.yml         Headless server orchestration
scripts/
  install-uf-tools.sh      Install all UF tools via go install + npm
  entrypoint.sh            Container entrypoint
  extract-changes.sh       Git format-patch extraction
  connect.sh               Host-side attach script
.github/workflows/
  build-push.yml           CI: multi-arch build + push to quay.io
```

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `host.containers.internal` not resolving | Podman version or platform limitation | Set `DEWEY_EMBEDDING_ENDPOINT` to host IP manually |
| SELinux denying volume access | Missing `:Z` relabel | Add `:Z` suffix to volume mount |
| `go install` fails during build | Network access required | Ensure build environment has internet access |
| OpenCode not starting | Port 4096 already in use | Stop conflicting process or change port mapping |
| `whoami` returns `root` | Containerfile `USER` instruction missing | Verify `USER dev` is the final user instruction |

## License

Apache 2.0 — see [LICENSE](LICENSE).
