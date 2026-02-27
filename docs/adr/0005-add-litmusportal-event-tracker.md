# ADR-0005: Add litmusportal-event-tracker Rock

**Status:** Accepted

**Date:** 2026-02-27

## Context

The event-tracker is a Kubernetes controller-runtime manager that watches for
deployment, daemonset, and statefulset changes in the cluster and reports them
back to the Litmus ChaosCenter control plane. It is part of the execution-plane
agent installed by ChaosCenter on each target Kubernetes cluster.

The upstream source lives in the `litmuschaos/litmus` monorepo under
`chaoscenter/event-tracker/`. It is a standalone Go module with its own
`go.mod`.

We need to package this component as a rock to provide a hardened, Ubuntu-based
OCI image.

## Decision

We will create a rock for litmusportal-event-tracker version 3.26.0 with the
following characteristics:

- **Base image**: ubuntu@24.04 (consistent with other rocks in this repository)
- **Build**: Use the rockcraft `go` plugin with `source-subdir` to compile from
  the litmus monorepo
- **Go version**: go/1.25/candidate build snap (compatible with the project's
  go 1.24 module requirement)
- **Binary**: `event-tracker` built from the module root (`.`)
- **Service**: Defined but disabled by default; requires a running Kubernetes
  cluster with ChaosCenter backend
- **Security**: Include ca-certificates for TLS and a dpkg security manifest

## Consequences

### Positive
- Consistent packaging with other Litmus Chaos rocks in this monorepo
- Hardened image with security manifest for vulnerability tracking
- Uses source-subdir to build from the upstream monorepo cleanly

### Negative
- Requires ongoing maintenance to track upstream releases
- Builds from a large monorepo (source-depth mitigates clone time)

## Implementation Notes

- Source: `https://github.com/litmuschaos/litmus`
- Source tag: `3.26.0`
- Source subdir: `chaoscenter/event-tracker`
- Build command: `CGO_ENABLED=0 go build -buildvcs=false -o event-tracker -v .`
- The binary should be staged to `bin/event-tracker`
- Port 8080 is used for metrics, port 8081 for health probes
- The upstream Dockerfile runs as UID 65534 (nobody); rockcraft handles
  non-root by default
