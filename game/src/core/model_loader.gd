class_name ModelLoader
extends RefCounted
## Tier 1 Asset Helper: Instantiates Blender-exported .glb models cleanly in both
## imported Godot editor runs and cold headless CI environments (via GLTFDocument fallback),
## with graceful geometric fallback if an asset is ever missing.

static var _gltf_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func instantiate_model(res_path: String, fallback_size: Vector3 = Vector3.ONE, fallback_color: Color = Color(0.45, 0.48, 0.54)) -> Node3D:
	if res_path.is_empty():
		return _make_fallback(fallback_size, fallback_color)

	# 1. Preferred path: Godot imported PackedScene resource
	if ResourceLoader.exists(res_path):
		var packed := ResourceLoader.load(res_path)
		if packed is PackedScene:
			var inst: Node = packed.instantiate()
			if inst is Node3D:
				MaterialLibrary.apply_to(inst)
				return inst

	# 2. Fallback path: Direct runtime GLTFDocument load (works cleanly even before editor import)
	var global_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		if _gltf_cache.has(res_path):
			var cached: PackedScene = _gltf_cache[res_path]
			var dup: Node = cached.instantiate()
			if dup is Node3D:
				MaterialLibrary.apply_to(dup)
				return dup
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(global_path, state)
		if err == OK:
			var generated := doc.generate_scene(state)
			if generated is Node3D:
				var packed_scene := PackedScene.new()
				_set_owner_recursive(generated, generated)
				if packed_scene.pack(generated) == OK:
					_gltf_cache[res_path] = packed_scene
				MaterialLibrary.apply_to(generated)
				return generated

	push_warning("ModelLoader: Could not load '%s'; using graceful placeholder mesh." % res_path)
	return _make_fallback(fallback_size, fallback_color)


static func clear_cache() -> void:
	_gltf_cache.clear()


## Returns the first Mesh found in a model (kit pieces are exported as a single merged mesh),
## with library materials bound — used for MultiMesh batching of repeated architecture.
static func load_mesh(res_path: String) -> Mesh:
	if _mesh_cache.has(res_path):
		return _mesh_cache[res_path]
	var inst := instantiate_model(res_path)
	var found: Mesh = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			found = (n as MeshInstance3D).mesh
		for c in n.get_children():
			stack.append(c)
	inst.free()
	_mesh_cache[res_path] = found
	return found


static func _set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owner_recursive(child, root)


static func _make_fallback(size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	box.material = mat
	mi.mesh = box
	mi.position.y = size.y * 0.5
	root.add_child(mi)
	return root
