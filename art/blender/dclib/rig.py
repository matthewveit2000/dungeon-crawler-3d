"""Humanoid rig, skin-modifier bodies, distance-based smooth skinning and keyframe animation DSL.

Skeleton convention (Blender): character faces -Y, left side (+X) bones end in '_l'.
Every bone's local Z axis is rolled to point FORWARD (-Y), so for every bone a positive local-X
rotation swings the bone tip forward (spine bends forward, legs/arms swing forward, elbows flex).
"""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

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
# Animation DSL
# ---------------------------------------------------------------------------

def _apply_pose(arm_ob, pose):
    for pb in arm_ob.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bname, val in pose.items():
        if bname == "_loc":
            pb = arm_ob.pose.bones["root"]
            pb.location = val
            continue
        pb = arm_ob.pose.bones.get(bname)
        if pb is None:
            continue
        pb.rotation_euler = tuple(math.radians(a) for a in val)


def make_action(arm_ob, name, keys, interpolation="BEZIER"):
    """keys: list of (frame, pose_dict). Bones absent from a pose are keyed at rest.
    Each action is pushed onto its own NLA track so the glTF exporter emits it as a clip."""
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
            if bn == "root":
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
    _apply_pose(arm_ob, {})
    return act


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


def mix(a, b, t):
    """Blend two pose dicts (missing bones treated as rest)."""
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
