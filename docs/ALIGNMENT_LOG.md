# Pre-Production Alignment Log

This document records each Q&A alignment round between the Project Owner (User) and the AI before any game code or art is built.

---

## Round 0 — Initial Direction (Completed: 2026-11-18)

**Inputs logged into [`docs/VISION_AND_CONSTRAINTS.md`](VISION_AND_CONSTRAINTS.md) and [`docs/DECISION_LOG.md`](DECISION_LOG.md):**
- New 3D game inspired by *Dungeon Crawler Carl* concepts, built on existing free/open-source engines/libraries.
- 100% free & open source; 100% in-house art using Blender and open-source tools.
- **North Star:** Gameplay must feel like **Skyrim**.
- **Floor Collapse:** 5 in-game days (~30 min per day for now) to push exploration; on collapse, reset to the beginning of the floor (no permadeath).
- **No staircase previews.**
- **Automated testing first:** Anything testable automatically must be tested automatically to cut down on manual user testing.
- **Multi-AI-tool ready:** Robust documentation, `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, Copilot instructions, and changelogs for everything.
- **Process:** Complete Q&A alignment rounds before building anything.

---

## Round 1 — Roles & Division of Labor (Completed: 2026-11-18)

**Agreed Outcomes (logged in [`docs/ROLES_AND_GOVERNANCE.md`](ROLES_AND_GOVERNANCE.md), `D-010`, `D-011`):**
- **Role Split:** User = Product Owner & Creative Director; AI = Full Technical Lead, Engineer & Technical Artist.
- **Full AI Autonomy:** Code structure/cleanliness/efficiency, libraries, data schemas, bug fixes, refactors, automated testing/CI, docs/changelogs, logged minor balance tuning, and first-pass Blender 3D assets.
- **Mandatory User Approval Gates:** Core gameplay feel / Skyrim north star changes; art style direction & key 3D model previews; major scope changes; major irreversible tech/platform choices.
- **Git Workflow:** Feature branches + PR per milestone/phase with plain-English summaries; wait for User approval before merging (implementation phase).
- **Review Cadence:** User playtests only at meaningful playable milestones and reviews Blender art via batched preview renders.
- **Communication:** Plain-English, jargon-free updates with proactive push-back authority if a request hurts quality, scope, or the Skyrim north star.

---

## Round 2 — Skyrim Feel & Core Gameplay Loop (`In Progress`)

**Goal:** Define what "feels like Skyrim" means in practice for camera perspective, combat mechanics, floor collapse reset rules, and exploration feel.

*(Awaiting user answers.)*

---

## Upcoming Rounds
- **Round 3:** World, Progression & *Dungeon Crawler Carl* Flavor
- **Round 4:** Tech Stack, Engine & Blender Art Pipeline
- **Round 5:** Automated Testing, CI & Milestone Roadmap
