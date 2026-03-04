# ADR-0007: Kubernetes Integration Tests for Litmus Rocks

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
4. Validates the deployment with `kubectl wait` assertions.

The test is structured as a **spread test** (`tests/litmus_integration/spread.yaml`)
following the same pattern used by individual rock tests. Suite lifecycle (MicroK8s
setup, registry pushes, CRD installation, namespace creation and cleanup) is handled
in the suite `prepare`/`restore` blocks. The test task itself lives at
`tests/litmus_integration/spread/k8s/integration/task.yaml`, with the Kubernetes
manifests co-located in the same directory.

The `justfile` gains a `test-integration` recipe that stages the built `.rock`
artifacts into the spread project directory, then invokes `spread ci:`.

The spread `ci` backend uses **`type: lxd`** to run tests inside a disposable LXD
container. This prevents the test run from modifying the host environment (SSH config,
snap installs, kubeconfig). Each run gets a fresh Ubuntu 24.04 container; LXD destroys
it automatically when the run completes or fails. Running MicroK8s inside an LXD
container requires `security.nesting=true`; this must be set on the LXD default profile
(or a custom profile applied to the container) on the host before invoking spread.

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
- Requires LXD to be installed and initialised on the host, with the MicroK8s-in-LXD
  profile settings applied (`security.nesting`, `security.privileged`, kernel modules,
  and `raw.lxc` AppArmor/cgroup settings) so that MicroK8s can run inside the container.
- CRD fetch from upstream adds a network dependency during test setup.
- Integration tests are slower than isolation tests.
- Each run installs `rockcraft` and `microk8s` snaps from scratch inside a fresh
  container, adding to run time.

## Implementation Notes

- `just test-integration <version>` is the entry point.
- The spread project root is `tests/litmus_integration/`; `spread.yaml` defines a
  `ci` LXD backend that creates and destroys a fresh Ubuntu 24.04 container per run.
- Before running `just test-integration`, the host LXD default profile must have the
  settings required to run MicroK8s inside a container (see
  https://microk8s.io/docs/lxd):
  ```
  lxc profile set default security.nesting true
  lxc profile set default security.privileged true
  lxc profile set default linux.kernel_modules \
    ip_vs,ip_vs_rr,ip_vs_wrr,ip_vs_sh,ip_tables,ip6_tables,netlink_diag,nf_nat,overlay,br_netfilter
  lxc profile set default raw.lxc \
    $'lxc.apparmor.profile=unconfined\nlxc.cap.drop=\nlxc.cgroup.devices.allow=a\nlxc.mount.auto=proc:rw sys:rw cgroup:rw'
  lxc profile device add default kmsg unix-char source=/dev/kmsg path=/dev/kmsg
  ```
- Kubernetes manifests (`rbac.yaml`, `chaos-operator.yaml`, `chaos-exporter.yaml`)
  live at `tests/litmus_integration/spread/k8s/integration/` alongside `task.yaml`.
- Rock artifacts (`.rock` files) are copied into the project directory by the
  `test-integration` justfile recipe before `spread` is invoked, so they are
  available via `$SPREAD_PATH` during suite preparation; they are removed on exit.
- The chaos-operator image is referenced as `localhost:32000/chaos-operator-dev:latest`.
- The chaos-exporter image is referenced as `localhost:32000/chaos-exporter-dev:latest`.
- RBAC resources (ClusterRole, ClusterRoleBinding) are cleaned up in the suite
  `restore` block.
