## 1. Fix Dynamic Devfile Install Script

- [x] 1.1 Replace local script reference in `devfile-dynamic.yaml` `install-tools` command with `curl -fsSL https://raw.githubusercontent.com/unbound-force/containerfile/main/scripts/install-uf-tools.sh | bash`
- [x] 1.2 Keep the OpenCode curl installer line unchanged (already uses curl)
- [x] 1.3 Add a comment in the devfile explaining the GitHub raw URL approach

## 2. Add Factory URL Documentation

- [x] 2.1 Add "Factory URLs" section to README.md under Model C (CDE) documentation
- [x] 2.2 Include default pattern: `https://<che-host>/#https://github.com/unbound-force/containerfile`
- [x] 2.3 Include dynamic devfile pattern: append `?devfilePath=devfile-dynamic.yaml`
- [x] 2.4 Note that Che uses `devfile.yaml` at repo root by default

## 3. Add Red Hat Dev Spaces Notes

- [x] 3.1 Add "Red Hat Dev Spaces" section to README.md
- [x] 3.2 State compatibility status honestly (expected compatible, not yet tested in Dev Spaces)
- [x] 3.3 Note known differences: per-user namespaces, OpenShift OAuth, image registry requirements
- [x] 3.4 Link to Dev Spaces documentation

## 4. Verification

- [x] 4.1 Validate `devfile-dynamic.yaml` parses as valid YAML
- [x] 4.2 Verify the GitHub raw URL resolves (curl exits 0): `curl -fsSL -o /dev/null https://raw.githubusercontent.com/unbound-force/containerfile/main/scripts/install-uf-tools.sh`
- [x] 4.3 Constitution check: Composability (no local dependency), Executable Truth (README matches devfile, honesty about Dev Spaces)
