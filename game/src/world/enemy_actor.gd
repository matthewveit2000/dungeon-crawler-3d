class_name EnemyActor
extends CharacterBody3D
## 3D Enemy & Floor Boss Actor (Phase 6 + Expressive Procedural Combat Animations).
## Implements aggro, melee/ranged attacks, Safe Room repulsion (D-021),
## Boss Arena dormancy/enrage phases (D-022), lootable corpse generation,
## and fluid procedural idle/stride/wind-up/lunge/stagger animations.

enum AiState { DORMANT, IDLE, CHASE, ATTACK, FLEE_SAFE_ZONE, DEAD }

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
var _attack_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _attack_anim_t: float = 0.0
var _attack_anim_dur: float = 0.42
var _anim_time: float = 0.0
var _stride_phase: float = 0.0
var _visual_root: Node3D = null
var _hp_bar_3d: Label3D = null
var _boss_ember_light: OmniLight3D = null

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

	# Boss stays dormant until player crosses into the Boss Arena (D-022)
	state = AiState.DORMANT if is_boss else AiState.IDLE

	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
	collision_layer = 1
	collision_mask = 1

	var radius := float(enemy_def.get("radius", 0.5))
	var height := float(enemy_def.get("height", 1.85))
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	col.shape = cap
	col.position.y = height * 0.5
	add_child(col)

	var model_path := str(enemy_def.get("model", ""))
	_visual_root = ModelLoader.instantiate_model(model_path, Vector3(radius * 2.0, height, radius * 2.0), Color(0.75, 0.25, 0.25))
	add_child(_visual_root)

	if is_boss:
		# Dedicated warm furnace key light slightly ahead of the Boss chest so forged steel armor gleams dramatically!
		_boss_ember_light = OmniLight3D.new()
		_boss_ember_light.position = Vector3(0.0, 2.05, 1.35)
		_boss_ember_light.light_color = Color(1.0, 0.64, 0.28)
		_boss_ember_light.light_energy = 2.0
		_boss_ember_light.omni_range = 7.5
		add_child(_boss_ember_light)
	else:
		# Clean subtle floating plate for regular mobs (Boss uses dramatic top-center HUD Boss Health Bar!)
		_hp_bar_3d = Label3D.new()
		_hp_bar_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hp_bar_3d.font_size = 15
		_hp_bar_3d.outline_size = 4
		_hp_bar_3d.outline_modulate = Color(0.04, 0.04, 0.06, 0.92)
		_hp_bar_3d.position = Vector3(0.0, height + 0.34, 0.0)
		_hp_bar_3d.modulate = Color(0.96, 0.88, 0.72)
		add_child(_hp_bar_3d)
		_update_label()

	global_position = spawn_pos


func wake_boss() -> void:
	if state == AiState.DORMANT:
		state = AiState.CHASE


func step_ai(delta: float, is_paused: bool) -> void:
	if is_paused or state == AiState.DEAD or _player_ref == null or not is_instance_valid(_player_ref):
		return

	_anim_time += delta
	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)
	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if _attack_anim_t > 0.0:
		_attack_anim_t = maxf(0.0, _attack_anim_t - delta)

	if state == AiState.DORMANT:
		_update_procedural_pose(delta, 0.0)
		return

	var player_pos := _player_ref.global_position
	var player_in_safe := _layout != null and _layout.is_world_in_safe_room(player_pos)

	# D-021: Enemies legally cannot pursue into Safe Rooms and immediately flee back!
	if player_in_safe and not is_boss:
		state = AiState.FLEE_SAFE_ZONE
		var retreat_dir := (spawn_pos - global_position)
		retreat_dir.y = 0.0
		if retreat_dir.length() > 0.6:
			var spd := move_speed * 1.15
			velocity.x = retreat_dir.normalized().x * spd
			velocity.z = retreat_dir.normalized().z * spd
			_face_dir(retreat_dir)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		velocity.y = -4.0 if not is_on_floor() else 0.0
		move_and_slide()
		_update_procedural_pose(delta, Vector2(velocity.x, velocity.z).length())
		return

	var to_player := player_pos - global_position
	var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
	var dist := flat_to_player.length()

	if _hp_bar_3d != null:
		_hp_bar_3d.visible = (dist <= 11.5) or (current_health < max_health)

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
			_update_procedural_pose(delta, 0.0)
			return

	var eff_speed := move_speed * (enrage_speed_mult if enraged else 1.0)
	_face_dir(flat_to_player)

	if dist <= attack_range:
		state = AiState.ATTACK
		if archetype == "ranged" and dist < preferred_distance * 0.65:
			var back := -flat_to_player.normalized()
			velocity.x = back.x * eff_speed * 0.65
			velocity.z = back.z * eff_speed * 0.65
		else:
			velocity.x = 0.0
			velocity.z = 0.0
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
	_update_procedural_pose(delta, Vector2(velocity.x, velocity.z).length())


func take_damage(amount: float) -> Dictionary:
	if state == AiState.DEAD:
		return {"killed": false, "damage_taken": 0.0}
	if state == AiState.DORMANT or state == AiState.IDLE:
		state = AiState.CHASE

	current_health = maxf(0.0, current_health - maxf(1.0, amount))
	_hit_flash_timer = 0.22

	if is_boss and not enraged and current_health > 0.0 and (current_health / max_health) <= enrage_hp_threshold:
		enraged = true
		if _boss_ember_light != null:
			_boss_ember_light.light_color = Color(1.0, 0.34, 0.14)
			_boss_ember_light.light_energy = 3.2
		if EventBus != null:
			EventBus.dungeon_ai_announcement.emit(
				"BOSS PHASE 2 — %s ENRAGED!" % display_name.to_upper(),
				"The Iron Warden's furnace core just hit overdrive. Time to block or dodge!",
				"warning"
			)

	_update_label()
	if current_health <= 0.0:
		state = AiState.DEAD
		if _on_died.is_valid():
			_on_died.call(self)
		queue_free()
		return {"killed": true, "damage_taken": amount}
	return {"killed": false, "damage_taken": amount}


func _update_procedural_pose(delta: float, horiz_speed: float) -> void:
	if _visual_root == null:
		return

	var move_ratio := clampf(horiz_speed / maxf(1.0, move_speed), 0.0, 1.4)
	if move_ratio > 0.08:
		var stride_rate := (5.4 if is_boss else 8.2) * (1.25 if enraged else 1.0)
		_stride_phase += delta * stride_rate
	else:
		_stride_phase = lerpf(_stride_phase, 0.0, clampf(delta * 5.0, 0.0, 1.0))

	# Base living breathing + walk stride bob & torso sway
	var breathe := sin(_anim_time * (2.2 if is_boss else 2.8))
	var pos := Vector3(0.0, absf(sin(_stride_phase)) * (0.09 if is_boss else 0.07) * move_ratio, 0.0)
	var rot_deg := Vector3(
		move_ratio * (7.0 if is_boss else 9.0),
		sin(_stride_phase) * 5.0 * move_ratio,
		sin(_stride_phase) * (5.5 if is_boss else 7.0) * move_ratio
	)
	var scl := Vector3(1.0 + breathe * 0.014, 1.0 - breathe * 0.012, 1.0 + breathe * 0.014)

	# Clear attack telegraph wind-up right before strike lands (lets player read & block!)
	if state == AiState.ATTACK and _attack_anim_t <= 0.0 and _attack_timer > 0.0 and _attack_timer < 0.34:
		var wind := 1.0 - (_attack_timer / 0.34)
		var ew := ease(wind, -1.6)
		pos.y += (0.14 if is_boss else 0.08) * ew
		pos.z -= 0.14 * ew
		rot_deg.x -= (18.0 if is_boss else 14.0) * ew
		rot_deg.y += (24.0 if is_boss else 18.0) * ew

	# Dramatic lunging strike follow-through!
	if _attack_anim_t > 0.0:
		var u := 1.0 - (_attack_anim_t / maxf(0.01, _attack_anim_dur))
		var lunge := sin(minf(1.0, u * 1.45) * PI)
		pos.z += (0.48 if is_boss else 0.32) * lunge
		pos.y -= 0.05 * lunge
		rot_deg.x += (26.0 if is_boss else 22.0) * lunge
		rot_deg.y -= (30.0 if is_boss else 24.0) * lunge

	# Crisp hit-stagger knockback recoil when struck by the player
	if _hit_flash_timer > 0.0:
		var hit_k := sin((_hit_flash_timer / 0.22) * PI)
		pos.z -= (0.14 if is_boss else 0.22) * hit_k
		rot_deg.x -= (12.0 if is_boss else 18.0) * hit_k
		rot_deg.z += 9.0 * hit_k
		scl *= (1.0 + 0.05 * hit_k)

	_visual_root.position = pos
	_visual_root.rotation_degrees = rot_deg
	_visual_root.scale = scl

	if _boss_ember_light != null:
		var base_e := 3.2 if enraged else 2.0
		_boss_ember_light.light_energy = base_e + sin(_anim_time * 5.2) * 0.35


func _perform_attack(flat_dir: Vector3) -> void:
	_attack_timer = attack_cooldown_sec / (1.2 if enraged else 1.0)
	_attack_anim_dur = 0.52 if is_boss else 0.40
	_attack_anim_t = _attack_anim_dur
	var eff_dmg := damage * (enrage_damage_mult if enraged else 1.0)
	if archetype == "ranged" and _on_shoot_projectile.is_valid():
		var origin := global_position + Vector3(0.0, 1.35, 0.0)
		var target := _player_ref.global_position + Vector3(0.0, 1.2, 0.0)
		var dir := (target - origin).normalized()
		_on_shoot_projectile.call(self, origin, dir * projectile_speed, eff_dmg)
	elif _on_attack_player.is_valid():
		_on_attack_player.call(self, eff_dmg, flat_dir.normalized())


func _face_dir(flat_dir: Vector3) -> void:
	if flat_dir.length_squared() > 0.001:
		rotation.y = atan2(flat_dir.x, flat_dir.z)


func _update_label() -> void:
	if _hp_bar_3d == null:
		return
	_hp_bar_3d.text = "%s\n%.0f / %.0f" % [display_name, current_health, max_health]
