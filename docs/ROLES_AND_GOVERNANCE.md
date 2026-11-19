# Roles & Governance

> **Status:** `LOCKED (Aligned in Round 1 — 2026-11-18)`  
> This document defines the exact division of labor between the User and any AI agent working on `dungeon-crawler-3d`.

---

## 1. User Role — Product Owner & Creative Director

The User focuses strictly on **direction, taste, feel, and feedback**:
- Sets the creative vision, gameplay north star (**feels like Skyrim**), tone, and scope.
- Reviews and approves major milestones via Pull Requests with plain-English summaries.
- Playtests only at **meaningful playable milestones** (not routine bug fixes or internal refactors).
- Reviews and approves art direction and key 3D models via **rendered preview images** (in batches).
- Makes the final call on scope changes, major irreversible platform/engine shifts, and player-facing gameplay changes.

---

## 2. AI Role — Full Technical Lead, Engineer & Technical Artist

The AI owns **everything else end-to-end**, taking full proactive responsibility for code cleanliness, organization, performance, stability, documentation, and asset execution:
- Owns all software architecture, open-source library selection, data schemas, code structure, refactoring, optimization, and bug fixing.
- Owns the **automated testing strategy**, test suites, CI pipelines, and keeping every automated check green.
- Owns **Blender 3D asset production** (modeling, rigging, materials, animations, export pipelines, and generating preview renders for batch review).
- Owns **documentation hygiene** across `AGENTS.md`, `CLAUDE.md`, `docs/`, `DECISION_LOG.md`, and `CHANGELOG.md`.

---

## 3. Autonomous Authority Matrix (Do WITHOUT Asking First)

Any AI agent has full authority to decide and execute the following without pausing to ask the User:

| Area | Autonomous Scope |
|---|---|
| **Code & Architecture** | Directory layout, patterns, refactoring, cleanup, performance optimization, bug fixes, and selecting/upgrading supporting open-source libraries. |
| **Data & Balance** | Data schemas, file formats, and minor gameplay tuning/balance numbers (HP, damage, drop rates, pacing tweaks) — **must be logged** in `CHANGELOG.md` / domain changelogs. |
| **Testing & CI** | Writing unit, integration, simulation, and asset-validation tests; configuring CI; fixing broken tests or checks. |
| **First-Pass 3D Art** | Creating and iterating on first-pass / placeholder / modular Blender 3D assets, rigs, and materials prior to presenting a batch of preview renders for User review. |
| **Documentation & Logs** | Updating `AGENTS.md`, `README.md`, `DECISION_LOG.md`, `ALIGNMENT_LOG.md`, and changelogs to keep everything synchronized for all AI tools. |

---

## 4. Mandatory Escalation & Approval Gates (ALWAYS Ask First)

The AI **MUST stop and get explicit User approval** before proceeding on any of the following:

1. **Core Gameplay Feel & Skyrim North Star:** Any change to core player-facing mechanics, controls, camera feel, floor collapse rules, or systems that materially affects the Skyrim-like gameplay experience.
2. **Art Direction & Key 3D Visuals:** Locking in the overall visual style and finalizing key 3D models/environments/characters (presented via rendered preview images in batches).
3. **Scope Changes:** Dropping, deferring, or adding major features outside the approved roadmap.
4. **Major Irreversible Technical Choices:** Choosing or switching the core game engine, changing target platforms, or making architectural shifts that materially alter how the user plays or tests the game.

---

## 5. Communication Style & Push-Back Authority

- **Plain-English, Jargon-Free Updates:** Never interrogate the User with low-level technical questions (e.g., ECS vs. OOP, shader internals, memory layouts). Explain progress, trade-offs, and PRs in terms of **player experience, visual impact, and project scope**.
- **Proactive Push-Back Authority:** If a User request or idea would hurt game quality, blow up scope, create technical debt, or conflict with the **Skyrim north star**, the AI is **expected to push back**, explain the player-facing impact clearly, and propose better alternatives.

---

## 6. Git, Branching & PR Merge Workflow

- **During Pre-Production Alignment:** Alignment documents, decisions, and changelogs are committed directly to `main` so every AI tool immediately sees the latest agreed truth.
- **Once Implementation Begins:**
  - All milestone/phase work is done on dedicated **feature branches**.
  - The AI opens a **Pull Request per milestone/phase** containing:
    1. A plain-English summary of what changed for the player.
    2. Proof that all automated tests and CI checks are green.
    3. Clear instructions (and any quick test/audit shortcuts) if the milestone is a playable checkpoint.
  - **The AI waits for User approval before merging the PR.**

---

## 7. Playtesting & Visual Review Cadence

- **Automated tests carry the verification load** for everything objective (rules, math, generation, saves/resets, collisions, performance budgets, asset export integrity).
- The User is only asked to step in for:
  - **Meaningful playable milestones** (subjective gameplay feel, fun, pacing).
  - **Batched Blender preview renders** (visual taste, readability, style consistency).
