## ADDED Requirements

### Requirement: Factory URL Documentation

README.md MUST document Eclipse Che factory URL patterns for one-click
workspace creation, including:
- Default pattern (`https://che.example.com/#<repo-url>`)
- Explicit devfile path for the dynamic variant
- At least one concrete example URL

#### Scenario: Engineer creates workspace via factory URL
- **GIVEN** an engineer with access to an Eclipse Che instance
- **WHEN** they navigate to `https://che.example.com/#https://github.com/unbound-force/containerfile`
- **THEN** Che creates a workspace using `devfile.yaml` from the repo root

#### Scenario: Engineer uses dynamic devfile via factory URL
- **GIVEN** an engineer who wants the UDI-based dynamic devfile
- **WHEN** they append `?devfilePath=devfile-dynamic.yaml` to the factory URL
- **THEN** Che creates a workspace using `devfile-dynamic.yaml` instead

### Requirement: Red Hat Dev Spaces Documentation

README.md MUST include a "Red Hat Dev Spaces" section noting:
- Expected compatibility status (tested or untested — be honest)
- Known differences from open-source Eclipse Che
- Link to Dev Spaces documentation

#### Scenario: Engineer looks for Dev Spaces guidance
- **GIVEN** an engineer using Red Hat OpenShift Dev Spaces
- **WHEN** they read the README
- **THEN** they find guidance on compatibility and any known differences

## MODIFIED Requirements

### Requirement: Dynamic Devfile Install Script

The `install-tools` command in `devfile-dynamic.yaml` MUST download
`install-uf-tools.sh` from the containerfile repo's GitHub raw URL
instead of referencing a local file path. The download MUST use
`curl -fsSL` with the `main` branch URL.

Previously: The command referenced `/projects/scripts/install-uf-tools.sh`
which only exists when the containerfile repo is the cloned project.

#### Scenario: Dynamic devfile with a non-containerfile project
- **GIVEN** an engineer who clones `unbound-force/gaze` into a Che workspace
  using `devfile-dynamic.yaml`
- **WHEN** the postStart event runs `install-tools`
- **THEN** the script is downloaded from GitHub and tools are installed
  successfully

#### Scenario: GitHub raw URL is unavailable
- **GIVEN** a workspace where `raw.githubusercontent.com` is unreachable
- **WHEN** the postStart event runs `install-tools`
- **THEN** the curl command fails with a clear error (exit 1) and the
  workspace starts without UF tools installed

## REMOVED Requirements

None.
