set shell := ["bash", "-uc"]

rock_name := `echo ${PWD##*/}`  # Get the rock name from the folder name
latest_version := `find . -name rockcraft.yaml -printf '%h\n' | sort -V | tail -n1 | sed 's@./@@'`

[private]
@default:
  just --list
  echo ""
  echo "For help with a specific recipe, run: just --usage <recipe>"

# Push an OCI image to a local registry
[private]
@push-to-registry version=latest_version:
  which docker || echo "docker not found"; exit 1
  test -f "{{version}}/{{rock_name}}_{{version}}_amd64.rock" || rockcraft pack
  echo "Pushing {{version}} to local docker registry"
  cd {{version}}; sudo rockcraft.skopeo --insecure-policy copy "oci-archive:{{rock_name}}_{{version}}_amd64.rock" docker-daemon:rockcraft-test:latest

# Pack a rock of a specific component and version
[group("dev")]
pack version=latest_version:
  cd "{{version}}" && rockcraft pack

# `rockcraft clean` for a specific component and version
[group("dev")]
clean version=latest_version:
  cd "{{version}}" && rockcraft clean

# Run a rock and open a shell into it with `docker`
[group("dev")]
run version=latest_version: (push-to-registry version)
  docker run --rm --name {{rock_name}} rockcraft-test:latest

# Test a rock with `rockcraft test`
[group("dev")]
test version=latest_version: (push-to-registry version)
  cp spread.yaml "{{version}}/spread.yaml"
  cp goss.yaml "{{version}}/goss.yaml"
  cd "{{version}}"; rockcraft test || echo "rockcraft test failed"; rm -f "{{version}}/spread.yaml"; rm -f "{{version}}/goss.yaml"; exit 1

# Generate a rock for the latest version of the upstream project
[arg("source_repo", help="Repository of the upstream project in 'org/repo' form")]
[group("maintenance")]
update source_repo:
  #!/usr/bin/env bash
  set -e
  latest_release="$(gh release list --repo {{source_repo}} --exclude-pre-releases --limit=1 --json tagName --jq '.[0].tagName')"
  echo "Latest release for {{source_repo}} is $latest_release"
  # Explicitly filter out prefixes for known rocks, so we can notice if a new rock has a different schema
  version="${latest_release}"
  version="${version#mimir-}"  # mimir
  version="${version#cmd/builder/v}"  # opentelemetry-collector
  version="${version#v}"  # Generic v- prefix
  # If the version already exists as a rock, exit here
  if [[ -d "$version" ]]; then echo "Folder $version already exists, nothing to do" && exit 0; fi
  # Create the folder for the new version and update the rockcraft.yaml
  cp -r "{{latest_version}}" "$version"
  latest_release="$latest_release" version="$version" yq -i \
    '.version = strenv(version) | .parts.{{rock_name}}["source-tag"] = strenv(latest_release)' \
    "./$version/rockcraft.yaml"
  # Automatically update build tools (go) from the upstream repository
  TMP_DIR="/tmp/rock-update"
  rm -rf "$TMP_DIR"; mkdir -p "$TMP_DIR"
  gh repo clone "{{source_repo}}" "$TMP_DIR/{{source_repo}}" -- --branch "$latest_release" --depth 1
  # If it's a Go project, update the Go version
  if [[ -f "$TMP_DIR/{{source_repo}}/go.mod" ]]; then
    go_snap_version="$(grep -Po '^go \K(\S+)' "$TMP_DIR/{{source_repo}}/go.mod" | sed -E 's/([0-9]+\.[0-9]+).*/\1/')"
    go_snap_version="$go_snap_version" yq -i \
      '.parts.{{rock_name}}.build-snaps += "go/"+strenv(go_snap_version)+"/stable"' \
      "./$version/rockcraft.yaml"
  fi
  rm -rf "$TMP_DIR"
  echo "Created rock for version $version"

# Fetch 'rock.just' from the canonical/observability repository
[group("maintenance")]
@refresh:
    echo "Fetching latest 'rock.just' from canonical/observability ..."
    gh api repos/canonical/observability/contents/rock.just --jq '.content' | base64 --decode > rock.just
    echo "✓ rock.just updated"

# Release rock to GHCR with tag `:dev`
[group("release")]
release-ghcr version=latest_version github_user="observability-noctua-bot":
  #!/usr/bin/env bash
  set -e
  if [[ -z "$GITHUB_TOKEN" ]]; then echo "Please export GITHUB_TOKEN for the user {{github_user}}"; exit 1; fi
  just pack "{{version}}"
  sudo rockcraft.skopeo --insecure-policy copy \
    "oci-archive:$(realpath ./{{version}}/*.rock)" \
    "docker://ghcr.io/canonical/{{rock_name}}:dev"
    --dest-creds "{{github_user}}:${GITHUB_TOKEN}"
  echo "{{rock_name}} {{version}} pushed to GHCR with tag ':dev'"

# Open a PR to OCI Factory
[group("release")]
[arg("support",pattern="major|minor|patch")]
[arg("risk", pattern="stable|candidate|beta|edge")]
release-oci-factory version=latest_version support="minor" risk="stable":
  #!/usr/bin/env bash
  set -e
  if [[ -z "$GITHUB_TOKEN" ]]; then echo "Please export GITHUB_TOKEN for the user observability-noctua-bot"; exit 1; fi
  just pack "{{version}}"
  # Build the OCI Factory manifest
  repository="$(git remote get-url origin | sed -E 's#(git@[^:]+:|https?://[^/]+/)##; s/\.git$//')"
  # Clone the oci-factory and push data to it
  gh repo sync --force observability-noctua-bot/oci-factory
  echo "Synced the observability-noctua-bot/oci-factory fork"
  TMP_DIR="/tmp/rock-release-oci-factory"
  rm -rf "$TMP_DIR"; mkdir -p "$TMP_DIR"
  gh repo clone observability-noctua-bot/oci-factory "$TMP_DIR/oci-factory"
  echo "Cloned observability-noctua-bot/oci-factory"
  pushd "$TMP_DIR/oci-factory"
  git config user.name observability-noctua-bot
  git config user.email webops+observability-noctua-bot@canonical.com
  uvx --from=git+https://github.com/lucabello/noctua noctua rock manifest \
    "$repository" \
    --commit="$(git rev-parse HEAD)" \
    --base=24.04 \
    --support="{{support}}" \
    --risk="{{risk}}" \
    --version="{{version}}" \
    > oci/{{rock_name}}/image.yaml
  echo "OCI Factory manifest generated"
  branch_name="update-$(date -d now +%s)"
  git checkout -b "$branch_name"
  git add oci/{{rock_name}}/image.yaml
  git commit -m "chore: Add new {{rock_name}} releases"
  git push -u origin "$branch_name" --force
  echo "Changes have been pushed to ${branch_name}"
  # gh pr create --repo canonical/oci-factory \
  #   --head "observability-noctua-bot:${branch_name}" \
  #   --title "chore: Add new {{rock_name}} releases" \
  #   --body "This is an automatic PR opened by the Observability Noctua bot."
  popd
  rm -rf "$TMP_DIR"
  echo "PR to OCI Factory opened successfully"

