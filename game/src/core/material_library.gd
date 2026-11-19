class_name MaterialLibrary
extends RefCounted
## Tier 1: Shared high-resolution PBR material library (game/data/materials.json).
## Blender exports .glb files whose surface materials carry only a NAME; this library binds the
## shared albedo / normal / ORM textures (game/assets/textures/) so every model in the game uses
## the same consistent, memory-efficient set of ORMMaterial3D resources.

const TEX_DIR := "res://assets/textures/"
const DEFS_PATH := "res://data/materials.json"

static var _defs: Dictionary = {}
static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _loaded: bool = false
## Graphics quality hook: 0 = low (no normal/ORM detail), 1 = full.
static var detail_level: int = 1


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(DEFS_PATH, FileAccess.READ)
	if f == null:
		push_warning("MaterialLibrary: missing %s" % DEFS_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_defs = (parsed as Dictionary).get("materials", {})


static func has_material(mat_name: String) -> bool:
	ensure_loaded()
	return _defs.has(mat_name)


static func material_names() -> Array:
	ensure_loaded()
	return _defs.keys()


static func get_material(mat_name: String) -> Material:
	ensure_loaded()
	if _cache.has(mat_name):
		return _cache[mat_name]
	if not _defs.has(mat_name):
		return null
	var d: Dictionary = _defs[mat_name]
	var m := ORMMaterial3D.new()
	m.resource_name = mat_name
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var tex := str(d.get("tex", ""))
	if not tex.is_empty():
		m.albedo_texture = _tex("%s_albedo" % tex)
		var orm := _tex("%s_orm" % tex)
		if orm != null:
			m.orm_texture = orm
			m.roughness = 1.0
			m.metallic = 1.0
			m.ao_enabled = true
			m.ao_light_affect = 0.35
		var nrm := _tex("%s_normal" % tex)
		if nrm != null:
			m.normal_enabled = true
			m.normal_texture = nrm
			m.normal_scale = float(d.get("normal_scale", 1.0))
		if bool(d.get("emission_tex", false)):
			m.emission_enabled = true
			m.emission_texture = _tex("%s_emission" % tex)
			m.emission = Color.WHITE
			m.emission_energy_multiplier = float(d.get("emission_energy", 1.0))
		elif d.has("emission"):
			m.emission_enabled = true
			m.emission = Color.html(str(d["emission"]))
			m.emission_energy_multiplier = float(d.get("emission_energy", 1.0))
			var em_mask := _tex("%s_emission" % tex)
			if em_mask != null:
				m.emission_texture = em_mask
				m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		if float(d.get("parallax", 0.0)) > 0.0:
			var ht := _tex("%s_height" % tex)
			if ht != null:
				m.heightmap_enabled = true
				m.heightmap_texture = ht
				m.heightmap_scale = float(d["parallax"]) * 100.0
				m.heightmap_deep_parallax = false
	else:
		m.albedo_color = Color.html(str(d.get("color", "#808080")))
		m.roughness = float(d.get("roughness", 0.5))
		m.metallic = float(d.get("metallic", 0.0))
		if d.has("emission"):
			m.emission_enabled = true
			m.emission = Color.html(str(d["emission"]))
			m.emission_energy_multiplier = float(d.get("emission_energy", 1.0))
	if d.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.albedo_color.a = float(d["alpha"])
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.6
	if bool(d.get("unshaded", false)):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if bool(d.get("double_sided", false)):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if bool(d.get("vertex_color", false)):
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = false
	if float(d.get("subsurface", 0.0)) > 0.0:
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = float(d["subsurface"])
		m.subsurf_scatter_skin_mode = mat_name.begins_with("skin")
	_cache[mat_name] = m
	return m


## Re-binds every surface of every MeshInstance3D under `root` to the shared library material
## of the same name. Mesh resources are shared across instances, so this runs once per mesh.
static func apply_to(root: Node) -> void:
	if root == null:
		return
	ensure_loaded()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null or mesh.has_meta("dc_mats_bound"):
			continue
		for i in range(mesh.get_surface_count()):
			var cur := mesh.surface_get_material(i)
			var nm := _base_name(cur.resource_name if cur != null else "")
			var lib := get_material(nm)
			if lib != null:
				mesh.surface_set_material(i, lib)
		mesh.set_meta("dc_mats_bound", true)


static func _base_name(n: String) -> String:
	# Blender may suffix duplicates ("stone_block.001"); importer may add "_mat".
	var s := n
	var dot := s.find(".")
	if dot > 0:
		s = s.substr(0, dot)
	return s


static func _tex(base: String) -> Texture2D:
	if _tex_cache.has(base):
		return _tex_cache[base]
	var path := TEX_DIR + base + ".webp"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	elif FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			img.generate_mipmaps()
			t = ImageTexture.create_from_image(img)
	_tex_cache[base] = t
	return t
