# ADR-0006: Add litmusportal-subscriber Rock

**Status:** Accepted

**Date:** 2026-02-27

## Context

The subscriber is an execution-plane agent that connects to the Litmus
ChaosCenter control plane via WebSocket. It watches for workflow events and
chaos experiment status changes in the target cluster and reports them back
to the ChaosCenter server. It also receives action requests from the server
(e.g., apply manifests, delete resources).

The upstream source lives in the `litmuschaos/litmus` monorepo under
`chaoscenter/subscriber/`. It is a standalone Go module with its own `go.mod`.

We need to package this component as a rock to provide a hardened, Ubuntu-based
OCI image.

## Decision

We will create a rock for litmusportal-subscriber version 3.26.0 with the
following characteristics:

- **Base image**: ubuntu@24.04 (consistent with other rocks in this repository)
- **Build**: Use the rockcraft `go` plugin with `source-subdir` to compile from
  the litmus monorepo
- **Go version**: go/1.25/candidate build snap (compatible with the project's
  go 1.24 module requirement)
- **Binary**: `subscriber` built from the module root (`.`)
- **Service**: Defined but disabled by default; requires ChaosCenter backend
  connectivity and a running Kubernetes cluster
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
- Source subdir: `chaoscenter/subscriber`
- Build command: `CGO_ENABLED=0 go build -buildvcs=false -o subscriber -v .`
- The binary should be staged to `bin/subscriber`
- No ports are exposed (outbound WebSocket connection to ChaosCenter)
- The upstream Dockerfile runs as UID 65534 (nobody); rockcraft handles
  non-root by default
