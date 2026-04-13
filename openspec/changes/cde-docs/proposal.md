## Why

The CDE devfiles and documentation have three gaps:

1. **Dynamic devfile postStart fails for non-containerfile repos** —
   `devfile-dynamic.yaml` references `/projects/scripts/install-uf-tools.sh`
   which only exists if the containerfile repo itself is cloned. If an
   engineer clones their own project (e.g., `unbound-force/gaze`), the
   postStart fails because the script isn't there.

2. **No factory URL documentation** — Eclipse Che supports one-click
   workspace creation via factory URLs
   (`https://che.example.com/#https://github.com/...`), but this isn't
   documented. Engineers don't know they can create a workspace directly
   from a GitHub URL.

3. **No Red Hat Dev Spaces notes** — The devfiles should work with
   Red Hat OpenShift Dev Spaces (enterprise Che), but compatibility
   is undocumented and known differences aren't called out.

Ref: [Issue #5](https://github.com/unbound-force/containerfile/issues/5)

## What Changes

### devfile-dynamic.yaml

Replace the local script reference with a curl download from the
containerfile repo's main branch on GitHub. This removes the
dependency on the containerfile repo being the cloned project.

### README.md

- Add factory URL documentation with patterns and examples
- Add Red Hat Dev Spaces compatibility notes

## Capabilities

### New Capabilities
- `factory-url`: One-click workspace creation via Che factory URL documented
- `remote-install`: Dynamic devfile downloads install script from GitHub (no local dependency)

### Modified Capabilities
- `install-tools` (devfile-dynamic.yaml): Changes from local file reference to curl-from-GitHub download

### Removed Capabilities
- None

## Impact

- **devfile-dynamic.yaml**: `install-tools` command rewritten to use curl
- **README.md**: New "Factory URLs" and "Red Hat Dev Spaces" sections
- **No Containerfile changes**: The install script itself is unchanged
- **No CI changes**: Devfile modifications don't affect container image builds

## Constitution Alignment

Assessed against the containerfile project constitution (v1.0.0).

### I. Composability First

**Assessment**: PASS

The curl-from-GitHub approach improves composability: the dynamic
devfile no longer requires the containerfile repo to be the cloned
project. Any project can use `devfile-dynamic.yaml` by copying it
into their repo — the install script is fetched at runtime.

### II. Security Through Isolation

**Assessment**: N/A

No security model changes. The curl-from-GitHub pattern has the
same risk profile as the existing OpenCode curl installer (already
mitigated by container isolation per Constitution II).

### III. Reproducible Builds

**Assessment**: N/A

No Containerfile or CI changes.

### IV. Executable Truth

**Assessment**: PASS

README documentation will be updated to match the new devfile
behavior. Factory URL patterns will be verified. Dev Spaces
compatibility will be documented honestly (tested vs untested).
