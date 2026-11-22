class_name PlayerController
extends CharacterBody3D
## Skyrim-Inspired 3D Player Controller (Phases 3, 5, 7, 8 + D-055 modular refactor).
## - First-person primary + instant Third-person over-the-shoulder toggle (V) (D-012)
## - Delegates 1st/3rd-person viewmodels, arm IK, weapon/bow/spell posing & blade trails to ViewmodelRig
## - Uses shared EntityStats, StatusComponent, and AbilityExecutor (D-051, D-055)
## - Crosshair raycast world interaction (E) & classic Skyrim menu time-pause support

const GEAR_DIR := ViewmodelRig.GEAR_DIR
const CROSS_GUARD_HOLD := 0.22

var player_cfg: Dictionary = {}
var camera_mode: String = "first_person"
var pitch_rad: float = 0.0
var god_mode: bool = false
var is_blocking: bool = false
var is_bow_drawing: bool = false
var bow_draw_time: float = 0.0
var right_attack_hold: float = 0.0
var is_right_holding: bool = false

# Shared unified stats, statuses, abilities & viewmodel rig (D-051, D-055)
var entity_stats: EntityStats = EntityStats.new()
var status_comp: StatusComponent = StatusComponent.new()
var ability_executor: AbilityExecutor = AbilityExecutor.new()
var viewmodel: ViewmodelRig = ViewmodelRig.new()

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

# Procedural animation state (read/driven by ViewmodelRig and animation tests/probes)
var _anim_time: float = 0.0
var _walk_bob_phase: float = 0.0
var _move_blend: float = 0.0
var _sprint_blend: float = 0.0
var _block_blend: float = 0.0
var _draw_blend: float = 0.0
var _bow_reach_blend: float = 0.0
var _bow_twang_t: float = 0.0
var _equip_raise: float = 0.0
var _look_sway: Vector2 = Vector2.ZERO
var _cam_swing_rot: Vector3 = Vector3.ZERO

var _right_swing_t: float = 0.0
var _right_swing_dur: float = 0.44
var _right_swing_power: bool = false
var _right_combo_step: int = 0
var _swing_was_charged: bool = false

var _left_action_t: float = 0.0
var _left_action_dur: float = 0.38
var _left_combo_step: int = 0
var _bow_release_recoil: float = 0.0
var _camera_kick: float = 0.0
var _slash_vfx_timer: float = 0.0
var _shield_hit_t: float = 0.0
var _last_right_attack_t: float = -10.0
var _last_left_attack_t: float = -10.0
var _hitstop: float = 0.0
var _shake: float = 0.0
var _shake_phase: float = 0.0
var _tp_action_lock: float = 0.0
var _tp_cast_right_t: float = -10.0
var _tp_cast_left_t: float = -10.0
var _tp_aim_blend: float = 0.0

var head_pivot: Node3D = null
var camera: Camera3D = null

# ViewmodelRig node accessors (preserving exact public & test-inspected attributes)
var fp_rig: Node3D:
	get: return viewmodel.fp_rig
var fp_right_anchor: Node3D:
	get: return viewmodel.fp_right_anchor
var fp_left_anchor: Node3D:
	get: return viewmodel.fp_left_anchor
var _fp_right_weapon_holder: Node3D:
	get: return viewmodel.fp_right_weapon_holder
var _fp_left_weapon_holder: Node3D:
	get: return viewmodel.fp_left_weapon_holder
var _fp_nocked_arrow: Node3D:
	get: return viewmodel.fp_nocked_arrow
var _fp_spell_node: Node3D:
	get: return viewmodel.fp_spell_node
var _slash_arc_mesh: MeshInstance3D:
	get: return viewmodel.slash_arc_mesh
var tp_mesh: Node3D:
	get: return viewmodel.tp_mesh
var tp_visual: CharacterVisual:
	get: return viewmodel.tp_visual

# D-049 item mastery runtime state
var _dash_t: float = 0.0
var _dash_vel: Vector3 = Vector3.ZERO
var _left_guard_pending: bool = false
var _left_guard_hold: float = 0.0
var is_cross_guarding: bool = false
var _frenzy_stacks: int = 0
var _frenzy_t: float = 0.0
var riposte_t: float = 0.0
var _second_wind_cd: float = 0.0
## FB-022 timed effects from potions, ingredients and the like: id -> {"id","name","t","duration","kind","params"}.
## Every numeric param is summed across effects: "speed", "slow", "armor", "hps", "magicka_regen", "stamina_regen".
var timed_effects: Dictionary = {}
var _status_peak: Dictionary = {}  ## FB-022: longest remaining time seen per StatusComponent entry (for countdown bars)
## FB-022 hotbar: HOTBAR_SIZE slots, each {} or {"kind": "gear", "uid", "id", "hand"} or {"kind": "stack", "id"}
const HOTBAR_SIZE := 8
var hotbar: Array = []

var _callbacks: Dictionary = {}
var _rng: SeededRng = null


func setup(p_cfg: Dictionary, p_prog: ProgressionSystem, p_rng: SeededRng, callbacks: Dictionary) -> void:
	player_cfg = p_cfg
	progression = p_prog
	_rng = p_rng
	_callbacks = callbacks
	entity_stats = EntityStats.from_player_cfg(player_cfg)
	status_comp = StatusComponent.new()
	ability_executor = AbilityExecutor.new()
	viewmodel = ViewmodelRig.new()

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

	viewmodel.build_nodes(self, camera)
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
			add_to_inventory(LootGenerator.make_base_item_instance(item_def, "bag_%s_%d" % [str(iid), inventory.size()]))
	timed_effects.clear()
	reset_hotbar()
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
	var aim_off: Array = cam_cfg.get("third_person_aim_offset", [1.0, 1.75, 2.1])
	var aim_local := Vector3(float(aim_off[0]), float(aim_off[1]) - float(player_cfg["movement"]["eye_height"]), float(aim_off[2]))
	desired_local = desired_local.lerp(aim_local, _tp_aim_blend)
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

	entity_stats.set_base("max_health", max_health)
	entity_stats.set_base("max_magicka", max_magicka)
	entity_stats.set_base("max_stamina", max_stamina)
	entity_stats.set_base("armor", float(stats["base_armor"]) + float(eq_totals["armor"]) + float(prog_bonuses.get("armor_bonus", 0.0)))
	entity_stats.set_base("cooldown_reduction", float(eq_totals["cooldown_reduction"]))

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
	var total := base + float(eq_totals["armor"]) + float(prog_bonuses.get("armor_bonus", 0.0)) + effect_sum("armor")
	return maxf(0.0, total - status_comp.armor_reduction())


func equip_from_inventory(inv_index: int, preferred_hand: String = "") -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var item: Dictionary = inventory[inv_index]
	if InventoryStacks.is_stackable(item):
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


## Repairs older saves: a ring stored under the old "ring" key moves to a real ring slot, legacy ids/rarities
## migrate cleanly, and every item inherits its current inherent rarity and mastery cap (D-060).
func normalize_equipment() -> void:
	for it in equipment.values() + inventory:
		var d := it as Dictionary
		if str(d.get("rarity", "")) == "sponsored":  # FB-014 retired rarity id (old saves only)
			d["rarity"] = "legendary"
		var nid := DataLoader.current_id(str(d.get("id", "")))
		var def := DataLoader.get_item_def(nid)
		if nid != str(d.get("id", "")):
			d["id"] = nid
			for k in ["name", "description", "model", "icon", "rarity"]:
				if def.has(k):
					d[k] = def[k]
		if not def.is_empty():
			var inh_r := str(def.get("rarity", "common"))
			var r_def := RarityTable.get_rarity({}, inh_r)
			d["rarity"] = inh_r
			d["rarity_label"] = str(r_def.get("label", inh_r.capitalize()))
			d["rarity_color"] = str(r_def.get("color", "#d8dce3"))
		if MasterySystem.is_masterable(d):
			var cap := MasterySystem.max_level_for(d)
			if int(d.get("mastery_level", 1)) > cap:
				d["mastery_level"] = cap
				d["mastery_xp"] = 0.0
		d.erase("affixes")
		for old_k in ["sponsored_effect", "sponsored_label"]:  # FB-022 old field names (old saves only)
			if d.has(old_k):
				var new_k: String = str(old_k).replace("sponsored", "legendary")
				d[new_k] = DataLoader.current_id(str(d[old_k])) if old_k == "sponsored_effect" else str(DataLoader.get_legendary_effect_def(str(d.get("legendary_effect", ""))).get("label", d[old_k]))
				d.erase(old_k)
	if equipment.has("ring"):
		var r: Dictionary = equipment["ring"]
		equipment.erase("ring")
		equipment["ring_2" if equipment.has("ring_1") and not equipment.has("ring_2") else "ring_1"] = r
	# FB-022: loose potions from older saves merge into stacks
	InventoryStacks.normalize(inventory)


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


## Puts an item in the bag; consumables and ingredients join their stack (FB-022). Returns the bag entry.
func add_to_inventory(item: Dictionary, n: int = 0) -> Dictionary:
	return InventoryStacks.add(inventory, item, n)


## Drinks / eats one from the stack at inv_index: restores vitals and starts its timed effect (FB-022).
func use_consumable(inv_index: int) -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var item: Dictionary = inventory[inv_index]
	if not InventoryStacks.is_stackable(item):
		return false
	health = minf(max_health, health + PowerScale.consumable_value(item, "heal_health"))
	magicka = minf(max_magicka, magicka + PowerScale.consumable_value(item, "heal_magicka"))
	stamina = minf(max_stamina, stamina + PowerScale.consumable_value(item, "heal_stamina"))
	var eff: Dictionary = item.get("effect", {})
	if not eff.is_empty():
		apply_timed_effect(eff, PowerScale.item(item))
	InventoryStacks.take(inventory, inv_index, 1)
	if EventBus != null:
		EventBus.sfx_requested.emit("spell_heal")
	emit_stats()
	return true


## Starts (or refreshes) a timed effect. Numeric params are scaled by `power` (except the duration).
func apply_timed_effect(eff: Dictionary, power: float = 1.0) -> void:
	var id := str(eff.get("id", "effect"))
	var params := {}
	for k in eff.keys():
		if k in ["id", "name", "duration", "kind"]:
			continue
		params[k] = float(eff[k]) * power if (typeof(eff[k]) == TYPE_FLOAT or typeof(eff[k]) == TYPE_INT) else eff[k]
	var dur := float(eff.get("duration", 10.0))
	var cur: Dictionary = timed_effects.get(id, {})
	timed_effects[id] = {"id": id, "name": str(eff.get("name", id.capitalize())), "kind": str(eff.get("kind", "buff")),
		"t": maxf(float(cur.get("t", 0.0)), dur), "duration": dur, "params": params}
	emit_stats()


## Sum of one numeric param across every active timed effect (e.g. "speed", "armor").
func effect_sum(key: String) -> float:
	var v := 0.0
	for e in timed_effects.values():
		v += float(e["params"].get(key, 0.0))
	return v


## FB-022: every temporary effect on the player, for the HUD's status list (buffs first, then debuffs, cooldowns).
## Each: {"id", "name", "remaining", "duration", "kind": "buff"/"debuff"/"cooldown", "stacks"}
func active_statuses() -> Array:
	var out: Array = []
	for e in timed_effects.values():
		out.append({"id": e["id"], "name": e["name"], "remaining": float(e["t"]), "duration": float(e["duration"]), "kind": e["kind"], "stacks": 0})
	var names := {"ward": ["Aegis Ward", "buff"], "regen": ["Renewal", "buff"], "haste": ["Hasted", "buff"], "enrage": ["Enraged", "buff"],
		"invulnerable": ["Invulnerable", "buff"], "slow": ["Slowed", "debuff"], "chill": ["Chilled", "debuff"], "root": ["Rooted", "debuff"],
		"burn": ["Burning", "debuff"], "bleed": ["Bleeding", "debuff"], "sunder": ["Sundered", "debuff"]}
	for k in names.keys():
		var en: Dictionary = status_comp.entries.get(k, {})
		if en.is_empty() or float(en.get("t", 0.0)) <= 0.0:
			_status_peak.erase(k)
			continue
		var t := float(en["t"])
		_status_peak[k] = maxf(float(_status_peak.get(k, 0.0)), t)
		out.append({"id": "slowed" if k == "slow" else ("renewal" if k == "regen" else k), "name": names[k][0], "remaining": t,
			"duration": float(_status_peak[k]), "kind": names[k][1], "stacks": 0})
	if status_comp.entries.has("poison"):
		var mt := 0.0
		for st in status_comp.entries["poison"]["stacks"]:
			mt = maxf(mt, float(st["t"]))
		_status_peak["poison"] = maxf(float(_status_peak.get("poison", 0.0)), mt)
		out.append({"id": "poison", "name": "Poisoned", "remaining": mt, "duration": float(_status_peak["poison"]), "kind": "debuff",
			"stacks": (status_comp.entries["poison"]["stacks"] as Array).size()})
	if status_comp.stun_t > 0.0:
		out.append({"id": "stun", "name": "Stunned", "remaining": status_comp.stun_t, "duration": maxf(status_comp.stun_t, 1.0), "kind": "debuff", "stacks": 0})
	if _frenzy_stacks > 0 and _frenzy_t > 0.0:
		out.append({"id": "frenzy", "name": "Frenzy", "remaining": _frenzy_t, "duration": 2.0, "kind": "buff", "stacks": _frenzy_stacks})
	if riposte_t > 0.0:
		out.append({"id": "riposte", "name": "Riposte Ready", "remaining": riposte_t, "duration": maxf(riposte_t, 2.0), "kind": "buff", "stacks": 0})
	if _second_wind_cd > 0.0:
		out.append({"id": "second_wind", "name": "Second Wind Recharging", "remaining": _second_wind_cd,
			"duration": maxf(_second_wind_cd, 60.0), "kind": "cooldown", "stacks": 0})
	var rank := {"buff": 0, "debuff": 1, "cooldown": 2}
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kind"] != b["kind"]:
			return int(rank.get(a["kind"], 3)) < int(rank.get(b["kind"], 3))
		return float(a["remaining"]) < float(b["remaining"]))
	return out


func quick_drink_health_potion() -> bool:
	for i in range(inventory.size()):
		if str(inventory[i].get("category", "")) == "consumable" and float(inventory[i].get("heal_health", 0.0)) > 0.0:
			return use_consumable(i)
	return false


# --- FB-022 Hotbar -----------------------------------------------------------------------------------------
## Default favourites: the starting weapons, spells and potions.
func reset_hotbar() -> void:
	hotbar.clear()
	hotbar.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar[i] = {}
	var order: Array = []
	for slot in ["right_hand", "left_hand"]:
		if equipment.has(slot):
			order.append(equipment[slot])
	for it in inventory:
		if not InventoryStacks.is_stackable(it) and str(it.get("category", "")) in ["weapon", "spell", "shield"]:
			order.append(it)
	for it in inventory:
		if InventoryStacks.is_stackable(it):
			order.append(it)
	for it in order:
		var free := hotbar.find({})
		if free < 0:
			break
		hotbar_assign(free, it)


## Puts an item on a hotbar slot (removing it from any other slot). Gear is remembered by its own instance,
## consumables by kind (the key keeps working while any of that stack is left).
func hotbar_assign(slot: int, item: Dictionary) -> bool:
	if slot < 0 or slot >= HOTBAR_SIZE or item.is_empty():
		return false
	if hotbar.size() != HOTBAR_SIZE:
		hotbar.resize(HOTBAR_SIZE)
		for i in range(HOTBAR_SIZE):
			if typeof(hotbar[i]) != TYPE_DICTIONARY:
				hotbar[i] = {}
	var cat := str(item.get("category", ""))
	var entry := {}
	if InventoryStacks.is_stackable(item):
		entry = {"kind": "stack", "id": str(item.get("id", ""))}
	elif cat in ["weapon", "spell", "shield"]:
		var hand := "left_hand" if cat == "shield" or (cat == "spell" and str(item.get("slot", "")) == "left_hand") else "right_hand"
		entry = {"kind": "gear", "uid": str(item.get("instance_id", "")), "id": str(item.get("id", "")), "hand": hand}
	else:
		return false
	for i in range(HOTBAR_SIZE):
		if _hotbar_same(hotbar[i], entry):
			hotbar[i] = {}
	hotbar[slot] = entry
	if EventBus != null:
		EventBus.equipment_changed.emit(equipment)
	return true


func hotbar_clear(slot: int) -> void:
	if slot >= 0 and slot < hotbar.size():
		hotbar[slot] = {}


func _hotbar_same(a: Variant, b: Dictionary) -> bool:
	if typeof(a) != TYPE_DICTIONARY or (a as Dictionary).is_empty():
		return false
	if str(a.get("kind", "")) != str(b.get("kind", "")):
		return false
	return str(a.get("uid", a.get("id", ""))) == str(b.get("uid", b.get("id", "")))


## The item a hotbar slot points at right now ({} when it is gone), plus where it is:
## {"item", "where": "equipped"/"bag", "index" (bag index or slot name), "count"}
func hotbar_item(slot: int) -> Dictionary:
	if slot < 0 or slot >= hotbar.size() or typeof(hotbar[slot]) != TYPE_DICTIONARY:
		return {}
	var e: Dictionary = hotbar[slot]
	if e.is_empty():
		return {}
	if str(e.get("kind", "")) == "stack":
		var n := InventoryStacks.total(inventory, str(e["id"]))
		var idx := InventoryStacks.find(inventory, str(e["id"]))
		var shown: Dictionary = inventory[idx] if idx >= 0 else DataLoader.get_item_def(str(e["id"]))
		return {"item": shown, "where": "bag", "index": idx, "count": n}
	var uid := str(e.get("uid", ""))
	for s in equipment.keys():
		if str(equipment[s].get("instance_id", "")) == uid:
			return {"item": equipment[s], "where": "equipped", "index": s, "count": 1}
	for i in range(inventory.size()):
		if str(inventory[i].get("instance_id", "")) == uid:
			return {"item": inventory[i], "where": "bag", "index": i, "count": 1}
	return {}


## What the HUD draws: one {"item", "count", "equipped"} per slot ({} for an empty / missing slot).
func hotbar_view() -> Array:
	var out: Array = []
	for i in range(HOTBAR_SIZE):
		var h := hotbar_item(i)
		out.append({} if h.is_empty() else {"item": h["item"], "count": int(h["count"]), "equipped": str(h["where"]) == "equipped",
			"stack": typeof(hotbar[i]) == TYPE_DICTIONARY and str(hotbar[i].get("kind", "")) == "stack"})
	return out


## Presses a hotbar key: equips that weapon / spell / shield, or drinks / eats one of that stack.
func use_hotbar(slot: int) -> bool:
	var h := hotbar_item(slot)
	if h.is_empty():
		return false
	var e: Dictionary = hotbar[slot]
	if str(e.get("kind", "")) == "stack":
		return int(h["count"]) > 0 and use_consumable(int(h["index"]))
	if str(h["where"]) == "equipped":
		return true  # already in hand
	var ok := equip_from_inventory(int(h["index"]), str(e.get("hand", "")))
	if ok and str(h["item"].get("weapon_type", "")) == "archery" and EventBus != null:
		EventBus.sfx_requested.emit("bow_draw")
	return ok


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
	entity_stats.tick(delta)
	ability_executor.tick(delta)
	_tick_mastery_timers(delta)
	var st_tick := status_comp.tick(delta, entity_stats)
	status_comp.tick_control(delta)

	var mov: Dictionary = player_cfg["movement"]
	var stats: Dictionary = player_cfg["stats"]

	var move_vec: Vector2 = input_override.get("move_vec", _read_move_input())
	var wants_sprint: bool = bool(input_override.get("sprint", Input.is_action_pressed("sprint")))
	var wants_jump: bool = bool(input_override.get("jump", Input.is_action_just_pressed("jump")))

	var lh: Dictionary = equipment.get("left_hand", {})
	var holding_left: bool = bool(input_override.get("left_held", Input.is_action_pressed("left_hand_action")))
	var holding_right: bool = bool(input_override.get("right_held", Input.is_action_pressed("right_hand_action")))
	var rh_eq: Dictionary = equipment.get("right_hand", {})
	var left_block := str(lh.get("category", "")) == "shield" and holding_left
	var right_block := str(rh_eq.get("category", "")) == "shield" and holding_right
	is_cross_guarding = false
	if _left_guard_pending:
		if holding_left:
			_left_guard_hold += delta
			is_cross_guarding = _left_guard_hold >= CROSS_GUARD_HOLD
		else:
			_left_guard_pending = false
			if _left_guard_hold < CROSS_GUARD_HOLD and not lh.is_empty():
				_perform_melee_attack(lh, false, false)
			_left_guard_hold = 0.0
	is_blocking = (left_block or right_block or is_cross_guarding) and stamina > 2.0

	var passives: Dictionary = LootGenerator.aggregate_equipment_stats(equipment).get("passives", {})
	var status_spd := status_comp.speed_mult() * (1.0 + effect_sum("speed")) * clampf(1.0 - effect_sum("slow"), 0.2, 1.0)
	var speed := float(mov["walk_speed"]) * (1.0 + float(passives.get("fleet", {}).get("speed", 0.0))) * status_spd
	var is_sprinting := false
	if is_blocking:
		speed *= float(mov["block_speed_multiplier"])
	elif is_bow_drawing:
		speed *= float(mov["bow_draw_speed_multiplier"])
	elif wants_sprint and move_vec.length_squared() > 0.05 and stamina > 1.0:
		speed = float(mov["sprint_speed"]) * (1.0 + float(passives.get("fleet", {}).get("speed", 0.0))) * status_spd
		stamina = maxf(0.0, stamina - float(mov["sprint_stamina_per_sec"]) * delta)
		_stamina_regen_delay = float(stats["regen_delay_after_spend_sec"])
		is_sprinting = true

	var world_dir := (global_transform.basis * Vector3(move_vec.x, 0.0, move_vec.y))
	world_dir.y = 0.0
	if world_dir.length_squared() > 0.001:
		world_dir = world_dir.normalized()
	velocity.x = world_dir.x * speed
	velocity.z = world_dir.z * speed
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity.x = _dash_vel.x
		velocity.z = _dash_vel.z

	if is_on_floor():
		if wants_jump and stamina >= float(mov["jump_stamina_cost"]):
			velocity.y = float(mov["jump_velocity"])
			stamina -= float(mov["jump_stamina_cost"])
			_stamina_regen_delay = float(stats["regen_delay_after_spend_sec"])
	else:
		velocity.y -= float(mov["gravity"]) * delta

	move_and_slide()

	# Passive Skyrim resource regeneration + status HoT/DoT (+ FB-022 timed effects)
	health = minf(max_health, health + (float(stats["health_regen_per_sec"]) + effect_sum("hps")) * delta + float(st_tick["heal"]))
	var dot := float(st_tick["dot_damage"])
	if dot > 0.0 and not god_mode and not status_comp.is_invulnerable():
		health = maxf(0.0, health - dot)
		if health <= 0.0 and EventBus != null:
			EventBus.player_died.emit()
	if _magicka_regen_delay <= 0.0:
		magicka = minf(max_magicka, magicka + (float(stats["magicka_regen_per_sec"]) + float(passives.get("arcane_flow", {}).get("magicka_regen", 0.0)) + effect_sum("magicka_regen")) * delta)
	if _stamina_regen_delay <= 0.0 and not is_blocking:
		stamina = minf(max_stamina, stamina + (float(stats["stamina_regen_per_sec"]) + float(passives.get("vigor", {}).get("stamina_regen", 0.0)) + effect_sum("stamina_regen")) * delta)

	if is_right_holding:
		right_attack_hold += delta
		var rh: Dictionary = equipment.get("right_hand", {})
		if str(rh.get("weapon_type", "")) == "archery":
			if not is_bow_drawing and tp_visual != null and tp_visual.visible and tp_visual.has_anim("bow_draw"):
				tp_visual.play_action("bow_draw", 0.1, 1.0)
			is_bow_drawing = true
			bow_draw_time = right_attack_hold * _draw_speed(rh)

	_update_procedural_animations(delta, move_vec.length(), is_sprinting)
	_tp_aim_blend = move_toward(_tp_aim_blend, 1.0 if is_bow_drawing else 0.0, delta * 4.0)
	if camera_mode == "third_person":
		_update_third_person_camera()
	_update_interaction_raycast()
	emit_stats()


func handle_hand_press(hand: String) -> void:
	if hand == "right_hand":
		is_right_holding = true
		right_attack_hold = 0.0
		var rh: Dictionary = equipment.get("right_hand", {})
		var rcat := str(rh.get("category", ""))
		if rcat == "spell":
			_cast_spell(rh, true)
			is_right_holding = false
		elif rcat == "shield" or rh.is_empty():
			is_right_holding = false
	elif hand == "left_hand":
		var lh: Dictionary = equipment.get("left_hand", {})
		if lh.is_empty():
			return
		var cat := str(lh.get("category", ""))
		if cat == "spell":
			_cast_spell(lh, false)
		elif cat == "weapon":
			if MasterySystem.has_ability(lh, "cross_guard") and str(equipment.get("right_hand", {}).get("category", "")) == "weapon":
				_left_guard_pending = true
				_left_guard_hold = 0.0
			else:
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
		_fire_bow(rh, hold * _draw_speed(rh))
	elif str(rh.get("category", "")) == "weapon":
		var is_power := hold >= float(player_cfg["combat"]["power_attack_hold_sec"])
		_perform_melee_attack(rh, true, is_power)


func trigger_interact() -> bool:
	var target := _raycast_interactable()
	if target != null:
		return target.trigger(self)
	return false


func take_damage(raw_damage: float) -> Dictionary:
	if god_mode or health <= 0.0 or status_comp.is_invulnerable():
		return {"final_damage": 0.0, "died": false, "was_blocked": false}

	var eq_totals := LootGenerator.aggregate_equipment_stats(equipment)
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
	var passives: Dictionary = eq_totals.get("passives", {})
	var dodge := float(passives.get("dodge", {}).get("chance", 0.0))
	if dodge > 0.0 and _rng != null and _rng.next_float("combat") < dodge:
		if EventBus != null:
			EventBus.sfx_requested.emit("sword_swing")
		return {"final_damage": 0.0, "died": false, "was_blocked": false, "dodged": true}
	raw_damage *= status_comp.damage_taken_mult()
	var block_bonus := float(eq_totals["block_bonus"]) + float(prog_bonuses.get("block_bonus", 0.0))
	var guard_item := blocking_item()
	if not guard_item.is_empty():
		block_bonus += float(MasterySystem.abilities(guard_item).get("bulwark", {}).get("block", 0.0))
		if is_cross_guarding:
			block_bonus = float(MasterySystem.abilities(guard_item).get("cross_guard", {}).get("block", 0.45)) \
				- float(player_cfg["combat"]["block_damage_reduction_base"])
	var res := CombatMath.resolve_attack({
		"base_damage": raw_damage,
		"crit_chance": 0.0,
		"target_armor": get_total_armor(),
		"target_blocking": is_blocking,
		"target_block_bonus": block_bonus,
	}, player_cfg, _rng)

	var dmg := float(res["final_damage"])
	if bool(res["was_blocked"]):
		stamina = maxf(0.0, stamina - float(res["block_stamina_cost"]))
		_stamina_regen_delay = float(player_cfg["stats"]["regen_delay_after_spend_sec"])
		_shield_hit_t = 0.16
		if str(equipment.get("left_hand", {}).get("category", "")) == "shield":
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
	if health > 0.0 and health < max_health * 0.3 and _second_wind_cd <= 0.0 and passives.has("second_wind"):
		var sw: Dictionary = passives["second_wind"]
		health = minf(max_health, health + float(sw.get("heal", 35.0)))
		_second_wind_cd = float(sw.get("cooldown", 60.0))
		if EventBus != null:
			EventBus.dungeon_ai_announcement.emit("SECOND WIND", "Your gear refuses to let you die here. +%d health." % int(sw.get("heal", 35.0)), "info")
	if bool(res["was_blocked"]) and not guard_item.is_empty() and MasterySystem.has_ability(guard_item, "riposte"):
		riposte_t = float(MasterySystem.abilities(guard_item)["riposte"].get("duration", 2.0))
	emit_stats()
	var died := health <= 0.0
	if died and EventBus != null:
		EventBus.player_died.emit()
	return {"final_damage": dmg, "died": died, "was_blocked": bool(res["was_blocked"])}


func _base_fov() -> float:
	if GameSettings != null:
		return float(GameSettings.get_value("graphics", "fov"))
	return float(player_cfg["camera"]["first_person_fov"])


func refresh_hand_visuals() -> void:
	viewmodel.refresh_equipment(equipment)
	_equip_raise = 1.0
	_bow_reach_blend = 0.0
	_bow_twang_t = 0.0
	_update_procedural_animations(0.016, 0.0, false)


func on_melee_hit(is_power: bool) -> void:
	_hitstop = 0.075 if is_power else 0.05
	add_shake(0.35 if is_power else 0.2)


func add_shake(amount: float) -> void:
	var k := 1.0
	if GameSettings != null:
		k = float(GameSettings.get_value("gameplay", "camera_shake"))
	_shake = maxf(_shake, amount * k)


func _update_procedural_animations(delta: float, move_amount: float, is_sprinting: bool) -> void:
	viewmodel.update_frame(self, delta, move_amount, is_sprinting)


func _tp_dual_wield() -> bool:
	var rh: Dictionary = equipment.get("right_hand", {})
	var lh: Dictionary = equipment.get("left_hand", {})
	return str(rh.get("category", "")) == "weapon" and str(lh.get("category", "")) == "weapon" \
		and str(rh.get("weapon_type", "")) != "archery" and not bool(rh.get("two_handed", false))


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
		"statuses": active_statuses(),
		"hotbar": hotbar_view(),
	})


func _count_health_potions() -> int:
	var n := 0
	for it in inventory:
		if str(it.get("category", "")) == "consumable" and float(it.get("heal_health", 0.0)) > 0.0:
			n += InventoryStacks.count(it)
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
	var cd := float(weapon.get("cooldown_sec", 0.55)) * (1.0 - float(eq_totals["cooldown_reduction"])) * (1.0 - _frenzy_haste(weapon))
	cd /= maxf(0.25, status_comp.attack_haste_mult())
	var is_two_hand := bool(weapon.get("two_handed", false))
	var w_abil := MasterySystem.abilities(weapon)
	var dash_dist := 0.0
	if is_power and w_abil.has("dash_strike"):
		dash_dist = float(w_abil["dash_strike"].get("distance", 3.5))
		var fwd := get_forward_vector()
		fwd.y = 0.0
		_dash_t = 0.2
		_dash_vel = fwd.normalized() * (dash_dist / 0.2)
	if tp_visual != null and tp_visual.visible:
		var tp_clip := "attack_2h" if (is_two_hand and tp_visual.has_anim("attack_2h")) else "attack"
		if not is_right and tp_visual.has_anim("attack_l"):
			tp_clip = "attack_l"
		elif is_right and _tp_dual_wield() and tp_visual.has_anim("attack_dual"):
			tp_clip = "attack_dual"
		tp_visual.play_action(tp_clip, 0.08, 1.15 if not is_power else 0.92)
	if is_right:
		_right_cooldown = cd
		_right_swing_power = is_power
		_swing_was_charged = is_power
		if is_power:
			_right_swing_dur = 0.68 if is_two_hand else 0.60
		else:
			_right_swing_dur = 0.58 if is_two_hand else 0.44
		_right_swing_t = _right_swing_dur
		if _anim_time - _last_right_attack_t > 1.2:
			_right_combo_step = 0
		_right_combo_step = (_right_combo_step + 1) % 2
		_last_right_attack_t = _anim_time
		_slash_vfx_timer = 0.16
		_camera_kick = 0.55 if is_power else 0.22
	else:
		_left_cooldown = cd
		_left_action_dur = 0.42
		_left_action_t = _left_action_dur
		if _anim_time - _last_left_attack_t > 1.2:
			_left_combo_step = 0
		_left_combo_step = (_left_combo_step + 1) % 2
		_last_left_attack_t = _anim_time

	if EventBus != null:
		EventBus.sfx_requested.emit("sword_swing")

	var cb: Callable = _callbacks.get("melee_swing", Callable())
	if cb.is_valid():
		var wtype := str(weapon.get("weapon_type", "one_handed"))
		var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
		var mult := ((progression.get_proficiency_damage_multiplier(wtype) if progression != null else 1.0) + float(prog_bonuses.get("damage_multiplier_bonus", 0.0))) * status_comp.damage_mult()
		cb.call({
			"weapon": weapon,
			"item": weapon,
			"abilities": w_abil,
			"dash_distance": dash_dist,
			"is_power_attack": is_power,
			"damage_multiplier": mult,
			"bonus_damage": float(eq_totals["bonus_damage"]),
			"crit_chance": float(player_cfg["stats"]["base_crit_chance"]) + float(eq_totals["bonus_crit_chance"])
				+ float(w_abil.get("keen_edge", {}).get("crit", 0.0)) + _consume_riposte(),
			"crit_multiplier": float(player_cfg["stats"]["base_crit_multiplier"]),
			"legendary_effects": eq_totals["legendary_effects"],
			"skill_name": wtype,
			"passives": eq_totals.get("passives", {}),
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
	_bow_twang_t = 0.32
	_draw_blend = 0.0
	_camera_kick = 0.32
	if tp_visual != null and tp_visual.visible and tp_visual.has_anim("bow_shoot"):
		tp_visual.play_action("bow_shoot", 0.05, 1.0)

	var ccfg: Dictionary = player_cfg["combat"]
	var speed := lerpf(float(ccfg["bow_arrow_speed_min"]), float(ccfg["bow_arrow_speed_max"]), ratio)
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
	var mult := ((progression.get_proficiency_damage_multiplier("archery") if progression != null else 1.0) + float(prog_bonuses.get("damage_multiplier_bonus", 0.0))) * status_comp.damage_mult()
	var b_abil := MasterySystem.abilities(bow)
	var dmg := (MasterySystem.stat(bow, "damage", 24.0) + float(eq_totals["bonus_damage"])) * mult * (0.45 + 0.55 * ratio)
	if ratio >= 1.0 and b_abil.has("power_shot"):
		dmg *= 1.0 + float(b_abil["power_shot"].get("bonus", 0.4))

	if EventBus != null:
		EventBus.sfx_requested.emit("bow_release")

	var cb: Callable = _callbacks.get("spawn_projectile", Callable())
	if cb.is_valid():
		var arrows := int(b_abil.get("multishot", {}).get("arrows", 1))
		var spread := deg_to_rad(float(b_abil.get("multishot", {}).get("spread", 5.0)))
		var crit := float(player_cfg["stats"]["base_crit_chance"]) + float(eq_totals["bonus_crit_chance"]) + _consume_riposte()
		for i in range(maxi(1, arrows)):
			var off := (float(i) - float(arrows - 1) * 0.5) * spread
			var dir := get_aim_direction().rotated(Vector3.UP, off)
			cb.call({
				"kind": "arrow",
				"origin": camera.global_position + dir * 0.8,
				"velocity": dir * speed,
				"gravity": 4.2,
				"damage": dmg,
				"crit_chance": crit,
				"crit_multiplier": float(player_cfg["stats"]["base_crit_multiplier"]),
				"from_player": true,
				"skill_name": "archery",
				"legendary_effects": eq_totals["legendary_effects"],
				"abilities": b_abil,
				"item_uid": str(bow.get("instance_id", "")),
				"full_draw": ratio >= 1.0,
				"pierce": int(b_abil.get("pierce", {}).get("count", 0)),
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
		_right_swing_dur = 0.38
		_right_swing_t = _right_swing_dur
		_right_swing_power = false
		_swing_was_charged = false
	else:
		_left_cooldown = cd
		_left_action_dur = 0.38
		_left_action_t = _left_action_dur
	_camera_kick = 0.24

	if tp_visual != null and tp_visual.visible:
		var clip := "cast_r" if is_right else "cast"
		var other_t := _tp_cast_left_t if is_right else _tp_cast_right_t
		if _anim_time - other_t < 0.25 and tp_visual.has_anim("cast_dual"):
			clip = "cast_dual"
		if is_right:
			_tp_cast_right_t = _anim_time
		else:
			_tp_cast_left_t = _anim_time
		if not tp_visual.has_anim(clip):
			clip = "cast"
		if clip != "cast_dual" or tp_visual.oneshot != "cast_dual":
			tp_visual.play_action(clip, 0.08, 1.15)
	var kind := str(spell.get("spell_kind", "projectile"))
	var skill_name := str(spell.get("weapon_type", "destruction"))
	var prog_bonuses := progression.get_derived_bonuses() if progression != null else {}
	var spell_mult := (progression.get_proficiency_damage_multiplier(skill_name) if progression != null else 1.0) + float(prog_bonuses.get("spell_multiplier_bonus", 0.0))

	var s_abil := MasterySystem.abilities(spell)
	if kind == "heal":
		var heal := MasterySystem.stat(spell, "heal_amount", 30.0) * spell_mult
		health = minf(max_health, health + heal)
		if s_abil.has("regen"):
			status_comp.apply("regen", s_abil["regen"], entity_stats)
		if s_abil.has("ward"):
			status_comp.apply("ward", s_abil["ward"], entity_stats)
		var mcb: Callable = _callbacks.get("item_used", Callable())
		if mcb.is_valid():
			mcb.call(spell, "cast")
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
		var count := int(s_abil.get("split", {}).get("count", 1))
		var spread := deg_to_rad(float(s_abil.get("split", {}).get("spread", 9.0)))
		var crit := float(player_cfg["stats"]["base_crit_chance"]) + float(eq_totals["bonus_crit_chance"]) + _consume_riposte()
		for i in range(maxi(1, count)):
			var off := (float(i) - float(count - 1) * 0.5) * spread
			var dir := get_aim_direction().rotated(Vector3.UP, off)
			cb.call({
				"kind": "spell",
				"color": str(spell.get("color", "#ff6a22")),
				"origin": camera.global_position + dir * 0.85,
				"velocity": dir * float(spell.get("projectile_speed", 26.0)),
				"gravity": 0.0,
				"damage": (MasterySystem.stat(spell, "damage", 22.0) + float(eq_totals["bonus_damage"]) * 0.5) * spell_mult,
				"crit_chance": crit,
				"crit_multiplier": float(player_cfg["stats"]["base_crit_multiplier"]),
				"from_player": true,
				"skill_name": skill_name,
				"splash_radius": float(spell.get("splash_radius", 0.0)),
				"chain_radius": float(spell.get("chain_radius", 0.0)),
				"legendary_effects": eq_totals["legendary_effects"],
				"abilities": s_abil,
				"item_uid": str(spell.get("instance_id", "")),
				"pierce": int(s_abil.get("pierce", {}).get("count", 0)),
				"homing": float(s_abil.get("homing", {}).get("turn", 0.0)),
			})


# --- Status & Mastery helpers ------------------------------------------------------------------

func apply_status(kind: String, params: Dictionary) -> void:
	status_comp.apply(kind, params, entity_stats)


func has_status(kind: String) -> bool:
	return status_comp.has(kind)


func _tick_mastery_timers(delta: float) -> void:
	_frenzy_t = maxf(0.0, _frenzy_t - delta)
	if _frenzy_t <= 0.0:
		_frenzy_stacks = 0
	riposte_t = maxf(0.0, riposte_t - delta)
	for id in timed_effects.keys():
		timed_effects[id]["t"] = float(timed_effects[id]["t"]) - delta
		if float(timed_effects[id]["t"]) <= 0.0:
			timed_effects.erase(id)
	_second_wind_cd = maxf(0.0, _second_wind_cd - delta)


func find_item_by_uid(uid: String) -> Dictionary:
	if uid.is_empty():
		return {}
	for slot in equipment.keys():
		var it: Dictionary = equipment[slot]
		if str(it.get("instance_id", "")) == uid:
			return it
	return {}


func blocking_item() -> Dictionary:
	if not is_blocking:
		return {}
	if is_cross_guarding:
		return equipment.get("left_hand", {})
	for h in ["left_hand", "right_hand"]:
		var it: Dictionary = equipment.get(h, {})
		if str(it.get("category", "")) == "shield":
			return it
	return {}


func apply_slow(amount: float, duration: float) -> void:
	status_comp.apply("slow", {"amount": amount, "duration": duration}, entity_stats)


func is_slowed() -> bool:
	return status_comp.has("slow") or status_comp.has("chill")


func _draw_speed(bow: Dictionary) -> float:
	var sp := 1.0 / maxf(0.3, float(bow.get("draw_time_mult", 1.0)))
	return sp * (1.0 + float(MasterySystem.abilities(bow).get("quick_draw", {}).get("speed", 0.0)))


func bullet_time_scale() -> float:
	if not is_bow_drawing:
		return 1.0
	var bow: Dictionary = equipment.get("right_hand", {})
	var bt: Dictionary = MasterySystem.abilities(bow).get("bullet_time", {})
	if bt.is_empty() or CombatMath.compute_bow_draw_ratio(bow_draw_time, player_cfg) < 1.0:
		return 1.0
	return float(bt.get("scale", 0.4))


func register_frenzy_hit(params: Dictionary) -> void:
	_frenzy_stacks = mini(int(params.get("stacks", 4)), _frenzy_stacks + 1)
	_frenzy_t = 2.0


func _frenzy_haste(weapon: Dictionary) -> float:
	var fr: Dictionary = MasterySystem.abilities(weapon).get("frenzy", {})
	var pas: Dictionary = LootGenerator.aggregate_equipment_stats(equipment).get("passives", {}).get("frenzy", {})
	var per := float(fr.get("haste", 0.0)) + float(pas.get("haste", 0.0))
	return clampf(per * float(_frenzy_stacks), 0.0, 0.5)


func _consume_riposte() -> float:
	if riposte_t > 0.0:
		riposte_t = 0.0
		return 1.0
	return 0.0


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
	var body := head_pivot.global_position if head_pivot != null else global_position
	var extra := from.distance_to(body) if camera_mode == "third_person" else 0.0
	var to := from + get_aim_direction() * (reach + extra)
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var col: Variant = hit.get("collider")
		if col is InteractableObject and not (col as InteractableObject).consumed \
				and (hit["position"] as Vector3).distance_to(body) <= reach + 0.9:
			return col as InteractableObject
	if camera_mode != "third_person":
		return null
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = reach
	sq.shape = sph
	sq.transform = Transform3D(Basis(), global_position + Vector3(0.0, 0.8, 0.0))
	sq.collision_mask = 2
	sq.exclude = [get_rid()]
	var fwd := get_forward_vector()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best: InteractableObject = null
	var best_d := INF
	for r in space.intersect_shape(sq, 16):
		var c: Variant = r.get("collider")
		if not (c is InteractableObject) or (c as InteractableObject).consumed:
			continue
		var d := (c as Node3D).global_position - global_position
		d.y = 0.0
		if d.length() > 0.05 and d.normalized().dot(fwd) < 0.2:
			continue
		if d.length() < best_d:
			best_d = d.length()
			best = c as InteractableObject
	return best


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
