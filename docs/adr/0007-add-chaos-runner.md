# ADR-0007: Add chaos-runner Rock

**Status:** Accepted

**Date:** 2026-03-17

## Context

The chaos-runner is the component that executes individual chaos experiments
inside target pods. When the chaos-operator schedules an experiment, it creates
a runner pod using this binary. The runner interacts directly with the Kubernetes
API to inject faults and monitor experiment results.

The upstream project lives at https://github.com/litmuschaos/chaos-runner and
is a standalone Go module built from the `./bin` entry point at the repository
root.

We need to package this component as a rock to provide a hardened, Ubuntu-based
OCI image consistent with other rocks in this monorepo.

## Decision

We will create a rock for chaos-runner version 3.26.0 with the following
characteristics:

- **Base image**: ubuntu@24.04 (consistent with other rocks in this repository)
- **Build**: Use the rockcraft `go` plugin to compile the Go binary from the
  `./bin` entry point, matching the upstream Dockerfile
- **Go version**: go/1.25/candidate build snap (compatible with the project's
  go 1.22 module requirement)
- **Binary**: `chaos-runner` built from `./bin`
- **Service**: Defined but with on-failure: ignore; requires a running Kubernetes
  cluster with Litmus CRDs and a chaos experiment to execute
- **Security**: Include ca-certificates for TLS and a dpkg security manifest

## Consequences

### Positive
- Consistent packaging with other Litmus Chaos rocks in this monorepo
- Hardened image with security manifest for vulnerability tracking
- Follows established patterns from chaos-operator and chaos-exporter rocks

### Negative
- Requires ongoing maintenance to track upstream releases

## Implementation Notes

- Source: `https://github.com/litmuschaos/chaos-runner`
- Source tag: `3.26.0`
- Build command: `CGO_ENABLED=0 go build -buildvcs=false -o chaos-runner -v ./bin`
- The binary should be staged to `bin/chaos-runner`
- The upstream Dockerfile runs as UID 65534 (nobody); rockcraft handles
  non-root by default
- The runner requires a running Kubernetes cluster with Litmus CRDs and is
  invoked by the chaos-operator, not run standalone
