# Future Ideas Vault & Backlog

> **Status:** `Living Brainstorm Vault — Append & Refine (D-053)`  
> **Purpose:** A zero-friction home for raw ideas ("word-vomit" dumps) for future features, items, spells, enemies, and systems so **nothing is ever lost**, and every idea can be expanded, combined, and eventually promoted into the game.  
> **Related Docs:** [`docs/CONTENT_CATALOG.md`](CONTENT_CATALOG.md) (fleshed-out specs & mastery tracks), [`docs/GAME_DESIGN.md`](GAME_DESIGN.md) (locked core rules), [`docs/USER_FEEDBACK_LOG.md`](USER_FEEDBACK_LOG.md) (verbatim User requests).

---

## How This Vault Works

1. **Dump ideas freely:** Anytime you think of something cool — one word ("Glock") or a whole paragraph — it gets logged here with a permanent **`IDEA-###`** ID and filed into a category.
2. **No accidental implementation:** Ideas live here strictly as **future concepts** until you explicitly ask to build them.
3. **Lifecycle Statuses:**
   - `Raw` — Captured as a seed idea; ready to brainstorm and expand later.
   - `Fleshed Out` — Detailed mechanics, stat hooks, and mastery/level scaling written up in [`docs/CONTENT_CATALOG.md`](CONTENT_CATALOG.md) or [`docs/GAME_DESIGN.md`](GAME_DESIGN.md).
   - `Scheduled` — Picked up for an upcoming milestone in [`docs/ROADMAP.md`](ROADMAP.md).
   - `Implemented` — Built and verified in the game.
   - `Shelved` — Intentionally set aside (kept with a brief reason so we don't re-debate it).

---

## 1. Spells & Magic Tomes

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| **IDEA-001** | **Slow Spell** | Spell that slows enemies (movement and/or attack speed), scaling against `slow_res` with mastery (stronger slow, longer duration, AoE/chain). | `FB-019` | `Fleshed Out` |
| **IDEA-003** | **Glue Floor Spell** | Spell that coats an area of the floor in sticky glue, heavily slowing or rooting enemies that step on it (synergizes with Poison Ground, Bombs, and kiting). | `FB-019` | `Fleshed Out` |
| **IDEA-006** | **Temporary Wall Spell** | Spell that erects a temporary physical wall/barricade to block enemies, flying exploders, and incoming projectiles or create choke points. | `FB-019` | `Fleshed Out` |
| **IDEA-012** | **One-Way Spell/Arrow Shield** | Spell that erects a magical shield/barrier in front of the player that **blocks enemy attacks and projectiles** while letting **only the player's spells and arrows pass through**. | `FB-019` | `Fleshed Out` |
| *Catalog* | *Seeking Missiles, Summoning Tomes, Poison Ground, Haste, Paralyze* | Full mastery specs already documented in [`CONTENT_CATALOG.md` §3](CONTENT_CATALOG.md#3-magic-tomes--spells-d-052). | `FB-018` | `Fleshed Out` |

---

## 2. Weapons, Shields & Combat Moves

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| **IDEA-002** | **Variety of Effect Bows** | Multiple distinct bows that apply different effects to enemies on hit (e.g., poison, burn, frost/slow, shock, bleed, armor sunder, knockback, paralysis). | `FB-019` | `Fleshed Out` |
| **IDEA-009** | **Scaling Shield Bash Attack** | Active shield bash move whose power grows as the shield levels up: more damage, pushes the enemy back further (vs. `knockback_res`), lunges/moves the player further forward, heavier stagger/stun. | `FB-019` | `Fleshed Out` |
| **IDEA-010** | **Glock** | Modern semi-auto handgun dropped straight into a dark-fantasy dungeon — peak "Dark Baseline, Goofy Payload" (`D-023`) rare unique weapon. | `FB-019` | `Fleshed Out` |
| *Catalog* | *Swift Blade (1H launch sword), Titanbreaker Greataxe (2H knockback axe)* | Full mastery specs already documented in [`CONTENT_CATALOG.md` §4](CONTENT_CATALOG.md#4-weapons-armor--accessories-d-052). | `FB-018` | `Fleshed Out` |

---

## 3. Consumables, Bombs & Crafting

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| **IDEA-004** | **Variety of Bombs** | Throwable bombs with distinct tactical effects (frag/explosive, fire/incendiary, poison cloud, glue/tar bomb, flash/stun, frost, concussion knockback). | `FB-019` | `Fleshed Out` |
| **IDEA-005** | **Crafting System (Bombs & Potions)** | Future crafting system (e.g., Safe Room alchemy bench / portable kit) where players combine dungeon reagents, monster parts, and vendor supplies to craft **bombs** and **potions**. | `FB-019` | `Raw` |

---

## 4. Active Abilities & Character Powers

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| **IDEA-007** | **Active Ability System** | Dedicated active abilities (separate from equipped hand items, triggered via ability hotkeys with cooldown/resource costs): e.g., **Enrage** (damage/speed/poise boost), **Radial Fling / Repulse** (flings all nearby enemies backward vs. `knockback_res`), **Brief Invulnerability** (short immunity window), plus room for many more unlockable powers. | `FB-019` | `Fleshed Out` |

---

## 5. Enemies & Bosses

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| *Catalog* | *Flying Exploder, Death Splitter, Adaptive Random-Spell Caster, Tanky Juggernaut, Rock-Throwing Goblin Skirmisher + Enemy Ability Scaling* | Full ability-tier scaling specs documented in [`CONTENT_CATALOG.md` §2](CONTENT_CATALOG.md#2-enemies--ability-scaling-progression-d-052). | `FB-018` | `Fleshed Out` |

---

## 6. Floor Themes, World & Arenas

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| **IDEA-008** | **Floor Themes** | Every floor has a distinct **Theme** (e.g., Nordic Barrow, Fungal Poison Cavern, Molten Forge, Goblin Scrapyard, Frozen Crypt, Arcane Ruin) that drives the **visual vibe/lighting**, **enemy roster**, **themed loot pool**, **room hazards**, and **Dungeon AI commentary** — while preserving `D-008` (no staircase previews before descending). | `FB-019` | `Fleshed Out` |

---

## 7. Mounts & Companions

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| **IDEA-013** | **Wacky Mounts & Companions** | Dedicated system for **companions** and **mounts** leaning into the game's goofy personality — e.g., a **flying bat companion that smacks enemies**, plus other absurd dungeon pets/mounts that fight, buff, distract, carry loot, or boost traversal across vast floors (`D-044`). | `FB-019` | `Fleshed Out` |

---

## 8. Rarity, Scarcity & Economy

| ID | Idea | Summary & Notes | Source | Status |
|---|---|---|---|---|
| **IDEA-011** | **Unified Rarity & Scarcity System (Items, Enemies, etc.)** | Organize **all items, enemies, etc.** into a unified rarity framework (`Common` → `Uncommon` → `Rare` → `Epic` → `Legendary`, `D-048`) where rarity directly drives **spawn/drop rates** and **vendor prices**. Unique/special items (like the Glock or exotic tomes) MUST have **low drop rates and high prices** so finding or affording one stays thrilling instead of boring or overwhelming. | `FB-019` | `Fleshed Out` |

---

## 9. Raw Brain-Dump Inbox

*(Drop uncategorized ideas here during fast brainstorming sessions, then sort them into the numbered sections above with the next `IDEA-###` ID.)*

- *(Empty — all ideas from `FB-018` and `FB-019` are filed above.)*
