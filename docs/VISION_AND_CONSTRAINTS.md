# Vision, Goals & Constraints

> **Status:** Living document — updated as alignment rounds conclude.  
> **Last Updated:** 2026-11-18

---

## 1. Gameplay North Star

> **"I want the game to feel like Skyrim. This is probably the most important and guiding note on how the gameplay should feel."**

Every major design decision—perspective, movement, combat weight, exploration, environmental storytelling, inventory, progression, and pacing—should be measured against whether it evokes the immersive, exploratory, tactile RPG feel of **Skyrim**, fused with the multi-floor dungeon premise inspired by ***Dungeon Crawler Carl***.

---

## 2. Locked-In Core Rules & Pillars

| Pillar | Locked-In Rule | Rationale |
|---|---|---|
| **3D Gameplay Feel** | Feels like **Skyrim** (north star) | Guides camera, exploration, combat feel, and immersion |
| **Floor Collapse Timer** | **5 in-game days** per floor, with **1 in-game day ≈ 30 real-time minutes** (initial target; data-driven) | Forces meaningful exploration and urgency without rushing the player through a 5-minute sprint |
| **Collapse Consequence** | **Reset to the beginning of the current floor** (NOT full-run permadeath) | Preserves stakes and time pressure without wiping an entire multi-hour run |
| **Staircase Descent** | **No staircase previews** | Keeps descending into the next floor mysterious and rewarding to discover |
| **Open-Source Leverage** | Use existing **free, open-source** engines & libraries rather than building from scratch | Maximum speed, stability, flexibility, and zero proprietary lock-in |
| **100% Original Art** | All art created by us using **Blender** and other free/open-source tools | Full ownership, cohesive style, zero asset-pack licensing issues |
| **Automated-Testing First** | Anything that can be tested automatically **must** be tested automatically | Minimizes manual testing burden on the user and catches regressions early |
| **Multi-AI Readiness** | Robust docs, `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, Copilot instructions, decision logs, and changelogs for everything | Any AI tool can pick up the repo cold with full context and zero drift |

---

## 3. Concepts Carried Forward From Prior Repos (To Refine in Alignment)

From `Dungeon-Crawler-Game-2` and `dungeon-crawler-engine`, the following concepts remain strong candidates to adapt into our 3D Skyrim-style design during upcoming alignment rounds:
- Multi-floor procedural dungeon descent with distinct floor identities/themes
- Safe Zones ("Cities") with Vendors and Quest Boards where enemies cannot pursue
- Locked Boss Arenas with adjoining Treasure Vaults
- Deep RPG loot & affix scaling, status effects, and character progression/skill trees
- *Dungeon Crawler Carl*–inspired dark-world / absurd-payload humor & "sponsored" loot flavor
- Seeded deterministic runs for reproducible testing and bug reports

---

## 4. Non-Negotiable Constraints

1. **100% Free & Open Source:** Engine, libraries, art tools (Blender, etc.), audio tools, and our own repository must remain completely free and open source.
2. **No Third-Party Art Packs:** All 3D models, textures, materials, animations, and UI graphics are built in-house.
3. **Automated Verification Before Handoff:** Unit tests, integration tests, headless gameplay/simulation tests, data validation, and asset-pipeline validation must cover everything automatable so the user only needs to evaluate subjective feel, visuals, and high-level direction.
4. **No Code Before Alignment:** No game implementation or asset generation begins until the pre-production alignment rounds are complete and approved.

---

## 5. Planned Pre-Production Alignment Rounds

1. **Round 1 — Roles & Division of Labor:** Clear boundaries on what the AI can decide/execute autonomously vs. when to ask the user, communication cadence, and approval gates. *(In Progress)*
2. **Round 2 — Skyrim Feel & Core Gameplay Loop:** Camera (1st/3rd person toggle?), combat mechanics (melee/magic/stealth/bows?), floor reset rules (what is kept vs. lost on floor collapse?), and exploration structure.
3. **Round 3 — World, Progression & *Dungeon Crawler Carl* Flavor:** Floor themes, safe zones/cities, bosses, loot/affixes, leveling/skills, and tone/humor.
4. **Round 4 — Tech Stack, Engine & Blender Art Pipeline:** Engine choice (e.g., Godot 4 vs. alternatives), target platforms, 3D visual style, and automated Blender asset/preview workflow.
5. **Round 5 — Automated Testing, CI & Milestone Roadmap:** What gets tested automatically, how builds/previews are delivered, and the phased execution plan.
