## 1. Update devfile.yaml

- [x] 1.1 Add demo endpoints: `demo-http` (port 3000, public), `demo-api` (port 8080, public), `demo-alt` (port 8443, public) with `protocol: https` to the container component's `endpoints` array
- [x] 1.2 Change `DEWEY_EMBEDDING_ENDPOINT` env value from `http://host.containers.internal:11434` to empty string `""`
- [x] 1.3 Add `events.postStart` section with `init-workspace` and `start-server` commands in that order

## 2. Update devfile-dynamic.yaml

- [x] 2.1 Add the same 3 demo endpoints as devfile.yaml (`demo-http`, `demo-api`, `demo-alt`)
- [x] 2.2 Change `DEWEY_EMBEDDING_ENDPOINT` env value to empty string `""`
- [x] 2.3 Update `events.postStart` to include `start-server` after `install-tools` and `init-workspace`

## 3. Update README.md

- [x] 3.1 Add "CDE Endpoints" section documenting the demo endpoints (port, name, intended use, how Che exposes them)
- [x] 3.2 Add "Ollama in CDE" section explaining how to configure `DEWEY_EMBEDDING_ENDPOINT` via Che user preferences or K8s secret, with examples for local Podman vs CDE

## 4. Verification

- [x] 4.1 Validate both devfiles parse as valid YAML
- [x] 4.2 Verify `DEWEY_EMBEDDING_ENDPOINT` is empty in both devfiles and unchanged in Containerfile/podman-compose.yml (local Podman path unaffected)
- [x] 4.3 Constitution alignment check: Composability (empty Ollama default = graceful degradation), Security (demo endpoints are public but Che-managed), Executable Truth (README matches devfile config)
