class_name PlayerController
extends CharacterBody3D
## Skyrim-Inspired 3D Player Controller (Phases 3, 5, 7, 8).
## - First-person primary + instant Third-person over-the-shoulder toggle (V) (D-012)
## - Left/Right-hand equipping: sword+shield, dual-wield, sword+spell, two-handed, bow (D-013)
## - Weighted melee swings, power attacks, directional shield blocking, stamina/magicka regen
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
var _swing_anim_timer: float = 0.0
var _last_prompt: String = ""

var head_pivot: Node3D = null
var camera: Camera3D = null
var fp_rig: Node3D = null
var fp_right_anchor: Node3D = null
var fp_left_anchor: Node3D = null
var tp_mesh: Node3D = null

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
	camera.fov = float(cam_cfg["first_person_fov"])
	head_pivot.add_child(camera)

	# 1st-person dual-hand viewmodel anchors
	fp_rig = Node3D.new()
	fp_rig.name = "FirstPersonHands"
	camera.add_child(fp_rig)

	fp_right_anchor = Node3D.new()
	fp_right_anchor.position = Vector3(0.42, -0.34, -0.68)
	fp_rig.add_child(fp_right_anchor)

	fp_left_anchor = Node3D.new()
	fp_left_anchor.position = Vector3(-0.44, -0.32, -0.64)
	fp_rig.add_child(fp_left_anchor)

	# 3rd-person Blender Crawler silhouette (hidden in 1st-person)
	tp_mesh = ModelLoader.instantiate_model("res://assets/models/batch3/player_crawler.glb", Vector3(0.7, 1.8, 0.5))
	tp_mesh.rotation.y = PI
	add_child(tp_mesh)

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
		camera.fov = float(cam_cfg["first_person_fov"])
		fp_rig.visible = true
		tp_mesh.visible = false
	else:
		var off: Array = cam_cfg["third_person_offset"]
		camera.position = Vector3(float(off[0]), float(off[1]) - float(player_cfg["movement"]["eye_height"]), float(off[2]))
		camera.fov = float(cam_cfg["third_person_fov"])
		fp_rig.visible = false
		tp_mesh.visible = true
	if EventBus != null:
		EventBus.camera_mode_changed.emit(camera_mode)


func toggle_camera_mode() -> String:
	set_camera_mode("third_person" if camera_mode == "first_person" else "first_person")
	return camera_mode


func apply_mouse_look(relative: Vector2) -> void:
	var cam_cfg: Dictionary = player_cfg["camera"]
	var sens := float(cam_cfg["mouse_sensitivity"])
	rotation.y -= relative.x * sens
	pitch_rad = clampf(
		pitch_rad - relative.y * sens,
		deg_to_rad(float(cam_cfg["min_pitch_degrees"])),
		deg_to_rad(float(cam_cfg["max_pitch_degrees"]))
	)
	head_pivot.rotation.x = pitch_rad


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

	# Return any displaced items to bag
	for slot in prev_eq.keys():
		if not new_eq.has(slot) or str(new_eq[slot].get("instance_id", "")) != str(prev_eq[slot].get("instance_id", "")):
			inventory.append(prev_eq[slot])

	equipment = new_eq
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

	_right_cooldown = maxf(0.0, _right_cooldown - delta)
	_left_cooldown = maxf(0.0, _left_cooldown - delta)
	_magicka_regen_delay = maxf(0.0, _magicka_regen_delay - delta)
	_stamina_regen_delay = maxf(0.0, _stamina_regen_delay - delta)

	if _swing_anim_timer > 0.0:
		_swing_anim_timer = maxf(0.0, _swing_anim_timer - delta)
		fp_right_anchor.rotation_degrees.x = -48.0 * (_swing_anim_timer / 0.22)
	else:
		fp_right_anchor.rotation_degrees.x = 0.0

	var mov: Dictionary = player_cfg["movement"]
	var stats: Dictionary = player_cfg["stats"]

	var move_vec: Vector2 = input_override.get("move_vec", _read_move_input())
	var wants_sprint: bool = bool(input_override.get("sprint", Input.is_action_pressed("sprint")))
	var wants_jump: bool = bool(input_override.get("jump", Input.is_action_just_pressed("jump")))

	# Left-hand Shield Block tracking
	var lh: Dictionary = equipment.get("left_hand", {})
	var holding_left: bool = bool(input_override.get("left_held", Input.is_action_pressed("left_hand_action")))
	is_blocking = (not lh.is_empty() and str(lh.get("category", "")) == "shield" and holding_left and stamina > 2.0)
	fp_left_anchor.position = Vector3(-0.24, -0.22, -0.52) if is_blocking else Vector3(-0.44, -0.32, -0.64)

	var speed := float(mov["walk_speed"])
	if is_blocking:
		speed *= float(mov["block_speed_multiplier"])
	elif is_bow_drawing:
		speed *= float(mov["bow_draw_speed_multiplier"])
	elif wants_sprint and move_vec.length_squared() > 0.05 and stamina > 1.0:
		speed = float(mov["sprint_speed"])
		stamina = maxf(0.0, stamina - float(mov["sprint_stamina_per_sec"]) * delta)
		_stamina_regen_delay = float(stats["regen_delay_after_spend_sec"])

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

	# Update right-hand hold (Power Attack or Bow Draw)
	if is_right_holding:
		right_attack_hold += delta
		var rh: Dictionary = equipment.get("right_hand", {})
		if str(rh.get("weapon_type", "")) == "archery":
			is_bow_drawing = true
			bow_draw_time = right_attack_hold

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
		if progression != null:
			var s_res := progression.record_skill_use("block")
			_emit_progression_feedback("block", s_res)
		if EventBus != null:
			EventBus.sfx_requested.emit("shield_block")
	else:
		if EventBus != null:
			EventBus.sfx_requested.emit("sword_hit")

	health = maxf(0.0, health - dmg)
	emit_stats()
	var died := health <= 0.0
	if died and EventBus != null:
		EventBus.player_died.emit()
	return {"final_damage": dmg, "died": died, "was_blocked": bool(res["was_blocked"])}


func refresh_hand_visuals() -> void:
	for anchor in [fp_right_anchor, fp_left_anchor]:
		if anchor == null:
			continue
		for child in anchor.get_children():
			child.queue_free()

	var rh: Dictionary = equipment.get("right_hand", {})
	if not rh.is_empty():
		var m := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.15, 0.7, 0.15))
		m.scale = Vector3.ONE * 0.65
		fp_right_anchor.add_child(m)

	var lh: Dictionary = equipment.get("left_hand", {})
	if not lh.is_empty():
		var m2 := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.35, 0.5, 0.15))
		m2.scale = Vector3.ONE * 0.65
		fp_left_anchor.add_child(m2)


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
	})


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
	if is_right:
		_right_cooldown = cd
	else:
		_left_cooldown = cd
	_swing_anim_timer = 0.22

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
	else:
		_left_cooldown = cd

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
