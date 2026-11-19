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

## Round 2 — Skyrim Feel & Core Gameplay Loop (Completed: 2026-11-18)

**Agreed Outcomes (logged in `D-012` through `D-017`):**
- **Camera:** First-person primary with optional toggle to over-the-shoulder third-person.
- **Core Combat:** Left/right-hand equipping (sword+shield, dual-wield, sword+spell, two-handed), weighted melee + power attacks + blocking + stamina, magicka spellcasting (fireballs, lightning, healing, buffs), and archery/ranged weapons with manual crosshair. (Stealth/sneak-attacks deferred.)
- **Floor Collapse Reset:** Floor-entry snapshot — keep level/gear from floor entry; reset floor fresh with a new 5-day timer.
- **Floor Structure:** Massive interconnected labyrinth of dungeon rooms, halls, and corridors (giant Skyrim Nordic ruin feel).
- **Exploration & Pacing Touches:** Top compass bar for nearby landmarks, interactive looting (chests, bodies, containers, levers, traps), and full time-pause on inventory/map/skill menus.
- **Saving:** Save-and-quit anytime (resumes exact position/timer/state), while floor collapse still resets to the floor-entry snapshot.

---

## Round 3 — World, Progression & *Dungeon Crawler Carl* Flavor (`In Progress`)

**Goal:** Align on tone/humor, floor themes, safe zones/cities, boss arenas, loot & affix depth, progression/leveling style, and combat death behavior.

*(Awaiting user answers.)*

---

## Upcoming Rounds
- **Round 4:** Tech Stack, Engine & Blender Art Pipeline
- **Round 5:** Automated Testing, CI & Milestone Roadmap
