# ADR-0005: Kubernetes Integration Tests for Litmus Rocks

**Status:** Accepted

**Date:** 2026-02-27

## Context

The existing goss tests (ADR-0003) verify each rock in isolation — confirming that
expected binaries are present inside the container image. This is necessary but not
sufficient: it does not verify that the chaos-operator and chaos-exporter rocks can
run together in a Kubernetes environment with the Litmus CRDs installed.

The [opentelemetry-collector-rock](https://github.com/canonical/opentelemetry-collector-rock)
repository demonstrates a pattern for integration testing rocks against real Kubernetes
workloads without requiring Juju or charms. The approach deploys Kubernetes manifests
into a MicroK8s cluster, then validates cross-component behavior using goss with
`kubectl` commands.

## Decision

Add a Kubernetes integration test suite under `tests/litmus_integration/` that:

1. Pushes both rock images to the MicroK8s local registry (`localhost:32000`).
2. Applies upstream Litmus CRDs (pinned to the version under test).
3. Deploys the chaos-operator and chaos-exporter as Kubernetes Deployments using the
   rock images.
4. Validates the deployment with goss assertions run from the host.

The `justfile` gains a `test-integration` recipe that automates the full lifecycle:
create namespace → apply CRDs and manifests → wait → run goss → cleanup.

CRDs are fetched from the upstream `litmuschaos/chaos-operator` repository at a
pinned tag rather than vendored, keeping the repository lightweight.

## Consequences

### Positive
- Catches integration failures (missing env vars, RBAC issues, CRD incompatibilities)
  that isolation tests miss.
- Avoids the overhead of Juju/charm deployment for rock-level validation.
- Follows an established pattern used by other Canonical rock repositories.
- Tests both rocks cooperating in a single Kubernetes namespace.

### Negative
- Requires a running MicroK8s cluster with the `registry` addon enabled.
- CRD fetch from upstream adds a network dependency during test setup.
- Integration tests are slower than isolation tests.

## Implementation Notes

- Test manifests live in `tests/litmus_integration/`.
- The goss file for the integration test lives alongside the manifests.
- `just test-integration <version>` is the entry point.
- The chaos-operator image is referenced as `localhost:32000/chaos-operator-dev:latest`.
- The chaos-exporter image is referenced as `localhost:32000/chaos-exporter-dev:latest`.
- RBAC resources (ClusterRole, ClusterRoleBinding) are scoped to the test namespace
  where possible, and cleaned up after the test run.
