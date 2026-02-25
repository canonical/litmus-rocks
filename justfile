# set quiet # Recipes are silent by default
set export # Just variables are exported to environment variables

[private]
default:
  just --list

# Push an OCI image to a local registry
[private]
push-to-registry component version:
  echo "Pushing {{component}} {{version}} to local registry"
  rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false \
    "oci-archive:${component}/${version}/${component}_${version}_amd64.rock" \
    "docker://localhost:32000/${component}-dev:${version}"

# Pack a rock of a specific component and version
pack component version:
  cd "{{component}}/{{version}}" && rockcraft pack

# `rockcraft clean` for a specific component and version
clean component version:
  cd "{{component}}/{{version}}" && rockcraft clean

# Run a rock and open a shell into it with `kgoss`
run component version: (push-to-registry component version)
  kgoss edit -i localhost:32000/{{component}}-dev:{{version}}

# Test a rock with `rockcraft test`
test component version:
  cd "{{component}}/{{version}}" && rockcraft test
