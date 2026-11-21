# Work Log

> **Status:** `Living document — append-only` (rule `D-050`, see [`AGENTS.md`](../AGENTS.md)).
> All work is committed **directly to `main`**. This log is the backtracking map: every change gets an entry with the
> commit SHA(s), what it changed, the feedback/decision it answers, and how to undo it. Newest entries at the bottom.
> Details live in [`CHANGELOG.md`](../CHANGELOG.md), the domain changelogs and [`USER_FEEDBACK_LOG.md`](USER_FEEDBACK_LOG.md).

**How to undo something**
- A normal commit: `git revert <sha>` (creates a new commit that undoes it; history is never rewritten).
- One of the older pull-request merges (before `D-050`): `git revert -m 1 <merge-sha>`.
- To look at the game as it was: `git checkout <sha>` (read-only look), then `git checkout main` to come back.
- Find a change by keyword: `git log --oneline --grep "<word>"`.

| Date | Commit(s) on `main` | Change | Feedback / Decision | Undo |
|---|---|---|---|---|
| 2026-11-20 | `4c61175` (PR #4 merge) | Natural animation overhaul | FB-001/002, `D-037` | `git revert -m 1 4c61175` |
| 2026-11-20 | `2bc0d19`, `bb7608b` (PR #5, #6) | Power-scaling gimmick documented; one fixed seed per playthrough | FB-004, FB-005, `D-038`, `D-039` | `git revert -m 1 <sha>` |
| 2026-11-20 | `d259d18`, `600cf61` (PR #7, #8) | First-person animation pass v3 | FB-006, `D-040` | `git revert -m 1 <sha>` |
| 2026-11-20 | `111ded6` (PR #9) | Brighter dungeon lighting | FB-009, `D-041` | `git revert -m 1 111ded6` |
| 2026-11-20 | `105eabc` (PR #10) | Vault access + larger floors | FB-010, `D-042` | `git revert -m 1 105eabc` |
| 2026-11-20 | `7c34c8a` (PR #11) | Boss gates fix | FB-011, `D-043` | `git revert -m 1 7c34c8a` |
| 2026-11-20 | `12ca666` (PR #12) | Vast floors | FB-012, `D-044` | `git revert -m 1 12ca666` |
| 2026-11-20 | `337cf05` (PR #13) | Feedback log, rings, difficulty, either-hand items, enemy AI, 3P looting, minimap, Test Mode | FB-013, `D-045`–`D-047` | `git revert -m 1 337cf05` |
| 2026-11-20 | `d6f6529` (PR #14) | Chest/shield holes, enemy pathfinding, RPG rarities, edge-forward blades, 3P dual-wield/bow/spells, inventory fit | FB-014, `D-048` | `git revert -m 1 d6f6529` |
| 2026-11-20 | `295f1c7` (PR #15) | Discovery & Mastery: varied all-Common loot, item mastery abilities, unique leveled enemies, Bestiary | FB-015, FB-016, `D-049` | `git revert -m 1 295f1c7` |
| 2026-11-20 | `17892bf` | Workflow switched to direct commits on `main`; this work log added | FB-017, `D-050` | `git revert 17892bf` |
| 2026-11-20 | `a5e5e94` | Living Content Catalog (`docs/CONTENT_CATALOG.md`), unified entity stats & extensibility architecture, ability-scaling enemies, planned tomes/weapons (docs only) | FB-018, `D-051`, `D-052` | `git revert a5e5e94` |
| 2026-11-20 | `3c35061` | Future Ideas Vault (`docs/IDEAS_BACKLOG.md`) & FB-019 ideas fleshed out in `CONTENT_CATALOG.md` (docs only) | FB-019, `D-053`, `D-054` | `git revert 3c35061` |
| 2026-11-20 | `c1dad94` | All-in-one modular architecture refactor (EntityStats, StatusComponent, CombatActor/AI, GroundZone/Barrier/AbilityExecutor, CombatResolver, ViewmodelRig, FloorTheme/RarityTable, modular DataLoader; zero gameplay changes) | FB-020, `D-055` | `git revert c1dad94` |
| 2026-11-21 | `ed7361f` | Standing rule: always include local GitHub sync command after every edit (branch-aware) | FB-021, `D-056` | `git revert ed7361f` |



| 2026-11-21 | `cbaa0b9` + merge `665d75a` | FB-022: exact enemy health bars, straight-walking enemies, 2.5× weaker enemies + champion lairs, power-scale knobs (`balance.json`), hotbar 1–8, stacking consumables/ingredients + vendor quantities, status-effect list, visible damage over time, level-1 abilities + level-up instructions, safe-room area maps, full removal of the TV-show/sponsor theme (merged onto the D-055 refactor) | FB-022, `D-057` | `git revert -m 1 665d75a` (undoes the whole round) |
| 2026-11-21 | `9992771`, `f2d9ba1`, `be84490` (fast-forward of `main` to `be84490`) | FB-022 test fixes + visual-QA polish (visible flames); FB-022 round landed on `main`; standing rule to always merge to `main` automatically | FB-022, FB-023, `D-057`, `D-058` | `git revert -m 1 665d75a` undoes the FB-022 merge; `git revert be84490` undoes the rule docs |
| 2026-11-21 | `1cd6e6a`, `bedeb5c` (branch `trial/premade-animations`, not merged to `main`) | FB-025 trial: CC0 premade animation research (`docs/PREMADE_ANIMATIONS_RESEARCH.md`), offline Mesh2Motion + ItsPogle CC0 banks (`art/premade_anims/`), all 6 rigged 3P characters retargeted (`premade_retarget.py`), all 1P `ViewmodelRig` animations replaced with data-driven CC0 curves (`game/data/fp_animations.json`), `EnemyActor.IMPACT_TIME` synced, `test_premade_animations.gd` added | FB-025, `D-060` | Delete branch (`git branch -D trial/premade-animations`) or `git revert bedeb5c 1cd6e6a` |
