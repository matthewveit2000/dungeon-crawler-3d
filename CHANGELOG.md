# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).  
For detailed domain-specific logs (design, art, architecture, testing), see [`docs/changelogs/README.md`](docs/changelogs/README.md).

---

## [Unreleased]

### Added
- **2026-11-18 — Repository & Multi-AI Foundation Initialized:**
  - Created public repository `matthewveit2000/dungeon-crawler-3d`.
  - Added universal AI-tool instruction files: [`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md), [`.cursorrules`](.cursorrules), and [`.github/copilot-instructions.md`](.github/copilot-instructions.md).
  - Created [`docs/VISION_AND_CONSTRAINTS.md`](docs/VISION_AND_CONSTRAINTS.md) logging the Skyrim gameplay north star, floor collapse loop (5 in-game days @ ~30 min/day, reset to floor start), no staircase previews, open-source/custom-art constraints, and automated-testing mandate.
  - Created [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) recording initial locked-in decisions `D-001` through `D-009`.
  - Created [`docs/ALIGNMENT_LOG.md`](docs/ALIGNMENT_LOG.md) and [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md) to track pre-production alignment rounds.
  - Created [`docs/changelogs/README.md`](docs/changelogs/README.md) establishing changelog standards across all project domains.
- **2026-11-18 — Round 1 Alignment Complete (Roles & Division of Labor):**
  - Finalized [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md) and updated [`AGENTS.md`](AGENTS.md) with clear User vs. AI authority boundaries, PR-per-milestone workflow, batched playtest/art review cadence, and push-back authority (`D-010`, `D-011`).
  - Updated [`docs/ALIGNMENT_LOG.md`](docs/ALIGNMENT_LOG.md) and [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md).
- **2026-11-18 — Round 2 Alignment Complete (Skyrim Feel & Core Gameplay Loop):**
  - Locked camera perspective (1st-person primary + 3rd-person toggle), Skyrim-style left/right-hand melee/magic/archery combat, floor-entry snapshot reset on collapse, massive Nordic-ruin labyrinth floor structure, top compass bar + interactive looting + menu time-pause, and save-and-quit anytime (`D-012`–`D-017`).
- **2026-11-18 — Round 3 Alignment Complete (World, Progression & DCC Flavor):**
  - Locked unified combat-death floor-entry reset, hybrid XP + Skyrim use-to-improve progression, Skyrim slots + Sponsored/Mythic affixes, discoverable Safe Rooms/Towns, hidden staircase + optional sealed Boss Arenas/Vaults, and full "Dark Baseline, Goofy Payload" DCC tone (`D-018`–`D-023`).
- **2026-11-18 — Round 4 Alignment Complete & Master Blueprint Authored:**
  - Locked Godot 4 desktop-first engine (optional web later), Clean Stylized Dark Fantasy Blender art style, procedural open-source SFX + Dungeon AI banners, and `v0.1` single-floor vertical slice scope (`D-024`–`D-027`).
  - Authored [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md), [`docs/TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md), and [`docs/ROADMAP.md`](docs/ROADMAP.md) for final User sign-off prior to implementation.
- **2026-11-18 — Pre-Production Alignment Signed Off (Round 5 Complete):**
  - User approved exiting Pre-Production and advancing through `v0.1` Vertical Slice development on feature branches.
