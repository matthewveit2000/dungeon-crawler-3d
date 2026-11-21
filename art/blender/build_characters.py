"""Batch 3 — Rigged & animated characters (player crawler, draugr, bone archer, goblin,
Iron Warden boss, safe-room vendor). Each exports one skinned mesh + armature with named clips:
idle, walk, run, attack, hit, death (+ shoot / slam / roar / talk / block / cast / draw_hold per role).

Run: blender -b --python art/blender/build_characters.py -- [--only kind,...] [--preview] [--strip kind:anim]
"""

from __future__ import annotations

import math
import pathlib
import random
import sys
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from dclib import core, premade_retarget, render, rig, shapes  # noqa: E402
from build_props import make_bone, make_skull  # noqa: E402

FPS = 30


# ---------------------------------------------------------------------------
# Geometry helpers anchored on the skeleton
# ---------------------------------------------------------------------------

def frame_between(a, b):
    a, b = Vector(a), Vector(b)
    d = (b - a)
    q = d.normalized().to_track_quat("Z", "Y")
    return Matrix.Translation(a) @ q.to_matrix().to_4x4(), d.length


def limb_tube(a, b, r0, r1, mat, segs=16, bulge=0.0, name="Tube", t0=0.0, t1=1.0, solid=0.0, flare_end=0.0):
    M, L = frame_between(a, b)
    prof = []
    steps = 8
    for k in range(steps + 1):
        t = t0 + (t1 - t0) * k / steps
        r = r0 + (r1 - r0) * (k / steps) + bulge * math.sin(k / steps * math.pi)
        if flare_end and k == steps:
            r += flare_end
        prof.append((r, t * L))
    ob = shapes.lathe(prof, segs, name, mat, cap_bottom=solid <= 0, cap_top=solid <= 0)
    if solid > 0:
        core.add_solidify(ob, solid, 1.0)
        core.apply_modifiers(ob)
    ob.matrix_world = M
    bpy.context.view_layer.update()
    core.apply_transform(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def garment(center_xy, z_top, z_bot, r_top, r_bot, mat, folds=9, fold_amp=0.012, depth=0.78, hem=0.03, seed=0,
            bulge=0.0, segs=32, rows=12, name="Garment", thick=0.008, open_back=False, flare=1.0):
    """Cloth tube (tunic / skirt / robe / sleeve) with vertical folds that deepen toward a frayed hem."""
    import bmesh as _bm
    from mathutils import noise as _n
    rnd = random.Random(seed)
    bm = _bm.new()
    rings = []
    for j in range(rows + 1):
        t = j / rows
        z = z_top + (z_bot - z_top) * t
        r = r_top + (r_bot - r_top) * (t ** flare) + bulge * math.sin(t * math.pi)
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            fa = fold_amp * (0.25 + 0.75 * t)
            rr = r + fa * math.sin(a * folds + seed) + fa * 0.6 * _n.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, t * 3 + seed)))
            zz = z
            if j == rows:
                zz += hem * _n.noise(Vector((a * 2.0, seed * 0.3, 0.5))) - hem * 0.3 * (1 if (i % 3 == 0) else 0)
            ring.append(bm.verts.new((center_xy[0] + math.cos(a) * rr, center_xy[1] + math.sin(a) * rr * depth, zz)))
        rings.append(ring)
    for j in range(rows):
        for i in range(segs):
            k = (i + 1) % segs
            bm.faces.new((rings[j][i], rings[j][k], rings[j + 1][k], rings[j + 1][i]))
    bmesh_obj = core.obj_from_bmesh(bm, name, mat)
    for p in bmesh_obj.data.polygons:
        p.use_smooth = True
    if thick > 0:
        core.add_solidify(bmesh_obj, thick, 1.0)
        core.apply_modifiers(bmesh_obj)
    return bmesh_obj


def bend_around(ob, radius, axis_y=0.0):
    """Wrap a flat XZ cloth panel around a vertical cylinder (radius) so it hugs the body."""
    for v in ob.data.vertices:
        a = v.co.x / radius
        d = radius + (v.co.y - axis_y)
        v.co.x = math.sin(a) * d
        v.co.y = axis_y - math.cos(a) * d + radius
    ob.data.update()


def shell(center, radius, scale, rot, mat, cut_z=-0.2, thick=0.006, name="Shell", seg=24):
    """Sphere-section armour plate (pauldrons, knee cops, helmets)."""
    ob = shapes.sphere(radius, (0, 0, 0), seg=seg, rings=seg // 2, mat=mat, name=name, scale=scale)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut_z * radius * scale[2]], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    if thick > 0:
        core.add_solidify(ob, thick, -1.0)
        core.apply_modifiers(ob)
    from build_props import _xf
    _xf(ob, center, rot)
    return ob


def tag(ob, bone):
    """Assign a whole part rigidly to one bone (stored until join)."""
    ob["dc_bone"] = bone
    return ob


def tag_blend(ob, fn):
    key = len(_BLEND_FNS) + 1
    _BLEND_FNS[key] = fn
    ob["dc_blend"] = True
    ob["_fn_id"] = key
    return ob


_BLEND_FNS = {}


def skin_parts(parts, js, arm_ob, name):
    """Weights every part (auto for bodies, rigid/blended for gear), joins, binds."""
    for p in parts:
        if p.modifiers:
            core.apply_modifiers(p)
        core.init_color(p)
        if "dc_bone" in p.keys():
            rig.rigid_weight(p, p["dc_bone"])
        elif "dc_blend" in p.keys():
            rig.blend_weight(p, _BLEND_FNS[p["_fn_id"]])
        else:
            rig.auto_weights(p, js)
    ob = core.join(parts, name)
    for k in ("dc_bone", "dc_blend", "_fn_id"):
        if k in ob.keys():
            del ob[k]
    core.finalize(ob, smooth_angle=55, uv="box", seed=zlib.crc32(name.encode()) % 997, weathering=0.6)  # stable across runs (hash() is salted per process)
    shapes.bake_vertex_ao(ob, rays=10, dist=0.12, strength=0.55)
    rig.bind(ob, arm_ob)
    return ob


def grip_socket(arm_ob, js, side="r", name=None, offset=0.07, fwd=0.0):
    h, t, _ = js["hand_" + side]
    d = (t - h).normalized()
    p = h + d * offset + Vector((0, -fwd, 0))
    e = bpy.data.objects.new(name or ("Grip" + side.upper()), None)
    core.link(e)
    e.empty_display_size = 0.08
    # Right hand: +Z = weapon shaft forward, +X = cutting edge aligned into strike plane (down/forward).
    # Left hand: +Z = bow/shield grip axis, +X = outer hand face (shield front), -Y = bow target face.
    rot = Matrix.Rotation(math.radians(90), 4, "X")
    if side == "r":
        rot = rot @ Matrix.Rotation(math.radians(-90), 4, "Z")
    e.matrix_world = Matrix.Translation(p) @ rot
    bpy.context.view_layer.update()
    mw = e.matrix_world.copy()
    e.parent = arm_ob
    e.parent_type = "BONE"
    e.parent_bone = "hand_" + side
    bpy.context.view_layer.update()
    e.matrix_world = mw
    return e


def socket_on_bone(arm_ob, bone, name, world_pos, rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    core.link(e)
    from mathutils import Euler
    e.matrix_world = Matrix.Translation(world_pos) @ Euler(rot).to_matrix().to_4x4()
    bpy.context.view_layer.update()
    mw = e.matrix_world.copy()
    e.parent = arm_ob
    e.parent_type = "BONE"
    e.parent_bone = bone
    bpy.context.view_layer.update()
    e.matrix_world = mw
    return e


def fist(js, side, mat, scale=1.0):
    """Gloved/bare fist on the hand bone (fingers curled, thumb over)."""
    h, t, _ = js["hand_" + side]
    d = (t - h)
    M, L = frame_between(h, t)
    parts = []
    palm = shapes.sphere(0.045 * scale, (0, 0, 0), seg=16, rings=10, mat=mat, scale=(0.78, 0.55, 1.0))
    palm.matrix_world = M @ Matrix.Translation((0, -0.006, 0.05 * scale))
    parts.append(palm)
    knuck = shapes.sphere(0.038 * scale, (0, 0, 0), seg=14, rings=8, mat=mat, scale=(0.95, 0.85, 0.6))
    knuck.matrix_world = M @ Matrix.Translation((0, -0.018 * scale, 0.09 * scale))
    parts.append(knuck)
    thumb = shapes.tube([(0.022 * (1 if side == "l" else -1), -0.01, 0.03), (0.026 * (1 if side == "l" else -1), -0.035, 0.07),
                         (0.012 * (1 if side == "l" else -1), -0.04, 0.09)], radius=0.011 * scale, seg=8, mat=mat)
    thumb.matrix_world = M
    parts.append(thumb)
    for p in parts:
        bpy.context.view_layer.update()
        core.apply_transform(p)
    ob = core.join(parts, "Fist_" + side)
    return tag(ob, "hand_" + side)


def boot(js, side, mat="leather_dark", cuff_mat="leather_brown", scale=1.0):
    a, _, _ = js["foot_" + side]
    toe = js["foot_" + side][1]
    parts = []
    foot = shapes.sphere(0.055 * scale, (0, 0, 0), seg=16, rings=10, mat=mat, scale=(0.95, 2.1, 0.8))
    mid = a.lerp(toe, 0.45)
    foot.location = (mid.x, mid.y - 0.01, 0.045 * scale)
    bpy.context.view_layer.update()
    core.apply_transform(foot)
    parts.append(tag(foot, "foot_" + side))
    sole = shapes.box((0.1 * scale, 0.27 * scale, 0.025), (mid.x, mid.y - 0.015, 0.0125), mat="leather_dark", bevel=0.008)
    parts.append(tag(sole, "foot_" + side))
    cuff = limb_tube(js["shin_" + side][0].lerp(js["shin_" + side][1], 0.55), a + Vector((0, 0, 0.02)), 0.066 * scale, 0.06 * scale,
                     cuff_mat, name="BootShaft", flare_end=0.0)
    parts.append(tag(cuff, "shin_" + side))
    return parts


# ---------------------------------------------------------------------------
# Heads & faces
# ---------------------------------------------------------------------------

def head_anchor(js):
    h, t, _ = js["head"]
    return h, t


def skull_head(js, mat="bone", eye_mat="glow_eye_blue", scale=1.25, jaw=True):
    h, t = head_anchor(js)
    sk = make_skull(7, scale=scale, mat=mat, jaw=jaw)
    sk.location = (h.x, h.y - 0.005, h.z - 0.02)
    bpy.context.view_layer.update()
    core.apply_transform(sk)
    parts = [tag(sk, "head")]
    for sx in (-1, 1):
        eye = shapes.sphere(0.014 * scale, (h.x + sx * 0.034 * scale, h.y - 0.095 * scale, h.z + 0.112 * scale), seg=10, rings=6, mat=eye_mat)
        parts.append(tag(eye, "head"))
    return parts


def beard(center, width, length, mat="fur", strands=9, seed=0, curl=0.04, tint=None):
    rnd = random.Random(seed)
    parts = []
    for i in range(strands):
        x = center[0] + (i / (strands - 1) - 0.5) * width
        y0 = center[1]
        z0 = center[2]
        ln = length * (0.7 + 0.3 * math.cos((i / (strands - 1) - 0.5) * math.pi))
        pts = [(x, y0, z0), (x * 0.95, y0 - curl, z0 - ln * 0.5), (x * 0.7 + rnd.uniform(-0.01, 0.01), y0 - curl * 0.6, z0 - ln)]
        st = shapes.tube(pts, radius=0.02 + 0.006 * rnd.random(), seg=8, mat=mat, radii=[1.0, 0.8, 0.25], name="Beard")
        if tint:
            core.tint_part(st, 1.0, tint)
        parts.append(st)
    return parts


def goblin_head(js):
    h, t = head_anchor(js)
    c = Vector((h.x, h.y - 0.03, h.z + 0.1))
    parts = []
    skull = shapes.sphere(0.12, c, seg=24, rings=14, mat="skin_goblin", scale=(1.0, 1.05, 0.95))
    core.displace_noise(skull, amp=0.006, freq=8, seed=5)
    parts.append(skull)
    jaw = shapes.sphere(0.09, c + Vector((0, -0.06, -0.06)), seg=20, rings=10, mat="skin_goblin", scale=(1.1, 0.9, 0.7))
    parts.append(jaw)
    # brow ridge
    parts.append(shapes.tube([(c.x - 0.07, c.y - 0.095, c.z + 0.035), (c.x, c.y - 0.115, c.z + 0.025), (c.x + 0.07, c.y - 0.095, c.z + 0.035)],
                             radius=0.022, seg=8, mat="skin_goblin"))
    # hooked nose
    parts.append(shapes.tube([(c.x, c.y - 0.11, c.z + 0.0), (c.x, c.y - 0.17, c.z - 0.03), (c.x, c.y - 0.19, c.z - 0.065)],
                             radius=0.022, seg=10, mat="skin_goblin", radii=[1.0, 0.8, 0.45]))
    # long ears
    for sx in (-1, 1):
        ear = shapes.prism_from_outline([(0.0, -0.03), (0.16, 0.03), (0.2, 0.07), (0.05, 0.05), (0.0, 0.03)], 0.012,
                                        mat="skin_goblin", bevel=0.004)
        from build_props import _xf
        _xf(ear, (c.x + sx * 0.1, c.y + 0.0, c.z + 0.01), (0, 0, 0) if sx > 0 else (0, 0, math.pi), (1.0, 1.0, 1.0))
        ear.rotation_euler = (0, sx * math.radians(-25), 0)
        bpy.context.view_layer.update()
        core.apply_transform(ear)
        parts.append(ear)
    # eyes (yellow, slit pupils) and grin with teeth
    for sx in (-1, 1):
        parts.append(shapes.sphere(0.024, c + Vector((sx * 0.045, -0.105, 0.0)), seg=12, rings=8, mat="glow_eye_gold"))
        parts.append(shapes.box((0.006, 0.006, 0.026), (c.x + sx * 0.045, c.y - 0.128, c.z), mat="pupil_black"))
    mouth = shapes.box((0.12, 0.02, 0.02), (c.x, c.y - 0.135, c.z - 0.07), mat="pupil_black", bevel=0.008)
    parts.append(mouth)
    for i in range(7):
        x = c.x - 0.05 + i * 0.0166
        parts.append(shapes.cone(0.007, 0.022, (x, c.y - 0.143, c.z - 0.062), seg=4, mat="teeth", rot=(math.pi, 0, 0)))
    return [tag(p, "head") for p in parts]


# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------

def torso_weights(js):
    hz = js["hips"][0].z
    sz = js["spine"][0].z
    cz = js["chest"][0].z
    tz = js["chest"][1].z

    def fn(co):
        if co.z >= tz - 0.05:
            return {"chest": 1.0}
        if co.z >= cz:
            t = (co.z - cz) / max(0.01, tz - 0.05 - cz)
            return {"chest": 0.5 + 0.5 * t, "spine": 0.5 - 0.5 * t}
        if co.z >= sz:
            t = (co.z - sz) / max(0.01, cz - sz)
            return {"spine": 0.6 + 0.2 * t, "chest": 0.2 * t + 0.0001, "hips": 0.4 - 0.4 * t}
        if co.z >= hz - 0.06:
            return {"hips": 0.75, "spine": 0.25}
        drop = min(1.0, (hz - 0.06 - co.z) / 0.5)
        side_b = "thigh_l" if co.x > 0 else "thigh_r"
        cross = min(1.0, abs(co.x) / 0.08)
        return {"hips": 1.0 - 0.65 * drop * cross, side_b: 0.65 * drop * cross + 0.0001}
    return fn


def open_front(ob, y_cut):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < y_cut], context="FACES")
    bm.to_mesh(ob.data)
    bm.free()


def mantle(center, rx, ry, r, mat="fur", seed=0):
    m = shapes.torus(rx, r, center, major=40, minor=10, mat=mat, scale=(1.0, ry / rx, 0.6))
    core.displace_noise(m, amp=r * 0.35, freq=14, seed=seed)
    return m


def build_draugr():
    props = rig.Proportions(height=1.86, width=1.02, hunch=0.5, arm=1.04)
    js = props.joints()
    arm_ob = rig.build_armature(js, "draugr_rig")
    r = dict(rig.DEFAULT_RADII)
    for k in ("bicep", "forearm", "thigh", "calf", "elbow", "knee"):
        r[k] = (r[k][0] * 0.9, r[k][1] * 0.9)
    pts, edges, rad = rig.humanoid_skin(js, r)
    body = rig.skin_body(pts, edges, rad, "Body", "skin_draugr", subsurf=1)
    core.displace_noise(body, amp=0.005, freq=12, seed=3)
    parts = [body]
    parts += skull_head(js, mat="skin_draugr", eye_mat="glow_eye_blue", scale=1.22)
    hh, ht = head_anchor(js)
    parts += [tag(b, "head") for b in beard((hh.x, hh.y - 0.1, hh.z + 0.0), 0.12, 0.3, mat="fur", strands=8, seed=2, tint=(0.62, 0.62, 0.58))]
    helm = shell((hh.x, hh.y + 0.0, hh.z + 0.15), 0.15, (0.95, 1.05, 0.9), (0, 0, 0), "iron_dark", cut_z=-0.1, thick=0.008)
    parts.append(tag(helm, "head"))
    parts.append(tag(shapes.torus(0.143, 0.012, (hh.x, hh.y, hh.z + 0.14), major=40, minor=6, mat="iron_dark", scale=(0.95, 1.05, 1)), "head"))
    parts.append(tag(shapes.box((0.02, 0.012, 0.1), (hh.x, hh.y - 0.15, hh.z + 0.1), mat="iron_dark", bevel=0.004), "head"))
    for sx in (-1, 1):
        horn = shapes.tube([(hh.x + sx * 0.12, hh.y, hh.z + 0.2), (hh.x + sx * 0.22, hh.y + 0.02, hh.z + 0.26),
                            (hh.x + sx * 0.27, hh.y - 0.04, hh.z + 0.36), (hh.x + sx * 0.25, hh.y - 0.09, hh.z + 0.42)],
                           radius=0.03, seg=10, mat="bone", radii=[1.0, 0.8, 0.45, 0.08])
        parts.append(tag(horn, "head"))
    ch = js["chest"][0]
    hp = js["hips"][0]
    tun = garment((0, ch.y - 0.005), js["chest"][1].z - 0.02, hp.z - 0.34, 0.15, 0.2, "cloth_dark", folds=7, fold_amp=0.02,
                  depth=0.72, hem=0.06, seed=4, bulge=0.025, name="Tunic")
    parts.append(tag_blend(tun, torso_weights(js)))
    plate = shell((ch.x, ch.y - 0.01, ch.z + 0.02), 0.17, (1.02, 0.68, 1.05), (math.radians(90), 0, 0), "iron_dark", cut_z=-0.2, thick=0.012)
    parts.append(tag(plate, "chest"))
    for k in range(3):
        parts.append(tag(shapes.box((0.24 - k * 0.03, 0.02, 0.014), (ch.x, ch.y - 0.15, ch.z - 0.02 - k * 0.05), mat="iron_dark", bevel=0.004), "chest"))
    pa = shell(js["upper_arm_l"][0] + Vector((0.02, 0, 0.03)), 0.1, (1.1, 1.0, 0.65), (0, math.radians(30), 0), "iron_dark", cut_z=0.0, thick=0.008)
    parts.append(tag(pa, "upper_arm_l"))
    parts.append(tag(mantle((js["upper_arm_r"][0].x + 0.04, 0.0, js["chest"][1].z - 0.02), 0.11, 0.09, 0.05, seed=7), "clavicle_r"))
    parts.append(tag(shapes.torus(0.15, 0.022, (hp.x, hp.y, hp.z + 0.02), major=36, minor=6, mat="leather_dark", scale=(1, 0.74, 1)), "hips"))
    parts.append(tag(shapes.box((0.05, 0.02, 0.05), (hp.x, hp.y - 0.12, hp.z + 0.02), mat="iron_dark", bevel=0.005), "hips"))
    for side, sx in (("l", 1), ("r", -1)):
        parts.append(tag(limb_tube(js["forearm_" + side][0].lerp(js["forearm_" + side][1], 0.2), js["forearm_" + side][1], 0.05, 0.043,
                                   "leather_dark", name="Bracer"), "forearm_" + side))
        parts.append(tag(limb_tube(js["thigh_" + side][0].lerp(js["thigh_" + side][1], 0.25), js["thigh_" + side][1], 0.085, 0.07,
                                   "cloth_dark", name="Trouser", bulge=0.006), "thigh_" + side))
        parts += boot(js, side, mat="leather_dark", cuff_mat="leather_brown", scale=1.0)
        parts.append(fist(js, side, "skin_draugr"))
        for k in range(3):
            z0 = js["shin_" + side][0].lerp(js["shin_" + side][1], 0.15 + k * 0.12)
            parts.append(tag(shapes.torus(0.058, 0.007, tuple(z0), major=20, minor=5, mat="leather_dark", rot=(0.15 * (k - 1), 0, 0)), "shin_" + side))
    ob = skin_parts(parts, js, arm_ob, "draugr")
    grip_socket(arm_ob, js, "r")
    grip_socket(arm_ob, js, "l")
    return arm_ob, ob, js


def build_crawler():
    """Player crawler (3rd-person): Nordic warrior with horned helm, layered plate, fur mantle, crimson tabard."""
    props = rig.Proportions(height=1.84, width=1.06)
    js = props.joints()
    arm_ob = rig.build_armature(js, "crawler_rig")
    r = dict(rig.DEFAULT_RADII)
    for k in ("bicep", "forearm", "thigh", "calf", "chest", "upper_chest", "shoulder"):
        r[k] = (r[k][0] * 1.08, r[k][1] * 1.06)
    pts, edges, rad = rig.humanoid_skin(js, r)
    body = rig.skin_body(pts, edges, rad, "Body", "cloth_dark", subsurf=1)
    parts = [body]
    hh, ht = head_anchor(js)
    head = shapes.sphere(0.105, (hh.x, hh.y - 0.01, hh.z + 0.1), seg=20, rings=12, mat="skin_human", scale=(0.92, 1.05, 1.1))
    parts.append(tag(head, "head"))
    for sx in (-1, 1):
        parts.append(tag(shapes.sphere(0.012, (hh.x + sx * 0.036, hh.y - 0.1, hh.z + 0.12), seg=8, rings=6, mat="eye_white"), "head"))
    parts += [tag(b, "head") for b in beard((hh.x, hh.y - 0.085, hh.z + 0.05), 0.14, 0.22, mat="fur", strands=9, seed=4, tint=(1.25, 0.72, 0.42))]
    helm = shell((hh.x, hh.y - 0.0, hh.z + 0.135), 0.132, (0.95, 1.05, 1.0), (0, 0, 0), "steel_armor", cut_z=-0.15, thick=0.008)
    parts.append(tag(helm, "head"))
    parts.append(tag(shapes.torus(0.127, 0.012, (hh.x, hh.y, hh.z + 0.12), major=40, minor=6, mat="bronze", scale=(0.95, 1.06, 1)), "head"))
    parts.append(tag(shapes.box((0.022, 0.012, 0.1), (hh.x, hh.y - 0.137, hh.z + 0.085), mat="steel_armor", bevel=0.004), "head"))
    # Mail aventail hung from inside the helm rim: wraps the back and sides of the head and neck, open at the face
    av_r = 0.124
    av = shapes.cloth_panel(0.5, 0.19, cols=18, rows=6, folds=2.5, fold_amp=0.005, seed=11, mat="chainmail", bottom="straight",
                            thickness=0.004, name="Aventail")
    bend_around(av, av_r)
    for v in av.data.vertices:
        v.co.x, v.co.y = -v.co.x, -v.co.y  # wrap toward the face
        f = 1.0 + max(0.0, -v.co.z) * 0.75  # flare over the shoulders
        v.co.x *= f
        v.co.y = (v.co.y + av_r) * f - av_r
    av.data.update()
    from build_props import _xf as _xf_av
    _xf_av(av, (hh.x, hh.y - 0.01 + av_r, hh.z + 0.128))
    parts.append(tag(av, "head"))
    for sx in (-1, 1):
        cheek = shell((hh.x + sx * 0.1, hh.y - 0.04, hh.z + 0.06), 0.06, (0.5, 1.0, 1.2), (0, 0, sx * 0.3), "steel_armor", cut_z=-1.0, thick=0.005)
        parts.append(tag(cheek, "head"))
        horn = shapes.tube([(hh.x + sx * 0.11, hh.y, hh.z + 0.2), (hh.x + sx * 0.2, hh.y + 0.01, hh.z + 0.24),
                            (hh.x + sx * 0.25, hh.y - 0.03, hh.z + 0.33)], radius=0.026, seg=10, mat="bone", radii=[1.0, 0.65, 0.1])
        parts.append(tag(horn, "head"))
    ch = js["chest"][0]
    hp = js["hips"][0]
    tun = garment((0, ch.y), js["chest"][1].z - 0.03, hp.z - 0.3, 0.165, 0.2, "cloth_crimson", folds=8, fold_amp=0.014, depth=0.74,
                  hem=0.02, seed=5, bulge=0.02, name="Gambeson")
    parts.append(tag_blend(tun, torso_weights(js)))
    cuir = shell((ch.x, ch.y - 0.004, ch.z + 0.035), 0.19, (1.06, 0.72, 1.1), (math.radians(90), 0, 0), "steel_armor", cut_z=-0.3, thick=0.012)
    parts.append(tag(cuir, "chest"))
    parts.append(tag(shapes.box((0.012, 0.02, 0.2), (ch.x, ch.y - 0.15, ch.z + 0.04), mat="bronze", bevel=0.004), "chest"))
    back = shell((ch.x, ch.y + 0.002, ch.z + 0.035), 0.188, (1.05, 0.7, 1.08), (math.radians(-90), 0, 0), "steel_armor", cut_z=0.0, thick=0.01)
    parts.append(tag(back, "chest"))
    for side, sx in (("l", 1), ("r", -1)):
        ua = js["upper_arm_" + side][0]
        for k in range(3):
            lame = shell(ua + Vector((sx * (0.015 + k * 0.012), 0, 0.045 - k * 0.04)), 0.088 - k * 0.006, (1.15, 1.0, 0.55),
                         (0, sx * math.radians(25 + k * 8), 0), "steel_armor", cut_z=0.0, thick=0.005)
            parts.append(tag(lame, "upper_arm_" + side if k else "clavicle_" + side))
        parts.append(tag(shapes.sphere(0.009, tuple(ua + Vector((sx * 0.02, -0.05, 0.08))), seg=8, rings=5, mat="bronze"), "clavicle_" + side))
        parts.append(tag(limb_tube(js["forearm_" + side][0].lerp(js["forearm_" + side][1], 0.2), js["forearm_" + side][1], 0.056, 0.048,
                                   "steel_armor", name="Bracer", flare_end=0.006), "forearm_" + side))
        parts.append(fist(js, side, "leather_brown", 1.05))
        parts += boot(js, side, mat="leather_dark", cuff_mat="leather_brown", scale=1.05)
        kn = js["shin_" + side][0]
        parts.append(tag(shell(kn + Vector((0, -0.05, 0.0)), 0.06, (1.0, 0.7, 1.0), (math.radians(90), 0, 0), "steel_armor", cut_z=0.0, thick=0.005), "shin_" + side))
        parts.append(tag(limb_tube(kn.lerp(js["shin_" + side][1], 0.1), kn.lerp(js["shin_" + side][1], 0.55), 0.062, 0.058, "steel_armor",
                                   name="Greave"), "shin_" + side))
    parts.append(tag(mantle((ch.x, ch.y + 0.01, js["chest"][1].z - 0.0), 0.17, 0.14, 0.06, seed=2), "chest"))
    for (yy, rot, sd) in ((-0.135, 0.0, 3), (0.13, math.pi, 4)):
        tab = shapes.cloth_panel(0.28, 0.5, cols=8, rows=12, folds=1.5, fold_amp=0.01, seed=sd, mat="cloth_crimson", bottom="points", thickness=0.006)
        bend_around(tab, 0.3)
        from build_props import _xf
        _xf(tab, (hp.x, hp.y + yy, hp.z + 0.06), (0, 0, rot))
        parts.append(tag_blend(tab, torso_weights(js)))
    parts.append(tag(shapes.torus(0.158, 0.024, (hp.x, hp.y, hp.z + 0.05), major=40, minor=6, mat="leather_dark", scale=(1, 0.76, 1)), "hips"))
    parts.append(tag(shapes.box((0.06, 0.02, 0.055), (hp.x, hp.y - 0.125, hp.z + 0.05), mat="bronze", bevel=0.005), "hips"))
    for sx in (-1, 1):
        parts.append(tag(shapes.box((0.08, 0.05, 0.09), (hp.x + sx * 0.14, hp.y - 0.05, hp.z), mat="leather_brown", bevel=0.012), "hips"))
    ob = skin_parts(parts, js, arm_ob, "crawler")
    grip_socket(arm_ob, js, "r")
    grip_socket(arm_ob, js, "l")
    return arm_ob, ob, js


def build_bone_archer():
    props = rig.Proportions(height=1.82, width=0.95)
    js = props.joints()
    arm_ob = rig.build_armature(js, "archer_rig")
    parts = []
    spine_pts = [js["hips"][0], js["spine"][0], js["chest"][0], js["chest"][1], js["neck"][1]]
    vert = shapes.tube([tuple(p) for p in spine_pts], radius=0.022, seg=8, mat="bone", radii=[1.2, 1.0, 0.9, 0.9, 0.7], name="Spine")
    parts.append(tag_blend(vert, lambda co: {"hips": 1.0} if co.z < 1.05 else ({"spine": 1.0} if co.z < 1.28 else {"chest": 1.0})))
    for k in range(9):
        z = js["hips"][0].z + 0.05 + k * 0.05
        vb = shapes.sphere(0.03, (0, 0.02, z), seg=10, rings=6, mat="bone", scale=(1.2, 0.9, 0.5))
        parts.append(tag_blend(vb, lambda co: {"hips": 1.0} if co.z < 1.05 else ({"spine": 1.0} if co.z < 1.28 else {"chest": 1.0})))
    hp = js["hips"][0]
    pelvis = shapes.torus(0.1, 0.03, (hp.x, hp.y, hp.z - 0.02), major=20, minor=8, mat="bone", scale=(1.2, 0.8, 0.9))
    parts.append(tag(pelvis, "hips"))
    ch = js["chest"][0]
    for i in range(6):
        z = ch.z - 0.06 + i * 0.045
        w = 0.13 - abs(i - 2.5) * 0.012
        rib = shapes.tube([(-w * 0.2, 0.05, z + 0.02), (-w, 0.0, z), (-w * 0.85, -0.08, z - 0.03), (0.0, -0.11, z - 0.05),
                           (w * 0.85, -0.08, z - 0.03), (w, 0.0, z), (w * 0.2, 0.05, z + 0.02)], radius=0.009, seg=6, mat="bone")
        parts.append(tag(rib, "chest"))
    parts.append(tag(shapes.box((0.03, 0.02, 0.2), (0, -0.112, ch.z + 0.06), mat="bone", bevel=0.006), "chest"))
    for side, sx in (("l", 1), ("r", -1)):
        parts.append(tag(shapes.tube([tuple(js["clavicle_" + side][0]), tuple(js["clavicle_" + side][1])], radius=0.012, seg=6, mat="bone"), "clavicle_" + side))
        for bname in ("upper_arm", "forearm", "thigh", "shin"):
            a, b, _ = js[bname + "_" + side]
            M, L = frame_between(a, b)
            bn = make_bone(sx * 3 + len(bname), length=L, mat="bone")
            bn.matrix_world = M @ Matrix.Translation((0, 0, L / 2)) @ Matrix.Scale(1.45 if bname in ("thigh", "upper_arm") else 1.25, 4)
            bpy.context.view_layer.update()
            core.apply_transform(bn)
            parts.append(tag(bn, bname + "_" + side))
        parts.append(tag(shapes.sphere(0.03, tuple(js["shin_" + side][0]), seg=10, rings=6, mat="bone"), "shin_" + side))
        parts.append(fist(js, side, "bone", 0.85))
        ft = js["foot_" + side]
        foot = shapes.box((0.07, 0.2, 0.03), (ft[0].x, (ft[0].y + ft[1].y) / 2, 0.02), mat="bone", bevel=0.012)
        parts.append(tag(foot, "foot_" + side))
        parts.append(tag(limb_tube(js["forearm_" + side][0].lerp(js["forearm_" + side][1], 0.45), js["forearm_" + side][1], 0.04, 0.036,
                                   "leather_dark", name="Bracer"), "forearm_" + side))
    parts += skull_head(js, mat="bone", eye_mat="glow_eye_blue", scale=1.2)
    hh, ht = head_anchor(js)
    hood = shell((hh.x, hh.y + 0.01, hh.z + 0.1), 0.165, (1.0, 1.12, 1.18), (math.radians(-12), 0, 0), "cloth_dark", cut_z=-0.45, thick=0.008)
    bm = bmesh.new()
    bm.from_mesh(hood.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < hh.y - 0.06 and v.co.z < hh.z + 0.18], context="VERTS")
    bm.to_mesh(hood.data)
    bm.free()
    parts.append(tag(hood, "head"))
    cloak = garment((0, ch.y + 0.03), js["chest"][1].z + 0.01, hp.z - 0.55, 0.19, 0.3, "cloth_dark", folds=9, fold_amp=0.025, depth=0.8,
                    hem=0.08, seed=8, name="Cloak", flare=0.8)
    open_front(cloak, ch.y - 0.06)
    parts.append(tag_blend(cloak, torso_weights(js)))
    parts.append(tag(mantle((ch.x, ch.y + 0.01, js["chest"][1].z - 0.0), 0.15, 0.12, 0.045, mat="cloth_dark", seed=3), "chest"))
    parts.append(tag(shapes.torus(0.12, 0.016, (hp.x, hp.y, hp.z + 0.03), major=30, minor=6, mat="leather_dark", scale=(1, 0.75, 1)), "hips"))
    quiver = shapes.cylinder(0.05, 0.5, (0.0, 0.0, 0.0), segments=12, mat="leather_brown")
    from build_props import _xf
    _xf(quiver, (ch.x - 0.08, ch.y + 0.15, ch.z + 0.05), (math.radians(-15), math.radians(20), 0))
    parts.append(tag(quiver, "chest"))
    for i in range(5):
        sh = shapes.cylinder(0.004, 0.22, (0, 0, 0), segments=5, mat="wood_beam")
        _xf(sh, (ch.x - 0.12 + i * 0.012, ch.y + 0.2, ch.z + 0.34), (math.radians(-15), math.radians(20), 0))
        parts.append(tag(sh, "chest"))
        fl = shapes.box((0.012, 0.002, 0.05), (ch.x - 0.12 + i * 0.012 + 0.034, ch.y + 0.24, ch.z + 0.43), mat="cloth_crimson")
        parts.append(tag(fl, "chest"))
    ob = skin_parts(parts, js, arm_ob, "bone_archer")
    grip_socket(arm_ob, js, "r")
    grip_socket(arm_ob, js, "l")
    return arm_ob, ob, js


def build_goblin():
    props = rig.Proportions(height=1.25, width=1.05, head=1.35, arm=1.12, leg=0.92, hunch=0.4, neck=0.6)
    js = props.joints()
    arm_ob = rig.build_armature(js, "goblin_rig")
    r = dict(rig.DEFAULT_RADII)
    for k, v in r.items():
        r[k] = (v[0] * 0.78, v[1] * 0.78)
    r["belly"] = (0.13, 0.12)
    pts, edges, rad = rig.humanoid_skin(js, r)
    body = rig.skin_body(pts, edges, rad, "Body", "skin_goblin", subsurf=1)
    parts = [body] + goblin_head(js)
    ch = js["chest"][0]
    hp = js["hips"][0]
    vest = garment((0, ch.y), js["chest"][1].z - 0.03, js["spine"][0].z - 0.03, 0.12, 0.14, "leather_brown", folds=5, fold_amp=0.008,
                   depth=0.85, hem=0.015, seed=2, name="Vest")
    open_front(vest, ch.y - 0.09)
    parts.append(tag_blend(vest, torso_weights(js)))
    skirt = garment((0, hp.y), hp.z + 0.04, hp.z - 0.2, 0.13, 0.16, "cloth_burlap", folds=6, fold_amp=0.012, depth=0.85, hem=0.04, seed=3,
                    name="Kilt")
    parts.append(tag_blend(skirt, torso_weights(js)))
    parts.append(tag(shapes.torus(0.125, 0.014, (hp.x, hp.y, hp.z + 0.04), major=30, minor=6, mat="leather_dark", scale=(1.0, 0.85, 1)), "hips"))
    for side in ("l", "r"):
        parts.append(fist(js, side, "skin_goblin", 0.85))
        parts.append(tag(limb_tube(js["forearm_" + side][0].lerp(js["forearm_" + side][1], 0.5), js["forearm_" + side][1], 0.036, 0.032,
                                   "cloth_burlap", name="Wrap"), "forearm_" + side))
        ft = js["foot_" + side]
        foot = shapes.sphere(0.05, ((ft[0].x + ft[1].x) / 2, (ft[0].y + ft[1].y) / 2 - 0.02, 0.03), seg=12, rings=8, mat="skin_goblin", scale=(0.9, 2.0, 0.7))
        parts.append(tag(foot, "foot_" + side))
    # FB-022: a pack-frame carrying a pole and an iron hoop of stolen, guttering candles (so everyone can see how
    # brave the goblin is)
    pole_base = Vector((ch.x, ch.y + 0.12, ch.z + 0.0))
    parts.append(tag(shapes.box((0.16, 0.08, 0.18), tuple(pole_base), mat="leather_dark", bevel=0.015), "chest"))
    parts.append(tag(shapes.cylinder(0.012, 0.6, tuple(pole_base + Vector((0, 0.03, 0.35))), segments=8, mat="wood_rough"), "chest"))
    hoop_c = pole_base + Vector((0, 0.04, 0.72))
    ring = shapes.torus(0.17, 0.012, tuple(hoop_c), major=40, minor=6, mat="iron_dark", rot=(math.pi / 2, 0, 0))
    parts.append(tag(ring, "chest"))
    for k in range(7):
        a = k / 7 * math.tau + 0.2
        cp = hoop_c + Vector((math.cos(a) * 0.17, 0.0, math.sin(a) * 0.17))
        parts.append(tag(shapes.cylinder(0.016, 0.07 - (k % 3) * 0.012, tuple(cp + Vector((0, 0, 0.03))), segments=8, mat="wax"), "chest"))
        parts.append(tag(shapes.sphere(0.014, tuple(cp + Vector((0, 0, 0.08 - (k % 3) * 0.012))), seg=8, rings=5, mat="flame_glow",
                                       scale=(0.7, 0.7, 1.4)), "chest"))
    parts.append(tag(shapes.sphere(0.035, tuple(hoop_c + Vector((0, 0.0, -0.17))), seg=10, rings=6, mat="bone", scale=(1, 0.9, 1.1)), "chest"))
    ob = skin_parts(parts, js, arm_ob, "goblin")
    grip_socket(arm_ob, js, "r")
    grip_socket(arm_ob, js, "l")
    socket_on_bone(arm_ob, "chest", "CandleHoop", hoop_c)
    return arm_ob, ob, js


def build_boss():
    props = rig.Proportions(height=2.95, width=1.35, arm=1.08, head=0.9)
    js = props.joints()
    arm_ob = rig.build_armature(js, "warden_rig")
    s = 2.95 / 1.8
    r = dict(rig.DEFAULT_RADII)
    for k, v in r.items():
        r[k] = (v[0] * s * 1.15, v[1] * s * 1.1)
    pts, edges, rad = rig.humanoid_skin(js, r)
    body = rig.skin_body(pts, edges, rad, "Body", "iron_dark", subsurf=1)
    parts = [body]
    ch = js["chest"][0]
    hp = js["hips"][0]
    bp = shell((ch.x, ch.y - 0.1 * s, ch.z + 0.05 * s), 0.25 * s, (1.12, 0.45, 1.12), (math.radians(90), 0, 0), "iron_dark", cut_z=-0.1, thick=0.02)
    parts.append(tag(bp, "chest"))
    bk = shell((ch.x, ch.y + 0.08 * s, ch.z + 0.05 * s), 0.24 * s, (1.1, 0.4, 1.1), (math.radians(-90), 0, 0), "iron_dark", cut_z=0.0, thick=0.02)
    parts.append(tag(bk, "chest"))
    core_c = Vector((ch.x, ch.y - 0.205 * s, ch.z + 0.06 * s))
    parts.append(tag(shapes.sphere(0.072 * s, tuple(core_c), seg=20, rings=12, mat="furnace_core", scale=(1, 0.55, 1)), "chest"))
    parts.append(tag(shapes.torus(0.082 * s, 0.014 * s, tuple(core_c + Vector((0, -0.01, 0))), major=32, minor=8, mat="gold_antique", rot=(math.pi / 2, 0, 0)), "chest"))
    for i in range(4):
        z = ch.z - 0.06 * s - i * 0.035 * s
        parts.append(tag(shapes.box((0.2 * s, 0.02, 0.012 * s), (ch.x, ch.y - 0.2 * s, z), mat="furnace_core"), "chest"))
    gut = garment((0, ch.y), js["spine"][1].z, hp.z - 0.05 * s, 0.24 * s, 0.25 * s, "iron_dark", folds=0, fold_amp=0.0, depth=0.75, hem=0.0,
                  seed=1, name="Gut", thick=0.02)
    parts.append(tag_blend(gut, torso_weights(js)))
    for k in range(3):
        parts.append(tag(shapes.torus(0.245 * s, 0.012 * s, (0, ch.y, js["spine"][0].z + k * 0.06 * s), major=40, minor=6, mat="gold_antique", scale=(1, 0.76, 1)),
                         "spine"))
    for side, sx in (("l", 1), ("r", -1)):
        ua = js["upper_arm_" + side][0]
        for k in range(3):
            lame = shell(ua + Vector((sx * (0.02 + k * 0.03) * s, 0, (0.05 - k * 0.06) * s)), (0.15 - k * 0.012) * s, (1.15, 1.05, 0.62),
                         (0, sx * math.radians(25 + k * 9), 0), "iron_dark", cut_z=0.0, thick=0.012)
            parts.append(tag(lame, "clavicle_" + side if k == 0 else "upper_arm_" + side))
        for k in range(3):
            parts.append(tag(shapes.cone(0.03 * s, 0.16 * s, tuple(ua + Vector((sx * (0.05 + k * 0.05) * s, (k - 1) * 0.06 * s, 0.17 * s))), seg=6,
                                         mat="iron_dark", rot=(0, sx * math.radians(-20), 0)), "clavicle_" + side))
        parts.append(tag(shapes.torus(0.12 * s, 0.012 * s, tuple(ua + Vector((sx * 0.02 * s, 0, 0.0))), mat="gold_antique", scale=(1.15, 1.05, 1)), "clavicle_" + side))
        parts.append(tag(limb_tube(js["forearm_" + side][0].lerp(js["forearm_" + side][1], 0.1), js["forearm_" + side][1], 0.085 * s, 0.07 * s,
                                   "iron_dark", name="Gauntlet", flare_end=0.012 * s), "forearm_" + side))
        parts.append(fist(js, side, "iron_dark", s * 1.1))
        parts += boot(js, side, mat="iron_dark", cuff_mat="iron_dark", scale=s * 1.05)
        kn = js["shin_" + side][0]
        parts.append(tag(shell(kn + Vector((0, -0.05 * s, 0.0)), 0.08 * s, (1.0, 0.8, 1.0), (math.radians(90), 0, 0), "gold_antique", cut_z=0.0, thick=0.008), "shin_" + side))
        parts.append(tag(limb_tube(js["thigh_" + side][0].lerp(js["thigh_" + side][1], 0.2), js["thigh_" + side][1], 0.1 * s, 0.085 * s,
                                   "iron_dark", name="Cuisse"), "thigh_" + side))
    hh, ht = head_anchor(js)
    helm = shapes.lathe([(0.0, 0.0), (0.12 * s, 0.0), (0.13 * s, 0.08 * s), (0.125 * s, 0.17 * s), (0.1 * s, 0.22 * s), (0.0, 0.24 * s)], 24, "Helm", "iron_dark")
    helm.location = (hh.x, hh.y - 0.01, hh.z - 0.02 * s)
    bpy.context.view_layer.update()
    core.apply_transform(helm)
    parts.append(tag(helm, "head"))
    parts.append(tag(shapes.box((0.16 * s, 0.03, 0.022 * s), (hh.x, hh.y - 0.135 * s, hh.z + 0.1 * s), mat="glow_eye_red"), "head"))
    parts.append(tag(shapes.box((0.02 * s, 0.035, 0.18 * s), (hh.x, hh.y - 0.13 * s, hh.z + 0.08 * s), mat="gold_antique", bevel=0.01), "head"))
    for sx in (-1, 1):
        horn = shapes.tube([(hh.x + sx * 0.11 * s, hh.y, hh.z + 0.14 * s), (hh.x + sx * 0.24 * s, hh.y + 0.02, hh.z + 0.2 * s),
                            (hh.x + sx * 0.3 * s, hh.y - 0.04 * s, hh.z + 0.34 * s), (hh.x + sx * 0.27 * s, hh.y - 0.1 * s, hh.z + 0.44 * s)],
                           radius=0.04 * s, seg=10, mat="gold_antique", radii=[1.0, 0.8, 0.45, 0.08])
        parts.append(tag(horn, "head"))
    for i in range(7):
        a = (i / 6 - 0.5) * math.radians(150)
        lame = shapes.box((0.12 * s, 0.015 * s, 0.26 * s), (hp.x + math.sin(a) * 0.19 * s, hp.y - math.cos(a) * 0.15 * s, hp.z - 0.1 * s),
                          mat="iron_dark", bevel=0.01, rot=(math.radians(-10), 0, -a))
        sd = "l" if math.sin(a) > 0 else "r"
        parts.append(tag_blend(lame, (lambda q: (lambda co: {"hips": 0.6, "thigh_" + q: 0.4}))(sd)))
    parts.append(tag(shapes.torus(0.21 * s, 0.03 * s, (hp.x, hp.y, hp.z + 0.04 * s), major=40, minor=6, mat="gold_antique", scale=(1, 0.75, 1)), "hips"))
    cloak = garment((0, ch.y + 0.06 * s), js["chest"][1].z + 0.02 * s, hp.z - 0.62 * s, 0.25 * s, 0.4 * s, "cloth_crimson", folds=9,
                    fold_amp=0.03 * s, depth=0.8, hem=0.1 * s, seed=11, name="Cloak", flare=0.8)
    open_front(cloak, ch.y - 0.0)
    parts.append(tag_blend(cloak, torso_weights(js)))
    ob = skin_parts(parts, js, arm_ob, "iron_warden")
    grip_socket(arm_ob, js, "r", offset=0.07 * s)
    grip_socket(arm_ob, js, "l", offset=0.07 * s)
    socket_on_bone(arm_ob, "chest", "CoreSocket", core_c + Vector((0, -0.05, 0)))
    return arm_ob, ob, js


def build_vendor():
    props = rig.Proportions(height=1.78, width=0.98, hunch=0.25)
    js = props.joints()
    arm_ob = rig.build_armature(js, "vendor_rig")
    r = dict(rig.DEFAULT_RADII)
    r["belly"] = (0.17, 0.15)
    pts, edges, rad = rig.humanoid_skin(js, r)
    body = rig.skin_body(pts, edges, rad, "Body", "cloth_teal", subsurf=1)
    parts = [body]
    hh, ht = head_anchor(js)
    face = shapes.sphere(0.1, (hh.x, hh.y - 0.015, hh.z + 0.09), seg=20, rings=12, mat="skin_human", scale=(0.9, 1.05, 1.1))
    parts.append(tag(face, "head"))
    parts.append(tag(shapes.cone(0.022, 0.05, (hh.x, hh.y - 0.1, hh.z + 0.07), seg=8, mat="skin_human", rot=(math.radians(-80), 0, 0)), "head"))
    for sx in (-1, 1):
        parts.append(tag(shapes.sphere(0.011, (hh.x + sx * 0.035, hh.y - 0.098, hh.z + 0.12), seg=8, rings=6, mat="glow_eye_gold"), "head"))
    parts += [tag(b, "head") for b in beard((hh.x, hh.y - 0.08, hh.z + 0.05), 0.14, 0.34, mat="fur", strands=10, seed=6, tint=(1.5, 1.5, 1.45))]
    hood = shell((hh.x, hh.y + 0.015, hh.z + 0.11), 0.16, (1.0, 1.15, 1.2), (math.radians(-15), 0, 0), "cloth_teal", cut_z=-0.5, thick=0.01)
    bm = bmesh.new()
    bm.from_mesh(hood.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < hh.y - 0.05 and v.co.z < hh.z + 0.2], context="VERTS")
    bm.to_mesh(hood.data)
    bm.free()
    parts.append(tag(hood, "head"))
    ch = js["chest"][0]
    hp = js["hips"][0]
    robe = garment((0, ch.y), js["chest"][1].z - 0.02, 0.06, 0.17, 0.32, "cloth_teal", folds=10, fold_amp=0.02, depth=0.8, hem=0.02,
                   seed=12, name="Robe", flare=1.4, bulge=0.03)
    parts.append(tag_blend(robe, torso_weights(js)))
    parts.append(tag(mantle((ch.x, ch.y + 0.0, js["chest"][1].z - 0.01), 0.16, 0.13, 0.05, mat="cloth_linen", seed=4), "chest"))
    parts.append(tag(shapes.torus(0.19, 0.028, (hp.x, hp.y, hp.z + 0.06), major=40, minor=6, mat="cloth_crimson", scale=(1, 0.82, 1)), "hips"))
    parts.append(tag(shapes.sphere(0.06, (hp.x + 0.17, hp.y - 0.1, hp.z - 0.04), seg=12, rings=8, mat="leather_brown", scale=(1, 0.7, 1.2)), "hips"))
    parts.append(tag(shapes.box((0.18, 0.08, 0.14), (hp.x - 0.2, hp.y + 0.02, hp.z - 0.02), mat="leather_brown", bevel=0.02), "hips"))
    for side in ("l", "r"):
        parts.append(fist(js, side, "skin_human", 0.95))
        parts.append(tag(limb_tube(js["forearm_" + side][0], js["forearm_" + side][1].lerp(js["forearm_" + side][0], 0.15), 0.06, 0.075,
                                   "cloth_teal", name="Sleeve", solid=0.008), "forearm_" + side))
    ob = skin_parts(parts, js, arm_ob, "vendor")
    grip_socket(arm_ob, js, "r")
    return arm_ob, ob, js


# ---------------------------------------------------------------------------
# Animation library (degrees; +X = bone tip swings forward; _r mirrors rz/ry)
# ---------------------------------------------------------------------------

def sym(p):
    out = dict(p)
    for k, v in p.items():
        if k.endswith("_l"):
            out[k[:-2] + "_r"] = (v[0], -v[1], -v[2])
    return out


def side(p, s):
    """Pose for one side only: keys without suffix get _l/_r appended (mirroring rz/ry for _r)."""
    out = {}
    for k, v in p.items():
        if s == "l":
            out[k + "_l"] = v
        else:
            out[k + "_r"] = (v[0], -v[1], -v[2])
    return out


REST_ARMS = sym({"upper_arm_l": (4, 0, 8), "forearm_l": (14, 0, 0)})


def idle_keys(style):
    hunch = style.get("hunch", 0)
    base = rig.add(REST_ARMS, {"spine": (2 + hunch, 0, 0), "chest": (1 + hunch * 0.5, 0, 0), "neck": (-hunch * 0.6, 0, 0),
                               "head": (-hunch * 0.5, 0, 0)}, style.get("idle_extra", {}))
    breathe = {"chest": (-2.0, 0, 0), "spine": (-0.8, 0, 0), "upper_arm_l": (0, 0, 1.5), "upper_arm_r": (0, 0, -1.5), "head": (1.5, 3, 0)}
    return [(0, base), (30, rig.add(base, breathe)), (60, base)]


def combat_idle(style):
    w = style.get("weapon", "1h")
    p = {"spine": (8 + style.get("hunch", 0), 8, 0), "chest": (4, 6, 0), "head": (-6, -10, 0),
         "thigh_l": (12, 0, 4), "shin_l": (-18, 0, 0), "foot_l": (6, 0, 0),
         "thigh_r": (-6, 0, -4), "shin_r": (-12, 0, 0), "foot_r": (8, 0, 0),
         "_loc": (0, 0, -0.03)}
    if w == "2h":
        p.update({"upper_arm_r": (40, 0, -10), "forearm_r": (75, 0, 0), "upper_arm_l": (50, 0, 20), "forearm_l": (70, 0, 0)})
    elif w == "bow":
        p.update({"upper_arm_l": (35, 0, 12), "forearm_l": (25, 0, 0), "upper_arm_r": (10, 0, -6), "forearm_r": (30, 0, 0)})
    else:
        p.update({"upper_arm_r": (30, 0, -14), "forearm_r": (70, 0, 0), "hand_r": (0, 0, 0),
                  "upper_arm_l": (40, 0, 18), "forearm_l": (65, 0, 0)})
    return p


def walk_keys(style, run=False):
    amp = 1.55 if run else 1.0
    lean = (12 if run else 4) + style.get("hunch", 0)
    n = 20 if run else 32
    arm_amp = (34 if run else 18) * style.get("arm_swing", 1.0)
    keys = []
    for i, ph in enumerate([0.0, 0.25, 0.5, 0.75, 1.0]):
        f = int(round(ph * n))
        s = math.sin(ph * 2 * math.pi)
        c = math.cos(ph * 2 * math.pi)
        thigh_l = 26 * amp * c
        thigh_r = -26 * amp * c
        knee_l = -max(0.0, -s) * 55 * amp - 8
        knee_r = -max(0.0, s) * 55 * amp - 8
        bob = -abs(c) * (0.05 if run else 0.03) + (0.02 if run else 0.01)
        pose = {"spine": (lean, -6 * s, 0), "chest": (2, 10 * c * (1.2 if run else 0.7), 0), "head": (-lean * 0.6, -8 * c * 0.5, 0),
                "thigh_l": (thigh_l, 0, 2), "thigh_r": (thigh_r, 0, -2), "shin_l": (knee_l, 0, 0), "shin_r": (knee_r, 0, 0),
                "foot_l": (max(0.0, -thigh_l) * 0.4 - 6, 0, 0), "foot_r": (max(0.0, -thigh_r) * 0.4 - 6, 0, 0),
                "upper_arm_l": (-arm_amp * c + 4, 0, 10), "upper_arm_r": (arm_amp * c + 4, 0, -10),
                "forearm_l": (20 + (25 if run else 10) * max(0.0, -c), 0, 0), "forearm_r": (20 + (25 if run else 10) * max(0.0, c), 0, 0),
                "_loc": (0, 0, bob)}
        pose = rig.add(pose, style.get("walk_extra", {}))
        keys.append((f, pose))
    return keys


def attack_keys(style):
    ci = combat_idle(style)
    if style.get("weapon") == "2h" or style.get("slam"):
        wind = rig.add(ci, {"upper_arm_r": (115, 0, 10), "forearm_r": (30, 0, 0), "upper_arm_l": (105, 0, -15), "forearm_l": (30, 0, 0),
                            "spine": (-14, 0, 0), "chest": (-10, 0, 0), "head": (8, 0, 0)})
        strike = rig.add(ci, {"upper_arm_r": (35, 0, 0), "forearm_r": (-30, 0, 0), "upper_arm_l": (25, 0, 0), "forearm_l": (-30, 0, 0),
                              "spine": (24, 0, 0), "chest": (14, 0, 0), "_loc": (0, -0.04, -0.06)})
        return [(0, ci), (12, wind), (18, strike), (24, strike), (40, ci)]
    wind = rig.add(ci, {"upper_arm_r": (95, 0, -40), "forearm_r": (40, 0, 0), "spine": (0, 30, 0), "chest": (-6, 16, 0), "thigh_r": (-8, 0, 0)})
    strike = rig.add(ci, {"upper_arm_r": (55, 0, 25), "forearm_r": (-10, 0, 0), "spine": (10, -32, 0), "chest": (10, -20, 0), "_loc": (0, -0.06, -0.02),
                          "thigh_l": (10, 0, 0)})
    return [(0, ci), (9, wind), (14, strike), (17, strike), (28, ci)]


def hit_keys(style):
    ci = combat_idle(style)
    rec = rig.add(ci, {"spine": (-18, -8, 0), "chest": (-10, 0, 0), "head": (-22, 12, 0), "upper_arm_l": (-10, 0, 12), "upper_arm_r": (-10, 0, -12),
                       "_loc": (0, 0.07, 0)})
    return [(0, ci), (4, rec), (16, ci)]


def death_keys(style):
    ci = combat_idle(style)
    buckle = rig.add(ci, {"thigh_l": (35, 0, 0), "thigh_r": (30, 0, 0), "shin_l": (-60, 0, 0), "shin_r": (-55, 0, 0), "spine": (20, 0, 0),
                          "head": (25, 0, 0), "upper_arm_l": (-20, 0, 20), "upper_arm_r": (-20, 0, -20), "_loc": (0, 0, -0.25)})
    fall = {"root": (-86, 0, 6), "spine": (-6, 0, 0), "chest": (-4, 0, 0), "head": (-20, 25, 0), "thigh_l": (14, 0, 6), "thigh_r": (8, 0, -10),
            "shin_l": (-14, 0, 0), "shin_r": (-6, 0, 0), "upper_arm_l": (-40, 0, 60), "upper_arm_r": (-30, 0, -55), "forearm_l": (20, 0, 0),
            "forearm_r": (35, 0, 0), "_loc": (0, 0.0, 0.12)}
    settle = rig.add(fall, {"head": (-6, 0, 0), "_loc": (0, 0, -0.02)})
    return [(0, ci), (10, buckle), (26, fall), (32, settle), (40, settle)]


def shoot_keys(style):
    ci = combat_idle(style)
    aim = rig.add(ci, {"upper_arm_l": (55, 0, 6), "forearm_l": (-25, 0, 0), "spine": (0, -24, 0), "chest": (0, -18, 0), "head": (0, 30, 0)})
    draw = rig.add(aim, {"upper_arm_r": (70, 0, 20), "forearm_r": (115, 0, 0), "hand_r": (0, 0, 0)})
    release = rig.add(aim, {"upper_arm_r": (62, 0, 40), "forearm_r": (75, 0, 0)})
    return [(0, ci), (10, aim), (22, draw), (30, draw), (33, release), (46, ci)]


def roar_keys(style):
    ci = combat_idle(style)
    up = rig.add(ci, {"chest": (-22, 0, 0), "spine": (-10, 0, 0), "head": (-28, 0, 0), "upper_arm_l": (20, 0, 55), "upper_arm_r": (20, 0, -55),
                      "forearm_l": (40, 0, 0), "forearm_r": (40, 0, 0)})
    return [(0, ci), (14, up), (40, up), (56, ci)]


def talk_keys(style):
    base = idle_keys(style)[0][1]
    g1 = rig.add(base, {"upper_arm_r": (30, 0, -10), "forearm_r": (70, 0, 0), "head": (6, -8, 0)})
    g2 = rig.add(base, {"upper_arm_r": (35, 0, -18), "forearm_r": (85, -20, 0), "head": (-4, 10, 0), "upper_arm_l": (12, 0, 10), "forearm_l": (40, 0, 0)})
    return [(0, base), (20, g1), (45, g2), (70, g1), (90, base)]


def block_keys(style):
    ci = combat_idle(style)
    blk = rig.add(ci, {"upper_arm_l": (60, 0, 0), "forearm_l": (85, 0, -10), "spine": (4, 14, 0), "head": (6, -6, 0)})
    return [(0, blk), (30, rig.add(blk, {"chest": (-1.5, 0, 0)})), (60, blk)]


def cast_keys(style):
    ci = combat_idle(style)
    gather = rig.add(ci, {"upper_arm_l": (30, 0, 10), "forearm_l": (100, 0, 0), "spine": (0, 15, 0)})
    thrust = rig.add(ci, {"upper_arm_l": (82, 0, -4), "forearm_l": (8, 0, 0), "spine": (6, -14, 0), "_loc": (0, -0.04, 0)})
    return [(0, ci), (8, gather), (14, thrust), (20, thrust), (32, ci)]


def draw_hold_keys(style):
    ci = combat_idle(dict(style, weapon="bow"))
    aim = rig.add(ci, {"upper_arm_l": (55, 0, 6), "forearm_l": (-25, 0, 0), "spine": (0, -24, 0), "chest": (0, -18, 0), "head": (0, 30, 0),
                       "upper_arm_r": (70, 0, 20), "forearm_r": (115, 0, 0)})
    return [(0, aim), (30, rig.add(aim, {"chest": (-1, 0, 0)})), (60, aim)]


def animate(arm_ob, style, extra=()):
    grip_r = next((c for c in arm_ob.children if c.name.startswith("GripR")), None)
    grip_l = next((c for c in arm_ob.children if c.name.startswith("GripL")), None)
    premade_retarget.animate_character(arm_ob, style, extra, grip_r=grip_r, grip_l=grip_l)


CHARACTERS = {
    "crawler": (build_crawler, {"weapon": "1h", "archetype": "crawler", "weapon_scale": 1.0}, ("block", "cast", "cast_r", "cast_dual", "dual", "draw_hold", "bow_draw", "bow_shoot", "attack_2h")),
    "draugr": (build_draugr, {"weapon": "2h", "archetype": "draugr", "hunch": 8, "weapon_scale": 1.0}, ()),
    "bone_archer": (build_bone_archer, {"weapon": "bow", "archetype": "archer", "hunch": 2}, ("shoot",)),
    "goblin": (build_goblin, {"weapon": "1h", "archetype": "goblin", "hunch": 10, "weapon_scale": 0.75}, ()),
    "iron_warden": (build_boss, {"weapon": "2h", "archetype": "boss", "hunch": 3, "weapon_scale": 2.1}, ("roar", "slam")),
    "vendor": (build_vendor, {"weapon": "none", "archetype": "vendor", "hunch": 4}, ("talk",)),
}


def own_action(arm_ob, clip):
    """The action behind this armature's own NLA track `clip` (Blender action names are global and get
    .001-style suffixes once several characters are built in one session)."""
    track = arm_ob.animation_data.nla_tracks.get(clip) if arm_ob.animation_data else None
    return track.strips[0].action if track is not None and track.strips else None


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set()
    strip = None
    for i, a in enumerate(argv):
        if a == "--only":
            only = set(argv[i + 1].split(","))
        if a == "--strip":
            strip = argv[i + 1]
    core.reset_scene()
    bpy.context.scene.render.fps = FPS
    built = {}
    for kind, (fn, style, extra) in CHARACTERS.items():
        if only and kind not in only:
            continue
        arm_ob, mesh_ob, js = fn()
        animate(arm_ob, style, extra)
        core.export_glb([arm_ob], f"characters/{kind}", "characters", animations=True,
                        extra={"animations": sorted(t.name for t in arm_ob.animation_data.nla_tracks)})
        built[kind] = (arm_ob, mesh_ob)
        # park this character away so the next one builds at the origin cleanly
        arm_ob.location.x += 0.0
    core.write_manifest()
    if "--preview" in argv and built:
        xs = 0.0
        objs = []
        for kind, (arm_ob, mesh_ob) in built.items():
            arm_ob.location.x = xs
            arm_ob.animation_data.action = own_action(arm_ob, "idle")
            xs += 2.6 if kind == "iron_warden" else 1.3
            objs.append(mesh_ob)
        bpy.context.scene.frame_set(0)
        bpy.context.view_layer.update()
        for o in bpy.data.objects:
            if o.type == "MESH":
                o.hide_render = o not in objs
        render.render_sheet(objs, "batch3_characters", cam_dist=1.25, elev=0.12, lens=35, samples=48, target_z_frac=0.5, yaw=-0.35)
    if strip:
        kind, an = strip.split(":")
        arm_ob, mesh_ob = built[kind]
        act = own_action(arm_ob, an)
        arm_ob.animation_data.action = act
        frames = [int(f) for f in act.frame_range]
        n = 6
        objs = []
        for o in bpy.data.objects:
            if o.type == "MESH":
                o.hide_render = o is not mesh_ob
        import shutil
        outs = []
        for i in range(n):
            f = frames[0] + (frames[1] - frames[0]) * i / (n - 1)
            bpy.context.scene.frame_set(int(f))
            bpy.context.view_layer.update()
            p = render.render_sheet([mesh_ob], f"_strip_{i}", cam_dist=1.0, elev=0.1, lens=30, samples=16, w=480, h=640, yaw=-1.1,
                                    target_z_frac=0.5, floor=True)
            outs.append(str(p))
        print("[strip]", " ".join(outs))


if __name__ == "__main__":
    main()
