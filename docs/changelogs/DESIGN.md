# Design & Balance Changelog

Detailed record of gameplay systems, rules, tuning, and DCC flavor implemented from [`docs/GAME_DESIGN.md`](../GAME_DESIGN.md).

---

## 2026-11-18 — Milestone 1 (`v0.1` Vertical Slice) Skyrim-Meets-DCC Complete Floor Loop

- **Skyrim Character Feel & Camera (`D-002`, `D-012`, `D-016`):**
  - Implemented 1st-person primary camera + `V` toggle to 3rd-person over-the-shoulder view with visible Blender crawler model.
  - Implemented stamina-governed sprinting, jumping, raycast world interaction (`[E]` prompts), and complete 5-day clock & world simulation freeze when Inventory (`I`/`Tab`), Vendor, or Pause (`Esc`) menus open.
- **Left/Right-Hand Combat (`D-013`):**
  - Implemented Skyrim left/right-hand equipping (`1` Sword+Shield, `2` Two-Handed Greatsword clearing off-hand, `3` Sword+Firebolt spell, `4` Hunting Bow with hold-and-release draw scaling).
  - Implemented Light/Power melee attacks, stamina shield blocking, Magicka offensive & healing spells, asymptotic armor mitigation, and Sponsored/Mythic combat triggers (`Explosive Crits`, `Vampiric Viewers`, `Tax Rebate Gold`).
- **Procedural Nordic-Ruin Labyrinth & World Landmarks (`D-008`, `D-015`, `D-021`, `D-022`):**
  - Implemented seeded multi-room floor generator guaranteeing Entrance, hidden Staircase (zero preview on descent), Safe Room (repels pursuing enemies into `FLEE_SAFE_ZONE`, hosts Vendor & Quest Board), and optional sealed Boss Arena + adjoining Treasure Vault unlocked only on Boss defeat.
  - Implemented Skyrim Top Compass Bar with proximity landmark discovery (`SAFE`, `BOSS`, `STAIRS`).
- **5-Day Floor Collapse, Snapshot Reset & Save-and-Quit (`D-006`, `D-007`, `D-014`, `D-017`, `D-018`):**
  - Configured 5 in-game days at 1,800 real seconds/day (~30 real minutes/day, data-driven in `world.json`).
  - Implemented Floor-Entry Snapshot capture on entering each floor; both Floor Collapse and Combat Death cleanly restore pre-floor state, discard failed-attempt mid-floor gains, and restart the floor with a fresh 5-day timer.
  - Implemented Save-and-Quit anytime preserving exact 3D position, vitals, inventory, remaining clock, boss state, and preserved Floor-Entry Snapshot.
- **Hybrid Progression, Loot & DCC Tone (`D-019`, `D-020`, `D-023`):**
  - Implemented XP/Level-Up Attributes + Perks alongside Skyrim use-to-improve weapon/magic/block proficiencies.
  - Implemented Skyrim equipment slots, 5 rarity tiers (`common` → `sponsored`), Safe Room Vendor trading, and snarky Dungeon AI popup banners.
