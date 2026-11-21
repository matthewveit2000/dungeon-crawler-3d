"""Batch 2 — Weapons, shields, bows, spells, potions, armour pieces and first-person arms.

Grip convention (all hand-held items): origin = centre of the hand's grip, grip/blade axis = +Z
(Blender) -> +Y in Godot. First-person arms share the convention so items attach with identity.

Run: blender -b --python art/blender/build_gear.py -- [--only name,...] [--preview] [--icons]
"""

from __future__ import annotations

import math
import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from dclib import core, render, shapes  # noqa: E402
from build_props import _xf  # noqa: E402


def loft(sections, name, mat, cap_start=True, cap_end=True):
    """sections: list of lists of (x, y, z) points (same count, closed loops)."""
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in sec] for sec in sections]
    n = len(sections[0])
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(n):
            j = (i + 1) % n
            try:
                bm.faces.new((a[i], a[j], b[j], b[i]))
            except ValueError:
                pass
    if cap_start:
        bm.faces.new(list(reversed(rings[0])))
    if cap_end:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = core.obj_from_bmesh(bm, name, mat)
    return ob


def finish_item(parts, name, seed=0, smooth=35, weathering=0.5):
    ob = core.join(parts, name) if isinstance(parts, list) else parts
    ob.name = name
    core.finalize(ob, smooth_angle=smooth, uv="box", seed=seed, weathering=weathering)
    return ob


# ---------------------------------------------------------------------------
# Blades
# ---------------------------------------------------------------------------

def blade(length=0.78, base_w=0.052, thick=0.009, fuller=0.6, tip=0.13, name="Blade", mat="steel_blade",
          curve=0.0, flare=0.0):
    """Lofted double-edged blade along +Z from z=0 (guard) to the point; lenticular section with fuller."""
    secs = []
    steps = 22
    for k in range(steps + 1):
        t = k / steps
        z = t * length
        # width profile: gentle taper then point
        w = base_w * (1.0 - 0.28 * t) * (1.0 + flare * math.sin(t * math.pi))
        if z > length - tip:
            u = (z - (length - tip)) / tip
            w *= max(0.0, math.cos(u * math.pi / 2)) ** 0.9
        w = max(w, 0.0008)
        th = thick * (1.0 - 0.45 * t) * (0.5 + 0.5 * w / base_w) + 0.0008
        fd = th * 0.42 * fuller if (0.04 < t < 0.72) else 0.0
        x_off = curve * (t ** 2) * length
        sec = [
            (x_off + w / 2, 0.0, z),               # edge +x
            (x_off + w * 0.22, th / 2, z),
            (x_off + 0.0, th / 2 - fd, z),         # fuller groove front
            (x_off - w * 0.22, th / 2, z),
            (x_off - w / 2, 0.0, z),               # edge -x
            (x_off - w * 0.22, -th / 2, z),
            (x_off + 0.0, -th / 2 + fd, z),        # fuller groove back
            (x_off + w * 0.22, -th / 2, z),
        ]
        secs.append(sec)
    return loft(secs, name, mat)


def grip_wrap(length=0.17, r=0.016, name="Grip", mat="leather_dark", turns=7):
    """Leather-wrapped grip with raised spiral ridges, centred on origin along Z."""
    prof = []
    steps = 40
    for k in range(steps + 1):
        z = -length / 2 + length * k / steps
        prof.append((r * (1.0 + 0.04 * math.sin(k / steps * math.pi)), z))
    g = shapes.lathe(prof, 16, name, mat)
    me = g.data
    for v in me.vertices:
        a = math.atan2(v.co.y, v.co.x)
        ph = (v.co.z / length) * turns * 2 * math.pi + a
        bump = 0.0016 * (0.5 + 0.5 * math.cos(ph * 1.0)) ** 6
        rr = math.hypot(v.co.x, v.co.y)
        if rr > 1e-4:
            s = (rr + bump) / rr
            v.co.x *= s
            v.co.y *= s
    me.update()
    return g


def build_longsword():
    parts = []
    bl = blade(0.8, 0.054, 0.0095, name="Blade")
    _xf(bl, (0, 0, 0.115))
    parts.append(bl)
    # ricasso collar
    parts.append(shapes.box((0.06, 0.014, 0.025), (0, 0, 0.107), mat="steel_blade", bevel=0.003))
    # crossguard: curved bar with flared, down-turned quillons
    pts = [(-0.12, 0, 0.082), (-0.075, 0, 0.098), (0.0, 0, 0.102), (0.075, 0, 0.098), (0.12, 0, 0.082)]
    cg = shapes.tube(pts, radius=0.011, seg=8, mat="iron_dark", radii=[1.25, 0.95, 1.1, 0.95, 1.25], name="Guard")
    cg.scale = (1, 0.8, 1.15)
    bpy.context.view_layer.update()
    core.apply_transform(cg)
    parts.append(cg)
    for sx in (-1, 1):
        parts.append(shapes.sphere(0.016, (sx * 0.125, 0, 0.08), seg=12, rings=8, mat="iron_dark"))
    parts.append(shapes.box((0.04, 0.03, 0.03), (0, 0, 0.1), mat="iron_dark", bevel=0.006))
    # grip + ferrules
    g = grip_wrap(0.17, 0.0155)
    parts.append(g)
    for z in (0.085, -0.085):
        parts.append(shapes.cylinder(0.0185, 0.012, (0, 0, z), segments=16, mat="bronze", bevel=0.002))
    # wheel pommel with peened tang
    pom = shapes.lathe([(0.0, -0.13), (0.018, -0.128), (0.032, -0.118), (0.036, -0.105), (0.032, -0.092), (0.016, -0.088), (0.0, -0.088)],
                       24, "Pommel", "iron_dark")
    pom.scale = (1, 0.62, 1)
    bpy.context.view_layer.update()
    core.apply_transform(pom)
    parts.append(pom)
    parts.append(shapes.sphere(0.008, (0, 0, -0.134), seg=10, rings=6, mat="iron_dark"))
    return finish_item(parts, "iron_sword", 1)


def build_cleaver():
    """The Gravefeast Cleaver — gilded broad cleaver with a row of glowing blood-runes cut into the blade (FB-022)."""
    parts = []
    outline = [(-0.02, 0.0), (0.075, 0.0), (0.09, 0.2), (0.1, 0.48), (0.08, 0.6), (-0.03, 0.66), (-0.035, 0.12)]
    head = shapes.prism_from_outline(outline, 0.012, mat="steel_blade", bevel=0.003)
    _xf(head, (0, 0, 0.11))
    parts.append(head)
    for i in range(5):
        parts.append(shapes.box((0.012, 0.016, 0.03 + (i % 2) * 0.02), (0.02 + i * 0.012, 0, 0.3 + i * 0.045), mat="glow_eye_red", rot=(0, 0.35 * (1 if i % 2 else -1), 0)))
    parts.append(shapes.box((0.12, 0.03, 0.03), (0.02, 0, 0.1), mat="gold_antique", bevel=0.008))
    parts.append(grip_wrap(0.17, 0.016, mat="leather_dark"))
    parts.append(shapes.sphere(0.03, (0, 0, -0.105), seg=16, rings=10, mat="gold_antique"))
    return finish_item(parts, "gravefeast_cleaver", 3)


def build_battleaxe():
    """Two-handed bearded battleaxe. Grip origin at the lower hand position; head at the top."""
    parts = []
    haft_len = 1.32
    haft = shapes.lathe([(0.017, -0.28), (0.02, -0.2), (0.019, 0.5), (0.0175, 0.95), (0.019, 1.02), (0.0, 1.04)], 12, "Haft", "wood_beam")
    parts.append(haft)
    for z0, z1 in ((-0.25, -0.05), (0.42, 0.6)):
        g = grip_wrap(z1 - z0, 0.021, mat="leather_dark", turns=5)
        _xf(g, (0, 0, (z0 + z1) / 2))
        parts.append(g)
    parts.append(shapes.cylinder(0.023, 0.06, (0, 0, -0.29), segments=12, mat="iron_dark", bevel=0.004))
    # bearded head: outline in XZ, tapered edge thickness
    outline = [(0.02, 0.0), (0.05, 0.02), (0.12, 0.0), (0.2, -0.08), (0.235, -0.1), (0.25, -0.02), (0.255, 0.08),
               (0.24, 0.17), (0.205, 0.2), (0.11, 0.135), (0.05, 0.13), (0.02, 0.12)]
    head = shapes.prism_from_outline(outline, 0.032, mat="iron_dark")
    for v in head.data.vertices:
        t = max(0.0, min(1.0, (v.co.x - 0.06) / 0.19))
        v.co.y *= 1.0 - 0.86 * t
    head.data.update()
    core.add_bevel(head, 0.003, 1, 35)
    core.apply_modifiers(head)
    _xf(head, (0.0, 0, 0.86))
    parts.append(head)
    # polished cutting edge strip
    edge = [(0.2, -0.08), (0.235, -0.1), (0.25, -0.02), (0.255, 0.08), (0.24, 0.17), (0.205, 0.2), (0.215, 0.15), (0.228, 0.07), (0.226, -0.02), (0.214, -0.07)]
    es = shapes.prism_from_outline(edge, 0.0065, mat="steel_blade")
    _xf(es, (0.0, 0, 0.86))
    parts.append(es)
    # socket & langets with rivets
    parts.append(shapes.cylinder(0.028, 0.16, (0, 0, 0.92), segments=12, mat="iron_dark", bevel=0.004))
    parts += shapes.rivet_row((0.0, -0.028, 0.86), (0.0, -0.028, 0.98), 2, (0, -1, 0), r=0.006)
    # spike on the back
    parts.append(shapes.cone(0.016, 0.07, (-0.026, 0, 0.93), seg=6, mat="iron_dark", rot=(0, -math.pi / 2, 0)))
    return finish_item(parts, "battleaxe", 4)


def build_round_shield():
    """Nordic round shield: 8 painted boards, iron boss, rawhide rim, grip bar on the back.
    Origin = handle grip centre (behind the boss), face toward -Y (Blender) == toward the enemy."""
    rnd = random.Random(9)
    parts = []
    R = 0.4
    boards = 7
    w = 2 * R / boards
    for i in range(boards):
        x = -R + w * (i + 0.5)
        half = math.sqrt(max(0.0, R * R - x * x))
        b = shapes.plank(2 * half, w - 0.004, 0.016, (x, -0.035, 0), (0, math.pi / 2, math.pi / 2), seed=i, mat="wood_oak", warp=0.0)
        # cut to circle: squash vertices outside radius
        for v in b.data.vertices:
            r = math.hypot(v.co.x, v.co.z)
            if r > R - 0.004:
                s = (R - 0.004) / r
                v.co.x *= s
                v.co.z *= s
            # slight dome toward the front
            v.co.y -= 0.025 * (1.0 - (math.hypot(v.co.x, v.co.z) / R) ** 2)
        b.data.update()
        # painted pattern: alternating crimson / bone quarters
        painted = (i in (1, 2, 4, 5))
        core.tint_part(b, rnd.uniform(0.85, 1.0), (1.25, 0.32, 0.26) if painted else (1.05, 0.98, 0.86))
        parts.append(b)
    # Solid backing disc behind the boards: the seams between painted boards never show through (FB-014)
    backing = shapes.cylinder(R - 0.006, 0.005, (0, -0.0245, 0), segments=48, mat="wood_dark", rot=(math.pi / 2, 0, 0))
    parts.append(backing)
    # rim (rawhide wrap + iron clamps)
    rim = shapes.torus(R, 0.012, (0, -0.03, 0), major=64, minor=8, mat="leather_brown", rot=(math.pi / 2, 0, 0))
    parts.append(rim)
    for i in range(12):
        a = i / 12 * math.tau
        clamp = shapes.box((0.03, 0.04, 0.03), (math.cos(a) * R, -0.03, math.sin(a) * R), mat="iron_dark", bevel=0.004, rot=(0, -a, 0))
        parts.append(clamp)
    # boss
    boss = shapes.lathe([(0.11, 0.0), (0.105, -0.01), (0.08, -0.015), (0.075, -0.05), (0.05, -0.08), (0.0, -0.09)], 28, "Boss", "iron_dark")
    _xf(boss, (0, -0.05, 0), (math.pi / 2, 0, 0))
    # lathe built along z; rotate so dome points -Y
    parts.append(boss)
    parts += [shapes.sphere(0.009, (math.cos(a) * 0.095, -0.06, math.sin(a) * 0.095), seg=8, rings=5, mat="iron_dark")
              for a in [i / 6 * math.tau for i in range(6)]]
    # back grip bar + leather strap
    parts.append(shapes.box((0.03, 0.03, 0.22), (0, 0.0, 0), mat="wood_beam", bevel=0.006))
    parts.append(shapes.box((0.24, 0.006, 0.05), (0, -0.018, 0.0), mat="leather_dark", bevel=0.002, rot=(0, 0, 0)))
    return finish_item(parts, "round_shield", 9)


def build_bow(name="hunting_bow", half=0.7, limb_mat="wood_beam", tip_mat="bone", recurve=0.05, belly=0.06, wraps=0):
    """Recurve hunting bow along Z; grip at origin, back of the bow toward -Y (target).
    Bowstring is two child segments ('StringTop', 'StringBottom') so Godot can pull the nock back."""
    parts = []
    limb_pts = []
    for k in range(13):
        t = k / 12
        z = 0.08 + t * (half - 0.08)
        y = -belly * math.sin(t * math.pi * 0.9) + (recurve * (t - 0.8) / 0.2 if t > 0.8 else 0.0)
        limb_pts.append((0, y, z))
    radii = [1.0 - 0.55 * (k / 12) for k in range(13)]
    for sgn in (1, -1):
        pts = [(x, y, z * sgn) for (x, y, z) in limb_pts]
        for w in range(wraps):
            wz = (0.18 + w * (half - 0.25) / max(1, wraps)) * sgn
            k2 = min(12, int(abs(wz) / half * 12))
            parts.append(shapes.torus(0.019, 0.004, (0, limb_pts[k2][1], wz), major=12, minor=4, mat="leather_dark"))
        limb = shapes.tube(pts, radius=0.018, seg=8, mat=limb_mat, radii=radii, name="Limb")
        limb.scale = (1.3, 0.75, 1)
        bpy.context.view_layer.update()
        core.apply_transform(limb)
        parts.append(limb)
        tip = shapes.cone(0.011, 0.05, (0, pts[-1][1], pts[-1][2]), seg=8, mat=tip_mat, rot=(0 if sgn > 0 else math.pi, 0, 0))
        parts.append(tip)
    riser = shapes.lathe([(0.018, -0.1), (0.024, -0.07), (0.026, 0.0), (0.024, 0.07), (0.018, 0.1)], 12, "Riser", "wood_dark")
    riser.scale = (1.1, 0.9, 1)
    bpy.context.view_layer.update()
    core.apply_transform(riser)
    parts.append(riser)
    parts.append(grip_wrap(0.1, 0.027, mat="leather_brown", turns=5))
    parts.append(shapes.box((0.01, 0.012, 0.025), (0.026, 0.0, 0.055), mat="leather_dark"))  # arrow rest
    ob = finish_item(parts, name, 7)
    top = (0, limb_pts[-1][1] + recurve * 0.2, half)
    bot = (0, top[1], -half)
    for nm, tip_pos in (("StringTop", top), ("StringBottom", bot)):
        seg = shapes.cylinder(0.0022, 1.0, (0, 0, 0.5), segments=6, mat="cloth_linen")
        core.finalize(seg, uv="box", weathering=0.0)
        seg.name = nm
        seg.location = tip_pos
        seg.parent = ob
        # aim at the rest nock point (0, string_y, 0)
        d = Vector((0, tip_pos[1], 0)) - Vector(tip_pos)
        seg.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        seg.scale = (1, 1, d.length)
    return ob


def build_arrow():
    parts = []
    parts.append(shapes.cylinder(0.0045, 0.7, (0, 0, 0.0), segments=8, mat="wood_beam"))
    head = shapes.prism_from_outline([(0.0, 0.0), (0.012, 0.012), (0.014, 0.03), (0.0, 0.07), (-0.014, 0.03), (-0.012, 0.012)], 0.003,
                                     mat="steel_blade")
    _xf(head, (0, 0, 0.345))
    parts.append(head)
    parts.append(shapes.cylinder(0.006, 0.03, (0, 0, 0.355), segments=8, mat="iron_dark"))
    for i in range(3):
        a = i / 3 * math.tau
        vane = shapes.prism_from_outline([(0.0, 0.0), (0.016, 0.02), (0.018, 0.09), (0.0, 0.11)], 0.0015, mat="cloth_crimson" if i == 0 else "cloth_linen")
        _xf(vane, (0, 0, -0.33), (0, 0, a))
        parts.append(vane)
    parts.append(shapes.cylinder(0.0055, 0.014, (0, 0, -0.352), segments=8, mat="bone"))
    return finish_item(parts, "arrow", 8)


def build_tome(variant="fire"):
    rune_mat = {"fire": "glow_eye_red", "spark": "neon_cyan", "mend": "glow_eye_gold", "frost": "glow_eye_blue",
                "venom": "glass_green", "void": "neon_pink", "blood": "glow_eye_red"}[variant]
    cover_mat = {"frost": "cloth_teal", "venom": "leather_brown", "void": "void_black", "blood": "cloth_crimson"}.get(variant, "leather_dark")
    parts = []
    W_, H_, D_ = 0.17, 0.23, 0.05
    cover = shapes.box((W_, D_, H_), (0, 0, 0), mat=cover_mat, bevel=0.006)
    parts.append(cover)
    pages = shapes.box((W_ - 0.014, D_ - 0.012, H_ - 0.018), (0.008, 0, 0), mat="parchment", bevel=0.002)
    parts.append(pages)
    parts.append(shapes.box((0.02, D_ + 0.006, H_ + 0.004), (-W_ / 2 + 0.008, 0, 0), mat="leather_brown", bevel=0.004))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(shapes.box((0.03, D_ + 0.004, 0.03), (sx * (W_ / 2 - 0.012), 0, sz * (H_ / 2 - 0.012)), mat="bronze", bevel=0.003))
    parts.append(shapes.box((0.04, 0.012, 0.03), (W_ / 2 + 0.004, -0.0, 0.0), mat="bronze", bevel=0.003))
    rune = shapes.torus(0.04, 0.005, (0.006, -D_ / 2 - 0.002, 0.01), mat=rune_mat, rot=(math.pi / 2, 0, 0))
    parts.append(rune)
    for k in range(3):
        a = k / 3 * math.tau
        parts.append(shapes.box((0.004, 0.003, 0.05), (0.006 + math.cos(a) * 0.018, -D_ / 2 - 0.002, 0.01 + math.sin(a) * 0.018), mat=rune_mat, rot=(0, a, 0)))
    return finish_item(parts, f"tome_{variant}", 11)


def build_potion(kind="health"):
    parts = []
    if kind == "health":
        prof = [(0.0, 0.0), (0.035, 0.002), (0.06, 0.02), (0.07, 0.06), (0.062, 0.1), (0.035, 0.125), (0.018, 0.14), (0.017, 0.18), (0.021, 0.19), (0.0, 0.19)]
        glass, liquid, lvl = "glass_clear", "glass_red", 0.095
    else:
        prof = [(0.0, 0.0), (0.03, 0.002), (0.038, 0.02), (0.04, 0.12), (0.03, 0.15), (0.016, 0.165), (0.015, 0.2), (0.019, 0.21), (0.0, 0.21)]
        glass, liquid, lvl = "glass_clear", "glass_blue", 0.13
    bottle = shapes.lathe(prof, 24, "Bottle", glass, cap_top=False)
    parts.append(bottle)
    inner = [(r * 0.86, z) for (r, z) in prof if z <= lvl] + [(0.0, lvl)]
    inner[0] = (0.0, 0.006)
    parts.append(shapes.lathe(inner, 20, "Liquid", liquid))
    cork_z = prof[-2][1]
    parts.append(shapes.cylinder(0.016, 0.035, (0, 0, cork_z + 0.005), segments=12, mat="wood_rough", r_top=0.019))
    parts.append(shapes.sphere(0.022, (0, 0, cork_z + 0.022), seg=12, rings=6, mat="glow_eye_red" if kind == "health" else "neon_cyan", scale=(1, 1, 0.35)))
    parts.append(shapes.torus(0.019, 0.003, (0, 0, cork_z - 0.01), mat="rope"))
    tag = shapes.cloth_panel(0.04, 0.05, cols=2, rows=2, fold_amp=0.002, seed=2, mat="parchment", thickness=0.0)
    _xf(tag, (0.03, -0.02, cork_z - 0.02), (0, 0, 0.6))
    parts.append(tag)
    return finish_item(parts, f"{kind}_potion", 12, smooth=60)


def build_flask(name, liquid, prof, lvl, cork_glow, glass="glass_clear", tag_seed=2):
    """FB-022 consumables: a corked glass vessel with a liquid fill, rope collar and a parchment tag."""
    parts = [shapes.lathe(prof, 24, "Bottle", glass, cap_top=False)]
    inner = [(r * 0.86, z) for (r, z) in prof if z <= lvl] + [(0.0, lvl)]
    inner[0] = (0.0, 0.006)
    parts.append(shapes.lathe(inner, 20, "Liquid", liquid))
    cork_z = prof[-2][1]
    parts.append(shapes.cylinder(0.016, 0.035, (0, 0, cork_z + 0.005), segments=12, mat="wood_rough", r_top=0.019))
    parts.append(shapes.sphere(0.02, (0, 0, cork_z + 0.022), seg=12, rings=6, mat=cork_glow, scale=(1, 1, 0.35)))
    parts.append(shapes.torus(0.019, 0.003, (0, 0, cork_z - 0.01), mat="rope"))
    tag = shapes.cloth_panel(0.04, 0.05, cols=2, rows=2, fold_amp=0.002, seed=tag_seed, mat="parchment", thickness=0.0)
    _xf(tag, (0.03, -0.02, cork_z - 0.02), (0, 0, 0.6))
    parts.append(tag)
    return finish_item(parts, name, 12 + tag_seed, smooth=60)


def build_stamina_potion():
    prof = [(0.0, 0.0), (0.045, 0.002), (0.058, 0.03), (0.058, 0.085), (0.04, 0.11), (0.018, 0.13), (0.017, 0.175), (0.021, 0.185), (0.0, 0.185)]
    return build_flask("stamina_potion", "glass_lime", prof, 0.09, "glass_lime", tag_seed=3)


def build_swiftness_draught():
    # tall, slim, waisted vial: speed in a bottle
    prof = [(0.0, 0.0), (0.028, 0.002), (0.032, 0.03), (0.022, 0.09), (0.03, 0.15), (0.02, 0.19), (0.012, 0.205), (0.012, 0.24), (0.016, 0.25), (0.0, 0.25)]
    return build_flask("swiftness_draught", "glass_amber", prof, 0.16, "glow_eye_gold", tag_seed=4)


def build_ironbark_tonic():
    # squat, heavy jug wrapped in bark strips
    prof = [(0.0, 0.0), (0.05, 0.002), (0.066, 0.025), (0.068, 0.06), (0.055, 0.09), (0.024, 0.11), (0.02, 0.14), (0.024, 0.15), (0.0, 0.15)]
    ob = build_flask("ironbark_tonic", "bronze", prof, 0.075, "embers", tag_seed=5)
    bark = []
    for k in range(5):
        a = k / 5 * math.tau
        st = shapes.box((0.012, 0.006, 0.07), (math.cos(a) * 0.066, math.sin(a) * 0.066, 0.045), mat="wood_dark", rot=(0, 0, a))
        bark.append(st)
    band = shapes.torus(0.068, 0.004, (0, 0, 0.045), mat="iron_dark")
    return finish_item([ob] + bark + [band], "ironbark_tonic", 15, smooth=50)


def build_troll_fat_salve():
    # a dented tin of greasy salve with its lid propped against it
    parts = [shapes.cylinder(0.055, 0.04, (0, 0, 0.02), segments=24, mat="iron_dark", bevel=0.004)]
    parts.append(shapes.cylinder(0.051, 0.006, (0, 0, 0.042), segments=24, mat="salve_fat"))
    for k in range(3):
        parts.append(shapes.sphere(0.014, (math.cos(k * 2.1) * 0.022, math.sin(k * 2.1) * 0.022, 0.046), seg=10, rings=6, mat="salve_fat", scale=(1, 1, 0.45)))
    lid = shapes.cylinder(0.058, 0.012, (0.0, 0.0, 0.0), segments=24, mat="iron_dark", bevel=0.003)
    _xf(lid, (0.07, 0.0, 0.035), (0, math.radians(-68), 0))
    parts.append(lid)
    label = shapes.cloth_panel(0.06, 0.03, cols=2, rows=2, fold_amp=0.001, seed=6, mat="parchment", thickness=0.0)
    _xf(label, (0.0, -0.056, 0.02), (math.radians(90), 0, 0))
    parts.append(label)
    return finish_item(parts, "troll_fat_salve", 16, smooth=50)


def build_glowcap_mushroom():
    # a little cluster of bioluminescent caps on one root
    parts = [shapes.sphere(0.03, (0, 0, 0.005), seg=10, rings=6, mat="dirt", scale=(1.3, 1.1, 0.4))]
    for (x, y, h, r) in [(0.0, 0.0, 0.09, 0.034), (0.026, 0.012, 0.06, 0.024), (-0.022, 0.016, 0.045, 0.018)]:
        parts.append(shapes.cylinder(r * 0.28, h, (x, y, h * 0.5), segments=10, mat="bone", r_top=r * 0.22))
        parts.append(shapes.sphere(r, (x, y, h), seg=14, rings=8, mat="fungus_glow", scale=(1, 1, 0.55)))
        for k in range(4):
            a = k * 1.7 + x * 40
            parts.append(shapes.sphere(r * 0.16, (x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6, h + r * 0.38), seg=6, rings=4, mat="glow_eye_blue"))
    return finish_item(parts, "glowcap_mushroom", 17, smooth=60, weathering=0.2)


def build_grave_moss():
    # a torn clump of moss still clinging to a chip of crypt stone
    rnd = random.Random(18)
    parts = [shapes.stone((0.09, 0.06, 0.025), (0, 0, 0.0), seed=4, mat="stone_block")]
    for k in range(9):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.0, 0.035)
        parts.append(shapes.sphere(rnd.uniform(0.014, 0.024), (math.cos(a) * rr, math.sin(a) * rr * 0.7, 0.02 + rnd.uniform(0, 0.01)),
                                   seg=8, rings=5, mat="moss", scale=(1, 1, 0.6)))
    return finish_item(parts, "grave_moss", 18, smooth=70, weathering=0.3)


def build_bat_wing_jerky():
    # a dried bat wing on a loop of string: finger bones and leathery membrane
    parts = []
    pts = [(0.0, 0.0), (0.09, 0.04), (0.11, -0.005), (0.075, -0.03), (0.04, -0.045), (0.0, -0.02)]
    wing = shapes.prism_from_outline(pts, 0.004, "Wing", "leather_dark")  # membrane in the XZ plane
    parts.append(wing)
    for (x, z) in [(0.09, 0.04), (0.11, -0.005), (0.075, -0.03), (0.04, -0.045)]:
        parts.append(shapes.tube([(0.0, -0.003, 0.0), (x * 0.5, -0.004, z * 0.5 + 0.006), (x, -0.003, z)], radius=0.0025, mat="bone"))
    parts.append(shapes.torus(0.012, 0.0015, (-0.012, 0.0, 0.0), mat="rope", rot=(math.radians(90), 0, 0)))
    return finish_item(parts, "bat_wing_jerky", 19, smooth=40, weathering=0.4)


def build_goblin_toenail():
    # one large, curled, yellowed toenail. A collector's item, apparently.
    prof = [(0.0, 0.0), (0.03, 0.0), (0.034, 0.004), (0.03, 0.008), (0.0, 0.008)]
    nail = shapes.lathe(prof, 20, "Nail", "keratin")
    nail.scale = (1.0, 0.7, 1.0)
    bm_ob = nail
    for v in bm_ob.data.vertices:
        v.co.z += (v.co.x ** 2) * 9.0  # curl the edges up
    ridge = shapes.torus(0.026, 0.002, (0, 0, 0.009), mat="keratin", scale=(1, 0.7, 1))
    grime = shapes.sphere(0.008, (0.012, 0.006, 0.01), seg=8, rings=5, mat="dirt", scale=(1, 1, 0.4))
    return finish_item([nail, ridge, grime], "goblin_toenail", 20, smooth=60, weathering=0.6)


# ---------------------------------------------------------------------------
# Armour pieces (inventory icons / loot visuals)
# ---------------------------------------------------------------------------

def build_helm():
    parts = []
    dome = shapes.sphere(0.125, (0, 0, 0.0), seg=32, rings=16, mat="steel_armor", scale=(0.92, 1.05, 1.05))
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.035], context="VERTS")
    bm.to_mesh(dome.data)
    bm.free()
    core.add_solidify(dome, 0.006, -1)
    core.apply_modifiers(dome)
    parts.append(dome)
    # spangen bands + brow band
    parts.append(shapes.torus(0.118, 0.008, (0, 0, -0.025), major=48, minor=6, mat="bronze", scale=(0.94, 1.06, 1)))
    for a in (0, math.pi / 2):
        pts = [(math.cos(a) * math.cos(t) * 0.118, math.sin(a) * math.cos(t) * 0.13, math.sin(t) * 0.132) for t in [k / 10 * math.pi for k in range(11)]]
        parts.append(shapes.strap(pts, width=0.022, thick=0.004, mat="bronze"))
    # nasal guard
    parts.append(shapes.box((0.02, 0.008, 0.08), (0, -0.128, -0.055), mat="steel_armor", bevel=0.003))
    # cheek guards
    for sx in (-1, 1):
        cheek = shapes.cloth_panel(0.07, 0.09, cols=3, rows=3, fold_amp=0.0, seed=1, mat="steel_armor", thickness=0.004)
        _xf(cheek, (sx * 0.1, -0.05, -0.03), (0, 0, sx * 1.2))
        parts.append(cheek)
    # horns
    for sx in (-1, 1):
        pts = [(sx * 0.1, 0.0, 0.05), (sx * 0.17, -0.02, 0.1), (sx * 0.2, -0.06, 0.18), (sx * 0.18, -0.1, 0.23)]
        parts.append(shapes.tube(pts, radius=0.022, seg=10, mat="bone", radii=[1.0, 0.8, 0.5, 0.1], name="Horn"))
    return finish_item(parts, "iron_helm", 13)


def build_cuirass():
    parts = []
    # tapered torso: narrow waist, broad chest, sloped shoulders (elliptical cross-section)
    prof = [(0.0, 0.0), (0.135, 0.0), (0.13, 0.06), (0.15, 0.16), (0.18, 0.27), (0.188, 0.34), (0.17, 0.41), (0.12, 0.455), (0.07, 0.47), (0.0, 0.47)]
    shell = shapes.lathe(prof, 32, "Shell", "leather_brown")
    shell.scale = (1.0, 0.64, 1.0)
    bpy.context.view_layer.update()
    core.apply_transform(shell)
    parts.append(shell)
    # moulded steel breastplate over the chest
    plate = shapes.lathe([(0.0, 0.2), (0.17, 0.2), (0.192, 0.28), (0.196, 0.35), (0.176, 0.42), (0.0, 0.43)], 32, "Breast", "steel_armor")
    plate.scale = (1.02, 0.7, 1.0)
    bpy.context.view_layer.update()
    core.apply_transform(plate)
    bm = bmesh.new()
    bm.from_mesh(plate.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.02], context="VERTS")
    bm.to_mesh(plate.data)
    bm.free()
    core.add_solidify(plate, 0.006, 1.0)
    parts.append(plate)
    parts.append(shapes.box((0.012, 0.02, 0.2), (0, -0.138, 0.31), mat="steel_armor", bevel=0.004))  # ridge
    # layered pauldrons: three curved lames per shoulder
    for sx in (-1, 1):
        for k in range(3):
            lame = shapes.sphere(0.085 - k * 0.006, (0, 0, 0), seg=20, rings=10, mat="steel_armor", scale=(1.15, 1.0, 0.55))
            bm = bmesh.new()
            bm.from_mesh(lame.data)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.005], context="VERTS")
            bm.to_mesh(lame.data)
            bm.free()
            core.add_solidify(lame, 0.004, -1.0)
            _xf(lame, (sx * (0.19 + k * 0.02), 0, 0.42 - k * 0.045), (0, sx * math.radians(28 + k * 10), 0))
            parts.append(lame)
        parts.append(shapes.sphere(0.008, (sx * 0.19, -0.04, 0.47), seg=8, rings=5, mat="bronze"))
    # belt, buckle and hanging tassets
    parts.append(shapes.torus(0.142, 0.016, (0, 0, 0.05), major=40, minor=6, mat="leather_dark", scale=(1, 0.66, 1)))
    parts.append(shapes.box((0.05, 0.02, 0.045), (0, -0.098, 0.05), mat="bronze", bevel=0.004))
    for i in range(5):
        x = -0.1 + i * 0.05
        t = shapes.plank(0.12, 0.045, 0.008, (x, -0.095 + abs(x) * 0.3, -0.03), (0, math.pi / 2, 0), seed=i, mat="leather_brown", warp=0.0)
        parts.append(t)
        parts.append(shapes.sphere(0.006, (x, -0.1 + abs(x) * 0.3, 0.02), seg=8, rings=5, mat="bronze"))
    # side straps
    for sx in (-1, 1):
        for z in (0.16, 0.26):
            parts.append(shapes.box((0.02, 0.06, 0.018), (sx * 0.172, 0.0, z), mat="leather_dark", bevel=0.003))
    return finish_item(parts, "leather_cuirass", 14)


def build_gauntlet(gold=False):
    plate = "gold_antique" if gold else "steel_armor"
    parts = []
    cuff = shapes.lathe([(0.045, 0.0), (0.05, 0.05), (0.058, 0.12), (0.062, 0.14), (0.0, 0.14)], 20, "Cuff", plate, cap_top=False)
    parts.append(cuff)
    hand = shapes.sphere(0.05, (0, 0, -0.05), seg=20, rings=12, mat="leather_dark", scale=(1.0, 0.55, 1.3))
    parts.append(hand)
    for i in range(4):
        x = -0.03 + i * 0.02
        parts.append(shapes.tube([(x, 0.0, -0.1), (x, -0.012, -0.14), (x, -0.006, -0.17)], radius=0.009, seg=8, mat="leather_dark"))
        parts.append(shapes.box((0.018, 0.02, 0.02), (x, -0.012, -0.12), mat=plate, bevel=0.004))
    parts.append(shapes.tube([(0.04, 0.0, -0.04), (0.06, -0.02, -0.08), (0.055, -0.03, -0.11)], radius=0.011, seg=8, mat="leather_dark"))
    parts.append(shapes.sphere(0.045, (0, -0.02, -0.04), seg=16, rings=8, mat=plate, scale=(1.05, 0.4, 1.0)))
    if gold:
        parts.append(shapes.torus(0.03, 0.006, (0, -0.04, -0.04), mat="neon_pink", rot=(math.pi / 2, 0, 0)))
    return finish_item(parts, "thunderclap_gauntlets" if gold else "steel_gauntlets", 15)


def build_boots():
    parts = []
    for sx in (-1, 1):
        shaft = shapes.lathe([(0.05, 0.08), (0.052, 0.2), (0.058, 0.3), (0.0, 0.3)], 16, "Shaft", "leather_brown", cap_top=False)
        _xf(shaft, (sx * 0.08, 0, 0))
        parts.append(shaft)
        foot = shapes.sphere(0.06, (sx * 0.08, -0.05, 0.05), seg=16, rings=10, mat="leather_dark", scale=(0.9, 1.9, 0.75))
        parts.append(foot)
        greave = shapes.cylinder(0.058, 0.17, (sx * 0.08, -0.004, 0.2), segments=16, mat="steel_armor", r_top=0.062)
        parts.append(greave)
        parts.append(shapes.torus(0.06, 0.006, (sx * 0.08, -0.004, 0.25), mat="rune_stone"))
        parts.append(shapes.box((0.1, 0.22, 0.02), (sx * 0.08, -0.06, 0.008), mat="leather_dark", bevel=0.006))
    return finish_item(parts, "iron_boots", 16)


def build_ring():
    parts = [shapes.torus(0.012, 0.0028, (0, 0, 0), major=32, minor=10, mat="steel_blade", rot=(math.pi / 2, 0, 0))]
    parts.append(shapes.box((0.009, 0.006, 0.009), (0, 0, 0.0145), mat="steel_blade", bevel=0.002))
    gem = shapes.sphere(0.0055, (0, 0, 0.019), seg=8, rings=4, mat="crystal_teal")
    parts.append(gem)
    return finish_item(parts, "silver_ring", 17, smooth=60)


def build_amulet():
    parts = []
    pend = shapes.prism_from_outline([(0.0, -0.05), (0.025, -0.02), (0.02, 0.02), (0.0, 0.035), (-0.02, 0.02), (-0.025, -0.02)], 0.01, mat="bone", bevel=0.003)
    parts.append(pend)
    parts.append(shapes.torus(0.012, 0.0035, (0, 0, -0.008), mat="glow_eye_blue", rot=(math.pi / 2, 0, 0)))
    pts = [(math.sin(t) * 0.07, 0.0, 0.035 + (1 - math.cos(t)) * 0.12) for t in [k / 12 * math.pi * 1.6 - math.pi * 0.8 for k in range(13)]]
    parts.append(shapes.tube(pts, radius=0.002, seg=6, mat="leather_dark"))
    return finish_item(parts, "bone_amulet", 18, smooth=60)


# ---------------------------------------------------------------------------
# D-049 discovery loot: new weapons, shields, tomes, armour and accessories
# ---------------------------------------------------------------------------

def _haft(z0, z1, r=0.017, mat="wood_beam"):
    return shapes.lathe([(r, z0), (r * 1.12, z0 + 0.04), (r * 1.05, (z0 + z1) / 2), (r, z1 - 0.02), (0.0, z1)], 12, "Haft", mat)


def build_hand_axe():
    """One-handed bearded hand axe: short haft, hooked beard, single cutting edge toward +X."""
    parts = [_haft(-0.13, 0.5, 0.015)]
    g = grip_wrap(0.16, 0.018, mat="leather_dark", turns=5)
    parts.append(g)
    parts.append(shapes.cylinder(0.019, 0.04, (0, 0, -0.13), segments=12, mat="iron_dark", bevel=0.003))
    outline = [(0.015, 0.0), (0.05, 0.015), (0.1, -0.02), (0.15, -0.09), (0.172, -0.1), (0.18, 0.0), (0.178, 0.07), (0.15, 0.1),
               (0.08, 0.075), (0.015, 0.075)]
    head = shapes.prism_from_outline(outline, 0.026, mat="iron_dark")
    for v in head.data.vertices:
        t = max(0.0, min(1.0, (v.co.x - 0.05) / 0.13))
        v.co.y *= 1.0 - 0.85 * t
    head.data.update()
    core.add_bevel(head, 0.002, 1, 35)
    core.apply_modifiers(head)
    _xf(head, (0, 0, 0.4))
    parts.append(head)
    edge = [(0.15, -0.09), (0.172, -0.1), (0.18, 0.0), (0.178, 0.07), (0.15, 0.1), (0.162, 0.06), (0.165, 0.0), (0.158, -0.06)]
    es = shapes.prism_from_outline(edge, 0.005, mat="steel_blade")
    _xf(es, (0, 0, 0.4))
    parts.append(es)
    parts.append(shapes.cylinder(0.022, 0.09, (0, 0, 0.44), segments=12, mat="iron_dark", bevel=0.003))
    return finish_item(parts, "hand_axe", 21)


def build_mace():
    """Flanged iron mace: six radial flanges around an iron head on an ash haft."""
    parts = [_haft(-0.12, 0.42, 0.016, "wood_oak")]
    parts.append(grip_wrap(0.17, 0.019, mat="leather_brown", turns=6))
    parts.append(shapes.sphere(0.024, (0, 0, -0.125), seg=12, rings=8, mat="iron_dark"))
    parts.append(shapes.cylinder(0.026, 0.2, (0, 0, 0.43), segments=12, mat="iron_dark", bevel=0.004))
    for i in range(6):
        a = i / 6 * math.tau
        fl = shapes.prism_from_outline([(0.0, 0.0), (0.06, 0.03), (0.07, 0.1), (0.05, 0.16), (0.0, 0.18)], 0.009, mat="iron_dark", bevel=0.002)
        _xf(fl, (0, 0, 0.34), (0, 0, a))
        parts.append(fl)
    parts.append(shapes.cone(0.022, 0.05, (0, 0, 0.545), seg=10, mat="iron_dark"))
    return finish_item(parts, "flanged_mace", 22)


def build_seax():
    """Barrow seax: broken-back single-edged long knife (edge toward +X)."""
    parts = []
    outline = [(-0.012, 0.0), (0.022, 0.0), (0.026, 0.2), (0.012, 0.31), (-0.006, 0.34), (-0.008, 0.24), (-0.014, 0.18)]
    bl = shapes.prism_from_outline(outline, 0.007, mat="steel_blade", bevel=0.0015)
    for v in bl.data.vertices:
        t = max(0.0, min(1.0, (v.co.x + 0.012) / 0.038))
        v.co.y *= 1.0 - 0.75 * t
    bl.data.update()
    _xf(bl, (0, 0, 0.09))
    parts.append(bl)
    parts.append(shapes.box((0.045, 0.02, 0.012), (0.004, 0, 0.088), mat="bronze", bevel=0.003))
    parts.append(grip_wrap(0.15, 0.015, mat="leather_dark", turns=6))
    parts.append(shapes.sphere(0.02, (0, 0, -0.09), seg=12, rings=8, mat="bone", scale=(1.0, 0.7, 0.8)))
    return finish_item(parts, "seax", 23)


def build_broadsword():
    parts = []
    bl = blade(0.74, 0.07, 0.01, name="Blade")
    _xf(bl, (0, 0, 0.11))
    parts.append(bl)
    parts.append(shapes.box((0.24, 0.026, 0.022), (0, 0, 0.098), mat="iron_dark", bevel=0.005))
    parts.append(grip_wrap(0.16, 0.0165, mat="wood_dark", turns=8))
    for z in (0.082, -0.082):
        parts.append(shapes.cylinder(0.019, 0.01, (0, 0, z), segments=16, mat="iron_dark", bevel=0.002))
    pom = shapes.sphere(0.03, (0, 0, -0.11), seg=16, rings=10, mat="bronze", scale=(1.1, 0.6, 0.9))
    parts.append(pom)
    return finish_item(parts, "broadsword", 24)


def build_war_hammer():
    """Two-handed war hammer: long bog-oak haft (grip origin at the lower hand), square iron head + back spike."""
    parts = [_haft(-0.28, 1.06, 0.02, "wood_dark")]
    for z0, z1 in ((-0.25, -0.05), (0.42, 0.6)):
        g = grip_wrap(z1 - z0, 0.022, mat="leather_dark", turns=5)
        _xf(g, (0, 0, (z0 + z1) / 2))
        parts.append(g)
    parts.append(shapes.cylinder(0.024, 0.06, (0, 0, -0.29), segments=12, mat="iron_dark", bevel=0.004))
    parts.append(shapes.box((0.2, 0.1, 0.11), (0.04, 0, 0.95), mat="iron_dark", bevel=0.012))
    parts.append(shapes.box((0.04, 0.115, 0.125), (0.15, 0, 0.95), mat="steel_blade", bevel=0.01))
    parts.append(shapes.cone(0.03, 0.12, (-0.11, 0, 0.95), seg=6, mat="iron_dark", rot=(0, -math.pi / 2, 0)))
    parts.append(shapes.cone(0.022, 0.09, (0, 0, 1.06), seg=8, mat="iron_dark"))
    parts += shapes.rivet_row((0.04, -0.052, 0.92), (0.04, -0.052, 0.98), 2, (0, -1, 0), r=0.007)
    return finish_item(parts, "war_hammer", 25)


def build_dane_axe():
    """Long-hafted Dane axe: very long haft, broad thin crescent head (edge toward +X)."""
    parts = [_haft(-0.3, 1.32, 0.018, "wood_beam")]
    for z0, z1 in ((-0.27, -0.07), (0.42, 0.6)):
        g = grip_wrap(z1 - z0, 0.02, mat="leather_brown", turns=5)
        _xf(g, (0, 0, (z0 + z1) / 2))
        parts.append(g)
    outline = [(0.02, 0.0), (0.06, 0.03), (0.16, -0.06), (0.23, -0.14), (0.26, -0.05), (0.27, 0.06), (0.255, 0.17), (0.22, 0.24),
               (0.15, 0.17), (0.06, 0.12), (0.02, 0.11)]
    head = shapes.prism_from_outline(outline, 0.024, mat="iron_dark")
    for v in head.data.vertices:
        t = max(0.0, min(1.0, (v.co.x - 0.06) / 0.2))
        v.co.y *= 1.0 - 0.88 * t
    head.data.update()
    core.add_bevel(head, 0.002, 1, 35)
    core.apply_modifiers(head)
    _xf(head, (0, 0, 1.12))
    parts.append(head)
    edge = [(0.23, -0.14), (0.26, -0.05), (0.27, 0.06), (0.255, 0.17), (0.22, 0.24), (0.235, 0.16), (0.245, 0.06), (0.24, -0.04)]
    es = shapes.prism_from_outline(edge, 0.005, mat="steel_blade")
    _xf(es, (0, 0, 1.12))
    parts.append(es)
    parts.append(shapes.cylinder(0.026, 0.15, (0, 0, 1.18), segments=12, mat="iron_dark", bevel=0.004))
    return finish_item(parts, "dane_axe", 26)


def build_kite_shield():
    """Iron kite shield. Origin = grip centre, face toward -Y; long axis along Z."""
    parts = []
    outline = [(0.0, 0.5), (0.18, 0.47), (0.28, 0.36), (0.3, 0.2), (0.27, -0.05), (0.18, -0.28), (0.0, -0.48),
               (-0.18, -0.28), (-0.27, -0.05), (-0.3, 0.2), (-0.28, 0.36), (-0.18, 0.47)]
    face = shapes.prism_from_outline(outline, 0.022, mat="wood_oak", bevel=0.004)
    for v in face.data.vertices:
        v.co.y -= 0.04 * (1.0 - min(1.0, abs(v.co.x) / 0.3) ** 2)
    face.data.update()
    _xf(face, (0, -0.04, 0))
    core.tint_part(face, 1.0, (1.25, 0.32, 0.26))
    parts.append(face)
    rim_pts = [(x * 1.0, -0.05, z) for (x, z) in outline] + [(outline[0][0], -0.05, outline[0][1])]
    parts.append(shapes.tube(rim_pts, radius=0.012, seg=6, mat="iron_dark", name="Rim"))
    # iron cross bands and boss
    parts.append(shapes.box((0.04, 0.012, 0.9), (0, -0.088, 0.0), mat="iron_dark", bevel=0.003))
    parts.append(shapes.box((0.54, 0.012, 0.04), (0, -0.088, 0.2), mat="iron_dark", bevel=0.003))
    boss = shapes.sphere(0.07, (0, -0.09, 0.2), seg=20, rings=10, mat="steel_armor", scale=(1, 0.55, 1))
    parts.append(boss)
    parts.append(shapes.box((0.03, 0.03, 0.22), (0, 0.0, 0), mat="wood_beam", bevel=0.006))
    return finish_item(parts, "kite_shield", 27)


def build_buckler():
    parts = []
    R = 0.2
    disc = shapes.cylinder(R, 0.02, (0, -0.03, 0), segments=40, mat="wood_dark", rot=(math.pi / 2, 0, 0))
    parts.append(disc)
    parts.append(shapes.torus(R, 0.012, (0, -0.035, 0), major=48, minor=8, mat="iron_dark", rot=(math.pi / 2, 0, 0)))
    parts.append(shapes.sphere(0.085, (0, -0.045, 0), seg=24, rings=12, mat="steel_armor", scale=(1.0, 0.55, 1.0)))
    parts.append(shapes.torus(0.09, 0.008, (0, -0.042, 0), major=32, minor=6, mat="iron_dark", rot=(math.pi / 2, 0, 0)))
    parts += [shapes.sphere(0.008, (math.cos(a) * 0.15, -0.042, math.sin(a) * 0.15), seg=8, rings=5, mat="iron_dark")
              for a in [i / 8 * math.tau for i in range(8)]]
    parts.append(shapes.box((0.03, 0.03, 0.12), (0, 0.0, 0), mat="leather_dark", bevel=0.006))
    return finish_item(parts, "buckler", 28)


def build_hauberk():
    parts = []
    prof = [(0.0, -0.08), (0.17, -0.08), (0.15, 0.06), (0.16, 0.16), (0.185, 0.27), (0.192, 0.34), (0.175, 0.41), (0.12, 0.455), (0.07, 0.47), (0.0, 0.47)]
    shell = shapes.lathe(prof, 32, "Mail", "chainmail")
    shell.scale = (1.0, 0.66, 1.0)
    bpy.context.view_layer.update()
    core.apply_transform(shell)
    parts.append(shell)
    for sx in (-1, 1):
        sl = shapes.cylinder(0.075, 0.2, (sx * 0.22, 0, 0.35), segments=16, mat="chainmail", rot=(0, sx * math.radians(70), 0), r_top=0.065)
        parts.append(sl)
    parts.append(shapes.torus(0.15, 0.016, (0, 0, 0.08), major=40, minor=6, mat="leather_dark", scale=(1, 0.68, 1)))
    parts.append(shapes.box((0.05, 0.02, 0.045), (0, -0.104, 0.08), mat="iron_dark", bevel=0.004))
    parts.append(shapes.torus(0.085, 0.02, (0, 0, 0.46), major=28, minor=6, mat="leather_brown", scale=(1, 0.75, 1)))
    return finish_item(parts, "chain_hauberk", 29)


def build_wolf_hood():
    parts = []
    dome = shapes.sphere(0.13, (0, 0.01, 0.0), seg=28, rings=14, mat="fur", scale=(0.95, 1.1, 1.05))
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.06 or (v.co.y < -0.07 and v.co.z < 0.05)], context="VERTS")
    bm.to_mesh(dome.data)
    bm.free()
    core.add_solidify(dome, 0.012, -1)
    core.apply_modifiers(dome)
    parts.append(dome)
    # wolf head on top: muzzle, ears, glinting eyes
    parts.append(shapes.sphere(0.06, (0, -0.1, 0.11), seg=16, rings=10, mat="fur", scale=(0.8, 1.5, 0.7)))
    parts.append(shapes.sphere(0.012, (0, -0.19, 0.11), seg=8, rings=5, mat="pupil_black"))
    for sx in (-1, 1):
        parts.append(shapes.cone(0.03, 0.07, (sx * 0.06, -0.01, 0.13), seg=6, mat="fur", rot=(math.radians(-15), sx * math.radians(15), 0)))
        parts.append(shapes.sphere(0.008, (sx * 0.03, -0.14, 0.13), seg=8, rings=5, mat="glow_eye_gold"))
        for k in range(2):
            parts.append(shapes.cone(0.006, 0.025, (sx * (0.012 + k * 0.012), -0.17, 0.085), seg=5, mat="teeth", rot=(math.pi, 0, 0)))
    parts.append(shapes.torus(0.12, 0.03, (0, 0.02, -0.07), major=32, minor=8, mat="fur", scale=(1.05, 1.15, 0.8)))
    return finish_item(parts, "wolf_hood", 30)


def build_bracers():
    parts = []
    cuff = shapes.lathe([(0.045, 0.0), (0.048, 0.05), (0.055, 0.14), (0.0, 0.14)], 20, "Cuff", "leather_brown", cap_top=False)
    parts.append(cuff)
    for z in (0.03, 0.07, 0.11):
        parts.append(shapes.torus(0.05 + z * 0.06, 0.004, (0, 0, z), major=20, minor=4, mat="rope"))
    hand = shapes.sphere(0.05, (0, 0, -0.05), seg=20, rings=12, mat="leather_dark", scale=(1.0, 0.55, 1.3))
    parts.append(hand)
    for i in range(4):
        x = -0.03 + i * 0.02
        parts.append(shapes.tube([(x, 0.0, -0.1), (x, -0.012, -0.14), (x, -0.006, -0.17)], radius=0.009, seg=8, mat="leather_brown"))
    parts.append(shapes.box((0.06, 0.02, 0.1), (0, -0.05, 0.07), mat="leather_dark", bevel=0.005))
    return finish_item(parts, "hide_bracers", 31)


def build_fur_boots():
    parts = []
    for sx in (-1, 1):
        shaft = shapes.lathe([(0.052, 0.08), (0.055, 0.2), (0.06, 0.26), (0.0, 0.26)], 16, "Shaft", "leather_dark", cap_top=False)
        _xf(shaft, (sx * 0.08, 0, 0))
        parts.append(shaft)
        parts.append(shapes.torus(0.066, 0.026, (sx * 0.08, 0, 0.27), major=20, minor=8, mat="fur"))
        foot = shapes.sphere(0.062, (sx * 0.08, -0.05, 0.05), seg=16, rings=10, mat="leather_brown", scale=(0.9, 1.9, 0.75))
        parts.append(foot)
        for z in (0.12, 0.18):
            parts.append(shapes.torus(0.056, 0.004, (sx * 0.08, 0, z), major=16, minor=4, mat="rope"))
        parts.append(shapes.box((0.1, 0.22, 0.02), (sx * 0.08, -0.06, 0.008), mat="leather_dark", bevel=0.006))
    return finish_item(parts, "fur_boots", 32)


def build_ember_ring():
    parts = [shapes.torus(0.012, 0.003, (0, 0, 0), major=32, minor=10, mat="iron_dark", rot=(math.pi / 2, 0, 0))]
    for sx in (-1, 1):
        parts.append(shapes.cone(0.003, 0.008, (sx * 0.005, 0, 0.016), seg=6, mat="iron_dark", rot=(0, sx * 0.4, 0)))
    parts.append(shapes.sphere(0.0065, (0, 0, 0.019), seg=10, rings=6, mat="glow_eye_red"))
    return finish_item(parts, "ember_ring", 33, smooth=60)


def build_gold_signet():
    parts = [shapes.torus(0.012, 0.0034, (0, 0, 0), major=32, minor=10, mat="gold_antique", rot=(math.pi / 2, 0, 0))]
    parts.append(shapes.cylinder(0.009, 0.006, (0, 0, 0.0155), segments=20, mat="gold_antique", bevel=0.0015))
    parts.append(shapes.box((0.008, 0.002, 0.0015), (0, 0, 0.0187), mat="void_black"))
    parts.append(shapes.box((0.0015, 0.002, 0.008), (0, 0, 0.0187), mat="void_black"))
    return finish_item(parts, "gold_signet", 34, smooth=60)


def build_wolf_tooth_amulet():
    parts = []
    pts = [(math.sin(t) * 0.07, 0.0, 0.03 + (1 - math.cos(t)) * 0.12) for t in [k / 12 * math.pi * 1.6 - math.pi * 0.8 for k in range(13)]]
    parts.append(shapes.tube(pts, radius=0.0022, seg=6, mat="leather_brown"))
    for i, x in enumerate((-0.022, 0.0, 0.022)):
        h = 0.075 if i == 1 else 0.06
        fang = shapes.cone(0.012, h, (x * 1.4, 0, 0.026), seg=8, mat="teeth", rot=(math.pi, 0, -x * 6))
        parts.append(fang)
        parts.append(shapes.torus(0.007, 0.002, (x * 1.4, 0, 0.03), mat="bronze", rot=(math.pi / 2, 0, 0)))
    return finish_item(parts, "wolf_tooth_amulet", 35, smooth=60)


# ---------------------------------------------------------------------------
# First-person arms (skin-modifier hands, gloved, with vambraces)
# ---------------------------------------------------------------------------

def _skin_mesh(verts, edges, radii, name, mat, subsurf=2):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, edges, [])
    me.update()
    ob = bpy.data.objects.new(name, me)
    core.link(ob)
    sk = ob.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.6
    for i, r in enumerate(radii):
        sv = me.skin_vertices[0].data[i]
        sv.radius = r if isinstance(r, (tuple, list)) else (r, r)
    me.skin_vertices[0].data[0].use_root = True
    ss = ob.modifiers.new("Sub", "SUBSURF")
    ss.levels = subsurf
    ss.render_levels = subsurf
    core.apply_modifiers(ob)
    core.set_material(ob, mat)
    core.init_color(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def hand_grip_skeleton():
    """Right hand wrapped around a rod on the Z axis (radius ~1.6 cm). Back of hand faces +X/-Y."""
    verts, edges, radii = [], [], []

    def add(p, r):
        verts.append(p)
        radii.append(r)
        return len(verts) - 1

    def polar(ang_deg, rad, z):
        a = math.radians(ang_deg)
        return (math.cos(a) * rad, math.sin(a) * rad, z)
    # Forearm leaves the fist at ~125 deg to the grip axis (back and down toward the pommel side), like a real
    # sword grip: with the blade cocked up-forward the forearm runs back-down out of the first-person view
    elbow = add((0.03, -0.288, -0.153), (0.04, 0.037))
    wrist = add((0.03, -0.075, -0.005), (0.03, 0.022))
    edges.append((elbow, wrist))
    palm = add(polar(-55, 0.036, 0.0), (0.03, 0.02))
    edges.append((wrist, palm))
    fingers = [(0.032, 0.0098, 1.0), (0.01, 0.0102, 1.05), (-0.012, 0.0096, 1.0), (-0.032, 0.0085, 0.9)]
    for (z, fr, ln) in fingers:
        kn = add(polar(10, 0.043, z), fr * 1.15)
        edges.append((palm, kn))
        prev = kn
        for (ang, rad) in ((75, 0.031), (145, 0.028), (205 * ln, 0.026)):
            v = add(polar(ang, rad, z), fr * (0.95 if ang < 150 else 0.85))
            edges.append((prev, v))
            prev = v
    th0 = add(polar(-115, 0.04, -0.012), 0.012)
    edges.append((wrist, th0))
    th1 = add(polar(-160, 0.036, 0.008), 0.0115)
    edges.append((th0, th1))
    th2 = add(polar(165, 0.034, 0.03), 0.0105)
    edges.append((th1, th2))
    th3 = add(polar(130, 0.033, 0.042), 0.0095)
    edges.append((th2, th3))
    return verts, edges, radii


def hand_open_skeleton():
    """Right hand open, palm facing -Y (forward / target), fingers up-forward, slightly curled & spread.
    Origin sits ~6 cm in front of the palm (where spell energy gathers)."""
    verts, edges, radii = [], [], []

    def add(p, r):
        verts.append(p)
        radii.append(r)
        return len(verts) - 1
    elbow = add((0.0, 0.24, -0.1), (0.04, 0.037))
    wrist = add((0.0, 0.06, -0.06), (0.03, 0.022))
    edges.append((elbow, wrist))
    palm = add((0.0, 0.055, -0.01), (0.034, 0.016))
    edges.append((wrist, palm))
    spreads = [(-0.03, 0.0098, 0.95, -0.18), (-0.01, 0.0102, 1.05, -0.05), (0.012, 0.0096, 1.0, 0.07), (0.03, 0.0085, 0.82, 0.2)]
    for (x, fr, ln, sp) in spreads:
        kn = add((x, 0.05, 0.035), fr * 1.15)
        edges.append((palm, kn))
        prev = kn
        segs = [(0.045, -0.006), (0.03, -0.012), (0.024, -0.016)]
        cx, cy, cz = x, 0.05, 0.035
        for (sl, curl) in segs:
            cx += sp * sl
            cz += sl * ln
            cy += curl
            v = add((cx, cy, cz), fr * 0.9)
            edges.append((prev, v))
            prev = v
    th0 = add((-0.03, 0.06, -0.035), 0.012)
    edges.append((wrist, th0))
    th1 = add((-0.06, 0.04, -0.01), 0.0115)
    edges.append((th0, th1))
    th2 = add((-0.078, 0.025, 0.015), 0.0105)
    edges.append((th1, th2))
    return verts, edges, radii


def build_fp_arm(pose="grip", side="r"):
    v, e, r = hand_grip_skeleton() if pose == "grip" else hand_open_skeleton()
    hand = _skin_mesh(v, e, r, "Hand", "leather_brown", subsurf=2)
    parts = [hand]
    # glove cuff flare + vambrace
    if pose == "grip":
        wrist, elbow = Vector((0.03, -0.075, -0.005)), Vector((0.03, -0.288, -0.153))
    else:
        wrist, elbow = Vector((0.0, 0.06, -0.06)), Vector((0.0, 0.24, -0.1))
    axis = (elbow - wrist).normalized()
    q = axis.to_track_quat("Z", "X")

    def along(t):
        return wrist.lerp(elbow, t)
    cuff = shapes.lathe([(0.032, 0.0), (0.04, 0.02), (0.042, 0.045), (0.0, 0.045)], 16, "Cuff", "leather_dark", cap_top=False)
    cuff.matrix_world = Matrix.Translation(along(0.06)) @ q.to_matrix().to_4x4()
    parts.append(cuff)
    vamb = shapes.lathe([(0.042, 0.0), (0.045, 0.025), (0.048, 0.12), (0.05, 0.15), (0.051, 0.155)], 20, "Vambrace", "steel_armor",
                        cap_bottom=False, cap_top=False)
    core.add_solidify(vamb, 0.004, 1.0)
    vamb.matrix_world = Matrix.Translation(along(0.2)) @ q.to_matrix().to_4x4()
    parts.append(vamb)
    for t, rr in ((0.28, 0.049), (0.8, 0.054)):
        band = shapes.torus(rr, 0.006, (0, 0, 0), major=24, minor=6, mat="leather_dark")
        band.matrix_world = Matrix.Translation(along(t)) @ q.to_matrix().to_4x4()
        parts.append(band)
    # Domed elbow cop closes the end of the vambrace: seen from behind it reads as an elbow guard, never a hollow tube
    cop = shapes.lathe([(0.052, 0.0), (0.05, 0.022), (0.042, 0.04), (0.026, 0.052), (0.0, 0.057)], 20, "ElbowCop", "steel_armor",
                       cap_bottom=True, cap_top=False)
    cop.matrix_world = Matrix.Translation(along(0.86)) @ q.to_matrix().to_4x4()
    parts.append(cop)

    # knuckle plates on the glove back (grip pose)
    if pose == "grip":
        for z in (0.032, 0.01, -0.012, -0.032):
            a = math.radians(10)
            parts.append(shapes.box((0.018, 0.012, 0.016), (math.cos(a) * 0.055, math.sin(a) * 0.055, z), mat="steel_armor", bevel=0.003,
                                    rot=(0, 0, a)))
        parts.append(shapes.box((0.03, 0.05, 0.06), (0.05, -0.04, 0.0), mat="steel_armor", bevel=0.008, rot=(0, 0, math.radians(-35))))
    for p in parts:
        bpy.context.view_layer.update()
        if p.matrix_world != Matrix.Identity(4):
            core.apply_transform(p)
    ob = core.join(parts, f"fp_arm_{pose}_{side}")
    if side == "l":
        ob.data.transform(Matrix.Scale(-1, 4, Vector((1, 0, 0))))
        ob.data.flip_normals()
    core.finalize(ob, smooth_angle=60, uv="box", seed=21, weathering=0.6)
    shapes.bake_vertex_ao(ob, rays=12, dist=0.05, strength=0.6)
    return ob


def build_fp_upper_arm():
    """First-person upper arm: a quilted dark gambeson sleeve from the elbow (z=0) to the shoulder (z=1).
    Unit length and radially symmetric: the game stretches it from the forearm's elbow back to the shoulder
    every frame, so first-person forearms never end in a floating elbow guard."""
    n = 16
    prof = [(0.0, -0.012)]
    for i in range(n + 1):
        t = i / n
        r = 0.046 + 0.017 * math.sin(min(1.0, t * 1.3) * math.pi / 2)
        r += 0.0025 * math.cos(t * n * math.pi)  # quilted channels
        prof.append((r, t))
    prof.append((0.0, 1.0))
    parts = [shapes.lathe(prof, 18, "Sleeve", "cloth_dark", smooth_profile=True)]
    # stitched leather cuff band where the sleeve tucks into the vambrace
    parts.append(shapes.torus(0.05, 0.005, (0, 0, 0.05), major=20, minor=6, mat="leather_dark", scale=(1, 1, 0.5)))
    ob = core.join(parts, "fp_upper_arm")
    core.finalize(ob, smooth_angle=60, uv="cyl", seed=23, weathering=0.5)
    return ob


GEAR = {
    "iron_sword": build_longsword,
    "gravefeast_cleaver": build_cleaver,
    "battleaxe": build_battleaxe,
    "round_shield": build_round_shield,
    "hunting_bow": build_bow,
    "arrow": build_arrow,
    "tome_fire": lambda: build_tome("fire"),
    "tome_spark": lambda: build_tome("spark"),
    "tome_mend": lambda: build_tome("mend"),
    "health_potion": lambda: build_potion("health"),
    "magicka_potion": lambda: build_potion("magicka"),
    "stamina_potion": build_stamina_potion,
    "swiftness_draught": build_swiftness_draught,
    "ironbark_tonic": build_ironbark_tonic,
    "troll_fat_salve": build_troll_fat_salve,
    "glowcap_mushroom": build_glowcap_mushroom,
    "grave_moss": build_grave_moss,
    "bat_wing_jerky": build_bat_wing_jerky,
    "goblin_toenail": build_goblin_toenail,
    "iron_helm": build_helm,
    "leather_cuirass": build_cuirass,
    "steel_gauntlets": lambda: build_gauntlet(False),
    "thunderclap_gauntlets": lambda: build_gauntlet(True),
    "iron_boots": build_boots,
    "silver_ring": build_ring,
    "bone_amulet": build_amulet,
    "hand_axe": build_hand_axe,
    "flanged_mace": build_mace,
    "seax": build_seax,
    "broadsword": build_broadsword,
    "war_hammer": build_war_hammer,
    "dane_axe": build_dane_axe,
    "yew_longbow": lambda: build_bow("yew_longbow", 0.86, "wood_dark", "iron_dark", 0.02, 0.05, 2),
    "bone_short_bow": lambda: build_bow("bone_short_bow", 0.52, "bone", "iron_dark", 0.07, 0.07, 3),
    "kite_shield": build_kite_shield,
    "buckler": build_buckler,
    "tome_frost": lambda: build_tome("frost"),
    "tome_venom": lambda: build_tome("venom"),
    "tome_void": lambda: build_tome("void"),
    "tome_blood": lambda: build_tome("blood"),
    "chain_hauberk": build_hauberk,
    "wolf_hood": build_wolf_hood,
    "hide_bracers": build_bracers,
    "fur_boots": build_fur_boots,
    "ember_ring": build_ember_ring,
    "gold_signet": build_gold_signet,
    "wolf_tooth_amulet": build_wolf_tooth_amulet,
    "fp_arm_grip_r": lambda: build_fp_arm("grip", "r"),
    "fp_arm_grip_l": lambda: build_fp_arm("grip", "l"),
    "fp_arm_open_r": lambda: build_fp_arm("open", "r"),
    "fp_arm_open_l": lambda: build_fp_arm("open", "l"),
    "fp_upper_arm": build_fp_upper_arm,
}

ICON_VIEWS = {
    "iron_sword": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, math.radians(20))),
    "gravefeast_cleaver": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, 0)),
    "battleaxe": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, 0)),
    "hunting_bow": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, math.radians(90))),
    "arrow": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, math.radians(90))),
    "round_shield": dict(yaw=0.3, elev=0.15, rot=(0, 0, 0)),
    "hand_axe": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, 0)),
    "flanged_mace": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, 0)),
    "seax": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, 0)),
    "broadsword": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, math.radians(20))),
    "war_hammer": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, 0)),
    "dane_axe": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, 0)),
    "yew_longbow": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, math.radians(90))),
    "bone_short_bow": dict(yaw=0.0, elev=0.05, roll=math.radians(-45), rot=(0, 0, math.radians(90))),
    "kite_shield": dict(yaw=0.3, elev=0.15, rot=(0, 0, 0)),
    "buckler": dict(yaw=0.3, elev=0.15, rot=(0, 0, 0)),
    "ember_ring": dict(yaw=-0.4, elev=0.5, rot=(math.radians(20), 0, 0)),
    "gold_signet": dict(yaw=-0.4, elev=0.5, rot=(math.radians(20), 0, 0)),
    "hide_bracers": dict(yaw=-0.5, elev=0.2, rot=(math.radians(180), 0, 0)),
    "silver_ring": dict(yaw=-0.4, elev=0.5, rot=(math.radians(20), 0, 0)),
    "steel_gauntlets": dict(yaw=-0.5, elev=0.2, rot=(math.radians(180), 0, 0)),
    "thunderclap_gauntlets": dict(yaw=-0.5, elev=0.2, rot=(math.radians(180), 0, 0)),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set()
    for i, a in enumerate(argv):
        if a == "--only":
            only = set(argv[i + 1].split(","))
    core.reset_scene()
    built = {}
    for name, fn in GEAR.items():
        if only and name not in only:
            continue
        ob = fn()
        ob.name = name
        core.export_glb(ob, f"gear/{name}", "gear")
        built[name] = ob
    core.write_manifest()
    if "--icons" in argv:
        for name, ob in built.items():
            if name.startswith("fp_arm"):
                continue
            for o in bpy.data.objects:
                o.hide_render = True
            ob.hide_render = False
            for c in ob.children:
                c.hide_render = False
            view = ICON_VIEWS.get(name, {})
            saved = ob.rotation_euler.copy()
            ob.rotation_euler = view.get("rot", (0, 0, 0))
            bpy.context.view_layer.update()
            render.render_icon([ob], name, yaw=view.get("yaw", -0.6), elev=view.get("elev", 0.4), roll=view.get("roll", 0.0))
            ob.rotation_euler = saved
    if "--preview" in argv:
        for o in bpy.data.objects:
            o.hide_render = True
        vis = []
        order = [n for n in GEAR if n in built]
        for n in order:
            o = built[n]
            c = o.copy()
            c.data = o.data
            core.link(c)
            c.hide_render = False
            scale = 1.0 if not n.startswith(("silver_ring", "bone_amulet")) else 4.0
            if n in ("iron_sword", "gravefeast_cleaver", "battleaxe", "hunting_bow", "arrow"):
                c.rotation_euler = (0, math.radians(90), 0)
            c.scale = (scale, scale, scale)
            bpy.context.view_layer.update()
            vis.append(c)
        rows = [vis[:6], vis[6:13], vis[13:]]
        y = 0.0
        for r in rows:
            render.layout_row(r, gap=0.12, y=y)
            y += 0.9
        # cam_dist 0.95: the widest row (sword .. arrow) needs ~1.1x the layout span in view at 40 mm
        render.render_sheet([o for o in vis], "batch2_weapons_gear", cam_dist=0.95, elev=0.75, lens=40, samples=48,
                            target_z_frac=0.0, yaw=0.0)


if __name__ == "__main__":
    main()
