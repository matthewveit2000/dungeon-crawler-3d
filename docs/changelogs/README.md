# Changelogs Directory

Every meaningful change in `dungeon-crawler-3d` is tracked so any human or AI tool can trace the full history of the project.

## Structure

- **Root [`CHANGELOG.md`](../../CHANGELOG.md):** High-level chronological log of every notable change across the entire repository.
- **Domain Changelogs (created as each domain becomes active):**
  - `docs/changelogs/DESIGN.md` — Gameplay rules, balance tuning, progression, and floor mechanics changes.
  - `docs/changelogs/ARCHITECTURE.md` — Engine setup, libraries, data schemas, and major refactors.
  - `docs/changelogs/ART.md` — Blender models, materials, rigs, animations, lighting, and UI art changes.
  - `docs/changelogs/TESTING.md` — Automated test suites, CI pipelines, and verification tooling changes.

## Rules for All AI Tools

1. Every PR or significant commit MUST update the root `CHANGELOG.md` under `[Unreleased]`.
2. When a change touches design, architecture, art, or testing, also log the detailed entry in the corresponding domain changelog once that domain is active.
3. Entries must state **what changed**, **why**, and link to any relevant decision ID (`D-XXX`) in [`docs/DECISION_LOG.md`](../DECISION_LOG.md).
