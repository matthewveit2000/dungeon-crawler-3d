# Game Design Document (GDD)

> **Status:** `Active Living Design Specification (v0.1+)`  
> **North Star:** **Feels like Skyrim**, fused with a dark-humor, multi-floor dungeon premise: a grim world full of goofy monsters (`D-057`).  
> **Decision References:** `D-001` through `D-039` in [`docs/DECISION_LOG.md`](DECISION_LOG.md).

---

## 1. Core Experience & Tone

- **Skyrim North Star (`D-002`):** Immersive 3D exploration, weighty tactile combat, environmental discovery, interactive looting, and build freedom.
- **"Dark Baseline, Goofy Payload" (`D-023`):** The dungeon itself looks and feels grim, ancient, and dangerous—flickering torchlight, cold stone corridors, looming Nordic-style ruins, and lethal monsters. Overlaid on that serious foundation are **goofy monsters and themes** (Glory-Hound goblins hauling hoops of stolen candles, champions with titles like *"the Gravy-Stained"*) and **the voice of the dungeon itself** — an ancient, smug, faintly bored announcer — plus absurd item descriptions. There is no TV show, audience, sponsor or Syndicate (`D-057`).

---

## 2. Camera, Controls & Low-Friction Tutorial Mode (`D-012`, `D-016`, `D-030`)

- **First-Person Primary + Third-Person Toggle:** Play primarily in first-person with an instant toggle to over-the-shoulder third-person (just like Skyrim). First-person weapons and shields must be framed cleanly in the lower corners so sightlines stay wide open.
- **Hotbar (`D-057`):** keys 1–8 equip favourite weapons/spells/shields or use a consumable from its stack.
- **Top Compass Bar:** Shows directional headings and reveals nearby landmarks (Safe Rooms, Boss Doors, Vaults, Staircases) as the player approaches them.
- **Classic Menu Pause:** Opening Inventory, Character/Skills, Map, or Vendor screens freezes world simulation and the floor collapse timer cleanly.
- **Interactive World Objects:** Aim at and interact with chests, enemy bodies, crates, urns, levers, traps, vendors, safe-room area maps, and staircases.
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

- **Hybrid Procedural + Custom-Built Architecture (`D-029`):** Each floor seamlessly stitches **handcrafted, custom-built signature rooms and encounters** into a sprawling **procedurally generated interconnected Nordic-ruin labyrinth**. Custom-authored blueprints define focal landmarks (grand Entrance Halls, cozy lantern-lit Safe Room sanctuaries with hearth/carpet/vendor stall/area-map board, dramatic multi-pillar Boss Arenas with bespoke encounter staging, ornate Treasure Vaults, shrine/puzzle chambers, and secret crypts) that are procedurally slotted and connected into every run's seeded dungeon graph.
- **Vast Floors — Explore Less Than a Quarter Per Run (`D-044`):** Each floor is a **vast** labyrinth (336×336 tiles ≈ 1.3 km square, ~650 rooms, ~430,000 m² walkable) sized so a player **cannot realistically explore even 25% of it in one 5-day run**: a quarter of the tiles takes ~85 min of perfect, never-backtracking walking, ~2.8 h with normal maze backtracking, versus a 2.5 h floor clock, before any fighting or looting.
  - **Sparse landmarks:** entrance near a random corner; Boss Arena + Treasure Vault in the far part of the map (one corridor in, through its sealable gate); **three hidden stairwells**, each far from the entrance and from each other; **nine Safe Rooms**, one per ninth of the map, so a vendor is never impossibly far.
  - **Always findable:** every landmark is reachable from the entrance, and the compass always shows a faint "?" toward the nearest undiscovered stairwell and the boss gate from any distance; the route through the maze is the exploration.
  - **Why it matters:** the player can never clear a floor, so every run is a routing decision between power (chests, containers, vendors, the boss vault) and the stairs — the heart of the power-scaling race (`D-038`).
- **Deterministic Seeded Generation:** Every floor layout is generated from a seed so any floor can be reproduced identically for automated testing and bug reports.
- **Discoverable Safe Rooms & Underground Towns:** Handcrafted sanctuary pockets scattered in the labyrinth where pursuing enemies immediately break off and cannot enter. Contain **Vendors**, an **Area Map** of the surroundings (`D-057`), and **Stash/Rest** spots.
- **Optional Sealed Boss Arenas + Treasure Vaults:** Handcrafted boss chambers where crossing the threshold seals the exit behind you until the boss falls; defeating the boss unlocks an adjoining high-tier **Treasure Vault**. Players constantly weigh risk and remaining time against big rewards.
- **Hidden Exit Staircase:** Placed deep in the labyrinth inside a carved descent chamber to reward thorough exploration.

---

## 5. Combat System (`D-013`, `D-046`)

- **Either hand (`D-046`):** any one-handed item — blade, shield or spell — can be held in either hand: dual spells, spell + shield, a shield in the right hand (blocks while that hand's button is held), a sword in the left. Bows and two-handed weapons use both hands.
- **Difficulty curve (`D-046`):** every floor starts very hard — enemy stats come from each enemy's level, which the floor sets (never the player's level, `D-049`), and a fresh arrival is evenly matched by a single draugr and outclassed by the boss — then gets easier as the player levels up and finds gear on that floor. This is the power-scaling race (`D-038`).
- **Enemy awareness (`D-046`):** idle enemies wander their rooms; they notice the player from 22-30 m when they can see them (6 m by hearing), archers shoot from 22 m, and they give up after a few seconds out of sight.

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
- **Skyrim Equipment Slots & Inherent Rarities (`D-060`):**
  - Familiar slots: Left Hand, Right Hand, Head, Chest, Hands, Feet, Ring(s), Amulet.
  - Rarity tiers are **Common → Uncommon → Rare → Epic → Legendary** (`D-048`, `D-060`). Every item has a **fixed inherent rarity** (no random prefixes/suffixes or floor-scaled copies of the same item): stronger, more unique items carry higher rarities, higher rarities become more common on deeper floors, and lower rarities have lower mastery ceilings and fewer abilities.
  - **No-Duplicate Non-Stackable Pool (`D-060`):** Once any weapon, spell, shield, armor piece, or accessory is received (including starting loadout), it is pulled from the world and vendor loot pools while owned. Selling an item returns it to the pool; death/collapse restores ownership with the Floor-Entry Snapshot. If a rarity's pool empties, drops step downward (never upward) and fall back to stackable consumables/ingredients + gold.
- **Economy & Quests:** Sell excess loot and buy supplies/gear at Safe Room Vendors; study each safe room's area map to mark nearby treasure and champion lairs on your own map.

### 6.1 Discovery, Inherent Rarities & Item Mastery (`D-049`, `D-060`)

The game should feel like you are **constantly discovering** something new: a weapon you have never held, a spell that
does something you have not seen, an enemy you have never fought, a rarer room variant.

- **A large variety of distinct loot.** Every item is its own thing with its own identity and inherent rarity (`common`–`legendary`):
  Nordic longsword, bearded hand axe, flanged mace, barrow seax, ash-hilt broadsword, battleaxe, war hammer, Dane axe,
  recurve / yew long / bone short bows, firebolt, chain spark, frost shard, venom spit, void lance, blood siphon, mend
  wounds, round / kite shields and a buckler, armor and jewellery for every slot, plus legendary relics. **Rarity drives
  spawn rates** across items, enemies, rooms, chests, traps, and props, with deeper floors boosting higher-rarity odds.
- **Rarity-capped Item Mastery (`D-060`).** Every weapon, spell, shield, armor piece and accessory has its own **mastery
  level** stored on the item, capped by rarity (`common`: Lv 3 / 1–2 abilities, `uncommon`: Lv 5 / 2–3, `rare`: Lv 7 / 3–4,
  `epic`: Lv 9 / 4–5, `legendary`: Lv 10 / 5–6; all start with a Level 1 ability). Using it earns mastery XP (hits, kills,
  blocks, hits taken while worn, casts). Each level makes the item's core stats stronger, and **specific levels unlock new
  abilities that belong to that item's own mastery track**, so two items of the same kind grow in different directions. Examples:
  - Chain Spark learns **Arc Chain** at 2 and keeps jumping to more enemies (2, 3, 5, 8 targets).
  - Firebolt learns **Ignite**, then **Detonation** (explodes), then **Splinter** (casts three).
  - One-handed swords learn **Lunge** (power-attack dash) and **Cross Guard** (dual-wield block).
  - The recurve bow learns **Quick Draw**, then **Hunter's Focus** (time slows at full draw), then **Volley** and **Piercing**.
  - Shields learn **Shield Bash**, **Riposte** and a **Spiked Rim**; armor learns **Second Wind**, **Thorns**, **Fleet Foot**…
- **Curiosity is the hook.** The item card shows the mastery level, XP bar and every ability discovered so far; the
  abilities still ahead are shown only as **"Lv N ???"**, so the player has to invest time in a weapon or spell to find
  out what it becomes. Unlocking one triggers a "NEW ABILITY" announcement.
- **Data-driven.** The ability library (≈45 mechanics with parameters) lives in `game/data/mastery.json`; each item's
  track lives with the item in `items.json`. Adding a new item = picking a unique path through the library.

### 6.2 Unique Enemies, Levels & the Bestiary (`D-049`, `D-052`)

- **Every enemy type is unique**: its own look (rig, scale, colour wash, weapon), behaviour and **trait** — the Draugr
  Shieldwarden blocks frontal hits, Frostbound Draugr slow you, the Bone Hexer throws slowing hexes, the Goblin
  Bomb-Tosser lobs fire pots, the Barrow Wight drains life and regenerates, the Draugr Deathlord slams the ground every
  third blow, the Goblin Hollerer's war cry makes everything nearby faster and stronger.
- **Levels with a range per type.** Each type has its own minimum and maximum level (`level_min`/`level_max`). Each
  floor covers a level band (floor 1 = 1–4, floor 2 = 4–7, …); a type only spawns where its range overlaps the band,
  and each spawn rolls a level inside the overlap (deterministically, same seed = same levels, `D-039`). Stats scale
  with level and the level is shown over the enemy's head. Deeper floors therefore keep **introducing new creatures**.
- **Abilities upgrade as enemies level up (`D-052`).** Higher-level enemies do not just gain larger HP and damage
  numbers — their unique abilities evolve at level breakpoints (e.g., spellcasters roll more and stronger spells,
  splitters split more times or deeper, flying exploders gain wider blasts or hazard pools, tanks gain stronger guard
  stances, skirmishers gain multi-throws or slowing rocks).
- **Bestiary** (Character menu → Bestiary): every creature has a page, unknown ones are "???" silhouettes. Knowledge
  fills in as you hunt: **sighted** (name, look, lore) → **slain** (stats per level seen, abilities) → **studied** after
  5 kills (weakness, full level range). The Bestiary is crawler knowledge: it is saved and never rolled back by a floor
  reset.

### 6.3 Unified Entity Stats & Living Content Catalog (`D-051`, `D-052`)

- **Built for constant creative expansion (`D-051`):** A core identity of the game is continuously building unique
  spells, enemies, weapons, summons, and arenas. Every living entity (player, enemy, boss, or player-summoned ally)
  shares one extensible **Entity Stat & Resistance Sheet** — covering vitals/resources (`max_health`, `max_magicka`/mana,
  `max_stamina`), defense (`armor`, `evasion_chance`), elemental/status resistances (`fire_res`, `frost_res`,
  `shock_res`, `poison_res`, `bleed_res`, `arcane_res`, `paralysis_res`, `stun_res`, `slow_res`), physics/control
  (`knockback_res`, `poise`, `mass`, `power_tier`), and mobility/offense (`move_speed`, `attack_speed`, `cast_speed`).
- **Clean ability scaling:** Abilities like **Paralyze** or **Knockback** resolve directly against target resistance
  and `power_tier`, so leveling up an item naturally lets it affect stronger, heavier, and more resistant foes without
  hardcoded per-enemy exceptions.
- **Living Content Catalog:** See [`docs/CONTENT_CATALOG.md`](CONTENT_CATALOG.md) for the full planned & brainstormed
  roster of enemies (Flying Exploder, Death Splitter, Adaptive Random-Spell Caster, Tanky Juggernaut, Rock-Throwing
  Goblin Skirmisher), Magic Tomes (Seeking Missiles, Summoning Tomes, Poison Ground, Haste, Paralyze), Weapons (Swift
  Blade, Knockback 2H Axe), and arena/hazard concepts.

### 6.4 FB-022 Round: Swarms, Champions, Power-Scale Knobs, Hotbar, Stacks & Area Maps (`D-057`)

- **More, weaker enemies:** floors hold ~2.5× as many enemies (1,100+ on Floor 1), each with ~0.42× health, ~0.55× damage
  and ~0.45× xp/gold, so a floor is busier but the total threat stays scaled. Enemies are only created within 100 m of
  the player (spawn records are seeded per index, so the same floor still replays identically, `D-039`).
- **Champion lairs — boss fights are common:** about one combat room in twelve (at least six per floor, away from the
  entrance) is a lair guarded by a **champion**: a promoted regular type with a goofy title (*"Grumbold the
  Gravy-Stained"* style), 7× health, 1.7× damage, bigger, gold-tinted with a glow, roars on engaging, enrages at 40 %
  health, shows the big boss health bar ("CHAMPION"), always drops loot and guards a lair chest. Tuned in
  `data/balance.json` → `champions`.
- **Power-scale knobs:** three multiplying layers, all 1.0 = tuned default: global knobs in `data/balance.json`
  (`enemy_health`, `enemy_damage`, `enemy_count`, `enemy_xp`, `enemy_gold`, `boss_*`, `champion_*`, `item_power`,
  `consumable_power`, `vendor_prices`), each floor's `power_scale` in `world.json`, and every enemy's and item's own
  `power_scale`. Item knobs apply live, even to gear already in the bag.
- **Hotbar:** keys **1–8** (rebindable). Weapons, spells and shields equip into their hand; consumables use one from the
  stack. Assign from the inventory (Hotbar 1–8 buttons on the item, or hover an item and press 1–8). Starts filled with
  the starting kit and potions; saved with the game and the floor snapshot.
- **Stacks & ingredients:** consumables and the new **ingredients** stack (one bag entry with a count). New: Verdant
  Stamina Tonic, Draught of Swiftness (+25 % speed), Ironbark Tonic (+25 armor), Troll-Fat Salve (regeneration), and
  edible ingredients Glowcap Mushroom, Grave Moss, Bat-Wing Jerky and Goblin Toenail (makes you Queasy). Crates and urns
  often hold a few. Vendors sell staples by the stack and buy/sell any quantity (box with −, +, Max).
- **Status-effect list:** every temporary effect on the player (potion buffs, Aegis Ward, Renewal, Frenzy stacks,
  Riposte, Slowed/Queasy debuffs, Second Wind recharge) is listed bottom-left with a countdown and draining bar.
- **Damage over time you can see:** burning enemies are on fire, bleeding ones drip blood, poisoned ones wear a toxic
  haze, chilled ones a frost aura; ticks pop up as numbers in the status colour; a status line under the name reads
  e.g. *BURNING 3s · POISONED ×2 5s*; the health bar takes the colour of the worst damage-over-time.
- **Mastery made readable:** every gear item has a **level-1 ability** (a weaker starter version that later levels
  upgrade, or its own signature trait), and its card explains **how to level it** ("land a hit (+1 xp) or finish an
  enemy (+5 xp) … 12 xp to mastery 2 (about 12 hits or 3 kills)").
- **Safe-room area maps:** each safe room's wall map inks every corridor and room within 40 tiles onto your map and marks
  treasure chests, champion lairs and landmarks inside that radius. Entering reads it automatically; the map board opens
  your map. Looted chests and slain champions are crossed off.
- **Straight-walking enemies & exact health bars:** enemies string-pull their tile paths and walk straight at you across
  open ground (kiting archers and fleeing are character behaviour, unchanged); enemy health bars drain exactly.
- **Own identity:** no TV show, audience, sponsors, Syndicate or achievements. The dungeon is grim and ancient, its
  monsters are goofy, and the announcer is the smug, bored voice of the dungeon itself.

---

## 7. Art & Audio Direction (`D-005`, `D-025`, `D-026`)

- **100% Original Blender 3D Art:** Modular Nordic-ruin dungeon kit (snappable floors, walls, arches, pillars, stairs, doors, torches, chests, props), characters, weapons, and enemies authored in Blender and exported as `.glb`.
- **Clean Stylized Dark Fantasy:** Crisp silhouettes, smooth-shaded/beveled geometry, atmospheric torchlight and shadows, and procedural/painted textures—built to iterate fast in v0.1 while leaving clean room to increase visual richness over time.
- **100% Open-Source Audio:** Procedural/synthesized SFX (steel clashes, spells, footsteps, chest latches, dungeon ambience) paired with punchy on-screen Dungeon AI notification banners.

---

## 8. Presentation, UI & Quality of Life (`D-031`–`D-035`)

- **Look:** stylized dark fantasy at an "AA-indie" bar — hand-cut stone architecture, warm torch pools against cool shadow, volumetric haze, detailed props, rigged and animated characters; Low → Ultra graphics presets.
- **Front end:** title screen over a live 3D hall (Continue with save summary, New Expedition, Settings, Credits, Quit).
- **HUD:** compass with landmark icons, floor clock, slim vitals that fade when full, contextual crosshair (hit marker, block, bow-draw ring), key-cap interaction prompts, equipped-item icons, dungeon announcement cards, loot toasts, area titles, level-up banner, boss bar with enrage state, tutorial card.
- **Menus:** pause (with run status, controls reference and settings), inventory (3D portrait, equipment slots, filter/sort grid, comparisons, unequip, off-hand right-click), Skills & Perks, vendor (comparisons, sell-all-common), dungeon map with fog of war (`M`), death/collapse screen.
- **Comfort & accessibility:** FOV, render scale/FSR, brightness, audio channels, mouse sensitivity/invert, full key rebinding, head bob & camera shake sliders, damage numbers, enemy health bar mode, crosshair style, HUD opacity, UI scale, colour-blind filters, announcement text, reduced flashing; confirmations before destructive actions.

