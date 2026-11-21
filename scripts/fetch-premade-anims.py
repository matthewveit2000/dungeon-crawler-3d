#!/usr/bin/env python3
"""Downloads and bakes curated CC0 1.0 premade animations into compact, offline-reproducible
JSON.GZ animation banks under art/premade_anims/.

Sources (100% CC0 1.0 Universal — public domain, free to redistribute):
  1. Mesh2Motion Humanoid Library (includes Quaternius Universal Animation Library 1 & 2
     plus Mesh2Motion original/mocap CC0 clips):
     https://github.com/Mesh2Motion/mesh2motion-assets
  2. ItsPogle First-Person Melee Arms Pack:
     https://github.com/ItsPogle/Unity-First-Person-Melee

Run with Blender 4.5.9 LTS:
  ./.tools/bin/blender --background --python scripts/fetch-premade-anims.py
"""

from __future__ import annotations

import concurrent.futures
import gzip
import json
import pathlib
import sys
import urllib.request

import bpy
from mathutils import Vector

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "art" / "premade_anims"
CACHE_DIR = pathlib.Path("/tmp/anim_research/bake_cache")

# Pinned upstream commits for 100% reproducible fetches
M2M_COMMIT = "7e8d139c7119dccadcf330c88d1498019feb02c3"
M2M_RAW = f"https://raw.githubusercontent.com/Mesh2Motion/mesh2motion-assets/{M2M_COMMIT}/"
ITSPOGLE_COMMIT = "592b08e2e1fe81a51f712fa65d806fa3621e2032"
ITSPOGLE_RAW = f"https://raw.githubusercontent.com/ItsPogle/Unity-First-Person-Melee/{ITSPOGLE_COMMIT}/"

TARGET_FPS = 30

# Core humanoid deform bones we sample from Mesh2Motion's rig-human.blend
M2M_BONES = [
    "root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head",
    "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
    "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
    "thigh_l", "calf_l", "foot_l", "ball_l",
    "thigh_r", "calf_r", "foot_r", "ball_r",
]

# Curated CC0 Mesh2Motion / Quaternius clips: key -> (relative path in mesh2motion-assets, is_loop)
M2M_CLIPS: dict[str, tuple[str, bool]] = {
    # Idles
    "idle_a": ("rigs/human/idles/animation-human-idle-a.blend", True),
    "idle_subtle": ("rigs/human/idles/animation-human-idle-subtle.blend", True),
    "idle_sword": ("rigs/human/combat/melee/animation-human-idle-sword.blend", True),
    "one_hand_weapon_idle": ("rigs/human/combat/melee/animation-human-one-hand-weapon-idle.blend", True),
    "polearm_idle": ("rigs/human/combat/melee/animation-human-polearm-idle.blend", True),
    "idle_shield": ("rigs/human/combat/defense/animation-human-idle-shield.blend", True),
    "fighting_idle": ("rigs/human/combat/unarmed/animation-human-fighting-idle.blend", True),
    "zombie_idle_2": ("rigs/human/zombie/animation-human-zombie-idle-2.blend", True),
    "crouch_idle": ("rigs/human/idles/animation-human-crouch-idle.blend", True),
    "idle_talking": ("rigs/human/idles/animation-human-idle-talking.blend", True),
    "idle_foldarms": ("rigs/human/idles/animation-human-idle-foldarms.blend", True),
    # Locomotion
    "walk": ("rigs/human/locomotion/animation-human-walk.blend", True),
    "jog": ("rigs/human/locomotion/animation-human-jog.blend", True),
    "sprint": ("rigs/human/locomotion/animation-human-sprint.blend", True),
    "walk_cautious": ("rigs/human/locomotion/animation-human-walk-cautious.blend", True),
    "walk_large": ("rigs/human/locomotion/animation-human-walk-large.blend", True),
    "polearm_run": ("rigs/human/combat/melee/animation-human-polearm-run.blend", True),
    "walk_stealth": ("rigs/human/locomotion/animation-human-walk-stealth.blend", True),
    "run_stealth": ("rigs/human/locomotion/animation-human-run-stealth.blend", True),
    "walk_relaxed": ("rigs/human/locomotion/animation-human-walk-relaxed.blend", True),
    "walk_formal": ("rigs/human/locomotion/animation-human-walk-formal.blend", True),
    "zombie_walk": ("rigs/human/zombie/animation-human-zombie-walk.blend", True),
    "zombie_run": ("rigs/human/zombie/animation-human-zombie-run.blend", True),
    # 1H / Dual / Skirmisher Attacks
    "sword_attack": ("rigs/human/combat/melee/animation-human-sword-attack.blend", False),
    "one_hand_slash_combo": ("rigs/human/combat/melee/animation-human-one-hand-slash-combo.blend", False),
    "sword_regular_a": ("rigs/human/combat/melee/animation-human-sword-regular-a.blend", False),
    "sword_regular_a_rec": ("rigs/human/combat/melee/animation-human-sword-regular-a-rec.blend", False),
    "sword_regular_b": ("rigs/human/combat/melee/animation-human-sword-regular-b.blend", False),
    "sword_regular_b_rec": ("rigs/human/combat/melee/animation-human-sword-regular-b-rec.blend", False),
    "dagger_stab": ("rigs/human/combat/melee/animation-human-dagger-stab.blend", False),
    "zombie_scratch": ("rigs/human/zombie/animation-human-zombie-scratch.blend", False),
    "dual_wield_combo": ("rigs/human/combat/melee/animation-human-dual-wield-combo.blend", False),
    "dual_wield_cross_slash": ("rigs/human/combat/melee/animation-human-dual-wield-cross-slash.blend", False),
    # 2H Melee & Boss
    "two_handed_horizontal_swing": ("rigs/human/combat/melee/animation-human-two-handed-horizontal-swing.blend", False),
    "two_handed_overhead_slam": ("rigs/human/combat/melee/animation-human-two-handed-overhead-slam.blend", False),
    "attack_ground_pound": ("rigs/human/abilities/animation-human-attack-ground-pound.blend", False),
    "chop_wood": ("rigs/human/activities/animation-human-chop-wood.blend", False),
    # Defense
    "sword_block": ("rigs/human/combat/defense/animation-human-sword-block.blend", False),
    "defend": ("rigs/human/combat/defense/animation-human-defend.blend", True),
    "shield_oneshot": ("rigs/human/combat/defense/animation-human-shield-oneshot.blend", False),
    # Archery
    "bow_pull": ("rigs/human/combat/ranged/animation-human-bow-pull.blend", False),
    "bow_pull_hold": ("rigs/human/combat/ranged/animation-human-bow-pull-hold.blend", True),
    "bow_release": ("rigs/human/combat/ranged/animation-human-bow-release.blend", False),
    # Spells, Roar & Vendor
    "spell_simple_enter": ("rigs/human/abilities/animation-human-spell-simple-enter.blend", False),
    "spell_simple_idle": ("rigs/human/abilities/animation-human-spell-simple-idle.blend", True),
    "spell_simple_shoot": ("rigs/human/abilities/animation-human-spell-simple-shoot.blend", False),
    "two_hand_blast": ("rigs/human/abilities/animation-human-two-hand-blast.blend", False),
    "zombie_yell": ("rigs/human/zombie/animation-human-zombie-yell.blend", False),
    "power_burst": ("rigs/human/abilities/animation-human-power-burst.blend", False),
    "reject": ("rigs/human/emotions/animation-human-reject.blend", False),
    # Hits & Deaths
    "hit_chest": ("rigs/human/combat/reactions/animation-human-hit-chest.blend", False),
    "hit_head": ("rigs/human/combat/reactions/animation-human-hit-head.blend", False),
    "death_a": ("rigs/human/combat/reactions/animation-human-death-A.blend", False),
    "death_b": ("rigs/human/combat/reactions/animation-human-death-B.blend", False),
    "death_c": ("rigs/human/combat/reactions/animation-human-death-C.blend", False),
    "death_d": ("rigs/human/combat/reactions/animation-human-death-d.blend", False),
}


def r5(seq) -> list[float]:
    return [round(float(x), 5) for x in seq]


def download_file(url: str, dst: pathlib.Path) -> pathlib.Path:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and dst.stat().st_size > 1000:
        return dst
    urllib.request.urlretrieve(url, str(dst))
    if dst.stat().st_size < 1000:
        raise RuntimeError(f"Download too small ({dst.stat().st_size}B): {url}")
    return dst


def fetch_all_sources() -> tuple[pathlib.Path, dict[str, pathlib.Path], pathlib.Path]:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    rig_dst = CACHE_DIR / "rig-human.blend"
    fp_dst = CACHE_DIR / "Arms.fbx"

    # Reuse /tmp/anim_research downloads if already present
    existing_rig = pathlib.Path("/tmp/anim_research/rig-human.blend")
    if existing_rig.exists() and not rig_dst.exists():
        rig_dst.write_bytes(existing_rig.read_bytes())
    existing_fp = pathlib.Path("/tmp/anim_research/fp/Arms.fbx")
    if existing_fp.exists() and not fp_dst.exists():
        fp_dst.write_bytes(existing_fp.read_bytes())

    jobs: list[tuple[str, pathlib.Path]] = [
        (M2M_RAW + "rigs/rig-human.blend", rig_dst),
        (ITSPOGLE_RAW + "Assets/Models/Arms.fbx", fp_dst),
    ]
    clip_paths: dict[str, pathlib.Path] = {}
    for key, (rel, _) in M2M_CLIPS.items():
        dst = CACHE_DIR / "m2m" / pathlib.Path(rel).name
        existing = pathlib.Path("/tmp/anim_research/m2m_blends") / pathlib.Path(rel).name
        if existing.exists() and not dst.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(existing.read_bytes())
        clip_paths[key] = dst
        jobs.append((M2M_RAW + rel, dst))

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        futs = [ex.submit(download_file, url, dst) for url, dst in jobs]
        for f in futs:
            f.result()

    # Also grab upstream CC0 license text
    lic_dst = OUT_DIR / "LICENSE_CC0.txt"
    download_file(M2M_RAW + "LICENSE", lic_dst)
    return rig_dst, clip_paths, fp_dst


def sample_m2m_bank(rig_path: pathlib.Path, clip_paths: dict[str, pathlib.Path]) -> dict:
    # 1. Extract exact rest skeleton from rig-human.blend
    bpy.ops.wm.open_mainfile(filepath=str(rig_path))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rest = {}
    for bn in M2M_BONES:
        b = arm.data.bones[bn]
        q = b.matrix_local.to_3x3().to_quaternion().normalized()
        rest[bn] = {
            "head": r5(b.head_local),
            "tail": r5(b.tail_local),
            "quat": r5((q.w, q.x, q.y, q.z)),
        }

    # 2. Sample every clip cleanly via open_mainfile + relinked rig-human.blend (preserves IK/FK switches)
    clips = {}
    for key, (rel, is_loop) in M2M_CLIPS.items():
        p = clip_paths[key]
        bpy.ops.wm.open_mainfile(filepath=str(p))
        for lib in bpy.data.libraries:
            lib.filepath = str(rig_path)
            lib.reload()
        arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
        if arm is None or arm.animation_data is None or arm.animation_data.action is None:
            raise RuntimeError(f"No active armature action in {p}")
        act = arm.animation_data.action
        orig_fps = float(bpy.context.scene.render.fps or 24)
        f0 = float(act.frame_range[0])
        f1 = float(act.frame_range[1])
        # Shift negative start frame (e.g. -1..39) smoothly to 0..duration
        dur = max(1.0 / orig_fps, (f1 - f0) / orig_fps)
        n_frames = max(2, int(round(dur * TARGET_FPS)))

        frames = []
        for i in range(n_frames + 1):
            u = i / n_frames
            src_f = f0 + u * (f1 - f0)
            frame_int = int(src_f)
            subframe = src_f - frame_int
            bpy.context.scene.frame_set(frame_int, subframe=subframe)
            bpy.context.view_layer.update()

            b_quats = {}
            for bn in M2M_BONES:
                pb = arm.pose.bones[bn]
                q = pb.matrix.to_3x3().to_quaternion().normalized()
                b_quats[bn] = r5((q.w, q.x, q.y, q.z))

            foot_zs = []
            for fb in ("foot_l", "foot_r", "ball_l", "ball_r"):
                if fb in arm.pose.bones:
                    pb = arm.pose.bones[fb]
                    foot_zs.append(pb.head.z)
                    foot_zs.append(pb.tail.z)

            frames.append({
                "pelvis_pos": r5(arm.pose.bones["pelvis"].head),
                "head_pos": r5(arm.pose.bones["head"].head),
                "hand_r_pos": r5(arm.pose.bones["hand_r"].head),
                "hand_l_pos": r5(arm.pose.bones["hand_l"].head),
                "foot_min_z": round(float(min(foot_zs)), 5),
                "bones": b_quats,
            })

        clips[key] = {
            "name": act.name,
            "source": f"Mesh2Motion/mesh2motion-assets@{M2M_COMMIT[:10]}:{rel}",
            "license": "CC0-1.0",
            "orig_fps": orig_fps,
            "fps": TARGET_FPS,
            "loop": is_loop,
            "duration": round(n_frames / TARGET_FPS, 4),
            "frames": frames,
        }
        print(f"[m2m] baked {key:30s} ({n_frames + 1:3d}f @ {TARGET_FPS}fps, dur={n_frames / TARGET_FPS:.2f}s)")

    return {
        "schema": "premade_human_bank_v1",
        "source_repo": "https://github.com/Mesh2Motion/mesh2motion-assets",
        "commit": M2M_COMMIT,
        "license": "CC0-1.0",
        "fps": TARGET_FPS,
        "rest": rest,
        "clips": clips,
    }


def sample_itspogle_fp_bank(fp_path: pathlib.Path) -> dict:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(fp_path))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.animation_data_create()

    keep_bones = [
        "Chest",
        "Shoulder.L", "UpperArm.L", "LowerArm.L", "Wrist.L",
        "Shoulder.R", "UpperArm.R", "LowerArm.R", "Wrist.R",
    ]
    rest = {}
    for bn in keep_bones:
        b = arm.data.bones[bn]
        mw = arm.matrix_world
        h = mw @ b.head_local
        t = mw @ b.tail_local
        q = (mw.to_3x3() @ b.matrix_local.to_3x3()).to_quaternion().normalized()
        rest[bn] = {"head": r5(h), "tail": r5(t), "quat": r5((q.w, q.x, q.y, q.z))}

    clips = {}
    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        short = act.name.split("|")[-1].lower().replace(".", "_")
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and len(act.slots) > 0:
            arm.animation_data.action_slot = act.slots[0]
        f0 = float(act.frame_range[0])
        f1 = float(act.frame_range[1])
        orig_fps = float(bpy.context.scene.render.fps or 24)
        dur = max(1.0 / orig_fps, (f1 - f0) / orig_fps)
        n_frames = max(2, int(round(dur * TARGET_FPS)))
        frames = []
        for i in range(n_frames + 1):
            u = i / n_frames
            src_f = f0 + u * (f1 - f0)
            fi = int(src_f)
            bpy.context.scene.frame_set(fi, subframe=src_f - fi)
            bpy.context.view_layer.update()
            bones_out = {}
            for bn in keep_bones:
                m = arm.matrix_world @ arm.pose.bones[bn].matrix
                q = m.to_3x3().to_quaternion().normalized()
                bones_out[bn] = {
                    "pos": r5(m.translation),
                    "quat": r5((q.w, q.x, q.y, q.z)),
                }
            frames.append({"bones": bones_out})
        clips[short] = {
            "name": act.name,
            "source": f"ItsPogle/Unity-First-Person-Melee@{ITSPOGLE_COMMIT[:10]}:Assets/Models/Arms.fbx",
            "license": "CC0-1.0",
            "fps": TARGET_FPS,
            "duration": round(n_frames / TARGET_FPS, 4),
            "frames": frames,
        }
        print(f"[fp]  baked {short:30s} ({n_frames + 1:3d}f @ {TARGET_FPS}fps)")

    return {
        "schema": "premade_fp_bank_v1",
        "source_repo": "https://github.com/ItsPogle/Unity-First-Person-Melee",
        "commit": ITSPOGLE_COMMIT,
        "license": "CC0-1.0",
        "fps": TARGET_FPS,
        "rest": rest,
        "clips": clips,
    }


def write_sources_doc(m2m_bank: dict, fp_bank: dict) -> None:
    lines = [
        "# Premade Free CC0 Animation Sources (`trial/premade-animations`)",
        "",
        "All premade animations baked into this directory are **CC0 1.0 Universal (Public Domain)**,",
        "allowing free commercial & open-source use, modification, and redistribution with zero restrictions.",
        "See [`LICENSE_CC0.txt`](LICENSE_CC0.txt).",
        "",
        "## 1. Mesh2Motion Humanoid Animation Library (includes Quaternius UAL 1 & 2)",
        f"- **Repository:** <https://github.com/Mesh2Motion/mesh2motion-assets>",
        f"- **Pinned Commit:** `{M2M_COMMIT}`",
        "- **License:** CC0 1.0 Universal (original animations by Quaternius & Mesh2Motion contributors)",
        f"- **Baked Bank:** `m2m_human_bank.json.gz` ({len(m2m_bank['clips'])} clips @ {TARGET_FPS} FPS)",
        "",
        "## 2. ItsPogle First-Person Melee Arms Pack",
        f"- **Repository:** <https://github.com/ItsPogle/Unity-First-Person-Melee>",
        f"- **Pinned Commit:** `{ITSPOGLE_COMMIT}`",
        "- **License:** CC0 1.0 Universal",
        f"- **Baked Bank:** `itspogle_fp_bank.json.gz` ({len(fp_bank['clips'])} clips @ {TARGET_FPS} FPS)",
        "",
        "## Rebuilding the Banks",
        "```bash",
        "./.tools/bin/blender --background --python scripts/fetch-premade-anims.py",
        "```",
        "",
        "## Included Humanoid Clips (`m2m_human_bank.json.gz`)",
        "",
        "| Key | Upstream Action | Duration | Loop | Source Path |",
        "|---|---|---|---|---|",
    ]
    for k, c in sorted(m2m_bank["clips"].items()):
        src = c["source"].split(":", 1)[1]
        lines.append(f"| `{k}` | {c['name']} | {c['duration']:.2f}s | {'yes' if c['loop'] else 'no'} | `{src}` |")
    lines += [
        "",
        "## Included First-Person Clips (`itspogle_fp_bank.json.gz`)",
        "",
        "| Key | Upstream Action | Duration |",
        "|---|---|---|",
    ]
    for k, c in sorted(fp_bank["clips"].items()):
        lines.append(f"| `{k}` | `{c['name']}` | {c['duration']:.2f}s |")
    (OUT_DIR / "SOURCES.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rig_path, clip_paths, fp_path = fetch_all_sources()
    m2m_bank = sample_m2m_bank(rig_path, clip_paths)
    fp_bank = sample_itspogle_fp_bank(fp_path)

    m2m_out = OUT_DIR / "m2m_human_bank.json.gz"
    with gzip.open(m2m_out, "wt", encoding="utf-8") as fh:
        json.dump(m2m_bank, fh, separators=(",", ":"))
    fp_out = OUT_DIR / "itspogle_fp_bank.json.gz"
    with gzip.open(fp_out, "wt", encoding="utf-8") as fh:
        json.dump(fp_bank, fh, separators=(",", ":"))

    write_sources_doc(m2m_bank, fp_bank)
    print(f"[done] {m2m_out} ({m2m_out.stat().st_size // 1024} KB), {fp_out} ({fp_out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
