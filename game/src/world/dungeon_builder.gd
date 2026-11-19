class_name DungeonBuilder
extends Node3D
## 3D Procedural Nordic-Ruin Scene Builder (Phase 4 & Phase 6).
## Converts a DungeonGenerator.FloorLayout into playable 3D geometry using our Blender Batch 1 .glb kit,
## complete with solid wall/floor collision, torchlight atmosphere, Safe Room sanctuary,
## Boss Gate seal & Treasure Vault gate, chests, containers, traps, levers, and hidden staircase.

var layout: DungeonGenerator.FloorLayout = null
var boss_gate_node: StaticBody3D = null
var vault_gate_node: StaticBody3D = null
var boss_arena_sealed: bool = false
var vault_unlocked: bool = false
var traps_disarmed: bool = false

var _trap_nodes: Array[Node3D] = []
var _world_root: Node3D = null


func build_floor(
	p_layout: DungeonGenerator.FloorLayout,
	floor_cfg: Dictionary,
	interact_cb: Callable,
	rng: SeededRng
) -> void:
	clear_floor()
	layout = p_layout
	boss_arena_sealed = false
	vault_unlocked = false
	traps_disarmed = false
	_trap_nodes.clear()

	_world_root = Node3D.new()
	_world_root.name = "DungeonGeometry"
	add_child(_world_root)

	_setup_environment(floor_cfg)

	var ts := layout.tile_size
	var wall_h := float(DataLoader.get_world()["grid"]["wall_height_meters"])
	var torch_color := Color.html(str(floor_cfg.get("torch_color", "#ff9e4a")))
	var safe_color := Color.html(str(floor_cfg.get("safe_zone_color", "#6ce5c4")))
	var boss_color := Color.html(str(floor_cfg.get("boss_color", "#e04838")))

	# Single static body for fast floor/ceiling/wall collision
	var static_world := StaticBody3D.new()
	static_world.name = "WorldColliders"
	static_world.collision_layer = 1
	static_world.collision_mask = 1
	_world_root.add_child(static_world)

	var floor_visuals := Node3D.new()
	floor_visuals.name = "Tiles"
	_world_root.add_child(floor_visuals)

	var wall_dirs := [
		{"d": Vector2i(0, -1), "rot_y": 0.0, "off": Vector3(0.0, 0.0, -ts * 0.5)},
		{"d": Vector2i(0, 1), "rot_y": PI, "off": Vector3(0.0, 0.0, ts * 0.5)},
		{"d": Vector2i(-1, 0), "rot_y": PI * 0.5, "off": Vector3(-ts * 0.5, 0.0, 0.0)},
		{"d": Vector2i(1, 0), "rot_y": -PI * 0.5, "off": Vector3(ts * 0.5, 0.0, 0.0)},
	]

	var torch_count := 0
	for y in range(layout.height):
		for x in range(layout.width):
			var tile := layout.get_tile(x, y)
			if tile == DungeonGenerator.TILE_VOID:
				continue
			var pos := layout.tile_to_world(Vector2i(x, y))

			# Floor tile + floor collider
			var f_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/floor_tile.glb", Vector3(ts, 0.2, ts))
			f_mesh.position = pos
			floor_visuals.add_child(f_mesh)
			_add_box_collider(static_world, pos + Vector3(0.0, -0.25, 0.0), Vector3(ts, 0.5, ts))

			# Ceiling tile + ceiling collider
			var c_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/ceiling_tile.glb", Vector3(ts, 0.3, ts))
			c_mesh.position = pos + Vector3(0.0, wall_h, 0.0)
			floor_visuals.add_child(c_mesh)
			_add_box_collider(static_world, pos + Vector3(0.0, wall_h + 0.25, 0.0), Vector3(ts, 0.5, ts))

			# Perimeter Nordic walls wherever neighbor is void
			for wd in wall_dirs:
				var d: Vector2i = wd["d"]
				if not layout.is_walkable(x + d.x, y + d.y):
					var w_pos: Vector3 = pos + wd["off"]
					var rot_y: float = float(wd["rot_y"])
					var w_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/wall_segment.glb", Vector3(ts, wall_h, 0.55))
					w_mesh.position = w_pos
					w_mesh.rotation.y = rot_y
					floor_visuals.add_child(w_mesh)

					var col_size := Vector3(ts, wall_h, 0.65) if d.y != 0 else Vector3(0.65, wall_h, ts)
					_add_box_collider(static_world, w_pos + Vector3(0.0, wall_h * 0.5, 0.0), col_size)

					# Atmospheric wall torch sconces spaced cleanly
					if (x + y) % 5 == 0 and torch_count < 28 and rng.next_float("gen") < 0.45:
						var sconce := ModelLoader.instantiate_model("res://assets/models/batch1/torch_sconce.glb", Vector3(0.3, 0.8, 0.3))
						var inward := Vector3(-float(d.x), 0.0, -float(d.y)) * 0.35
						sconce.position = w_pos + inward + Vector3(0.0, 2.3, 0.0)
						sconce.rotation.y = rot_y
						floor_visuals.add_child(sconce)
						var light := OmniLight3D.new()
						light.position = w_pos + inward * 2.2 + Vector3(0.0, 2.8, 0.0)
						light.light_color = safe_color if tile == DungeonGenerator.TILE_SAFE_FLOOR else (boss_color if tile == DungeonGenerator.TILE_BOSS_FLOOR else torch_color)
						light.light_energy = 2.6
						light.omni_range = 12.0
						floor_visuals.add_child(light)
						torch_count += 1

	# Room centerpieces & special rooms
	for room in layout.rooms:
		var role := str(room["role"])
		var rect: Rect2i = room["rect"]
		var center_w := layout.tile_to_world(room["center"])

		# Corner Nordic pillars in larger rooms
		if rect.size.x >= 5 and rect.size.y >= 5:
			for px in [rect.position.x + 1, rect.end.x - 2]:
				for py in [rect.position.y + 1, rect.end.y - 2]:
					var pil_pos := layout.tile_to_world(Vector2i(px, py))
					var pil := ModelLoader.instantiate_model("res://assets/models/batch1/pillar.glb", Vector3(1.0, wall_h, 1.0))
					pil.position = pil_pos
					floor_visuals.add_child(pil)
					_add_box_collider(static_world, pil_pos + Vector3(0.0, wall_h * 0.5, 0.0), Vector3(0.95, wall_h, 0.95))

		if role == "safe":
			_build_safe_room_props(center_w, safe_color, interact_cb)
		elif role == "stairs":
			_build_stairs_interactable(center_w, interact_cb)
		elif role == "boss":
			var b_light := OmniLight3D.new()
			b_light.position = center_w + Vector3(0.0, 3.6, 0.0)
			b_light.light_color = boss_color
			b_light.light_energy = 3.8
			b_light.omni_range = 18.0
			_world_root.add_child(b_light)
		elif role == "entrance":
			var e_light := OmniLight3D.new()
			e_light.position = center_w + Vector3(0.0, 3.4, 0.0)
			e_light.light_color = torch_color
			e_light.light_energy = 3.2
			e_light.omni_range = 14.0
			_world_root.add_child(e_light)

	# Boss Gate (open initially, slams shut when player enters Boss Arena)
	boss_gate_node = _build_gate(layout.boss_gate_tile, "BossGate", false)
	# Treasure Vault Gate (sealed initially, opens when Boss dies!)
	vault_gate_node = _build_gate(layout.vault_gate_tile, "VaultGate", true)

	# Chests
	for idx in range(layout.chests.size()):
		var c: Dictionary = layout.chests[idx]
		var wpos := layout.tile_to_world(c["tile"])
		var tier := str(c.get("tier", "standard"))
		var label := "Open Vault Treasure Chest" if tier == "vault_sponsored" else "Open Nordic Chest"
		var inter := InteractableObject.new()
		inter.setup("chest_%d" % idx, "chest", label, c, interact_cb, Vector3(1.3, 1.0, 0.9))
		inter.position = wpos
		var mesh := ModelLoader.instantiate_model("res://assets/models/batch1/chest.glb", Vector3(1.1, 0.8, 0.7))
		inter.add_child(mesh)
		_world_root.add_child(inter)

	# Crates & Urns
	for idx in range(layout.containers.size()):
		var cont: Dictionary = layout.containers[idx]
		var kind := str(cont.get("kind", "crate"))
		var wpos := layout.tile_to_world(cont["tile"]) + Vector3(-1.1, 0.0, -1.1)
		var inter := InteractableObject.new()
		inter.setup("cont_%d" % idx, kind, "Search %s" % kind.capitalize(), cont, interact_cb, Vector3(0.95, 1.0, 0.95))
		inter.position = wpos
		var mpath := "res://assets/models/batch1/crate.glb" if kind == "crate" else "res://assets/models/batch1/urn.glb"
		inter.add_child(ModelLoader.instantiate_model(mpath, Vector3(0.9, 0.9, 0.9)))
		_world_root.add_child(inter)

	# Spike Traps + Disarm Lever
	for idx in range(layout.traps.size()):
		var t_pos := layout.tile_to_world(layout.traps[idx])
		var trap_mesh := ModelLoader.instantiate_model("res://assets/models/batch1/spike_trap.glb", Vector3(1.8, 0.4, 1.8))
		trap_mesh.position = t_pos
		_world_root.add_child(trap_mesh)
		_trap_nodes.append(trap_mesh)

		if idx == 0:
			var lever := InteractableObject.new()
			lever.setup("trap_lever", "lever", "Pull Trap Disarm Lever", {}, interact_cb, Vector3(0.8, 1.5, 0.8))
			lever.position = t_pos + Vector3(1.5, 0.0, 0.0)
			lever.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/lever.glb", Vector3(0.6, 1.5, 0.6)))
			_world_root.add_child(lever)


func seal_boss_arena() -> void:
	if boss_arena_sealed or boss_gate_node == null:
		return
	boss_arena_sealed = true
	_set_gate_closed(boss_gate_node, true)


func unlock_boss_and_vault() -> void:
	boss_arena_sealed = false
	vault_unlocked = true
	if boss_gate_node != null:
		_set_gate_closed(boss_gate_node, false)
	if vault_gate_node != null:
		_set_gate_closed(vault_gate_node, false)


func disarm_traps() -> void:
	traps_disarmed = true
	for tn in _trap_nodes:
		if is_instance_valid(tn):
			tn.position.y = -0.38


func is_player_on_active_trap(player_pos: Vector3) -> bool:
	if traps_disarmed or layout == null:
		return false
	for t in layout.traps:
		var tp := layout.tile_to_world(t)
		if Vector2(tp.x - player_pos.x, tp.z - player_pos.z).length() <= 1.05:
			return true
	return false


func clear_floor() -> void:
	if _world_root != null and is_instance_valid(_world_root):
		_world_root.queue_free()
	_world_root = null
	boss_gate_node = null
	vault_gate_node = null
	_trap_nodes.clear()


func _build_safe_room_props(center_w: Vector3, safe_color: Color, interact_cb: Callable) -> void:
	var light := OmniLight3D.new()
	light.position = center_w + Vector3(0.0, 3.5, 0.0)
	light.light_color = safe_color
	light.light_energy = 4.2
	light.omni_range = 18.0
	_world_root.add_child(light)

	# Vendor Stall + Friendly Vendor NPC
	var vendor := InteractableObject.new()
	vendor.setup("safe_vendor", "vendor", "Trade with Safe Room Merchant", {}, interact_cb, Vector3(2.6, 2.2, 1.4))
	vendor.position = center_w + Vector3(-2.4, 0.0, -1.8)
	vendor.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/vendor_stall.glb", Vector3(2.4, 2.5, 1.2)))
	var npc := ModelLoader.instantiate_model("res://assets/models/batch3/vendor_npc.glb", Vector3(0.8, 1.8, 0.8))
	npc.position = Vector3(0.0, 0.0, 0.85)
	vendor.add_child(npc)
	_world_root.add_child(vendor)

	# Safe Room Quest Board
	var qboard := InteractableObject.new()
	qboard.setup("safe_quest_board", "quest_board", "Inspect Syndicate Quest Board", {}, interact_cb, Vector3(1.9, 2.2, 0.8))
	qboard.position = center_w + Vector3(2.6, 0.0, -1.8)
	qboard.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/quest_board.glb", Vector3(1.8, 2.2, 0.4)))
	_world_root.add_child(qboard)


func _build_stairs_interactable(center_w: Vector3, interact_cb: Callable) -> void:
	# D-008: Strictly NO next-floor preview text!
	var stairs := InteractableObject.new()
	stairs.setup("hidden_stairs", "stairs", "Descend Stairwell to Next Floor", {}, interact_cb, Vector3(3.4, 2.0, 3.4))
	stairs.position = center_w
	stairs.add_child(ModelLoader.instantiate_model("res://assets/models/batch1/stairs_down.glb", Vector3(3.6, 1.2, 3.6)))
	_world_root.add_child(stairs)

	var glow := OmniLight3D.new()
	glow.position = center_w + Vector3(0.0, 2.2, 0.0)
	glow.light_color = Color(0.25, 0.85, 1.0)
	glow.light_energy = 3.2
	glow.omni_range = 12.0
	_world_root.add_child(glow)


func _build_gate(tile: Vector2i, gate_name: String, closed_initially: bool) -> StaticBody3D:
	var gate := StaticBody3D.new()
	gate.name = gate_name
	var wpos := layout.tile_to_world(tile)
	gate.position = wpos
	# Orient perpendicular to open corridor passage
	var left_open := layout.is_walkable(tile.x - 1, tile.y)
	var right_open := layout.is_walkable(tile.x + 1, tile.y)
	if left_open and right_open:
		gate.rotation.y = PI * 0.5

	var mesh := ModelLoader.instantiate_model("res://assets/models/batch1/boss_gate.glb", Vector3(3.6, 3.8, 0.4))
	mesh.name = "GateVisual"
	gate.add_child(mesh)

	var col := CollisionShape3D.new()
	col.name = "GateCollider"
	var box := BoxShape3D.new()
	box.size = Vector3(3.8, 4.0, 0.55)
	col.shape = box
	col.position.y = 2.0
	gate.add_child(col)

	_world_root.add_child(gate)
	_set_gate_closed(gate, closed_initially)
	return gate


func _set_gate_closed(gate: StaticBody3D, closed: bool) -> void:
	var visual := gate.get_node_or_null("GateVisual") as Node3D
	var col := gate.get_node_or_null("GateCollider") as CollisionShape3D
	if visual != null:
		visual.position.y = 0.0 if closed else 3.9
	if col != null:
		col.disabled = not closed


func _setup_environment(floor_cfg: Dictionary) -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html(str(floor_cfg.get("fog_color", "#11151d")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html(str(floor_cfg.get("ambient_color", "#1a1f28")))
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color.html(str(floor_cfg.get("fog_color", "#11151d")))
	env.fog_density = float(floor_cfg.get("fog_density", 0.014))
	env_node.environment = env
	_world_root.add_child(env_node)


static func _add_box_collider(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	body.add_child(col)
