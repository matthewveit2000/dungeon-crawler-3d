"""Humanoid rig, skin-modifier bodies, distance-based smooth skinning, analytical 2-bone IK,
world-space orientation helpers, and sampled biomechanical animation DSL.

Skeleton convention (Blender): character faces -Y, left side (+X) bones end in '_l'.
Every bone's local Z axis is rolled to point FORWARD (-Y) (feet point +Z up), and local +Y runs
from head to tail. World-space helpers convert cleanly between armature space (+X left, -Y fwd, +Z up)
and bone-local space so pelvic motion, ground contact, 2-hand grips and bow draws stay exact.
"""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

from . import core

BONES = [
    # name, head, tail, parent
    ("root", (0, 0, 0.0), (0, 0, 0.25), None),
    ("hips", (0, 0, 0.98), (0, 0, 1.1), "root"),
    ("spine", (0, 0, 1.1), (0, 0, 1.28), "hips"),
    ("chest", (0, 0, 1.28), (0, 0, 1.47), "spine"),
    ("neck", (0, 0, 1.47), (0, -0.01, 1.57), "chest"),
    ("head", (0, -0.01, 1.57), (0, -0.01, 1.8), "neck"),
    ("clavicle_l", (0.03, 0.0, 1.42), (0.18, 0.01, 1.43), "chest"),
    ("upper_arm_l", (0.19, 0.01, 1.42), (0.31, 0.03, 1.16), "clavicle_l"),
    ("forearm_l", (0.31, 0.03, 1.16), (0.40, -0.01, 0.93), "upper_arm_l"),
    ("hand_l", (0.40, -0.01, 0.93), (0.43, -0.03, 0.84), "forearm_l"),
    ("thigh_l", (0.1, 0.0, 0.95), (0.115, -0.015, 0.52), "hips"),
    ("shin_l", (0.115, -0.015, 0.52), (0.115, 0.02, 0.09), "thigh_l"),
    ("foot_l", (0.115, 0.02, 0.09), (0.115, -0.12, 0.025), "shin_l"),
]


def mirrored_bones():
    out = []
    for (n, h, t, p) in BONES:
        out.append((n, h, t, p))
        if n.endswith("_l"):
            out.append((n[:-2] + "_r", (-h[0], h[1], h[2]), (-t[0], t[1], t[2]), (p[:-2] + "_r") if p and p.endswith("_l") else p))
    return out


class Proportions:
    """Scales the base skeleton: height (overall), width (shoulders/hips), arm_len, leg_len, hunch."""

    def __init__(self, height=1.8, width=1.0, arm=1.0, leg=1.0, head=1.0, hunch=0.0, neck=1.0):
        self.height = height
        self.width = width
        self.arm = arm
        self.leg = leg
        self.head = head
        self.hunch = hunch
        self.neck = neck

    def joints(self):
        s = self.height / 1.8
        js = {}
        for (n, h, t, p) in mirrored_bones():
            js[n] = [Vector(h), Vector(t), p]
        # width
        for n in js:
            for k in (0, 1):
                v = js[n][k]
                if n.startswith(("clavicle", "upper_arm", "forearm", "hand")):
                    v.x *= self.width
                elif n.startswith(("thigh", "shin", "foot")):
                    v.x *= 0.85 + 0.15 * self.width
        # leg length (scale z below hips), arms
        hip_z = 0.98
        for n in js:
            for k in (0, 1):
                v = js[n][k]
                if n.startswith(("thigh", "shin", "foot")) or n == "root":
                    v.z *= self.leg
                elif v.z >= 0.9:
                    v.z = hip_z * self.leg + (v.z - hip_z)
        for side in ("_l", "_r"):
            sh = js["upper_arm" + side][0]
            for n in ("upper_arm", "forearm", "hand"):
                for k in (0, 1):
                    if n == "upper_arm" and k == 0:
                        continue
                    v = js[n + side][k]
                    js[n + side][k] = sh + (v - sh) * self.arm
            js["forearm" + side][0] = js["upper_arm" + side][1].copy()
            js["hand" + side][0] = js["forearm" + side][1].copy()
        # neck / head size
        nb = js["neck"][0]
        js["neck"][1] = nb + (js["neck"][1] - nb) * self.neck
        js["head"][0] = js["neck"][1].copy()
        js["head"][1] = js["head"][0] + Vector((0, 0, 0.23 * self.head))
        # hunch: push chest/neck/head forward & down
        if self.hunch:
            for n in ("chest", "neck", "head", "clavicle_l", "clavicle_r", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r"):
                for k in (0, 1):
                    v = js[n][k]
                    f = max(0.0, (v.z - 1.2 * self.leg) / 0.6)
                    v.y -= self.hunch * 0.12 * f
                    v.z -= self.hunch * 0.05 * f
        for n in js:
            js[n][0] = js[n][0] * s
            js[n][1] = js[n][1] * s
        return js


def build_armature(js, name="Armature"):
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    core.link(ob)
    core.select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = {}
    for n, (h, t, p) in js.items():
        eb = arm.edit_bones.new(n)
        eb.head = h
        eb.tail = t
        d = (t - h).normalized()
        if abs(d.y) > 0.8:
            eb.align_roll(Vector((0, 0, 1)))
        else:
            eb.align_roll(Vector((0, -1, 0)))
        ebs[n] = eb
    for n, (h, t, p) in js.items():
        if p:
            ebs[n].parent = ebs[p]
            ebs[n].use_connect = (ebs[p].tail - ebs[n].head).length < 1e-4
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


# ---------------------------------------------------------------------------
# Skin-modifier body
# ---------------------------------------------------------------------------

def skin_body(points, edges, radii, name="Body", mat="skin_human", subsurf=1, smooth=0.5):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in points], edges, [])
    me.update()
    ob = bpy.data.objects.new(name, me)
    core.link(ob)
    sk = ob.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = smooth
    for i, r in enumerate(radii):
        me.skin_vertices[0].data[i].radius = r if isinstance(r, (tuple, list)) else (r, r)
    me.skin_vertices[0].data[0].use_root = True
    ss = ob.modifiers.new("Sub", "SUBSURF")
    ss.levels = subsurf
    ss.render_levels = subsurf
    core.apply_modifiers(ob)
    core.set_material(ob, mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def humanoid_skin(js, r):
    """Builds a skin graph from joints. r: dict of radii (x, y) per landmark."""
    pts, edges, rad = [], [], []

    def add(p, rr):
        pts.append(Vector(p))
        rad.append(rr)
        return len(pts) - 1
    hips = js["hips"][0]
    pelvis = add(hips, r["pelvis"])
    belly = add(js["spine"][0] + Vector((0, -0.012, 0)), r["belly"])
    edges.append((pelvis, belly))
    chest = add(js["chest"][0] + Vector((0, -0.01, 0.04)), r["chest"])
    edges.append((belly, chest))
    upper = add(js["chest"][1] + Vector((0, 0.0, -0.04)), r["upper_chest"])
    edges.append((chest, upper))
    neck = add(js["neck"][0].lerp(js["neck"][1], 0.6), r["neck"])
    edges.append((upper, neck))
    for side in ("_l", "_r"):
        sh = add(js["upper_arm" + side][0], r["shoulder"])
        edges.append((upper, sh))
        mid_u = add(js["upper_arm" + side][0].lerp(js["upper_arm" + side][1], 0.5), r["bicep"])
        edges.append((sh, mid_u))
        el = add(js["forearm" + side][0], r["elbow"])
        edges.append((mid_u, el))
        mid_f = add(js["forearm" + side][0].lerp(js["forearm" + side][1], 0.4), r["forearm"])
        edges.append((el, mid_f))
        wr = add(js["hand" + side][0], r["wrist"])
        edges.append((mid_f, wr))
        hp = add(js["thigh" + side][0] + Vector((0, 0, -0.02)), r["hip"])
        edges.append((pelvis, hp))
        mid_t = add(js["thigh" + side][0].lerp(js["thigh" + side][1], 0.45), r["thigh"])
        edges.append((hp, mid_t))
        kn = add(js["shin" + side][0], r["knee"])
        edges.append((mid_t, kn))
        calf = add(js["shin" + side][0].lerp(js["shin" + side][1], 0.35) + Vector((0, 0.012, 0)), r["calf"])
        edges.append((kn, calf))
        an = add(js["foot" + side][0], r["ankle"])
        edges.append((calf, an))
        toe = add(js["foot" + side][1] + Vector((0, 0, 0.02)), r["toe"])
        edges.append((an, toe))
    return pts, edges, rad


DEFAULT_RADII = {
    "pelvis": (0.15, 0.11), "belly": (0.14, 0.1), "chest": (0.16, 0.11), "upper_chest": (0.17, 0.1),
    "neck": (0.055, 0.055), "shoulder": (0.06, 0.06), "bicep": (0.052, 0.05), "elbow": (0.042, 0.042),
    "forearm": (0.045, 0.04), "wrist": (0.032, 0.026), "hip": (0.085, 0.08), "thigh": (0.08, 0.078),
    "knee": (0.058, 0.058), "calf": (0.06, 0.058), "ankle": (0.04, 0.04), "toe": (0.04, 0.03),
}


# ---------------------------------------------------------------------------
# Skinning
# ---------------------------------------------------------------------------

def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length, t


def auto_weights(mesh_ob, js, exclude=("root",), power=5.0, max_bones=3):
    """Smooth distance-based skin weights (deterministic alternative to bone-heat)."""
    me = mesh_ob.data
    names = [n for n in js if n not in exclude]
    groups = {n: (mesh_ob.vertex_groups.get(n) or mesh_ob.vertex_groups.new(name=n)) for n in names}
    for v in me.vertices:
        p = v.co
        cands = []
        for n in names:
            if n.endswith("_l") and p.x < -0.05:
                continue
            if n.endswith("_r") and p.x > 0.05:
                continue
            h, t, _ = js[n]
            d, tt = _seg_dist(p, h, t)
            cands.append((d, n))
        cands.sort()
        cands = cands[:max_bones]
        ws = [(1.0 / (max(d, 0.004) ** power), n) for d, n in cands]
        tot = sum(w for w, _ in ws)
        for w, n in ws:
            if w / tot > 0.02:
                groups[n].add([v.index], w / tot, "REPLACE")


def rigid_weight(mesh_ob, bone, weight=1.0):
    vg = mesh_ob.vertex_groups.get(bone) or mesh_ob.vertex_groups.new(name=bone)
    vg.add([v.index for v in mesh_ob.data.vertices], weight, "REPLACE")


def blend_weight(mesh_ob, fn):
    """fn(co) -> dict bone->weight for each vertex (normalised here)."""
    for v in mesh_ob.data.vertices:
        ws = fn(v.co)
        tot = sum(ws.values()) or 1.0
        for b, w in ws.items():
            vg = mesh_ob.vertex_groups.get(b) or mesh_ob.vertex_groups.new(name=b)
            vg.add([v.index], w / tot, "REPLACE")


def bind(mesh_ob, arm_ob):
    mesh_ob.parent = arm_ob
    m = mesh_ob.modifiers.new("Armature", "ARMATURE")
    m.object = arm_ob
    return m


# ---------------------------------------------------------------------------
# Easing & Biomechanical Curve Helpers
# ---------------------------------------------------------------------------

def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if x < lo else (hi if x > hi else x)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def vlerp(a, b, t: float) -> Vector:
    return Vector(a).lerp(Vector(b), t)


def smoothstep(t: float) -> float:
    t = clamp(t)
    return t * t * (3.0 - 2.0 * t)


def smootherstep(t: float) -> float:
    t = clamp(t)
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def apply_ease(t: float, kind: str = "in_out") -> float:
    t = clamp(t)
    if kind == "linear":
        return t
    if kind == "in":
        return t * t
    if kind == "in_cubic":
        return t * t * t
    if kind == "in_quart":
        return t * t * t * t
    if kind == "out":
        u = 1.0 - t
        return 1.0 - u * u
    if kind == "out_cubic":
        u = 1.0 - t
        return 1.0 - u * u * u
    if kind == "out_quart":
        u = 1.0 - t
        return 1.0 - u * u * u * u
    if kind == "back_out":
        c1 = 1.4
        c3 = c1 + 1.0
        u = t - 1.0
        return 1.0 + c3 * u * u * u + c1 * u * u
    if kind == "gravity":
        # Accelerates smoothly under gravity (quadratic)
        return t * t
    if kind == "in_out":
        return smootherstep(t)
    return smoothstep(t)


def sample_curve(frame: float, keys: list) -> float | Vector:
    """keys: list of (frame, value[, ease_into_this_key]). Supports floats, tuples or Vectors."""
    if frame <= keys[0][0]:
        v = keys[0][1]
        return Vector(v) if isinstance(v, (tuple, list, Vector)) else float(v)
    for i in range(len(keys) - 1):
        f0, v0 = keys[i][0], keys[i][1]
        f1, v1 = keys[i + 1][0], keys[i + 1][1]
        if frame <= f1 or i == len(keys) - 2:
            ease_kind = keys[i + 1][2] if len(keys[i + 1]) > 2 else "in_out"
            u = apply_ease((frame - f0) / max(1e-6, f1 - f0), ease_kind)
            if isinstance(v0, (tuple, list, Vector)):
                return Vector(v0).lerp(Vector(v1), u)
            return float(v0) + (float(v1) - float(v0)) * u
    v = keys[-1][1]
    return Vector(v) if isinstance(v, (tuple, list, Vector)) else float(v)


# ---------------------------------------------------------------------------
# World-Space Pose & Analytical 2-Bone IK Engine
# ---------------------------------------------------------------------------

def basis_from_yz(y_dir: Vector, z_hint: Vector) -> Matrix:
    """Right-handed 3x3 matrix with columns (X, Y, Z), Y along y_dir, Z aligned to z_hint."""
    y = Vector(y_dir).normalized()
    zh = Vector(z_hint)
    z = zh - y * zh.dot(y)
    if z.length_squared < 1e-8:
        alt = Vector((0, -1, 0)) if abs(y.y) < 0.8 else Vector((1, 0, 0))
        z = alt - y * alt.dot(y)
    z = z.normalized()
    x = y.cross(z).normalized()
    z = x.cross(y).normalized()
    return Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))


def basis_from_zx(z_dir: Vector, x_hint: Vector) -> Matrix:
    """Right-handed 3x3 matrix with columns (X, Y, Z), Z along z_dir, X aligned to x_hint."""
    z = Vector(z_dir).normalized()
    xh = Vector(x_hint)
    x = xh - z * xh.dot(z)
    if x.length_squared < 1e-8:
        alt = Vector((1, 0, 0)) if abs(z.x) < 0.8 else Vector((0, 0, 1))
        x = alt - z * alt.dot(z)
    x = x.normalized()
    y = z.cross(x).normalized()
    x = y.cross(z).normalized()
    return Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))


def reset_pose(arm_ob):
    for pb in arm_ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Quaternion((1.0, 0.0, 0.0, 0.0))
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def _zero_rot(pb) -> Matrix:
    r_rest = pb.bone.matrix_local.to_3x3()
    if pb.parent is None:
        return r_rest
    r_par = pb.parent.matrix.to_3x3()
    r_par_rest = pb.parent.bone.matrix_local.to_3x3()
    return r_par @ r_par_rest.transposed() @ r_rest


def set_bone_euler(arm_ob, bone_name: str, deg_xyz):
    """Set bone-local XYZ rotation in degrees (stored cleanly as quaternion)."""
    pb = arm_ob.pose.bones.get(bone_name)
    if pb is None:
        return
    pb.rotation_mode = "QUATERNION"
    e = Euler((math.radians(deg_xyz[0]), math.radians(deg_xyz[1]), math.radians(deg_xyz[2])), "XYZ")
    pb.rotation_quaternion = e.to_quaternion()


def set_bone_world_rot(arm_ob, bone_name: str, r_world: Matrix):
    """Set pose bone so its armature-space 3x3 orientation equals r_world."""
    pb = arm_ob.pose.bones[bone_name]
    pb.rotation_mode = "QUATERNION"
    r_zero = _zero_rot(pb)
    pb.rotation_quaternion = (r_zero.transposed() @ r_world).to_quaternion()


def set_bone_world_delta(arm_ob, bone_name: str, world_delta):
    """Translate pose bone by a world/armature-space delta (dx_left, dy_back, dz_up)."""
    pb = arm_ob.pose.bones[bone_name]
    r_zero = _zero_rot(pb)
    pb.location = r_zero.transposed() @ Vector(world_delta)


def solve_2bone_ik(
    arm_ob,
    upper_name: str,
    lower_name: str,
    target_world,
    pole_world,
    flip_z: bool = False,
    soft_zone: float = 0.035,
):
    """Exact analytical 2-bone IK in armature space.
    Caller should call bpy.context.view_layer.update() after posing parent torso/hips first.
    flip_z=False for legs (knee points toward +Z/pole), flip_z=True for arms (elbow points toward -Z/pole).
    Returns (mid_joint_world, end_joint_world).
    """
    up_pb = arm_ob.pose.bones[upper_name]
    lo_pb = arm_ob.pose.bones[lower_name]
    A = up_pb.head.copy()
    L1 = up_pb.bone.length
    L2 = lo_pb.bone.length
    T = Vector(target_world)
    P = Vector(pole_world)

    at = T - A
    raw_d = at.length
    max_reach = L1 + L2 - 0.003
    min_reach = abs(L1 - L2) + 0.015
    if raw_d < 1e-6:
        dir_at = Vector((0, 0, -1))
        d = min_reach
    else:
        dir_at = at / raw_d
        # Soft IK compression near full reach prevents knee/elbow snapping
        soft_start = max_reach * (1.0 - soft_zone)
        if raw_d > soft_start:
            over = raw_d - soft_start
            span = max_reach - soft_start
            d = soft_start + span * (1.0 - math.exp(-over / max(1e-5, span)))
        else:
            d = max(min_reach, raw_d)

    cos_a = clamp((L1 * L1 + d * d - L2 * L2) / max(1e-6, 2.0 * L1 * d), -1.0, 1.0)
    sin_a = math.sqrt(max(0.0, 1.0 - cos_a * cos_a))

    pole_v = P - A
    pole_perp = pole_v - dir_at * pole_v.dot(dir_at)
    if pole_perp.length_squared < 1e-8:
        pole_perp = Vector((0, -1, 0)) if not flip_z else Vector((0, 1, 0))
        pole_perp = pole_perp - dir_at * pole_perp.dot(dir_at)
    pole_perp = pole_perp.normalized()

    M = A + (dir_at * cos_a + pole_perp * sin_a) * L1
    E = A + dir_at * d

    z_hint = -pole_perp if flip_z else pole_perp
    r_up = basis_from_yz(M - A, z_hint)
    set_bone_world_rot(arm_ob, upper_name, r_up)

    # Analytically compute lower bone's zero rotation from r_up (no extra depsgraph flush needed)
    r_up_rest = up_pb.bone.matrix_local.to_3x3()
    r_lo_rest = lo_pb.bone.matrix_local.to_3x3()
    r_lo_zero = r_up @ r_up_rest.transposed() @ r_lo_rest
    r_lo = basis_from_yz(E - M, z_hint)
    lo_pb.rotation_mode = "QUATERNION"
    lo_pb.rotation_quaternion = (r_lo_zero.transposed() @ r_lo).to_quaternion()
    return M, E


def orient_foot_world(arm_ob, side_s: str, toe_pitch_deg: float = 0.0, yaw_deg: float = 0.0, roll_deg: float = 0.0):
    """Orient foot_l / foot_r relative to flat ground contact.
    toe_pitch_deg > 0 lifts toes (heel strike); toe_pitch_deg < 0 lifts heel (toe push-off).
    """
    bname = "foot_" + side_s
    pb = arm_ob.pose.bones[bname]
    # Rest bone matrix has the foot flat on z=0 facing -Y
    r_flat = pb.bone.matrix_local.to_3x3()
    # Apply pitch around world -X (+pitch lifts toes upward from -Y toward +Z), yaw around world +Z, roll around world -Y
    r_pitch = Matrix.Rotation(math.radians(-toe_pitch_deg), 3, "X")
    r_yaw = Matrix.Rotation(math.radians(yaw_deg), 3, "Z")
    r_roll = Matrix.Rotation(math.radians(roll_deg), 3, "Y")
    r_world = r_yaw @ r_roll @ r_pitch @ r_flat
    set_bone_world_rot(arm_ob, bname, r_world)


def grip_rest_local_matrix(arm_ob, grip_ob) -> Matrix:
    """Constant transform of a bone-parented Grip Empty relative to its parent hand bone."""
    hand_b = arm_ob.data.bones[grip_ob.parent_bone]
    return hand_b.matrix_local.inverted() @ grip_ob.matrix_world


def orient_hand_for_grip(
    arm_ob,
    side_s: str,
    grip_local_mat: Matrix,
    shaft_world,
    edge_world,
    edge_is_neg_y: bool = False,
):
    """Orient hand_l/hand_r so its Grip socket's +Z (weapon shaft/bow limbs) points along shaft_world
    and either +X (cutting edge) or -Y (bow target back) aligns with edge_world.
    Returns (grip_world_pos, grip_world_rot_3x3).
    """
    hand_name = "hand_" + side_s
    pb = arm_ob.pose.bones[hand_name]
    z = Vector(shaft_world).normalized()
    if edge_is_neg_y:
        # Bow: +Z = limbs up, -Y = forward toward target -> +Y = -edge_world
        y = (-Vector(edge_world))
        y = (y - z * y.dot(z)).normalized()
        x = y.cross(z).normalized()
        r_grip = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z)))
    else:
        r_grip = basis_from_zx(z, Vector(edge_world))
    r_h2g = grip_local_mat.to_3x3()
    r_hand = r_grip @ r_h2g.transposed()
    set_bone_world_rot(arm_ob, hand_name, r_hand)
    # Exact grip position in armature space using hand head (wrist) + rotated local offset
    grip_pos = pb.head + r_hand @ grip_local_mat.to_translation()
    return grip_pos, r_grip


def orient_head_look(arm_ob, look_dir_world=(0, -1, 0), up_world=(0, 0, 1), weight: float = 0.75, tilt_deg: float = 0.0):
    """Blend head orientation toward looking along look_dir_world while respecting torso posture."""
    pb = arm_ob.pose.bones["head"]
    r_zero = _zero_rot(pb)
    fwd = Vector(look_dir_world).normalized()
    up = Vector(up_world).normalized()
    r_target = basis_from_yz(up, fwd)
    if abs(tilt_deg) > 1e-3:
        r_target = r_target @ Matrix.Rotation(math.radians(tilt_deg), 3, "Z")
    q_zero = r_zero.to_quaternion()
    q_tgt = r_target.to_quaternion()
    if q_zero.dot(q_tgt) < 0:
        q_tgt = -q_tgt
    q_blend = q_zero.slerp(q_tgt, clamp(weight))
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (r_zero.transposed() @ q_blend.to_matrix()).to_quaternion()


# ---------------------------------------------------------------------------
# Action Builders (Sampled 30fps Quaternion + Legacy Pose-Dict)
# ---------------------------------------------------------------------------

def _fcurves(act):
    try:
        return list(act.fcurves)
    except Exception:
        out = []
        for layer in getattr(act, "layers", []):
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
        return out


def make_sampled_action(arm_ob, name: str, n_frames: int, pose_fn, cyclic: bool = False):
    """Evaluates pose_fn(arm_ob, frame, phase) at every frame 0..n_frames (30fps), enforces
    quaternion continuity, keys quaternion rotations on all bones + location on root & hips,
    and pushes onto a clean NLA track for glTF export.
    """
    if arm_ob.animation_data is None:
        arm_ob.animation_data_create()
    act = bpy.data.actions.new(name)
    arm_ob.animation_data.action = act
    all_bones = [pb.name for pb in arm_ob.pose.bones]
    prev_q: dict[str, Quaternion] = {}

    for f in range(n_frames + 1):
        phase = (f / n_frames) if n_frames > 0 else 0.0
        if cyclic and f == n_frames:
            phase = 0.0
        reset_pose(arm_ob)
        pose_fn(arm_ob, f, phase)
        for bn in all_bones:
            pb = arm_ob.pose.bones[bn]
            pb.rotation_mode = "QUATERNION"
            q = pb.rotation_quaternion.normalized()
            if bn in prev_q and q.dot(prev_q[bn]) < 0.0:
                q = -q
            pb.rotation_quaternion = q
            prev_q[bn] = q.copy()
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if bn in ("root", "hips"):
                pb.keyframe_insert("location", frame=f)

    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"

    track = arm_ob.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, act)
    strip.name = name
    track.mute = True
    arm_ob.animation_data.action = None
    reset_pose(arm_ob)
    return act


# Legacy pose-dict helpers (preserved for compatibility)
def _apply_pose(arm_ob, pose):
    for pb in arm_ob.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bname, val in pose.items():
        if bname == "_loc":
            set_bone_world_delta(arm_ob, "hips", val)
            continue
        pb = arm_ob.pose.bones.get(bname)
        if pb is None:
            continue
        pb.rotation_euler = tuple(math.radians(a) for a in val)


def make_action(arm_ob, name, keys, interpolation="BEZIER"):
    if arm_ob.animation_data is None:
        arm_ob.animation_data_create()
    act = bpy.data.actions.new(name)
    arm_ob.animation_data.action = act
    all_bones = [pb.name for pb in arm_ob.pose.bones]
    for frame, pose in keys:
        _apply_pose(arm_ob, pose)
        for bn in all_bones:
            pb = arm_ob.pose.bones[bn]
            pb.keyframe_insert("rotation_euler", frame=frame)
            if bn in ("root", "hips"):
                pb.keyframe_insert("location", frame=frame)
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = interpolation
    track = arm_ob.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(keys[0][0]), act)
    strip.name = name
    track.mute = True
    arm_ob.animation_data.action = None
    reset_pose(arm_ob)
    return act


def mix(a, b, t):
    out = {}
    for k in set(a) | set(b):
        va = a.get(k, (0, 0, 0))
        vb = b.get(k, (0, 0, 0))
        out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
    return out


def add(*poses):
    out = {}
    for p in poses:
        for k, v in p.items():
            o = out.get(k, (0, 0, 0))
            out[k] = tuple(x + y for x, y in zip(o, v))
    return out
