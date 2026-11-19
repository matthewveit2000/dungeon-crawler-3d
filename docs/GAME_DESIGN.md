# Game Design Document (GDD)

> **Status:** `Pre-Production Blueprint — Awaiting Final Sign-Off`  
> **North Star:** **Feels like Skyrim**, fused with the dark-humor multi-floor dungeon premise of ***Dungeon Crawler Carl***.  
> **Decision References:** `D-001` through `D-027` in [`docs/DECISION_LOG.md`](DECISION_LOG.md).

---

## 1. Core Experience & Tone

- **Skyrim North Star (`D-002`):** Immersive 3D exploration, weighty tactile combat, environmental discovery, interactive looting, and build freedom.
- **"Dark Baseline, Goofy Payload" (`D-023`):** The dungeon itself looks and feels grim, ancient, and dangerous—flickering torchlight, cold stone corridors, looming Nordic-style ruins, and lethal monsters. Overlaid on that serious foundation is a **snarky Dungeon AI** that delivers sarcastic system announcements, absurd achievement popups, and ridiculous **"Sponsored / Mythic"** loot descriptions.

---

## 2. Camera & Controls (`D-012`, `D-016`)

- **First-Person Primary + Third-Person Toggle:** Play primarily in first-person with an instant toggle to over-the-shoulder third-person (just like Skyrim).
- **Top Compass Bar:** Shows directional headings and reveals nearby landmarks (Safe Rooms, Boss Doors, Vaults, Staircases) as the player approaches them.
- **Classic Menu Pause:** Opening Inventory, Character/Skills, Map, or Vendor screens freezes world simulation and the floor collapse timer cleanly.
- **Interactive World Objects:** Aim at and interact with chests, enemy bodies, crates, urns, levers, traps, vendors, quest boards, and staircases.

---

## 3. Core Floor Loop & Stakes (`D-006`, `D-007`, `D-008`, `D-014`, `D-017`, `D-018`)

1. **Enter Floor (Snapshot Taken):** Upon entering a floor, the game records a **Floor-Entry Snapshot** of the player's character level, skills, perks, gold, and equipped/carried gear.
2. **Explore Under the 5-Day Clock:** Each floor has a **5 in-game day** collapse countdown (~30 real-time minutes per in-game day = ~2.5 hours per floor initially; fully data-driven).
3. **Save-and-Quit Anytime:** Players can exit at any time; the game auto-saves exact position, floor state, and remaining timer so long floors can span multiple play sessions.
4. **Collapse or Combat Death = Floor-Entry Reset:** If the 5-day timer hits zero OR the player dies in combat, the player resets to the **Floor-Entry Snapshot** at the floor entrance with a fresh 5-day timer and a freshly reset floor. No full-run permadeath.
5. **Unknown Descent:** Finding the hidden exit staircase lets the player descend to the next floor with **no staircase previews**—what awaits below is always a surprise.

---

## 4. World Structure (`D-015`, `D-021`, `D-022`)

- **Massive Interconnected Dungeon Labyrinth:** Each floor is a sprawling procedural labyrinth of modular rooms, vaulted halls, winding corridors, bridges, and side chambers (inspired by massive Skyrim Nordic ruins).
- **Deterministic Seeded Generation:** Every floor layout is generated from a seed so any floor can be reproduced identically for automated testing and bug reports.
- **Discoverable Safe Rooms & Underground Towns:** Hidden pockets scattered in the labyrinth where pursuing enemies immediately break off and cannot enter. Contain **Vendors**, **Quest Boards**, and **Stash/Rest** spots.
- **Optional Sealed Boss Arenas + Treasure Vaults:** Crossing a Boss Arena threshold seals the exit behind you until the boss falls; defeating the boss unlocks an adjoining high-tier **Treasure Vault**. Players constantly weigh risk and remaining time against big rewards.
- **Hidden Exit Staircase:** Placed deep in the labyrinth to reward thorough exploration.

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
