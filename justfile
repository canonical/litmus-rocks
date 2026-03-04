[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Push an OCI image to docker daemon
[private]
push-to-registry component version:
  echo "Pushing {{component}} {{version}} to local registry"
  cd "{{component}}/{{version}}" && sudo rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false "oci-archive:{{component}}_{{version}}_amd64.rock" docker-daemon:rockcraft-test:latest

# Push an OCI image to MicroK8s local registry (localhost:32000)
[private]
push-to-microk8s component version:
  echo "Pushing {{component}} {{version}} to MicroK8s registry"
  cd "{{component}}/{{version}}" && rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false \
    "oci-archive:{{component}}_{{version}}_amd64.rock" \
    "docker://localhost:32000/{{component}}-dev:{{version}}"
  rockcraft.skopeo --insecure-policy copy --src-tls-verify=false --dest-tls-verify=false \
    "docker://localhost:32000/{{component}}-dev:{{version}}" \
    "docker://localhost:32000/{{component}}-dev:latest"

# Pack a rock of a specific component and version
pack component version:
  cd "{{component}}"; just pack "{{version}}"

# `rockcraft clean` for a specific component and version
clean component version:
  cd "{{component}}"; just clean "{{version}}"

# Run a rock and open a shell into it with `docker`
run component version:
  cd "{{component}}"; just run "{{version}}"

# Test a rock with `rockcraft test`
test component version:
  cd "{{component}}"; just test "{{version}}"


# Run Kubernetes integration tests for all rocks at a given version (ADR-0005)
test-integration version:
  #!/usr/bin/env bash
  set -euo pipefail

  cleanup() {
    rm -f "tests/litmus_integration/chaos-operator_{{version}}_amd64.rock"
    rm -f "tests/litmus_integration/chaos-exporter_{{version}}_amd64.rock"
  }
  trap cleanup EXIT

  echo "+ Staging rock artifacts for spread"
  cp "chaos-operator/{{version}}/chaos-operator_{{version}}_amd64.rock" tests/litmus_integration/
  cp "chaos-exporter/{{version}}/chaos-exporter_{{version}}_amd64.rock" tests/litmus_integration/

  echo "+ Running spread integration tests"
  cd tests/litmus_integration && VERSION={{version}} ~/go/bin/spread ci:
