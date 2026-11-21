# Premade Free CC0 Animation Sources (`trial/premade-animations`)

All premade animations baked into this directory are **CC0 1.0 Universal (Public Domain)**,
allowing free commercial & open-source use, modification, and redistribution with zero restrictions.
See [`LICENSE_CC0.txt`](LICENSE_CC0.txt).

## 1. Mesh2Motion Humanoid Animation Library (includes Quaternius UAL 1 & 2)
- **Repository:** <https://github.com/Mesh2Motion/mesh2motion-assets>
- **Pinned Commit:** `7e8d139c7119dccadcf330c88d1498019feb02c3`
- **License:** CC0 1.0 Universal (original animations by Quaternius & Mesh2Motion contributors)
- **Baked Bank:** `m2m_human_bank.json.gz` (56 clips @ 30 FPS)

## 2. ItsPogle First-Person Melee Arms Pack
- **Repository:** <https://github.com/ItsPogle/Unity-First-Person-Melee>
- **Pinned Commit:** `592b08e2e1fe81a51f712fa65d806fa3621e2032`
- **License:** CC0 1.0 Universal
- **Baked Bank:** `itspogle_fp_bank.json.gz` (9 clips @ 30 FPS)

## Rebuilding the Banks
```bash
./.tools/bin/blender --background --python scripts/fetch-premade-anims.py
```

## Included Humanoid Clips (`m2m_human_bank.json.gz`)

| Key | Upstream Action | Duration | Loop | Source Path |
|---|---|---|---|---|
| `attack_ground_pound` | Attack_Ground_Pound | 2.70s | no | `rigs/human/abilities/animation-human-attack-ground-pound.blend` |
| `bow_pull` | Bow Pull Back | 1.27s | no | `rigs/human/combat/ranged/animation-human-bow-pull.blend` |
| `bow_pull_hold` | Bow Pull Hold | 0.27s | yes | `rigs/human/combat/ranged/animation-human-bow-pull-hold.blend` |
| `bow_release` | Bow Release | 0.50s | no | `rigs/human/combat/ranged/animation-human-bow-release.blend` |
| `chop_wood` | Chop_Wood | 1.67s | no | `rigs/human/activities/animation-human-chop-wood.blend` |
| `crouch_idle` | Crouch_Idle | 3.67s | yes | `rigs/human/idles/animation-human-crouch-idle.blend` |
| `dagger_stab` | Dagger Stab | 1.40s | no | `rigs/human/combat/melee/animation-human-dagger-stab.blend` |
| `death_a` | Death_A | 4.50s | no | `rigs/human/combat/reactions/animation-human-death-A.blend` |
| `death_b` | Death_B | 1.87s | no | `rigs/human/combat/reactions/animation-human-death-B.blend` |
| `death_c` | Death_C | 2.20s | no | `rigs/human/combat/reactions/animation-human-death-C.blend` |
| `death_d` | Death_D | 2.17s | no | `rigs/human/combat/reactions/animation-human-death-d.blend` |
| `defend` | Defend | 0.93s | yes | `rigs/human/combat/defense/animation-human-defend.blend` |
| `dual_wield_combo` | Dual_Wield_Combo | 2.27s | no | `rigs/human/combat/melee/animation-human-dual-wield-combo.blend` |
| `dual_wield_cross_slash` | Dual_Wield_Cross_Slash | 1.67s | no | `rigs/human/combat/melee/animation-human-dual-wield-cross-slash.blend` |
| `fighting_idle` | Fighting Idle | 1.67s | yes | `rigs/human/combat/unarmed/animation-human-fighting-idle.blend` |
| `hit_chest` | Hit_Chest | 0.40s | no | `rigs/human/combat/reactions/animation-human-hit-chest.blend` |
| `hit_head` | Hit_Head | 0.53s | no | `rigs/human/combat/reactions/animation-human-hit-head.blend` |
| `idle_a` | Idle_A | 3.13s | yes | `rigs/human/idles/animation-human-idle-a.blend` |
| `idle_foldarms` | Idle_FoldArms | 2.50s | yes | `rigs/human/idles/animation-human-idle-foldarms.blend` |
| `idle_shield` | Idle_Shield | 2.50s | yes | `rigs/human/combat/defense/animation-human-idle-shield.blend` |
| `idle_subtle` | Idle_Subtle | 2.60s | yes | `rigs/human/idles/animation-human-idle-subtle.blend` |
| `idle_sword` | Idle_Sword | 2.10s | yes | `rigs/human/combat/melee/animation-human-idle-sword.blend` |
| `idle_talking` | Idle_Talking | 3.67s | yes | `rigs/human/idles/animation-human-idle-talking.blend` |
| `jog` | Jog | 1.17s | yes | `rigs/human/locomotion/animation-human-jog.blend` |
| `one_hand_slash_combo` | One_Hand_Slash_Combo | 1.80s | no | `rigs/human/combat/melee/animation-human-one-hand-slash-combo.blend` |
| `one_hand_weapon_idle` | One Hand Weapon Idle | 2.67s | yes | `rigs/human/combat/melee/animation-human-one-hand-weapon-idle.blend` |
| `polearm_idle` | Polearm Idle | 2.67s | yes | `rigs/human/combat/melee/animation-human-polearm-idle.blend` |
| `polearm_run` | Polearm_Run | 0.83s | yes | `rigs/human/combat/melee/animation-human-polearm-run.blend` |
| `power_burst` | Power_Burst | 4.20s | no | `rigs/human/abilities/animation-human-power-burst.blend` |
| `reject` | Reject | 3.73s | no | `rigs/human/emotions/animation-human-reject.blend` |
| `run_stealth` | Run_Stealth | 0.53s | yes | `rigs/human/locomotion/animation-human-run-stealth.blend` |
| `shield_oneshot` | Shield_OneShot | 0.83s | no | `rigs/human/combat/defense/animation-human-shield-oneshot.blend` |
| `spell_simple_enter` | Spell_Simple_Enter | 0.67s | no | `rigs/human/abilities/animation-human-spell-simple-enter.blend` |
| `spell_simple_idle` | Spell_Simple_Idle | 2.67s | yes | `rigs/human/abilities/animation-human-spell-simple-idle.blend` |
| `spell_simple_shoot` | Spell_Simple_Shoot | 0.63s | no | `rigs/human/abilities/animation-human-spell-simple-shoot.blend` |
| `sprint` | Sprint | 0.83s | yes | `rigs/human/locomotion/animation-human-sprint.blend` |
| `sword_attack` | Sword_Attack | 1.93s | no | `rigs/human/combat/melee/animation-human-sword-attack.blend` |
| `sword_block` | Sword_Block | 1.27s | no | `rigs/human/combat/defense/animation-human-sword-block.blend` |
| `sword_regular_a` | Sword_Regular_A | 0.47s | no | `rigs/human/combat/melee/animation-human-sword-regular-a.blend` |
| `sword_regular_a_rec` | Sword_Regular_A_Rec | 0.97s | no | `rigs/human/combat/melee/animation-human-sword-regular-a-rec.blend` |
| `sword_regular_b` | Sword_Regular_B | 0.53s | no | `rigs/human/combat/melee/animation-human-sword-regular-b.blend` |
| `sword_regular_b_rec` | Sword_Regular_B_Rec | 1.00s | no | `rigs/human/combat/melee/animation-human-sword-regular-b-rec.blend` |
| `two_hand_blast` | Two-hand Blast | 0.40s | no | `rigs/human/abilities/animation-human-two-hand-blast.blend` |
| `two_handed_horizontal_swing` | Two_Handed_Horizontal_Swing | 1.67s | no | `rigs/human/combat/melee/animation-human-two-handed-horizontal-swing.blend` |
| `two_handed_overhead_slam` | Two_Handed_Overhead_Slam | 1.83s | no | `rigs/human/combat/melee/animation-human-two-handed-overhead-slam.blend` |
| `walk` | Walk | 1.67s | yes | `rigs/human/locomotion/animation-human-walk.blend` |
| `walk_cautious` | Walk_Cautious | 1.83s | yes | `rigs/human/locomotion/animation-human-walk-cautious.blend` |
| `walk_formal` | Walk_Formal | 1.67s | yes | `rigs/human/locomotion/animation-human-walk-formal.blend` |
| `walk_large` | Walk_Large | 1.40s | yes | `rigs/human/locomotion/animation-human-walk-large.blend` |
| `walk_relaxed` | Walk_Relaxed | 1.40s | yes | `rigs/human/locomotion/animation-human-walk-relaxed.blend` |
| `walk_stealth` | Walk_Stealth | 1.50s | yes | `rigs/human/locomotion/animation-human-walk-stealth.blend` |
| `zombie_idle_2` | Zombie_Idle | 1.33s | yes | `rigs/human/zombie/animation-human-zombie-idle-2.blend` |
| `zombie_run` | Zombie Run | 0.73s | yes | `rigs/human/zombie/animation-human-zombie-run.blend` |
| `zombie_scratch` | Zombie_Scratch | 1.80s | no | `rigs/human/zombie/animation-human-zombie-scratch.blend` |
| `zombie_walk` | Zombie_Walk | 1.33s | yes | `rigs/human/zombie/animation-human-zombie-walk.blend` |
| `zombie_yell` | Zombie Yell | 3.70s | no | `rigs/human/zombie/animation-human-zombie-yell.blend` |

## Included First-Person Clips (`itspogle_fp_bank.json.gz`)

| Key | Upstream Action | Duration |
|---|---|---|
| `consumable_drink_001` | `CharacterArmature|CharacterArmature|Consumable_Drink.001` | 0.47s |
| `fists_block` | `CharacterArmature|CharacterArmature|Fists_Block` | 0.13s |
| `fists_idle` | `CharacterArmature|CharacterArmature|Fists_Idle` | 3.33s |
| `lefthand_spell1` | `CharacterArmature|CharacterArmature|Lefthand_Spell1` | 2.93s |
| `sword_block` | `CharacterArmature|CharacterArmature|Sword_Block` | 0.13s |
| `sword_idle` | `CharacterArmature|CharacterArmature|Sword_Idle` | 3.33s |
| `sword_slash1` | `CharacterArmature|CharacterArmature|Sword_Slash1` | 0.83s |
| `sword_slash2` | `CharacterArmature|CharacterArmature|Sword_Slash2` | 0.83s |
| `sword_walk` | `CharacterArmature|CharacterArmature|Sword_Walk` | 0.93s |
