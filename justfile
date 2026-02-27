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
  cd "{{component}}/{{version}}" && rockcraft pack

# `rockcraft clean` for a specific component and version
clean component version:
  cd "{{component}}/{{version}}" && rockcraft clean

# Run a rock and open a shell into it with `docker`
run component version: (push-to-registry component version)
  docker run --rm --name rockcraft-test rockcraft-test:latest

# Test a rock with `rockcraft test`
test component version:
  cp spread.yaml "{{component}}/{{version}}/spread.yaml"
  cp "{{component}}/goss.yaml" "{{component}}/{{version}}/goss.yaml"
  cd "{{component}}/{{version}}" && rockcraft test

# Run Kubernetes integration tests for all rocks at a given version (ADR-0005)
test-integration version:
  #!/usr/bin/env bash
  set -euo pipefail
  NAMESPACE="test-litmus-rocks-integration"
  CRD_TAG="{{ version }}"

  echo "+ Pushing rocks to MicroK8s registry"
  just push-to-microk8s chaos-operator {{ version }}
  just push-to-microk8s chaos-exporter {{ version }}

  echo "+ Preparing test namespace: $NAMESPACE"
  kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=true
  kubectl create namespace "$NAMESPACE"

  echo "+ Applying Litmus CRDs from upstream tag $CRD_TAG"
  kubectl apply -f "https://raw.githubusercontent.com/litmuschaos/chaos-operator/${CRD_TAG}/deploy/crds/chaosengine_crd.yaml"
  kubectl apply -f "https://raw.githubusercontent.com/litmuschaos/chaos-operator/${CRD_TAG}/deploy/crds/chaosexperiment_crd.yaml"
  kubectl apply -f "https://raw.githubusercontent.com/litmuschaos/chaos-operator/${CRD_TAG}/deploy/crds/chaosresults_crd.yaml"

  echo "+ Applying test manifests"
  for manifest in tests/litmus_integration/*.yaml; do
    [ "$(basename "$manifest")" = "goss.yaml" ] && continue
    sed "s/TO_BE_REPLACED/$NAMESPACE/g" "$manifest" | kubectl apply -n "$NAMESPACE" -f -
  done

  echo "+ Waiting for pods to settle"
  kubectl wait --for=condition=Available deployment/chaos-operator -n "$NAMESPACE" --timeout=120s || true
  kubectl wait --for=condition=Available deployment/chaos-exporter -n "$NAMESPACE" --timeout=120s || true
  sleep 10

  echo "+ Running goss integration tests"
  NAMESPACE="$NAMESPACE" goss \
    --gossfile "tests/litmus_integration/goss.yaml" \
    validate \
    --retry-timeout=120s \
    --sleep=5s

  echo "+ Cleaning up"
  kubectl delete all --all -n "$NAMESPACE"
  kubectl delete clusterrole litmus --ignore-not-found
  kubectl delete clusterrolebinding litmus --ignore-not-found
  kubectl delete namespace "$NAMESPACE"
