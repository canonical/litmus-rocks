# ADR-0001: Monorepo Structure for Litmus Chaos Rocks

**Status:** Accepted

**Date:** 2026-02-23

## Context

Litmus Chaos is composed of multiple components that need to be packaged as OCI images using Canonical's rockcraft tool. We need to establish a structure for managing multiple rock definitions in a single repository. Following the pattern from other Canonical rock repositories, we need to support multiple versions of each component.

## Decision

We will organize this repository as a monorepo with each rock as a top-level directory, and each version in a subdirectory:

```
litmus-rocks/
├── docs/
│   └── adr/              # Architecture Decision Records
├── chaos-operator/       # Litmus execution plane components
│   ├── 3.26.0/
│   │   └── rockcraft.yaml
│   └── 3.27.0/
│       └── rockcraft.yaml
├── chaos-exporter/
│   └── 3.26.0/
│       └── rockcraft.yaml
├── AGENTS.md             # LLM agent operational guidelines
├── README.md
├── justfile              # Command automation using just
├── goss.yaml             # Shared test configuration (if needed)
└── LICENSE
```

### Key Principles

1. **Top-Level Components**: Each Litmus Chaos component is a top-level directory in the repository
2. **Version Subdirectories**: Each version of a component has its own subdirectory (e.g., `chaos-operator/3.26.0/`)
3. **Centralized Documentation**: All ADRs and shared documentation live in `docs/`
4. **Self-Contained Versions**: Each version directory contains its `rockcraft.yaml`
5. **Just-Based Workflow**: All rockcraft commands are triggered using `just` for consistency
6. **Testing Standard**: All rocks must be testable using `rockcraft test` (triggered via `just`)
7. **ADR-First**: All architectural decisions must be documented in an ADR before implementation

### Directory Naming

- Use the Litmus Chaos component name as the top-level directory name
- Use lowercase with hyphens for multi-word names (e.g., `chaos-operator`, `event-tracker`)
- Use semantic version numbers for subdirectories (e.g., `3.26.0`, `3.27.0`)
- Keep names concise and descriptive

## Consequences

### Positive
- Single repository simplifies version control and coordination across components
- Shared documentation and standards across all rocks
- Easier to maintain consistency in build and test processes
- Clear audit trail of architectural decisions via ADRs
- Top-level structure makes each component immediately visible
- Version subdirectories allow multiple versions to coexist
- `just` provides consistent, discoverable commands across all rocks
- Follows established pattern from other Canonical rock repositories

### Negative
- Top-level directory can become crowded as more components are added
- Need discipline to maintain separation between components and versions
- CI/CD pipelines need to handle multiple build targets and versions
- Need clear naming to distinguish rock directories from infrastructure directories

## Implementation Notes

- Each version directory contains only the `rockcraft.yaml` file
- Testing is done using `rockcraft test` but triggered via `just` commands
- Common test configurations (e.g., `goss.yaml`) can be shared at the repository root
- `justfile` at repository root provides standard recipes: `pack`, `clean`, `run`, `test`
- Reserve certain top-level names for infrastructure: `docs/`, `.github/`, `justfile`, `goss.yaml`
- Rock naming convention: Use the Litmus Chaos component name as the top-level directory name
- Version naming convention: Use semantic version numbers (e.g., `3.26.0`)
