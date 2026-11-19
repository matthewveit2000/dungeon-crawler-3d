extends GutTest
## GameSettings (persistence defaults, live set/get, key rebinding with conflict swap) and the shared
## PBR MaterialLibrary (every material builds, textured materials bind albedo/normal/ORM, name binding).


func test_settings_defaults_and_set_get() -> void:
	assert_not_null(GameSettings, "GameSettings autoload must exist")
	assert_between(GameSettings.get_quality(), 0, 3, "Quality preset is 0..3")
	var prev: Variant = GameSettings.get_value("gameplay", "head_bob")
	GameSettings.set_value("gameplay", "head_bob", 0.25, false)
	assert_almost_eq(float(GameSettings.get_value("gameplay", "head_bob")), 0.25, 0.0001)
	GameSettings.set_value("gameplay", "head_bob", prev, false)
	assert_eq(str(GameSettings.get_value("gameplay", "crosshair")), str(GameSettings.DEFAULTS["gameplay"]["crosshair"]))
	assert_null(GameSettings.get_value("nope", "missing"), "Unknown keys return null")


func test_rebinding_swaps_conflicts_and_resets() -> void:
	var jump_before := GameSettings.action_label("jump")
	var interact_ev := InputMap.action_get_events("interact")[0]
	var conflict := GameSettings.rebind("jump", interact_ev)
	assert_eq(conflict, "interact", "Binding jump to the interact key reports the conflict")
	assert_eq(GameSettings.action_label("jump"), GameSettings.event_label(interact_ev))
	assert_eq(GameSettings.action_label("interact"), jump_before, "Conflicting action receives the old binding (swap)")
	GameSettings.reset_bindings()
	assert_eq(GameSettings.action_label("jump"), jump_before, "Defaults restored")
	assert_true(InputMap.has_action("toggle_map"), "QoL map action registered")
	assert_true(InputMap.has_action("dismiss_hint"), "Rebindable hint-dismiss action registered")


func test_event_serialization_round_trip() -> void:
	var k := InputEventKey.new()
	k.physical_keycode = KEY_G
	var d := GameSettings.event_to_dict(k)
	var back := GameSettings.dict_to_event(d) as InputEventKey
	assert_eq(back.physical_keycode, KEY_G)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_RIGHT
	var md := GameSettings.event_to_dict(m)
	assert_eq((GameSettings.dict_to_event(md) as InputEventMouseButton).button_index, MOUSE_BUTTON_RIGHT)


func test_material_library_builds_every_material() -> void:
	var names := MaterialLibrary.material_names()
	assert_gt(names.size(), 40, "Material library should define the full PBR set")
	for n in names:
		var m := MaterialLibrary.get_material(str(n))
		assert_not_null(m, "Material %s builds" % n)
	var stone := MaterialLibrary.get_material("stone_block") as ORMMaterial3D
	assert_not_null(stone.albedo_texture, "Textured materials bind albedo")
	assert_not_null(stone.normal_texture, "Textured materials bind normal maps")
	assert_not_null(stone.orm_texture, "Textured materials bind ORM maps")
	assert_true(stone.vertex_color_use_as_albedo, "Baked vertex AO/tint multiplies albedo")
	var glass := MaterialLibrary.get_material("glass_red") as BaseMaterial3D
	assert_ne(glass.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "Glass is transparent")
	assert_true(MaterialLibrary.get_material("void_black") != null)


func test_models_bind_library_materials_by_name() -> void:
	var wall := ModelLoader.instantiate_model("res://assets/models/kit/wall_a.glb")
	add_child_autofree(wall)
	var found := false
	var stack: Array[Node] = [wall]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mesh := (n as MeshInstance3D).mesh
			for i in range(mesh.get_surface_count()):
				var mat := mesh.surface_get_material(i)
				if mat != null and mat == MaterialLibrary.get_material("stone_block"):
					found = true
	assert_true(found, "Kit wall surfaces must be bound to the shared stone_block material")
	assert_not_null(ModelLoader.load_mesh("res://assets/models/kit/floor_a.glb"), "Kit meshes load for MultiMesh batching")
