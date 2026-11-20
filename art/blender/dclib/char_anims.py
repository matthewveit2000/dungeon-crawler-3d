"""Biomechanical character animation library (30 FPS, quaternion-sampled, 2-bone IK + ground contact).

Every character animation is authored in armature space (+X left, -Y forward, +Z up, floor at z=0)
relative to each rig's true skeleton proportions so 1.25m goblins, 1.84m crawlers and 2.95m bosses
all share physically grounded feet, zero foot sliding, locked 2-hand weapon grips, authentic bow
draws, weighty kinetic-chain attacks, and corpses that settle flush on the dungeon flagstones.
"""

from __future__ import annotations

import math

import bpy
from mathutils import Matrix, Vector

from . import rig

FPS = 30


# ---------------------------------------------------------------------------
# Skeleton measurement & low-level rig helpers
# ---------------------------------------------------------------------------

class RigMetrics:
    """Measured rest landmarks for one armature so animations scale cleanly to any height/hunch."""

    def __init__(self, arm_ob, grip_r_ob=None, grip_l_ob=None):
        self.arm = arm_ob
        b = arm_ob.data.bones
        self.ankle_z = b["foot_l"].head_local.z
        self.foot_x = abs(b["foot_l"].head_local.x)
        self.hip_z = b["hips"].head_local.z
        self.hip_x = abs(b["thigh_l"].head_local.x)
        self.sh_z = b["upper_arm_l"].head_local.z
        self.sh_x = abs(b["upper_arm_l"].head_local.x)
        self.sh_y = b["upper_arm_l"].head_local.y
        self.head_z = b["head"].tail_local.z
        self.scale = self.head_z / 1.84
        self.leg_len = b["thigh_l"].length + b["shin_l"].length
        self.arm_len = b["upper_arm_l"].length + b["forearm_l"].length
        self.grip_r_local = rig.grip_rest_local_matrix(arm_ob, grip_r_ob) if grip_r_ob else None
        self.grip_l_local = rig.grip_rest_local_matrix(arm_ob, grip_l_ob) if grip_l_ob else None


_MX = Matrix.Diagonal((-1.0, 1.0, 1.0, 1.0))


def _mx(v) -> Vector:
    """Mirror a character-space vector across the body's mid-plane (X = left/right)."""
    return Vector((-v[0], v[1], v[2]))


def _flip_name(n: str) -> str:
    if n.endswith("_l"):
        return n[:-2] + "_r"
    if n.endswith("_r"):
        return n[:-2] + "_l"
    return n


def _mirror_current_pose(arm_ob):
    """Mirror the whole current pose left<->right (FB-014: left-hand swings and right-hand casts are exact
    mirrors of the authored right-hand swing / left-hand cast). Works whatever the bone rolls are: each bone's
    target is chosen so its skinning deform equals the mirrored deform of its partner bone."""
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


def _mirrored(pose_fn):
    def pose(arm, f, phase):
        pose_fn(arm, f, phase)
        _mirror_current_pose(arm)
    return pose


def _shrug(arm_ob, l_up: float = 0.0, l_fwd: float = 0.0, r_up: float = 0.0, r_fwd: float = 0.0):
    rig.set_bone_euler(arm_ob, "clavicle_l", (l_fwd, 0.0, l_up))
    rig.set_bone_euler(arm_ob, "clavicle_r", (-r_fwd, 0.0, -r_up))


def _set_torso(
    arm_ob,
    hips_delta=(0.0, 0.0, 0.0),
    hips_deg=(0.0, 0.0, 0.0),
    spine_deg=(0.0, 0.0, 0.0),
    chest_deg=(0.0, 0.0, 0.0),
    neck_deg=(0.0, 0.0, 0.0),
    head_deg=(0.0, 0.0, 0.0),
    clav=(0.0, 0.0, 0.0, 0.0),
):
    rig.set_bone_world_delta(arm_ob, "hips", hips_delta)
    rig.set_bone_euler(arm_ob, "hips", hips_deg)
    rig.set_bone_euler(arm_ob, "spine", spine_deg)
    rig.set_bone_euler(arm_ob, "chest", chest_deg)
    rig.set_bone_euler(arm_ob, "neck", neck_deg)
    rig.set_bone_euler(arm_ob, "head", head_deg)
    _shrug(arm_ob, *clav)
    bpy.context.view_layer.update()


def _place_legs(
    m: RigMetrics,
    l_ankle: Vector,
    r_ankle: Vector,
    l_pitch: float = 0.0,
    r_pitch: float = 0.0,
    l_yaw: float = 10.0,
    r_yaw: float = -12.0,
    l_knee_bias: float = 0.16,
    r_knee_bias: float = -0.16,
):
    """Solve both legs via 2-bone IK with knees aimed cleanly forward and feet flat/pitched."""
    arm = m.arm
    s = m.scale
    for side_s, ank, pitch, yaw, kbias in (
        ("l", l_ankle, l_pitch, l_yaw, l_knee_bias),
        ("r", r_ankle, r_pitch, r_yaw, r_knee_bias),
    ):
        ya = math.radians(yaw)
        # Knee pole aims forward along foot yaw direction
        k_fwd = Vector((-math.sin(ya), -math.cos(ya), 0.0))
        hip_p = arm.pose.bones["thigh_" + side_s].head
        mid_z = (hip_p.z + ank.z) * 0.52
        pole = Vector((ank.x + kbias * s, ank.y, mid_z)) + k_fwd * (0.95 * s)
        rig.solve_2bone_ik(arm, "thigh_" + side_s, "shin_" + side_s, ank, pole, flip_z=False, soft_zone=0.04)
    bpy.context.view_layer.update()
    rig.orient_foot_world(arm, "l", toe_pitch_deg=l_pitch, yaw_deg=l_yaw)
    rig.orient_foot_world(arm, "r", toe_pitch_deg=r_pitch, yaw_deg=r_yaw)


def _place_grip_arm(
    m: RigMetrics,
    side_s: str,
    grip_target: Vector,
    shaft_dir: Vector,
    edge_dir: Vector,
    elbow_pole: Vector,
    edge_is_neg_y: bool = False,
):
    """Places a hand so its Grip socket sits exactly at grip_target with shaft_dir & edge_dir."""
    arm = m.arm
    grip_local = m.grip_r_local if side_s == "r" else m.grip_l_local
    if grip_local is None:
        rig.solve_2bone_ik(arm, "upper_arm_" + side_s, "forearm_" + side_s, grip_target, elbow_pole, flip_z=True)
        return grip_target, Matrix.Identity(3)

    z = Vector(shaft_dir).normalized()
    if edge_is_neg_y:
        y = -Vector(edge_dir)
        y = (y - z * y.dot(z)).normalized()
        x = y.cross(z).normalized()
        r_grip = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))
    else:
        r_grip = rig.basis_from_zx(z, Vector(edge_dir))

    r_hand = r_grip @ grip_local.to_3x3().transposed()
    wrist_target = Vector(grip_target) - r_hand @ grip_local.to_translation()
    _, actual_wrist = rig.solve_2bone_ik(
        arm, "upper_arm_" + side_s, "forearm_" + side_s, wrist_target, elbow_pole, flip_z=True, soft_zone=0.04
    )
    bpy.context.view_layer.update()
    rig.set_bone_world_rot(arm, "hand_" + side_s, r_hand)
    actual_grip = actual_wrist + r_hand @ grip_local.to_translation()
    return actual_grip, r_grip


def _place_hand_free(
    m: RigMetrics,
    side_s: str,
    wrist_target: Vector,
    elbow_pole: Vector,
    hand_fwd: Vector,
    palm_hint: Vector,
):
    """Places an unarmed / open hand cleanly via 2-bone IK + world hand orientation."""
    arm = m.arm
    rig.solve_2bone_ik(arm, "upper_arm_" + side_s, "forearm_" + side_s, wrist_target, elbow_pole, flip_z=True, soft_zone=0.04)
    bpy.context.view_layer.update()
    r_hand = rig.basis_from_yz(Vector(hand_fwd), Vector(palm_hint))
    rig.set_bone_world_rot(arm, "hand_" + side_s, r_hand)


def _place_two_hand_axe(
    m: RigMetrics,
    r_grip_pos: Vector,
    shaft_dir: Vector,
    edge_dir: Vector,
    r_elbow_pole: Vector,
    l_elbow_pole: Vector,
    offhand_offset: float,
):
    """Locks right hand on primary lower grip (z=0) and left hand on the upper battleaxe leather wrap (+shaft).
    Automatically verifies both hands stay within anatomical arm reach so the offhand NEVER detaches from the haft!
    """
    sh = Vector(shaft_dir).normalized()
    ed = Vector(edge_dir).normalized()
    actual_r_grip, _ = _place_grip_arm(m, "r", r_grip_pos, sh, ed, r_elbow_pole)
    # Left hand grips higher up the haft (upper leather wrap, +offhand_offset along shaft)
    l_grip_pos = actual_r_grip + sh * offhand_offset
    # Ensure left shoulder can cleanly reach l_grip_pos (if slightly stretched on extreme follow-through, slide modestly along haft)
    sh_l = m.arm.pose.bones["upper_arm_l"].head.copy()
    max_reach = m.arm_len * 0.96
    dist_l = (l_grip_pos - sh_l).length
    if dist_l > max_reach and offhand_offset > 0.0:
        # Slide left hand smoothly down the haft just enough to stay locked on the wood with zero detachment
        best_off = offhand_offset
        for frac in (0.90, 0.80, 0.70, 0.60, 0.50, 0.40):
            cand = actual_r_grip + sh * (offhand_offset * frac)
            if (cand - sh_l).length <= max_reach:
                best_off = offhand_offset * frac
                break
        l_grip_pos = actual_r_grip + sh * best_off
    _place_grip_arm(m, "l", l_grip_pos, sh, ed, l_elbow_pole, edge_is_neg_y=True)
    return actual_r_grip, l_grip_pos


def _weapon_2h_offset(style: dict, m: RigMetrics) -> float:
    """Distance along battleaxe haft from GripR (lower wrap, z=0) to left-hand upper leather wrap (+z)."""
    wscale = float(style.get("weapon_scale", 1.0))
    # Upper leather wrap on battleaxe.glb sits at z = +0.42..+0.60 * wscale; clamp to comfortable two-hand span
    return min(0.45 * wscale, 0.72 * m.arm_len)


def _shield_arm_pose(m: RigMetrics, grip_pos: Vector, shield_face: Vector, shield_up: Vector, elbow_pole: Vector):
    """Orients left hand so a round shield mounted with Y=+90deg inside GripL faces shield_face.
    In GripL: +Z = grip bar (up), +X = outer face of left hand (shield front face!).
    """
    _place_grip_arm(m, "l", grip_pos, shield_up, shield_face, elbow_pole, edge_is_neg_y=False)


# ---------------------------------------------------------------------------
# 1. IDLE (60 frames = 2.0s cyclic) — Relaxed, grounded, character-specific
# ---------------------------------------------------------------------------

def _build_idle(m: RigMetrics, style: dict):
    w = style.get("weapon", "1h")
    s = m.scale
    hunch = float(style.get("hunch", 0.0))
    is_goblin = style.get("archetype") == "goblin"
    is_boss = style.get("archetype") == "boss"
    is_vendor = w == "none"

    def pose(arm, f, phase):
        ang = phase * math.tau
        br = math.sin(ang)                       # primary breathing
        br2 = math.sin(ang - 0.55)               # lagged chest/arm wave
        sway = math.sin(ang + 0.4)               # subtle weight shift (cyclic at 1x)
        look_yaw = math.sin(ang - 0.9) * (10.0 if is_goblin else (6.5 if is_vendor else 4.5))
        look_pitch = math.sin(ang * 2.0 + 0.3) * (3.5 if is_goblin else 1.5)

        crouch = (0.09 if is_goblin else (0.035 if is_boss else 0.025)) * m.leg_len
        hip_dz = -crouch + br * 0.009 * s
        hip_dx = sway * (0.022 if is_goblin else 0.014) * s
        hip_dy = 0.01 * s

        hips_deg = (4.0 if is_goblin else 1.5, -5.0 + sway * 2.0, sway * 1.5)
        spine_deg = ((12.0 if is_goblin else 3.0) + hunch * 0.5 - br * 1.2, 4.0, -sway * 1.2)
        chest_deg = ((8.0 if is_goblin else 1.5) + hunch * 0.35 - br2 * 2.4, 3.0, 0.0)
        clav_up = br2 * 2.2
        _set_torso(arm, (hip_dx, hip_dy, hip_dz), hips_deg, spine_deg, chest_deg,
                   (-hunch * 0.4, 0.0, 0.0), (0.0, 0.0, 0.0), (clav_up, 2.0, clav_up, 2.0))

        # Grounded asymmetric stance
        stance_w = (1.35 if is_boss else (1.25 if is_goblin else 1.15)) * m.foot_x
        l_ank = Vector((stance_w, -0.07 * s, m.ankle_z))
        r_ank = Vector((-stance_w * 1.05, 0.08 * s, m.ankle_z))
        _place_legs(m, l_ank, r_ank, l_yaw=11.0, r_yaw=-16.0)

        if w == "2h":
            # Diagonal Nordic battleaxe carry: right hand on lower grip at right hip, left hand on upper wrap
            # across front-left chest, gleaming bearded axe head poised cleanly in frame above-forward of left shoulder!
            off = _weapon_2h_offset(style, m)
            r_pos = Vector((-0.24 * s, -0.22 * s, m.hip_z - 0.02 * s + br2 * 0.014 * s))
            shaft = Vector((0.60, -0.34, 0.72))
            edge = Vector((-0.20, -0.96, -0.20))
            r_pole = Vector((-0.68 * s, 0.24 * s, m.sh_z - 0.30 * s))
            l_pole = Vector((0.62 * s, 0.16 * s, m.sh_z - 0.26 * s))
            _place_two_hand_axe(m, r_pos, shaft, edge, r_pole, l_pole, off)
        elif w == "bow":
            # Bow held vertically at relaxed left side, right hand relaxed near hip/quiver
            l_pos = Vector((m.sh_x + 0.07 * s, -0.18 * s, m.hip_z + 0.02 * s + br2 * 0.012 * s))
            _place_grip_arm(m, "l", l_pos, Vector((0.06, -0.12, 0.99)), Vector((0.05, -0.99, -0.12)),
                            Vector((m.sh_x + 0.28 * s, 0.30 * s, m.sh_z - 0.26 * s)), edge_is_neg_y=True)
            r_pos = Vector((-m.sh_x - 0.04 * s, -0.05 * s, m.hip_z - 0.06 * s + br2 * 0.01 * s))
            _place_hand_free(m, "r", r_pos, Vector((-m.sh_x - 0.26 * s, 0.28 * s, m.sh_z - 0.24 * s)),
                             Vector((0.12, -0.25, -0.96)), Vector((0.95, -0.2, 0.0)))
        elif is_vendor:
            # Warm welcoming merchant posture — hands relaxed in front of waist/belly
            r_w = Vector((-0.12 * s, -0.22 * s, m.hip_z + 0.06 * s + br2 * 0.012 * s))
            l_w = Vector((0.13 * s, -0.21 * s, m.hip_z + 0.04 * s + br2 * 0.010 * s))
            _place_hand_free(m, "r", r_w, Vector((-m.sh_x - 0.24 * s, 0.16 * s, m.sh_z - 0.32 * s)),
                             Vector((0.65, -0.55, -0.45)), Vector((0.0, -0.6, 0.8)))
            _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.24 * s, 0.16 * s, m.sh_z - 0.32 * s)),
                             Vector((-0.65, -0.55, -0.45)), Vector((0.0, -0.6, 0.8)))
        elif is_goblin:
            # Crouched jittery goblin streamer holding ratings cleaver low-right with bouncy wrist
            bnc = math.sin(ang * 2.0) * 0.018 * s
            r_pos = Vector((-m.sh_x - 0.06 * s, -0.24 * s, m.hip_z - 0.04 * s + bnc))
            _place_grip_arm(m, "r", r_pos, Vector((-0.25, -0.78, 0.56)), Vector((0.08, -0.62, -0.78)),
                            Vector((-m.sh_x - 0.32 * s, 0.26 * s, m.sh_z - 0.18 * s)))
            l_w = Vector((m.sh_x + 0.08 * s, -0.24 * s, m.hip_z + 0.04 * s - bnc * 0.7))
            _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.32 * s, 0.28 * s, m.sh_z - 0.16 * s)),
                             Vector((-0.25, -0.82, -0.45)), Vector((0.0, -0.5, 0.85)))
        else:
            # Crawler (1H sword + shield): relaxed Nordic warrior stance
            r_pos = Vector((-m.sh_x - 0.06 * s, -0.14 * s, m.hip_z - 0.06 * s + br2 * 0.012 * s))
            _place_grip_arm(m, "r", r_pos, Vector((-0.18, -0.78, -0.60)), Vector((0.05, -0.60, 0.80)),
                            Vector((-m.sh_x - 0.28 * s, 0.30 * s, m.sh_z - 0.24 * s)))
            # Shield hangs naturally along outer left flank facing left-forward so armor reads clearly
            l_pos = Vector((m.sh_x + 0.10 * s, -0.16 * s, m.hip_z - 0.02 * s + br2 * 0.01 * s))
            _shield_arm_pose(m, l_pos, Vector((0.82, -0.57, 0.04)), Vector((-0.08, -0.12, 0.99)),
                             Vector((m.sh_x + 0.28 * s, 0.32 * s, m.sh_z - 0.24 * s)))

        # Eyes gently scanning ahead
        ly = math.radians(look_yaw)
        lp = math.radians(look_pitch)
        look_dir = Vector((-math.sin(ly) * math.cos(lp), -math.cos(ly) * math.cos(lp), math.sin(lp)))
        rig.orient_head_look(arm, look_dir, weight=0.82, tilt_deg=sway * (4.0 if is_goblin else 1.5))

    rig.make_sampled_action(m.arm, "idle", 60, pose, cyclic=True)


# ---------------------------------------------------------------------------
# 2. IDLE_COMBAT (60 frames = 2.0s cyclic) — Alert fighter guard
# ---------------------------------------------------------------------------

DUAL_SHAFT = Vector((-0.30, -0.76, 0.58))
DUAL_EDGE = Vector((0.18, -0.65, -0.74))


def _place_offhand_blade(m: RigMetrics, l_pos: Vector, shaft: Vector = None, edge: Vector = None):
    """Left-hand blade held as the mirror of the right-hand guard. In-game the left weapon sits in GripL rotated
    -90 deg about the grip axis, so its cutting edge is GripL -Y (edge_is_neg_y)."""
    s = m.scale
    _place_grip_arm(m, "l", l_pos, _mx(shaft if shaft is not None else DUAL_SHAFT), _mx(edge if edge is not None else DUAL_EDGE),
                    Vector((m.sh_x + 0.34 * s, 0.24 * s, m.sh_z - 0.22 * s)), edge_is_neg_y=True)


def _pose_combat_guard(m: RigMetrics, style: dict, breath: float = 0.0, breath2: float = 0.0):
    """Shared combat-ready base pose (also used as exact frame 0/end for attack/hit/roar/block)."""
    arm = m.arm
    w = style.get("weapon", "1h")
    s = m.scale
    hunch = float(style.get("hunch", 0.0))
    is_goblin = style.get("archetype") == "goblin"
    is_boss = style.get("archetype") == "boss"

    crouch = (0.14 if is_goblin else (0.075 if is_boss else 0.085)) * m.leg_len
    hip_dz = -crouch + breath * 0.012 * s
    torso_yaw = -24.0 if w == "bow" else (-14.0 if w == "2h" else (4.0 if w == "dual" else 16.0))

    hips_deg = (7.0 if is_goblin else 5.0, torso_yaw * 0.55, 0.0)
    spine_deg = ((14.0 if is_goblin else 7.0) + hunch * 0.5 - breath * 1.4, torso_yaw * 0.30, 0.0)
    chest_deg = ((10.0 if is_goblin else 4.0) + hunch * 0.35 - breath2 * 2.2, torso_yaw * 0.25, 0.0)
    _set_torso(arm, (0.0, 0.02 * s, hip_dz), hips_deg, spine_deg, chest_deg,
               (-hunch * 0.35, 0.0, 0.0), (0.0, 0.0, 0.0), (3.0 + breath2 * 1.8, 5.0, 3.0 + breath2 * 1.8, 5.0))

    stance_w = (1.55 if is_boss else 1.35) * m.foot_x
    if w == "bow":
        l_ank = Vector((stance_w * 0.9, -0.18 * s, m.ankle_z))
        r_ank = Vector((-stance_w * 1.15, 0.16 * s, m.ankle_z))
        _place_legs(m, l_ank, r_ank, l_yaw=8.0, r_yaw=-38.0)
    elif w == "2h":
        l_ank = Vector((stance_w * 1.05, 0.14 * s, m.ankle_z))
        r_ank = Vector((-stance_w, -0.18 * s, m.ankle_z))
        _place_legs(m, l_ank, r_ank, l_yaw=26.0, r_yaw=-12.0)
    else:
        l_ank = Vector((stance_w, -0.18 * s, m.ankle_z))
        r_ank = Vector((-stance_w * 1.05, 0.20 * s, m.ankle_z))
        _place_legs(m, l_ank, r_ank, l_yaw=10.0, r_yaw=-28.0)

    if w == "2h":
        # Aggressive two-handed battleaxe combat guard: wide hands on both leather wraps, bearded head poised forward-left!
        off = _weapon_2h_offset(style, m)
        r_pos = Vector((-0.24 * s, -0.26 * s, m.hip_z + 0.02 * s + breath2 * 0.016 * s))
        shaft = Vector((0.52, -0.48, 0.71))
        edge = Vector((-0.22, -0.92, -0.32))
        r_pole = Vector((-0.70 * s, 0.18 * s, m.sh_z - 0.26 * s))
        l_pole = Vector((0.66 * s, 0.14 * s, m.sh_z - 0.22 * s))
        _place_two_hand_axe(m, r_pos, shaft, edge, r_pole, l_pole, off)
    elif w == "bow":
        l_pos = Vector((0.20 * s, -0.42 * s, m.hip_z + 0.16 * s + breath2 * 0.014 * s))
        _place_grip_arm(m, "l", l_pos, Vector((0.08, -0.05, 0.99)), Vector((0.0, -1.0, -0.05)),
                        Vector((m.sh_x + 0.32 * s, 0.10 * s, m.sh_z - 0.20 * s)), edge_is_neg_y=True)
        r_pos = Vector((-0.24 * s, -0.16 * s, m.hip_z + 0.12 * s + breath2 * 0.012 * s))
        _place_hand_free(m, "r", r_pos, Vector((-m.sh_x - 0.35 * s, 0.25 * s, m.sh_z - 0.16 * s)),
                         Vector((0.60, -0.70, 0.25)), Vector((0.0, -0.5, 0.85)))
    elif is_goblin:
        r_pos = Vector((-m.sh_x - 0.05 * s, -0.30 * s, m.hip_z + 0.05 * s + breath2 * 0.02 * s))
        _place_grip_arm(m, "r", r_pos, Vector((-0.12, -0.68, 0.72)), Vector((0.05, -0.73, -0.68)),
                        Vector((-m.sh_x - 0.34 * s, 0.24 * s, m.sh_z - 0.15 * s)))
        l_w = Vector((m.sh_x + 0.06 * s, -0.34 * s, m.hip_z + 0.14 * s - breath2 * 0.015 * s))
        _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.34 * s, 0.22 * s, m.sh_z - 0.12 * s)),
                         Vector((-0.30, -0.90, -0.25)), Vector((0.0, -0.4, 0.9)))
    elif w == "dual":
        # Dual-wield guard (FB-014): both blades poised forward, the left an exact mirror of the right
        r_pos = Vector((-m.sh_x - 0.09 * s, -0.28 * s, m.hip_z + 0.05 * s + breath2 * 0.015 * s))
        _place_grip_arm(m, "r", r_pos, DUAL_SHAFT, DUAL_EDGE, Vector((-m.sh_x - 0.34 * s, 0.24 * s, m.sh_z - 0.22 * s)))
        _place_offhand_blade(m, Vector((m.sh_x + 0.09 * s, -0.28 * s, m.hip_z + 0.05 * s + breath * 0.012 * s)))
    elif w == "none":
        r_w = Vector((-0.18 * s, -0.26 * s, m.hip_z + 0.14 * s))
        l_w = Vector((0.20 * s, -0.28 * s, m.hip_z + 0.16 * s))
        _place_hand_free(m, "r", r_w, Vector((-m.sh_x - 0.26 * s, 0.18 * s, m.sh_z - 0.24 * s)),
                         Vector((0.3, -0.8, 0.4)), Vector((0.0, -0.5, 0.8)))
        _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.26 * s, 0.18 * s, m.sh_z - 0.24 * s)),
                         Vector((-0.3, -0.8, 0.4)), Vector((0.0, -0.5, 0.8)))
    else:
        # 1H Sword + Shield combat guard: sword poised forward-right clearly outside silhouette;
        # shield angled defensively on left flank so chest armor & athletic stance stay crisp and readable!
        r_pos = Vector((-m.sh_x - 0.09 * s, -0.28 * s, m.hip_z + 0.05 * s + breath2 * 0.015 * s))
        _place_grip_arm(m, "r", r_pos, Vector((-0.30, -0.76, 0.58)), Vector((0.18, -0.65, -0.74)),
                        Vector((-m.sh_x - 0.34 * s, 0.24 * s, m.sh_z - 0.22 * s)))
        l_pos = Vector((0.30 * s, -0.26 * s, m.hip_z + 0.06 * s + breath2 * 0.012 * s))
        _shield_arm_pose(m, l_pos, Vector((0.58, -0.81, 0.08)), Vector((-0.10, -0.08, 0.99)),
                         Vector((m.sh_x + 0.34 * s, 0.16 * s, m.sh_z - 0.24 * s)))

    rig.orient_head_look(arm, (0.0, -1.0, -0.04), weight=0.90)


def _build_idle_combat(m: RigMetrics, style: dict, clip_name: str = "idle_combat"):
    def pose(arm, f, phase):
        ang = phase * math.tau
        _pose_combat_guard(m, style, math.sin(ang), math.sin(ang - 0.5))
    rig.make_sampled_action(m.arm, clip_name, 60, pose, cyclic=True)


# ---------------------------------------------------------------------------
# 3. WALK (32f) & RUN (20f) — True Biomechanical Gait with Ground-Locked Feet
# ---------------------------------------------------------------------------

def _foot_gait_sample(phase: float, stride_half: float, lift: float, stance_frac: float, ankle_z: float, foot_x: float):
    """Returns (ankle_pos_Vector, toe_pitch_deg) for one foot over cyclic phase in [0, 1).
    During stance [0, stance_frac), foot glides backward at constant velocity flush on the floor
    with realistic heel-strike -> flat sole -> ball push-off roll.
    During swing [stance_frac, 1), foot lifts in a smooth parabolic arc and prepares for heel-strike.
    """
    p = phase % 1.0
    if p < stance_frac:
        u = p / stance_frac  # 0 at heel strike, 1 at toe-off
        y = -stride_half + 2.0 * stride_half * u
        if u < 0.14:
            # Heel strike landing flat
            k = rig.smoothstep(u / 0.14)
            pitch = rig.lerp(18.0, 0.0, k)
            z = ankle_z + rig.lerp(0.014, 0.0, k)
        elif u < 0.72:
            # Flat planted sole
            pitch = 0.0
            z = ankle_z
        else:
            # Heel lift / ball push-off
            k = rig.smoothstep((u - 0.72) / 0.28)
            pitch = rig.lerp(0.0, -28.0, k)
            z = ankle_z + 0.042 * k
    else:
        u = (p - stance_frac) / (1.0 - stance_frac)  # 0 at toe-off, 1 at heel-strike
        # Smooth S-curve forward swing
        y = stride_half - 2.0 * stride_half * rig.smootherstep(u)
        z = ankle_z + 0.042 * (1.0 - u) + lift * math.sin(u * math.pi)
        # Toe trails down during early swing, dorsiflexes before heel strike
        if u < 0.55:
            pitch = rig.lerp(-28.0, -8.0, rig.smoothstep(u / 0.55))
        else:
            pitch = rig.lerp(-8.0, 18.0, rig.smoothstep((u - 0.55) / 0.45))
    return Vector((foot_x, y, z)), pitch


def _build_locomotion(m: RigMetrics, style: dict, run: bool = False):
    w = style.get("weapon", "1h")
    s = m.scale
    hunch = float(style.get("hunch", 0.0))
    is_goblin = style.get("archetype") == "goblin"
    is_boss = style.get("archetype") == "boss"
    is_vendor = w == "none"

    n_frames = 20 if run else 32
    clip_name = "run" if run else "walk"

    # Stride calibrated to leg length (and goblin scurries briskly!)
    stride_half = (0.48 if run else 0.30) * m.leg_len * (0.88 if is_vendor else (1.08 if is_goblin else 1.0))
    lift = (0.20 if run else 0.095) * m.leg_len
    stance_frac = 0.40 if run else 0.54
    lean = (16.0 if run else 5.0) + hunch * 0.65 + (10.0 if is_goblin else 0.0)
    base_drop = (0.11 if run else 0.045) * m.leg_len + (0.06 * m.leg_len if is_goblin else 0.0)
    bob_amp = (0.048 if run else 0.028) * m.leg_len
    lat_amp = (0.022 if run else 0.030) * s
    foot_x = m.foot_x * (1.28 if is_boss else (1.18 if is_goblin else 1.05))

    def pose(arm, f, phase):
        ang = phase * math.tau
        # Pelvis vertical arc: lowest during weight absorption (~0.08, 0.58), highest at passing (~0.32, 0.82)
        bob = math.cos(2.0 * ang - 0.62 * math.pi) * bob_amp
        lat = math.sin(ang + 0.15 * math.pi) * lat_amp
        hip_yaw = math.cos(ang) * (11.0 if run else 6.5)
        hip_roll = math.sin(ang + 0.15 * math.pi) * (4.5 if run else 3.2)
        chest_yaw = -math.cos(ang) * (14.0 if run else 8.0)

        _set_torso(
            arm,
            (lat, 0.0, -base_drop + bob),
            (lean * 0.35, hip_yaw, hip_roll),
            (lean * 0.45, chest_yaw * 0.35, -hip_roll * 0.6),
            (lean * 0.30, chest_yaw * 0.65, -hip_roll * 0.4),
            (-lean * 0.35, 0.0, 0.0),
            (0.0, 0.0, 0.0),
            (2.0, -math.cos(ang) * (6.0 if run else 3.0), 2.0, math.cos(ang) * (6.0 if run else 3.0)),
        )

        # Left foot at phase, Right foot at phase + 0.5
        l_ank, l_pitch = _foot_gait_sample(phase, stride_half, lift, stance_frac, m.ankle_z, foot_x)
        r_ank, r_pitch = _foot_gait_sample(phase + 0.5, stride_half, lift, stance_frac, m.ankle_z, -foot_x)
        _place_legs(m, l_ank, r_ank, l_pitch=l_pitch, r_pitch=r_pitch, l_yaw=5.0, r_yaw=-5.0)

        # Arm swing counter-phase to legs: when left leg is forward (cos > 0), right arm is forward
        sw = math.cos(ang)
        sw2 = math.sin(ang)

        if w == "2h":
            # Both hands remain solidly locked on lower + upper wraps across the torso with rhythmic stride weight!
            off = _weapon_2h_offset(style, m)
            sway_x = sw * (0.048 if run else 0.028) * s
            sway_y = (-0.30 if run else -0.26) * s + abs(sw2) * 0.022 * s
            sway_z = m.hip_z + (-0.02 if run else 0.01) * s + bob * 0.7
            r_pos = Vector((-0.24 * s + sway_x, sway_y, sway_z))
            shaft = Vector((0.54 - sw * 0.10, -0.44, 0.71))
            edge = Vector((-0.20, -0.94, -0.28))
            r_pole = Vector((-0.70 * s, 0.22 * s, m.sh_z - 0.26 * s))
            l_pole = Vector((0.66 * s, 0.16 * s, m.sh_z - 0.24 * s))
            _place_two_hand_axe(m, r_pos, shaft, edge, r_pole, l_pole, off)
        elif w == "bow":
            # Left arm carries bow upright-low steady; right arm swings counter to stride
            l_pos = Vector((m.sh_x + 0.04 * s, -0.28 * s + sw * 0.07 * s, m.hip_z + 0.07 * s + bob * 0.6))
            _place_grip_arm(m, "l", l_pos, Vector((0.12, -0.18, 0.97)), Vector((0.02, -0.98, -0.18)),
                            Vector((m.sh_x + 0.30 * s, 0.22 * s, m.sh_z - 0.24 * s)), edge_is_neg_y=True)
            r_amp = (0.28 if run else 0.17) * s
            r_w = Vector((-m.sh_x - 0.05 * s, -0.06 * s - sw * r_amp, m.hip_z + (0.04 if run else -0.04) * s + max(0.0, sw) * 0.08 * s))
            _place_hand_free(m, "r", r_w, Vector((-m.sh_x - 0.26 * s, 0.32 * s - sw * 0.14 * s, m.sh_z - 0.22 * s)),
                             Vector((0.08, -0.55 - sw * 0.35, -0.82)), Vector((0.95, 0.0, 0.0)))
        elif is_goblin:
            # Manic crouched goblin charge / scamper
            amp = (0.30 if run else 0.18) * s
            r_pos = Vector((-m.sh_x - 0.06 * s, -0.22 * s - sw * amp, m.hip_z + (0.06 if run else 0.0) * s + max(0.0, sw) * 0.09 * s))
            _place_grip_arm(m, "r", r_pos, Vector((-0.24, -0.78, 0.56 - sw * 0.25)), Vector((0.08, -0.60, -0.78)),
                            Vector((-m.sh_x - 0.36 * s, 0.24 * s - sw * 0.16 * s, m.sh_z - 0.14 * s)))
            l_w = Vector((m.sh_x + 0.08 * s, -0.24 * s + sw * amp, m.hip_z + (0.10 if run else 0.04) * s + max(0.0, -sw) * 0.09 * s))
            _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.36 * s, 0.24 * s + sw * 0.16 * s, m.sh_z - 0.12 * s)),
                             Vector((-0.25, -0.85, -0.30)), Vector((0.0, -0.4, 0.9)))
        elif is_vendor:
            # Calm dignified walk — modest natural arm swing
            amp = (0.18 if run else 0.12) * s
            r_w = Vector((-m.sh_x - 0.03 * s, -0.04 * s - sw * amp, m.hip_z - 0.06 * s + max(0.0, sw) * 0.04 * s))
            l_w = Vector((m.sh_x + 0.03 * s, -0.04 * s + sw * amp, m.hip_z - 0.06 * s + max(0.0, -sw) * 0.04 * s))
            _place_hand_free(m, "r", r_w, Vector((-m.sh_x - 0.22 * s, 0.28 * s - sw * 0.08 * s, m.sh_z - 0.26 * s)),
                             Vector((0.12, -0.35, -0.92)), Vector((0.9, 0.0, 0.0)))
            _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.22 * s, 0.28 * s + sw * 0.08 * s, m.sh_z - 0.26 * s)),
                             Vector((-0.12, -0.35, -0.92)), Vector((-0.9, 0.0, 0.0)))
        else:
            # Crawler (1H sword + shield): controlled warrior stride — shield carried on left flank, sword poised safely!
            r_amp = (0.24 if run else 0.14) * s
            r_pos = Vector((-m.sh_x - 0.08 * s, -0.14 * s - sw * r_amp, m.hip_z + (0.04 if run else -0.03) * s + max(0.0, sw) * 0.06 * s))
            _place_grip_arm(m, "r", r_pos, Vector((-0.22, -0.84, -0.28 + sw * 0.26)), Vector((0.08, -0.45, 0.88)),
                            Vector((-m.sh_x - 0.32 * s, 0.28 * s - sw * 0.12 * s, m.sh_z - 0.22 * s)))
            # Shield held low-flank with compact rhythmic pump so torso & leg drive read cleanly
            l_pos = Vector((0.30 * s + sw * 0.02 * s, -0.22 * s + sw * (0.08 if run else 0.05) * s, m.hip_z + (0.08 if run else 0.04) * s + bob * 0.6))
            _shield_arm_pose(m, l_pos, Vector((0.68, -0.73, 0.06)), Vector((-0.10, -0.08, 0.99)),
                             Vector((m.sh_x + 0.34 * s, 0.22 * s + sw * 0.06 * s, m.sh_z - 0.24 * s)))

        rig.orient_head_look(arm, (0.0, -1.0, -0.06 if run else -0.03), weight=0.88)

    rig.make_sampled_action(m.arm, clip_name, n_frames, pose, cyclic=True)


# ---------------------------------------------------------------------------
# 4. ATTACKS (1H: 28f impact f14; 2H: 40f impact f18; Boss Slam: 40f impact f18)
# ---------------------------------------------------------------------------

def _build_attack_1h(m: RigMetrics, style: dict, clip_name: str = "attack", mirror: bool = False):
    """Kinetic-chain 1H melee slash (28 frames, impact at frame 14 = 0.467s)."""
    s = m.scale
    hunch = float(style.get("hunch", 0.0))
    is_goblin = style.get("archetype") == "goblin"

    # Keyframes: 0=guard, 8=windup coil, 14=impact across front, 19=follow-through, 28=guard
    hip_y_k = [(0, 0.02), (8, 0.09, "in_out"), (14, -0.10, "in_cubic"), (19, -0.13, "out"), (28, 0.02, "in_out")]
    hip_z_k = [(0, -0.085), (8, -0.06, "in_out"), (14, -0.115, "in"), (19, -0.125, "out"), (28, -0.085, "in_out")]
    hips_yaw_k = [(0, 9.0), (8, -26.0, "in_out"), (14, 30.0, "in_cubic"), (19, 36.0, "out"), (28, 9.0, "in_out")]
    chest_yaw_k = [(0, 7.0), (9, -36.0, "in_out"), (14, 38.0, "in_cubic"), (19, 44.0, "out"), (28, 7.0, "in_out")]
    spine_p_k = [(0, 7.0), (8, -4.0, "in_out"), (14, 18.0, "in_cubic"), (19, 21.0, "out"), (28, 7.0, "in_out")]

    r_pos_k = [
        (0, (-m.sh_x - 0.09 * s, -0.28 * s, m.hip_z + 0.05 * s)),
        (8, (-m.sh_x - 0.18 * s, 0.06 * s, m.sh_z + 0.14 * s), "in_out"),
        (11, (-0.20 * s, -0.36 * s, m.sh_z + 0.02 * s), "in"),
        (14, (0.14 * s, -0.52 * s, m.hip_z + 0.14 * s), "in_cubic"),
        (19, (0.28 * s, -0.34 * s, m.hip_z - 0.04 * s), "out_cubic"),
        (28, (-m.sh_x - 0.09 * s, -0.28 * s, m.hip_z + 0.05 * s), "in_out"),
    ]
    r_shaft_k = [
        (0, (-0.30, -0.76, 0.58)),
        (8, (-0.42, 0.55, 0.72), "in_out"),
        (11, (-0.30, -0.78, 0.55), "in"),
        (14, (0.52, -0.82, -0.22), "in_cubic"),
        (19, (0.76, -0.45, -0.46), "out_cubic"),
        (28, (-0.30, -0.76, 0.58), "in_out"),
    ]
    r_edge_k = [
        (0, (0.18, -0.65, -0.74)),
        (8, (0.55, -0.68, -0.48), "in_out"),
        (14, (0.78, 0.42, -0.45), "in_cubic"),
        (19, (0.45, 0.65, -0.60), "out"),
        (28, (0.18, -0.65, -0.74), "in_out"),
    ]
    # Lead foot steps forward slightly into the strike
    l_foot_y_k = [(0, -0.18), (8, -0.14, "in_out"), (14, -0.28, "in_cubic"), (20, -0.28, "linear"), (28, -0.18, "in_out")]

    def pose(arm, f, phase):
        if f == 0 or f == 28:
            _pose_combat_guard(m, style)
            return
        hy = float(rig.sample_curve(f, hip_y_k)) * s
        hz = float(rig.sample_curve(f, hip_z_k)) * m.leg_len - (0.04 * m.leg_len if is_goblin else 0.0)
        hyaw = float(rig.sample_curve(f, hips_yaw_k))
        cyaw = float(rig.sample_curve(f, chest_yaw_k))
        sp = float(rig.sample_curve(f, spine_p_k)) + hunch * 0.5 + (6.0 if is_goblin else 0.0)
        _set_torso(arm, (0.0, hy, hz), (5.0, hyaw, 0.0), (sp, cyaw * 0.45, 0.0), (sp * 0.55, cyaw * 0.55, 0.0),
                   (-hunch * 0.35, 0.0, 0.0), (0.0, 0.0, 0.0), (2.0, -cyaw * 0.18, 4.0, cyaw * 0.25))

        stance_w = 1.35 * m.foot_x
        lfy = float(rig.sample_curve(f, l_foot_y_k)) * s
        # Brief subtle toe lift on step-in
        l_lift = math.sin(rig.clamp((f - 8.0) / 6.0) * math.pi) * 0.045 * s if 8 <= f <= 14 else 0.0
        _place_legs(m, Vector((stance_w, lfy, m.ankle_z + l_lift)), Vector((-stance_w * 1.05, 0.20 * s, m.ankle_z)),
                    l_yaw=10.0, r_yaw=-28.0)

        rp = rig.sample_curve(f, r_pos_k)
        rs = rig.sample_curve(f, r_shaft_k)
        re = rig.sample_curve(f, r_edge_k)
        r_pole = Vector((-m.sh_x - 0.38 * s, 0.22 * s, m.sh_z - 0.16 * s))
        _place_grip_arm(m, "r", rp, rs, re, r_pole)

        if is_goblin:
            # Left claw balances wide behind during slash
            l_w = Vector((m.sh_x + 0.12 * s, -0.22 * s + cyaw * 0.005 * s, m.hip_z + 0.12 * s))
            _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.36 * s, 0.28 * s, m.sh_z - 0.10 * s)),
                             Vector((-0.3, -0.8, -0.3)), Vector((0.0, -0.5, 0.85)))
        elif style.get("weapon") == "dual":
            # Off-hand blade stays on guard, drawing back a little to counter-balance the cut
            open_k = math.sin(rig.clamp((f - 4.0) / 19.0) * math.pi)
            _place_offhand_blade(m, Vector((m.sh_x + 0.09 * s + open_k * 0.10 * s, -0.28 * s + open_k * 0.18 * s,
                                            m.hip_z + 0.05 * s + open_k * 0.04 * s)))
        else:
            # Shield opens wide out-left to counter-balance the torso torque and leave the full sword slash unobstructed!
            open_k = math.sin(rig.clamp((f - 4.0) / 19.0) * math.pi)
            l_pos = Vector((0.30 * s + open_k * 0.14 * s, -0.26 * s + open_k * 0.22 * s, m.hip_z + 0.06 * s - open_k * 0.04 * s))
            _shield_arm_pose(m, l_pos, Vector((0.58 + open_k * 0.34, -0.81 + open_k * 0.44, 0.08)),
                             Vector((-0.10, -0.08, 0.99)), Vector((m.sh_x + 0.38 * s, 0.26 * s, m.sh_z - 0.22 * s)))

        rig.orient_head_look(arm, (0.0, -1.0, -0.05), weight=0.92)

    rig.make_sampled_action(m.arm, clip_name, 28, _mirrored(pose) if mirror else pose, cyclic=False)


def _build_attack_2h(m: RigMetrics, style: dict, clip_name: str = "attack", vertical_slam: bool = False):
    """Heavy two-handed battleaxe cleave or Boss vertical overhead earth-slam (40f, impact f18 = 0.60s).
    Right hand holds lower grip wrap (z=0), Left hand grips upper leather wrap (+shaft) on every frame!
    """
    s = m.scale
    hunch = float(style.get("hunch", 0.0))
    is_boss = style.get("archetype") == "boss"
    off = _weapon_2h_offset(style, m)

    if vertical_slam:
        # Boss cataclysmic vertical overhead slam right down to the dungeon flagstones!
        hip_y_k = [(0, 0.02), (12, 0.12, "in_out"), (18, -0.14, "in_cubic"), (24, -0.17, "out"), (40, 0.02, "in_out")]
        hip_z_k = [(0, -0.075), (12, -0.015, "in_out"), (18, -0.175, "in_cubic"), (24, -0.20, "out"), (40, -0.075, "in_out")]
        spine_p_k = [(0, 7.0), (12, -16.0, "in_out"), (18, 28.0, "in_cubic"), (24, 32.0, "out"), (40, 7.0, "in_out")]
        chest_yaw_k = [(0, -14.0), (12, 8.0, "in_out"), (18, -8.0, "in_cubic"), (24, -10.0, "out"), (40, -14.0, "in_out")]
        r_pos_k = [
            (0, (-0.24 * s, -0.26 * s, m.hip_z + 0.02 * s)),
            (12, (-0.12 * s, -0.08 * s, m.sh_z + 0.06 * s), "in_out"),
            (15, (-0.08 * s, -0.32 * s, m.sh_z + 0.04 * s), "in"),
            (18, (-0.08 * s, -0.34 * s, m.hip_z + 0.04 * s), "in_cubic"),
            (23, (-0.08 * s, -0.32 * s, m.hip_z - 0.02 * s), "out"),
            (26, (-0.10 * s, -0.32 * s, m.hip_z + 0.02 * s), "in_out"),
            (40, (-0.24 * s, -0.26 * s, m.hip_z + 0.02 * s), "in_out"),
        ]
        shaft_k = [
            (0, (0.52, -0.48, 0.71)),
            (12, (0.14, 0.45, 0.88), "in_out"),
            (15, (0.08, -0.50, 0.86), "in"),
            (18, (0.08, -0.84, -0.54), "in_cubic"),
            (23, (0.08, -0.78, -0.62), "out"),
            (40, (0.52, -0.48, 0.71), "in_out"),
        ]
        edge_k = [
            (0, (-0.22, -0.92, -0.32)),
            (12, (-0.06, -0.88, 0.46), "in_out"),
            (18, (-0.06, -0.54, -0.84), "in_cubic"),
            (23, (-0.06, -0.62, -0.78), "out"),
            (40, (-0.22, -0.92, -0.32), "in_out"),
        ]
    else:
        # Sweeping heavy diagonal high-left to low-right battleaxe cleave (zero crossed arms, edge leads clean!)
        hip_y_k = [(0, 0.02), (12, 0.11, "in_out"), (18, -0.13, "in_cubic"), (24, -0.15, "out"), (40, 0.02, "in_out")]
        hip_z_k = [(0, -0.080), (12, -0.040, "in_out"), (18, -0.145, "in_cubic"), (24, -0.16, "out"), (40, -0.080, "in_out")]
        spine_p_k = [(0, 7.0), (12, -10.0, "in_out"), (18, 22.0, "in_cubic"), (24, 25.0, "out"), (40, 7.0, "in_out")]
        chest_yaw_k = [(0, -14.0), (12, 36.0, "in_out"), (18, -32.0, "in_cubic"), (24, -40.0, "out"), (40, -14.0, "in_out")]
        r_pos_k = [
            (0, (-0.24 * s, -0.26 * s, m.hip_z + 0.02 * s)),
            (12, (-0.02 * s, -0.14 * s, m.sh_z - 0.12 * s), "in_out"),
            (15, (-0.06 * s, -0.34 * s, m.sh_z - 0.08 * s), "in"),
            (18, (-0.08 * s, -0.30 * s, m.hip_z + 0.10 * s), "in_cubic"),
            (24, (-0.10 * s, -0.22 * s, m.hip_z + 0.06 * s), "out_cubic"),
            (40, (-0.24 * s, -0.26 * s, m.hip_z + 0.02 * s), "in_out"),
        ]
        shaft_k = [
            (0, (0.52, -0.48, 0.71)),
            (12, (0.48, 0.44, 0.76), "in_out"),
            (15, (0.20, -0.78, 0.59), "in"),
            (18, (-0.26, -0.94, -0.22), "in_cubic"),
            (24, (-0.54, -0.68, -0.50), "out_cubic"),
            (40, (0.52, -0.48, 0.71), "in_out"),
        ]
        edge_k = [
            (0, (-0.22, -0.92, -0.32)),
            (12, (-0.56, -0.66, 0.50), "in_out"),
            (18, (-0.72, 0.10, -0.68), "in_cubic"),
            (24, (-0.42, 0.55, -0.72), "out"),
            (40, (-0.22, -0.92, -0.32), "in_out"),
        ]

    r_foot_y_k = [(0, -0.18), (11, -0.14, "in_out"), (18, -0.32, "in_cubic"), (25, -0.32, "linear"), (40, -0.18, "in_out")]

    def pose(arm, f, phase):
        if f == 0 or f == 40:
            if style.get("weapon") == "2h":
                _pose_combat_guard(m, style)
            else:
                _pose_combat_guard(m, dict(style, weapon="2h"))
            return
        hy = float(rig.sample_curve(f, hip_y_k)) * s
        hz = float(rig.sample_curve(f, hip_z_k)) * m.leg_len
        sp = float(rig.sample_curve(f, spine_p_k)) + hunch * 0.5
        cy = float(rig.sample_curve(f, chest_yaw_k))
        # Subtle metallic shudder right after slam impact (f18..25)
        shudder = math.sin((f - 18) * 2.2) * 0.008 * s if (vertical_slam and 18 <= f <= 25) else 0.0
        _set_torso(arm, (shudder, hy, hz), (5.0, cy * 0.45, 0.0), (sp * 0.65, cy * 0.30, 0.0),
                   (sp * 0.45, cy * 0.25, 0.0), (-hunch * 0.35, 0.0, 0.0), (0.0, 0.0, 0.0),
                   (4.0, 4.0, 4.0, 4.0))

        stance_w = (1.55 if is_boss else 1.35) * m.foot_x
        rfy = float(rig.sample_curve(f, r_foot_y_k)) * s
        r_lift = math.sin(rig.clamp((f - 11.0) / 7.0) * math.pi) * 0.055 * s if 11 <= f <= 18 else 0.0
        _place_legs(m, Vector((stance_w * 1.05, 0.14 * s, m.ankle_z)), Vector((-stance_w, rfy, m.ankle_z + r_lift)),
                    l_yaw=26.0, r_yaw=-12.0)

        rp = rig.sample_curve(f, r_pos_k) + Vector((0.0, 0.0, shudder))
        sh = rig.sample_curve(f, shaft_k)
        ed = rig.sample_curve(f, edge_k)
        r_pole = Vector((-0.72 * s, 0.14 * s, m.sh_z - 0.18 * s + max(0.0, rp.z - m.sh_z) * 0.6))
        l_pole = Vector((0.70 * s, 0.10 * s, m.sh_z - 0.12 * s + max(0.0, rp.z - m.sh_z) * 0.6))
        _place_two_hand_axe(m, rp, sh, ed, r_pole, l_pole, off)
        rig.orient_head_look(arm, (0.0, -1.0, -0.10 if vertical_slam and 18 <= f <= 26 else -0.04), weight=0.88)

    rig.make_sampled_action(m.arm, clip_name, 40, pose, cyclic=False)


# ---------------------------------------------------------------------------
# 5. ARCHERY — shoot (46f, release @ f32 = 1.067s), draw_hold (60f), bow_shoot (24f)
# ---------------------------------------------------------------------------

def _apply_archery_pose(m: RigMetrics, style: dict, aim_k: float, draw_k: float, release_k: float, breath: float = 0.0):
    """Exact archery biomechanics: sideways stance, dead-vertical bow aimed at -Y, right hand
    pulling straight back along the arrow line to jaw with elbow raised high & behind shoulder!
    """
    arm = m.arm
    s = m.scale
    hunch = float(style.get("hunch", 0.0))

    # Rotate torso ~48 deg right when aiming so left shoulder points straight down-range (-Y)
    yaw_total = rig.lerp(-24.0, -52.0, aim_k) - draw_k * 6.0 + release_k * 5.0
    crouch = (0.085 + 0.015 * aim_k) * m.leg_len
    _set_torso(
        arm,
        (0.015 * s * aim_k, 0.02 * s, -crouch + breath * 0.008 * s),
        (4.0, yaw_total * 0.45, 0.0),
        (5.0 + hunch * 0.4 - breath * 1.0, yaw_total * 0.30, 0.0),
        (3.0 + hunch * 0.25 - breath * 1.5, yaw_total * 0.25, 0.0),
        (-hunch * 0.3, 0.0, 0.0),
        (0.0, 0.0, 0.0),
        (2.0 * aim_k, 8.0 * aim_k, 6.0 * draw_k, -14.0 * draw_k),
    )

    stance_w = 1.35 * m.foot_x
    l_ank = Vector((stance_w * 0.9, -0.20 * s, m.ankle_z))
    r_ank = Vector((-stance_w * 1.15, 0.18 * s, m.ankle_z))
    _place_legs(m, l_ank, r_ank, l_yaw=8.0, r_yaw=-42.0)

    # Left bow arm: smoothly lifts from relaxed guard to extended straight forward (-Y) at shoulder height
    rest_l = Vector((0.20 * s, -0.42 * s, m.hip_z + 0.16 * s))
    aim_l = Vector((0.04 * s, -m.arm_len * 0.88 - 0.12 * s, m.sh_z - 0.04 * s + breath * 0.008 * s))
    recoil_l = Vector((0.02 * s, -0.03 * s, -0.035 * s)) * release_k
    l_pos = rest_l.lerp(aim_l, aim_k) + recoil_l
    # crisp upright bow with a hunting cant; the player's crawler cants harder (~20 deg, top limb out to the left)
    # so the bow reads beside the helm from the over-the-shoulder aim camera (FB-014)
    cant = 0.36 if style.get("archetype") == "crawler" else 0.08
    bow_up = Vector((cant, -0.02, 0.996)).normalized()
    bow_fwd = Vector((0.0, -1.0, -0.02 - 0.05 * release_k)).normalized()
    l_pole = Vector((m.sh_x + 0.38 * s, -0.10 * s, m.sh_z - 0.18 * s))
    actual_bow_grip, _ = _place_grip_arm(m, "l", l_pos, bow_up, bow_fwd, l_pole, edge_is_neg_y=True)

    # Right drawing hand: rest -> string nock behind bow -> jaw anchor -> back-tension follow-through!
    rest_r = Vector((-0.24 * s, -0.16 * s, m.hip_z + 0.12 * s))
    nock_r = actual_bow_grip + Vector((-0.02 * s, 0.18 * s, 0.02 * s))
    cheek_r = Vector((-0.05 * s, -0.10 * s, m.sh_z + 0.07 * s + breath * 0.006 * s))
    loose_r = Vector((-0.14 * s, 0.10 * s, m.sh_z + 0.05 * s))

    if release_k > 0.001:
        r_target = cheek_r.lerp(loose_r, release_k)
        # Elbow snaps smoothly back behind shoulder on release
        r_pole = Vector((-m.sh_x - 0.45 * s, 0.55 * s, m.sh_z + 0.16 * s))
    elif draw_k > 0.001:
        r_target = nock_r.lerp(cheek_r, draw_k)
        # Key archery posture: drawing elbow stays HIGH at shoulder level & pulls STRAIGHT BACK!
        r_pole = Vector((-m.sh_x - 0.42 * s, 0.48 * s * draw_k + 0.05 * s, m.sh_z + 0.12 * s * draw_k))
    else:
        r_target = rest_r.lerp(nock_r, aim_k)
        r_pole = Vector((-m.sh_x - 0.35 * s, 0.20 * s, m.sh_z - 0.08 * s * (1.0 - aim_k)))

    _place_hand_free(m, "r", r_target, r_pole, (actual_bow_grip - r_target).normalized(), Vector((0.0, 0.0, 1.0)))

    # Head turns cleanly left to sight straight down the arrow at the target!
    rig.orient_head_look(arm, (0.0, -1.0, -0.02), weight=0.96, tilt_deg=-4.0 * draw_k)


def _build_shoot(m: RigMetrics, style: dict):
    """Bone archer full draw & release cycle (46 frames, arrow loose at frame 32 = 1.067s)."""
    aim_k_curve = [(0, 0.0), (10, 1.0, "in_out"), (36, 1.0, "linear"), (46, 0.0, "in_out")]
    draw_k_curve = [(0, 0.0), (10, 0.0, "linear"), (24, 1.0, "out_cubic"), (32, 1.0, "linear"), (33, 0.0, "linear"), (46, 0.0, "linear")]
    rel_k_curve = [(0, 0.0), (31, 0.0, "linear"), (34, 1.0, "out_cubic"), (39, 0.55, "in_out"), (46, 0.0, "in_out")]

    def pose(arm, f, phase):
        if f == 0 or f == 46:
            _pose_combat_guard(m, style)
            return
        ak = float(rig.sample_curve(f, aim_k_curve))
        dk = float(rig.sample_curve(f, draw_k_curve))
        rk = float(rig.sample_curve(f, rel_k_curve))
        # Subtle live tension breathing during aim hold (f24..32)
        br = math.sin((f - 24) * 0.45) * 0.35 if 24 <= f <= 32 else 0.0
        _apply_archery_pose(m, style, ak, dk, rk, br)

    rig.make_sampled_action(m.arm, "shoot", 46, pose, cyclic=False)


def _build_draw_hold(m: RigMetrics, style: dict):
    """Player 3rd-person full-draw aim loop (60 frames = 2.0s cyclic)."""
    def pose(arm, f, phase):
        br = math.sin(phase * math.tau) * 0.45
        _apply_archery_pose(m, style, 1.0, 1.0, 0.0, br)
    rig.make_sampled_action(m.arm, "draw_hold", 60, pose, cyclic=True)


def _build_bow_draw(m: RigMetrics, style: dict):
    """Player 3rd-person draw-up one-shot (18 frames = 0.6s, FB-014): raise the bow from guard, nock and pull
    back to the cheek, ending exactly on draw_hold's first frame so the loop takes over seamlessly."""
    aim_k_curve = [(0, 0.0), (8, 1.0, "in_out"), (18, 1.0, "linear")]
    draw_k_curve = [(0, 0.0), (6, 0.0, "linear"), (16, 1.0, "out_cubic"), (18, 1.0, "linear")]

    def pose(arm, f, phase):
        if f == 0:
            _pose_combat_guard(m, style)
            return
        _apply_archery_pose(m, style, float(rig.sample_curve(f, aim_k_curve)), float(rig.sample_curve(f, draw_k_curve)), 0.0, 0.0)
    rig.make_sampled_action(m.arm, "bow_draw", 18, pose, cyclic=False)


def _build_bow_shoot(m: RigMetrics, style: dict):
    """Player 3rd-person bow release follow-through one-shot (24 frames = 0.8s)."""
    rel_k_curve = [(0, 0.0), (3, 1.0, "out_cubic"), (11, 0.65, "in_out"), (24, 0.0, "in_out")]
    aim_k_curve = [(0, 1.0), (10, 1.0, "linear"), (24, 0.0, "in_out")]

    def pose(arm, f, phase):
        rk = float(rig.sample_curve(f, rel_k_curve))
        ak = float(rig.sample_curve(f, aim_k_curve))
        dk = 1.0 if f == 0 else 0.0
        _apply_archery_pose(m, style, ak, dk, rk, 0.0)
    rig.make_sampled_action(m.arm, "bow_shoot", 24, pose, cyclic=False)


# ---------------------------------------------------------------------------
# 6. BLOCK, CAST, ROAR, TALK
# ---------------------------------------------------------------------------

def _build_block(m: RigMetrics, style: dict):
    """Crawler shield-wall block (60f cyclic): shield square across upper chest with helm peeking over rim!"""
    s = m.scale

    def pose(arm, f, phase):
        br = math.sin(phase * math.tau)
        br2 = math.sin(phase * math.tau - 0.5)
        crouch = 0.125 * m.leg_len
        _set_torso(arm, (0.015 * s, 0.03 * s, -crouch + br * 0.008 * s),
                   (7.0, 20.0, 0.0), (8.0 - br * 1.0, 12.0, 0.0), (5.0 - br2 * 1.5, 8.0, 0.0),
                   (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (5.0, 10.0, 2.0, 2.0))
        stance_w = 1.45 * m.foot_x
        _place_legs(m, Vector((stance_w, -0.22 * s, m.ankle_z)), Vector((-stance_w * 1.1, 0.24 * s, m.ankle_z)),
                    l_yaw=14.0, r_yaw=-34.0)
        # Shield held firmly SQUARE across chest facing enemy (-Y), low enough that eyes/horned helm peer over top rim!
        l_pos = Vector((0.08 * s, -0.40 * s, m.sh_z - 0.20 * s + br2 * 0.01 * s))
        _shield_arm_pose(m, l_pos, Vector((0.10, -0.99, 0.10)), Vector((-0.06, -0.10, 0.99)),
                         Vector((m.sh_x + 0.36 * s, -0.02 * s, m.sh_z - 0.24 * s)))
        # Sword tucked poised beside right side ready to counter-slash
        r_pos = Vector((-m.sh_x - 0.08 * s, -0.22 * s, m.hip_z + 0.08 * s + br2 * 0.01 * s))
        _place_grip_arm(m, "r", r_pos, Vector((-0.26, -0.68, 0.68)), Vector((0.14, -0.70, -0.70)),
                        Vector((-m.sh_x - 0.32 * s, 0.28 * s, m.sh_z - 0.20 * s)))
        rig.orient_head_look(arm, (0.0, -1.0, -0.04), weight=0.95)

    rig.make_sampled_action(m.arm, "block", 60, pose, cyclic=True)


def _build_cast(m: RigMetrics, style: dict, clip_name: str = "cast", mirror: bool = False, both: bool = False):
    """Crawler off-hand spell cast (32f): gather at ribs -> clean forward palm thrust -> settle."""
    s = m.scale
    l_pos_k = [
        (0, (0.30 * s, -0.26 * s, m.hip_z + 0.06 * s)),
        (8, (0.28 * s, -0.08 * s, m.hip_z + 0.14 * s), "in_out"),
        (14, (0.06 * s, -m.arm_len * 0.90 - 0.10 * s, m.sh_z - 0.04 * s), "in_cubic"),
        (19, (0.05 * s, -m.arm_len * 0.86 - 0.08 * s, m.sh_z + 0.02 * s), "out"),
        (32, (0.30 * s, -0.26 * s, m.hip_z + 0.06 * s), "in_out"),
    ]
    yaw_k = [(0, 16.0), (8, 30.0, "in_out"), (14, -22.0, "in_cubic"), (19, -24.0, "out"), (32, 16.0, "in_out")]
    hip_y_k = [(0, 0.02), (8, 0.07, "in_out"), (14, -0.09, "in_cubic"), (20, -0.08, "out"), (32, 0.02, "in_out")]

    def pose(arm, f, phase):
        if f == 0 or f == 32:
            _pose_combat_guard(m, style)
            return
        yw = float(rig.sample_curve(f, yaw_k)) * (0.15 if both else 1.0)
        hy = float(rig.sample_curve(f, hip_y_k)) * s
        _set_torso(arm, (0.0, hy, -0.095 * m.leg_len), (5.0, yw * 0.45, 0.0), (8.0, yw * 0.30, 0.0),
                   (4.0, yw * 0.25, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (3.0, -yw * 0.25, 2.0, 0.0))
        stance_w = 1.35 * m.foot_x
        _place_legs(m, Vector((stance_w, -0.22 * s, m.ankle_z)), Vector((-stance_w * 1.05, 0.20 * s, m.ankle_z)),
                    l_yaw=10.0, r_yaw=-28.0)
        lp = rig.sample_curve(f, l_pos_k)
        l_pole = Vector((m.sh_x + 0.36 * s, 0.16 * s, m.sh_z - 0.22 * s))
        _place_hand_free(m, "l", lp, l_pole, Vector((0.0, -0.96, 0.28)), Vector((0.0, 0.28, 0.96)))
        if both:
            # Two-handed cast: both palms thrust forward together, mirrored (dual spells)
            _place_hand_free(m, "r", _mx(lp) + Vector((0.0, 0.0, 0.0)), _mx(l_pole), _mx(Vector((0.0, -0.96, 0.28))),
                             _mx(Vector((0.0, 0.28, 0.96))))
        else:
            # Sword hand balances naturally at right hip
            r_pos = Vector((-m.sh_x - 0.09 * s, -0.20 * s + hy * 0.4, m.hip_z + 0.04 * s))
            _place_grip_arm(m, "r", r_pos, Vector((-0.26, -0.74, 0.62)), Vector((0.14, -0.65, -0.74)),
                            Vector((-m.sh_x - 0.32 * s, 0.28 * s, m.sh_z - 0.24 * s)))
        rig.orient_head_look(arm, (0.0, -1.0, -0.03), weight=0.92)

    rig.make_sampled_action(m.arm, clip_name, 32, _mirrored(pose) if mirror else pose, cyclic=False)


def _build_roar(m: RigMetrics, style: dict):
    """Iron Warden boss battle cry (56f): coil crouch -> erupting roar w/ living rage tremor -> heavy guard settle."""
    s = m.scale
    off = _weapon_2h_offset(style, m)
    crouch_k = [(0, -0.075), (12, -0.15, "in_out"), (20, -0.02, "out_cubic"), (42, -0.035, "in_out"), (56, -0.075, "in_out")]
    chest_p_k = [(0, 4.0), (12, 18.0, "in_out"), (20, -24.0, "out_cubic"), (42, -20.0, "in_out"), (56, 4.0, "in_out")]
    head_p_k = [(0, -4.0), (12, 18.0, "in_out"), (21, -34.0, "out_cubic"), (42, -28.0, "in_out"), (56, -4.0, "in_out")]
    open_k_c = [(0, 0.0), (12, 0.0, "linear"), (20, 1.0, "out_cubic"), (42, 1.0, "linear"), (56, 0.0, "in_out")]

    def pose(arm, f, phase):
        if f == 0 or f == 56:
            _pose_combat_guard(m, style)
            return
        hz = float(rig.sample_curve(f, crouch_k)) * m.leg_len
        cp = float(rig.sample_curve(f, chest_p_k))
        hp = float(rig.sample_curve(f, head_p_k))
        ok = float(rig.sample_curve(f, open_k_c))

        # Living furnace-rage heave & subtle high-frequency tremor during peak roar (f19..43)
        rage = math.sin(rig.clamp((f - 18.0) / 25.0) * math.pi)
        heave = math.sin((f - 18.0) * 0.65) * 3.5 * rage
        tremor = math.sin(f * 2.1) * 1.8 * rage

        _set_torso(arm, (0.0, 0.02 * s - ok * 0.04 * s, hz),
                   (5.0 * (1.0 - ok), -10.0 * (1.0 - ok), 0.0),
                   (cp * 0.55 + heave * 0.4, 0.0, tremor * 0.4),
                   (cp * 0.65 + heave * 0.6, tremor * 0.5, -tremor * 0.3),
                   (hp * 0.35, 0.0, 0.0),
                   (hp * 0.65, tremor * 1.4, tremor * 0.6),
                   (10.0 * ok + heave * 0.6, -12.0 * ok, 10.0 * ok + heave * 0.6, -12.0 * ok))

        stance_w = 1.55 * m.foot_x
        _place_legs(m, Vector((stance_w * 1.05, 0.14 * s, m.ankle_z)), Vector((-stance_w, -0.18 * s, m.ankle_z)),
                    l_yaw=26.0, r_yaw=-12.0)

        r_guard = Vector((-0.24 * s, -0.26 * s, m.hip_z + 0.02 * s))
        sh_g = Vector((0.52, -0.48, 0.71))
        ed_g = Vector((-0.22, -0.92, -0.32))
        if ok < 0.05:
            # Coiled two-handed before erupting wide open
            coil = rig.smoothstep(f / 12.0) if f <= 12 else 0.0
            r_pos = r_guard + Vector((0.0, coil * 0.06 * s, -coil * 0.08 * s))
            _place_two_hand_axe(m, r_pos, sh_g, ed_g,
                                Vector((-0.70 * s, 0.18 * s, m.sh_z - 0.26 * s)),
                                Vector((0.66 * s, 0.14 * s, m.sh_z - 0.22 * s)), off)
        else:
            # Right arm throws giant battleaxe wide to right (head clearly visible in upper-left of shot!), left fist roars wide!
            r_roar = Vector((-m.sh_x - 0.30 * s, -0.12 * s, m.hip_z + 0.14 * s + heave * 0.008 * s))
            r_pos = r_guard.lerp(r_roar, ok)
            sh_r = Vector((-0.68, -0.24, 0.69))
            ed_r = Vector((0.18, -0.96, -0.20))
            actual_rg, _ = _place_grip_arm(m, "r", r_pos, sh_g.lerp(sh_r, ok), ed_g.lerp(ed_r, ok),
                                           Vector((-m.sh_x - 0.45 * s, 0.36 * s, m.sh_z - 0.18 * s)))
            l_guard = actual_rg + sh_g.normalized() * off
            l_roar = Vector((m.sh_x + 0.36 * s, -0.14 * s, m.sh_z - 0.02 * s + heave * 0.008 * s))
            l_pos = l_guard.lerp(l_roar, ok)
            _place_hand_free(m, "l", l_pos, Vector((m.sh_x + 0.46 * s, 0.36 * s, m.sh_z - 0.18 * s)),
                             Vector((0.35, -0.75, 0.55)), Vector((-0.6, -0.6, 0.0)))

    rig.make_sampled_action(m.arm, "roar", 56, pose, cyclic=False)


def _build_talk(m: RigMetrics, style: dict):
    """Vendor warm, expressive open-handed merchant dialogue loop (90 frames = 3.0s cyclic)."""
    s = m.scale
    hunch = float(style.get("hunch", 4.0))

    def pose(arm, f, phase):
        ang = phase * math.tau
        sway = math.sin(ang)
        g1 = math.sin(ang) * 0.5 + 0.5            # first gesture wave
        g2 = math.sin(ang * 2.0 - 1.1) * 0.5 + 0.5  # secondary emphasizing wave
        nod = math.sin(ang * 2.0 + 0.4) * 5.0
        turn = math.sin(ang - 0.6) * 9.0

        _set_torso(arm, (sway * 0.022 * s, 0.0, -0.025 * m.leg_len + math.sin(ang * 2.0) * 0.006 * s),
                   (2.0, sway * 4.0, sway * 1.5),
                   (3.5 + hunch * 0.5 + math.sin(ang * 2.0) * 1.8, sway * 5.0, -sway * 1.0),
                   (2.0 + hunch * 0.3, sway * 4.0, 0.0),
                   (-hunch * 0.35, 0.0, 0.0), (0.0, 0.0, 0.0),
                   (1.5 + g2 * 2.0, 3.0, 2.0 + g1 * 2.5, 4.0))

        stance_w = 1.15 * m.foot_x
        _place_legs(m, Vector((stance_w, -0.06 * s, m.ankle_z)), Vector((-stance_w * 1.05, 0.07 * s, m.ankle_z)),
                    l_yaw=11.0, r_yaw=-15.0)

        # Warm welcoming open-palm gestures in front of chest/waist (NEVER folding into armpit!)
        r_w = Vector((-0.18 * s - g1 * 0.14 * s, -0.32 * s - g2 * 0.10 * s, m.hip_z + 0.12 * s + g1 * 0.10 * s))
        l_w = Vector((0.18 * s + g2 * 0.12 * s, -0.28 * s - g1 * 0.08 * s, m.hip_z + 0.08 * s + g2 * 0.08 * s))
        _place_hand_free(m, "r", r_w, Vector((-m.sh_x - 0.24 * s, 0.14 * s, m.sh_z - 0.32 * s)),
                         Vector((-0.22 * g1, -0.92, 0.25)), Vector((0.0, 0.25, 0.96)))
        _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.24 * s, 0.14 * s, m.sh_z - 0.32 * s)),
                         Vector((0.20 * g2, -0.92, 0.22)), Vector((0.0, 0.22, 0.96)))

        ty = math.radians(turn)
        np = math.radians(nod - 2.0)
        rig.orient_head_look(arm, (-math.sin(ty) * math.cos(np), -math.cos(ty) * math.cos(np), math.sin(np)),
                             weight=0.88, tilt_deg=sway * 4.5)

    rig.make_sampled_action(m.arm, "talk", 90, pose, cyclic=True)


# ---------------------------------------------------------------------------
# 7. HIT (16 frames = 0.533s) — Grounded impact flinch (feet stay planted!)
# ---------------------------------------------------------------------------

def _build_hit(m: RigMetrics, style: dict):
    s = m.scale
    w = style.get("weapon", "1h")
    hunch = float(style.get("hunch", 0.0))
    is_boss = style.get("archetype") == "boss"
    is_goblin = style.get("archetype") == "goblin"
    amp = 0.65 if is_boss else (1.15 if is_goblin else 1.0)
    off = _weapon_2h_offset(style, m) if w == "2h" else 0.0

    # Sharp impact stagger backward (+Y) and downward (-Z) while feet remain planted!
    rec_k = [(0, 0.0), (4, 1.0, "out_cubic"), (8, 0.75, "in_out"), (16, 0.0, "in_out")]
    head_lag_k = [(0, 0.0), (5, 1.0, "out_cubic"), (10, 0.55, "in_out"), (16, 0.0, "in_out")]

    def pose(arm, f, phase):
        if f == 0 or f == 16:
            _pose_combat_guard(m, style)
            return
        k = float(rig.sample_curve(f, rec_k)) * amp
        hk = float(rig.sample_curve(f, head_lag_k)) * amp

        base_crouch = (0.14 if is_goblin else (0.075 if is_boss else 0.085)) * m.leg_len
        base_yaw = -14.0 if w == "2h" else (-24.0 if w == "bow" else 16.0)
        _set_torso(
            arm,
            (0.02 * s * k, 0.02 * s + 0.11 * s * k, -base_crouch - 0.055 * m.leg_len * k),
            (5.0 - 6.0 * k, base_yaw * 0.55 - 10.0 * k, -4.0 * k),
            (7.0 + hunch * 0.4 - 16.0 * k, base_yaw * 0.30 - 12.0 * k, -3.0 * k),
            (4.0 + hunch * 0.3 - 14.0 * k, base_yaw * 0.25 - 10.0 * k, 0.0),
            (-hunch * 0.3 - 8.0 * hk, 6.0 * hk, 0.0),
            (-18.0 * hk, 14.0 * hk, 8.0 * hk),
            (8.0 * k, -6.0 * k, 8.0 * k, -6.0 * k),
        )

        stance_w = (1.55 if is_boss else 1.35) * m.foot_x
        if w == "2h":
            _place_legs(m, Vector((stance_w * 1.05, 0.14 * s, m.ankle_z)), Vector((-stance_w, -0.18 * s, m.ankle_z)),
                        l_yaw=26.0, r_yaw=-12.0)
        else:
            _place_legs(m, Vector((stance_w, -0.18 * s, m.ankle_z)), Vector((-stance_w * 1.05, 0.20 * s, m.ankle_z)),
                        l_yaw=10.0, r_yaw=-28.0)

        if w == "2h":
            r_pos = Vector((-0.24 * s - 0.04 * s * k, -0.26 * s + 0.12 * s * k, m.hip_z + 0.02 * s + 0.04 * s * k))
            _place_two_hand_axe(m, r_pos, Vector((0.52 + 0.10 * k, -0.48 + 0.24 * k, 0.71)),
                                Vector((-0.22, -0.92, -0.32)),
                                Vector((-0.70 * s, 0.22 * s, m.sh_z - 0.22 * s)),
                                Vector((0.66 * s, 0.18 * s, m.sh_z - 0.20 * s)), off)
        elif w == "bow":
            l_pos = Vector((0.20 * s + 0.08 * s * k, -0.42 * s + 0.12 * s * k, m.hip_z + 0.16 * s + 0.06 * s * k))
            _place_grip_arm(m, "l", l_pos, Vector((0.12, -0.05 + 0.18 * k, 0.98)), Vector((0.0, -1.0, 0.0)),
                            Vector((m.sh_x + 0.34 * s, 0.18 * s, m.sh_z - 0.16 * s)), edge_is_neg_y=True)
            r_pos = Vector((-0.24 * s - 0.08 * s * k, -0.16 * s + 0.10 * s * k, m.hip_z + 0.14 * s + 0.06 * s * k))
            _place_hand_free(m, "r", r_pos, Vector((-m.sh_x - 0.36 * s, 0.28 * s, m.sh_z - 0.14 * s)),
                             Vector((0.3, -0.6, 0.5)), Vector((0.0, -0.5, 0.85)))
        elif w == "none":
            r_w = Vector((-0.22 * s - 0.08 * s * k, -0.24 * s + 0.12 * s * k, m.hip_z + 0.18 * s + 0.08 * s * k))
            l_w = Vector((0.24 * s + 0.08 * s * k, -0.24 * s + 0.12 * s * k, m.hip_z + 0.18 * s + 0.08 * s * k))
            _place_hand_free(m, "r", r_w, Vector((-m.sh_x - 0.30 * s, 0.22 * s, m.sh_z - 0.22 * s)),
                             Vector((0.2, -0.7, 0.6)), Vector((0.0, -0.5, 0.85)))
            _place_hand_free(m, "l", l_w, Vector((m.sh_x + 0.30 * s, 0.22 * s, m.sh_z - 0.22 * s)),
                             Vector((-0.2, -0.7, 0.6)), Vector((0.0, -0.5, 0.85)))
        else:
            r_pos = Vector((-m.sh_x - 0.09 * s - 0.08 * s * k, -0.28 * s + 0.12 * s * k, m.hip_z + 0.05 * s + 0.05 * s * k))
            _place_grip_arm(m, "r", r_pos, Vector((-0.30 - 0.08 * k, -0.76 + 0.22 * k, 0.58)), Vector((0.18, -0.65, -0.74)),
                            Vector((-m.sh_x - 0.36 * s, 0.28 * s, m.sh_z - 0.20 * s)))
            l_pos = Vector((0.30 * s + 0.08 * s * k, -0.26 * s + 0.12 * s * k, m.hip_z + 0.06 * s + 0.04 * s * k))
            _shield_arm_pose(m, l_pos, Vector((0.58 + 0.22 * k, -0.81 + 0.15 * k, 0.12)), Vector((-0.10, -0.08, 0.99)),
                             Vector((m.sh_x + 0.36 * s, 0.20 * s, m.sh_z - 0.20 * s)))

    rig.make_sampled_action(m.arm, "hit", 16, pose, cyclic=False)


# ---------------------------------------------------------------------------
# 8. DEATH (42 frames = 1.40s) — Gravity Collapse Flush on the Stone Floor!
# ---------------------------------------------------------------------------

def _build_death(m: RigMetrics, style: dict):
    """Natural knee-buckle -> smooth gravity-accelerated fall -> thud bounce -> corpse flush on z >= 0!
    Uses hips translation (NOT root tip-over) and explicit mid-fall waypoints so the drop flows organically.
    """
    s = m.scale
    w = style.get("weapon", "1h")
    is_boss = style.get("archetype") == "boss"

    # Ground rest height for pelvis (thick enough that back armor/ribs sit flush on top of z=0!)
    ground_hip_z = (0.17 if is_boss else 0.145) * s
    drop_to_ground = ground_hip_z - m.hip_z  # negative delta bringing hips down to ground_hip_z

    # Phase 1 (0..10): stagger & knees buckle sharply downward while feet stay planted
    # Phase 2 (10..28): smooth quadratic gravity fall onto back/slightly left side (explicit mid-fall waypoints!)
    # Phase 3 (28..36): floor impact micro-bounce & limb/head relaxation onto stone
    # Phase 4 (36..42): still lootable corpse rest
    hip_z_k = [
        (0, -0.08 * m.leg_len),
        (10, -0.32 * m.leg_len, "out"),
        (18, rig.lerp(-0.32 * m.leg_len, drop_to_ground, 0.34), "in_out"),
        (23, rig.lerp(-0.32 * m.leg_len, drop_to_ground, 0.72), "in"),
        (28, drop_to_ground, "in"),
        (32, drop_to_ground + 0.022 * s, "out"),
        (37, drop_to_ground, "in_out"),
        (42, drop_to_ground, "linear"),
    ]
    hip_y_k = [
        (0, 0.02 * s),
        (10, 0.16 * s, "out"),
        (18, 0.34 * s, "in_out"),
        (28, 0.56 * s, "in_out"),
        (36, 0.62 * s, "out"),
        (42, 0.62 * s, "linear"),
    ]
    # Smooth accelerating fall arc from upright (5) -> hunch (14) -> mid-tilt (-26) -> steep (-64) -> floor (-86)
    hips_pitch_k = [
        (0, 5.0),
        (10, 14.0, "in_out"),
        (18, -26.0, "in_out"),
        (23, -64.0, "in"),
        (28, -86.0, "in"),
        (32, -82.0, "out"),
        (37, -86.0, "in_out"),
        (42, -86.0, "linear"),
    ]
    hips_roll_k = [(0, 0.0), (10, 4.0, "in_out"), (20, 8.0, "in_out"), (28, 12.0, "in_out"), (37, 14.0, "out"), (42, 14.0, "linear")]
    hips_yaw_k = [(0, 10.0), (10, -4.0, "in_out"), (28, -12.0, "in_out"), (42, -12.0, "linear")]

    spine_p_k = [(0, 6.0), (10, 20.0, "out"), (18, 16.0, "in_out"), (28, 4.0, "in"), (33, -2.0, "out"), (37, 2.0, "in_out"), (42, 2.0, "linear")]
    head_p_k = [(0, -4.0), (10, 24.0, "out"), (20, 20.0, "in_out"), (27, 8.0, "in"), (31, -8.0, "in"), (36, 4.0, "out"), (42, 4.0, "linear")]
    head_yaw_k = [(0, 0.0), (10, -10.0, "in_out"), (29, 24.0, "in_out"), (37, 32.0, "out"), (42, 32.0, "linear")]

    # Feet stay planted during buckle (0..12), then legs sprawl smoothly forward resting cleanly on floor!
    l_ank_k = [
        (0, (1.35 * m.foot_x, -0.18 * s, m.ankle_z)),
        (12, (1.35 * m.foot_x, -0.18 * s, m.ankle_z), "linear"),
        (20, (0.20 * s, -0.22 * s, m.ankle_z + 0.02 * s), "in_out"),
        (28, (0.22 * s, -0.26 * s, m.ankle_z + 0.03 * s), "in"),
        (35, (0.24 * s, -0.24 * s, m.ankle_z + 0.01 * s), "out"),
        (42, (0.24 * s, -0.24 * s, m.ankle_z + 0.01 * s), "linear"),
    ]
    r_ank_k = [
        (0, (-1.40 * m.foot_x, 0.20 * s, m.ankle_z)),
        (12, (-1.40 * m.foot_x, 0.20 * s, m.ankle_z), "linear"),
        (20, (-0.18 * s, 0.02 * s, m.ankle_z + 0.03 * s), "in_out"),
        (28, (-0.18 * s, -0.14 * s, m.ankle_z + 0.04 * s), "in"),
        (35, (-0.22 * s, -0.18 * s, m.ankle_z + 0.01 * s), "out"),
        (42, (-0.22 * s, -0.18 * s, m.ankle_z + 0.01 * s), "linear"),
    ]

    # Arms collapse helplessly with smooth mid-fall tracking then splay out resting ABOVE floor (z >= 0.12*s)
    r_arm_k = [
        (0, (-0.26 * s, -0.28 * s, m.hip_z + 0.05 * s)),
        (10, (-0.34 * s, -0.14 * s, m.hip_z - 0.24 * s), "out"),
        (19, (-0.44 * s, 0.28 * s, m.hip_z - 0.42 * s), "in_out"),
        (29, (-0.54 * s, 0.88 * s, 0.15 * s), "in"),
        (33, (-0.58 * s, 0.90 * s, 0.19 * s), "out"),
        (38, (-0.60 * s, 0.92 * s, 0.12 * s), "in_out"),
        (42, (-0.60 * s, 0.92 * s, 0.12 * s), "linear"),
    ]
    l_arm_k = [
        (0, (0.30 * s, -0.26 * s, m.hip_z + 0.06 * s)),
        (10, (0.36 * s, -0.06 * s, m.hip_z - 0.20 * s), "out"),
        (19, (0.48 * s, 0.34 * s, m.hip_z - 0.40 * s), "in_out"),
        (30, (0.58 * s, 0.96 * s, 0.16 * s), "in"),
        (34, (0.62 * s, 0.98 * s, 0.20 * s), "out"),
        (38, (0.64 * s, 1.00 * s, 0.12 * s), "in_out"),
        (42, (0.64 * s, 1.00 * s, 0.12 * s), "linear"),
    ]

    def pose(arm, f, phase):
        if f == 0:
            _pose_combat_guard(m, style)
            return
        hz = float(rig.sample_curve(f, hip_z_k))
        hy = float(rig.sample_curve(f, hip_y_k))
        hp = float(rig.sample_curve(f, hips_pitch_k))
        hr = float(rig.sample_curve(f, hips_roll_k))
        hyw = float(rig.sample_curve(f, hips_yaw_k))
        sp = float(rig.sample_curve(f, spine_p_k))
        hdp = float(rig.sample_curve(f, head_p_k))
        hdy = float(rig.sample_curve(f, head_yaw_k))

        _set_torso(arm, (0.0, hy, hz), (hp, hyw, hr), (sp * 0.6, 0.0, 0.0), (sp * 0.4, 0.0, 0.0),
                   (hdp * 0.35, hdy * 0.3, 0.0), (hdp * 0.65, hdy * 0.7, 10.0 * rig.smoothstep(f / 32.0)),
                   (0.0, 0.0, 0.0, 0.0))

        la = rig.sample_curve(f, l_ank_k)
        ra = rig.sample_curve(f, r_ank_k)
        # During fall, knees transition smoothly from forward (-Y) to upward (+Z) so legs rest naturally on stone!
        fall_k = rig.smoothstep((f - 10.0) / 18.0)
        for side_s, ank, yaw, sgn in (("l", la, 18.0 * fall_k + 8.0, 1.0), ("r", ra, -26.0 * fall_k - 14.0, -1.0)):
            hip_p = arm.pose.bones["thigh_" + side_s].head
            k_dir = Vector((sgn * 0.25, -1.0 * (1.0 - fall_k), 1.0 * fall_k)).normalized()
            pole = (hip_p + ank) * 0.5 + k_dir * (0.8 * s)
            rig.solve_2bone_ik(arm, "thigh_" + side_s, "shin_" + side_s, ank, pole, flip_z=False, soft_zone=0.05)
        bpy.context.view_layer.update()
        # Relaxed splayed feet on ground
        rig.orient_foot_world(arm, "l", toe_pitch_deg=-38.0 * fall_k, yaw_deg=10.0 + 24.0 * fall_k, roll_deg=-15.0 * fall_k)
        rig.orient_foot_world(arm, "r", toe_pitch_deg=-32.0 * fall_k, yaw_deg=-22.0 - 20.0 * fall_k, roll_deg=18.0 * fall_k)

        rp = rig.sample_curve(f, r_arm_k)
        lp = rig.sample_curve(f, l_arm_k)
        # Elbow poles lift slightly ABOVE floor (+Z) once fallen so elbows never dip below z=0
        r_pole = Vector((rp.x - 0.25 * s, rp.y + 0.10 * s, max(0.22 * s, rp.z + 0.25 * s)))
        l_pole = Vector((lp.x + 0.25 * s, lp.y + 0.10 * s, max(0.22 * s, lp.z + 0.25 * s)))
        if w in ("1h", "2h"):
            # Weapon drops gradually from guard orientation down to resting flat alongside body on the flagstones!
            sh_start = Vector((0.52, -0.48, 0.71)) if w == "2h" else Vector((-0.30, -0.76, 0.58))
            sh_end = Vector((-0.45, 0.88, 0.08))
            ed_start = Vector((-0.22, -0.92, -0.32)) if w == "2h" else Vector((0.18, -0.65, -0.74))
            ed_end = Vector((0.88, 0.45, 0.12))
            _place_grip_arm(m, "r", rp, sh_start.lerp(sh_end, fall_k), ed_start.lerp(ed_end, fall_k), r_pole)
        else:
            _place_hand_free(m, "r", rp, r_pole, Vector((-0.6, 0.8, 0.0)), Vector((0.0, 0.0, 1.0)))
        if w == "bow":
            b_up = Vector((0.08, -0.05, 0.99)).lerp(Vector((0.35, 0.93, 0.08)), fall_k)
            b_fw = Vector((0.0, -1.0, -0.05)).lerp(Vector((0.0, 0.0, -1.0)), fall_k)
            _place_grip_arm(m, "l", lp, b_up, b_fw, l_pole, edge_is_neg_y=True)
        elif w == "1h" and style.get("archetype") == "crawler":
            # Smoothly rotate shield from upright left-flank carry down onto the flagstones (NEVER flips flat mid-stumble!)
            sf = Vector((0.58, -0.81, 0.08)).lerp(Vector((0.15, 0.05, 0.98)), fall_k)
            su = Vector((-0.10, -0.08, 0.99)).lerp(Vector((0.40, 0.91, 0.06)), fall_k)
            _shield_arm_pose(m, lp, sf, su, l_pole)
        else:
            _place_hand_free(m, "l", lp, l_pole, Vector((0.6, 0.8, 0.0)), Vector((0.0, 0.0, 1.0)))

    rig.make_sampled_action(m.arm, "death", 42, pose, cyclic=False)

    # Automated sanity check: verify final corpse frame sits flush ABOVE floor z=0 (no underground sinking!)
    rig.reset_pose(m.arm)
    pose(m.arm, 42, 1.0)
    bpy.context.view_layer.update()
    for bn in ("hips", "chest", "head"):
        z = m.arm.pose.bones[bn].head.z
        assert z >= 0.04, f"{m.arm.name} death final {bn} sank underground (z={z:.3f}m)"
    rig.reset_pose(m.arm)


# ---------------------------------------------------------------------------
# Public entry point called by build_characters.py
# ---------------------------------------------------------------------------

def animate_character(arm_ob, style: dict, extra=(), grip_r=None, grip_l=None):
    """Generates the full biomechanical animation suite for one rigged character."""
    m = RigMetrics(arm_ob, grip_r, grip_l)
    _build_idle(m, style)
    _build_idle_combat(m, style)
    _build_locomotion(m, style, run=False)
    _build_locomotion(m, style, run=True)
    if style.get("weapon") == "2h":
        _build_attack_2h(m, style, clip_name="attack", vertical_slam=False)
    else:
        _build_attack_1h(m, style, clip_name="attack")
    _build_hit(m, style)
    _build_death(m, style)

    for e in extra:
        if e == "shoot":
            _build_shoot(m, style)
        elif e == "roar":
            _build_roar(m, style)
        elif e == "slam":
            _build_attack_2h(m, style, clip_name="slam", vertical_slam=True)
        elif e == "talk":
            _build_talk(m, style)
        elif e == "block":
            _build_block(m, style)
        elif e == "cast":
            _build_cast(m, style)
        elif e == "cast_r":
            _build_cast(m, style, clip_name="cast_r", mirror=True)
        elif e == "cast_dual":
            _build_cast(m, style, clip_name="cast_dual", both=True)
        elif e == "dual":
            # Dual-wield set (FB-014): guard, right swing with the left blade on guard, mirrored left swing
            dual = dict(style, weapon="dual")
            _build_idle_combat(m, dual, clip_name="idle_dual")
            _build_attack_1h(m, dual, clip_name="attack_dual")
            _build_attack_1h(m, dual, clip_name="attack_l", mirror=True)
        elif e == "draw_hold":
            _build_draw_hold(m, dict(style, weapon="bow"))
        elif e == "bow_shoot":
            _build_bow_shoot(m, dict(style, weapon="bow"))
        elif e == "bow_draw":
            _build_bow_draw(m, dict(style, weapon="bow"))
        elif e == "attack_2h":
            _build_attack_2h(m, dict(style, weapon="2h", weapon_scale=1.0), clip_name="attack_2h", vertical_slam=False)
