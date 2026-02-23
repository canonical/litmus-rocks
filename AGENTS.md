# Agent Operational Guidelines

This document provides guidance for LLM agents operating on the litmus-rocks repository.

## Repository Overview

This is a monorepo containing rockcraft definitions for Litmus Chaos components. Each component is packaged as an OCI image (rock) using Canonical's rockcraft tool.

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
├── AGENTS.md           # This file
├── README.md
├── justfile            # Command automation
├── goss.yaml           # Shared test configuration (optional)
└── LICENSE
```

## Operational Rules

### 1. ADR-First Architecture

**CRITICAL**: All architectural decisions or structural changes MUST be documented in an Architecture Decision Record (ADR) BEFORE implementation.

#### What Requires an ADR?

- Adding a new rock to the monorepo
- Changing the monorepo structure
- Establishing new testing patterns or requirements
- Modifying build processes or CI/CD pipelines
- Introducing new dependencies or base images
- Changing versioning or release strategies

#### ADR Process

1. **Create ADR**: Add a new file in `docs/adr/` following the naming pattern `NNNN-descriptive-title.md`
   - Use sequential numbering (0001, 0002, etc.)
   - Use lowercase with hyphens for the title

2. **ADR Template**:
   ```markdown
   # ADR-NNNN: [Title]

   **Status:** [Proposed|Accepted|Deprecated|Superseded]

   **Date:** YYYY-MM-DD

   ## Context
   [What is the issue we're addressing?]

   ## Decision
   [What is the change we're making?]

   ## Consequences
   ### Positive
   [What benefits does this bring?]

   ### Negative
   [What drawbacks or risks exist?]

   ## Implementation Notes
   [Specific details for implementation]
   ```

3. **Commit ADR**: Commit the ADR before implementing the change
4. **Reference ADR**: Reference the ADR number in commits implementing the decision

### 2. Rock Development

#### Creating a New Rock

1. **Write ADR**: Document why the component needs a rock and any architectural decisions
2. **Create Directory**: `mkdir <component-name>` at the repository root
3. **Create rockcraft.yaml**: Define the rock specification in `<component-name>/rockcraft.yaml`
4. **Create Tests**: Add `<component-name>/tests/` with rockcraft tests

#### Testing Requirements

- All rocks MUST be testable using `rockcraft test`
- All rockcraft commands MUST be triggered using `just` (not called directly)
- Tests should verify:
  - Rock builds successfully
  - Expected binaries/files are present
  - Component starts and runs correctly
  - Health checks pass (if applicable)

#### Building and Testing

```bash
# Build a specific version of a rock
just pack <component-name> <version>

# Run tests for a specific version
just test <component-name> <version>

# Clean build artifacts
just clean <component-name> <version>

# Run a rock interactively (requires kgoss)
just run <component-name> <version>
```

**Note:** Direct `rockcraft` commands should not be used. Always use `just` recipes for consistency.

### 3. Directory Naming Conventions

#### Component Directories (Top-Level)
- Use the Litmus Chaos component name
- Use lowercase with hyphens (e.g., `chaos-operator`, `chaos-runner`, `chaos-exporter`, `event-tracker`)
- Keep names concise and descriptive

#### Version Subdirectories
- Use semantic version numbers (e.g., `3.26.0`, `3.27.0`)
- Each version directory contains only the `rockcraft.yaml` file
- No additional nesting within version directories

#### Reserved Top-Level Items
The following items are reserved for infrastructure and should NOT be used for component names:
- `docs/` - Documentation and ADRs
- `.github/` - GitHub workflows and actions
- `justfile` - Command automation
- `goss.yaml` - Shared test configuration
- `scripts/` - Shared build/CI scripts (if needed)

### 4. Git Commit Guidelines

- Reference ADR numbers in commits: `feat: implement chaos-operator rock (ADR-0002)`
- Use conventional commits format
- Keep commits focused and atomic
- Include co-authored-by trailer for Copilot contributions

### 5. Documentation Standards

- Keep README.md updated with the list of available rocks
- Document component-specific details in each rock's directory (add a README.md in the rock directory if needed)
- Use ADRs for decisions, not implementation details

### 6. Dependencies and Base Images

- Prefer official Ubuntu base images
- Document base image choices in ADRs
- Keep dependencies minimal and justified
- Pin versions for reproducibility

## Common Tasks

### Adding a New Litmus Chaos Component

1. Create ADR documenting the component and its requirements (e.g., `docs/adr/0002-add-chaos-operator.md`)
2. Create component directory: `mkdir -p <component-name>/<version>/`
3. Write `<component-name>/<version>/rockcraft.yaml` with appropriate specifications
4. Update main README.md with the new component
5. Verify build and tests pass:
   ```bash
   just pack <component-name> <version>
   just test <component-name> <version>
   ```

### Adding a New Version of an Existing Component

1. Create version directory: `mkdir -p <component-name>/<new-version>/`
2. Copy and modify rockcraft.yaml from previous version (if applicable)
3. Update `<component-name>/<new-version>/rockcraft.yaml` with new version details
4. Update main README.md with the new version
5. Verify build and tests pass:
   ```bash
   just pack <component-name> <new-version>
   just test <component-name> <new-version>
   ```

### Modifying Existing Rock

1. If the change is architectural (base image, major dependency), create an ADR
2. Update `rockcraft.yaml` and/or tests
3. Run `rockcraft test` to verify changes
4. Commit with reference to ADR if applicable

### Reviewing Changes

- Check that ADR exists for architectural changes
- Verify all rocks have tests
- Ensure `rockcraft test` passes
- Confirm documentation is updated

## Tools and Commands

### Just Recipes
All rockcraft operations are performed via `just`:
- `just pack <component> <version>` - Build a specific version of a rock
- `just test <component> <version>` - Test a specific version of a rock
- `just clean <component> <version>` - Clean build artifacts for a version
- `just run <component> <version>` - Run a rock interactively with kgoss
- `just` - List all available recipes

### Rockcraft (via Just only)
Do not call these directly - use `just` recipes instead:
- `rockcraft pack` - Build the rock
- `rockcraft test` - Run tests
- `rockcraft clean` - Clean build artifacts

### Repository Navigation
- ADRs: `docs/adr/`
- Components: Top-level directories (excluding `docs/`, `.github/`, `justfile`, etc.)
- Versions: Subdirectories within component directories
- List all components: `ls -d */ | grep -v "docs/" | grep -v ".github/"`
- List versions: `ls -d <component-name>/*/`

## Best Practices

1. **One Component Per Directory**: Each top-level directory (except reserved ones) represents one Litmus Chaos component
2. **One Version Per Subdirectory**: Each version has its own subdirectory with a single `rockcraft.yaml`
3. **Use Just**: Always use `just` recipes instead of direct `rockcraft` commands
4. **Descriptive Names**: Use clear, component-aligned directory names
5. **Self-Documenting**: Each rock should have sufficient inline documentation in rockcraft.yaml
6. **Test Coverage**: Aim for comprehensive testing of each rock
7. **Consistency**: Follow established patterns from existing rocks (see litmuschaos-server-rock, litmuschaos-frontend-rock)
8. **Version Control**: Track all changes, no manual modifications
9. **Clean Repository Root**: Keep the top level organized and avoid clutter

## Questions and Clarifications

If uncertain about:
- Whether a change needs an ADR → If in doubt, create one
- Which base image to use → Check existing rocks or ask for clarification
- Testing approach → Review existing tests as examples
- Directory naming → Follow the naming conventions above

## References

- [Rockcraft Documentation](https://canonical-rockcraft.readthedocs-hosted.com/)
- [Litmus Chaos Documentation](https://litmuschaos.io/)
- [ADR-0001: Monorepo Structure](docs/adr/0001-monorepo-structure.md)
