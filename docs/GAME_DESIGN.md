# Game Design Document (GDD)

> **Status:** `Active Living Design Specification (v0.1+)`  
> **North Star:** **Feels like Skyrim**, fused with the dark-humor multi-floor dungeon premise of ***Dungeon Crawler Carl***.  
> **Decision References:** `D-001` through `D-039` in [`docs/DECISION_LOG.md`](DECISION_LOG.md).

---

## 1. Core Experience & Tone

- **Skyrim North Star (`D-002`):** Immersive 3D exploration, weighty tactile combat, environmental discovery, interactive looting, and build freedom.
- **"Dark Baseline, Goofy Payload" (`D-023`):** The dungeon itself looks and feels grim, ancient, and dangerous—flickering torchlight, cold stone corridors, looming Nordic-style ruins, and lethal monsters. Overlaid on that serious foundation is a **snarky Dungeon AI** that delivers sarcastic system announcements, absurd achievement popups, and ridiculous **"Sponsored / Mythic"** loot descriptions.

---

## 2. Camera, Controls & Low-Friction Tutorial Mode (`D-012`, `D-016`, `D-030`)

- **First-Person Primary + Third-Person Toggle:** Play primarily in first-person with an instant toggle to over-the-shoulder third-person (just like Skyrim). First-person weapons and shields must be framed cleanly in the lower corners so sightlines stay wide open.
- **Top Compass Bar:** Shows directional headings and reveals nearby landmarks (Safe Rooms, Boss Doors, Vaults, Staircases) as the player approaches them.
- **Classic Menu Pause:** Opening Inventory, Character/Skills, Map, or Vendor screens freezes world simulation and the floor collapse timer cleanly.
- **Interactive World Objects:** Aim at and interact with chests, enemy bodies, crates, urns, levers, traps, vendors, quest boards, and staircases.
- **Low-Friction Toggleable Tutorial Mode (`D-030`):**
  - Enabled by default and toggleable anytime in the Pause Menu (with an option to Reset Tutorials).
  - The **first time** a player encounters or interacts with any mechanic (camera/movement, melee/blocking/power attacks, spells/archery, looting, inventory pause, Safe Room & Vendor, Boss Arena seal, 5-day clock & snapshot reset, hidden staircase descent), a sleek, unobtrusive corner hint card walks them through it in 1–2 crisp lines.
  - Auto-completes with a subtle chime when the player performs the action (or dismisses cleanly with one tap/timeout) — never freezes the screen with annoying modal walls of text.

---

## 3. Core Floor Loop & Stakes (`D-006`, `D-007`, `D-008`, `D-014`, `D-017`, `D-018`)

1. **Enter Floor (Snapshot Taken):** Upon entering a floor, the game records a **Floor-Entry Snapshot** of the player's character level, skills, perks, gold, and equipped/carried gear.
2. **Explore Under the 5-Day Clock:** Each floor has a **5 in-game day** collapse countdown (~30 real-time minutes per in-game day = ~2.5 hours per floor initially; fully data-driven).
3. **Save-and-Quit Anytime:** Players can exit at any time; the game auto-saves exact position, floor state, and remaining timer so long floors can span multiple play sessions.
4. **Collapse or Combat Death = Floor-Entry Reset:** If the 5-day timer hits zero OR the player dies in combat, the player resets to the **Floor-Entry Snapshot** at the floor entrance with a fresh 5-day timer and a freshly reset floor. No full-run permadeath.
5. **Unknown Descent:** Finding the hidden exit staircase lets the player descend to the next floor with **no staircase previews**—what awaits below is always a surprise.

---

### 3.1 Core Gimmick — The Power-Scaling Race (`D-038`)

- **The central challenge:** Can the player power-scale fast enough to survive the end of the floor? Every floor ramps up in difficulty, so the player must **level up heavily and secure strong gear** on each floor and between floors — falling behind the curve makes later floors unwinnable.
- **Everything feeds the race:** XP, use-to-improve skills, perks, loot rarity/affixes, vendor purchases, quests, and optional Boss Arenas + Treasure Vaults are the player's tools for keeping ahead of the difficulty ramp; the 5-day clock forces the trade-off between farming power and pushing for the staircase.
- **Reset to Any Floor:** The player can **always reset their progress to the start of any floor they have reached**, restoring that floor's Floor-Entry Snapshot. If they descend under-powered, they can go back to an earlier floor and rebuild rather than being permanently stuck.
- **Same Floor Every Attempt (`D-039`):** Every playthrough uses one fixed seed. When the player dies or the floor collapses, the floor comes back **exactly the same** — same layout, enemies, vendor stock, and the same loot in every chest, crate, urn and enemy drop (regardless of the order things are opened). Players can learn a floor and plan the fastest route to the gear they need.
- **Still to design:** the per-floor difficulty curve (enemy stats, density, elites, boss scaling), how the floor-select/reset is presented to the player, and how many floor snapshots are stored in the save.

---

## 4. Hybrid World Structure: Procedural + Handcrafted Setpieces (`D-015`, `D-021`, `D-022`, `D-029`)

- **Hybrid Procedural + Custom-Built Architecture (`D-029`):** Each floor seamlessly stitches **handcrafted, custom-built signature rooms and encounters** into a sprawling **procedurally generated interconnected Nordic-ruin labyrinth**. Custom-authored blueprints define focal landmarks (grand Entrance Halls, cozy lantern-lit Safe Room sanctuaries with hearth/carpet/vendor stall/quest board, dramatic multi-pillar Boss Arenas with bespoke encounter staging, ornate Treasure Vaults, shrine/puzzle chambers, and secret crypts) that are procedurally slotted and connected into every run's seeded dungeon graph.
- **Deterministic Seeded Generation:** Every floor layout is generated from a seed so any floor can be reproduced identically for automated testing and bug reports.
- **Discoverable Safe Rooms & Underground Towns:** Handcrafted sanctuary pockets scattered in the labyrinth where pursuing enemies immediately break off and cannot enter. Contain **Vendors**, **Quest Boards**, and **Stash/Rest** spots.
- **Optional Sealed Boss Arenas + Treasure Vaults:** Handcrafted boss chambers where crossing the threshold seals the exit behind you until the boss falls; defeating the boss unlocks an adjoining high-tier **Treasure Vault**. Players constantly weigh risk and remaining time against big rewards.
- **Hidden Exit Staircase:** Placed deep in the labyrinth inside a carved descent chamber to reward thorough exploration.

---

## 5. Combat System (`D-013`)

Skyrim-inspired **left-hand / right-hand equipping** supporting four classic playstyles:
- **Sword & Shield:** Weighted melee swings, stamina-driven power attacks, directional blocking, and shield bashes.
- **Dual-Wield / Two-Handed:** Fast dual combos or heavy high-stagger two-handed strikes.
- **Magicka Spellcasting:** Equip spells in either hand (e.g., Firebolt, Chain Lightning, Healing, Ward/Buff) fueled by regenerating Magicka.
- **Archery / Ranged:** Manual crosshair aiming, draw-tension shots, and projectile physics.
- *(Stealth/sneak-attack systems are intentionally deferred out of the core foundation to keep v0.1 focused and crisp.)*

---

## 6. Progression, Loot & Economy (`D-019`, `D-020`)

- **Hybrid Progression:**
  - **XP & Levels:** Combat, quests, and landmark discovery award XP that levels up the character, granting **Attribute Points** (Health / Magicka / Stamina) and **Perk / Skill Tree Points**.
  - **Skyrim Use-to-Improve:** Swinging melee weapons, casting spells, blocking, and firing bows steadily improve those skill proficiencies through use.
- **Skyrim Equipment Slots + Chaotic Affixes:**
  - Familiar slots: Left Hand, Right Hand, Head, Chest, Hands, Feet, Ring(s), Amulet.
  - Items roll across rarity tiers (**Common → Uncommon → Rare → Epic → Sponsored/Mythic**) with scalable stats and wild build-changing affixes (especially on Sponsored/Mythic drops).
- **Economy & Quests:** Sell excess loot and buy supplies/gear at Safe Room Vendors; pick up floor-specific bounties and exploration quests from Quest Boards.

---

## 7. Art & Audio Direction (`D-005`, `D-025`, `D-026`)

- **100% Original Blender 3D Art:** Modular Nordic-ruin dungeon kit (snappable floors, walls, arches, pillars, stairs, doors, torches, chests, props), characters, weapons, and enemies authored in Blender and exported as `.glb`.
- **Clean Stylized Dark Fantasy:** Crisp silhouettes, smooth-shaded/beveled geometry, atmospheric torchlight and shadows, and procedural/painted textures—built to iterate fast in v0.1 while leaving clean room to increase visual richness over time.
- **100% Open-Source Audio:** Procedural/synthesized SFX (steel clashes, spells, footsteps, chest latches, dungeon ambience) paired with punchy on-screen Dungeon AI notification banners.

---

## 8. Presentation, UI & Quality of Life (`D-031`–`D-035`)

- **Look:** stylized dark fantasy at an "AA-indie" bar — hand-cut stone architecture, warm torch pools against cool shadow, volumetric haze, detailed props, rigged and animated characters; Low → Ultra graphics presets.
- **Front end:** title screen over a live 3D hall (Continue with save summary, New Expedition, Settings, Credits, Quit).
- **HUD:** compass with landmark icons, floor clock, slim vitals that fade when full, contextual crosshair (hit marker, block, bow-draw ring), key-cap interaction prompts, equipped-item icons, Dungeon AI broadcast cards, loot toasts, area titles, level-up banner, boss bar with enrage state, tutorial card.
- **Menus:** pause (with run status, controls reference and settings), inventory (3D portrait, equipment slots, filter/sort grid, comparisons, unequip, off-hand right-click), Skills & Perks, vendor (comparisons, sell-all-common), dungeon map with fog of war (`M`), death/collapse screen.
- **Comfort & accessibility:** FOV, render scale/FSR, brightness, audio channels, mouse sensitivity/invert, full key rebinding, head bob & camera shake sliders, damage numbers, enemy health bar mode, crosshair style, HUD opacity, UI scale, colour-blind filters, announcement text, reduced flashing; confirmations before destructive actions.

