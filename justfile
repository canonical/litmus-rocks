[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Push an OCI image to a local registry
[private]
push-to-registry component version:
  echo "Pushing {{component}} {{version}} to local registry"
  cd "{{component}}/{{version}}" && sudo rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false "oci-archive:{{component}}_{{version}}_amd64.rock" docker-daemon:rockcraft-test:latest

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
