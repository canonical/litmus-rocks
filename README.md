# Litmus Chaos Rocks

This repository contains rockcraft definitions for packaging Litmus Chaos components as OCI images (rocks).

## Overview

Litmus Chaos is a cloud-native chaos engineering platform. This monorepo provides rock definitions for all Litmus Chaos components, enabling deployment on Kubernetes using Canonical's rockcraft tooling.

## Repository Structure

```
litmus-rocks/
├── docs/adr/                     # Architecture Decision Records
├── chaos-operator/               # Each component is a top-level directory
│   ├── goss.yaml                 # Component-level isolation test assertions
│   ├── 3.26.0/                   # Each version has its own subdirectory
│   │   └── rockcraft.yaml
│   └── 3.27.0/
│       └── rockcraft.yaml
├── chaos-exporter/
│   ├── goss.yaml                 # Component-level isolation test assertions
│   └── 3.26.0/
│       └── rockcraft.yaml
├── tests/
│   └── litmus_integration/       # Cross-component Kubernetes integration tests
│       ├── spread.yaml           # Spread project config (ci LXD backend)
│       └── spread/k8s/integration/
│           ├── task.yaml         # Spread task: deploy and validate
│           ├── rbac.yaml         # Kubernetes RBAC manifests
│           ├── chaos-operator.yaml
│           └── chaos-exporter.yaml
├── AGENTS.md                     # LLM agent operational guidelines
├── README.md
├── justfile                      # Command automation
└── LICENSE
```

## Available Rocks

| Component | Version | Description |
|-----------|---------|-------------|
| chaos-exporter | 3.26.0 | Prometheus exporter for Litmus Chaos experiments |
| chaos-operator | 3.26.0 | Kubernetes operator for Litmus Chaos experiment orchestration |
| litmusportal-event-tracker | 3.26.0 | Kubernetes controller that tracks deployment events for Litmus ChaosCenter |
| litmusportal-subscriber | 3.26.0 | Execution-plane agent that connects to Litmus ChaosCenter via WebSocket |

## Getting Started

### Prerequisites

- [Rockcraft](https://canonical-rockcraft.readthedocs-hosted.com/) installed (`sudo snap install rockcraft --classic`)
- [Just](https://github.com/casey/just) installed
- LXD configured for building rocks

For Kubernetes integration tests only:
- LXD installed and initialised, with the MicroK8s-in-LXD profile applied to the default profile:
  ```bash
  lxc profile set default security.nesting true
  lxc profile set default security.privileged true
  lxc profile set default linux.kernel_modules \
    ip_vs,ip_vs_rr,ip_vs_wrr,ip_vs_sh,ip_tables,ip6_tables,netlink_diag,nf_nat,overlay,br_netfilter
  lxc profile set default raw.lxc \
    $'lxc.apparmor.profile=unconfined\nlxc.cap.drop=\nlxc.cgroup.devices.allow=a\nlxc.mount.auto=proc:rw sys:rw cgroup:rw'
  lxc profile device add default kmsg unix-char source=/dev/kmsg path=/dev/kmsg
  ```
- `spread` installed via Go (`go install github.com/snapcore/spread/cmd/spread@latest`)

### Using Just

This repository uses `just` to manage all rockcraft operations:

```bash
# List available commands
just

# Build a specific version
just pack chaos-operator 3.26.0

# Test a specific version
just test chaos-operator 3.26.0

# Clean build artifacts
just clean chaos-operator 3.26.0

# Run interactively with kgoss
just run chaos-operator 3.26.0
```

### Testing Model

There are two levels of testing:

**Isolation tests** (per rock, via `rockcraft test`):
- `just test <component> <version>` runs the spread test for a single rock using `rockcraft test`
- `goss.yaml` at the component root defines assertions; version-specific overrides can set `GOSS_FILE`
- No Kubernetes cluster needed

**Kubernetes integration tests** (cross-component, via `spread`):
- `just test-integration <version>` deploys both rocks into MicroK8s and validates them together
- Requires LXD with the MicroK8s-in-LXD profile applied (see Prerequisites) and `spread` installed via Go
- The suite prepare pushes rock images to the MicroK8s registry, installs upstream CRDs, and creates
  a test namespace; the task applies RBAC and workload manifests and waits for deployments to become
  available; teardown deletes all resources created
- See [ADR-0007](docs/adr/0007-kubernetes-integration-tests.md) for the full design rationale

#### Running integration tests locally

```bash
# Build both rocks first
just pack chaos-operator 3.26.0
just pack chaos-exporter 3.26.0

# Run the Kubernetes integration test suite
just test-integration 3.26.0
```

#### Running integration tests in CI

The `test-integration` recipe uses spread's `lxd` backend, which spins up a fresh
Ubuntu 24.04 LXD container per run, installs MicroK8s inside it, runs the full test
suite, and destroys the container on completion. The CI runner must have LXD installed
and the default profile configured as described in Prerequisites above.

A typical CI step looks like:

```yaml
- name: Install spread
  run: go install github.com/snapcore/spread/cmd/spread@latest

- name: Run integration tests
  run: just test-integration 3.26.0
```

## Adding a New Component

1. Review [AGENTS.md](AGENTS.md) for operational guidelines
2. Create an ADR in `docs/adr/` documenting the new component
3. Create directory structure: `mkdir -p <component-name>/<version>/`
4. Add `<component-name>/<version>/rockcraft.yaml`
5. Update this README with the new component
6. Test: `just pack <component-name> <version>` and `just test <component-name> <version>`

## Architecture Decisions

All architectural decisions are documented as ADRs in the `docs/adr/` directory. See [ADR-0001](docs/adr/0001-monorepo-structure.md) for the monorepo structure decision.

## Contributing

- All architectural changes require an ADR
- All rocks must include tests using `rockcraft test`
- Follow the guidelines in [AGENTS.md](AGENTS.md)

## License

Apache License 2.0 - See [LICENSE](LICENSE) file for details
