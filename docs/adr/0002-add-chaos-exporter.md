# ADR-0002: Add chaos-exporter Rock

**Status:** Accepted

**Date:** 2026-02-25

## Context

The chaos-exporter is a Prometheus exporter for Litmus Chaos experiments. It exposes chaos experiment metrics on port 8080 for Prometheus scraping, enabling monitoring of chaos experiment results and status.

The upstream project lives at https://github.com/litmuschaos/chaos-exporter and is a standalone Go binary that runs as part of the Litmus Chaos execution plane alongside the chaos-operator.

We need to package this component as a rock to provide a hardened, Ubuntu-based OCI image.

## Decision

We will create a rock for chaos-exporter version 3.26.0 (the latest release) with the following characteristics:

- **Base image**: ubuntu@24.04 (consistent with other rocks in this repository)
- **Build**: Use the rockcraft `go` plugin to compile the Go binary from source at the pinned tag
- **Go version**: go/1.25/candidate build snap (compatible with the project's go 1.20 module requirement)
- **Binary**: `chaos-exporter` built from `./cmd/exporter/`
- **Service startup**: Disabled by default, as the exporter requires a running Kubernetes cluster with Litmus CRDs to function
- **Security**: Include ca-certificates for TLS and a dpkg security manifest

## Consequences

### Positive
- Consistent packaging with other Litmus Chaos rocks in this monorepo
- Hardened image with security manifest for vulnerability tracking
- Follows established patterns from litmuschaos-server-rock

### Negative
- Requires ongoing maintenance to track upstream releases
- Go 1.20 is an older Go version; the build snap (1.22) is newer but backward-compatible

## Implementation Notes

- Source: `https://github.com/litmuschaos/chaos-exporter`
- Source tag: `3.26.0`
- Build subdir: not needed (standalone repository)
- Build command: `CGO_ENABLED=0 go build -buildvcs=false -o chaos-exporter -v ./cmd/exporter/`
- The binary should be staged to `bin/chaos-exporter`
- Port 8080 is used for the `/metrics` endpoint
- The upstream Dockerfile runs as UID 65534 (nobody); rockcraft handles non-root by default
