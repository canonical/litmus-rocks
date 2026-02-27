# ADR-0004: Add chaos-operator Rock

**Status:** Accepted

**Date:** 2026-02-26

## Context

The chaos-operator is the core Kubernetes operator for Litmus Chaos. It watches for ChaosEngine custom resources and orchestrates the execution of chaos experiments by managing runner pods and reconciling experiment state.

The upstream project lives at https://github.com/litmuschaos/chaos-operator and is a standalone Go binary built from the repository root (`main.go`). It runs as part of the Litmus Chaos control plane alongside the chaos-exporter.

We need to package this component as a rock to provide a hardened, Ubuntu-based OCI image consistent with other rocks in this monorepo.

## Decision

We will create a rock for chaos-operator version 3.26.0 with the following characteristics:

- **Base image**: ubuntu@24.04 (consistent with other rocks in this repository)
- **Build**: Use the rockcraft `go` plugin to compile the Go binary from source at the pinned tag
- **Go version**: go/1.25/candidate build snap (compatible with the project's go 1.22 module requirement)
- **Binary**: `chaos-operator` built from the repository root (entry point: `./main.go`)
- **Service startup**: Enabled, matching the chaos-exporter rock pattern
- **Security**: Include ca-certificates for TLS and a dpkg security manifest

## Consequences

### Positive
- Consistent packaging with other Litmus Chaos rocks in this monorepo
- Hardened image with security manifest for vulnerability tracking
- Follows established patterns from the chaos-exporter rock

### Negative
- Requires ongoing maintenance to track upstream releases

## Implementation Notes

- Source: `https://github.com/litmuschaos/chaos-operator`
- Source tag: `3.26.0`
- Build command: `CGO_ENABLED=0 go build -buildvcs=false -o chaos-operator -v .`
- The binary should be staged to `bin/chaos-operator`
- The upstream Dockerfile runs as UID 65534 (nobody); rockcraft handles non-root by default
- The operator requires `WATCH_NAMESPACE` environment variable and a running Kubernetes cluster with Litmus CRDs
