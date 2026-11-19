class_name PlayerController
extends CharacterBody3D
## Skyrim-Inspired 3D Player Controller (Phases 3, 5, 7, 8 + Visual & Animation Overhaul).
## - First-person primary + instant Third-person over-the-shoulder toggle (V) (D-012)
## - Sculpted first-person armored gauntlets + compact lower-corner weapon/shield framing
## - Fluid multi-phase procedural animations: breathing sway, look-inertia, walk/sprint bob,
##   alternating diagonal melee combos, power attacks with slash trail, shield raise,
##   bow draw with nocked arrow & FOV zoom, and animated 3rd-person locomotion
## - Crosshair raycast world interaction (E) & classic Skyrim menu time-pause support

var player_cfg: Dictionary = {}
var camera_mode: String = "first_person"
var pitch_rad: float = 0.0
var god_mode: bool = false
var is_blocking: bool = false
var is_bow_drawing: bool = false
var bow_draw_time: float = 0.0
var right_attack_hold: float = 0.0
var is_right_holding: bool = false

# Live Vitals
var max_health: float = 120.0
var health: float = 120.0
var max_magicka: float = 100.0
var magicka: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0

var gold: int = 75
var equipment: Dictionary = {}
var inventory: Array[Dictionary] = []
var progression: ProgressionSystem = null

var _right_cooldown: float = 0.0
var _left_cooldown: float = 0.0
var _magicka_regen_delay: float = 0.0
var _stamina_regen_delay: float = 0.0
var _last_prompt: String = ""

# Procedural animation state
var _anim_time: float = 0.0
var _walk_bob_phase: float = 0.0
var _move_blend: float = 0.0
var _sprint_blend: float = 0.0
var _block_blend: float = 0.0
var _draw_blend: float = 0.0
var _look_sway: Vector2 = Vector2.ZERO

var _right_swing_t: float = 0.0
var _right_swing_dur: float = 0.34
var _right_swing_power: bool = false
var _right_combo_step: int = 0
var _left_action_t: float = 0.0
var _left_action_dur: float = 0.30
var _bow_release_recoil: float = 0.0
var _camera_kick: float = 0.0
var _slash_vfx_timer: float = 0.0

var head_pivot: Node3D = null
var camera: Camera3D = null
var fp_rig: Node3D = null
var fp_right_anchor: Node3D = null
var fp_left_anchor: Node3D = null
var _fp_right_weapon_holder: Node3D = null
var _fp_left_weapon_holder: Node3D = null
var _fp_nocked_arrow: Node3D = null
var _fp_spell_node: Node3D = null
var _slash_arc_mesh: MeshInstance3D = null
var tp_mesh: Node3D = null
var tp_visual: CharacterVisual = null
var _bow_node: Node3D = null
var _string_top: Node3D = null
var _string_bot: Node3D = null
var _string_tip_top: Vector3 = Vector3.ZERO
var _string_tip_bot: Vector3 = Vector3.ZERO
var _string_rest_z: float = 0.0
var _spell_fx: Node3D = null
var _spell_light: OmniLight3D = null
var _offhand_axe: bool = false
var _trail: MeshInstance3D = null
var _trail_pts: Array = []
var _blade_tip: Node3D = null
var _blade_base: Node3D = null
var _hitstop: float = 0.0
var _shake: float = 0.0
var _shake_phase: float = 0.0
var _tp_action_lock: float = 0.0

var _callbacks: Dictionary = {}
var _rng: SeededRng = null


func setup(p_cfg: Dictionary, p_prog: ProgressionSystem, p_rng: SeededRng, callbacks: Dictionary) -> void:
	player_cfg = p_cfg
	progression = p_prog
	_rng = p_rng
	_callbacks = callbacks
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1

	var mov: Dictionary = player_cfg["movement"]
	var cam_cfg: Dictionary = player_cfg["camera"]

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(mov["capsule_radius"])
	cap.height = float(mov["capsule_height"])
	col.shape = cap
	col.position.y = float(mov["capsule_height"]) * 0.5
	add_child(col)

	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, float(mov["eye_height"]), 0.0)
	add_child(head_pivot)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.near = 0.04
	camera.fov = float(cam_cfg["first_person_fov"])
	head_pivot.add_child(camera)

	# 1st-person dual-hand viewmodel rig
	fp_rig = Node3D.new()
	fp_rig.name = "FirstPersonHands"
	camera.add_child(fp_rig)

	fp_right_anchor = Node3D.new()
	fp_right_anchor.name = "RightHandAnchor"
	fp_rig.add_child(fp_right_anchor)

	fp_left_anchor = Node3D.new()
	fp_left_anchor.name = "LeftHandAnchor"
	fp_rig.add_child(fp_left_anchor)

	# Soft "presence" fill: keeps hands, weapons and nearby stone readable in dark corridors
	var fp_rim := OmniLight3D.new()
	fp_rim.name = "PlayerFill"
	fp_rim.position = Vector3(0.12, 0.22, 0.05)
	fp_rim.light_color = Color(1.0, 0.86, 0.7)
	fp_rim.light_energy = 0.35
	fp_rim.omni_range = 5.0
	fp_rim.omni_attenuation = 1.6
	fp_rim.light_specular = 0.25
	fp_rim.shadow_enabled = false
	fp_rim.light_volumetric_fog_energy = 0.0
	camera.add_child(fp_rim)

	_trail = MeshInstance3D.new()
	_trail.name = "BladeTrail"
	_trail.mesh = ImmediateMesh.new()
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.vertex_color_use_as_albedo = true
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.no_depth_test = false
	_trail.material_override = tm
	camera.add_child(_trail)

	# Sleek blade-edge golden-steel slash streak (attached dynamically to right weapon holder during swing!)
	_slash_arc_mesh = null

	# 3rd-person rigged & animated crawler (hidden in 1st-person)
	tp_visual = CharacterVisual.create("crawler")
	tp_visual.rotation.y = PI
	tp_mesh = tp_visual
	add_child(tp_visual)
	tp_visual.play_state("idle", 0.0)

	set_camera_mode(str(cam_cfg.get("default_mode", "first_person")))
	init_starting_loadout()


func init_starting_loadout() -> void:
	gold = int(player_cfg.get("starting_gold", 75))
	equipment.clear()
	inventory.clear()
	var start_eq: Dictionary = player_cfg.get("starting_equipment", {})
	for slot in start_eq.keys():
		var item_def := DataLoader.get_item_def(str(start_eq[slot]))
		if not item_def.is_empty():
			equipment[slot] = LootGenerator.make_base_item_instance(item_def, "start_%s" % str(item_def["id"]))
	for iid in player_cfg.get("starting_inventory", []):
		var item_def := DataLoader.get_item_def(str(iid))
		if not item_def.is_empty():
			inventory.append(LootGenerator.make_base_item_instance(item_def, "bag_%s_%d" % [str(iid), inventory.size()]))
	recalculate_vitals(true)
	refresh_hand_visuals()


func set_camera_mode(mode: String) -> void:
	camera_mode = "third_person" if mode == "third_person" else "first_person"
	var cam_cfg: Dictionary = player_cfg["camera"]
	if camera_mode == "first_person":
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		camera.fov = _base_fov()
		fp_rig.visible = true
		tp_mesh.visible = false
	else:
		camera.rotation = Vector3.ZERO
		camera.fov = float(cam_cfg["third_person_fov"])
		fp_rig.visible = false
		tp_mesh.visible = true
		_update_third_person_camera()
	if EventBus != null:
		EventBus.camera_mode_changed.emit(camera_mode)


func _update_third_person_camera() -> void:
	if camera == null or head_pivot == null or camera_mode != "third_person":
		return
	var cam_cfg: Dictionary = player_cfg["camera"]
	var off: Array = cam_cfg["third_person_offset"]
	var desired_local := Vector3(float(off[0]), float(off[1]) - float(player_cfg["movement"]["eye_height"]), float(off[2]))
	var resolved_local := desired_local
	if is_inside_tree() and get_world_3d() != null:
		var origin := head_pivot.global_position
		var target := head_pivot.to_global(desired_local)
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var total_dist := maxf(0.01, origin.distance_to(target))
			var safe_dist := maxf(0.55, origin.distance_to(hit_pos) - 0.30)
			resolved_local = desired_local * (safe_dist / total_dist)
	camera.position = resolved_local


func toggle_camera_mode() -> String:
	set_camera_mode("third_person" if camera_mode == "first_person" else "first_person")
	return camera_mode


func apply_mouse_look(relative: Vector2) -> void:
	var cam_cfg: Dictionary = player_cfg["camera"]
	var sens := float(cam_cfg["mouse_sensitivity"])
	var inv := 1.0
	if GameSettings != null:
		sens *= float(GameSettings.get_value("controls", "mouse_sensitivity"))
		inv = -1.0 if bool(GameSettings.get_value("controls", "invert_y")) else 1.0
	rotation.y -= relative.x * sens
	pitch_rad = clampf(
		pitch_rad - relative.y * sens * inv,
		deg_to_rad(float(cam_cfg["min_pitch_degrees"])),
		deg_to_rad(float(cam_cfg["max_pitch_degrees"]))
	)
	head_pivot.rotation.x = pitch_rad
	# Subtle Skyrim look-inertia weapon lag
	_look_sway.x = clampf(_look_sway.x - relative.x * 0.00055, -0.055, 0.055)
	_look_sway.y = clampf(_look_sway.y + relative.y * 0.00045, -0.045, 0.045)


func get_forward_vector() -> Vector3:
	return -global_transform.basis.z


func get_aim_direction() -> Vector3:
	return -camera.global_transform.basis.z.normalized()


func recalculate_vitals(refill_all: bool = false) -> void:
	var stats: Dictionary = player_cfg["stats"]
	var eq_totals := LootGenerator.aggregate_equipment_stats(equipment)
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}

	max_health = float(stats["base_max_health"]) + float(eq_totals["bonus_health"]) + float(prog_bonuses.get("health_bonus", 0.0))
	max_magicka = float(stats["base_max_magicka"]) + float(eq_totals["bonus_magicka"]) + float(prog_bonuses.get("magicka_bonus", 0.0))
	max_stamina = float(stats["base_max_stamina"]) + float(eq_totals["bonus_stamina"]) + float(prog_bonuses.get("stamina_bonus", 0.0))

	if refill_all:
		health = max_health
		magicka = max_magicka
		stamina = max_stamina
	else:
		health = minf(health, max_health)
		magicka = minf(magicka, max_magicka)
		stamina = minf(stamina, max_stamina)
	emit_stats()


func get_total_armor() -> float:
	var base := float(player_cfg["stats"]["base_armor"])
	var eq_totals := LootGenerator.aggregate_equipment_stats(equipment)
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
	return base + float(eq_totals["armor"]) + float(prog_bonuses.get("armor_bonus", 0.0))


func equip_from_inventory(inv_index: int, preferred_hand: String = "") -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var item: Dictionary = inventory[inv_index]
	if str(item.get("category", "")) == "consumable":
		return use_consumable(inv_index)

	var prev_eq := equipment.duplicate(true)
	var new_eq := CombatMath.equip_item_in_slots(equipment, item, preferred_hand)
	inventory.remove_at(inv_index)

	for slot in prev_eq.keys():
		if not new_eq.has(slot) or str(new_eq[slot].get("instance_id", "")) != str(prev_eq[slot].get("instance_id", "")):
			inventory.append(prev_eq[slot])

	equipment = new_eq
	recalculate_vitals(false)
	refresh_hand_visuals()
	if EventBus != null:
		EventBus.equipment_changed.emit(equipment)
	return true


## Moves an equipped item back into the bag (QoL: lets players strip a slot from the inventory screen).
func unequip_slot(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	var item: Dictionary = equipment[slot]
	equipment.erase(slot)
	inventory.append(item)
	recalculate_vitals(false)
	refresh_hand_visuals()
	if EventBus != null:
		EventBus.equipment_changed.emit(equipment)
	return true


func use_consumable(inv_index: int) -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var item: Dictionary = inventory[inv_index]
	if str(item.get("category", "")) != "consumable":
		return false
	health = minf(max_health, health + float(item.get("heal_health", 0.0)))
	magicka = minf(max_magicka, magicka + float(item.get("heal_magicka", 0.0)))
	inventory.remove_at(inv_index)
	if EventBus != null:
		EventBus.sfx_requested.emit("spell_heal")
	emit_stats()
	return true


func quick_drink_health_potion() -> bool:
	for i in range(inventory.size()):
		if float(inventory[i].get("heal_health", 0.0)) > 0.0:
			return use_consumable(i)
	return false


func quick_equip_preset(preset_num: int) -> void:
	match preset_num:
		1:
			_equip_by_id_if_owned("iron_longsword", "right_hand")
			_equip_by_id_if_owned("nordic_kite_shield", "left_hand")
		2:
			_equip_by_id_if_owned("iron_war_axe", "right_hand")
		3:
			_equip_by_id_if_owned("iron_longsword", "right_hand")
			_equip_by_id_if_owned("spell_firebolt", "left_hand")
		4:
			_equip_by_id_if_owned("hunting_bow", "right_hand")


func step_simulation(delta: float, is_paused: bool, input_override: Dictionary = {}) -> void:
	if is_paused:
		return

	_anim_time += delta
	_right_cooldown = maxf(0.0, _right_cooldown - delta)
	_left_cooldown = maxf(0.0, _left_cooldown - delta)
	_magicka_regen_delay = maxf(0.0, _magicka_regen_delay - delta)
	_stamina_regen_delay = maxf(0.0, _stamina_regen_delay - delta)

	var mov: Dictionary = player_cfg["movement"]
	var stats: Dictionary = player_cfg["stats"]

	var move_vec: Vector2 = input_override.get("move_vec", _read_move_input())
	var wants_sprint: bool = bool(input_override.get("sprint", Input.is_action_pressed("sprint")))
	var wants_jump: bool = bool(input_override.get("jump", Input.is_action_just_pressed("jump")))

	# Left-hand Shield Block tracking
	var lh: Dictionary = equipment.get("left_hand", {})
	var holding_left: bool = bool(input_override.get("left_held", Input.is_action_pressed("left_hand_action")))
	is_blocking = (not lh.is_empty() and str(lh.get("category", "")) == "shield" and holding_left and stamina > 2.0)

	var speed := float(mov["walk_speed"])
	var is_sprinting := false
	if is_blocking:
		speed *= float(mov["block_speed_multiplier"])
	elif is_bow_drawing:
		speed *= float(mov["bow_draw_speed_multiplier"])
	elif wants_sprint and move_vec.length_squared() > 0.05 and stamina > 1.0:
		speed = float(mov["sprint_speed"])
		stamina = maxf(0.0, stamina - float(mov["sprint_stamina_per_sec"]) * delta)
		_stamina_regen_delay = float(stats["regen_delay_after_spend_sec"])
		is_sprinting = true

	var world_dir := (global_transform.basis * Vector3(move_vec.x, 0.0, move_vec.y))
	world_dir.y = 0.0
	if world_dir.length_squared() > 0.001:
		world_dir = world_dir.normalized()
	velocity.x = world_dir.x * speed
	velocity.z = world_dir.z * speed

	if is_on_floor():
		if wants_jump and stamina >= float(mov["jump_stamina_cost"]):
			velocity.y = float(mov["jump_velocity"])
			stamina -= float(mov["jump_stamina_cost"])
			_stamina_regen_delay = float(stats["regen_delay_after_spend_sec"])
	else:
		velocity.y -= float(mov["gravity"]) * delta

	move_and_slide()

	# Passive Skyrim resource regeneration
	health = minf(max_health, health + float(stats["health_regen_per_sec"]) * delta)
	if _magicka_regen_delay <= 0.0:
		magicka = minf(max_magicka, magicka + float(stats["magicka_regen_per_sec"]) * delta)
	if _stamina_regen_delay <= 0.0 and not is_blocking:
		stamina = minf(max_stamina, stamina + float(stats["stamina_regen_per_sec"]) * delta)

	# Update right-hand hold (Power Attack wind-up or Bow Draw)
	if is_right_holding:
		right_attack_hold += delta
		var rh: Dictionary = equipment.get("right_hand", {})
		if str(rh.get("weapon_type", "")) == "archery":
			is_bow_drawing = true
			bow_draw_time = right_attack_hold

	_update_procedural_animations(delta, move_vec.length(), is_sprinting)
	if camera_mode == "third_person":
		_update_third_person_camera()
	_update_interaction_raycast()
	emit_stats()


func handle_hand_press(hand: String) -> void:
	if hand == "right_hand":
		is_right_holding = true
		right_attack_hold = 0.0
		var rh: Dictionary = equipment.get("right_hand", {})
		if str(rh.get("category", "")) == "spell":
			_cast_spell(rh, true)
			is_right_holding = false
	elif hand == "left_hand":
		var lh: Dictionary = equipment.get("left_hand", {})
		if lh.is_empty():
			return
		var cat := str(lh.get("category", ""))
		if cat == "spell":
			_cast_spell(lh, false)
		elif cat == "weapon":
			_perform_melee_attack(lh, false, false)


func handle_hand_release(hand: String) -> void:
	if hand != "right_hand" or not is_right_holding:
		return
	is_right_holding = false
	var hold := right_attack_hold
	right_attack_hold = 0.0
	is_bow_drawing = false
	bow_draw_time = 0.0

	var rh: Dictionary = equipment.get("right_hand", {})
	if rh.is_empty():
		return
	if str(rh.get("weapon_type", "")) == "archery":
		_fire_bow(rh, hold)
	elif str(rh.get("category", "")) == "weapon":
		var is_power := hold >= float(player_cfg["combat"]["power_attack_hold_sec"])
		_perform_melee_attack(rh, true, is_power)


func trigger_interact() -> bool:
	var target := _raycast_interactable()
	if target != null:
		return target.trigger(self)
	return false


func take_damage(raw_damage: float) -> Dictionary:
	if god_mode or health <= 0.0:
		return {"final_damage": 0.0, "died": false, "was_blocked": false}

	var eq_totals := LootGenerator.aggregate_equipment_stats(equipment)
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
	var res := CombatMath.resolve_attack({
		"base_damage": raw_damage,
		"crit_chance": 0.0,
		"target_armor": get_total_armor(),
		"target_blocking": is_blocking,
		"target_block_bonus": float(eq_totals["block_bonus"]) + float(prog_bonuses.get("block_bonus", 0.0)),
	}, player_cfg, _rng)

	var dmg := float(res["final_damage"])
	if bool(res["was_blocked"]):
		stamina = maxf(0.0, stamina - float(res["block_stamina_cost"]))
		_stamina_regen_delay = float(player_cfg["stats"]["regen_delay_after_spend_sec"])
		_left_action_t = 0.16
		_left_action_dur = 0.16
		_camera_kick = maxf(_camera_kick, 0.35)
		if progression != null:
			var s_res := progression.record_skill_use("block")
			_emit_progression_feedback("block", s_res)
		if EventBus != null:
			EventBus.sfx_requested.emit("shield_block")
	else:
		_camera_kick = maxf(_camera_kick, 0.85)
		add_shake(0.5)
		if tp_visual != null and tp_visual.visible:
			tp_visual.play_action("hit", 0.05)
		if EventBus != null:
			EventBus.sfx_requested.emit("sword_hit")
		var dmg_cb: Callable = _callbacks.get("player_damaged", Callable())
		if dmg_cb.is_valid():
			dmg_cb.call(dmg)

	health = maxf(0.0, health - dmg)
	emit_stats()
	var died := health <= 0.0
	if died and EventBus != null:
		EventBus.player_died.emit()
	return {"final_damage": dmg, "died": died, "was_blocked": bool(res["was_blocked"])}


const GEAR_DIR := "res://assets/models/gear/"


func _base_fov() -> float:
	if GameSettings != null:
		return float(GameSettings.get_value("graphics", "fov"))
	return float(player_cfg["camera"]["first_person_fov"])


func _arm(model_name: String) -> Node3D:
	var a := ModelLoader.instantiate_model(GEAR_DIR + model_name + ".glb", Vector3(0.12, 0.12, 0.4))
	a.name = "Arm"
	_disable_shadows(a)
	return a


func _disable_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_shadows(c)


func refresh_hand_visuals() -> void:
	for anchor in [fp_right_anchor, fp_left_anchor]:
		if anchor == null:
			continue
		for child in anchor.get_children():
			child.queue_free()
	_fp_right_weapon_holder = null
	_fp_left_weapon_holder = null
	_fp_nocked_arrow = null
	_fp_spell_node = null
	_slash_arc_mesh = null
	_bow_node = null
	_string_top = null
	_string_bot = null
	_spell_fx = null
	_spell_light = null
	_blade_tip = null
	_blade_base = null
	_offhand_axe = false
	if fp_right_anchor == null:
		return

	var rh: Dictionary = equipment.get("right_hand", {})
	var lh: Dictionary = equipment.get("left_hand", {})
	var is_bow := str(rh.get("weapon_type", "")) == "archery"
	var is_two_hand := bool(rh.get("two_handed", false)) and not is_bow

	# --- RIGHT HAND ---
	if not rh.is_empty():
		_fp_right_weapon_holder = Node3D.new()
		fp_right_anchor.add_child(_fp_right_weapon_holder)
		if str(rh.get("category", "")) == "spell":
			fp_right_anchor.add_child(_arm("fp_arm_open_r"))
			_attach_spell_fx(_fp_right_weapon_holder, rh)
		else:
			fp_right_anchor.add_child(_arm("fp_arm_grip_r"))
			if not is_bow:
				var w_model := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 0.9, 0.05))
				_disable_shadows(w_model)
				_fp_right_weapon_holder.add_child(w_model)
				var tip_len := 0.95 if is_two_hand else 0.9
				_blade_base = Node3D.new()
				_blade_base.position = Vector3(0, 0.62 if is_two_hand else 0.16, 0)
				_fp_right_weapon_holder.add_child(_blade_base)
				_blade_tip = Node3D.new()
				_blade_tip.position = Vector3(0, tip_len + (0.12 if is_two_hand else 0.0), 0)
				_fp_right_weapon_holder.add_child(_blade_tip)
				if is_two_hand:
					_offhand_axe = true

	# --- LEFT HAND ---
	if is_bow:
		_fp_left_weapon_holder = Node3D.new()
		fp_left_anchor.add_child(_fp_left_weapon_holder)
		fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
		_bow_node = ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 1.4, 0.1))
		_bow_node.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		_disable_shadows(_bow_node)
		_fp_left_weapon_holder.add_child(_bow_node)
		_string_top = _bow_node.find_child("StringTop*", true, false) as Node3D
		_string_bot = _bow_node.find_child("StringBottom*", true, false) as Node3D
		if _string_top != null and _string_bot != null:
			_string_tip_top = _string_top.position
			_string_tip_bot = _string_bot.position
			_string_rest_z = _string_tip_top.z
		_fp_nocked_arrow = ModelLoader.instantiate_model(GEAR_DIR + "arrow.glb", Vector3(0.02, 0.7, 0.02))
		_fp_nocked_arrow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_disable_shadows(_fp_nocked_arrow)
		fp_left_anchor.add_child(_fp_nocked_arrow)
	elif _offhand_axe:
		fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
	elif not lh.is_empty():
		_fp_left_weapon_holder = Node3D.new()
		fp_left_anchor.add_child(_fp_left_weapon_holder)
		var lcat := str(lh.get("category", ""))
		if lcat == "shield":
			fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
			var sh := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			sh.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			_disable_shadows(sh)
			_fp_left_weapon_holder.add_child(sh)
		elif lcat == "spell":
			fp_left_anchor.add_child(_arm("fp_arm_open_l"))
			_attach_spell_fx(_fp_left_weapon_holder, lh)
		else:
			fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
			var lw := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.05, 0.9, 0.05))
			_disable_shadows(lw)
			_fp_left_weapon_holder.add_child(lw)

	_refresh_tp_weapons()
	_update_procedural_animations(0.016, 0.0, false)


func _attach_spell_fx(holder: Node3D, spell: Dictionary) -> void:
	var col := Color.html(str(spell.get("color", "#ff6a22")))
	var fx := Node3D.new()
	fx.name = "SpellFx"
	fx.position = Vector3(0.0, 0.0, 0.0)
	holder.add_child(fx)
	var core := VfxFactory.make_glow(col.lightened(0.35), 0.16, 2.2)
	fx.add_child(core)
	var halo := VfxFactory.make_glow(col, 0.42, 1.0)
	fx.add_child(halo)
	var aura := VfxFactory.make_magic_aura(col, 0.07, 26)
	fx.add_child(aura)
	if str(spell.get("spell_kind", "projectile")) != "heal":
		var flames := VfxFactory.make_fire(0.22, false)
		flames.position = Vector3(0, -0.02, 0)
		fx.add_child(flames)
	_spell_light = OmniLight3D.new()
	_spell_light.light_color = col
	_spell_light.light_energy = 0.9
	_spell_light.omni_range = 3.6
	_spell_light.shadow_enabled = false
	fx.add_child(_spell_light)
	_spell_fx = fx
	_fp_spell_node = fx


## Third-person: weapons follow the animated crawler's hand sockets.
func _refresh_tp_weapons() -> void:
	if tp_visual == null or tp_visual.model == null:
		return
	for grip_name in ["GripR", "GripL"]:
		var g := tp_visual.model.find_child(grip_name + "*", true, false) as Node3D
		if g == null:
			continue
		for c in g.get_children():
			c.queue_free()
	var rh: Dictionary = equipment.get("right_hand", {})
	var lh: Dictionary = equipment.get("left_hand", {})
	var gr := tp_visual.model.find_child("GripR*", true, false) as Node3D
	var gl := tp_visual.model.find_child("GripL*", true, false) as Node3D
	var is_bow := str(rh.get("weapon_type", "")) == "archery"
	if gr != null and not rh.is_empty() and str(rh.get("category", "")) != "spell" and not is_bow:
		gr.add_child(ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 0.9, 0.05)))
	if gl != null:
		if is_bow:
			var b := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 1.4, 0.1))
			gl.add_child(b)
		elif not lh.is_empty() and str(lh.get("category", "")) == "shield":
			var sh := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			sh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			gl.add_child(sh)
		elif not lh.is_empty() and str(lh.get("category", "")) == "spell":
			gl.add_child(VfxFactory.make_glow(Color.html(str(lh.get("color", "#ff6a22"))), 0.3, 1.6))


## Called by GameMain when a melee swing connects: brief hit-stop + camera punch for weight.
func on_melee_hit(is_power: bool) -> void:
	_hitstop = 0.075 if is_power else 0.05
	add_shake(0.35 if is_power else 0.2)


func add_shake(amount: float) -> void:
	var k := 1.0
	if GameSettings != null:
		k = float(GameSettings.get_value("gameplay", "camera_shake"))
	_shake = maxf(_shake, amount * k)


func _update_procedural_animations(delta: float, move_amount: float, is_sprinting: bool) -> void:
	var dt := maxf(0.001, delta)
	# Hit-stop: freeze action timers for a few frames when a blow lands (weight & impact)
	var act_dt := dt
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - dt)
		act_dt = dt * 0.08
	_move_blend = lerpf(_move_blend, clampf(move_amount, 0.0, 1.0), clampf(dt * 10.0, 0.0, 1.0))
	_sprint_blend = lerpf(_sprint_blend, 1.0 if is_sprinting else 0.0, clampf(dt * 9.0, 0.0, 1.0))
	_block_blend = lerpf(_block_blend, 1.0 if is_blocking else 0.0, clampf(dt * 14.0, 0.0, 1.0))
	var target_draw := CombatMath.compute_bow_draw_ratio(bow_draw_time, player_cfg) if is_bow_drawing else 0.0
	_draw_blend = lerpf(_draw_blend, target_draw, clampf(dt * 12.0, 0.0, 1.0))
	_look_sway = _look_sway.lerp(Vector2.ZERO, clampf(dt * 9.0, 0.0, 1.0))
	_bow_release_recoil = maxf(0.0, _bow_release_recoil - dt * 5.0)
	_camera_kick = maxf(0.0, _camera_kick - dt * 4.5)
	_shake = maxf(0.0, _shake - dt * 3.2)
	_shake_phase += dt * 47.0
	if _move_blend > 0.04:
		_walk_bob_phase += dt * lerpf(7.6, 11.6, _sprint_blend)
	else:
		_walk_bob_phase = lerpf(_walk_bob_phase, 0.0, clampf(dt * 4.0, 0.0, 1.0))
	if _right_swing_t > 0.0:
		_right_swing_t = maxf(0.0, _right_swing_t - act_dt)
	if _left_action_t > 0.0:
		_left_action_t = maxf(0.0, _left_action_t - act_dt)
	if _slash_vfx_timer > 0.0:
		_slash_vfx_timer = maxf(0.0, _slash_vfx_timer - act_dt)

	var bob_k := 1.0
	if GameSettings != null:
		bob_k = float(GameSettings.get_value("gameplay", "head_bob"))
	if camera_mode == "first_person":
		var target_fov := _base_fov() + (_sprint_blend * 5.0) - (_draw_blend * 14.0)
		camera.fov = lerpf(camera.fov, target_fov, clampf(dt * 10.0, 0.0, 1.0))
		var head_bob_y := sin(_walk_bob_phase * 2.0) * 0.03 * _move_blend * (1.0 + _sprint_blend * 0.5) * bob_k
		var head_bob_x := cos(_walk_bob_phase) * 0.016 * _move_blend * bob_k
		var sh := Vector3(sin(_shake_phase * 1.3), sin(_shake_phase * 1.7 + 1.0), 0.0) * _shake * 0.035
		camera.position = Vector3(head_bob_x, head_bob_y, 0.0) + sh
		camera.rotation_degrees = Vector3(_camera_kick * 1.6 + sh.y * 30.0, sh.x * 20.0, -head_bob_x * 22.0 + sin(_shake_phase) * _shake * 1.5)

	var breathe_x := sin(_anim_time * 1.3) * 0.005
	var breathe_y := sin(_anim_time * 2.6) * 0.007
	var walk_x := cos(_walk_bob_phase) * 0.02 * _move_blend * bob_k
	var walk_y := absf(sin(_walk_bob_phase)) * -0.026 * _move_blend * bob_k
	fp_rig.position = Vector3(breathe_x + walk_x + _look_sway.x, breathe_y + walk_y + _look_sway.y - _sprint_blend * 0.035, 0.0)
	fp_rig.rotation_degrees = Vector3(_look_sway.y * 40.0, _look_sway.x * 50.0, -_look_sway.x * 30.0)

	var rh: Dictionary = equipment.get("right_hand", {})
	var lh: Dictionary = equipment.get("left_hand", {})
	var is_bow := str(rh.get("weapon_type", "")) == "archery"
	var is_two_hand := bool(rh.get("two_handed", false)) and not is_bow
	var r_spell := str(rh.get("category", "")) == "spell"

	# --- RIGHT HAND rest pose -------------------------------------------------------
	var r_pos := Vector3(0.30, -0.30, -0.50)
	var r_rot := Vector3(-22.0, -8.0, 16.0)
	if is_two_hand:
		r_pos = Vector3(0.24, -0.42, -0.46)
		r_rot = Vector3(-48.0, -26.0, 38.0)
	elif is_bow:
		r_pos = Vector3(0.24, -0.34, -0.42)
		r_rot = Vector3(-60.0, 10.0, 70.0)
	elif r_spell:
		r_pos = Vector3(0.28, -0.3, -0.5)
		r_rot = Vector3(-10.0, 10.0, 0.0)

	if is_right_holding and not is_bow and str(rh.get("category", "")) == "weapon":
		var charge := clampf(right_attack_hold / float(player_cfg["combat"]["power_attack_hold_sec"]), 0.0, 1.0)
		var ce := ease(charge, 0.6)
		r_pos += Vector3(0.06, 0.16, 0.12) * ce
		r_rot += Vector3(30.0, -16.0, -24.0) * ce
		r_pos += Vector3(sin(_anim_time * 40.0), cos(_anim_time * 37.0), 0) * 0.002 * ce

	if _right_swing_t > 0.0:
		var u := 1.0 - (_right_swing_t / maxf(0.01, _right_swing_dur))
		var sp := Vector3.ZERO
		var sr := Vector3.ZERO
		if r_spell:
			var pulse := sin(u * PI)
			sp = Vector3(-0.06, 0.04, -0.22) * pulse
			sr = Vector3(-20.0, 10.0, 0.0) * pulse
		elif _right_swing_power or is_two_hand:
			# Overhead cleave: big anticipation, fast chop, heavy follow-through
			var p0 := Vector3(0.06, 0.26, 0.14)
			var r0 := Vector3(52.0, -10.0, -30.0)
			var p1 := Vector3(-0.30, -0.22, -0.18)
			var r1 := Vector3(-70.0, 30.0, 40.0)
			if u < 0.3:
				var k := ease(u / 0.3, -1.8)
				sp = p0 * k
				sr = r0 * k
			elif u < 0.52:
				var k := ease((u - 0.3) / 0.22, 0.35)
				sp = p0.lerp(p1, k)
				sr = r0.lerp(r1, k)
			else:
				var k := ease((u - 0.52) / 0.48, -2.0)
				sp = p1.lerp(Vector3.ZERO, k)
				sr = r1.lerp(Vector3.ZERO, k)
		elif _right_combo_step % 2 == 0:
			# Forehand diagonal cut: right-high to left-low across the view
			var p0 := Vector3(0.14, 0.12, 0.06)
			var r0 := Vector3(18.0, -30.0, -38.0)
			var p1 := Vector3(-0.36, -0.16, -0.2)
			var r1 := Vector3(-48.0, 62.0, 72.0)
			if u < 0.24:
				var k := ease(u / 0.24, -1.6)
				sp = p0 * k
				sr = r0 * k
			elif u < 0.5:
				var k := ease((u - 0.24) / 0.26, 0.35)
				sp = p0.lerp(p1, k)
				sr = r0.lerp(r1, k)
			else:
				var k := ease((u - 0.5) / 0.5, -1.8)
				sp = p1.lerp(Vector3.ZERO, k)
				sr = r1.lerp(Vector3.ZERO, k)
		else:
			# Backhand riposte: left to right, rising
			var p0 := Vector3(-0.32, -0.04, 0.02)
			var r0 := Vector3(-10.0, 54.0, 64.0)
			var p1 := Vector3(0.22, 0.1, -0.22)
			var r1 := Vector3(-30.0, -48.0, -44.0)
			if u < 0.26:
				var k := ease(u / 0.26, -1.6)
				sp = p0 * k
				sr = r0 * k
			elif u < 0.52:
				var k := ease((u - 0.26) / 0.26, 0.35)
				sp = p0.lerp(p1, k)
				sr = r0.lerp(r1, k)
			else:
				var k := ease((u - 0.52) / 0.48, -1.8)
				sp = p1.lerp(Vector3.ZERO, k)
				sr = r1.lerp(Vector3.ZERO, k)
		r_pos += sp
		r_rot += sr

	r_pos += Vector3(-0.05, -0.1, 0.06) * _sprint_blend
	r_rot += Vector3(-22.0, 14.0, 20.0) * _sprint_blend
	r_pos.y += sin(_walk_bob_phase + 0.6) * 0.008 * _move_blend * bob_k

	# --- LEFT HAND ------------------------------------------------------------------
	var l_pos := Vector3(-0.36, -0.38, -0.56)
	var l_rot := Vector3(-6.0, 22.0, -6.0)
	var lcat := str(lh.get("category", ""))
	if is_bow:
		var recoil := Vector3(0.0, 0.015, 0.05) * _bow_release_recoil
		l_pos = Vector3(-0.2, -0.26, -0.56).lerp(Vector3(-0.1, -0.12, -0.6), _draw_blend) + recoil
		l_rot = Vector3(-4.0, 6.0, 26.0).lerp(Vector3(0.0, 0.0, 12.0), _draw_blend)
	elif _offhand_axe:
		pass
	elif lcat == "shield":
		var rest_p := Vector3(-0.42, -0.42, -0.58)
		var rest_r := Vector3(-4.0, 34.0, -10.0)
		var blk_p := Vector3(-0.2, -0.26, -0.46)
		var blk_r := Vector3(2.0, 8.0, -4.0)
		var be := ease(_block_blend, -1.6)
		l_pos = rest_p.lerp(blk_p, be)
		l_rot = rest_r.lerp(blk_r, be)
		if _left_action_t > 0.0:
			var imp := sin((_left_action_t / maxf(0.01, _left_action_dur)) * PI)
			l_pos += Vector3(0.0, -0.025, 0.1) * imp
			l_rot += Vector3(12.0, 8.0, 0.0) * imp
	elif lcat == "spell":
		l_pos = Vector3(-0.3, -0.3, -0.5)
		l_rot = Vector3(-8.0, -10.0, 0.0)
		if _left_action_t > 0.0:
			var u2 := 1.0 - (_left_action_t / maxf(0.01, _left_action_dur))
			var pulse := sin(u2 * PI)
			l_pos += Vector3(0.12, 0.06, -0.26) * pulse
			l_rot += Vector3(-16.0, -14.0, 8.0) * pulse
	elif not lh.is_empty():
		l_pos = Vector3(-0.32, -0.32, -0.52)
		l_rot = Vector3(-18.0, 10.0, -16.0)
		if _left_action_t > 0.0:
			var u3 := 1.0 - (_left_action_t / maxf(0.01, _left_action_dur))
			var pulse3 := sin(u3 * PI)
			l_pos += Vector3(0.32, 0.04, -0.24) * pulse3
			l_rot += Vector3(-52.0, -48.0, -34.0) * pulse3
	l_pos += Vector3(0.03, -0.08, 0.05) * _sprint_blend
	l_pos.y += sin(_walk_bob_phase + 2.2) * 0.008 * _move_blend * bob_k

	fp_right_anchor.position = r_pos
	fp_right_anchor.rotation_degrees = r_rot
	if _offhand_axe:
		# Left hand rides the haft above the right hand
		var hold := fp_right_anchor.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.42, 0.0))
		fp_left_anchor.transform = hold
	else:
		fp_left_anchor.position = l_pos
		fp_left_anchor.rotation_degrees = l_rot

	# --- Bowstring pull, nocked arrow & drawing hand ---------------------------------
	if is_bow and _bow_node != null:
		var pull := 0.5 * _draw_blend
		var nock_local := Vector3(0.0, 0.0, _string_rest_z - pull) if _string_top != null else Vector3.ZERO
		if _string_top != null and _string_bot != null:
			_aim_segment(_string_top, _string_tip_top, nock_local)
			_aim_segment(_string_bot, _string_tip_bot, nock_local)
		var nock_anchor := _fp_left_weapon_holder.transform * (_bow_node.transform * nock_local)
		if _fp_nocked_arrow != null:
			_fp_nocked_arrow.visible = _bow_release_recoil <= 0.15
			_fp_nocked_arrow.position = nock_anchor + Vector3(0.012, 0.012, -0.35)
		var nock_cam := fp_left_anchor.transform * nock_anchor
		var drawing_hand := nock_cam + Vector3(0.03, -0.02, 0.05)
		fp_right_anchor.position = r_pos.lerp(drawing_hand, clampf(_draw_blend * 1.6 + (0.35 if is_right_holding else 0.0), 0.0, 1.0))
		fp_right_anchor.rotation_degrees = r_rot.lerp(Vector3(-80.0, 0.0, 90.0), _draw_blend)

	# --- Spell glow breathing --------------------------------------------------------
	if _spell_fx != null and is_instance_valid(_spell_fx):
		var cast_pulse := 0.0
		if _left_action_t > 0.0 or _right_swing_t > 0.0:
			cast_pulse = 1.0
		_spell_fx.scale = Vector3.ONE * (1.0 + sin(_anim_time * 5.0) * 0.06 + cast_pulse * 0.35)
		if _spell_light != null:
			_spell_light.light_energy = 0.8 + sin(_anim_time * 7.3) * 0.12 + cast_pulse * 1.4

	_update_blade_trail()

	# --- 3RD-PERSON SKELETAL ANIMATION -----------------------------------------------
	if tp_visual != null and tp_visual.visible:
		_tp_action_lock = maxf(0.0, _tp_action_lock - dt)
		var st := "idle"
		if _move_blend > 0.15:
			st = "run" if _sprint_blend > 0.5 else "walk"
		elif is_blocking:
			st = "block"
		elif is_bow_drawing:
			st = "draw_hold"
		tp_visual.play_state(st, 0.18, 1.0 if st != "walk" else clampf(0.8 + _move_blend * 0.4, 0.8, 1.3))


func _aim_segment(seg: Node3D, tip: Vector3, target: Vector3) -> void:
	var d := target - tip
	var ln := d.length()
	if ln < 0.0005:
		return
	var y := d / ln
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	seg.transform = Transform3D(Basis(x, y * ln, z), tip)


func _update_blade_trail() -> void:
	var im := _trail.mesh as ImmediateMesh
	if im == null:
		return
	im.clear_surfaces()
	var swinging := _right_swing_t > 0.0 and _blade_tip != null and is_instance_valid(_blade_tip) and camera_mode == "first_person"
	if swinging:
		var inv := camera.global_transform.affine_inverse()
		var u := 1.0 - (_right_swing_t / maxf(0.01, _right_swing_dur))
		if u > 0.22 and u < 0.62:
			_trail_pts.push_front([inv * _blade_base.global_position, inv * _blade_tip.global_position])
	if not swinging or _trail_pts.size() > 9:
		if not _trail_pts.is_empty():
			_trail_pts.pop_back()
	if not swinging and _trail_pts.size() > 0:
		_trail_pts.pop_back()
	if _trail_pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trail_pts.size()
	for i in range(n):
		var a := 1.0 - float(i) / float(n - 1)
		var c := Color(1.0, 0.86, 0.6, 0.55 * a * a)
		var pair: Array = _trail_pts[i]
		im.surface_set_color(Color(c.r, c.g, c.b, c.a * 0.2))
		im.surface_add_vertex(pair[0])
		im.surface_set_color(c)
		im.surface_add_vertex(pair[1])
	im.surface_end()


func emit_stats() -> void:
	if EventBus == null:
		return
	EventBus.player_stats_changed.emit({
		"health": health,
		"max_health": max_health,
		"magicka": magicka,
		"max_magicka": max_magicka,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"armor": get_total_armor(),
		"gold": gold,
		"is_blocking": is_blocking,
		"bow_draw_ratio": CombatMath.compute_bow_draw_ratio(bow_draw_time, player_cfg) if is_bow_drawing else 0.0,
		"right_hand_name": str(equipment.get("right_hand", {}).get("name", "Empty")),
		"left_hand_name": str(equipment.get("left_hand", {}).get("name", "Empty")),
		"right_hand_item": equipment.get("right_hand", {}),
		"left_hand_item": equipment.get("left_hand", {}),
		"health_potions": _count_health_potions(),
	})


func _count_health_potions() -> int:
	var n := 0
	for it in inventory:
		if float(it.get("heal_health", 0.0)) > 0.0:
			n += 1
	return n


func _perform_melee_attack(weapon: Dictionary, is_right: bool, is_power: bool) -> void:
	if is_right and _right_cooldown > 0.0:
		return
	if not is_right and _left_cooldown > 0.0:
		return
	var stam_cost := float(weapon.get("stamina_cost", 12.0)) * (float(player_cfg["combat"]["power_attack_stamina_multiplier"]) if is_power else 1.0)
	if stamina < stam_cost * 0.5:
		return
	stamina = maxf(0.0, stamina - stam_cost)
	_stamina_regen_delay = float(player_cfg["stats"]["regen_delay_after_spend_sec"])

	var eq_totals := LootGenerator.aggregate_equipment_stats(equipment)
	var cd := float(weapon.get("cooldown_sec", 0.55)) * (1.0 - float(eq_totals["cooldown_reduction"]))
	if tp_visual != null and tp_visual.visible:
		tp_visual.play_action("attack", 0.08, 1.15 if not is_power else 0.95)
	if is_right:
		_right_cooldown = cd
		_right_swing_power = is_power
		_right_swing_dur = 0.5 if (is_power or bool(weapon.get("two_handed", false))) else 0.36
		_right_swing_t = _right_swing_dur
		_right_combo_step = (_right_combo_step + 1) % 2
		_slash_vfx_timer = 0.14
		_camera_kick = 0.55 if is_power else 0.22
	else:
		_left_cooldown = cd
		_left_action_dur = 0.30
		_left_action_t = _left_action_dur

	if EventBus != null:
		EventBus.sfx_requested.emit("sword_swing")

	var cb: Callable = _callbacks.get("melee_swing", Callable())
	if cb.is_valid():
		var wtype := str(weapon.get("weapon_type", "one_handed"))
		var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
		var mult := (progression.get_proficiency_damage_multiplier(wtype) if progression != null else 1.0) + float(prog_bonuses.get("damage_multiplier_bonus", 0.0))
		cb.call({
			"weapon": weapon,
			"is_power_attack": is_power,
			"damage_multiplier": mult,
			"bonus_damage": float(eq_totals["bonus_damage"]),
			"crit_chance": float(player_cfg["stats"]["base_crit_chance"]) + float(eq_totals["bonus_crit_chance"]),
			"crit_multiplier": float(player_cfg["stats"]["base_crit_multiplier"]),
			"sponsored_effects": eq_totals["sponsored_effects"],
			"skill_name": wtype,
		})


func _fire_bow(bow: Dictionary, hold_sec: float) -> void:
	if _right_cooldown > 0.0:
		return
	var ratio := CombatMath.compute_bow_draw_ratio(hold_sec, player_cfg)
	if ratio <= 0.0:
		ratio = 0.35
	var eq_totals := LootGenerator.aggregate_equipment_stats(equipment)
	_right_cooldown = float(bow.get("cooldown_sec", 0.45)) * (1.0 - float(eq_totals["cooldown_reduction"]))
	stamina = maxf(0.0, stamina - float(bow.get("stamina_cost", 10.0)))
	_stamina_regen_delay = float(player_cfg["stats"]["regen_delay_after_spend_sec"])
	_bow_release_recoil = 1.0
	_camera_kick = 0.32

	var ccfg: Dictionary = player_cfg["combat"]
	var speed := lerpf(float(ccfg["bow_arrow_speed_min"]), float(ccfg["bow_arrow_speed_max"]), ratio)
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
	var mult := (progression.get_proficiency_damage_multiplier("archery") if progression != null else 1.0) + float(prog_bonuses.get("damage_multiplier_bonus", 0.0))
	var dmg := (float(bow.get("damage", 24.0)) + float(eq_totals["bonus_damage"])) * mult * (0.45 + 0.55 * ratio)

	if EventBus != null:
		EventBus.sfx_requested.emit("bow_release")

	var cb: Callable = _callbacks.get("spawn_projectile", Callable())
	if cb.is_valid():
		cb.call({
			"kind": "arrow",
			"origin": camera.global_position + get_aim_direction() * 0.8,
			"velocity": get_aim_direction() * speed,
			"gravity": 4.2,
			"damage": dmg,
			"crit_chance": float(player_cfg["stats"]["base_crit_chance"]) + float(eq_totals["bonus_crit_chance"]),
			"crit_multiplier": float(player_cfg["stats"]["base_crit_multiplier"]),
			"from_player": true,
			"skill_name": "archery",
			"sponsored_effects": eq_totals["sponsored_effects"],
		})


func _cast_spell(spell: Dictionary, is_right: bool) -> void:
	if is_right and _right_cooldown > 0.0:
		return
	if not is_right and _left_cooldown > 0.0:
		return
	var cost := float(spell.get("magicka_cost", 18.0))
	if magicka < cost:
		return
	magicka -= cost
	_magicka_regen_delay = float(player_cfg["stats"]["regen_delay_after_spend_sec"])

	var eq_totals := LootGenerator.aggregate_equipment_stats(equipment)
	var cd := float(spell.get("cooldown_sec", 0.55)) * (1.0 - float(eq_totals["cooldown_reduction"]))
	if is_right:
		_right_cooldown = cd
		_right_swing_dur = 0.28
		_right_swing_t = _right_swing_dur
		_right_swing_power = false
	else:
		_left_cooldown = cd
		_left_action_dur = 0.28
		_left_action_t = _left_action_dur
	_camera_kick = 0.24

	if tp_visual != null and tp_visual.visible:
		tp_visual.play_action("cast", 0.08, 1.3)
	var kind := str(spell.get("spell_kind", "projectile"))
	var skill_name := str(spell.get("weapon_type", "destruction"))
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
	var spell_mult := (progression.get_proficiency_damage_multiplier(skill_name) if progression != null else 1.0) + float(prog_bonuses.get("spell_multiplier_bonus", 0.0))

	if kind == "heal":
		var heal := float(spell.get("heal_amount", 30.0)) * spell_mult
		health = minf(max_health, health + heal)
		if progression != null:
			_emit_progression_feedback("restoration", progression.record_skill_use("restoration"))
		if EventBus != null:
			EventBus.sfx_requested.emit("spell_heal")
		emit_stats()
		return

	if EventBus != null:
		EventBus.sfx_requested.emit("spell_fire")

	var cb: Callable = _callbacks.get("spawn_projectile", Callable())
	if cb.is_valid():
		cb.call({
			"kind": "spell",
			"color": str(spell.get("color", "#ff6a22")),
			"origin": camera.global_position + get_aim_direction() * 0.85,
			"velocity": get_aim_direction() * float(spell.get("projectile_speed", 26.0)),
			"gravity": 0.0,
			"damage": (float(spell.get("damage", 22.0)) + float(eq_totals["bonus_damage"]) * 0.5) * spell_mult,
			"crit_chance": float(player_cfg["stats"]["base_crit_chance"]) + float(eq_totals["bonus_crit_chance"]),
			"crit_multiplier": float(player_cfg["stats"]["base_crit_multiplier"]),
			"from_player": true,
			"skill_name": skill_name,
			"splash_radius": float(spell.get("splash_radius", 0.0)),
			"chain_radius": float(spell.get("chain_radius", 0.0)),
			"sponsored_effects": eq_totals["sponsored_effects"],
		})


func _equip_by_id_if_owned(item_id: String, hand: String) -> void:
	if str(equipment.get(hand, {}).get("id", "")) == item_id:
		return
	for i in range(inventory.size()):
		if str(inventory[i].get("id", "")) == item_id:
			equip_from_inventory(i, hand)
			return


func _read_move_input() -> Vector2:
	var x := 0.0
	var y := 0.0
	if Input.is_action_pressed("move_right"): x += 1.0
	if Input.is_action_pressed("move_left"): x -= 1.0
	if Input.is_action_pressed("move_backward"): y += 1.0
	if Input.is_action_pressed("move_forward"): y -= 1.0
	return Vector2(x, y)


func _raycast_interactable() -> InteractableObject:
	if camera == null or get_world_3d() == null:
		return null
	var reach := float(player_cfg["interaction"]["reach_meters"])
	var from := camera.global_position
	var to := from + get_aim_direction() * reach
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var col: Variant = hit.get("collider")
		if col is InteractableObject and not (col as InteractableObject).consumed:
			return col as InteractableObject
	return null


func _update_interaction_raycast() -> void:
	var inter := _raycast_interactable()
	var prompt := inter.get_prompt() if inter != null else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		if EventBus != null:
			EventBus.interaction_prompt_changed.emit(prompt)


func _emit_progression_feedback(skill_name: String, res: Dictionary) -> void:
	if EventBus == null:
		return
	if bool(res.get("skill_leveled_up", false)):
		EventBus.skill_improved.emit(skill_name, int(res["new_skill_level"]))
	for lvl in res.get("char_levels_gained", []):
		EventBus.level_up_occurred.emit(int(lvl))
