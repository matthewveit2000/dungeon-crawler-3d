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
var _tp_bow_node: Node3D = null
var _tp_string_top: Node3D = null
var _tp_string_bot: Node3D = null
var _tp_string_tip_top: Vector3 = Vector3.ZERO
var _tp_string_tip_bot: Vector3 = Vector3.ZERO
var _tp_string_rest_z: float = 0.0
var _tp_nocked_arrow: Node3D = null
var _tp_grip_r: Node3D = null
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
const TRAIL_LIFE := 0.095
var _swing_start_key: Array = []
var _shield_hit_t: float = 0.0  ## block impact recoil timer (either hand's shield)
var _last_right_attack_t: float = -10.0
var _last_left_attack_t: float = -10.0
var _fp_upper_r: Node3D = null
var _fp_upper_l: Node3D = null
var _elbow_local_r: Vector3 = Vector3.ZERO  ## where this hand's forearm mesh ends (ZERO = no arm shown)
var _elbow_local_l: Vector3 = Vector3.ZERO
var _right_single_edge: bool = false
var _left_single_edge: bool = false

# ---------------------------------------------------------------------------
# First-person pose library (D-040)
# Rig space = camera space: +X right, +Y up, -Z forward into the world.
# A weapon key is [fist position, blade/haft direction out of the fist, cutting-edge direction]. The edge
# direction is where the cut travels: the weapon is rolled in the fist so its edge always leads, while the
# forearm's roll comes from a 2-bone arm solve toward the shoulder, so wrists never twist unnaturally.
# Spell keys are [palm position, palm-facing direction, finger direction]. Bow keys are
# [bow-hand position, bow limb axis, direction the back of the bow faces].
# ---------------------------------------------------------------------------
const FP_SHOULDER := Vector3(0.20, -0.30, 0.12)
const FP_ELBOW_POLE := Vector3(0.6, -1.0, 0.15)
const FP_UPPER_ARM := 0.31
const FP_FOREARM := 0.30
## End of the forearm meshes (anchor space), where the upper-arm sleeve tucks in
const FP_ELBOW_GRIP := Vector3(0.03, -0.141, 0.271)
const FP_ELBOW_OPEN := Vector3(0.0, -0.097, 0.226)

# One-handed blade (right hand; the off-hand uses the mirror image)
## FB-014 standing rule: blades face away from the player — at rest and sprinting the cutting edge points forward
const FP_SWORD_REST := [Vector3(0.27, -0.29, -0.50), Vector3(-0.10, 0.88, -0.46), Vector3(0.0, 0.46, -0.88)]
const FP_SWORD_SPRINT := [Vector3(0.24, -0.38, -0.44), Vector3(0.30, 0.55, -0.78), Vector3(0.0, 0.82, 0.58)]
## Forehand: cocked over the right shoulder -> cuts out in front, high-right to low-left -> follows through low-left
const FP_SWORD_LIGHT_1 := [
	[Vector3(0.35, -0.05, -0.36), Vector3(0.30, 0.70, 0.65), Vector3(-0.45, -0.30, -0.84)],
	[Vector3(0.06, -0.15, -0.60), Vector3(-0.62, 0.22, -0.75), Vector3(-0.35, -0.93, 0.10)],
	[Vector3(-0.10, -0.33, -0.54), Vector3(-0.70, -0.38, -0.60), Vector3(-0.30, -0.60, 0.74)],
]
## Backhand: coiled across the body low-left -> rising cut out in front -> finishes high-right
const FP_SWORD_LIGHT_2 := [
	[Vector3(-0.06, -0.32, -0.44), Vector3(-0.75, -0.10, 0.25), Vector3(0.40, 0.20, -0.90)],
	[Vector3(0.08, -0.15, -0.62), Vector3(0.55, 0.30, -0.78), Vector3(0.30, 0.92, 0.25)],
	[Vector3(0.36, -0.04, -0.44), Vector3(0.62, 0.62, -0.10), Vector3(0.20, 0.40, 0.90)],
]
const FP_SWORD_CHARGE := [Vector3(0.32, 0.0, -0.36), Vector3(0.20, 0.80, 0.55), Vector3(-0.20, -0.50, -0.84)]
## Power cleave: from the coiled charge, a committed downward-diagonal cut through the crosshair
const FP_SWORD_POWER := [
	[Vector3(0.10, -0.10, -0.64), Vector3(-0.55, 0.12, -0.83), Vector3(-0.40, -0.92, 0.0)],
	[Vector3(-0.08, -0.33, -0.54), Vector3(-0.62, -0.45, -0.64), Vector3(-0.20, -0.55, 0.80)],
]

# Two-handed axe: keys are for the TOP (right) hand; the left hand rides lower on the haft.
const FP_AXE_HAND_R := 0.47  ## right fist on the upper leather wrap (model units along the haft)
const FP_AXE_HAND_L := -0.11  ## left fist on the lower leather wrap
const FP_AXE_REST := [Vector3(0.30, -0.26, -0.50), Vector3(0.30, 0.80, -0.52), Vector3(-0.25, 0.0, -0.97)]
const FP_AXE_SPRINT := [Vector3(0.24, -0.34, -0.42), Vector3(0.62, 0.62, -0.48), Vector3(-0.15, 0.0, -0.99)]
## Diagonal chop: axe hoisted over the right shoulder -> head drives down-left through the crosshair
const FP_AXE_LIGHT_1 := [
	[Vector3(0.36, 0.02, -0.34), Vector3(0.28, 0.55, 0.79), Vector3(0.0, 0.82, -0.57)],
	[Vector3(0.08, -0.20, -0.58), Vector3(-0.50, 0.25, -0.83), Vector3(-0.45, -0.89, 0.0)],
	[Vector3(-0.12, -0.34, -0.50), Vector3(-0.72, -0.28, -0.64), Vector3(-0.20, -0.60, 0.77)],
]
## Backhand sweep: head out to the left -> sweeps across the front -> carries out to the right
const FP_AXE_LIGHT_2 := [
	[Vector3(-0.14, -0.18, -0.40), Vector3(-0.82, 0.30, 0.20), Vector3(0.10, 0.10, -1.0)],
	[Vector3(0.06, -0.14, -0.62), Vector3(0.05, 0.25, -0.97), Vector3(1.0, 0.0, 0.0)],
	[Vector3(0.32, -0.10, -0.46), Vector3(0.86, 0.25, -0.05), Vector3(0.0, 0.0, 1.0)],
]
const FP_AXE_CHARGE := [Vector3(0.26, 0.10, -0.30), Vector3(0.10, 0.55, 0.83), Vector3(0.0, 0.83, -0.55)]
## Overhead slam: the head comes up and over the top of the view, then drives down the centre line while the
## hands finish low at the belly (a forward-pointing haft at face height would put the lower fist in the lens)
const FP_AXE_POWER := [
	[Vector3(0.16, -0.04, -0.46), Vector3(-0.12, 0.85, -0.52), Vector3(-0.40, -0.45, -0.80)],
	[Vector3(0.10, -0.26, -0.56), Vector3(-0.30, 0.10, -0.95), Vector3(-0.45, -0.89, 0.0)],
	[Vector3(0.0, -0.40, -0.50), Vector3(-0.36, -0.25, -0.90), Vector3(-0.30, -0.90, 0.30)],
]
const FP_AXE_POWER_TIMES := [0.0, 0.16, 0.30, 0.48, 1.0]
const FP_AXE_POWER_CURVES := [1.6, 0.9, 0.45, -1.8]

# Spell hands: palm faces the target, back of the hand toward the player
const FP_SPELL_REST_R := [Vector3(0.30, -0.31, -0.52), Vector3(-0.30, 0.10, -0.95), Vector3(-0.10, 0.95, 0.30)]
const FP_SPELL_REST_L := [Vector3(-0.30, -0.31, -0.52), Vector3(0.30, 0.10, -0.95), Vector3(0.10, 0.95, 0.30)]
## Gather (draw the palm back) -> thrust the open palm at the crosshair -> hold the release -> settle
const FP_SPELL_CAST_R := [
	[Vector3(0.33, -0.34, -0.42), Vector3(-0.40, 0.30, -0.87), Vector3(0.0, 0.95, 0.30)],
	[Vector3(0.14, -0.17, -0.72), Vector3(-0.10, 0.0, -1.0), Vector3(0.0, 0.95, -0.30)],
	[Vector3(0.17, -0.19, -0.66), Vector3(-0.15, 0.05, -0.99), Vector3(0.0, 0.97, -0.20)],
]

# Bow: canted low carry -> raised vertical just left of the crosshair, the arrow under the eye (an archer's view)
const FP_BOW_IDLE := [Vector3(-0.30, -0.36, -0.56), Vector3(0.42, 0.84, -0.34), Vector3(0.25, -0.20, -0.95)]
const FP_BOW_AIM := [Vector3(-0.07, -0.125, -0.62), Vector3(-0.04, 0.998, -0.04), Vector3(0.06, 0.0, -1.0)]
## Full-draw nock relative to the arrow rest: drawn back to the right cheek, so the string and arrow slant in from
## the lower right and the arrow tip settles just below-left of the crosshair (the nock stays ~10 cm off the lens)
const FP_BOW_ANCHOR := Vector3(0.085, -0.035, 0.52)
const FP_BOW_HOOK := Vector3(0.03, -0.035, 0.035)  ## drawing fist relative to the nock (fingers hooked on the string)
const FP_BOW_HAND_REST := Vector3(0.38, -0.60, -0.28)  ## drawing hand relaxed below the frame

const FP_SWING_TIMES := [0.0, 0.22, 0.42, 0.60, 1.0]
const FP_SWING_TIMES_2H := [0.0, 0.26, 0.46, 0.64, 1.0]
## wind-up decelerates into the coil, the strike accelerates into impact, follow-through bleeds off, recovery eases
const FP_SWING_CURVES := [0.7, 1.4, 0.5, -1.8]
const FP_POWER_TIMES := [0.0, 0.30, 0.50, 1.0]
const FP_POWER_CURVES := [1.9, 0.45, -1.8]
const FP_CAST_TIMES := [0.0, 0.22, 0.42, 0.62, 1.0]
const FP_CAST_CURVES := [-1.6, 1.8, 0.5, -1.8]
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

	# Upper-arm sleeves run from each forearm's elbow back to the shoulder (no floating elbow guards)
	_fp_upper_r = _arm("fp_upper_arm")
	_fp_upper_r.name = "RightUpperArm"
	fp_rig.add_child(_fp_upper_r)
	_fp_upper_l = _arm("fp_upper_arm")
	_fp_upper_l.name = "LeftUpperArm"
	fp_rig.add_child(_fp_upper_l)

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


## Repairs older saves: a ring stored under the old "ring" key (D-046 bug) moves to a real ring slot, and the old
## "sponsored" rarity becomes "legendary" (FB-014).
func normalize_equipment() -> void:
	# FB-014: the old "sponsored" (Sponsored Mythic) rarity is now "legendary"
	for it in equipment.values() + inventory:
		if str((it as Dictionary).get("rarity", "")) == "sponsored":
			(it as Dictionary)["rarity"] = "legendary"
	if equipment.has("ring"):
		var r: Dictionary = equipment["ring"]
		equipment.erase("ring")
		equipment["ring_2" if equipment.has("ring_1") and not equipment.has("ring_2") else "ring_1"] = r


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
	var holding_right: bool = bool(input_override.get("right_held", Input.is_action_pressed("right_hand_action")))
	var rh_eq: Dictionary = equipment.get("right_hand", {})
	# D-046: a shield blocks from whichever hand holds it
	var left_block := str(lh.get("category", "")) == "shield" and holding_left
	var right_block := str(rh_eq.get("category", "")) == "shield" and holding_right
	is_blocking = (left_block or right_block) and stamina > 2.0

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
		var rcat := str(rh.get("category", ""))
		if rcat == "spell":
			_cast_spell(rh, true)
			is_right_holding = false
		elif rcat == "shield" or rh.is_empty():
			is_right_holding = false  # a right-hand shield blocks while held (see step_simulation)
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


## Open spell-casting arm. The fp_arm_open models are authored palm-forward in Blender's frame, which lands
## palm-toward-camera in Godot, so the mesh is turned to face the target (palm along the anchor's -Z). Turned
## around, the "_l" mesh is the anatomically right hand (thumb toward the body) and vice versa.
func _open_arm(side: String) -> Node3D:
	var a := _arm("fp_arm_open_" + ("l" if side == "r" else "r"))
	a.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	return a


static func _is_single_edged(model_path: String) -> bool:
	return model_path.contains("axe") or model_path.contains("cleaver")


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
	_right_single_edge = false
	_left_single_edge = false
	_elbow_local_r = Vector3.ZERO
	_elbow_local_l = Vector3.ZERO
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
			fp_right_anchor.add_child(_open_arm("r"))
			_elbow_local_r = FP_ELBOW_OPEN
			_attach_spell_fx(_fp_right_weapon_holder, rh)
		elif str(rh.get("category", "")) == "shield":
			fp_right_anchor.add_child(_arm("fp_arm_grip_r"))
			_elbow_local_r = FP_ELBOW_GRIP
			var rsh := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			rsh.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			rsh.scale = Vector3.ONE * 0.62
			_disable_shadows(rsh)
			_fp_right_weapon_holder.add_child(rsh)
		else:
			fp_right_anchor.add_child(_arm("fp_arm_grip_r"))
			_elbow_local_r = FP_ELBOW_GRIP
			if not is_bow:
				var w_model := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 0.9, 0.05))
				_right_single_edge = _is_single_edged(str(rh.get("model", "")))
				_disable_shadows(w_model)
				_fp_right_weapon_holder.add_child(w_model)
				# Streak only along the outer part of the blade / the axe's cutting edge, so it reads as a glint
				_blade_base = Node3D.new()
				_blade_base.position = Vector3(0.21, 0.80, 0.0) if is_two_hand else Vector3(0.0, 0.68, 0.0)
				_fp_right_weapon_holder.add_child(_blade_base)
				_blade_tip = Node3D.new()
				_blade_tip.position = Vector3(0.25, 1.0, 0.0) if is_two_hand else Vector3(0.0, 0.9, 0.0)
				_fp_right_weapon_holder.add_child(_blade_tip)
				if is_two_hand:
					_offhand_axe = true

	# --- LEFT HAND ---
	if is_bow:
		_fp_left_weapon_holder = Node3D.new()
		fp_left_anchor.add_child(_fp_left_weapon_holder)
		fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
		_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
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
		_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
	elif not lh.is_empty():
		_fp_left_weapon_holder = Node3D.new()
		fp_left_anchor.add_child(_fp_left_weapon_holder)
		var lcat := str(lh.get("category", ""))
		if lcat == "shield":
			fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
			_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
			var sh := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			sh.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			sh.scale = Vector3.ONE * 0.62
			_disable_shadows(sh)
			_fp_left_weapon_holder.add_child(sh)
		elif lcat == "spell":
			fp_left_anchor.add_child(_open_arm("l"))
			_elbow_local_l = FP_ELBOW_OPEN
			_attach_spell_fx(_fp_left_weapon_holder, lh)
		else:
			fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
			_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
			var lw := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.05, 0.9, 0.05))
			_left_single_edge = _is_single_edged(str(lh.get("model", "")))
			_disable_shadows(lw)
			_fp_left_weapon_holder.add_child(lw)

	_equip_raise = 1.0
	_bow_reach_blend = 0.0
	_bow_twang_t = 0.0
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


## Third-person: weapons follow the animated crawler's hand sockets (with proper shield & bow alignment).
func _refresh_tp_weapons() -> void:
	_tp_bow_node = null
	_tp_string_top = null
	_tp_string_bot = null
	_tp_nocked_arrow = null
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
	_tp_grip_r = gr
	var is_bow := str(rh.get("weapon_type", "")) == "archery"
	var rcat := str(rh.get("category", ""))
	if gr != null and not rh.is_empty() and not is_bow:
		if rcat == "spell":
			gr.add_child(VfxFactory.make_glow(Color.html(str(rh.get("color", "#ff6a22"))), 0.3, 1.6))
		elif rcat == "shield":
			var rsh := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			rsh.rotation_degrees = Vector3(0.0, -90.0, 0.0)  # painted face out from the right hand's outer side
			gr.add_child(rsh)
		else:
			gr.add_child(ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 0.9, 0.05)))
	if gl != null:
		if is_bow:
			var b := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 1.4, 0.1))
			gl.add_child(b)
			_tp_bow_node = b
			_tp_string_top = b.find_child("StringTop*", true, false) as Node3D
			_tp_string_bot = b.find_child("StringBottom*", true, false) as Node3D
			if _tp_string_top != null and _tp_string_bot != null:
				_tp_string_tip_top = _tp_string_top.position
				_tp_string_tip_bot = _tp_string_bot.position
				_tp_string_rest_z = _tp_string_tip_top.z
			_tp_nocked_arrow = ModelLoader.instantiate_model(GEAR_DIR + "arrow.glb", Vector3(0.02, 0.7, 0.02))
			_tp_nocked_arrow.visible = false
			b.add_child(_tp_nocked_arrow)
		elif not lh.is_empty() and str(lh.get("category", "")) == "shield":
			var sh := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			# Shield grip bar stays vertical along GripL +Y while painted face points out from outer hand (+X)
			sh.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			gl.add_child(sh)
		elif not lh.is_empty() and str(lh.get("category", "")) == "spell":
			gl.add_child(VfxFactory.make_glow(Color.html(str(lh.get("color", "#ff6a22"))), 0.3, 1.6))
		elif not lh.is_empty() and str(lh.get("category", "")) == "weapon":
			var lw := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.05, 0.9, 0.05))
			lw.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			gl.add_child(lw)


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
	_sprint_blend = lerpf(_sprint_blend, 1.0 if is_sprinting else 0.0, clampf(dt * 8.5, 0.0, 1.0))
	_block_blend = lerpf(_block_blend, 1.0 if is_blocking else 0.0, clampf(dt * 13.0, 0.0, 1.0))
	_equip_raise = maxf(0.0, _equip_raise - dt * 3.8)
	var target_draw := CombatMath.compute_bow_draw_ratio(bow_draw_time, player_cfg) if is_bow_drawing else 0.0
	if is_bow_drawing:
		_draw_blend = lerpf(_draw_blend, target_draw, clampf(dt * 14.0, 0.0, 1.0))
	else:
		# Snap draw blend rapidly to 0 on release so string releases crisply rather than oozing forward
		_draw_blend = lerpf(_draw_blend, 0.0, clampf(dt * 32.0, 0.0, 1.0))
	var target_reach := 1.0 if (is_bow_drawing or is_right_holding) else 0.0
	_bow_reach_blend = lerpf(_bow_reach_blend, target_reach, clampf(dt * (12.0 if target_reach > 0.5 else 7.5), 0.0, 1.0))
	_bow_twang_t = maxf(0.0, _bow_twang_t - dt)
	_bow_release_recoil = maxf(0.0, _bow_release_recoil - dt * 3.4)
	_look_sway = _look_sway.lerp(Vector2.ZERO, clampf(dt * 8.5, 0.0, 1.0))
	_camera_kick = maxf(0.0, _camera_kick - dt * 4.2)
	_shake = maxf(0.0, _shake - dt * 3.2)
	_shake_phase += dt * 47.0
	if _move_blend > 0.02:
		# Wrap modulo TAU; never spin phase backwards when stopping (amplitude fades smoothly via _move_blend)
		_walk_bob_phase = fmod(_walk_bob_phase + dt * lerpf(7.8, 12.2, _sprint_blend), TAU)
	if _right_swing_t > 0.0:
		_right_swing_t = maxf(0.0, _right_swing_t - act_dt)
	if _left_action_t > 0.0:
		_left_action_t = maxf(0.0, _left_action_t - act_dt)
	_shield_hit_t = maxf(0.0, _shield_hit_t - act_dt)
	if _slash_vfx_timer > 0.0:
		_slash_vfx_timer = maxf(0.0, _slash_vfx_timer - act_dt)

	var bob_k := 1.0
	var shake_k := 1.0
	if GameSettings != null:
		bob_k = float(GameSettings.get_value("gameplay", "head_bob"))
		shake_k = float(GameSettings.get_value("gameplay", "camera_shake"))

	var rh: Dictionary = equipment.get("right_hand", {})
	var lh: Dictionary = equipment.get("left_hand", {})
	var is_bow := str(rh.get("weapon_type", "")) == "archery"
	var is_two_hand := bool(rh.get("two_handed", false)) and not is_bow
	var r_spell := str(rh.get("category", "")) == "spell"
	var r_shield := str(rh.get("category", "")) == "shield"

	# Subtle organic breathing (asymmetric inhale/exhale) + smooth figure-8 pendulum stride bob
	var br_wave := sin(_anim_time * 1.45) + 0.25 * sin(_anim_time * 2.9 - 0.55)
	var breathe_x := cos(_anim_time * 0.72) * 0.004
	var breathe_y := br_wave * 0.0065
	var walk_x := cos(_walk_bob_phase) * 0.018 * _move_blend * (1.0 + _sprint_blend * 0.65) * bob_k
	# Smooth double-frequency vertical pendulum lagged slightly behind head bob (no sharp abs(sin) cusp!)
	var walk_y := (-cos(_walk_bob_phase * 2.0 - 0.35) - 0.15) * 0.014 * _move_blend * (1.0 + _sprint_blend * 0.7) * bob_k
	var equip_drop := ease(_equip_raise, 2.2) * 0.26
	fp_rig.position = Vector3(breathe_x + walk_x + _look_sway.x, breathe_y + walk_y + _look_sway.y - _sprint_blend * 0.03 - equip_drop, 0.0)
	fp_rig.rotation_degrees = Vector3(_look_sway.y * 38.0 - ease(_equip_raise, 2.0) * 16.0, _look_sway.x * 46.0, -_look_sway.x * 28.0 - walk_x * 45.0)

	# --- RIGHT HAND ----------------------------------------------------------------
	# Weapon keys are [fist position, blade/haft direction, cutting-edge direction] in rig space (see FP_* consts).
	var r_key: Array = FP_AXE_REST if is_two_hand else FP_SWORD_REST
	if r_spell:
		r_key = FP_SPELL_REST_R
	var sprint_key: Array = FP_AXE_SPRINT if is_two_hand else FP_SWORD_SPRINT
	if _sprint_blend > 0.01 and _right_swing_t <= 0.0 and not is_bow and not r_spell and not r_shield:
		var sp_pump := sin(_walk_bob_phase) * bob_k
		var pumped := [
			(sprint_key[0] as Vector3) + Vector3(sp_pump * 0.03, cos(_walk_bob_phase * 2.0) * 0.015 * bob_k, -sp_pump * 0.025),
			(sprint_key[1] as Vector3) + Vector3(0.0, 0.0, sp_pump * 0.12),
			sprint_key[2],
		]
		r_key = _blend_keys(r_key, pumped, ease(_sprint_blend, -1.5))

	# Power-attack charge: weapon coils high over the right shoulder, trembling as the charge completes
	if is_right_holding and not is_bow and str(rh.get("category", "")) == "weapon" and _right_swing_t <= 0.0:
		var charge := clampf(right_attack_hold / float(player_cfg["combat"]["power_attack_hold_sec"]), 0.0, 1.0)
		r_key = _blend_keys(r_key, FP_AXE_CHARGE if is_two_hand else FP_SWORD_CHARGE, ease(charge, -1.8))
		var trem := maxf(0.0, charge - 0.6) / 0.4
		r_key = [(r_key[0] as Vector3) + Vector3(sin(_anim_time * 36.0), cos(_anim_time * 43.0), 0.0) * 0.0025 * trem, r_key[1], r_key[2]]

	# FB-014 standing rule: at rest / sprinting the cutting edge faces straight away from the player's eye
	if _right_swing_t <= 0.0 and not is_right_holding and not is_bow and not r_spell and not r_shield:
		r_key = _away_edge(r_key, 0.45 if is_two_hand else 0.55)

	# The live pose right before a swing starts, so a swing (incl. a released charge) never snaps
	if _right_swing_t <= 0.0 or _swing_start_key.is_empty():
		_swing_start_key = r_key

	var target_cam_swing := Vector3.ZERO
	if _right_swing_t > 0.0:
		var u := 1.0 - (_right_swing_t / maxf(0.01, _right_swing_dur))
		var sw := sin(u * PI)
		var keys: Array = []
		var times: Array = FP_SWING_TIMES
		var curves: Array = FP_SWING_CURVES
		if r_spell:
			keys = [_swing_start_key] + FP_SPELL_CAST_R + [r_key]
			times = FP_CAST_TIMES
			curves = FP_CAST_CURVES
		elif _right_swing_power:
			keys = [_swing_start_key] + (FP_AXE_POWER if is_two_hand else FP_SWORD_POWER) + [r_key]
			times = FP_AXE_POWER_TIMES if is_two_hand else FP_POWER_TIMES
			curves = FP_AXE_POWER_CURVES if is_two_hand else FP_POWER_CURVES
			target_cam_swing = Vector3(-3.2 * sw, 0.4 * sw, 1.0 * sw)
		elif _right_combo_step % 2 == 1:
			keys = [_swing_start_key] + (FP_AXE_LIGHT_1 if is_two_hand else FP_SWORD_LIGHT_1) + [r_key]
			target_cam_swing = Vector3(-1.2 * sw, 1.6 * sw, 1.6 * sw)
		else:
			keys = [_swing_start_key] + (FP_AXE_LIGHT_2 if is_two_hand else FP_SWORD_LIGHT_2) + [r_key]
			target_cam_swing = Vector3(-0.6 * sw, -1.8 * sw, -1.2 * sw)
		if is_two_hand and not r_spell and not _right_swing_power:
			times = FP_SWING_TIMES_2H
		r_key = _sample_keys(u, keys, times, curves)

	r_key = [(r_key[0] as Vector3) + Vector3(0.0, sin(_walk_bob_phase + 0.6) * 0.006 * _move_blend * bob_k, 0.0), r_key[1], r_key[2]]

	# --- LEFT HAND ------------------------------------------------------------------
	var l_key: Array = []
	var l_pos := Vector3(-0.36, -0.38, -0.56)
	var l_quat := Basis.from_euler(Vector3(-6.0, 22.0, -6.0) * (PI / 180.0)).get_rotation_quaternion()
	var lcat := str(lh.get("category", ""))
	if is_bow or _offhand_axe:
		pass
	elif lcat == "shield":
		var sp := _shield_pose()
		l_pos = sp[0]
		l_quat = sp[1]
	elif lcat == "spell":
		l_key = FP_SPELL_REST_L
		if _left_action_t > 0.0:
			var u2 := 1.0 - (_left_action_t / maxf(0.01, _left_action_dur))
			l_key = _sample_keys(u2, [l_key] + _mirror_keys(FP_SPELL_CAST_R) + [l_key], FP_CAST_TIMES, FP_CAST_CURVES)
	elif not lh.is_empty():
		# Dual-wield off-hand weapon: the right-hand sword library mirrored across the screen
		l_key = _away_edge(_mirror_key(FP_SWORD_REST), 0.55)
		if _left_action_t > 0.0:
			var u3 := 1.0 - (_left_action_t / maxf(0.01, _left_action_dur))
			var sw3 := sin(u3 * PI)
			var lib: Array = FP_SWORD_LIGHT_1 if _left_combo_step % 2 == 1 else FP_SWORD_LIGHT_2
			l_key = _sample_keys(u3, [l_key] + _mirror_keys(lib) + [l_key], FP_SWING_TIMES, FP_SWING_CURVES)
			target_cam_swing += Vector3(-1.0 * sw3, -1.4 * sw3, -1.4 * sw3) if _left_combo_step % 2 == 1 else Vector3(-0.5 * sw3, 1.6 * sw3, 1.1 * sw3)
	if not l_key.is_empty():
		l_key = [(l_key[0] as Vector3) + Vector3(0.0, sin(_walk_bob_phase + 2.2) * 0.006 * _move_blend * bob_k, 0.0), l_key[1], l_key[2]]
	l_pos.y += sin(_walk_bob_phase + 2.2) * 0.006 * _move_blend * bob_k

	# Apply camera bob, shake & subtle melee swing coupling in first-person
	_cam_swing_rot = _cam_swing_rot.lerp(target_cam_swing * shake_k, clampf(dt * 14.0, 0.0, 1.0))
	if camera_mode == "first_person":
		var target_fov := _base_fov() + (_sprint_blend * 5.0) - (_draw_blend * 14.0)
		camera.fov = lerpf(camera.fov, target_fov, clampf(dt * 10.0, 0.0, 1.0))
		var head_bob_y := sin(_walk_bob_phase * 2.0) * 0.028 * _move_blend * (1.0 + _sprint_blend * 0.5) * bob_k
		var head_bob_x := cos(_walk_bob_phase) * 0.015 * _move_blend * bob_k
		var sh := Vector3(sin(_shake_phase * 1.3), sin(_shake_phase * 1.7 + 1.0), 0.0) * _shake * 0.035
		camera.position = Vector3(head_bob_x, head_bob_y, 0.0) + sh
		camera.rotation_degrees = Vector3(
			_camera_kick * 1.6 + sh.y * 30.0 + _cam_swing_rot.x,
			sh.x * 20.0 + _cam_swing_rot.y,
			-head_bob_x * 20.0 + sin(_shake_phase) * _shake * 1.5 + _cam_swing_rot.z
		)

	# --- Pose the rig -----------------------------------------------------------------
	if is_bow:
		_pose_bow()
	elif is_two_hand:
		_pose_two_hand(r_key)
	elif r_spell:
		_pose_palm(fp_right_anchor, r_key)
	elif r_shield:
		var rsp := _shield_pose()
		fp_right_anchor.transform = Transform3D(_mirror_basis(Basis(rsp[1] as Quaternion)), (rsp[0] as Vector3) * Vector3(-1.0, 1.0, 1.0))
		if _fp_right_weapon_holder != null:
			_fp_right_weapon_holder.basis = Basis()
	elif not rh.is_empty():
		_pose_fist(fp_right_anchor, _fp_right_weapon_holder, r_key, false, _right_single_edge)
	else:
		fp_right_anchor.transform = Transform3D(_fist_basis(FP_SWORD_REST[0], FP_SWORD_REST[1], false), FP_SWORD_REST[0])
	if not is_bow and not is_two_hand:
		if lcat == "spell":
			_pose_palm(fp_left_anchor, l_key)
		elif not l_key.is_empty():
			_pose_fist(fp_left_anchor, _fp_left_weapon_holder, l_key, true, _left_single_edge)
		else:
			fp_left_anchor.transform = Transform3D(Basis(l_quat), l_pos)
	_pose_upper_arm(_fp_upper_r, fp_right_anchor, _elbow_local_r, false)
	_pose_upper_arm(_fp_upper_l, fp_left_anchor, _elbow_local_l, true)

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
		var horiz_spd := Vector2(velocity.x, velocity.z).length()
		var armed := not rh.is_empty() or not lh.is_empty()
		var st := "idle_combat" if (armed and tp_visual.has_anim("idle_combat")) else "idle"
		var play_spd := 1.0
		if is_blocking and horiz_spd < 2.2:
			st = "block"
		elif is_bow_drawing and horiz_spd < 2.2:
			st = "draw_hold"
		elif _move_blend > 0.12:
			# Calibrate walk/run switch & speed to true stride velocity (zero foot sliding!)
			var use_run := _sprint_blend > 0.35 or horiz_spd > 4.2
			st = "run" if use_run else "walk"
			play_spd = clampf(horiz_spd / (3.4 if use_run else 1.85), 0.75, 1.65)
		tp_visual.play_state(st, 0.18, play_spd)
		_update_tp_bowstring()


func _update_tp_bowstring() -> void:
	if _tp_bow_node == null or not is_instance_valid(_tp_bow_node):
		return
	var drawing := is_bow_drawing and (tp_visual.state == "draw_hold" or _draw_blend > 0.1)
	var nock_local := Vector3(0.0, 0.0, _tp_string_rest_z)
	if drawing and _tp_grip_r != null and is_instance_valid(_tp_grip_r):
		var p_local := _tp_bow_node.to_local(_tp_grip_r.global_position)
		var pull_z := clampf(p_local.z, _tp_string_rest_z - 0.52, _tp_string_rest_z)
		nock_local = Vector3(clampf(p_local.x, -0.04, 0.04), clampf(p_local.y, -0.05, 0.08), pull_z)
	if _tp_string_top != null and _tp_string_bot != null:
		_aim_segment(_tp_string_top, _tp_string_tip_top, nock_local)
		_aim_segment(_tp_string_bot, _tp_string_tip_bot, nock_local)
	if _tp_nocked_arrow != null:
		_tp_nocked_arrow.visible = drawing
		if drawing:
			var rest_pt := Vector3(0.024, 0.055, 0.0)
			var dir := (rest_pt - nock_local).normalized()
			var y_ax := dir
			var x_ax := y_ax.cross(Vector3.UP).normalized()
			if x_ax.length() < 0.1:
				x_ax = Vector3.RIGHT
			var z_ax := x_ax.cross(y_ax).normalized()
			_tp_nocked_arrow.transform = Transform3D(Basis(x_ax, y_ax, z_ax), nock_local + dir * 0.36)


## Orientation for a first-person fist from where its grip axis (through the fist) and its forearm (toward
## the elbow) should point. Matches the fp_arm_grip models: grip = +Y, forearm in the +Z half of the YZ plane.
static func _hand_basis(grip_dir: Vector3, forearm_dir: Vector3) -> Basis:
	var y := grip_dir.normalized()
	var z := forearm_dir - y * forearm_dir.dot(y)
	if z.length() < 0.001:
		z = Vector3.BACK
	z = z.normalized()
	return Basis(y.cross(z).normalized(), y, z)


## 2-bone arm solve: where the elbow sits for a hand at `hand`, bending toward `pole` (rig space).
static func _ik_elbow(shoulder: Vector3, hand: Vector3, pole: Vector3) -> Vector3:
	var d := hand - shoulder
	var dist := maxf(d.length(), 0.0001)
	var dir := d / dist
	dist = clampf(dist, 0.05, (FP_UPPER_ARM + FP_FOREARM) * 0.999)
	var cos_a := (FP_UPPER_ARM * FP_UPPER_ARM + dist * dist - FP_FOREARM * FP_FOREARM) / (2.0 * FP_UPPER_ARM * dist)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var bend := pole - dir * pole.dot(dir)
	if bend.length() < 0.001:
		bend = Vector3.DOWN
	return shoulder + (dir * cos_a + bend.normalized() * sin_a) * FP_UPPER_ARM


## Fist orientation for a grip direction, rolled so the forearm runs back to a solved elbow (left = mirrored).
static func _fist_basis(hand: Vector3, grip_dir: Vector3, left: bool, pole_override: Vector3 = Vector3.ZERO) -> Basis:
	var s := -1.0 if left else 1.0
	var shoulder := Vector3(FP_SHOULDER.x * s, FP_SHOULDER.y, FP_SHOULDER.z)
	var pole := pole_override if pole_override != Vector3.ZERO else Vector3(FP_ELBOW_POLE.x * s, FP_ELBOW_POLE.y, FP_ELBOW_POLE.z)
	return _hand_basis(grip_dir, _ik_elbow(shoulder, hand, pole) - hand)


## Replaces a key's edge with the direction from the eye (rig origin) to the blade, so the blade is seen edge-on,
## facing away from the player (FB-014). `reach` = how far along the blade/haft the edge is judged (blade middle /
## axe head).
static func _away_edge(k: Array, reach: float) -> Array:
	var blade_mid := (k[0] as Vector3) + (k[1] as Vector3).normalized() * reach
	return [k[0], k[1], blade_mid.normalized()]


static func _mirror_key(k: Array) -> Array:
	var m := Vector3(-1.0, 1.0, 1.0)
	return [(k[0] as Vector3) * m, (k[1] as Vector3) * m, (k[2] as Vector3) * m]


static func _mirror_keys(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		out.append(_mirror_key(k))
	return out


static func _blend_keys(a: Array, b: Array, t: float) -> Array:
	return [
		(a[0] as Vector3).lerp(b[0] as Vector3, t),
		(a[1] as Vector3).normalized().slerp((b[1] as Vector3).normalized(), t),
		(a[2] as Vector3).normalized().slerp((b[2] as Vector3).normalized(), t),
	]


## Samples keyed poses at u (0..1) along a Catmull-Rom curve (smooth arcs, no straight-line kinks between
## keys), with a per-segment ease so wind-ups settle, strikes accelerate and follow-throughs bleed off.
static func _sample_keys(u: float, keys: Array, times: Array, curves: Array) -> Array:
	var n := keys.size()
	var i := 0
	while i < n - 2 and u > float(times[i + 1]):
		i += 1
	var span := maxf(0.0001, float(times[i + 1]) - float(times[i]))
	var k := ease(clampf((u - float(times[i])) / span, 0.0, 1.0), float(curves[i]))
	var a: Array = keys[maxi(i - 1, 0)]
	var b: Array = keys[i]
	var c: Array = keys[i + 1]
	var d: Array = keys[mini(i + 2, n - 1)]
	var out: Array = [(b[0] as Vector3).cubic_interpolate(c[0], a[0], d[0], k)]
	for j in [1, 2]:
		var bj := (b[j] as Vector3).normalized()
		var cj := (c[j] as Vector3).normalized()
		var v := bj.cubic_interpolate(cj, (a[j] as Vector3).normalized(), (d[j] as Vector3).normalized(), k)
		out.append(v.normalized() if v.length() > 0.05 else bj.slerp(cj, k).normalized())
	return out


## Left-hand shield pose (rig space): compact edge-on lower-left at rest, decisive raise across left-of-centre to
## block, shove-back on impact. A right-hand shield (D-046) uses the mirror image of this pose.
func _shield_pose() -> Array:
	var rest_p := Vector3(-0.50, -0.44, -0.62)
	var rest_q := Basis.from_euler(Vector3(-8.0, 58.0, -14.0) * (PI / 180.0)).get_rotation_quaternion()
	var blk_p := Vector3(-0.24, -0.27, -0.56)
	var blk_q := Basis.from_euler(Vector3(2.0, 18.0, -6.0) * (PI / 180.0)).get_rotation_quaternion()
	var be := ease(_block_blend, -1.6)
	var pos := rest_p.lerp(blk_p, be)
	var quat := rest_q.slerp(blk_q, be)
	if _sprint_blend > 0.01 and _block_blend < 0.2:
		pos += Vector3(0.06, -0.06, 0.05) * _sprint_blend
	if _shield_hit_t > 0.0:
		var bu := 1.0 - (_shield_hit_t / 0.16)
		# Fast knockback shock -> damped spring settle back into guard
		var imp := sin(minf(1.0, bu * 2.2) * PI * 0.5) * exp(-bu * 3.8)
		pos += Vector3(-0.025, -0.035, 0.13) * imp
		quat = quat * Basis.from_euler(Vector3(16.0, 12.0, -8.0) * imp * (PI / 180.0)).get_rotation_quaternion()
	return [pos, quat]


static func _mirror_basis(b: Basis) -> Basis:
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	return m * b * m


## Stretches an upper-arm sleeve from the end of a forearm mesh back to that side's shoulder.
func _pose_upper_arm(sleeve: Node3D, anchor: Node3D, elbow_local: Vector3, left: bool) -> void:
	if sleeve == null:
		return
	sleeve.visible = elbow_local != Vector3.ZERO
	if not sleeve.visible:
		return
	var e := anchor.transform * elbow_local
	var d := Vector3(FP_SHOULDER.x * (-1.0 if left else 1.0), FP_SHOULDER.y, FP_SHOULDER.z) - e
	var ln := maxf(d.length(), 0.01)
	var y := d / ln
	var x := y.cross(Vector3.FORWARD)
	x = x.normalized() if x.length() > 0.1 else y.cross(Vector3.UP).normalized()
	sleeve.transform = Transform3D(Basis(x, y * ln, x.cross(y)), e)


## Places a one-handed fist and rolls its weapon inside the grip so the cutting edge faces key[2].
func _pose_fist(anchor: Node3D, holder: Node3D, key: Array, left: bool, single_edge: bool) -> void:
	var pos: Vector3 = key[0]
	var b := _fist_basis(pos, key[1], left)
	anchor.transform = Transform3D(b, pos)
	if holder == null or not is_instance_valid(holder):
		return
	var e := b.inverse() * (key[2] as Vector3)
	if not single_edge and e.x < 0.0:
		e = -e  # double-edged: use whichever edge needs the least roll
	if Vector2(e.x, e.z).length() < 0.001:
		holder.basis = Basis()
	else:
		holder.basis = Basis(Vector3.UP, atan2(-e.z, e.x))


## Two-handed weapon: the axe is posed as one object (top hand position, haft direction, edge direction)
## and BOTH fists are placed on its leather wraps, each rolled toward its own shoulder.
func _pose_two_hand(key: Array) -> void:
	var h := (key[1] as Vector3).normalized()
	var e := key[2] as Vector3
	e = e - h * e.dot(h)
	if e.length() < 0.001:
		e = Vector3.FORWARD.cross(h)
	e = e.normalized()
	var pr: Vector3 = key[0]
	var pl := pr - h * (FP_AXE_HAND_R - FP_AXE_HAND_L)
	fp_right_anchor.transform = Transform3D(_fist_basis(pr, h, false), pr)
	fp_left_anchor.transform = Transform3D(_fist_basis(pl, h, true), pl)
	if _fp_right_weapon_holder != null:
		var w := Transform3D(Basis(e, h, e.cross(h)), pr - h * FP_AXE_HAND_R)
		_fp_right_weapon_holder.transform = fp_right_anchor.transform.affine_inverse() * w


## Open spell hand: palm toward key[1], fingers toward key[2] (the open-hand arm is turned to face away).
func _pose_palm(anchor: Node3D, key: Array) -> void:
	var palm := (key[1] as Vector3).normalized()
	var fingers := key[2] as Vector3
	fingers = (fingers - palm * fingers.dot(palm)).normalized()
	var z := -palm
	anchor.transform = Transform3D(Basis(fingers.cross(z), fingers, z), key[0])


## Bow: left fist raises the bow from a canted carry to vertical just left of the crosshair; the right hand
## hooks the string at the bow, then draws the nock straight back under the cheek so the arrow runs down the
## sightline. On the loose the string snaps forward and twangs, the bow kicks, and the hand follows through.
func _pose_bow() -> void:
	var reach := ease(clampf(_bow_reach_blend, 0.0, 1.0), -1.6)
	var rec := clampf(_bow_release_recoil, 0.0, 1.0)
	var raise := maxf(reach, ease(rec, 0.5))
	var pull := ease(clampf(_draw_blend, 0.0, 1.0), 0.85) * reach
	var k := _blend_keys(FP_BOW_IDLE, FP_BOW_AIM, raise)
	var kick := rec * rec
	var bow_pos: Vector3 = (k[0] as Vector3) + Vector3(-0.006, -0.012, -0.03) * kick
	if pull > 0.75:
		bow_pos += Vector3(sin(_anim_time * 2.1), cos(_anim_time * 1.7), 0.0) * 0.002 * (pull - 0.75) / 0.25
	var bow_axis := ((k[1] as Vector3) + Vector3(0.0, 0.0, -0.25) * kick).normalized()
	var lb := _fist_basis(bow_pos, bow_axis, true)
	fp_left_anchor.transform = Transform3D(lb, bow_pos)
	if _fp_left_weapon_holder == null or _bow_node == null:
		return
	var bb := lb.inverse() * (k[2] as Vector3)
	_fp_left_weapon_holder.basis = Basis(Vector3.UP, atan2(-bb.x, -bb.z))

	var bow_rig := fp_left_anchor.transform * _fp_left_weapon_holder.transform * _bow_node.transform
	var rest_a := bow_rig * Vector3(0.026, 0.055, 0.0)
	var rest_b := bow_rig * Vector3(-0.026, 0.055, 0.0)
	var arrow_rest := rest_a if rest_a.x > rest_b.x else rest_b  # arrow rides the inner (crosshair) side
	var string_rest := bow_rig * Vector3(0.0, 0.055, _string_rest_z)
	var anchor_pt := arrow_rest + FP_BOW_ANCHOR
	var nock := string_rest.lerp(anchor_pt, pull)
	if _bow_twang_t > 0.0 and pull < 0.05:
		var tw_u := 0.32 - _bow_twang_t
		nock += (string_rest - arrow_rest).normalized() * sin(tw_u * 75.0) * exp(-tw_u * 13.0) * 0.03
	var nock_local := bow_rig.affine_inverse() * nock
	if _string_top != null and _string_bot != null:
		_aim_segment(_string_top, _string_tip_top, nock_local)
		_aim_segment(_string_bot, _string_tip_bot, nock_local)

	if _fp_nocked_arrow != null:
		var nocked := reach > 0.55 and rec < 0.05
		_fp_nocked_arrow.visible = nocked
		if nocked:
			# Barely drawn, the string sits only ~4 cm behind the rest: aim the shaft along the bow's facing instead
			var span := arrow_rest - nock
			var dir := (k[2] as Vector3).normalized().slerp(span.normalized(), clampf(span.length() / 0.2, 0.0, 1.0)).normalized()
			var x_axis := dir.cross(Vector3.UP)
			x_axis = x_axis.normalized() if x_axis.length() > 0.1 else Vector3.RIGHT
			var arrow_rig := Transform3D(Basis(x_axis, dir, x_axis.cross(dir).normalized()), nock + dir * 0.352)
			_fp_nocked_arrow.transform = fp_left_anchor.transform.affine_inverse() * arrow_rig

	# Drawing hand: rises from below the frame onto the string, then rides the nock back to the cheek
	var hand_pos := FP_BOW_HAND_REST.lerp(nock + FP_BOW_HOOK, ease(reach, -1.4))
	if rec > 0.01 and not is_bow_drawing:
		# Loose: the hand flicks back past the cheek, then sinks out of frame
		hand_pos = FP_BOW_HAND_REST.lerp(anchor_pt + FP_BOW_HOOK + Vector3(0.05, 0.01, 0.09), ease(rec, 0.7))
	var draw_pole := Vector3(1.0, -0.15, 0.6)
	fp_right_anchor.transform = Transform3D(_fist_basis(hand_pos, bow_axis, false, draw_pole), hand_pos)


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
		var u0 := 0.12 if _swing_was_charged else 0.22
		if u > u0 and u < 0.64:
			_trail_pts.push_front([inv * _blade_base.global_position, inv * _blade_tip.global_position, _anim_time])
	# Keep only the last ~90 ms of blade path so the streak has the same length at any frame rate
	while not _trail_pts.is_empty() and (_anim_time - float(_trail_pts.back()[2]) > TRAIL_LIFE or _trail_pts.size() > 12):
		_trail_pts.pop_back()
	if _trail_pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trail_pts.size()
	for i in range(n):
		var a := 1.0 - float(i) / float(n - 1)
		var c := Color(1.0, 0.84, 0.6, 0.07 * a * a)
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
	var is_two_hand := bool(weapon.get("two_handed", false))
	if tp_visual != null and tp_visual.visible:
		var tp_clip := "attack_2h" if (is_two_hand and tp_visual.has_anim("attack_2h")) else "attack"
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
			_right_combo_step = 0  # after a pause the combo restarts with the forehand opener
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
	_bow_twang_t = 0.32
	_draw_blend = 0.0
	_camera_kick = 0.32
	if tp_visual != null and tp_visual.visible and tp_visual.has_anim("bow_shoot"):
		tp_visual.play_action("bow_shoot", 0.05, 1.0)

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
		tp_visual.play_action("cast", 0.08, 1.15)
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
	var body := head_pivot.global_position if head_pivot != null else global_position
	# Third person (D-046): the camera sits metres behind the crawler, so the ray is lengthened by that offset and
	# only accepts targets within reach of the crawler's body
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
	# Third person fallback: the nearest unlooted interactable in front of the crawler within reach
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
