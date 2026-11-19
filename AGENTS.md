# AGENTS.md — Universal AI Agent Handbook

This file is the **single source of truth** for any AI agent or coding assistant (Antigravity, Claude Code, Cursor, GitHub Copilot, OpenAI Codex, Jules, etc.) working on `dungeon-crawler-3d`.

Read this file and the linked documents in `docs/` before taking any action.

---

## 1. Project Identity & North Star

- **What we are building:** A completely free, open-source 3D action-RPG dungeon crawler inspired by *Dungeon Crawler Carl*.
- **Gameplay North Star:** **The game must feel like Skyrim.** Every major gameplay, camera, pacing, exploration, and combat decision is evaluated against this north star.
- **Core Loop Rules (Locked In):**
  - **Floor Collapse Timer:** 5 in-game days per floor (~30 real-time minutes per in-game day for now; data-driven/configurable) to compel exploration.
  - **Collapse Consequence:** Reset to the **beginning of the current floor** (no full-run permadeath).
  - **No Staircase Previews:** Descending to a new floor does not preview what is below.
- **Build Philosophy:**
  - Leverage existing **free, open-source** engines and libraries rather than building engine plumbing from scratch, while preserving maximum flexibility and freedom.
  - **100% original in-house art** created by us using **Blender** and other free, open-source tools. No third-party asset packs.
  - **Automated-Testing First:** Anything that can be tested automatically *must* be tested automatically to minimize manual testing for the user.

See [`docs/VISION_AND_CONSTRAINTS.md`](docs/VISION_AND_CONSTRAINTS.md) and [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) for full details.

---

## 2. Current Phase

- **Phase:** `Active Development — Milestone 1 (v0.1 Vertical Slice)`
- **Pre-Production Alignment:** Completed (`Rounds 0–5`, Decisions `D-001` through `D-027`).
- **Workflow:** Build on feature branches, maintain green automated tests and CI, log every change in `CHANGELOG.md` and domain changelogs, and open PRs for User approval before merging to `main`.

---

## 3. Roles & Division of Labor

> **Status:** `LOCKED (Aligned in Round 1)` — Full rules in [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md).

- **User = Product Owner & Creative Director:** Owns vision, feel, fun, art taste, scope approvals, and milestone PR sign-off.
- **AI = Full Technical Lead, Engineer & Technical Artist:** Owns all architecture, code cleanliness/organization, libraries, automated testing, CI, documentation/changelogs, minor balance tuning (logged), and Blender 3D asset execution.
- **Ask First ONLY For:** (1) Core gameplay feel / Skyrim north star changes, (2) Art style direction & batched 3D preview approvals, (3) Major scope changes, (4) Major irreversible tech/platform choices.
- **Workflow & Communication:** Plain-English, jargon-free updates with proactive push-back authority. Once implementation starts, work on feature branches, open one PR per milestone/phase, keep CI green, and wait for User approval before merging. Only request manual playtesting at meaningful playable milestones and visual review via batched Blender preview renders.

---

## 4. Non-Negotiable Documentation & Changelog Rules

Because this repository must be seamlessly usable by **any AI tool** across sessions:

1. **Log Every Decision:** Any new gameplay, architectural, tooling, or governance decision MUST be added to [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) with a unique ID (`D-XXX`), date, decision, and rationale.
2. **Maintain Changelogs for Everything:** Every meaningful change (documentation, design decisions, code, tests, art assets, tooling) MUST be recorded in [`CHANGELOG.md`](CHANGELOG.md) and, when applicable, the corresponding domain changelog under [`docs/changelogs/`](docs/changelogs/README.md).
3. **Keep Tool Entry Points Synchronized:** Never duplicate detailed rules in `CLAUDE.md`, `.cursorrules`, or `.github/copilot-instructions.md`. Update `AGENTS.md` and `docs/` so every AI tool reads the exact same truth.
4. **Never Leave Stale Docs:** If a change alters architecture, controls, systems, or status, update the affected docs in the same commit/PR.

---

## 5. Testing Mandate

- Every feature, system, data schema, and art-export pipeline step that can be verified automatically MUST have automated tests.
- Automated tests should be fast, deterministic (seeded randomness), and run in CI.
- Never merge or declare work complete when automated checks are failing.

---

## 6. Essential Reading Order for New AI Sessions

1. `AGENTS.md` (this file)
2. `docs/ROLES_AND_GOVERNANCE.md`
3. `docs/VISION_AND_CONSTRAINTS.md`
4. `docs/GAME_DESIGN.md`
5. `docs/ARCHITECTURE.md`
6. `docs/ART_PIPELINE.md`
7. `docs/TESTING_STRATEGY.md`
8. `docs/PLAYTEST_GUIDE.md`
9. `docs/ROADMAP.md`
10. `docs/DECISION_LOG.md`
11. `docs/ALIGNMENT_LOG.md`
12. `CHANGELOG.md` and `docs/changelogs/`
