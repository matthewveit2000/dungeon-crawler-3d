# Content Catalog & Design Brainstorm

> **Status:** `Living Design Catalog (D-051, D-052, D-054)`  
> **Scope:** Planned and brainstormed enemies, magic tomes, weapons, gear, abilities, floor themes, companions, arenas, and the unified entity stat system that powers them.  
> **Related Docs:** [`docs/IDEAS_BACKLOG.md`](IDEAS_BACKLOG.md) (raw idea vault & status tracker), [`docs/GAME_DESIGN.md`](GAME_DESIGN.md), [`docs/ARCHITECTURE.md`](ARCHITECTURE.md), [`docs/DECISION_LOG.md`](DECISION_LOG.md), [`docs/USER_FEEDBACK_LOG.md`](USER_FEEDBACK_LOG.md).

Entries are tagged so it is always clear what is locked in vs. open for discussion:
- **`[User-Requested — Planned]`**: Explicitly requested by the Product Owner (`FB-018`, `FB-019`) as future design targets.
- **`[Brainstorm — Open]`**: Creative proposals to riff on, modify, or cut before implementation.

---

## 1. Unified Entity Stat & Resistance Sheet (`D-051`)

A core pillar of `dungeon-crawler-3d` is **continuous content expansion** — constantly adding unique spells, enemies, weapons, summons, and arenas without rewriting core combat code. To make that possible, **every living entity** (the player, every enemy, every boss, and every player-summoned ally) shares one extensible, data-driven **Entity Stat Sheet** with modifiers (base + level scaling + gear + active buffs/debuffs).

### 1.1 Core Stat Categories

| Category | Stats | How Abilities Use Them |
|---|---|---|
| **Vitals & Resources** | `max_health`, `health_regen`, `max_magicka` (mana), `magicka_regen`, `max_stamina`, `stamina_regen` | Spells (both player and enemy casters) spend `magicka`; melee, blocking, sprinting, and enemy dashes/heavy moves spend `stamina`. |
| **Physical Defense** | `armor`, `block_mitigation`, `evasion_chance` | Mitigates physical hits; armor-shredding abilities (`sunder`, acid pools) apply negative modifiers to `armor`. |
| **Elemental Resistances** | `fire_res`, `frost_res`, `shock_res`, `poison_res`, `bleed_res`, `arcane_res` | Fractional mitigation (`-1.0` = double damage / vulnerability, `0.0` = neutral, `0.5` = 50% reduced, `1.0` = immune). Lets enemies have meaningful strengths and Bestiary weaknesses. |
| **Control & Physics Resistances** | `knockback_res`, `paralysis_res`, `stun_res`, `slow_res`, `poise`, `mass` | Governs whether knockback, paralysis, stuns, and slows land — and how strong/long they are. |
| **Power & Scale** | `level`, `power_tier` (`minion`, `standard`, `elite`, `miniboss`, `boss`) | Cleanly gates high-impact effects (like Paralysis or heavy Knockback) without hardcoded per-enemy `if` checks. |
| **Offense & Mobility** | `move_speed`, `sprint_mult`, `attack_speed`, `cast_speed`, `crit_chance`, `crit_mult`, `ability_power`, `cooldown_reduction` | Driven by Haste buffs, Swift Blade launches, berserk traits, and chill/slow debuffs. |

### 1.2 Power vs. Resistance Resolution (No Hardcoded Exceptions)

Whenever an ability applies knockback, paralysis, stun, or elemental damage, combat resolves it through one shared formula:

- **Elemental & Poison Damage:** `final_damage = raw_damage * (1.0 - clamp(target.<element>_res, -1.0, 1.0))`
- **Knockback:** `effective_impulse = max(0.0, ability.knockback_force - target.knockback_res) / target.mass`
  - If `ability.knockback_power < target.knockback_res`, the target resists (or only flinches). Leveling up a weapon like the **Knockback 2H Axe** raises both `knockback_force` and `knockback_power`, naturally letting it launch heavier, higher-tier enemies as mastery grows.
- **Paralysis / Crowd Control:**
  - Checks `ability.control_power` against `target.paralysis_res` (which scales with `power_tier` and enemy `level`).
  - Effective duration scales down smoothly with partial resistance (`duration * resistance_factor`) and fails with a clear *"RESISTED"* feedback popup if `control_power` is too low.
  - Leveling up **Paralyze** increases both `base_duration` and `control_power`, smoothly unlocking stronger enemies without special-case boss code.

---

## 2. Enemies & Ability-Scaling Progression (`D-052`)

### 2.1 Core Rule: Enemy Abilities Upgrade With Level

Enemies do not merely gain bigger HP and damage bars as they level up. Each enemy type defines **Ability Scaling Tiers** tied to its spawned `level` (e.g., Tier I at `level_min`, Tier II at +3 levels, Tier III at +6 levels, Tier IV at high floors):
- Upgraded abilities add new mechanics, stronger spell ranks, higher split counts, wider blast radii, or secondary status effects.
- The **Bestiary** (`D-049`) records new ability tiers as the player encounters higher-level variants.

---

### 2.2 Planned Enemies `[User-Requested — Planned]`

#### 1. Cinder Wisp / Blight Drone — *Flying Exploder*
- **Role:** Aerial rusher / area-denial threat that punishes tunnel vision.
- **Core Behavior:** Hovers and flies directly toward the player (bypassing ground clutter), emitting a rising pitch whine and glowing brighter as it closes. Detonates on impact (or within trigger radius), dealing heavy burst damage + knockback and destroying itself.
- **Key Stats:** Low HP, low `armor`, high `move_speed`, low `knockback_res` (can be swatted/shot back before it reaches you), high `fire_res` (or `poison_res` for blight variant).
- **Counterplay:** Shoot or spell it out of the air, block the blast with a shield, or knock it back into other enemies so its explosion damages them too.
- **Level-Up Ability Scaling:**
  - **Tier I (Low Lv):** Direct flight, medium explosion radius, single fire/impact burst.
  - **Tier II (Mid Lv):** Faster dive-acceleration when within 8 m; larger blast radius; applies **Burn** (or **Poison**) on hit.
  - **Tier III (High Lv):** Leaves a lingering burning/toxic hazard zone on detonation; zig-zags slightly while approaching to dodge lazy aim.
  - **Tier IV (Apex Lv):** Detonation fires 3–4 mini shrapnel embers outward and triggers a chain-detonation if another exploder is caught in the blast.

#### 2. Mire Ooze / Marrow Splitter — *Death Splitter*
- **Role:** Swarming attrition enemy that turns sloppy single-target kills into a crowd.
- **Core Behavior:** Lurches toward the player with sticky melee strikes. Upon death, it **splits** into smaller, faster child copies that immediately join the fight.
- **Key Stats:** Moderate HP, high `poison_res`, low `fire_res` / `shock_res` (elemental AoE counterplay), low `knockback_res` on smaller children.
- **Counterplay:** Cleave/whirlwind 2H weapons, Poison Ground (if non-immune variant) or Fire Detonation, or kiting children into a tight pack.
- **Level-Up Ability Scaling:**
  - **Tier I (Low Lv):** Splits once on death into **2 smaller copies** (split depth = 1).
  - **Tier II (Mid Lv):** Splits into **3 copies**, or **2 copies that each split once more** (split depth = 2 → up to 4 tiny copies).
  - **Tier III (High Lv):** Each split bursts a small splatter puddle at the death spot; final-generation mini-copies gain a brief speed surge.
  - **Tier IV (Apex Lv):** Splits into **3 copies with depth 2**, and if two living splits stay near each other for too long they can **re-merge** to heal.

#### 3. Runebound Arcanist — *Adaptive Random-Spell Caster*
- **Role:** Tactical ranged wildcard — no two Arcanists play quite the same.
- **Core Behavior:** On spawn, rolls **2+ random spells** (deterministically from the enemy's per-spawn seed per `D-039`!) from a curated enemy spell pool (e.g., Firebolt, Frost Shard, Poison Pool, Paralyze, Arcane Ward, Minor Heal, Blink Step, Summon Imp). Uses a **Utility-Scoring AI** that inspects combat context every decision tick:
  - Has enough `magicka` and spell off cooldown?
  - **Self-preservation:** Low HP → prioritize Heal / Arcane Ward; player too close → prioritize Blink Step / Paralyze / Knockback Pulse.
  - **Offense & control:** Player at mid-range → offensive bolt; player stationary or in a choke point → Poison Pool; allies nearby and hurt → Buff/Heal ally.
  - **Fallback:** When out of `magicka`, retreats to regenerate or uses a weak staff strike.
- **Key Stats:** Moderate-low HP, high `max_magicka` & `magicka_regen`, moderate `arcane_res`, low `armor`.
- **Level-Up Ability Scaling:**
  - **Tier I (Low Lv):** Spawns with **2 random basic spells**, modest mana pool, clear cast telegraph.
  - **Tier II (Mid Lv):** Spawns with **3 random spells** (at least 1 offensive + 1 utility/control); spells cast at upgraded rank (e.g., faster bolts, wider pools).
  - **Tier III (High Lv):** Higher `magicka` & `cast_speed`; unlocks combo scoring (e.g., Paralyze → Poison Pool, or Ward → Heavy Bolt).
  - **Tier IV (Apex Lv):** Spawns with **4 spells**, including high-tier spells (multi-missile volley, summon, or blink-ambush).

#### 4. Obsidian Juggernaut — *Tanky Frontliner*
- **Role:** Immovable wall and pace-breaker that punishes button-mashing.
- **Core Behavior:** Heavy armored bruiser carrying a tower shield or greatmaul. Advances steadily, shrugs off light hits and weak crowd control, and delivers crushing telegraphed blows.
- **Key Stats:** Very high `max_health`, very high `armor`, high `knockback_res`, high `paralysis_res`, high `poise`, slow `move_speed`, vulnerable to `shock_res` / `armor` sunder / sustained `poison_res` (or elemental gaps).
- **Counterplay:** Armor-sundering weapons, elemental spells, Poison Ground while kiting, flanking behind its guard, or high-mastery Knockback / Paralyze.
- **Level-Up Ability Scaling:**
  - **Tier I (Low Lv):** Heavy armor + frontal guard stance that reduces incoming physical damage.
  - **Tier II (Mid Lv):** Periodic **Iron Brace** (briefly boosts `armor` and `knockback_res` further) + heavy slam that staggers.
  - **Tier III (High Lv):** Guard reflects a portion of blocked melee damage; slam creates a short radial shockwave.
  - **Tier IV (Apex Lv):** **Unstoppable Charge** telegraph that bulldozes through the room, forcing the player to dodge sideways or break its poise with high-mastery tools.

#### 5. Crag Goblin Skirmisher — *Rock-Throwing Kiter*
- **Role:** Annoying, nimble harassment enemy that refuses to stand and trade blows.
- **Core Behavior:** Pelts the player with thrown rocks from medium-long range. The moment the player closes inside its **panic radius** (~6–8 m), it shrieks and **sprints away rapidly** along escape paths / around corners, then turns to throw again once it re-establishes distance.
- **Key Stats:** Low HP, low `armor`, very high `move_speed` & `sprint_mult`, low `knockback_res`, low `paralysis_res`.
- **Counterplay:** **Swift Blade** lunge, **Haste** tome, **Paralyze** tome, **Seeking Missiles**, bows, or cornering it against walls.
- **Level-Up Ability Scaling:**
  - **Tier I (Low Lv):** Single thrown rock; fast flee sprint when approached.
  - **Tier II (Mid Lv):** Throws a **2-rock burst**; faster sprint cooldown and sharper cornering.
  - **Tier III (High Lv):** Mixes in **heavy concussion stones** (brief stagger/daze) or **pitch/tar rocks** (slows the player while it escapes).
  - **Tier IV (Apex Lv):** Drops a **smoke/caltrop hazard** behind itself when fleeing and coordinates with nearby goblins to scatter in different directions.

---

### 2.3 Bonus Enemy Ideas `[Brainstorm — Open]`

| Concept | Archetype | Core Gimmick | Level-Up Ability Scaling |
|---|---|---|---|
| **Bone Caller (Enemy Summoner)** | Support / Backline | Raises fragile skeleton minions from the floor; flees behind them. | Summons higher-level & more skeletons; later casts haste/frenzy on its summons. |
| **Gilded Mimic** | Ambush / Trap | Disguised as a rare chest (subtle breathing/chain tell for observant players). | Faster lunging bite; higher levels spit sticky acid or steal a small amount of gold until slain. |
| **Tether Wraith** | Debuffer / Ghost | Projects a spectral beam that drains stamina or slows the player until line-of-sight is broken. | Stronger drain; higher levels tether through thin props or split into 2 beams. |
| **Bramble Stalker** | Ambush Melee | Clings to shadows/corners and pounces with bleed claws; weak to fire. | Longer pounce, deeper bleed stacks, brief camouflage reset after retreating. |
| **Runic Turret / Obelisk** | Stationary Hazard | Anchored crystal in signature rooms that pulses elemental beams or buffs nearby mobs until shattered. | Fires sweeping beams, shields nearby enemies, or rotates elements. |

---

## 3. Magic Tomes & Spells (`D-052`)

All Magic Tomes are **one-handed equippable items** (usable in either hand — sword + tome, shield + tome, or dual-tome per `D-046`) and follow the **Item Mastery (`D-049`)** system (levels 1–10, undiscovered abilities hidden as `Lv N ???` until unlocked).

### 3.1 Planned Magic Tomes `[User-Requested — Planned]`

#### 1. Tome of Seeking Missiles
- **Core Cast:** Launches arcane projectile(s) that curve smoothly in flight to track the nearest enemy in front of the player.
- **Resource:** Moderate `magicka`; quick cast.
- **Mastery Progression (More Missiles + Unique Per-Missile Abilities):**
  - **Lv 1:** Fires **1** homing arcane missile.
  - **Lv 2:** Fires **2** missiles; improved turn radius.
  - **Lv 3:** Missile #2 becomes an **Ember Missile** (applies **Burn** DoT on hit).
  - **Lv 4:** Fires **3** missiles; Missile #3 becomes a **Frost Missile** (applies **Chill** slow).
  - **Lv 5:** Fires **4** missiles; Missile #4 becomes a **Spark Missile** (mini **Arc Chain** jump to 1 nearby enemy).
  - **Lv 7:** Fires **5** missiles; Missile #5 becomes a **Venom Missile** (applies stacking **Poison** + slight armor melt).
  - **Lv 9:** Fires **6** missiles; Missile #6 becomes a **Force Missile** (bonus **Knockback** + stagger).
  - **Lv 10 (Capstone):** **Prismatic Barrage** — if at least 3 distinct missile types hit the same target within 2 s, triggers a resonant arcane detonation.

#### 2. Tomes of Summoning (Family of Summon Tomes)
- **Core Cast:** Consumes `magicka` to summon allied creatures that fight alongside the player, draw aggro, and use the exact same unified entity stat sheet and AI framework as dungeon enemies (with an `ally` faction tag).
- **Planned Tome Variants:**
  - **Tome of Skeletal Thralls:** Balanced melee frontline skeletons (reliable blockers/fighters).
  - **Tome of Dire Hounds:** Fast pack hunters that chase down kiters like Crag Goblins.
  - **Tome of Ember Imps:** Ranged fire-spitting casters (fragile, high DPS).
  - **Tome of Stone Golems:** Slow, tanky bruisers with high `armor` and `knockback_res` (lower quantity cap, higher durability).
- **Mastery Progression (Higher Level + Higher Quantity):**
  - **Lv 1:** Summons **1** ally at base level (e.g., floor/player-anchored base level).
  - **Lv 2:** Summon level **+1**; longer active duration.
  - **Lv 3:** Max active quantity **+1** (e.g., 2 skeletons / 2 hounds).
  - **Lv 5:** Summon level **+2** (unlocks the creature's **Tier II** upgraded ability!).
  - **Lv 7:** Max active quantity **+1** (e.g., 3 skeletons / 3 hounds; 2 golems).
  - **Lv 8:** Summon level **+3**; summons inherit a portion of the player's `ability_power`.
  - **Lv 10 (Capstone):** Summon level **+4** (unlocks **Tier III** ability) + **Pack Tactics / Death Burst** (summons explode or refund mana when they fall).

#### 3. Tome of Venomous Ground (Poison Pool)
- **Core Cast:** Targets a spot on the floor (or splashes on impact) to create a persistent **toxic ground zone** that damages and poisons any enemy walking across it (mitigated by `poison_res`).
- **Mastery Progression:**
  - **Lv 1:** Small poison puddle (radius ~2.2 m, duration 5 s) dealing ticking poison damage.
  - **Lv 3:** **Spreading Mire** — larger radius (~3.2 m) and longer duration (7 s).
  - **Lv 5:** **Corrosive Bile** — enemies standing in the pool suffer **Armor Sunder** (great against Obsidian Juggernauts!).
  - **Lv 7:** **Mire Grip** — slows enemies inside the pool (checked against `slow_res`), keeping them trapped in the damage.
  - **Lv 9:** **Double Pool** — allows two active pools at once (or casts a wider lingering cloud).
  - **Lv 10 (Capstone):** **Blight Eruption** — enemies that die inside the poison pool burst, refreshing the pool's duration and spreading poison nearby.

#### 4. Tome of Haste (Fleetstep)
- **Core Cast:** Channels a burst of `magicka` to buff the player's `move_speed` for a set duration (ideal for catching Crag Goblins, escaping swarms, or beating the 5-day clock).
- **Mastery Progression:**
  - **Lv 1:** +25% `move_speed` for 6 s.
  - **Lv 3:** **Second Breath** — also boosts `stamina_regen` while active; duration → 8 s.
  - **Lv 5:** **Quicksilver Hands** — also grants +15% `attack_speed` and `cast_speed` while active.
  - **Lv 7:** **Windstride** — speed bonus → +40%, duration → 10 s, and grants immunity to minor `slow` effects.
  - **Lv 10 (Capstone):** **Blur** — grants bonus `evasion_chance` during Haste and leaves a brief speed-burst afterimage on cast.

#### 5. Tome of Paralysis
- **Core Cast:** Fires a crisp sigil bolt (or short-range hex) that locks the target completely rigid — unable to move, turn, or attack — for a duration, tested against the target's `paralysis_res` and `power_tier`.
- **Mastery Progression (Longer Duration + Higher Power Enemies Affected):**
  - **Lv 1:** Paralyzes `minion` / `standard` enemies (low `paralysis_res`) for **2.0 s**.
  - **Lv 3:** Duration → **3.0 s**; higher `control_power` (reliably locks mid-level enemies and skirmishers).
  - **Lv 5:** **Heavy Bind** — `control_power` jumps to affect high-resistance / `elite` enemies (like Obsidian Juggernauts); duration → **4.0 s**.
  - **Lv 7:** **Brittle Lock** — paralyzed enemies take +20% bonus damage from melee and ranged hits; duration → **5.0 s**.
  - **Lv 9:** **Chain Bind** — paralysis jumps to 1 additional nearby enemy within 3.5 m.
  - **Lv 10 (Capstone):** **Sovereign Stasis** — `control_power` can briefly stagger/paralyze even `miniboss` / `boss` tier foes (scaled down by boss resistance rather than flat immunity); duration → **6.0 s** on standard foes.

#### 6. Tome of Slow (`IDEA-001`)
- **Core Cast:** Launches a temporal/hex bolt that drags down the target's `move_speed` and `attack_speed` (tested against `slow_res`).
- **Mastery Progression:** Stronger slow percentage, longer duration, wider splash/chain slow, and at high mastery slows enemy projectiles or cast speed too.

#### 7. Tome of Glue Floor (`IDEA-003`)
- **Core Cast:** Coats a patch of dungeon floor in thick, sticky adhesive. Enemies stepping onto the glue are heavily slowed or briefly rooted (tested against `slow_res`), turning corridors into killboxes for Poison Ground, Bombs, and bows.
- **Mastery Progression:** Larger adhesive patch, stickier slow/root strength, longer persistence, and optional flammable/volatile glue synergy at high mastery.

#### 8. Tome of Stone Barricade — *Temporary Wall* (`IDEA-006`)
- **Core Cast:** Erects a temporary physical stone/arcane wall in front of the player that blocks enemy movement, flying exploders, and incoming projectiles — great for sealing choke points or buying breathing room.
- **Mastery Progression:** Wider/sturdier wall, longer duration, faster cast, and at high mastery shatters outward into damaging shrapnel when broken or dismissed.

#### 9. Tome of Aegis Curtain — *One-Way Front Shield* (`IDEA-012`)
- **Core Cast:** Projects a glowing magical shield plane directly in front of the player that **blocks enemy attacks, spells, and projectiles** while allowing **only the player's own spells and arrows to pass straight through**.
- **Mastery Progression:** Larger shield arc/durability, longer duration, lower magicka upkeep, and at high mastery empowers friendly arrows/spells passing through the curtain with bonus velocity or arcane damage.

---

### 3.2 Bonus Magic Tome Ideas `[Brainstorm — Open]`

| Tome | Core Effect | Fun Mastery Unlocks |
|---|---|---|
| **Tome of Blink Step** | Short forward teleport in camera direction. | Leaves a decoy/shockwave at origin; reduces cooldown; passes through enemies with a backstab crit window. |
| **Tome of Gravity Well** | Pulls enemies in an area inward toward a point. | Stronger pull (affects heavier mobs); combines brutally with Poison Ground, Glue Floor, or 2H Cleave. |
| **Tome of Reflective Ward** | Timed magical barrier that bounces enemy projectiles back. | Reflects spells at +50% damage; restores magicka on a timed parry-reflect. |
| **Tome of Corpse Detonation** | Detonates a fallen enemy body for heavy AoE damage. | Chain-detonates nearby corpses; scales with the corpse's max HP. |

---

## 4. Weapons, Shields, Bombs & Gear (`D-052`, `D-054`)

*(All blades obey standing rule `D-048`: cutting edge faces away from the player in first person at rest and while sprinting.)*

### 4.1 Planned Weapons & Shield Moves `[User-Requested — Planned]`

#### 1. Swift Blade — *One-Handed Sword*
- **Identity:** A sleek, featherweight one-handed blade built for gap-closing and high-tempo dueling (especially lethal against kiters like the Crag Goblin Skirmisher).
- **Signature Mechanic:** Triggering its attack (or power/ability swing when off cooldown) **launches the player forward** in their aim direction right before the blade swings, seamlessly carrying momentum into the strike.
- **Mastery Progression (Longer Launch + Faster Cooldown):**
  - **Lv 1:** Launches **3.5 m** forward before swinging; **6.0 s** launch cooldown.
  - **Lv 2:** Launch distance → **4.5 m**; cooldown → **5.2 s**.
  - **Lv 4:** Launch distance → **5.5 m**; cooldown → **4.4 s**; +15% bonus damage on the launch-strike.
  - **Lv 6:** **Slipstream** — brief partial `evasion_chance` during the dash; cooldown → **3.6 s**.
  - **Lv 8:** Launch distance → **7.0 m**; cooldown → **2.8 s**; passes cleanly along walls without snagging.
  - **Lv 10 (Capstone):** **Relentless Pursuit** — killing an enemy with (or within 1.5 s of) a Swift Blade launch immediately resets the launch cooldown.

#### 2. Titanbreaker Greataxe — *Two-Handed Knockback Axe*
- **Identity:** A massive, momentum-heavy two-handed battleaxe designed to send enemies flying across rooms and into walls or hazards.
- **Signature Mechanic:** Swings (especially heavy/power swings) apply strong **knockback impulse** + **poise break**, tested against the target's `knockback_res` and `mass`. Slamming a knocked-back enemy into a wall or pillar deals bonus **wall-impact damage** + brief stun.
- **Mastery Progression (Further Knockback + Affects Stronger Enemies):**
  - **Lv 1:** Moderate knockback (~3.0 m) on `minion` / `standard` enemies; modest `knockback_power`.
  - **Lv 2:** Knockback force +25% (~4.0 m); interrupts enemy attack wind-ups.
  - **Lv 4:** **Heavy Impact** — `knockback_power` overcomes mid-resistance enemies; wall-slam bonus damage unlocked.
  - **Lv 6:** Knockback force +50% (~5.5 m); **Bowling Blow** — a knocked-back enemy colliding with another enemy knocks the second enemy back too!
  - **Lv 8:** **Juggernaut Breaker** — `knockback_power` breaks through high `knockback_res` / `elite` enemies (like Obsidian Juggernauts).
  - **Lv 10 (Capstone):** **Colossus Cleave** — massive knockback (~7.5 m), wide sweeping arc, and enough `knockback_power` to visibly shove/stagger even `miniboss` and `boss` enemies.

#### 3. Variety of Effect Bows (`IDEA-002`)
- **Identity:** Distinct bows that imbue arrows with different tactical effects rather than just higher base damage (each with its own mastery track):
  - **Venomwood Bow:** Applies stacking **Poison** (tested vs. `poison_res`).
  - **Cinderstring Bow:** Ignites enemies with **Burn** and tiny ember bursts on full draw.
  - **Frostbite Recurve:** Applies **Chill / Slow** (tested vs. `slow_res` / `frost_res`).
  - **Stormcaller Longbow:** Full-draw arrows arc **Shock** to nearby targets.
  - **Barbed Bone Bow:** Inflicts deep **Bleed** and **Armor Sunder**.
  - **Concussion Greatbow:** Heavy draw arrows apply **Knockback** / brief stagger.

#### 4. Scaling Shield Bash Attack (`IDEA-009`)
- **Identity:** An active offensive **Shield Bash** attack available while wielding a shield (e.g., attacking while blocking or triggering the shield's active strike).
- **Mastery Progression:** As the shield levels up, the bash scales across multiple axes depending on the shield's identity:
  - Higher **bash damage** and **stagger/stun duration**.
  - Stronger **enemy pushback** (scaling `knockback_force` & `knockback_power` vs. `knockback_res`).
  - Further **forward player lunge/rush** into the bash, letting shield-bearers close distance and slam enemies into walls or hazards.

#### 5. The Glock (`IDEA-010`) — *Rare Goofy Payload Weapon*
- **Identity:** Literally a modern semi-automatic handgun dropped into an ancient dark-fantasy dungeon — pure "Dark Baseline, Goofy Payload" (`D-023`) energy.
- **Rarity & Feel:** High rarity (`Epic` / `Legendary`), **very low drop rate and very high vendor price** (`IDEA-011`), crisp snappy semi-auto firing, reload/magicka-ammo rhythm, and snarky Dungeon AI commentary on pickup.
- **Mastery Ideas:** Faster reload, hollow-point bleed/armor-piercing rounds, extended mag, brief hip-fire rapid burst.

---

### 4.2 Bonus Item & Gear Ideas `[Brainstorm — Open]`

| Item | Slot / Type | Core Gimmick | Mastery Direction |
|---|---|---|---|
| **Chain-Hook Spear** | 2H Polearm | Power attack throws a tethered spearhead that **yanks** a distant enemy to you (inverse of Titanbreaker!). | Longer range, works on heavier enemies, applies bleed on yank. |
| **Returning Hatchet** | 1H Axe | Normal melee in close; power attack throws it spinning forward and boomerangs back to your hand. | Pierces targets on return, faster throw, ignites at high mastery. |
| **Vampiric Twin Fangs** | 1H Dagger | Ultra-fast strikes that build a blood-meter; dual-wielding two amplifies lifesteal. | Higher lifesteal, bleed stacks, attack speed frenzy. |
| **Ring of Volatile Momentum** | Ring | Moving fast (Haste, Swift Blade launch, sprinting) charges static energy discharged on your next hit. | Higher charge cap, shock AoE discharge, faster charge rate. |
| **Alchemist's Belt / Cloak** | Armor / Accessory | Boosts `poison_res` and extends the duration of all ground hazards & buffs. | Adds immunity to your own hazards, drops a free poison puddle when hit below 30% HP. |

---

### 4.3 Bombs & Future Crafting System (`IDEA-004`, `IDEA-005`) `[User-Requested — Planned]`

- **Variety of Throwable Bombs (`IDEA-004`):** Consumable thrown explosives with distinct effects:
  - **Frag / Blast Bomb:** High physical burst + shrapnel.
  - **Firebomb / Pitch Flask:** Ignites a burning floor zone + Burn DoT.
  - **Venom Bomb:** Bursts into a temporary **Poison Ground** cloud.
  - **Glue / Tar Bomb:** Coats the impact zone in sticky glue (slows/roots enemies).
  - **Flash / Concussion Bomb:** Blinds/stuns and applies radial knockback.
  - **Frost Bomb:** Chills/freezes enemies in the blast radius.
- **Crafting System (`IDEA-005`):** Future crafting system (e.g., Alchemy / Workbench in Safe Rooms or portable kit) where **bombs and potions** are crafted from dungeon-foraged reagents, monster drops, and vendor components — giving extra value to exploration and enemy hunting.

---

## 5. Arenas, Room Hazards & Environmental Mechanics `[Brainstorm — Open]`

Because unique arenas and hazards multiply the fun of unique enemies and abilities (e.g., knocking a Juggernaut into a spike pit, luring Exploders near oil barrels, or blinking across collapsing floors), future handcrafted setpieces (`D-029`) can draw from these modular mechanics:

- **Oil & Brazier Rooms:** Flammable oil slicks on the floor that ignite into raging fire zones when hit by any fire spell, torch, or Cinder Wisp explosion.
- **Spike Pits & Wall Grates:** Environmental kill/damage zones that reward **Titanbreaker Greataxe** knockback, **Shield Bash**, and **Gravity Well** positioning.
- **Crumbling Bridge / Collapsing Tile Arenas:** Boss or elite chambers where specific floor slabs crack and drop after being stepped on, rewarding **Haste**, **Swift Blade**, and **Blink Step**.
- **Runic Pylon Arenas:** Boss rooms with 3–4 destructible pylons that grant the boss extra `armor`, `fire_res`, or `magicka_regen` until shattered.
- **Choke-Point Gauntlets:** Narrow pillar halls ideal for **Poison Ground**, **Glue Floor**, **Stone Barricade**, and **Summon** frontlines.
- **Dungeon Whim Rooms:** Rare marked chambers where the bored voice of the dungeon announces a goofy room-wide modifier (e.g., *"Low Gravity Hour: +100% Knockback!"* or *"Floor Is Literally Lava"*).

---

## 6. Active Ability System (`IDEA-007`) `[User-Requested — Planned]`

Separate from equipped hand weapons and magic tomes, the player will have an **Active Ability System** — slotted character/skill powers triggered via dedicated hotkeys on cooldown (and/or stamina/magicka cost):

- **Enrage / Berserk:** Temporarily surges damage, `attack_speed`, `move_speed`, and `poise` / `knockback_res` (with optional visual screen-edge fury and high-risk/high-reward flavor).
- **Shockwave Fling / Repulse:** Unleashes a radial burst around the player that **flings all nearby enemies backward** (resolved against each enemy's `knockback_res` and `mass`, great when surrounded by Splitters or Exploders).
- **Brief Invulnerability (Aegis / Phase):** Makes the player completely invulnerable to damage for a short emergency window (e.g., 2–3 s) on a long cooldown.
- **Extensibility (`D-051`):** Built as a data-driven registry so future perks, class unlocks, or floor rewards can add many more active abilities cleanly.

---

## 7. Floor Themes (`IDEA-008`) `[User-Requested — Planned]`

Each dungeon floor has a distinct **Theme** that shapes the entire experience of that floor — **visual vibe & lighting**, **enemy roster**, **themed loot & reagents**, **room hazards/setpieces**, and **Dungeon AI commentary** — while strictly keeping `D-008` (**no staircase previews**, so descending to a new floor is always a surprise).

- *Example Future Theme Directions:*
  - **Nordic Barrow Crypt** (current Floor 1 baseline: cold ashlar stone, warm torches, draugr, bone archers, Nordic steel)
  - **Fungal / Mire Caverns** (bioluminescent spores, Mire Ooze splitters, toxic pools, poison/alchemy loot)
  - **Molten Iron Forge** (lava grates, Cinder Wisps, Obsidian Juggernauts, fire/heavy-metal gear)
  - **Goblin Scrapyard** (rickety scaffolding, Crag Goblin skirmishers, bomb-tossers, wacky out-of-place loot like the Glock)
  - **Frozen Catacombs** (ice-slick floors, frostbound undead, chill/shatter gear)
  - **Arcane Observatory** (floating runes, Runebound Arcanists, spell tomes & mana relics)

---

## 8. Unified Rarity & Scarcity System (`IDEA-011`) `[User-Requested — Planned]`

To keep unique, wild items (like the **Glock**, exotic tomes, or signature weapons) feeling genuinely special rather than boring or overwhelming, **all items, enemies, etc.** will be organized under one unified **Rarity System** (`Common` → `Uncommon` → `Rare` → `Epic` → `Legendary`, `D-048`):

- **Rarity drives scarcity & economy:**
  - **Items:** Higher rarity = dramatically **lower drop rate** and **higher vendor price** (making finding one in a vault or saving gold for one at a Safe Room Vendor a memorable milestone).
  - **Enemies:** Rarity/tier tags drive **spawn weight**, elite/rare encounter frequency, XP/gold payouts, and rare crafting/loot drops.
- **Preserves `D-049` philosophy:** Higher rarities are never "the same sword with +10% numbers" — they are genuinely rarer, weirder, more unique discoveries whose low drop rates keep the game exciting over long runs.

---

## 9. Wacky Mounts & Companions (`IDEA-013`) `[User-Requested — Planned]`

A dedicated future system for **Companions** (allied followers using the shared entity/AI framework) and **Mounts** (traversal across vast 1.3 km² floors `D-044`), leaning hard into the game's absurd, memorable goofy personality (`D-023`):

- **Wacky Companions:**
  - **Slappy the Flying Bat** *(User example)* — an oversized, cranky cave bat that swoops around and physically **smacks enemies** in the face (interrupting casts or knocking skirmishers off-balance).
  - *Brainstormed companion directions `[Brainstorm — Open]`:* a sarcastic floating skull that heckles enemies to draw aggro, a tiny armored crab that hoards dropped gold, a miniature mimic chest that carries extra bag weight and bites anything that sneaks up behind you.
- **Wacky Mounts:**
  - Faster traversal across vast corridors & rooms (with dismount/combat rules so dungeons still feel dangerous).
  - *Brainstormed mount directions `[Brainstorm — Open]`:* an oversized armored dungeon boar, a skeletal war-goat that can leap over floor hazards, a goblin-rigged steam-powered shopping cart / minecart.

