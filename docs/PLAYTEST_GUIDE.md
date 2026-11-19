# Playtest Guide — Milestone 1 (`v0.1` Vertical Slice)

Welcome to your first hands-on playtest of **Dungeon Crawler 3D**!  
Everything mechanical has already been verified by automated tests, so this playtest is all about **feel, fun, atmosphere, and the Skyrim north star**.

---

## 1. How to Launch the Game (Free, Open-Source)

1. Download **Godot 4.7.2-stable** (free, open-source, no install needed): <https://godotengine.org/download>
2. Clone or pull this repository and check out the branch (`feat/v0.1-vertical-slice` before merge, or `main` after merge).
3. Open Godot → click **Import** → select `game/project.godot`.
4. Press **F5** (Play) — the game boots straight into **Floor 1: The Nordic Ruin** with zero setup required.

*(Optional terminal launch if you have Godot on your PATH: `godot --path game`)*

---

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
| **I** or **Tab** | Open **Inventory, Equipment & Progression Menu** *(pauses the 5-day clock!)* |
| **H** | Hide the current Tutorial Mode hint card *(non-blocking, auto-completes as you play)* |
| **Esc** | Open **Pause Menu** *(Resume, Camera Toggle, **Tutorial Mode ON/OFF & Reset**, Save & Quit, Reset Floor)* |
| **`** (Backtick / Tilde) | Toggle the **Playtest Audit Console** (instant shortcuts below) |

---

## 3. Recommended 5-Minute `v0.1` Playtest Tour

1. **Feel the Upgraded Visuals, Skyrim Movement & Tutorial Mode:** Start in the handcrafted **Arrival Hall** (carved stone masonry, flaming braziers, crimson runner). Notice the unobtrusive bottom-right **Tutorial Card** (`D-030`) that updates automatically as you first encounter each mechanic (or toggle it OFF anytime in `Esc`). Walk, sprint (`Shift`), jump (`Space`), and press `V` for 3rd-person over-the-shoulder with smooth wall-collision pullback.
2. **Test Left/Right-Hand Combat & Animations:** Notice the sleek lower-left shield framing (~11% screen area) and sculpted armored gauntlets. Cycle loadouts `1`–`4` against Draugr Raiders, Bone Archers, and **Sponsored Goblin Streamers** (glowing neon ring-light halo + hovering twin-rotor drone!). Block with `Right Click`, land alternating diagonal sword combos and overhead power attacks (`Hold Left Click`), hurl Firebolts (`3` → `Right Click`), and snipe with the bow (`4` → hold & release `Left Click` with FOV zoom).
3. **Loot, Pause & Level Up:** Loot chests and fallen enemy corpses (`E`). Open the dark-fantasy Inventory (`I`) — confirm the 5-day countdown freezes while you equip gear, spend Attribute/Perk points, or inspect your Skyrim use-to-improve weapon/magic skills.
4. **Visit the Handcrafted Safe Room Sanctuary:** Follow the **Top Compass Bar** (`◆ SAFE`) or type `teleport safe` in the `` ` `` console. Step into the warm hearth-lit Sanctuary with the striped **Merchant Stall**, robed **Safe Room Vendor**, glowing **Sanctuary Beacon**, and **Syndicate Quest Board** — pursuing monsters flee immediately on sight!
5. **Challenge the Handcrafted Boss Crucible & Treasure Vault:** Follow the `☠ BOSS` compass marker (or type `teleport boss`). Step inside — the iron portcullis slams shut behind you as the towering 3m **Iron Warden** strides off the glowing Rune Dais! Defeat him (or type `kill_boss`) to unlock the adjoining gilded **Treasure Vault** packed with guaranteed Sponsored/Mythic loot.
6. **Test the 5-Day Floor Collapse & Snapshot Reset:** Earn some gold or spawn loot (`spawn_loot sponsored`), then type `advance_days 5.1`. Watch the Syndicate AI collapse toast fire and confirm your run resets cleanly to the start of Floor 1 with your pre-floor inventory/gold intact and a fresh 5-day clock!
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
| `spawn_loot <rarity>` | Drops a freshly rolled item (`common`, `uncommon`, `rare`, `epic`, `sponsored`) into your bag |
| `add_gold <N>` | Adds `<N>` Syndicate Gold for testing the Safe Room Vendor |
| `add_xp <N>` | Grants `<N>` Character XP to test leveling, attributes & perks |
| `god` | Toggles invincibility ON/OFF |
| `camera` | Toggles 1st-Person ↔ 3rd-Person Over-the-Shoulder camera |
| `seed [int]` | Prints current seed or regenerates the floor with a specific seed |

---

## 5. What Feedback Helps Most Right Now

When you review this milestone, let me know:
1. **Skyrim Feel:** Does movement speed, camera height/FOV, left/right-hand combat, and menu pausing feel right?
2. **Art Direction (3 Preview Sheets):** Look at `art/previews/batch1_dungeon_kit.png`, `batch2_weapons_gear.png`, and `batch3_characters_enemies.png` — what do you love, and what would you tweak before we expand art in `v0.2`?
3. **Pacing & Tone:** How do the 5-day floor clock, Safe Room sanctuary, Boss Arena tension, and Dungeon AI snarky banners feel?
