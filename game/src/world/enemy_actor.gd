class_name EnemyActor
extends CharacterBody3D
## 3D Enemy & Floor Boss Actor (Phase 6 + rigged skeletal animation).
## Implements aggro, melee/ranged attacks, Safe Room repulsion (D-021),
## Boss Arena dormancy/enrage phases (D-022) and lootable corpses.
## Presentation: rigged Blender character (CharacterVisual) with cross-faded idle/walk/run,
## telegraphed attack clips whose impact frame lands exactly when damage resolves,
## hit flinches + flashes, death falls that remain as lootable bodies, and a sleek health bar.

enum AiState { DORMANT, IDLE, CHASE, ATTACK, FLEE_SAFE_ZONE, DEAD }

## Seconds from the start of each attack clip to its impact frame (clip timing authored in Blender).
const IMPACT_TIME := {"attack_1h": 0.47, "attack_2h": 0.6, "shoot": 1.08, "slam": 0.6}

var enemy_id: String = ""
var display_name: String = "Enemy"
var archetype: String = "melee"
var is_boss: bool = false
var room_id: int = -1
var floor_number: int = 1

var max_health: float = 60.0
var current_health: float = 60.0
var damage: float = 12.0
var armor: float = 6.0
var move_speed: float = 3.8
var aggro_radius: float = 13.0
var attack_range: float = 2.2
var preferred_distance: float = 1.8
var attack_cooldown_sec: float = 1.4
var projectile_speed: float = 20.0
var enrage_hp_threshold: float = 0.5
var enrage_speed_mult: float = 1.35
var enrage_damage_mult: float = 1.3
var xp_reward: int = 40
var gold_min: int = 8
var gold_max: int = 18
var loot_drop_chance: float = 0.5
var guaranteed_rarity: String = ""

var state: AiState = AiState.IDLE
var enraged: bool = false
var spawn_pos: Vector3 = Vector3.ZERO
var visual: CharacterVisual = null
var _attack_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _anim_time: float = 0.0
var _attack_clip: String = "attack"
var _impact_time: float = 0.47
var _attack_anim_started: bool = false
var _roared: bool = false
var _health_bar: Node3D = null
var _health_fill: MeshInstance3D = null
var _health_lag: MeshInstance3D = null
var _name_label: Label3D = null
var _lag_ratio: float = 1.0
var _bar_visible_t: float = 0.0
var _boss_ember_light: OmniLight3D = null
var _height: float = 1.85
var _bow_node: Node3D = null
var _string_top: Node3D = null
var _string_bot: Node3D = null
var _string_tip_top: Vector3 = Vector3.ZERO
var _string_tip_bot: Vector3 = Vector3.ZERO
var _string_rest_z: float = 0.0
var _nocked_arrow: Node3D = null
var _grip_r_node: Node3D = null
var _stride_walk_mps: float = 1.65
var _stride_run_mps: float = 4.2

var _layout: DungeonGenerator.FloorLayout = null
var _player_ref: Node3D = null
var _rng: SeededRng = null
var _on_attack_player: Callable = Callable()
var _on_shoot_projectile: Callable = Callable()
var _on_died: Callable = Callable()


func setup(
	enemy_def: Dictionary,
	scaling_cfg: Dictionary,
	p_floor_number: int,
	p_room_id: int,
	p_spawn_pos: Vector3,
	p_layout: DungeonGenerator.FloorLayout,
	p_player: Node3D,
	p_rng: SeededRng,
	callbacks: Dictionary
) -> void:
	enemy_id = str(enemy_def["id"])
	display_name = str(enemy_def["name"])
	archetype = str(enemy_def.get("archetype", "melee"))
	is_boss = bool(enemy_def.get("is_boss", false))
	room_id = p_room_id
	floor_number = p_floor_number
	spawn_pos = p_spawn_pos
	_layout = p_layout
	_player_ref = p_player
	_rng = p_rng
	_on_attack_player = callbacks.get("attack_player", Callable())
	_on_shoot_projectile = callbacks.get("shoot_projectile", Callable())
	_on_died = callbacks.get("died", Callable())

	var depth := float(maxi(0, floor_number - 1))
	var hp_scale := pow(float(scaling_cfg.get("health_per_floor", 1.32)), depth)
	var dmg_scale := pow(float(scaling_cfg.get("damage_per_floor", 1.22)), depth)
	var xp_scale := pow(float(scaling_cfg.get("xp_per_floor", 1.35)), depth)
	var gold_scale := pow(float(scaling_cfg.get("gold_per_floor", 1.25)), depth)

	max_health = snappedf(float(enemy_def["max_health"]) * hp_scale, 1.0)
	current_health = max_health
	damage = snappedf(float(enemy_def["damage"]) * dmg_scale, 0.5)
	armor = float(enemy_def.get("armor", 5.0))
	move_speed = float(enemy_def.get("move_speed", 3.6))
	aggro_radius = float(enemy_def.get("aggro_radius", 13.0))
	attack_range = float(enemy_def.get("attack_range", 2.2))
	preferred_distance = float(enemy_def.get("preferred_distance", 1.8))
	attack_cooldown_sec = float(enemy_def.get("attack_cooldown_sec", 1.4))
	projectile_speed = float(enemy_def.get("projectile_speed", 20.0))
	enrage_hp_threshold = float(enemy_def.get("enrage_hp_threshold", 0.5))
	enrage_speed_mult = float(enemy_def.get("enrage_speed_multiplier", 1.35))
	enrage_damage_mult = float(enemy_def.get("enrage_damage_multiplier", 1.3))
	xp_reward = int(round(float(enemy_def.get("xp_reward", 35)) * xp_scale))
	gold_min = int(round(float(enemy_def.get("gold_min", 8)) * gold_scale))
	gold_max = int(round(float(enemy_def.get("gold_max", 18)) * gold_scale))
	loot_drop_chance = float(enemy_def.get("loot_drop_chance", 0.45))
	guaranteed_rarity = str(enemy_def.get("guaranteed_rarity", ""))
	_anim_time = _rng.next_float("ai") * TAU if _rng != null else 0.0

	state = AiState.DORMANT if is_boss else AiState.IDLE

	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
	collision_layer = 1
	collision_mask = 1

	var radius := float(enemy_def.get("radius", 0.5))
	_height = float(enemy_def.get("height", 1.85))
	# Natural clip stride velocity matching char_anims.py (4*stride_half / clip_duration)
	var leg_len := _height * 0.48
	var g_mult := 1.08 if archetype == "charger" else 1.0
	_stride_walk_mps = maxf(0.8, (4.0 * 0.30 * leg_len * g_mult) / (32.0 / 30.0))
	_stride_run_mps = maxf(1.5, (4.0 * 0.48 * leg_len * g_mult) / (20.0 / 30.0))

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = _height
	col.shape = cap
	col.position.y = _height * 0.5
	add_child(col)

	var vdef: Dictionary = enemy_def.get("visual", {})
	var kind := str(vdef.get("kind", str(enemy_def.get("model", "")).get_file().get_basename()))
	visual = CharacterVisual.create(kind)
	add_child(visual)
	_grip_r_node = visual.model.find_child("GripR*", true, false) as Node3D
	var weapon_path := str(vdef.get("weapon", ""))
	if not weapon_path.is_empty():
		var w := ModelLoader.instantiate_model(weapon_path, Vector3(0.1, 0.8, 0.1))
		w.scale = Vector3.ONE * float(vdef.get("weapon_scale", 1.0))
		var grip_name := "GripL" if str(vdef.get("weapon_hand", "r")) == "l" else "GripR"
		var grip := visual.model.find_child(grip_name + "*", true, false) as Node3D
		if grip != null:
			grip.add_child(w)
		else:
			visual.attach_to_bone("hand_" + str(vdef.get("weapon_hand", "r")), w)
		if archetype == "ranged":
			_bow_node = w
			_string_top = w.find_child("StringTop*", true, false) as Node3D
			_string_bot = w.find_child("StringBottom*", true, false) as Node3D
			if _string_top != null and _string_bot != null:
				_string_tip_top = _string_top.position
				_string_tip_bot = _string_bot.position
				_string_rest_z = _string_tip_top.z
			_nocked_arrow = ModelLoader.instantiate_model("res://assets/models/gear/arrow.glb", Vector3(0.02, 0.7, 0.02))
			_nocked_arrow.visible = false
			w.add_child(_nocked_arrow)
	if archetype == "ranged":
		_attack_clip = "shoot"
	elif is_boss:
		_attack_clip = "slam" if visual.has_anim("slam") else "attack"
	else:
		_attack_clip = "attack"
	var key := "shoot" if _attack_clip == "shoot" else ("slam" if _attack_clip == "slam" else ("attack_2h" if kind in ["draugr", "iron_warden"] else "attack_1h"))
	_impact_time = float(IMPACT_TIME.get(key, 0.47))
	visual.play_state("idle", 0.0)
	if visual.anim != null and visual.has_anim("idle"):
		visual.anim.seek(fmod(_anim_time, 2.0), true)

	if is_boss:
		_boss_ember_light = OmniLight3D.new()
		_boss_ember_light.position = Vector3(0.0, 2.05, 0.9)
		_boss_ember_light.light_color = Color(1.0, 0.5, 0.2)
		_boss_ember_light.light_energy = 1.4
		_boss_ember_light.omni_range = 5.5
		_boss_ember_light.shadow_enabled = false
		var core_socket := visual.model.find_child("CoreSocket*", true, false) as Node3D
		if core_socket != null:
			core_socket.add_child(_boss_ember_light)
			_boss_ember_light.position = Vector3(0, 0, 0.2)
			var glow := VfxFactory.make_glow(Color(1.0, 0.45, 0.15), 0.9, 1.4)
			core_socket.add_child(glow)
		else:
			add_child(_boss_ember_light)
	else:
		_build_health_bar()
	if kind == "goblin_streamer":
		var ring := visual.model.find_child("RingLight*", true, false) as Node3D
		if ring != null:
			var rl := OmniLight3D.new()
			rl.light_color = Color(1.0, 0.35, 0.85)
			rl.light_energy = 1.2
			rl.omni_range = 3.5
			ring.add_child(rl)
	global_position = spawn_pos


func _build_health_bar() -> void:
	_health_bar = Node3D.new()
	_health_bar.name = "HealthBar"
	_health_bar.position = Vector3(0.0, _height + 0.38, 0.0)
	add_child(_health_bar)
	var mk := func(col: Color, w: float, h: float, z: float, pri: int) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = col
		m.no_depth_test = true
		m.render_priority = pri
		q.material = m
		mi.mesh = q
		mi.position.z = z
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi
	_health_bar.add_child(mk.call(Color(0.02, 0.02, 0.03, 0.78), 0.86, 0.085, 0.0, 1))
	_health_lag = mk.call(Color(1.0, 0.85, 0.55, 0.85), 0.82, 0.05, 0.001, 2)
	_health_bar.add_child(_health_lag)
	_health_fill = mk.call(Color(0.86, 0.16, 0.12, 1.0), 0.82, 0.05, 0.002, 3)
	_health_bar.add_child(_health_fill)
	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.font_size = 26
	_name_label.pixel_size = 0.0042
	_name_label.outline_size = 8
	_name_label.modulate = Color(0.95, 0.9, 0.8)
	_name_label.outline_modulate = Color(0, 0, 0, 0.85)
	_name_label.position = Vector3(0, 0.12, 0)
	_name_label.render_priority = 4
	if UiTheme.font_ui() != null:
		_name_label.font = UiTheme.font_ui()
	_health_bar.add_child(_name_label)
	_health_bar.visible = false


func _update_health_bar(delta: float, dist: float) -> void:
	if _health_bar == null:
		return
	var ratio := clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	_lag_ratio = move_toward(_lag_ratio, ratio, delta * 0.6) if _lag_ratio > ratio else ratio
	_health_fill.scale.x = maxf(0.001, ratio)
	_health_fill.position.x = -0.41 * (1.0 - ratio)
	_health_lag.scale.x = maxf(0.001, _lag_ratio)
	_health_lag.position.x = -0.41 * (1.0 - _lag_ratio)
	_bar_visible_t = maxf(0.0, _bar_visible_t - delta)
	var mode := str(GameSettings.get_value("gameplay", "enemy_health_bars")) if GameSettings != null else "damaged"
	var show := false
	match mode:
		"always":
			show = dist <= 18.0
		"never":
			show = false
		_:
			show = (current_health < max_health or _bar_visible_t > 0.0) and dist <= 22.0
	_health_bar.visible = show and state != AiState.DEAD


func wake_boss() -> void:
	if state == AiState.DORMANT:
		state = AiState.CHASE
		if not _roared and visual != null and visual.play_action("roar", 0.15):
			_roared = true
			_attack_timer = maxf(_attack_timer, 1.6)


func step_ai(delta: float, is_paused: bool) -> void:
	if is_paused or state == AiState.DEAD or _player_ref == null or not is_instance_valid(_player_ref):
		return

	_anim_time += delta
	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)

	if state == AiState.DORMANT:
		_update_animation(delta, 0.0)
		return

	var player_pos := _player_ref.global_position
	var player_in_safe := _layout != null and _layout.is_world_in_safe_room(player_pos)

	if player_in_safe and not is_boss:
		state = AiState.FLEE_SAFE_ZONE
		var retreat_dir := (spawn_pos - global_position)
		retreat_dir.y = 0.0
		if retreat_dir.length() > 0.6:
			var spd := move_speed * 1.15
			velocity.x = retreat_dir.normalized().x * spd
			velocity.z = retreat_dir.normalized().z * spd
			_face_dir(retreat_dir, delta)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		velocity.y = -4.0 if not is_on_floor() else 0.0
		move_and_slide()
		_update_animation(delta, Vector2(velocity.x, velocity.z).length())
		return

	var to_player := player_pos - global_position
	var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
	var dist := flat_to_player.length()
	_update_health_bar(delta, dist)

	if state == AiState.FLEE_SAFE_ZONE:
		state = AiState.IDLE

	if state == AiState.IDLE:
		if dist <= aggro_radius:
			state = AiState.CHASE
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			velocity.y = -4.0 if not is_on_floor() else 0.0
			move_and_slide()
			_update_animation(delta, 0.0)
			return

	var eff_speed := move_speed * (enrage_speed_mult if enraged else 1.0)
	if visual != null and visual.oneshot == "roar":
		eff_speed = 0.0
	_face_dir(flat_to_player, delta)

	if dist <= attack_range:
		state = AiState.ATTACK
		if archetype == "ranged" and dist < preferred_distance * 0.65:
			var back := -flat_to_player.normalized()
			velocity.x = back.x * eff_speed * 0.65
			velocity.z = back.z * eff_speed * 0.65
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		# Start the attack clip so its impact frame lands exactly when the strike resolves
		if not _attack_anim_started and _attack_timer <= _impact_time / _anim_speed():
			_attack_anim_started = true
			if visual != null:
				visual.play_action(_attack_clip, 0.1, _anim_speed())
		if _attack_timer <= 0.0:
			_perform_attack(flat_to_player)
	else:
		state = AiState.CHASE
		var dir := flat_to_player.normalized()
		var next_probe := global_position + dir * 1.1
		if not is_boss and _layout != null and _layout.is_world_in_safe_room(next_probe):
			state = AiState.FLEE_SAFE_ZONE
			velocity.x = -dir.x * eff_speed
			velocity.z = -dir.z * eff_speed
		else:
			velocity.x = dir.x * eff_speed
			velocity.z = dir.z * eff_speed

	velocity.y = -6.0 if not is_on_floor() else 0.0
	move_and_slide()
	_update_animation(delta, Vector2(velocity.x, velocity.z).length())


func _anim_speed() -> float:
	return 1.2 if enraged else 1.0


func take_damage(amount: float) -> Dictionary:
	if state == AiState.DEAD:
		return {"killed": false, "damage_taken": 0.0}
	if state == AiState.DORMANT or state == AiState.IDLE:
		state = AiState.CHASE
		if is_boss and not _roared:
			wake_boss()

	current_health = maxf(0.0, current_health - maxf(1.0, amount))
	_hit_flash_timer = 0.22
	_bar_visible_t = 4.0
	if visual != null:
		visual.flash(Color(1.0, 0.82, 0.7) if current_health > 0.0 else Color(1.0, 0.3, 0.2))
		var winding_up := _attack_anim_started and visual.oneshot == _attack_clip
		if current_health > 0.0 and not winding_up and not is_boss:
			visual.play_action("hit", 0.05)

	if is_boss and not enraged and current_health > 0.0 and (current_health / max_health) <= enrage_hp_threshold:
		enraged = true
		if _boss_ember_light != null:
			_boss_ember_light.light_color = Color(1.0, 0.3, 0.1)
		if visual != null:
			visual.play_action("roar", 0.1, 1.3)
		if EventBus != null:
			EventBus.dungeon_ai_announcement.emit(
				"BOSS PHASE 2 — %s ENRAGED!" % display_name.to_upper(),
				"The Iron Warden's furnace core just hit overdrive. Time to block or dodge!",
				"warning"
			)

	if current_health <= 0.0:
		state = AiState.DEAD
		if _health_bar != null:
			_health_bar.visible = false
		if visual != null:
			visual.play_action("death", 0.08)
		if _on_died.is_valid():
			_on_died.call(self)
		queue_free()
		return {"killed": true, "damage_taken": amount}
	return {"killed": false, "damage_taken": amount}


## Hands the animated body over to the lootable corpse so the death fall plays out and stays.
func detach_visual() -> Node3D:
	if visual == null or not is_instance_valid(visual):
		return null
	var v := visual
	var xf := v.global_transform if v.is_inside_tree() else global_transform
	remove_child(v)
	visual = null
	v.set_meta("world_xf", xf)
	return v


func _update_animation(delta: float, horiz_speed: float) -> void:
	if visual == null:
		return
	var target := "idle"
	if state == AiState.ATTACK or (state == AiState.CHASE and horiz_speed < 0.2):
		target = "idle_combat"
	if horiz_speed > 0.22:
		var use_run := horiz_speed > _stride_walk_mps * 1.45 or (enraged and is_boss) or archetype == "charger"
		target = "run" if use_run else "walk"
	var play_speed := 1.0
	if target == "walk":
		play_speed = clampf(horiz_speed / maxf(0.5, _stride_walk_mps), 0.65, 1.55)
	elif target == "run":
		play_speed = clampf(horiz_speed / maxf(0.8, _stride_run_mps), 0.70, 1.55)
	visual.play_state(target if visual.has_anim(target) else "idle", 0.22, play_speed)
	if visual.oneshot.is_empty():
		_attack_anim_started = false if _attack_timer > _impact_time else _attack_anim_started
	if _boss_ember_light != null:
		var base_e := 2.6 if enraged else 1.4
		_boss_ember_light.light_energy = base_e + sin(_anim_time * 5.2) * 0.3
	if _bow_node != null and is_instance_valid(_bow_node):
		_update_archer_bowstring()


func _update_archer_bowstring() -> void:
	var drawing := visual != null and visual.oneshot == "shoot" and visual.action_progress() >= (9.0 / 46.0) and visual.action_progress() < (32.0 / 46.0)
	var nock_local := Vector3(0.0, 0.0, _string_rest_z)
	if drawing and _grip_r_node != null and is_instance_valid(_grip_r_node):
		var p_local := _bow_node.to_local(_grip_r_node.global_position)
		# Clamp nock neatly along the string's draw axis (-Z in Godot bow space)
		var pull_z := clampf(p_local.z, _string_rest_z - 0.52, _string_rest_z)
		nock_local = Vector3(clampf(p_local.x, -0.04, 0.04), clampf(p_local.y, -0.05, 0.08), pull_z)
	if _string_top != null and _string_bot != null:
		_aim_bow_seg(_string_top, _string_tip_top, nock_local)
		_aim_bow_seg(_string_bot, _string_tip_bot, nock_local)
	if _nocked_arrow != null:
		_nocked_arrow.visible = drawing
		if drawing:
			var rest_pt := Vector3(0.024, 0.055, 0.0)
			var dir := (rest_pt - nock_local).normalized()
			var y_ax := dir
			var x_ax := y_ax.cross(Vector3.UP).normalized()
			if x_ax.length() < 0.1:
				x_ax = Vector3.RIGHT
			var z_ax := x_ax.cross(y_ax).normalized()
			_nocked_arrow.transform = Transform3D(Basis(x_ax, y_ax, z_ax), nock_local + dir * 0.36)


static func _aim_bow_seg(seg: Node3D, tip: Vector3, target: Vector3) -> void:
	var d := target - tip
	var ln := d.length()
	if ln < 0.0005:
		return
	var y := d / ln
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	seg.transform = Transform3D(Basis(x, y * ln, z), tip)


func _perform_attack(flat_dir: Vector3) -> void:
	_attack_timer = attack_cooldown_sec / (1.2 if enraged else 1.0)
	_attack_anim_started = false
	var eff_dmg := damage * (enrage_damage_mult if enraged else 1.0)
	if archetype == "ranged" and _on_shoot_projectile.is_valid():
		var origin := global_position + Vector3(0.0, 1.45, 0.0) + flat_dir.normalized() * 0.4
		var target := _player_ref.global_position + Vector3(0.0, 1.2, 0.0)
		var dir := (target - origin).normalized()
		_on_shoot_projectile.call(self, origin, dir * projectile_speed, eff_dmg)
	elif _on_attack_player.is_valid():
		_on_attack_player.call(self, eff_dmg, flat_dir.normalized())
	if EventBus != null:
		EventBus.sfx_requested.emit("bow_release" if archetype == "ranged" else "sword_swing")


func _face_dir(flat_dir: Vector3, delta: float = 1.0) -> void:
	if flat_dir.length_squared() > 0.001:
		var target := atan2(flat_dir.x, flat_dir.z)
		rotation.y = lerp_angle(rotation.y, target, clampf(delta * 10.0, 0.0, 1.0))
