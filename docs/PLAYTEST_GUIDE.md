# Playtest Guide — Milestone 1 (`v0.1` Vertical Slice)

Welcome to your first hands-on playtest of **Dungeon Crawler 3D**!  
Everything mechanical has already been verified by automated tests, so this playtest is all about **feel, fun, atmosphere, and the Skyrim north star**.

---

## 1. How to Launch the Game (Free, Open-Source)

1. Download **Godot 4.7.2-stable** (free, open-source, no install needed): <https://godotengine.org/download>
2. Clone or pull this repository and check out the branch (`feat/v0.1-vertical-slice` before merge, or `main` after merge).
3. Open Godot → click **Import** → select `game/project.godot`.
4. Press **F5** (Play) — the **title screen** opens over a live torch-lit hall. Choose **New Expedition** (or **Continue** to resume a save). Open **Settings** first if you want to pick a graphics preset, field of view, mouse sensitivity or re-bind keys.

*(Optional terminal launch if you have Godot on your PATH: `godot --path game`)*

---

## 1a. Discovery & Mastery (`D-049`)

- Every item you find is Common for now, but each one has its own **mastery track**: use it and its level (shown as `· M<level>` next to its name on the HUD) goes up, its stats grow, and at certain levels it unlocks a new ability ("NEW ABILITY" banner). Open the Character menu (Tab) and select the item to see its mastery XP, the abilities you have discovered, and the "???" ones still ahead.
- Try: Chain Spark until it chains (M2), Firebolt until it explodes (M4), the Longsword's Lunge (M3, hold attack for a power attack) and Cross Guard (M5, a sword in each hand — hold the off-hand attack), the Recurve Bow's Hunter's Focus (M4, hold a full draw).
- Enemies show their level over their heads; every type has its own level range and trait. Character menu → **Bestiary** fills in as you meet (sighted), kill (stats + abilities) and kill five (weakness) of each creature. It is never lost on a floor reset.
- Test Mode (F1 → Player) has **+1 / +5 mastery** for equipped gear and **Reveal whole bestiary**.

## 1b. Test Mode — Spawn Anything (`D-047`)

Choose **Test Mode** on the title screen. You start on a compact floor with every room type (entrance, combat halls, safe room, boss arena + treasure vault, stairwell) and no regular enemies; it uses its own save file, so your real expedition is never touched. Press **F1** for the tools:

| Tab | What you can do |
|---|---|
| **Enemies** | Spawn any enemy (including the Iron Warden) 1, 3 or 5 at a time in front of you; kill nearby / all; remove all; freeze AI. |
| **Items** | Pick a rarity, then add any item to your bag (or every item at once); +1,000 gold; health potions; open the inventory. |
| **World** | Place chests (standard / rare / vault), crates, urns, trap levers, spike traps, braziers, lights, a stairwell, a full safe-room kit (vendor, quest board, ward) or any handcrafted room setpiece where you are looking. |
| **Player** | God mode, infinite stamina & magicka, +1 / +5 levels, full heal, first / third person, die (tests the floor reset). |
| **Floor** | Teleport to every room type, open the boss + vault gates, pause / run the floor clock, advance a day, collapse the floor, rebuild the test floor, jump to a real vast floor, next / previous floor. |

## 2. Controls Cheat Sheet (Skyrim-Inspired)

| Input | Action |
|---|---|
| **W / A / S / D** | Move |
| **Mouse** | Look around |
| **Shift** | Sprint (drains Stamina) |
| **Space** | Jump |
| **V** | Toggle **1st-Person** (default) ↔ **3rd-Person Over-the-Shoulder** |
| **Left Click** | Right-Hand Action (Tap = Light Attack, Hold = Power Attack, or Hold & Release = Draw/Fire Bow) |
| **Right Click** | Left-Hand Action (Hold = Shield Block, Tap = Off-Hand Swing, or Cast Equipped Spell) |
| **1 / 2 / 3 / 4** | Quick Loadouts: `1` Sword + Shield · `2` Two-Handed Greatsword · `3` Sword + Firebolt Spell · `4` Hunting Bow |
| **E** | Interact / Loot (Chests, Crates, Urns, Enemy Corpses, Trap Levers, Safe Room Vendor, Quest Board, Hidden Staircase) |
| **Q** | Quick-drink Health Potion |
| **I** or **Tab** | Open **Inventory & Character** *(pauses the 5-day clock!)* — click to inspect, double-click to equip/use, right-click to equip off-hand, click an equipped slot to unequip; **Skills & Perks** tab for level-up points |
| **M** | Open the **Dungeon Map** (explored areas, landmarks; mouse wheel zoom, drag to pan) |
| **H** | Hide the current Tutorial Mode hint card *(non-blocking, auto-completes as you play)* |
| **Esc** | Open **Pause Menu** *(Resume, Settings, Controls, Camera Toggle, Tutorial ON/OFF & Replay, Save, Reset Floor, Save & Quit to Title / Desktop)* |

All keys except Esc can be re-bound in **Settings → Controls**.
| **`** (Backtick / Tilde) | Toggle the **Playtest Audit Console** (instant shortcuts below) |

---

## 3. Recommended 5-Minute `v0.1` Playtest Tour

1. **Feel the Upgraded Visuals, Skyrim Movement & Tutorial Mode:** Start in the handcrafted **Arrival Hall** (carved stone masonry, flaming braziers, crimson runner). Notice the unobtrusive bottom-right **Tutorial Card** (`D-030`) that updates automatically as you first encounter each mechanic (or toggle it OFF anytime in `Esc`). Walk, sprint (`Shift`), jump (`Space`), and press `V` for 3rd-person over-the-shoulder with smooth wall-collision pullback.
2. **Test Left/Right-Hand Combat & Animations:** Notice the sleek lower-left shield framing (~11% screen area) and sculpted armored gauntlets. Cycle loadouts `1`–`4` against Draugr Raiders, Bone Archers, and **Sponsored Goblin Streamers** (glowing neon ring-light halo + hovering twin-rotor drone!). Block with `Right Click`, land alternating diagonal sword combos and overhead power attacks (`Hold Left Click`), hurl Firebolts (`3` → `Right Click`), and snipe with the bow (`4` → hold & release `Left Click` with FOV zoom).
3. **Loot, Pause & Level Up:** Loot chests and fallen enemy corpses (`E`). Open the dark-fantasy Inventory (`I`) — confirm the 5-day countdown freezes while you equip gear, spend Attribute/Perk points, or inspect your Skyrim use-to-improve weapon/magic skills.
4. **Visit the Handcrafted Safe Room Sanctuary:** Follow the **Top Compass Bar** (`◆ SAFE`) or type `teleport safe` in the `` ` `` console. Step into the warm hearth-lit Sanctuary with the striped **Merchant Stall**, robed **Safe Room Vendor**, glowing **Sanctuary Beacon**, and **Syndicate Quest Board** — pursuing monsters flee immediately on sight!
5. **Challenge the Handcrafted Boss Crucible & Treasure Vault:** Follow the `☠ BOSS` compass marker (or type `teleport boss`). Step inside — the iron portcullis slams shut behind you as the towering 3m **Iron Warden** strides off the glowing Rune Dais! Defeat him (or type `kill_boss`) to unlock the adjoining gilded **Treasure Vault** packed with guaranteed Sponsored/Mythic loot.
6. **Test the 5-Day Floor Collapse & Snapshot Reset:** Earn some gold or spawn loot (`spawn_loot common`), then type `advance_days 5.1`. Watch the Syndicate AI collapse toast fire and confirm your run resets cleanly to the start of Floor 1 with your pre-floor inventory/gold intact and a fresh 5-day clock!
7. **Descend to Floor 2 (No Preview!) & Save-and-Quit:** Type `teleport stairs`, press `E` on the hidden staircase to descend straight into Floor 2 with zero preview, then press `Esc` → **Save & Quit** and relaunch to confirm you resume in the exact same spot with the exact same remaining time and tutorial progress.

---

## 4. Playtest Audit Console Commands (Press `` ` ``)

These shortcuts exist so you never have to grind to inspect any feature:

| Command | What It Does |
|---|---|
| `help` | Lists all available console commands |
| `status` | Prints current Floor, Seed, Days Remaining, HP, Gold, and Position |
| `teleport entrance\|safe\|boss\|vault\|stairs` | Teleports directly to any major landmark on the floor |
| `advance_days <N>` | Advances the 5-day clock by `<N>` in-game days (e.g., `advance_days 4.9` or `advance_days 5.1`) |
| `collapse` | Triggers an immediate Floor Collapse reset to the Floor-Entry Snapshot |
| `kill_player` | Triggers a Combat-Death reset to the Floor-Entry Snapshot |
| `kill_boss` | Defeats the Floor Boss immediately to inspect the Treasure Vault unlock |
| `spawn_loot <rarity>` | Drops a freshly rolled item (`common`, `uncommon`, `rare`, `epic`, `legendary`) into your bag |
| `add_gold <N>` | Adds `<N>` Syndicate Gold for testing the Safe Room Vendor |
| `add_xp <N>` | Grants `<N>` Character XP to test leveling, attributes & perks |
| `god` | Toggles invincibility ON/OFF |
| `camera` | Toggles 1st-Person ↔ 3rd-Person Over-the-Shoulder camera |
| `seed [int]` | Prints current seed or regenerates the floor with a specific seed |

---

## 4b. What Changed in the Visual Overhaul v2

- **New art everywhere:** hand-cut stone halls with arches and coffered vaults, real fire, fog and shadows; detailed props; rigged, animated enemies that wind up, flinch and fall (their bodies stay to be looted); a real bowstring; glowing spell hands.
- **New menus:** title screen, gilded HUD, tabbed settings, inventory with a 3D portrait and stat comparisons, vendor, hand-inked map, death screen.
- **Comfort options:** head bob and camera shake sliders, FOV, UI scale, colour-blind filters, reduced flashing, damage numbers on/off, HUD opacity.

## 5. What Feedback Helps Most Right Now

When you review this milestone, let me know:
1. **Skyrim Feel:** Does movement speed, camera height/FOV, left/right-hand combat, and menu pausing feel right?
2. **Art Direction (5 Preview Sheets):** Look at `art/previews/batch1_kit_room.png`, `batch1_props.png`, `batch2_weapons_gear.png`, `batch3_characters.png` and `texture_library.png` (plus the live screenshots from `./scripts/run-visual-qa.sh`) — what do you love, and what would you tweak before we expand art in `v0.2`?
3. **Pacing & Tone:** How do the 5-day floor clock, Safe Room sanctuary, Boss Arena tension, and Dungeon AI snarky banners feel?
