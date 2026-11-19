"""Shared Blender 4.5 LTS helpers for Clean Stylized Dark Fantasy assets,
glTF (.glb) exporting, manifest recording, and studio Cycles preview renders.
"""

import json
import math
import pathlib
import bpy
from mathutils import Vector

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
MODELS_DIR = REPO_ROOT / "game" / "assets" / "models"
PREVIEWS_DIR = REPO_ROOT / "art" / "previews"
MANIFEST_PATH = REPO_ROOT / "art" / "manifest.json"


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_material(
    name: str,
    color: tuple[float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.72,
    emission: tuple[float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None and emission_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def palette() -> dict[str, bpy.types.Material]:
    return {
        "stone_dark": make_material("StoneDark", (0.19, 0.21, 0.25), 0.0, 0.84),
        "stone_mid": make_material("StoneMid", (0.29, 0.31, 0.36), 0.0, 0.78),
        "stone_trim": make_material("StoneTrim", (0.40, 0.42, 0.46), 0.05, 0.68),
        "stone_moss": make_material("StoneMoss", (0.20, 0.27, 0.22), 0.0, 0.85),
        "wood_dark": make_material("WoodDark", (0.24, 0.15, 0.09), 0.0, 0.75),
        "wood_warm": make_material("WoodWarm", (0.38, 0.24, 0.13), 0.0, 0.68),
        "leather": make_material("Leather", (0.22, 0.13, 0.08), 0.0, 0.62),
        "iron_dark": make_material("IronDark", (0.18, 0.20, 0.23), 0.82, 0.42),
        "steel": make_material("Steel", (0.56, 0.59, 0.64), 0.9, 0.28),
        "bronze": make_material("Bronze", (0.58, 0.41, 0.18), 0.85, 0.35),
        "gold_sponsored": make_material("GoldSponsored", (0.95, 0.72, 0.16), 0.92, 0.22, (0.95, 0.65, 0.1), 0.6),
        "cloth_red": make_material("ClothRed", (0.52, 0.11, 0.12), 0.0, 0.85),
        "cloth_teal": make_material("ClothTeal", (0.12, 0.38, 0.36), 0.0, 0.8),
        "cloth_dark": make_material("ClothDark", (0.14, 0.15, 0.19), 0.0, 0.86),
        "parchment": make_material("Parchment", (0.78, 0.71, 0.54), 0.0, 0.82),
        "bone": make_material("Bone", (0.74, 0.70, 0.60), 0.0, 0.64),
        "goblin_skin": make_material("GoblinSkin", (0.28, 0.48, 0.20), 0.0, 0.62),
        "flame_glow": make_material("FlameGlow", (1.0, 0.55, 0.12), 0.0, 0.25, (1.0, 0.48, 0.08), 4.5),
        "arcane_cyan": make_material("ArcaneCyan", (0.25, 0.85, 1.0), 0.1, 0.2, (0.25, 0.85, 1.0), 4.2),
        "safe_emerald": make_material("SafeEmerald", (0.22, 0.92, 0.68), 0.1, 0.25, (0.22, 0.92, 0.68), 3.6),
        "boss_ember": make_material("BossEmber", (1.0, 0.22, 0.08), 0.1, 0.2, (1.0, 0.20, 0.06), 5.2),
        "potion_red": make_material("PotionRed", (0.85, 0.12, 0.16), 0.05, 0.15, (0.7, 0.08, 0.1), 1.4),
        "streamer_ring": make_material("StreamerRing", (0.98, 0.35, 0.88), 0.1, 0.2, (1.0, 0.35, 0.92), 4.8),
    }


def apply_stylized_finish(obj: bpy.types.Object, mat: bpy.types.Material, bevel_width: float = 0.03, segments: int = 2) -> bpy.types.Object:
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    if bevel_width > 0.0:
        mod = obj.modifiers.new(name="Bevel", type="BEVEL")
        mod.width = bevel_width
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30.0)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def add_box(name: str, loc: tuple[float, float, float], size: tuple[float, float, float], mat: bpy.types.Material, rot: tuple[float, float, float] = (0, 0, 0), bevel: float = 0.025) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return apply_stylized_finish(obj, mat, bevel_width=bevel)


def add_cylinder(name: str, loc: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material, vertices: int = 12, rot: tuple[float, float, float] = (0, 0, 0), bevel: float = 0.015) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return apply_stylized_finish(obj, mat, bevel_width=bevel)


def add_cone(name: str, loc: tuple[float, float, float], r1: float, r2: float, depth: float, mat: bpy.types.Material, vertices: int = 12, rot: tuple[float, float, float] = (0, 0, 0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def add_sphere(name: str, loc: tuple[float, float, float], radius: float, mat: bpy.types.Material, scale: tuple[float, float, float] = (1, 1, 1)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    if scale != (1, 1, 1):
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def add_torus(name: str, loc: tuple[float, float, float], major_r: float, minor_r: float, mat: bpy.types.Material, rot: tuple[float, float, float] = (0, 0, 0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=24,
        minor_segments=10,
        major_radius=major_r,
        minor_radius=minor_r,
        location=loc,
        rotation=rot,
    )
    obj = bpy.context.active_object
    obj.name = name
    return apply_stylized_finish(obj, mat, bevel_width=0.0)


def compute_scene_bounds() -> tuple[list[float], int]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    min_v = Vector((1e9, 1e9, 1e9))
    max_v = Vector((-1e9, -1e9, -1e9))
    tri_count = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        tri_count += sum(max(1, len(p.vertices) - 2) for p in mesh.polygons)
        for v in mesh.vertices:
            world_co = obj.matrix_world @ v.co
            min_v.x = min(min_v.x, world_co.x)
            min_v.y = min(min_v.y, world_co.y)
            min_v.z = min(min_v.z, world_co.z)
            max_v.x = max(max_v.x, world_co.x)
            max_v.y = max(max_v.y, world_co.y)
            max_v.z = max(max_v.z, world_co.z)
        eval_obj.to_mesh_clear()
    size = max_v - min_v
    return [round(size.x, 3), round(size.y, 3), round(size.z, 3)], tri_count


def export_asset(batch: str, asset_name: str, manifest_entries: list[dict]) -> pathlib.Path:
    out_dir = MODELS_DIR / batch
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{asset_name}.glb"

    # Apply modifiers cleanly before export so bevels are baked into geometry
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.modifiers:
            bpy.context.view_layer.objects.active = obj
            for mod in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)

    dims, tris = compute_scene_bounds()

    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )

    manifest_entries.append(
        {
            "batch": batch,
            "name": asset_name,
            "path": str(out_path.relative_to(REPO_ROOT)),
            "dimensions_xyz_m": dims,
            "triangles": tris,
            "bytes": out_path.stat().st_size,
        }
    )
    print(f"[blender] Exported {batch}/{asset_name}.glb ({tris} tris, {dims} m)")
    return out_path


def render_batch_preview(
    batch_title: str,
    glb_paths: list[pathlib.Path],
    output_png: pathlib.Path,
    spacing: float = 3.2,
    cam_dist: float = 12.0,
    cam_height: float = 5.5,
    single_row: bool = False,
) -> None:
    """Imports all exported .glb models from a batch onto a dark stylized studio plinth
    and renders a clean Cycles CPU preview image for User art review.
    """
    reset_scene()
    PREVIEWS_DIR.mkdir(parents=True, exist_ok=True)
    p = palette()

    # Arrange assets in neat grid (or single unobstructed showcase row)
    cols = len(glb_paths) if single_row else max(1, math.ceil(math.sqrt(len(glb_paths))))
    rows = 1 if single_row else max(1, math.ceil(len(glb_paths) / cols))

    for idx, glb in enumerate(glb_paths):
        r = idx // cols
        c = idx % cols
        x = (c - (cols - 1) * 0.5) * spacing
        y = ((rows - 1) * 0.5 - r) * spacing

        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(glb))
        imported = [o for o in bpy.context.scene.objects if o not in before]

        # Shift imported root objects to grid cell and place bottom on z=0
        roots = [o for o in imported if o.parent is None]
        for root in roots:
            root.location.x += x
            root.location.y += y
            root.rotation_euler.z += math.radians(-16)

    # Dark studio backdrop plane
    bpy.ops.mesh.primitive_plane_add(size=max(cols, rows) * spacing * 3.5, location=(0, 0, -0.02))
    floor = bpy.context.active_object
    floor.data.materials.append(make_material("StudioFloor", (0.07, 0.08, 0.11), 0.1, 0.75))

    # Dramatic Skyrim torch-warm key + cool Nordic rim lighting
    bpy.ops.object.light_add(type="AREA", location=(cam_dist * 0.7, -cam_dist * 0.8, cam_height * 1.5))
    key = bpy.context.active_object
    key.data.energy = 2800.0 * (spacing / 3.2) ** 1.4
    key.data.size = 6.0
    key.data.color = (1.0, 0.80, 0.58)
    key.rotation_euler = (math.radians(55), 0, math.radians(38))

    bpy.ops.object.light_add(type="AREA", location=(-cam_dist * 0.8, cam_dist * 0.6, cam_height * 1.2))
    rim = bpy.context.active_object
    rim.data.energy = 1400.0 * (spacing / 3.2) ** 1.4
    rim.data.size = 7.0
    rim.data.color = (0.48, 0.72, 1.0)
    rim.rotation_euler = (math.radians(60), 0, math.radians(-135))

    # Subtle ambient world
    world = bpy.data.worlds.new("StudioWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.03, 0.04, 0.06, 1.0)
    bg.inputs["Strength"].default_value = 0.55

    # Camera framed toward grid center
    bpy.ops.object.camera_add(location=(0.0, -cam_dist, cam_height))
    cam = bpy.context.active_object
    direction = Vector((0.0, 0.0, 0.9)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 36.0
    bpy.context.scene.camera = cam

    # Cycles CPU fast high-quality studio render
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(output_png)

    bpy.ops.render.render(write_still=True)
    print(f"[blender] Rendered preview {output_png.name} for {batch_title}")


def save_manifest(entries: list[dict], previews: list[str]) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "style": "Clean Stylized Dark Fantasy",
        "grid_unit_meters": 4.0,
        "blender_version": bpy.app.version_string,
        "previews": previews,
        "assets": entries,
    }
    MANIFEST_PATH.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"[blender] Wrote art/manifest.json ({len(entries)} assets, {len(previews)} previews)")
