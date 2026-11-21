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

## 2026-11-18 — Hybrid Handcrafted Setpieces, Low-Friction Tutorial Mode & QoL Polish (`D-028`, `D-029`, `D-030`)

- **Hybrid Procedural + Handcrafted Rooms (`D-029`):**
  - Authored `game/data/setpieces.json` defining 5 handcrafted room archetypes (Entrance Arrival Hall, Warm Safe Room Sanctuary, Iron Warden Boss Crucible, Gilded Treasure Vault, Hidden Stairwell) stitched into procedural layouts on every seed.
- **Low-Friction Toggleable Tutorial Mode (`D-030`):**
  - Authored `game/data/tutorials.json` (9 contextual first-encounter topics) + `TutorialSystem` + non-blocking bottom-right HUD card with automatic completion as you perform each mechanic, `[H]` instant hide, Pause Menu ON/OFF toggle, and Reset Tutorials option (persisted across Save-and-Quit).
- **Skyrim Combat Feel & QoL Overhaul:**
  - Shrunk resting shield footprint to ~11% lower-left corner, added smooth alternating diagonal melee combos + power cleave + shield block raise + bow draw FOV zoom + 3rd-person wall-collision camera pullback + enemy telegraph wind-up & hit-flash reactions.
  - Replaced plain Godot default UI controls with obsidian-glass & antique-gold dark-fantasy HUD, Inventory, Vendor, Pause, and Audit Console themes (`UiTheme`).

## 2026-11-19 — UX & Quality-of-Life Suite (`D-035`) — no rule or balance changes

- Title screen (Continue with save summary, New Expedition with overwrite confirmation, Settings, Credits), Quit to Title.
- Dungeon map (`M`) with fog of war that persists in saves; landmark icons; zoom & pan.
- Inventory: equipment portrait, filters, sorting, stat comparison vs. equipped, double-click equip/use, right-click off-hand, unequip; separate Skills & Perks tab.
- Vendor: comparison card, double-click buy/sell, Sell All Common.
- HUD: landmark icons on the compass, vitals that fade when full, damage trails, low-health pulse, contextual crosshair (hit markers, block, bow-draw ring), key-cap prompts, loot toasts, area titles, level-up banner, potion count, death/collapse screen.
- Settings & accessibility: see `D-035`. Gameplay timing is unchanged — enemy attack animations are synchronised to the existing attack timers (`D-033`).


## 2026-11-20 — Core Gimmick: The Power-Scaling Race (`D-038`) — design direction only

- The game's central challenge is power-scaling fast enough to survive the end of each floor; every floor ramps up in difficulty, so leveling heavily and securing good gear between floors is essential.
- Players can always reset their progress to the start of any floor they have reached (restoring that floor's Floor-Entry Snapshot).
- Not yet implemented: per-floor difficulty curve, floor-select/reset UI, and multi-floor snapshot storage.

## 2026-11-20 — One Fixed Seed: Same Floor Every Attempt (`D-039`)

- Every playthrough uses run seed `20261118`. Layout, dressing, enemies, vendor stock and all container/enemy loot are identical on every attempt at a floor; loot no longer depends on open/kill order.
- Known gap (pre-existing): opened containers are not recorded in the save file, so save-and-quit then Continue refills them — now with the identical items. To be addressed separately.

## 2026-11-20 — Larger, Denser Floors (`D-042`)

- 72x72 grid, 28-36 rooms, more loops, ~2x enemies (30 / 38), 1-3 containers per combat room, chest chance 0.6, prop density 0.6. Default seed: 30 rooms, ~17,200 m2, 31 enemies, 17 chests, 45 containers.
- Treasure Vault now has a compass/map landmark and is force-opened whenever the boss is dead.

## 2026-11-20 — Vast Floors (`D-044`)

- 336x336-tile floors (~650 rooms, ~430,000 m2) so a run cannot realistically explore 25%. Sparse landmarks: entrance near a corner, boss arena + vault far away (single gated corridor), 3 stairwells far apart, 9 safe rooms (one per ninth). Compass always hints the nearest undiscovered stairwell and the boss gate. Enemy budget 440 / 530.

## 2026-11-20 — FB-013: Difficulty Curve, Either-Hand Items, Enemy Awareness (`D-046`)

- Enemy rebalance (floor 1): draugr 210 HP / 21 dmg / 1.2 s, archer 140 / 20 / 1.8 s (range 22 m), goblin 170 / 24 / 1.0 s, Iron Warden 1600 / 48 / 1.4 s; XP raised. Aggro 22 / 30 / 24 / 24 m with line of sight; 6 m hearing; 4 s lose-sight. No player-level scaling.
- Any one-handed blade, shield or spell in either hand; rings fill ring slots 1-2.

## 2026-11-20 — FB-014: Pathfinding Enemies, RPG Rarities (`D-048`)

- Enemies path around walls and props (A* over floor tiles) and unstick themselves instead of pressing into obstacles.
- Rarity tiers are Common / Uncommon / Rare / Epic / Legendary (the old Sponsored tier is Legendary; the sponsored *effects* on specific items are unchanged).

## 2026-11-20 — FB-015: Discovery & Mastery (`D-049`)

- All world loot Common for now; 38 distinct items with per-item drop weights and their own mastery tracks (levels 1–10, +7% core stats per level, item-specific abilities from `mastery.json`).
- 11 enemy types with unique traits and per-type level ranges; floors cover level bands (1–4, 4–7, …) so deeper floors introduce new enemies; stats scale with level.
- Bestiary with tiered knowledge (sighted → slain → studied after 5 kills).

## 2026-11-20 — FB-018: Ability-Scaling Enemies & Living Content Catalog (`D-051`, `D-052`) — design only

- Created [`docs/CONTENT_CATALOG.md`](../CONTENT_CATALOG.md) and updated `docs/GAME_DESIGN.md` (§6.2–6.3):
  - **Enemies upgrade unique abilities with level:** higher-level spawns unlock stronger ability tiers (not just HP/damage).
  - **Planned enemies:** Flying Exploder (`Cinder Wisp / Blight Drone`), Death Splitter (`Mire Ooze / Marrow Splitter`), Adaptive Random-Spell Caster (`Runebound Arcanist` with Utility-Scoring AI), Tanky Frontliner (`Obsidian Juggernaut`), and Rock-Throwing Kiter (`Crag Goblin Skirmisher`).
  - **Planned magic tomes:** `Tome of Seeking Missiles` (more missiles + distinct per-missile abilities), `Tomes of Summoning` family (higher summon levels + quantities), `Tome of Venomous Ground` (poison pool), `Tome of Haste`, and `Tome of Paralysis` (longer duration + overcomes higher enemy power/resistance).
  - **Planned weapons:** `Swift Blade` (1H forward-launch sword: longer lunge & faster cooldown with mastery) and `Titanbreaker Greataxe` (2H knockback axe: further knockback & overcomes higher enemy knockback resistance).
  - Added brainstormed bonus enemies, tomes, gear, and arena/hazard mechanics for iteration.

