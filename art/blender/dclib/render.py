"""Cycles preview sheets and transparent item icons."""

from __future__ import annotations

import math

import bpy
from mathutils import Matrix, Vector

from .core import ICONS, PREVIEWS, add_preview, link


def _cycles(samples=64, w=1280, h=720, transparent=False):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    sc.cycles.max_bounces = 6
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = transparent
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"


def _world(color=(0.02, 0.022, 0.03), strength=1.0):
    w = bpy.data.worlds.new("PreviewWorld") if not bpy.data.worlds else bpy.data.worlds[0]
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*color, 1.0)
    bg.inputs["Strength"].default_value = strength


def _light(kind, loc, energy, color=(1, 1, 1), size=1.0, rot=None, name="L"):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
    elif kind in ("POINT", "SPOT"):
        ld.shadow_soft_size = size
    ob = bpy.data.objects.new(name, ld)
    link(ob)
    ob.location = loc
    if rot is not None:
        ob.rotation_euler = rot
    return ob


def _look_at(ob, target):
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def _camera(loc, target, lens=35.0, ortho=None):
    cd = bpy.data.cameras.new("Cam")
    cd.lens = lens
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", cd)
    link(cam)
    cam.location = loc
    _look_at(cam, target)
    bpy.context.scene.camera = cam
    return cam


def bounds(objs):
    xs, ys, zs = [], [], []
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            xs.append(w.x)
            ys.append(w.y)
            zs.append(w.z)
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def dungeon_floor(size=60.0, z=0.0):
    from .shapes import box
    from .core import uv_box
    fl = box((size, size, 0.1), (0, 0, z - 0.05), mat="flagstone", name="PreviewFloor")
    uv_box(fl)
    return fl


def layout_row(objs, gap=0.6, y=0.0):
    """Place objects left-to-right with spacing (objects are already joined/finalized)."""
    x = 0.0
    placed = []
    for o in objs:
        mn, mx = bounds([o])
        w = mx.x - mn.x
        o.location.x += x - mn.x
        o.location.y += y - (mn.y + mx.y) / 2
        o.location.z += -mn.z
        bpy.context.view_layer.update()
        placed.append(o)
        x += w + gap
    total = x - gap
    for o in placed:
        o.location.x -= total / 2
    bpy.context.view_layer.update()
    return total


def render_sheet(objs, out_name, title_rel=None, cam_dist=1.0, elev=0.32, lens=40.0, samples=64,
                 key_color=(1.0, 0.72, 0.45), fill_color=(0.45, 0.55, 0.8), floor=True, w=1600, h=900,
                 target_z_frac=0.4, yaw=-0.35):
    """Studio sheet: warm torch key, cool fill, rim, on a flagstone floor."""
    _cycles(samples, w, h)
    _world((0.012, 0.014, 0.02), 1.0)
    if floor:
        dungeon_floor()
    mn, mx = bounds(objs)
    ctr = (mn + mx) / 2
    span = max(mx.x - mn.x, (mx.z - mn.z) * 1.6, 1.0)
    d = span * 1.05 * cam_dist
    target = Vector((ctr.x, ctr.y, mn.z + (mx.z - mn.z) * target_z_frac))
    cam_loc = target + Vector((math.sin(yaw) * d, -math.cos(yaw) * d, d * elev))
    _camera(cam_loc, target, lens)
    def e(off, k):
        return k * off.length ** 2
    ko = Vector((-span * 0.4, -span * 0.5, span * 0.7))
    _light("AREA", target + ko, e(ko, 70), key_color, span * 0.5, name="Key")
    kl = bpy.data.objects["Key"]
    _look_at(kl, target)
    fo = Vector((span * 0.6, -span * 0.35, span * 0.3))
    _light("AREA", target + fo, e(fo, 18), fill_color, span * 0.6, name="Fill")
    _look_at(bpy.data.objects["Fill"], target)
    ro = Vector((0.0, span * 0.6, span * 0.5))
    _light("AREA", target + ro, e(ro, 40), (1.0, 0.85, 0.7), span * 0.4, name="Rim")
    _look_at(bpy.data.objects["Rim"], target)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    out = PREVIEWS / f"{out_name}.png"
    bpy.context.scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    add_preview(f"art/previews/{out_name}.png")
    print(f"[render] {out}")
    return out


def render_scene(cam_loc, target, out_name, lens=28.0, samples=64, w=1600, h=900, world=(0.01, 0.012, 0.018),
                 world_strength=1.0):
    """Render whatever scene was assembled (lights placed by caller)."""
    _cycles(samples, w, h)
    _world(world, world_strength)
    _camera(cam_loc, target, lens)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    out = PREVIEWS / f"{out_name}.png"
    bpy.context.scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    add_preview(f"art/previews/{out_name}.png")
    print(f"[render] {out}")
    return out


def render_icon(objs, name, samples=48, size=256, yaw=-0.6, elev=0.45, lens=50.0, rim=(0.6, 0.75, 1.0), roll=0.0, fill=0.86):
    """Transparent-background inventory icon rendered from the actual 3D model (orthographic, tightly framed)."""
    _cycles(samples, size, size, transparent=True)
    _world((0.05, 0.05, 0.06), 0.6)
    mn, mx = bounds(objs)
    ctr = (mn + mx) / 2
    rad = max((mx - mn).length / 2, 0.01)
    view = Vector((math.sin(yaw) * math.cos(elev), -math.cos(yaw) * math.cos(elev), math.sin(elev)))
    cam_loc = ctr + view * rad * 6.0
    cam = _camera(cam_loc, ctr, lens, ortho=1.0)
    cam.data.clip_start = 0.001
    cam.data.clip_end = rad * 20.0
    bpy.context.view_layer.update()
    if roll:
        from mathutils import Matrix as _M
        cam.matrix_world = cam.matrix_world @ _M.Rotation(roll, 4, "Z")
    bpy.context.view_layer.update()
    # fit ortho scale to the silhouette projected onto the camera plane
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for o in objs:
        for v in o.data.vertices:
            p = inv @ (o.matrix_world @ v.co)
            xs.append(p.x)
            ys.append(p.y)
    w = max(xs) - min(xs)
    h = max(ys) - min(ys)
    cx = (max(xs) + min(xs)) / 2
    cy = (max(ys) + min(ys)) / 2
    cam.matrix_world = cam.matrix_world @ Matrix.Translation((cx, cy, 0))
    bpy.context.view_layer.update()
    cam.data.ortho_scale = max(w, h) / fill
    for o in [o for o in bpy.data.objects if o.type == "LIGHT"]:
        bpy.data.objects.remove(o, do_unlink=True)
    _light("AREA", ctr + Vector((-rad * 2, -rad * 2, rad * 3)), 220 * rad * rad + 30 * rad, (1.0, 0.86, 0.7), rad * 2, name="IKey")
    _look_at(bpy.data.objects["IKey"], ctr)
    _light("AREA", ctr + Vector((rad * 2.5, rad * 2, rad * 1.5)), 260 * rad * rad + 30 * rad, rim, rad * 1.5, name="IRim")
    _look_at(bpy.data.objects["IRim"], ctr)
    _light("AREA", ctr + Vector((rad * 2.5, -rad * 2.5, 0)), 90 * rad * rad + 10 * rad, (0.8, 0.85, 1.0), rad * 2, name="IFill")
    _look_at(bpy.data.objects["IFill"], ctr)
    ICONS.mkdir(parents=True, exist_ok=True)
    out = ICONS / f"{name}.png"
    bpy.context.scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    print(f"[icon] {out}")
    return out
