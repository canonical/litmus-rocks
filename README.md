# Litmus Chaos Rocks

This repository contains rockcraft definitions for packaging Litmus Chaos components as OCI images (rocks).

## Overview

Litmus Chaos is a cloud-native chaos engineering platform. This monorepo provides rock definitions for all Litmus Chaos components, enabling deployment on Kubernetes using Canonical's rockcraft tooling.

## Repository Structure

```
litmus-rocks/
├── docs/adr/           # Architecture Decision Records
├── chaos-operator/     # Each component is a top-level directory
│   ├── 3.26.0/         # Each version has its own subdirectory
│   │   └── rockcraft.yaml
│   └── 3.27.0/
│       └── rockcraft.yaml
├── chaos-exporter/
│   └── 3.26.0/
│       └── rockcraft.yaml
├── AGENTS.md           # LLM agent operational guidelines
├── README.md
├── justfile            # Command automation
└── LICENSE
```

## Available Rocks

| Component | Version | Description |
|-----------|---------|-------------|
| chaos-exporter | 3.26.0 | Prometheus exporter for Litmus Chaos experiments |

## Getting Started

### Prerequisites

- [Rockcraft](https://canonical-rockcraft.readthedocs-hosted.com/) installed
- [Just](https://github.com/casey/just) installed
- LXD configured for building rocks

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
