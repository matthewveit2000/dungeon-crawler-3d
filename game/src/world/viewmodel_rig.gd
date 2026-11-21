class_name ViewmodelRig
extends RefCounted
## First-Person & Third-Person Viewmodel / Pose System v3 (D-040, D-048, D-055).
## Extracted out of PlayerController so weapon/spell/bow/shield posing, arm IK, upper-arm sleeves,
## blade trails, and third-person weapon mounting live cleanly in one focused module.
## Preserves pixel-for-pixel identical framing, blade-away rule (D-048), and test hooks.

const GEAR_DIR := "res://assets/models/gear/"
const FP_ANIMS_PATH := "res://data/fp_animations.json"
const TRAIL_LIFE := 0.095

# ---------------------------------------------------------------------------
# First-person rig geometry & framing anchors (D-040, D-048, D-060)
# All FP idle/walk/sprint/attack/power/cast/draw/recoil curves come from
# premade CC0 animations baked in `res://data/fp_animations.json`.
# Rig space = camera space: +X right, +Y up, -Z forward into the world.
# ---------------------------------------------------------------------------
const FP_SHOULDER := Vector3(0.20, -0.30, 0.12)
const FP_ELBOW_POLE := Vector3(0.6, -1.0, 0.15)
const FP_UPPER_ARM := 0.31
const FP_FOREARM := 0.30
const FP_ELBOW_GRIP := Vector3(0.03, -0.141, 0.271)
const FP_ELBOW_OPEN := Vector3(0.0, -0.097, 0.226)

# Two-handed battleaxe leather wrap positions along haft (+Y in weapon space)
const FP_AXE_HAND_R := 0.47
const FP_AXE_HAND_L := -0.11

# Bow framing anchors (modulated by premade Mesh2Motion bow_pull / bow_release curves)
const FP_BOW_IDLE := [Vector3(-0.30, -0.36, -0.56), Vector3(0.42, 0.84, -0.34), Vector3(0.25, -0.20, -0.95)]
const FP_BOW_AIM := [Vector3(-0.07, -0.125, -0.62), Vector3(-0.04, 0.998, -0.04), Vector3(0.06, 0.0, -1.0)]
const FP_BOW_ANCHOR := Vector3(0.085, -0.035, 0.52)
const FP_BOW_HOOK := Vector3(0.03, -0.035, 0.035)
const FP_BOW_HAND_REST := Vector3(0.38, -0.60, -0.28)

static var _fp_bank: Dictionary = {}

# Node references owned under PlayerController's Camera3D and body
var fp_rig: Node3D = null
var fp_right_anchor: Node3D = null
var fp_left_anchor: Node3D = null
var fp_right_weapon_holder: Node3D = null
var fp_left_weapon_holder: Node3D = null
var fp_nocked_arrow: Node3D = null
var fp_spell_node: Node3D = null
var slash_arc_mesh: MeshInstance3D = null
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
var _swing_start_key: Array = []
var _fp_upper_r: Node3D = null
var _fp_upper_l: Node3D = null
var _elbow_local_r: Vector3 = Vector3.ZERO
var _elbow_local_l: Vector3 = Vector3.ZERO
var _right_single_edge: bool = false
var _left_single_edge: bool = false
var _blade_tip: Node3D = null
var _blade_base: Node3D = null


func build_nodes(player_body: Node3D, camera: Camera3D) -> void:
	fp_rig = Node3D.new()
	fp_rig.name = "FirstPersonHands"
	camera.add_child(fp_rig)

	fp_right_anchor = Node3D.new()
	fp_right_anchor.name = "RightHandAnchor"
	fp_rig.add_child(fp_right_anchor)

	fp_left_anchor = Node3D.new()
	fp_left_anchor.name = "LeftHandAnchor"
	fp_rig.add_child(fp_left_anchor)

	_fp_upper_r = _arm("fp_upper_arm")
	_fp_upper_r.name = "RightUpperArm"
	fp_rig.add_child(_fp_upper_r)
	_fp_upper_l = _arm("fp_upper_arm")
	_fp_upper_l.name = "LeftUpperArm"
	fp_rig.add_child(_fp_upper_l)

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

	slash_arc_mesh = null

	tp_visual = CharacterVisual.create("crawler")
	tp_visual.rotation.y = PI
	tp_mesh = tp_visual
	player_body.add_child(tp_visual)
	tp_visual.play_state("idle", 0.0)


func refresh_equipment(equipment: Dictionary) -> void:
	for anchor in [fp_right_anchor, fp_left_anchor]:
		if anchor == null:
			continue
		for child in anchor.get_children():
			child.queue_free()
	fp_right_weapon_holder = null
	fp_left_weapon_holder = null
	fp_nocked_arrow = null
	fp_spell_node = null
	slash_arc_mesh = null
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
		fp_right_weapon_holder = Node3D.new()
		fp_right_anchor.add_child(fp_right_weapon_holder)
		if str(rh.get("category", "")) == "spell":
			fp_right_anchor.add_child(_open_arm("r"))
			_elbow_local_r = FP_ELBOW_OPEN
			_attach_spell_fx(fp_right_weapon_holder, rh)
		elif str(rh.get("category", "")) == "shield":
			fp_right_anchor.add_child(_arm("fp_arm_grip_r"))
			_elbow_local_r = FP_ELBOW_GRIP
			var rsh := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			rsh.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			rsh.scale = Vector3.ONE * 0.62
			_disable_shadows(rsh)
			fp_right_weapon_holder.add_child(rsh)
		else:
			fp_right_anchor.add_child(_arm("fp_arm_grip_r"))
			_elbow_local_r = FP_ELBOW_GRIP
			if not is_bow:
				var w_model := ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 0.9, 0.05))
				_right_single_edge = _is_single_edged(str(rh.get("model", "")))
				_disable_shadows(w_model)
				fp_right_weapon_holder.add_child(w_model)
				_blade_base = Node3D.new()
				_blade_base.position = Vector3(0.21, 0.80, 0.0) if is_two_hand else Vector3(0.0, 0.68, 0.0)
				fp_right_weapon_holder.add_child(_blade_base)
				_blade_tip = Node3D.new()
				_blade_tip.position = Vector3(0.25, 1.0, 0.0) if is_two_hand else Vector3(0.0, 0.9, 0.0)
				fp_right_weapon_holder.add_child(_blade_tip)
				if is_two_hand:
					_offhand_axe = true

	# --- LEFT HAND ---
	if is_bow:
		fp_left_weapon_holder = Node3D.new()
		fp_left_anchor.add_child(fp_left_weapon_holder)
		fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
		_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
		_bow_node = ModelLoader.instantiate_model(str(rh.get("model", "")), Vector3(0.05, 1.4, 0.1))
		_bow_node.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		_disable_shadows(_bow_node)
		fp_left_weapon_holder.add_child(_bow_node)
		_string_top = _bow_node.find_child("StringTop*", true, false) as Node3D
		_string_bot = _bow_node.find_child("StringBottom*", true, false) as Node3D
		if _string_top != null and _string_bot != null:
			_string_tip_top = _string_top.position
			_string_tip_bot = _string_bot.position
			_string_rest_z = _string_tip_top.z
		fp_nocked_arrow = ModelLoader.instantiate_model(GEAR_DIR + "arrow.glb", Vector3(0.02, 0.7, 0.02))
		fp_nocked_arrow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		_disable_shadows(fp_nocked_arrow)
		fp_left_anchor.add_child(fp_nocked_arrow)
	elif _offhand_axe:
		fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
		_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
	elif not lh.is_empty():
		fp_left_weapon_holder = Node3D.new()
		fp_left_anchor.add_child(fp_left_weapon_holder)
		var lcat := str(lh.get("category", ""))
		if lcat == "shield":
			fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
			_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
			var sh := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.8, 0.8, 0.1))
			sh.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			sh.scale = Vector3.ONE * 0.62
			_disable_shadows(sh)
			fp_left_weapon_holder.add_child(sh)
		elif lcat == "spell":
			fp_left_anchor.add_child(_open_arm("l"))
			_elbow_local_l = FP_ELBOW_OPEN
			_attach_spell_fx(fp_left_weapon_holder, lh)
		else:
			fp_left_anchor.add_child(_arm("fp_arm_grip_l"))
			_elbow_local_l = FP_ELBOW_GRIP * Vector3(-1.0, 1.0, 1.0)
			var lw := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.05, 0.9, 0.05))
			_left_single_edge = _is_single_edged(str(lh.get("model", "")))
			_disable_shadows(lw)
			fp_left_weapon_holder.add_child(lw)

	_refresh_tp_weapons(equipment)


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
	fp_spell_node = fx


func _refresh_tp_weapons(equipment: Dictionary) -> void:
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
			rsh.rotation_degrees = Vector3(0.0, -90.0, 0.0)
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
			sh.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			gl.add_child(sh)
		elif not lh.is_empty() and str(lh.get("category", "")) == "spell":
			gl.add_child(VfxFactory.make_glow(Color.html(str(lh.get("color", "#ff6a22"))), 0.3, 1.6))
		elif not lh.is_empty() and str(lh.get("category", "")) == "weapon":
			var lw := ModelLoader.instantiate_model(str(lh.get("model", "")), Vector3(0.05, 0.9, 0.05))
			lw.rotation_degrees = Vector3(0.0, -90.0, 0.0)
			gl.add_child(lw)


func update_frame(p: PlayerController, delta: float, move_amount: float, is_sprinting: bool) -> void:
	var dt := maxf(0.001, delta)
	var act_dt := dt
	if p._hitstop > 0.0:
		p._hitstop = maxf(0.0, p._hitstop - dt)
		act_dt = dt * 0.08
	p._move_blend = lerpf(p._move_blend, clampf(move_amount, 0.0, 1.0), clampf(dt * 10.0, 0.0, 1.0))
	p._sprint_blend = lerpf(p._sprint_blend, 1.0 if is_sprinting else 0.0, clampf(dt * 8.5, 0.0, 1.0))
	p._block_blend = lerpf(p._block_blend, 1.0 if p.is_blocking else 0.0, clampf(dt * 13.0, 0.0, 1.0))
	p._equip_raise = maxf(0.0, p._equip_raise - dt * 3.8)
	var target_draw := CombatMath.compute_bow_draw_ratio(p.bow_draw_time, p.player_cfg) if p.is_bow_drawing else 0.0
	if p.is_bow_drawing:
		p._draw_blend = lerpf(p._draw_blend, target_draw, clampf(dt * 14.0, 0.0, 1.0))
	else:
		p._draw_blend = lerpf(p._draw_blend, 0.0, clampf(dt * 32.0, 0.0, 1.0))
	var target_reach := 1.0 if (p.is_bow_drawing or p.is_right_holding) else 0.0
	p._bow_reach_blend = lerpf(p._bow_reach_blend, target_reach, clampf(dt * (12.0 if target_reach > 0.5 else 7.5), 0.0, 1.0))
	p._bow_twang_t = maxf(0.0, p._bow_twang_t - dt)
	p._bow_release_recoil = maxf(0.0, p._bow_release_recoil - dt * 3.4)
	p._look_sway = p._look_sway.lerp(Vector2.ZERO, clampf(dt * 8.5, 0.0, 1.0))
	p._camera_kick = maxf(0.0, p._camera_kick - dt * 4.2)
	p._shake = maxf(0.0, p._shake - dt * 3.2)
	p._shake_phase += dt * 47.0
	if p._move_blend > 0.02:
		p._walk_bob_phase = fmod(p._walk_bob_phase + dt * lerpf(7.8, 12.2, p._sprint_blend), TAU)
	if p._right_swing_t > 0.0:
		p._right_swing_t = maxf(0.0, p._right_swing_t - act_dt)
	if p._left_action_t > 0.0:
		p._left_action_t = maxf(0.0, p._left_action_t - act_dt)
	p._shield_hit_t = maxf(0.0, p._shield_hit_t - act_dt)
	if p._slash_vfx_timer > 0.0:
		p._slash_vfx_timer = maxf(0.0, p._slash_vfx_timer - act_dt)

	var bob_k := 1.0
	var shake_k := 1.0
	if GameSettings != null:
		bob_k = float(GameSettings.get_value("gameplay", "head_bob"))
		shake_k = float(GameSettings.get_value("gameplay", "camera_shake"))

	var rh: Dictionary = p.equipment.get("right_hand", {})
	var lh: Dictionary = p.equipment.get("left_hand", {})
	var is_bow := str(rh.get("weapon_type", "")) == "archery"
	var is_two_hand := bool(rh.get("two_handed", false)) and not is_bow
	var r_spell := str(rh.get("category", "")) == "spell"
	var r_shield := str(rh.get("category", "")) == "shield"

	var br_wave := sin(p._anim_time * 1.45) + 0.25 * sin(p._anim_time * 2.9 - 0.55)
	var breathe_x := cos(p._anim_time * 0.72) * 0.004
	var breathe_y := br_wave * 0.0065
	var walk_x := cos(p._walk_bob_phase) * 0.018 * p._move_blend * (1.0 + p._sprint_blend * 0.65) * bob_k
	var walk_y := (-cos(p._walk_bob_phase * 2.0 - 0.35) - 0.15) * 0.014 * p._move_blend * (1.0 + p._sprint_blend * 0.7) * bob_k
	var equip_drop := ease(p._equip_raise, 2.2) * 0.26
	fp_rig.position = Vector3(breathe_x + walk_x + p._look_sway.x, breathe_y + walk_y + p._look_sway.y - p._sprint_blend * 0.03 - equip_drop, 0.0)
	fp_rig.rotation_degrees = Vector3(p._look_sway.y * 38.0 - ease(p._equip_raise, 2.0) * 16.0, p._look_sway.x * 46.0, -p._look_sway.x * 28.0 - walk_x * 45.0)

	# --- RIGHT HAND (premade CC0 clips from res://data/fp_animations.json) ---
	var walk_u := fposmod(p._walk_bob_phase / TAU, 1.0)
	var r_key: Array = []
	if is_two_hand:
		r_key = sample_clip("axe_idle", p._anim_time * 0.36, true)
	elif r_spell:
		r_key = mirror_key(sample_clip("spell_idle_l", p._anim_time * 0.42, true))
	else:
		r_key = sample_clip("sword_idle", p._anim_time * 0.45, true)
		if p._move_blend > 0.01 and not is_bow and not r_shield and p._right_swing_t <= 0.0:
			var walk_k := sample_clip("sword_walk", walk_u, true)
			r_key = blend_keys(r_key, walk_k, clampf(p._move_blend * bob_k * (1.0 - p._sprint_blend), 0.0, 1.0))

	if p._sprint_blend > 0.01 and p._right_swing_t <= 0.0 and not is_bow and not r_spell and not r_shield:
		var sp_clip := "axe_sprint" if is_two_hand else "sword_sprint"
		var sprint_k := sample_clip(sp_clip, walk_u, true)
		r_key = blend_keys(r_key, sprint_k, ease(p._sprint_blend, -1.5))

	if p.is_right_holding and not is_bow and str(rh.get("category", "")) == "weapon" and p._right_swing_t <= 0.0:
		var charge := clampf(p.right_attack_hold / float(p.player_cfg["combat"]["power_attack_hold_sec"]), 0.0, 1.0)
		var ch_clip := "axe_charge" if is_two_hand else "sword_charge"
		var ch_k := sample_clip(ch_clip, ease(charge, -1.35), false)
		r_key = blend_keys(r_key, ch_k, clampf(charge * 4.0, 0.0, 1.0))
		var trem := maxf(0.0, charge - 0.6) / 0.4
		r_key = [(r_key[0] as Vector3) + Vector3(sin(p._anim_time * 36.0), cos(p._anim_time * 43.0), 0.0) * 0.0025 * trem, r_key[1], r_key[2]]

	if p._right_swing_t <= 0.0 and not p.is_right_holding and not is_bow and not r_spell and not r_shield:
		r_key = away_edge(r_key, 0.45 if is_two_hand else 0.55)

	if p._right_swing_t <= 0.0 or _swing_start_key.is_empty():
		_swing_start_key = r_key

	var target_cam_swing := Vector3.ZERO
	if p._right_swing_t > 0.0:
		var u := 1.0 - (p._right_swing_t / maxf(0.01, p._right_swing_dur))
		var sw := sin(u * PI)
		if r_spell:
			r_key = sample_oneshot("spell_cast_l", u, _swing_start_key, r_key, 0.10, 0.14, true)
		elif p._right_swing_power:
			var pw_clip := "axe_power" if is_two_hand else "sword_power"
			r_key = sample_oneshot(pw_clip, u, _swing_start_key, r_key, 0.10, 0.18, false)
			target_cam_swing = Vector3(-3.2 * sw, 0.4 * sw, 1.0 * sw)
		elif p._right_combo_step % 2 == 1:
			var l1_clip := "axe_light_1" if is_two_hand else "sword_light_1"
			r_key = sample_oneshot(l1_clip, u, _swing_start_key, r_key, 0.10, 0.16, false)
			target_cam_swing = Vector3(-1.2 * sw, 1.6 * sw, 1.6 * sw)
		else:
			var l2_clip := "axe_light_2" if is_two_hand else "sword_light_2"
			r_key = sample_oneshot(l2_clip, u, _swing_start_key, r_key, 0.10, 0.16, false)
			target_cam_swing = Vector3(-0.6 * sw, -1.8 * sw, -1.2 * sw)

	r_key = [(r_key[0] as Vector3) + Vector3(0.0, sin(p._walk_bob_phase + 0.6) * 0.004 * p._move_blend * bob_k, 0.0), r_key[1], r_key[2]]

	# --- LEFT HAND (premade CC0 clips from res://data/fp_animations.json) ---
	var l_key: Array = []
	var l_pos := Vector3(-0.36, -0.38, -0.56)
	var l_quat := Basis.from_euler(Vector3(-6.0, 22.0, -6.0) * (PI / 180.0)).get_rotation_quaternion()
	var lcat := str(lh.get("category", ""))
	if is_bow or _offhand_axe:
		pass
	elif lcat == "shield":
		var sp := _shield_pose(p)
		l_pos = sp[0]
		l_quat = sp[1]
	elif lcat == "spell":
		l_key = sample_clip("spell_idle_l", p._anim_time * 0.42 + 0.35, true)
		if p._left_action_t > 0.0:
			var u2 := 1.0 - (p._left_action_t / maxf(0.01, p._left_action_dur))
			l_key = sample_oneshot("spell_cast_l", u2, l_key, l_key, 0.10, 0.14, false)
	elif not lh.is_empty():
		var l_rest := sample_clip("sword_idle", p._anim_time * 0.45 + 0.4, true)
		if p._move_blend > 0.01 and p._left_action_t <= 0.0:
			l_rest = blend_keys(l_rest, sample_clip("sword_walk", fposmod(walk_u + 0.5, 1.0), true), clampf(p._move_blend * bob_k * (1.0 - p._sprint_blend), 0.0, 1.0))
		if p._sprint_blend > 0.01 and p._left_action_t <= 0.0:
			l_rest = blend_keys(l_rest, sample_clip("sword_sprint", fposmod(walk_u + 0.5, 1.0), true), ease(p._sprint_blend, -1.5))
		l_key = away_edge(mirror_key(l_rest), 0.55)
		if p._left_action_t > 0.0:
			var u3 := 1.0 - (p._left_action_t / maxf(0.01, p._left_action_dur))
			var sw3 := sin(u3 * PI)
			var l_clip := "sword_light_1" if p._left_combo_step % 2 == 1 else "sword_light_2"
			l_key = sample_oneshot(l_clip, u3, l_key, l_key, 0.10, 0.16, true)
			target_cam_swing += Vector3(-1.0 * sw3, -1.4 * sw3, -1.4 * sw3) if p._left_combo_step % 2 == 1 else Vector3(-0.5 * sw3, 1.6 * sw3, 1.1 * sw3)
	if not l_key.is_empty():
		l_key = [(l_key[0] as Vector3) + Vector3(0.0, sin(p._walk_bob_phase + 2.2) * 0.004 * p._move_blend * bob_k, 0.0), l_key[1], l_key[2]]
	l_pos.y += sin(p._walk_bob_phase + 2.2) * 0.006 * p._move_blend * bob_k

	# Apply camera bob, shake & subtle melee swing coupling in first-person
	p._cam_swing_rot = p._cam_swing_rot.lerp(target_cam_swing * shake_k, clampf(dt * 14.0, 0.0, 1.0))
	if p.camera_mode == "first_person":
		var target_fov := p._base_fov() + (p._sprint_blend * 5.0) - (p._draw_blend * 14.0)
		p.camera.fov = lerpf(p.camera.fov, target_fov, clampf(dt * 10.0, 0.0, 1.0))
		var head_bob_y := sin(p._walk_bob_phase * 2.0) * 0.028 * p._move_blend * (1.0 + p._sprint_blend * 0.5) * bob_k
		var head_bob_x := cos(p._walk_bob_phase) * 0.015 * p._move_blend * bob_k
		var sh := Vector3(sin(p._shake_phase * 1.3), sin(p._shake_phase * 1.7 + 1.0), 0.0) * p._shake * 0.035
		p.camera.position = Vector3(head_bob_x, head_bob_y, 0.0) + sh
		p.camera.rotation_degrees = Vector3(
			p._camera_kick * 1.6 + sh.y * 30.0 + p._cam_swing_rot.x,
			sh.x * 20.0 + p._cam_swing_rot.y,
			-head_bob_x * 20.0 + sin(p._shake_phase) * p._shake * 1.5 + p._cam_swing_rot.z
		)

	# --- Pose the rig ---
	if is_bow:
		_pose_bow(p)
	elif is_two_hand:
		_pose_two_hand(r_key)
	elif r_spell:
		_pose_palm(fp_right_anchor, r_key)
	elif r_shield:
		var rsp := _shield_pose(p)
		fp_right_anchor.transform = Transform3D(mirror_basis(Basis(rsp[1] as Quaternion)), (rsp[0] as Vector3) * Vector3(-1.0, 1.0, 1.0))
		if fp_right_weapon_holder != null:
			fp_right_weapon_holder.basis = Basis()
	elif not rh.is_empty():
		_pose_fist(fp_right_anchor, fp_right_weapon_holder, r_key, false, _right_single_edge)
	else:
		var unarmed_k := sample_clip("sword_idle", p._anim_time * 0.45, true)
		fp_right_anchor.transform = Transform3D(fist_basis(unarmed_k[0], unarmed_k[1], false), unarmed_k[0])
	if not is_bow and not is_two_hand:
		if lcat == "spell":
			_pose_palm(fp_left_anchor, l_key)
		elif not l_key.is_empty():
			_pose_fist(fp_left_anchor, fp_left_weapon_holder, l_key, true, _left_single_edge)
		else:
			fp_left_anchor.transform = Transform3D(Basis(l_quat), l_pos)
	_pose_upper_arm(_fp_upper_r, fp_right_anchor, _elbow_local_r, false)
	_pose_upper_arm(_fp_upper_l, fp_left_anchor, _elbow_local_l, true)

	# --- Spell glow breathing ---
	if _spell_fx != null and is_instance_valid(_spell_fx):
		var cast_pulse := 0.0
		if p._left_action_t > 0.0 or p._right_swing_t > 0.0:
			cast_pulse = 1.0
		_spell_fx.scale = Vector3.ONE * (1.0 + sin(p._anim_time * 5.0) * 0.06 + cast_pulse * 0.35)
		if _spell_light != null:
			_spell_light.light_energy = 0.8 + sin(p._anim_time * 7.3) * 0.12 + cast_pulse * 1.4

	_update_blade_trail(p)

	# --- 3RD-PERSON SKELETAL ANIMATION ---
	if tp_visual != null and tp_visual.visible:
		p._tp_action_lock = maxf(0.0, p._tp_action_lock - dt)
		var horiz_spd := Vector2(p.velocity.x, p.velocity.z).length()
		var armed := not rh.is_empty() or not lh.is_empty()
		var st := "idle_combat" if (armed and tp_visual.has_anim("idle_combat")) else "idle"
		if p._tp_dual_wield() and tp_visual.has_anim("idle_dual"):
			st = "idle_dual"
		var play_spd := 1.0
		if p.is_blocking and horiz_spd < 2.2:
			st = "block"
		elif p.is_bow_drawing and horiz_spd < 2.2:
			st = "draw_hold"
		elif p._move_blend > 0.12:
			var use_run := p._sprint_blend > 0.35 or horiz_spd > 4.2
			st = "run" if use_run else "walk"
			play_spd = clampf(horiz_spd / (3.4 if use_run else 1.85), 0.75, 1.65)
		tp_visual.play_state(st, 0.18, play_spd)
		_update_tp_bowstring(p)


func _update_tp_bowstring(p: PlayerController) -> void:
	if _tp_bow_node == null or not is_instance_valid(_tp_bow_node):
		return
	var drawing := p.is_bow_drawing and (tp_visual.state == "draw_hold" or p._draw_blend > 0.1)
	var nock_local := Vector3(0.0, 0.0, _tp_string_rest_z)
	if drawing and _tp_grip_r != null and is_instance_valid(_tp_grip_r):
		var p_local := _tp_bow_node.to_local(_tp_grip_r.global_position)
		var pull_z := clampf(p_local.z, _tp_string_rest_z - 0.52, _tp_string_rest_z)
		nock_local = Vector3(clampf(p_local.x, -0.04, 0.04), clampf(p_local.y, -0.05, 0.08), pull_z)
	if _tp_string_top != null and _tp_string_bot != null:
		aim_segment(_tp_string_top, _tp_string_tip_top, nock_local)
		aim_segment(_tp_string_bot, _tp_string_tip_bot, nock_local)
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


func _shield_pose(p: PlayerController) -> Array:
	var rest_p := Vector3(-0.50, -0.44, -0.62)
	var rest_q := Basis.from_euler(Vector3(-8.0, 58.0, -14.0) * (PI / 180.0)).get_rotation_quaternion()
	var blk_p := Vector3(-0.24, -0.27, -0.56)
	var blk_q := Basis.from_euler(Vector3(2.0, 18.0, -6.0) * (PI / 180.0)).get_rotation_quaternion()
	var be := ease(p._block_blend, -1.6)
	var pos := rest_p.lerp(blk_p, be)
	var quat := rest_q.slerp(blk_q, be)
	if p._sprint_blend > 0.01 and p._block_blend < 0.2:
		pos += Vector3(0.06, -0.06, 0.05) * p._sprint_blend
	if p._shield_hit_t > 0.0:
		var bu := clampf(1.0 - (p._shield_hit_t / 0.16), 0.0, 1.0)
		var sh_disp := sample_curve("shield_hit", bu)
		var imp := sin(minf(1.0, bu * 2.2) * PI * 0.5) * exp(-bu * 3.2)
		pos += sh_disp * 0.65 + Vector3(-0.015, -0.02, 0.09) * imp
		quat = quat * Basis.from_euler(Vector3(16.0, 12.0, -8.0) * imp * (PI / 180.0)).get_rotation_quaternion()
	return [pos, quat]


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


func _pose_fist(anchor: Node3D, holder: Node3D, key: Array, left: bool, single_edge: bool) -> void:
	var pos: Vector3 = key[0]
	var b := fist_basis(pos, key[1], left)
	anchor.transform = Transform3D(b, pos)
	if holder == null or not is_instance_valid(holder):
		return
	var e := b.inverse() * (key[2] as Vector3)
	if not single_edge and e.x < 0.0:
		e = -e
	if Vector2(e.x, e.z).length() < 0.001:
		holder.basis = Basis()
	else:
		holder.basis = Basis(Vector3.UP, atan2(-e.z, e.x))


func _pose_two_hand(key: Array) -> void:
	var h := (key[1] as Vector3).normalized()
	var e := key[2] as Vector3
	e = e - h * e.dot(h)
	if e.length() < 0.001:
		e = Vector3.FORWARD.cross(h)
	e = e.normalized()
	var pr: Vector3 = key[0]
	var pl := pr - h * (FP_AXE_HAND_R - FP_AXE_HAND_L)
	fp_right_anchor.transform = Transform3D(fist_basis(pr, h, false), pr)
	fp_left_anchor.transform = Transform3D(fist_basis(pl, h, true), pl)
	if fp_right_weapon_holder != null:
		var w := Transform3D(Basis(e, h, e.cross(h)), pr - h * FP_AXE_HAND_R)
		fp_right_weapon_holder.transform = fp_right_anchor.transform.affine_inverse() * w


func _pose_palm(anchor: Node3D, key: Array) -> void:
	var palm := (key[1] as Vector3).normalized()
	var fingers := key[2] as Vector3
	fingers = (fingers - palm * fingers.dot(palm)).normalized()
	var z := -palm
	anchor.transform = Transform3D(Basis(fingers.cross(z), fingers, z), key[0])


func _pose_bow(p: PlayerController) -> void:
	var reach := ease(clampf(p._bow_reach_blend, 0.0, 1.0), -1.6)
	var rec := clampf(p._bow_release_recoil, 0.0, 1.0)
	var raise := maxf(reach, ease(rec, 0.5))
	var draw_u := clampf(p._draw_blend, 0.0, 1.0)
	var bd := sample_curve("bow_draw", draw_u)
	var pull := clampf(lerpf(draw_u, bd.x, 0.65), 0.0, 1.0) * reach
	var k := blend_keys(FP_BOW_IDLE, FP_BOW_AIM, raise)
	var kick := rec * rec
	var rel_off := sample_curve("bow_release", 1.0 - rec) if rec > 0.01 else Vector3.ZERO
	var bow_pos: Vector3 = (k[0] as Vector3) + Vector3(bd.y * 0.25, bd.z * 0.25, 0.0) * reach + (Vector3(-0.006, -0.012, -0.03) + rel_off * 0.22) * kick
	if pull > 0.75:
		bow_pos += Vector3(sin(p._anim_time * 2.1), cos(p._anim_time * 1.7), 0.0) * 0.002 * (pull - 0.75) / 0.25
	var bow_axis := ((k[1] as Vector3) + Vector3(0.0, 0.0, -0.25) * kick).normalized()
	var lb := fist_basis(bow_pos, bow_axis, true)
	fp_left_anchor.transform = Transform3D(lb, bow_pos)
	if fp_left_weapon_holder == null or _bow_node == null:
		return
	var bb := lb.inverse() * (k[2] as Vector3)
	fp_left_weapon_holder.basis = Basis(Vector3.UP, atan2(-bb.x, -bb.z))

	var bow_rig := fp_left_anchor.transform * fp_left_weapon_holder.transform * _bow_node.transform
	var rest_a := bow_rig * Vector3(0.026, 0.055, 0.0)
	var rest_b := bow_rig * Vector3(-0.026, 0.055, 0.0)
	var arrow_rest := rest_a if rest_a.x > rest_b.x else rest_b
	var string_rest := bow_rig * Vector3(0.0, 0.055, _string_rest_z)
	var anchor_pt := arrow_rest + FP_BOW_ANCHOR
	var nock := string_rest.lerp(anchor_pt, pull)
	if p._bow_twang_t > 0.0 and pull < 0.05:
		var tw_u := 0.32 - p._bow_twang_t
		nock += (string_rest - arrow_rest).normalized() * sin(tw_u * 75.0) * exp(-tw_u * 13.0) * 0.03
	var nock_local := bow_rig.affine_inverse() * nock
	if _string_top != null and _string_bot != null:
		aim_segment(_string_top, _string_tip_top, nock_local)
		aim_segment(_string_bot, _string_tip_bot, nock_local)

	if fp_nocked_arrow != null:
		var nocked := reach > 0.55 and rec < 0.05
		fp_nocked_arrow.visible = nocked
		if nocked:
			var span := arrow_rest - nock
			var dir := (k[2] as Vector3).normalized().slerp(span.normalized(), clampf(span.length() / 0.2, 0.0, 1.0)).normalized()
			var x_axis := dir.cross(Vector3.UP)
			x_axis = x_axis.normalized() if x_axis.length() > 0.1 else Vector3.RIGHT
			var arrow_rig := Transform3D(Basis(x_axis, dir, x_axis.cross(dir).normalized()), nock + dir * 0.352)
			fp_nocked_arrow.transform = fp_left_anchor.transform.affine_inverse() * arrow_rig

	var hand_pos := FP_BOW_HAND_REST.lerp(nock + FP_BOW_HOOK, ease(reach, -1.4))
	if rec > 0.01 and not p.is_bow_drawing:
		hand_pos = FP_BOW_HAND_REST.lerp(anchor_pt + FP_BOW_HOOK + Vector3(0.05, 0.01, 0.09), ease(rec, 0.7))
	var draw_pole := Vector3(1.0, -0.15, 0.6)
	fp_right_anchor.transform = Transform3D(fist_basis(hand_pos, bow_axis, false, draw_pole), hand_pos)


func _update_blade_trail(p: PlayerController) -> void:
	var im := _trail.mesh as ImmediateMesh
	if im == null:
		return
	im.clear_surfaces()
	var swinging := p._right_swing_t > 0.0 and _blade_tip != null and is_instance_valid(_blade_tip) and p.camera_mode == "first_person"
	if swinging:
		var inv := p.camera.global_transform.affine_inverse()
		var u := 1.0 - (p._right_swing_t / maxf(0.01, p._right_swing_dur))
		var u0 := 0.12 if p._swing_was_charged else 0.22
		if u > u0 and u < 0.64:
			_trail_pts.push_front([inv * _blade_base.global_position, inv * _blade_tip.global_position, p._anim_time])
	while not _trail_pts.is_empty() and (p._anim_time - float(_trail_pts.back()[2]) > TRAIL_LIFE or _trail_pts.size() > 12):
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


# --- Premade CC0 First-Person Clip Bank (D-060 / FB-025) ----------------------

static func get_fp_bank() -> Dictionary:
	if _fp_bank.is_empty():
		var txt := FileAccess.get_file_as_string(FP_ANIMS_PATH)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			var clips_out: Dictionary = {}
			var raw_clips: Dictionary = parsed.get("clips", {})
			for k in raw_clips:
				var c: Dictionary = raw_clips[k]
				var frames_out: Array = []
				for fr in c.get("frames", []):
					var p: Array = fr[0]
					var d: Array = fr[1]
					var e: Array = fr[2]
					frames_out.append([
						Vector3(float(p[0]), float(p[1]), float(p[2])),
						Vector3(float(d[0]), float(d[1]), float(d[2])),
						Vector3(float(e[0]), float(e[1]), float(e[2])),
					])
				clips_out[k] = {
					"source": str(c.get("source", "")),
					"license": str(c.get("license", "")),
					"fps": float(c.get("fps", 30.0)),
					"frames": frames_out,
				}
			var curves_out: Dictionary = {}
			var raw_curves: Dictionary = parsed.get("curves", {})
			for k in raw_curves:
				var cv: Dictionary = raw_curves[k]
				var pts: Array = []
				for s in cv.get("samples", []):
					pts.append(Vector3(float(s[0]), float(s[1]), float(s[2])))
				curves_out[k] = {"source": str(cv.get("source", "")), "samples": pts}
			_fp_bank = {
				"schema": str(parsed.get("schema", "")),
				"license": str(parsed.get("license", "")),
				"sources": parsed.get("sources", []),
				"clips": clips_out,
				"curves": curves_out,
			}
	return _fp_bank


static func sample_clip(clip_name: String, u: float, cyclic: bool = false) -> Array:
	var bank := get_fp_bank()
	var clips: Dictionary = bank.get("clips", {})
	if not clips.has(clip_name):
		return [Vector3(0.27, -0.29, -0.50), Vector3(-0.10, 0.88, -0.46).normalized(), Vector3(0.0, 0.46, -0.88).normalized()]
	var frames: Array = clips[clip_name]["frames"]
	var n := frames.size()
	if n <= 1:
		return frames[0]
	var t_u := fposmod(u, 1.0) if cyclic else clampf(u, 0.0, 1.0)
	var pos := t_u * float(n - 1)
	var i0 := int(floor(pos))
	var i1 := mini(n - 1, i0 + 1)
	var frac := pos - float(i0)
	return blend_keys(frames[i0], frames[i1], frac)


static func sample_oneshot(clip_name: String, u: float, start_key: Array, end_key: Array, blend_in: float = 0.10, blend_out: float = 0.16, mirror_x: bool = false) -> Array:
	var k := sample_clip(clip_name, u, false)
	if mirror_x:
		k = mirror_key(k)
	if blend_in > 0.0 and u < blend_in and not start_key.is_empty():
		var wi := smoothstep(0.0, blend_in, u)
		k = blend_keys(start_key, k, wi)
	if blend_out > 0.0 and u > 1.0 - blend_out and not end_key.is_empty():
		var wo := smoothstep(1.0 - blend_out, 1.0, u)
		k = blend_keys(k, end_key, wo)
	return k


static func sample_curve(curve_name: String, u: float) -> Vector3:
	var bank := get_fp_bank()
	var curves: Dictionary = bank.get("curves", {})
	if not curves.has(curve_name):
		return Vector3.ZERO
	var pts: Array = curves[curve_name]["samples"]
	var n := pts.size()
	if n == 0:
		return Vector3.ZERO
	if n == 1:
		return pts[0]
	var pos := clampf(u, 0.0, 1.0) * float(n - 1)
	var i0 := int(floor(pos))
	var i1 := mini(n - 1, i0 + 1)
	return (pts[i0] as Vector3).lerp(pts[i1] as Vector3, pos - float(i0))


# --- Pure Math & Rig Helpers --------------------------------------------------

func _arm(model_name: String) -> Node3D:
	var a := ModelLoader.instantiate_model(GEAR_DIR + model_name + ".glb", Vector3(0.12, 0.12, 0.4))
	a.name = "Arm"
	_disable_shadows(a)
	return a


func _open_arm(side: String) -> Node3D:
	var a := _arm("fp_arm_open_" + ("l" if side == "r" else "r"))
	a.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	return a


static func _is_single_edged(model_path: String) -> bool:
	return model_path.contains("axe") or model_path.contains("cleaver") or model_path.contains("seax")


static func _disable_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_shadows(c)


static func hand_basis(grip_dir: Vector3, forearm_dir: Vector3) -> Basis:
	var y := grip_dir.normalized()
	var z := forearm_dir - y * forearm_dir.dot(y)
	if z.length() < 0.001:
		z = Vector3.BACK
	z = z.normalized()
	return Basis(y.cross(z).normalized(), y, z)


static func ik_elbow(shoulder: Vector3, hand: Vector3, pole: Vector3) -> Vector3:
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


static func fist_basis(hand: Vector3, grip_dir: Vector3, left: bool, pole_override: Vector3 = Vector3.ZERO) -> Basis:
	var s := -1.0 if left else 1.0
	var shoulder := Vector3(FP_SHOULDER.x * s, FP_SHOULDER.y, FP_SHOULDER.z)
	var pole := pole_override if pole_override != Vector3.ZERO else Vector3(FP_ELBOW_POLE.x * s, FP_ELBOW_POLE.y, FP_ELBOW_POLE.z)
	var forearm := (ik_elbow(shoulder, hand, pole) - hand).normalized()
	var g := grip_dir.normalized()
	# When a horizontal slash drives the blade nearly straight forward (-Z), forearm and -grip_dir
	# become nearly collinear and Gram-Schmidt projection can flip +Z upward above the wrist.
	# Smoothly biasing toward the downward-outward elbow pole keeps the elbow anatomically low.
	var anti := clampf((-g.dot(forearm) - 0.45) / 0.45, 0.0, 1.0)
	if anti > 0.0:
		forearm = (forearm + pole.normalized() * (anti * 1.15)).normalized()
	return hand_basis(g, forearm)


static func away_edge(k: Array, reach: float) -> Array:
	var blade_mid := (k[0] as Vector3) + (k[1] as Vector3).normalized() * reach
	return [k[0], k[1], blade_mid.normalized()]


static func mirror_key(k: Array) -> Array:
	var m := Vector3(-1.0, 1.0, 1.0)
	return [(k[0] as Vector3) * m, (k[1] as Vector3) * m, (k[2] as Vector3) * m]


static func mirror_keys(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		out.append(mirror_key(k))
	return out


static func blend_keys(a: Array, b: Array, t: float) -> Array:
	return [
		(a[0] as Vector3).lerp(b[0] as Vector3, t),
		(a[1] as Vector3).normalized().slerp((b[1] as Vector3).normalized(), t),
		(a[2] as Vector3).normalized().slerp((b[2] as Vector3).normalized(), t),
	]


static func mirror_basis(b: Basis) -> Basis:
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	return m * b * m


static func aim_segment(seg: Node3D, tip: Vector3, target: Vector3) -> void:
	var d := target - tip
	var ln := d.length()
	if ln < 0.0005:
		return
	var y := d / ln
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	seg.transform = Transform3D(Basis(x, y * ln, z), tip)
