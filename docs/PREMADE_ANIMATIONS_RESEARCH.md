# Premade Free 3D Animation Research Report (`FB-025` / `D-060`)

> **Context:** User requested (`FB-025`) a trial branch (`trial/premade-animations`) researching free online 3D animation libraries and replacing **all** AI-generated animations (all 6 rigged 3rd-person characters + all first-person viewmodel animations) with genuine human-authored / mocap-derived premade animations.
>
> **Licensing Rule (`D-004`):** Everything committed into this open-source repository MUST be truly free, open-source, and redistributable without non-commercial or no-redistribution clauses.

---

## 1. Candidate Libraries Evaluated

| Library / Source | License | Compatible with `D-004`? | Format & Rig | Clip Coverage | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **[Mesh2Motion (`mesh2motion-assets`)](https://github.com/Mesh2Motion/mesh2motion-assets)** *(incorporating Quaternius Universal Animation Library 1 & 2 + Mesh2Motion community/mocap clips)* | **CC0 1.0 Universal** (art/anims CC0; app code MIT) | **YES (100% open & redistributable)** | Native Blender 4.5 `.blend` files (`rigs/rig-human.blend`, 65-bone UE5-style humanoid facing `-Y` fwd / `+Z` up / `+X` left — **identical coordinate convention to our `dclib/rig.py`!**) | **234+ humanoid clips**: idle/combat/stealth/zombie/giant walks & runs, 1H/2H/dual-wield swings & slams, bow pull/hold/release, spells, shield guard/recoil, talking/emotes, 4 distinct deaths, hit reacts. **Bonus future rigs:** `dragon`, `spider`, `fox`, `horse`, `bird`, `snake`, `shark`, `kaiju`. | **SELECTED — Primary 3rd-Person + 2H/Bow/Spell/Shield FP Source** |
| **[ItsPogle First-Person Melee](https://github.com/ItsPogle/Unity-First-Person-Melee)** | **CC0 1.0 Universal** | **YES (100% open & redistributable)** | `Assets/Models/Arms.fbx` (loads cleanly in Blender 4.5 with action slots) | **9 dedicated FP arm clips**: `Sword_Idle`, `Sword_Walk`, `Sword_Slash1`, `Sword_Slash2`, `Sword_Block`, `Lefthand_Spell1`, `Fists_Idle`, `Fists_Block`, `Consumable_Drink`. | **SELECTED — Primary 1H First-Person Sword Source** |
| **[Quaternius Universal Animation Library 1 & 2](https://quaternius.com/)** | **CC0 1.0 Universal** | **YES** | `.fbx` / `.glb` / `.blend` (itch.io downloads rate-limited with HTTP 429 in CI; full UAL 1 & 2 human catalog is officially mirrored and maintained under CC0 inside `Mesh2Motion/mesh2motion-assets`) | ~86 high-craft human locomotion, combat, sword, spell, crouch, hit, and death clips. | **INCLUDED via Mesh2Motion** |
| **[KayKit Character Packs (Adventures & Skeletons 1.0)](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0)** | **CC0 1.0 Universal** | **YES** | `.glb` / `.fbx` directly on GitHub (`Knight.glb`, `Skeleton_Warrior.glb`) | 75–90+ RPG clips (1H, 2H, bow, spell, block, dual-wield, death). Chibi/blocky rig proportions make realistic Skyrim-style retargeting slightly stiffer than Mesh2Motion. | **Verified CC0 Backup** |
| **Adobe Mixamo** | Adobe General Terms (§6.2.E) | **NO — REJECTED** | `.fbx` | Huge mocap library, but Adobe ToS prohibits redistributing raw/derived animation libraries/datasets in open-source repositories. | **REJECTED (`D-004`)** |
| **Bandai Namco Research Motion Dataset** | **CC BY-NC-ND 4.0** | **NO — REJECTED** | `.bvh` | 3,000+ combat & locomotion mocap clips, but Non-Commercial + No-Derivatives strictly conflicts with open-source game distribution. | **REJECTED (`D-004`)** |
| **CMU Mocap / ACCAD Open Mocap** | Public Domain / Academic | **YES** | Raw `.bvh` / `.c3d` | Thousands of raw lab captures, but noisy/unlooped and lack fantasy combat (swords, shields, bows, spells) without heavy manual cleanup. | **Not needed** (Mesh2Motion/Quaternius already cleaned & game-ready) |
| **Godot4-OpenAnimationLibraries / Cinevva / KinemIQ** | Mixed CC0 / CC-BY | Partial | `.glb` / `.fbx` | Community aggregators; mostly repackage Quaternius UAL or smaller subsets after Mixamo removal. | **Superseded by direct upstream CC0 sources** |

---

## 2. Why Mesh2Motion + ItsPogle Won

1. **Zero Legal Friction (`D-004`):** Both libraries are explicitly **CC0 1.0 Universal** (public domain dedication). Every animation can be stored offline in our repo, rebuilt deterministically by any contributor or CI runner, and shipped freely in open-source releases.
2. **Exact Coordinate & Proportion Match:** Mesh2Motion's `rig-human.blend` is a realistic-proportioned humanoid facing `-Y` forward, `+Z` up, `+X` left — the exact coordinate convention of [`art/blender/dclib/rig.py`](../art/blender/dclib/rig.py). Retargeting needs only rest-pose T-pose → A-pose calibration, proportional hip height scaling, and floor contact grounding.
3. **Purpose-Built First-Person Melee:** ItsPogle's `Arms.fbx` was specifically animated for first-person camera framing (sword idle, walk, slash 1, slash 2, block, drink), giving natural first-person wrist arcs that complement Mesh2Motion's 2H battleaxe, bow, spell, and shield curves.
4. **Massive Future Expansion Ready (`D-051`):** `Mesh2Motion/mesh2motion-assets` ships **234+ humanoid clips** plus CC0 rigs and animations for **dragons, spiders, wolves/foxes, horses, birds, snakes, sharks, and kaiju** — ready to plug directly into our planned enemy catalog in [`docs/CONTENT_CATALOG.md`](CONTENT_CATALOG.md)!

---

## 3. Offline Reproducible Pipeline Implemented on `trial/premade-animations`

1. **Fetcher & Sampler ([`scripts/fetch-premade-anims.py`](../scripts/fetch-premade-anims.py)):**
   - Downloads pinned commits of `Mesh2Motion/mesh2motion-assets` (`7e8d139c7119dccadcf330c88d1498019feb02c3`) and `ItsPogle/Unity-First-Person-Melee` (`592b08e2e1fe81a51f712fa65d806fa3621e2032`) into `/tmp`, evaluates each clip cleanly in Blender 4.5 (with relinked `rig-human.blend` and bound Blender 4.5 action slots), and bakes compact 30 FPS JSON banks:
     - `art/premade_anims/m2m_human_bank.json.gz` (838 KB, **56 curated CC0 clips**)
     - `art/premade_anims/itspogle_fp_bank.json.gz` (24 KB, **9 curated CC0 FP clips**)
     - `art/premade_anims/LICENSE_CC0.txt` & `art/premade_anims/SOURCES.md`
2. **3rd-Person Character Retargeter ([`art/blender/dclib/premade_retarget.py`](../art/blender/dclib/premade_retarget.py)):**
   - Drop-in replacement for `art/blender/dclib/char_anims.py` in [`art/blender/build_characters.py`](../art/blender/build_characters.py).
   - Transfers world-space bone orientations (with T-pose → A-pose swing removal, optional hunch preservation for Draugr/Goblin, shoulder clearance for armored rigs, proportional pelvis scaling, ground contact / floor-flush corpse settlement, 2H upper-wrap shaft IK lock, upright bow alignment, dual-wield blade guard alignment, and exact left↔right mirroring).
3. **First-Person Extractor & Player ([`scripts/extract-fp-anims.py`](../scripts/extract-fp-anims.py) → `game/data/fp_animations.json` → [`game/src/world/viewmodel_rig.gd`](../game/src/world/viewmodel_rig.gd)):**
   - Projects ItsPogle's CC0 FP sword clips + Mesh2Motion's CC0 2H chop/swing/slam, spell, bow pull/release, and shield recoil clips into 30 FPS camera-space curves in `game/data/fp_animations.json` (15 clips + 3 curves, 50 KB).
   - Replaces all hardcoded AI pose arrays in `ViewmodelRig` while strictly preserving `D-048` (blades face away from the player at rest/sprint), anatomical 2-bone arm IK, and seamless power-attack charge continuity.

---

## 4. Clip Mapping Summary (Every Character & First-Person Action)

| Target | Premade CC0 Source Clips Used |
| :--- | :--- |
| **Player Crawler (3rd-Person)** | `idle_a`, `idle_sword`, `walk`, `jog`, `sword_attack`, `two_handed_horizontal_swing` (`attack_2h`), `idle_shield` (`block`), `spell_simple_enter+shoot` (`cast` / mirrored `cast_r`), `two_hand_blast` (`cast_dual`), `fighting_idle` (`idle_dual`), `one_hand_slash_combo` (`attack_dual` / mirrored `attack_l`), `bow_pull` / `bow_pull_hold` / `bow_release`, `hit_chest`, `death_b` |
| **Hollow Draugr Raider** | `zombie_idle_2`, `polearm_idle`, `zombie_walk`, `polearm_run`, `two_handed_horizontal_swing`, `hit_chest`, `death_a` |
| **Crypt Bone Archer** | `idle_subtle`, `bow_pull_hold`, `walk_cautious`, `jog`, `bow_pull+hold+release` (`shoot`), `dagger_stab`, `hit_head`, `death_c` |
| **Goblin Glory-Hound** | `one_hand_weapon_idle`, `fighting_idle`, `walk_stealth`, `run_stealth`, `one_hand_slash_combo`, `hit_chest`, `death_d` |
| **The Iron Warden (Boss)** | `polearm_idle`, `walk_large`, `polearm_run`, `two_handed_horizontal_swing`, `zombie_yell` (`roar`), `two_handed_overhead_slam` (`slam`), `hit_chest`, `death_a` |
| **Safe Room Merchant** | `idle_a`, `idle_subtle`, `idle_talking` (`talk`), `walk_relaxed`, `walk_formal`, `reject`, `hit_chest`, `death_b` |
| **First-Person Viewmodel** | **1H Sword / Dual-Wield:** ItsPogle `Sword_Idle`, `Sword_Walk`, `Sword_Slash1`, `Sword_Slash2` + Mesh2Motion `sprint`, `sword_attack` (power charge/cleave)<br>**2H Battleaxe:** Mesh2Motion `polearm_idle`, `polearm_run`, `chop_wood` (light 1), `two_handed_horizontal_swing` (light 2), `two_handed_overhead_slam` (charge + power)<br>**Spells:** Mesh2Motion `spell_simple_idle`, `spell_simple_enter+shoot`<br>**Bow & Shield:** Mesh2Motion `bow_pull`, `bow_release`, `shield_oneshot` |
