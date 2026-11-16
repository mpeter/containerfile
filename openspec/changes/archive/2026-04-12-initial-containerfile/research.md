# Research: Initial Containerfile

**Phase**: 0 — Research
**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## R1: Fedora Base Image Selection

**Question**: Which Fedora base image and version strategy to use?

**Decision**: Use `registry.fedoraproject.org/fedora:41` (pinned major
version).

**Rationale**:
- Fedora 41 is the current stable release (as of April 2026).
- Pinning the major version (`fedora:41`) provides reproducibility
  while still receiving security updates via `dnf update`.
- Using `fedora:latest` would cause unpredictable breakage when Fedora
  bumps to the next release.
- Using `fedora:41-YYYYMMDD` (date-pinned) is too rigid — prevents
  security patches without manual bumps.
- Fedora provides official multi-arch images for both `linux/arm64`
  and `linux/amd64`.

**Alternatives rejected**:
- `ubuntu:24.04`: Would work, but Fedora aligns with the Red Hat
  ecosystem (Eclipse Che, Dev Spaces, UDI). Using `dnf` consistently
  across Containerfile and UDI variant simplifies maintenance.
- `alpine:3.20`: Musl libc causes compatibility issues with Go
  binaries built with CGO. Would require static builds.
- `fedora:latest`: Non-deterministic. A Fedora version bump could
  break the build without any code change.

## R2: Multi-Stage Build Strategy

**Question**: Should the Containerfile use multi-stage builds to reduce
image size, or keep Go in the final image?

**Decision**: Single-stage build. Keep Go, Node.js, and all build tools
in the final image.

**Rationale**:
- AI agents running inside the container need `go test`, `go build`,
  `go vet`, and `golangci-lint` to validate their own code changes.
  Stripping Go from the final image would break the core use case.
- Similarly, `npm` is needed for OpenSpec CLI and any Node.js-based
  tooling the agent might use.
- Image size is a secondary concern. Developer productivity and tool
  availability are primary. The image is pulled once and cached.
- Multi-stage builds add complexity for zero benefit when all build
  tools are also runtime tools.

**Alternatives rejected**:
- Multi-stage with Go in builder only: Breaks `go test` inside the
  container. Agents cannot validate Go code changes.
- Multi-stage with selective copy: Same problem. Any tool omitted
  from the final stage is unavailable to agents.

## R3: UDI Base Image Compatibility

**Question**: How does the UDI (Universal Developer Image) differ from
Fedora, and what installation adjustments are needed?

**Decision**: The UDI variant (`Containerfile.udi`) uses
`quay.io/devfile/universal-developer-image:latest` as the base and
installs UF tools on top.

**Key differences**:
- UDI is based on UBI (Universal Base Image) / Fedora, so `dnf` works.
- UDI already includes Go, Node.js, Git, and common developer tools.
  The UF-specific tools (uf, dewey, replicator, gaze, opencode) must
  be installed on top.
- UDI runs as user `user` (UID 1001) by default, not `root`. The
  Containerfile.udi should respect this and NOT switch to root for
  tool installation — use `USER 0` temporarily if needed, then switch
  back.
- UDI includes `$HOME` at `/home/user`, not `/home/dev`. The
  Containerfile.udi should use the UDI's existing user rather than
  creating a new `dev` user.
- Go and Node.js versions in UDI may differ from what we pin in the
  primary Containerfile. Accept UDI's versions for compatibility.

**Alternatives rejected**:
- Creating a `dev` user in UDI: Conflicts with Eclipse Che's
  expectations. Che expects the UDI's default user.
- Replacing UDI's Go/Node.js: Fragile. UDI's tool versions are tested
  together. Overriding them risks breaking the base image.

## R4: Devfile 2.2.0 Schema Requirements

**Question**: What are the key schema requirements for Eclipse Che
devfiles?

**Decision**: Both devfiles conform to Devfile 2.2.0 specification.

**Key requirements**:
- `schemaVersion: 2.2.0` is mandatory at the top level.
- `metadata.name` is required.
- Container components use `container` type with `image`, `memoryLimit`,
  `cpuLimit`, `mountSources`, and `endpoints` fields.
- `endpoints` define exposed ports with `name`, `targetPort`, and
  optional `exposure` (public, internal, none).
- `commands` define lifecycle hooks: `postStart` for tool installation
  in the dynamic devfile.
- `events.postStart` references command IDs for automatic execution.
- Memory/CPU limits use string format: `"8Gi"` for memory, `"4"` for
  CPU cores.
- `mountSources: true` mounts the project source at `/projects`.

**devfile.yaml** (custom image):
- References `quay.io/unbound-force/opencode-dev:latest`.
- Sets resource limits.
- Defines OpenCode server endpoint on port 4096.

**devfile-dynamic.yaml** (UDI + postStart):
- Uses `quay.io/devfile/universal-developer-image:latest`.
- Defines a `postStart` command that runs `install-uf-tools.sh`.
- No custom image dependency — tools installed at workspace start.

## R5: GitHub Actions Multi-Arch Build with Podman

**Question**: How to build multi-arch OCI images in GitHub Actions
using Podman (not Docker)?

**Decision**: Use `podman manifest` with QEMU emulation for cross-arch
builds.

**Approach**:
1. Install QEMU user-static for cross-architecture emulation:
   `sudo apt-get install qemu-user-static`.
2. Create a manifest list: `podman manifest create opencode-dev`.
3. Build for each architecture:
   `podman build --platform linux/arm64 --manifest opencode-dev .`
   `podman build --platform linux/amd64 --manifest opencode-dev .`
4. Push the manifest: `podman manifest push opencode-dev
   quay.io/unbound-force/opencode-dev:latest`.
5. Login to quay.io: `podman login quay.io` with secrets.

**CI triggers**:
- Push to `main`: Build and push with `latest` tag.
- Version tag push (`v*`): Build and push with version tag.
- Pull request: Build only (no push) for validation.

**Alternatives rejected**:
- Docker Buildx: We standardize on Podman. Using Docker in CI while
  requiring Podman locally creates inconsistency.
- GitHub Container Registry (ghcr.io): quay.io is the established
  registry for Red Hat ecosystem images. Aligns with UDI and Dev
  Spaces conventions.

## R6: OpenCode Installation Method

**Question**: How to install OpenCode in the container?

**Decision**: Use the official curl installer.

**Approach**:
```bash
curl -fsSL https://opencode.ai/install | bash
```

**Rationale**:
- OpenCode is not a Go tool — it cannot be installed via `go install`.
- The curl installer is the official distribution method.
- The installer detects architecture (arm64/amd64) automatically.
- The binary is placed in a standard location (`/usr/local/bin` or
  similar).

**Security consideration**: Piping curl to bash is a known anti-pattern
for security. However, this is during image build (not runtime), the
source is the official OpenCode domain, and the resulting image is
verified via smoke tests. The alternative (manual binary download with
checksum) is more complex and requires maintaining checksum values.

## R7: Non-Root User Setup in Fedora Containers

**Question**: How to create and configure a non-root user in the
Fedora-based Containerfile?

**Decision**: Create a `dev` user with a home directory, add to
necessary groups, and set as the default user.

**Approach**:
```dockerfile
RUN useradd -m -s /bin/bash dev
# ... install tools as root ...
USER dev
WORKDIR /home/dev
```

**Key considerations**:
- User creation happens early in the Containerfile so that `go install`
  and other tool installations can target the user's `$GOPATH`.
- However, system packages (`dnf install`) require root. So the
  sequence is: create user → install system packages as root →
  install Go tools as `dev` → set `USER dev` as the final instruction.
- `$GOPATH/bin` must be in `$PATH` for the `dev` user.
- The `dev` user's home directory (`/home/dev`) is the default
  `WORKDIR`.
- File permissions on installed tools must allow execution by the
  `dev` user.

**Alternative approach**: Install everything as root, then `chown` to
`dev`. This is simpler but creates a larger image (duplicate layer
data). Prefer installing as the target user where possible.
