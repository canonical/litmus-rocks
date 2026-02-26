# ADR-0003: Shared spread.yaml with component-level goss.yaml Testing Pattern

**Status:** Accepted

**Date:** 2026-02-25

## Context

Rock integration tests in this repository should be consistent across components and versions, while still allowing version-specific test behavior when needed.

Until now, spread configuration existed in both the repository root and component version directories, which introduces duplication and drift risk.

## Decision

We standardize on the following testing pattern:

- Keep a single shared `spread.yaml` at the repository root.
- Keep a `goss.yaml` at each component root (for example, `chaos-exporter/goss.yaml`) for component-level integration assertions.
- During `just test <component> <version>`, copy the root `spread.yaml` and the component `goss.yaml` into the target version directory, then run `rockcraft test` from that directory.
- Integration test tasks reference the copied version-local `goss.yaml` by default.
- If a version requires custom goss assertions, define an alternative `GOSS_FILE` in that version's `spread/.../task.yaml`.
- Ignore copied per-version `spread.yaml` files in Git.

## Consequences

### Positive
- Reduces duplicated spread configuration across versions.
- Keeps integration checks centralized per component and reusable across versions.
- Preserves flexibility for version-specific goss assertions.

### Negative
- Test execution now depends on the copy step in `just test`.
- Relative path to copied version-local `goss.yaml` must remain correct in each task.

## Implementation Notes

- `justfile` handles copying `spread.yaml` and `{{component}}/goss.yaml` into `{{component}}/{{version}}/` before `rockcraft test`.
- `.gitignore` ignores `**/spread.yaml` while preserving the repository root `spread.yaml`.
- Version-specific overrides are done in `spread/.../task.yaml` by setting `GOSS_FILE` to a local path.