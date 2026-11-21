"""Premade CC0 Humanoid Animation Retargeting Engine (FB-025 / D-060).

Retargets curated CC0 1.0 animations baked from Mesh2Motion (incorporating Quaternius
Universal Animation Library 1 & 2 + Mesh2Motion community/mocap clips) in
`art/premade_anims/m2m_human_bank.json.gz` onto every rigged character in `build_characters.py`
(`crawler`, `draugr`, `bone_archer`, `goblin`, `iron_warden`, `vendor`).

Zero AI-generated procedural keyframe poses: every clip transfers genuine human-authored /
mocap-derived motion via rest-pose-compensated world-space orientation retargeting
(T-pose -> A-pose swing removal), proportional pelvis scaling, automatic floor contact
grounding, optional 2H weapon off-hand shaft tracking, and exact left<->right mirroring
for symmetric off-hand / right-hand clips.
"""

from __future__ import annotations

import gzip
import json
import math
import pathlib
from typing import Any

import bpy
from mathutils import Matrix, Quaternion, Vector

from . import rig

FPS = 30
BANK_PATH = pathlib.Path(__file__).resolve().parents[2] / "premade_anims" / "m2m_human_bank.json.gz"

_BANK_CACHE: dict | None = None

# Target bone (dclib/rig.py) -> source bone (Mesh2Motion rig-human.blend)
# Note: spine blends spine_01 -> spine_02 (50%), chest uses spine_03 directly in world space.
BONE_MAP: dict[str, str] = {
    "hips": "pelvis",
    "spine": "spine_01",
    "chest": "spine_03",
    "neck": "neck_01",
    "head": "head",
    "clavicle_l": "clavicle_l",
    "upper_arm_l": "upperarm_l",
    "forearm_l": "lowerarm_l",
    "hand_l": "hand_l",
    "clavicle_r": "clavicle_r",
    "upper_arm_r": "upperarm_r",
    "forearm_r": "lowerarm_r",
    "hand_r": "hand_r",
    "thigh_l": "thigh_l",
    "shin_l": "calf_l",
    "foot_l": "foot_l",
    "thigh_r": "thigh_r",
    "shin_r": "calf_r",
    "foot_r": "foot_r",
}

# Topological order (parents before children)
TOPO_BONES = [
    "hips", "spine", "chest", "neck", "head",
    "clavicle_l", "upper_arm_l", "forearm_l", "hand_l",
    "clavicle_r", "upper_arm_r", "forearm_r", "hand_r",
    "thigh_l", "shin_l", "foot_l",
    "thigh_r", "shin_r", "foot_r",
]

_MX = Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0))


def load_bank() -> dict:
    global _BANK_CACHE
    if _BANK_CACHE is None:
        if not BANK_PATH.exists():
            raise FileNotFoundError(
                f"Missing premade animation bank: {BANK_PATH}. "
                "Run: ./.tools/bin/blender --background --python scripts/fetch-premade-anims.py"
            )
        with gzip.open(BANK_PATH, "rt", encoding="utf-8") as fh:
            _BANK_CACHE = json.load(fh)
    return _BANK_CACHE


def _q(seq) -> Quaternion:
    return Quaternion((seq[0], seq[1], seq[2], seq[3])).normalized()


def _v(seq) -> Vector:
    return Vector((seq[0], seq[1], seq[2]))


def _slerp(qa: Quaternion, qb: Quaternion, t: float) -> Quaternion:
    if qa.dot(qb) < 0.0:
        qb = -qb
    return qa.slerp(qb, t).normalized()


def _interp_frame(frames: list[dict], u: float) -> dict:
    """Linearly/slerp-interpolates a bank clip at normalized time u in [0, 1]."""
    n = len(frames) - 1
    if n <= 0:
        return frames[0]
    pos = max(0.0, min(float(n), u * n))
    i0 = int(math.floor(pos))
    i1 = min(n, i0 + 1)
    t = pos - i0
    if t <= 1e-6 or i0 == i1:
        return frames[i0]
    f0, f1 = frames[i0], frames[i1]
    bones = {}
    for bn, q0s in f0["bones"].items():
        q = _slerp(_q(q0s), _q(f1["bones"][bn]), t)
        bones[bn] = [q.w, q.x, q.y, q.z]
    return {
        "pelvis_pos": list(_v(f0["pelvis_pos"]).lerp(_v(f1["pelvis_pos"]), t)),
        "head_pos": list(_v(f0["head_pos"]).lerp(_v(f1["head_pos"]), t)),
        "hand_r_pos": list(_v(f0["hand_r_pos"]).lerp(_v(f1["hand_r_pos"]), t)),
        "hand_l_pos": list(_v(f0["hand_l_pos"]).lerp(_v(f1["hand_l_pos"]), t)),
        "foot_min_z": f0["foot_min_z"] + (f1["foot_min_z"] - f0["foot_min_z"]) * t,
        "bones": bones,
    }


def _slice_clip(clip: dict, t0: float = 0.0, t1: float = 1.0) -> list[dict]:
    """Sub-range of frames from a bank clip."""
    fs = clip["frames"]
    n = len(fs) - 1
    i0 = max(0, min(n, int(round(t0 * n))))
    i1 = max(i0 + 1, min(n, int(round(t1 * n))))
    return fs[i0:i1 + 1]


def _blend_frame(fa: dict, fb: dict, t: float) -> dict:
    bones = {}
    for bn, qa in fa["bones"].items():
        q = _slerp(_q(qa), _q(fb["bones"][bn]), t)
        bones[bn] = [q.w, q.x, q.y, q.z]
    return {
        "pelvis_pos": list(_v(fa["pelvis_pos"]).lerp(_v(fb["pelvis_pos"]), t)),
        "head_pos": list(_v(fa["head_pos"]).lerp(_v(fb["head_pos"]), t)),
        "hand_r_pos": list(_v(fa["hand_r_pos"]).lerp(_v(fb["hand_r_pos"]), t)),
        "hand_l_pos": list(_v(fa["hand_l_pos"]).lerp(_v(fb["hand_l_pos"]), t)),
        "foot_min_z": fa["foot_min_z"] + (fb["foot_min_z"] - fa["foot_min_z"]) * t,
        "bones": bones,
    }


def _concat_clips(segments: list[list[dict]], blend_frames: int = 3) -> list[dict]:
    """Concatenates multiple premade clip segments with smooth slerp cross-fades."""
    if not segments:
        return []
    out = list(segments[0])
    for seg in segments[1:]:
        if not seg:
            continue
        k = min(blend_frames, len(out) - 1, len(seg) - 1)
        if k > 0:
            for j in range(k):
                t = (j + 1) / (k + 1)
                out[len(out) - k + j] = _blend_frame(out[len(out) - k + j], seg[j], t)
            out.extend(seg[k:])
        else:
            out.extend(seg)
    return out


def _make_cyclic_seamless(frames: list[dict], seam_frames: int = 3) -> list[dict]:
    """Gently cross-blends the last few frames back toward frame 0 so cyclic loops never pop."""
    out = list(frames)
    n = len(out)
    k = min(seam_frames, max(0, n // 6))
    if k <= 0:
        return out
    for j in range(k):
        t = (j + 1) / (k + 1)
        idx = n - 1 - k + j
        out[idx] = _blend_frame(out[idx], out[0], t)
    out[-1] = out[0]
    return out


def _flip_name(n: str) -> str:
    if n.endswith("_l"):
        return n[:-2] + "_r"
    if n.endswith("_r"):
        return n[:-2] + "_l"
    return n


def _mirror_current_pose(arm_ob) -> None:
    """Exact left<->right mirror of the whole posed armature."""
    bpy.context.view_layer.update()
    cur = {pb.name: pb.matrix.copy() for pb in arm_ob.pose.bones}
    rest = {b.name: b.matrix_local.copy() for b in arm_ob.data.bones}
    tgt = {}
    for n, mat in cur.items():
        o = _flip_name(n)
        if o not in rest:
            o = n
        tgt[o] = _MX @ mat @ rest[n].inverted() @ _MX @ rest[o]

    def depth(pb):
        d = 0
        p = pb.parent
        while p is not None:
            d += 1
            p = p.parent
        return d

    levels: dict[int, list] = {}
    for pb in arm_ob.pose.bones:
        levels.setdefault(depth(pb), []).append(pb)
    for d in sorted(levels):
        for pb in levels[d]:
            pb.rotation_mode = "QUATERNION"
            pb.matrix = tgt[pb.name]
        bpy.context.view_layer.update()


class RetargetContext:
    """Precomputes rest-pose calibration matrices between the CC0 Mesh2Motion source rig
    and a specific target character armature (`crawler`, `draugr`, `goblin`, `iron_warden`, etc.).
    """

    def __init__(self, arm_ob, bank: dict, style: dict, grip_r=None, grip_l=None):
        self.arm = arm_ob
        self.bank = bank
        self.style = style
        self.grip_r = grip_r
        self.grip_l = grip_l
        self.grip_r_local = rig.grip_rest_local_matrix(arm_ob, grip_r) if grip_r else None
        self.grip_l_local = rig.grip_rest_local_matrix(arm_ob, grip_l) if grip_l else None

        src_rest = bank["rest"]
        b = arm_ob.data.bones

        self.src_hip_pos = _v(src_rest["pelvis"]["head"])
        self.src_rest_foot_z = min(
            src_rest["foot_l"]["tail"][2],
            src_rest["foot_r"]["tail"][2],
            src_rest["ball_l"]["tail"][2],
            src_rest["ball_r"]["tail"][2],
        )
        self.tgt_hip_z = b["hips"].head_local.z
        self.tgt_scale = b["head"].tail_local.z / 1.84
        self.hip_scale = self.tgt_hip_z / max(0.1, self.src_hip_pos.z)
        self.tgt_rest_foot_z = min(
            b["foot_l"].tail_local.z,
            b["foot_r"].tail_local.z,
        )

        # Precompute per-bone world-space rest alignment matrix:
        #   R_tgt_world(f) = R_src_world(f) @ C[bone]
        # where C[bone] = R_src_rest^T @ R_tgt_canonical_tpose
        self.corr: dict[str, Matrix] = {}
        self.tgt_rest_rot: dict[str, Matrix] = {}
        self.tgt_parent: dict[str, str | None] = {}

        # Optional gentle arm-out opening on broad-chested / armoured rigs so arms never clip cuirass
        arm_open_deg = float(style.get("arm_open_deg", 6.0))
        # Preserve partial character hunch on spine/chest for hunched archetypes (draugr, goblin)
        hunch_keep = float(style.get("hunch_keep", 0.35))

        for tbone, sbone in BONE_MAP.items():
            tb = b[tbone]
            r_tgt_rest = tb.matrix_local.to_3x3()
            self.tgt_rest_rot[tbone] = r_tgt_rest
            self.tgt_parent[tbone] = tb.parent.name if tb.parent else None

            sr = src_rest[sbone]
            r_src_rest = _q(sr["quat"]).to_matrix()
            d_src = (_v(sr["tail"]) - _v(sr["head"])).normalized()
            d_tgt = (tb.tail_local - tb.head_local).normalized()

            # Minimal swing from target rest axis to source T-pose axis
            q_swing = d_tgt.rotation_difference(d_src)
            if tbone in ("spine", "chest") and hunch_keep > 0.0:
                # Keep a fraction of the character's built-in hunch posture
                q_swing = Quaternion((1, 0, 0, 0)).slerp(q_swing, 1.0 - hunch_keep)

            r_tgt_tpose = q_swing.to_matrix() @ r_tgt_rest

            # Gentle shoulder opening on arm chain so thick plate/fur doesn't clip upper arms
            if arm_open_deg != 0.0 and tbone in ("upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r"):
                sgn = 1.0 if tbone.endswith("_l") else -1.0
                # Opening arms slightly outward around world -Y lifts them away from torso
                r_open = Matrix.Rotation(math.radians(sgn * arm_open_deg), 3, "Y")
                r_tgt_tpose = r_open @ r_tgt_tpose

            self.corr[tbone] = r_src_rest.transposed() @ r_tgt_tpose

        # Hand twist alignment: adjust hand_r / hand_l local roll around the bone axis (+Y)
        # so GripR (+Z blade axis, +X cutting edge) aligns with Mesh2Motion's weapon grip.
        self.hand_r_roll = Matrix.Rotation(math.radians(float(style.get("hand_r_roll_deg", 0.0))), 3, "Y")
        self.hand_l_roll = Matrix.Rotation(math.radians(float(style.get("hand_l_roll_deg", 0.0))), 3, "Y")

    def apply_frame(
        self,
        frame: dict,
        ground_mode: str = "stand",
        lock_2h_offhand: str | bool = False,
        min_weapon_tip_z: float = 0.0,
        shield_guard_l: bool = False,
        bow_pose: bool = False,
        dual_guard_l: bool = False,
        extra_hand_r_rot: Matrix | None = None,
        extra_hand_l_rot: Matrix | None = None,
        keep_pelvis_xy: float = 0.75,
        zero_pelvis_xy: bool = False,
    ) -> None:
        """Applies one sampled Mesh2Motion frame to `self.arm` in armature space."""
        arm = self.arm
        rig.reset_pose(arm)

        # 1. Pelvis translation (proportionally scaled)
        src_pel = _v(frame["pelvis_pos"])
        dp = (src_pel - self.src_hip_pos) * self.hip_scale
        if zero_pelvis_xy:
            dp.x = 0.0
            dp.y = 0.0
        else:
            dp.x *= keep_pelvis_xy
            dp.y *= keep_pelvis_xy
        rig.set_bone_world_delta(arm, "hips", dp)

        # 2. Propagate world-space rotations analytically in topological order
        world_rot: dict[str, Matrix] = {"root": arm.data.bones["root"].matrix_local.to_3x3()}
        fbones = frame["bones"]
        for tbone in TOPO_BONES:
            sbone = BONE_MAP[tbone]
            if tbone == "spine" and "spine_02" in fbones:
                q_src = _slerp(_q(fbones["spine_01"]), _q(fbones["spine_02"]), 0.45)
            else:
                q_src = _q(fbones[sbone])
            r_tgt_world = q_src.to_matrix() @ self.corr[tbone]

            if tbone == "hand_r":
                r_tgt_world = r_tgt_world @ self.hand_r_roll
                if extra_hand_r_rot is not None:
                    r_tgt_world = r_tgt_world @ extra_hand_r_rot
            elif tbone == "hand_l":
                r_tgt_world = r_tgt_world @ self.hand_l_roll
                if extra_hand_l_rot is not None:
                    r_tgt_world = r_tgt_world @ extra_hand_l_rot

            par_name = self.tgt_parent[tbone]
            r_rest = self.tgt_rest_rot[tbone]
            if par_name is None or par_name not in world_rot:
                r_zero = r_rest
            else:
                r_par = world_rot[par_name]
                r_par_rest = arm.data.bones[par_name].matrix_local.to_3x3()
                r_zero = r_par @ r_par_rest.transposed() @ r_rest

            pb = arm.pose.bones[tbone]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (r_zero.transposed() @ r_tgt_world).to_quaternion().normalized()
            world_rot[tbone] = r_tgt_world

        bpy.context.view_layer.update()

        # 3. Ground contact / floor flush pass
        if ground_mode == "stand":
            tgt_foot_z = min(
                arm.pose.bones["foot_l"].head.z,
                arm.pose.bones["foot_l"].tail.z,
                arm.pose.bones["foot_r"].head.z,
                arm.pose.bones["foot_r"].tail.z,
            )
            src_lift = max(0.0, float(frame["foot_min_z"]) - self.src_rest_foot_z)
            desired_foot_z = self.tgt_rest_foot_z + src_lift * self.hip_scale
            dz = desired_foot_z - tgt_foot_z
            dp.z += dz
            rig.set_bone_world_delta(arm, "hips", dp)
            bpy.context.view_layer.update()
        elif ground_mode == "death":
            # Guarantee corpse sits cleanly above flagstones (never sinks underground)
            min_z = min(
                arm.pose.bones[bn].head.z
                for bn in ("hips", "spine", "chest", "head", "foot_l", "foot_r", "hand_l", "hand_r")
            )
            floor_pad = 0.065 * self.tgt_scale
            if min_z < floor_pad:
                dp.z += (floor_pad - min_z)
                rig.set_bone_world_delta(arm, "hips", dp)
                bpy.context.view_layer.update()

        # 4a. Optional heavy weapon floor clearance (prevents 1.3m-2.8m battleaxe heads from scraping/burying in flagstones)
        if min_weapon_tip_z > 0.0 and self.grip_r_local is not None:
            w_scale = float(self.style.get("weapon_scale", 1.0))
            m_grip_r = arm.pose.bones["hand_r"].matrix @ self.grip_r_local
            grip_r_pos = m_grip_r.to_translation()
            shaft_dir = m_grip_r.to_3x3().col[2].normalized()
            edge_dir = m_grip_r.to_3x3().col[0].normalized()
            tip_len = 0.98 * w_scale
            tip_z = grip_r_pos.z + shaft_dir.z * tip_len
            if tip_z < min_weapon_tip_z:
                need_sz = min(0.85, (min_weapon_tip_z - grip_r_pos.z) / max(0.2, tip_len))
                xy = Vector((shaft_dir.x, shaft_dir.y, 0.0))
                xy_len = xy.length
                horiz = math.sqrt(max(0.01, 1.0 - need_sz * need_sz))
                if xy_len > 1e-4:
                    new_shaft = Vector((xy.x / xy_len * horiz, xy.y / xy_len * horiz, need_sz)).normalized()
                else:
                    new_shaft = Vector((0.0, -horiz, need_sz)).normalized()
                rig.orient_hand_for_grip(arm, "r", self.grip_r_local, shaft_world=new_shaft, edge_world=edge_dir)
                bpy.context.view_layer.update()

        # 4b. Optional 2H battleaxe off-hand shaft lock:
        # On battleaxe.glb, GripR sits at z=0 (lower leather wrap) and the upper leather wrap sits
        # along +shaft_dir (~+0.44 * weapon_scale). Preserves 100% of the premade body/legs/right-arm swing!
        if lock_2h_offhand and self.grip_r_local is not None and self.grip_l_local is not None:
            w_scale = float(self.style.get("weapon_scale", 1.0))
            arm_len_l = (
                (arm.data.bones["upper_arm_l"].tail_local - arm.data.bones["upper_arm_l"].head_local).length
                + (arm.data.bones["forearm_l"].tail_local - arm.data.bones["forearm_l"].head_local).length
            )
            m_grip_r = arm.pose.bones["hand_r"].matrix @ self.grip_r_local
            grip_r_pos = m_grip_r.to_translation()
            if lock_2h_offhand == "polearm_run":
                # In Mesh2Motion polearm_run, hand_r is the lower grip and hand_l is the upper grip:
                # orient GripR +Z directly from right hand toward left hand so the axe head rides UP-LEFT!
                m_grip_l = arm.pose.bones["hand_l"].matrix @ self.grip_l_local
                grip_l_pos = m_grip_l.to_translation()
                d_rl = grip_l_pos - grip_r_pos
                shaft_dir = d_rl.normalized() if d_rl.length > 0.05 else Vector((0.45, -0.35, 0.82)).normalized()
                edge_dir = Vector((0.0, -1.0, 0.15)).normalized()
                grip_r_pos, r_grip_r = rig.orient_hand_for_grip(
                    arm, "r", self.grip_r_local,
                    shaft_world=shaft_dir,
                    edge_world=edge_dir,
                    edge_is_neg_y=False,
                )
                bpy.context.view_layer.update()
            else:
                shaft_dir = m_grip_r.to_3x3().col[2].normalized()
                edge_dir = m_grip_r.to_3x3().col[0].normalized()

            off_dist = min(0.44 * w_scale, 0.68 * arm_len_l)
            sh_l = arm.pose.bones["upper_arm_l"].head.copy()
            max_reach = arm_len_l * 0.94
            # Slide left hand smoothly along +shaft_dir (upper leather wrap) if extreme follow-through stretches arm_l
            best_off = off_dist
            for frac in (1.0, 0.88, 0.76, 0.64, 0.52, 0.40, 0.30):
                cand = grip_r_pos + shaft_dir * (off_dist * frac)
                if (cand - sh_l).length <= max_reach:
                    best_off = off_dist * frac
                    break
            upper_target = grip_r_pos + shaft_dir * best_off
            l_pole = sh_l + Vector((0.38 * self.tgt_scale, 0.28 * self.tgt_scale, -0.32 * self.tgt_scale))
            # Orient left hand onto upper wrap along +shaft_dir
            r_grip_l = rig.basis_from_zx(shaft_dir, edge_dir)
            r_hand_l = r_grip_l @ self.grip_l_local.to_3x3().transposed()
            wrist_l_tgt = upper_target - r_hand_l @ self.grip_l_local.to_translation()
            rig.solve_2bone_ik(arm, "upper_arm_l", "forearm_l", wrist_l_tgt, l_pole, flip_z=True, soft_zone=0.05)
            bpy.context.view_layer.update()
            rig.set_bone_world_rot(arm, "hand_l", r_hand_l)

        # 5. Optional bow orientation polish: keeps bow limbs vertical & back facing forward (-Y)
        # while keeping 100% of the premade body, arm positions, and pull timing!
        if bow_pose and self.grip_l_local is not None:
            rig.orient_hand_for_grip(
                arm, "l", self.grip_l_local,
                shaft_world=Vector((0.04, -0.02, 1.0)),
                edge_world=Vector((0.0, -1.0, 0.0)),
                edge_is_neg_y=True,
            )

        # 6. Optional dual-wield off-hand blade guard alignment (FB-014):
        # Keeps left blade pointing naturally forward-and-up rather than tucked straight back.
        if dual_guard_l and self.grip_l_local is not None:
            rig.orient_hand_for_grip(
                arm, "l", self.grip_l_local,
                shaft_world=Vector((0.22, -0.78, 0.58)),
                edge_world=Vector((0.0, -0.58, -0.82)),
                edge_is_neg_y=False,
            )


def _bake_clip(
    ctx: RetargetContext,
    name: str,
    frames: list[dict],
    target_frames: int | None = None,
    cyclic: bool = False,
    mirror: bool = False,
    ground_mode: str = "stand",
    lock_2h_offhand: str | bool = False,
    min_weapon_tip_z: float = 0.0,
    bow_pose: bool = False,
    dual_guard_l: bool = False,
    zero_pelvis_xy: bool = False,
    extra_hand_r_rot: Matrix | None = None,
    extra_hand_l_rot: Matrix | None = None,
) -> None:
    if cyclic:
        frames = _make_cyclic_seamless(frames, seam_frames=3)
    n_out = target_frames if target_frames is not None else max(2, len(frames) - 1)

    def pose_fn(arm_ob, f, phase):
        fr = _interp_frame(frames, phase)
        ctx.apply_frame(
            fr,
            ground_mode=ground_mode,
            lock_2h_offhand=lock_2h_offhand,
            min_weapon_tip_z=min_weapon_tip_z,
            bow_pose=bow_pose,
            dual_guard_l=dual_guard_l,
            zero_pelvis_xy=zero_pelvis_xy,
            extra_hand_r_rot=extra_hand_r_rot,
            extra_hand_l_rot=extra_hand_l_rot,
        )
        if mirror:
            _mirror_current_pose(arm_ob)

    rig.make_sampled_action(ctx.arm, name, n_out, pose_fn, cyclic=cyclic)


def _clip_frames(bank: dict, key: str, t0: float = 0.0, t1: float = 1.0) -> list[dict]:
    return _slice_clip(bank["clips"][key], t0, t1)


def _verify_death_above_floor(arm_ob) -> None:
    """Sanity check: final death frame sits cleanly above z=0 (no underground corpses)."""
    track = arm_ob.animation_data.nla_tracks.get("death")
    if track is None or not track.strips:
        return
    act = track.strips[0].action
    arm_ob.animation_data.action = act
    if hasattr(arm_ob.animation_data, "action_slot") and hasattr(act, "slots") and len(act.slots) > 0:
        arm_ob.animation_data.action_slot = act.slots[0]
    f_end = int(round(act.frame_range[1]))
    bpy.context.scene.frame_set(f_end)
    bpy.context.view_layer.update()
    for bn in ("hips", "chest", "head"):
        z = arm_ob.pose.bones[bn].head.z
        assert z >= 0.04, f"{arm_ob.name} death final {bn} sank underground (z={z:.3f}m)"
    arm_ob.animation_data.action = None
    rig.reset_pose(arm_ob)


# ---------------------------------------------------------------------------
# Public entry point called by build_characters.py (drop-in replacement for char_anims)
# ---------------------------------------------------------------------------

def animate_character(arm_ob, style: dict, extra=(), grip_r=None, grip_l=None) -> None:
    """Retargets premade CC0 Mesh2Motion/Quaternius clips onto one rigged character."""
    bank = load_bank()
    arch = style.get("archetype", "crawler")

    # Per-archetype calibration tweaks (only rest-pose / shoulder clearance)
    cal = dict(style)
    if arch in ("boss", "iron_warden"):
        cal.setdefault("arm_open_deg", 12.0)
        cal.setdefault("hunch_keep", 0.25)
    elif arch == "goblin":
        cal.setdefault("arm_open_deg", 8.0)
        cal.setdefault("hunch_keep", 0.72)
    elif arch == "draugr":
        cal.setdefault("arm_open_deg", 6.0)
        cal.setdefault("hunch_keep", 0.45)
    elif arch == "vendor":
        cal.setdefault("arm_open_deg", 8.0)
        cal.setdefault("hunch_keep", 0.30)
    else:
        cal.setdefault("arm_open_deg", 6.0)
        cal.setdefault("hunch_keep", 0.20)

    ctx = RetargetContext(arm_ob, bank, cal, grip_r=grip_r, grip_l=grip_l)

    # --- Archetype clip selection (100% premade CC0 clips!) ---
    if arch == "crawler":
        _bake_clip(ctx, "idle", _clip_frames(bank, "idle_a"), cyclic=True)
        _bake_clip(ctx, "idle_combat", _clip_frames(bank, "idle_sword"), cyclic=True)
        _bake_clip(ctx, "walk", _clip_frames(bank, "walk"), cyclic=True, zero_pelvis_xy=True)
        _bake_clip(ctx, "run", _clip_frames(bank, "jog"), cyclic=True, zero_pelvis_xy=True)
        # Snappy 1H slash: 28 frames (0.93s) matching crisp Skyrim feel & existing attack timing
        _bake_clip(ctx, "attack", _clip_frames(bank, "sword_attack"), target_frames=28)
        _bake_clip(ctx, "hit", _clip_frames(bank, "hit_chest"), target_frames=16)
        _bake_clip(ctx, "death", _clip_frames(bank, "death_b"), ground_mode="death")

    elif arch == "draugr":
        _bake_clip(ctx, "idle", _clip_frames(bank, "zombie_idle_2"), cyclic=True, min_weapon_tip_z=0.28)
        _bake_clip(ctx, "idle_combat", _clip_frames(bank, "polearm_idle"), cyclic=True, lock_2h_offhand="upper")
        _bake_clip(ctx, "walk", _clip_frames(bank, "zombie_walk"), cyclic=True, zero_pelvis_xy=True, min_weapon_tip_z=0.30)
        _bake_clip(ctx, "run", _clip_frames(bank, "polearm_run"), cyclic=True, zero_pelvis_xy=True, lock_2h_offhand="polearm_run")
        _bake_clip(ctx, "attack", _clip_frames(bank, "two_handed_horizontal_swing"), target_frames=40, lock_2h_offhand="upper")
        _bake_clip(ctx, "hit", _clip_frames(bank, "hit_chest"), target_frames=16)
        _bake_clip(ctx, "death", _clip_frames(bank, "death_a"), ground_mode="death")

    elif arch == "archer":
        _bake_clip(ctx, "idle", _clip_frames(bank, "idle_subtle"), cyclic=True, bow_pose=True)
        _bake_clip(ctx, "idle_combat", _clip_frames(bank, "bow_pull_hold"), target_frames=36, cyclic=True, bow_pose=True)
        _bake_clip(ctx, "walk", _clip_frames(bank, "walk_cautious"), cyclic=True, zero_pelvis_xy=True, bow_pose=True)
        _bake_clip(ctx, "run", _clip_frames(bank, "jog"), cyclic=True, zero_pelvis_xy=True, bow_pose=True)
        _bake_clip(ctx, "attack", _clip_frames(bank, "dagger_stab"), target_frames=28)
        _bake_clip(ctx, "hit", _clip_frames(bank, "hit_head"), target_frames=16)
        _bake_clip(ctx, "death", _clip_frames(bank, "death_c"), ground_mode="death")

    elif arch == "goblin":
        _bake_clip(ctx, "idle", _clip_frames(bank, "one_hand_weapon_idle"), cyclic=True)
        _bake_clip(ctx, "idle_combat", _clip_frames(bank, "fighting_idle"), cyclic=True)
        _bake_clip(ctx, "walk", _clip_frames(bank, "walk_stealth"), cyclic=True, zero_pelvis_xy=True)
        _bake_clip(ctx, "run", _clip_frames(bank, "run_stealth"), cyclic=True, zero_pelvis_xy=True)
        _bake_clip(ctx, "attack", _clip_frames(bank, "one_hand_slash_combo", 0.0, 0.62), target_frames=28)
        _bake_clip(ctx, "hit", _clip_frames(bank, "hit_chest"), target_frames=16)
        _bake_clip(ctx, "death", _clip_frames(bank, "death_d"), ground_mode="death")

    elif arch == "boss":
        _bake_clip(ctx, "idle", _clip_frames(bank, "polearm_idle"), cyclic=True, lock_2h_offhand="upper")
        _bake_clip(ctx, "idle_combat", _clip_frames(bank, "polearm_idle"), cyclic=True, lock_2h_offhand="upper")
        _bake_clip(ctx, "walk", _clip_frames(bank, "walk_large"), cyclic=True, zero_pelvis_xy=True, min_weapon_tip_z=0.55)
        _bake_clip(ctx, "run", _clip_frames(bank, "polearm_run"), cyclic=True, zero_pelvis_xy=True, lock_2h_offhand="polearm_run")
        _bake_clip(ctx, "attack", _clip_frames(bank, "two_handed_horizontal_swing"), target_frames=40, lock_2h_offhand="upper")
        _bake_clip(ctx, "hit", _clip_frames(bank, "hit_chest"), target_frames=16)
        _bake_clip(ctx, "death", _clip_frames(bank, "death_a"), ground_mode="death")

    elif arch == "vendor":
        _bake_clip(ctx, "idle", _clip_frames(bank, "idle_a"), cyclic=True)
        _bake_clip(ctx, "idle_combat", _clip_frames(bank, "idle_subtle"), cyclic=True)
        _bake_clip(ctx, "walk", _clip_frames(bank, "walk_relaxed"), cyclic=True, zero_pelvis_xy=True)
        _bake_clip(ctx, "run", _clip_frames(bank, "walk_formal"), cyclic=True, zero_pelvis_xy=True)
        _bake_clip(ctx, "attack", _clip_frames(bank, "reject"), target_frames=36)
        _bake_clip(ctx, "hit", _clip_frames(bank, "hit_chest"), target_frames=16)
        _bake_clip(ctx, "death", _clip_frames(bank, "death_b"), ground_mode="death")

    else:
        _bake_clip(ctx, "idle", _clip_frames(bank, "idle_a"), cyclic=True)
        _bake_clip(ctx, "idle_combat", _clip_frames(bank, "idle_sword"), cyclic=True)
        _bake_clip(ctx, "walk", _clip_frames(bank, "walk"), cyclic=True, zero_pelvis_xy=True)
        _bake_clip(ctx, "run", _clip_frames(bank, "jog"), cyclic=True, zero_pelvis_xy=True)
        _bake_clip(ctx, "attack", _clip_frames(bank, "sword_attack"), target_frames=28)
        _bake_clip(ctx, "hit", _clip_frames(bank, "hit_chest"), target_frames=16)
        _bake_clip(ctx, "death", _clip_frames(bank, "death_b"), ground_mode="death")

    # --- Role-specific extra clips (100% premade CC0 clips!) ---
    spell_cast_seq = _concat_clips([
        _clip_frames(bank, "spell_simple_enter"),
        _clip_frames(bank, "spell_simple_shoot"),
    ], blend_frames=3)

    for e in extra:
        if e == "shoot":
            # Full archer draw -> hold -> release sequence (~46 frames, release at ~1.20s)
            seq = _concat_clips([
                _clip_frames(bank, "bow_pull"),
                _clip_frames(bank, "bow_pull_hold"),
                _clip_frames(bank, "bow_release"),
            ], blend_frames=2)
            _bake_clip(ctx, "shoot", seq, target_frames=46, bow_pose=True)
        elif e == "roar":
            _bake_clip(ctx, "roar", _clip_frames(bank, "zombie_yell"), target_frames=60, min_weapon_tip_z=0.55)
        elif e == "slam":
            _bake_clip(ctx, "slam", _clip_frames(bank, "two_handed_overhead_slam"), target_frames=44, lock_2h_offhand="upper", min_weapon_tip_z=0.14)
        elif e == "talk":
            _bake_clip(ctx, "talk", _clip_frames(bank, "idle_talking"), cyclic=True)
        elif e == "block":
            _bake_clip(ctx, "block", _clip_frames(bank, "idle_shield"), cyclic=True)
        elif e == "cast":
            # Mesh2Motion's Spell_Simple_Enter/Shoot thrusts the LEFT hand forward!
            _bake_clip(ctx, "cast", spell_cast_seq, target_frames=32)
        elif e == "cast_r":
            # Mirror left-hand premade cast -> right hand thrusts forward cleanly
            _bake_clip(ctx, "cast_r", spell_cast_seq, target_frames=32, mirror=True)
        elif e == "cast_dual":
            # Lead-in from idle into Mesh2Motion's Two-hand Blast (both palms thrust forward!)
            dual_seq = _concat_clips([
                _clip_frames(bank, "idle_a", 0.0, 0.15),
                _clip_frames(bank, "two_hand_blast"),
                _clip_frames(bank, "two_hand_blast"),
                _clip_frames(bank, "idle_a", 0.0, 0.15),
            ], blend_frames=3)
            _bake_clip(ctx, "cast_dual", dual_seq, target_frames=32)
        elif e == "dual":
            # Dual-wield set (FB-014):
            # - idle_dual: fighting guard with both blades pointed cleanly forward-and-up
            # - attack_dual: right hand swings (one_hand_slash_combo first slash), left stays on guard
            # - attack_l: exact mirror of attack_dual so left blade swings while right holds guard
            _bake_clip(ctx, "idle_dual", _clip_frames(bank, "fighting_idle"), cyclic=True, dual_guard_l=True)
            dw_right = _clip_frames(bank, "one_hand_slash_combo", 0.0, 0.65)
            _bake_clip(ctx, "attack_dual", dw_right, target_frames=28)
            _bake_clip(ctx, "attack_l", dw_right, target_frames=28, mirror=True)
        elif e == "bow_draw":
            _bake_clip(ctx, "bow_draw", _clip_frames(bank, "bow_pull"), target_frames=24, bow_pose=True)
        elif e == "draw_hold":
            _bake_clip(ctx, "draw_hold", _clip_frames(bank, "bow_pull_hold"), target_frames=36, cyclic=True, bow_pose=True)
        elif e == "bow_shoot":
            _bake_clip(ctx, "bow_shoot", _clip_frames(bank, "bow_release"), target_frames=22, bow_pose=True)
        elif e == "attack_2h":
            _bake_clip(ctx, "attack_2h", _clip_frames(bank, "two_handed_horizontal_swing"), target_frames=40, lock_2h_offhand="upper")

    _verify_death_above_floor(arm_ob)
