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
const BOMB_GRAVITY := 9.0
const IMPACT_TIME := {"attack_1h": 0.47, "attack_2h": 0.6, "shoot": 1.08, "slam": 0.6}

var enemy_id: String = ""
var display_name: String = "Enemy"
var archetype: String = "melee"
var is_boss: bool = false
var is_champion: bool = false  ## FB-022: a promoted, named mini-boss guarding a champion lair
var champion_title: String = ""
var room_id: int = -1
var floor_number: int = 1

var max_health: float = 60.0
var current_health: float = 60.0
var damage: float = 12.0
var armor: float = 6.0
var move_speed: float = 3.8
var aggro_radius: float = 13.0
var body_radius: float = 0.5  ## collision radius; melee reach is measured to the body's edge
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
## D-049: level, unique traits and status effects
var level: int = 1
var traits: Dictionary = {}  ## trait id -> params
var projectile_kind: String = "arrow"
var projectile_color: String = "#ffffff"
var statuses: Dictionary = {}  ## "bleed"/"burn" -> {"dps","t"}; "poison" -> {"stacks": [...]}; "chill" -> {"slow","t"}; "stun"/"sunder"/"rally" ...
var _stun_t: float = 0.0
var _knock_vel: Vector3 = Vector3.ZERO
var _since_hurt: float = 99.0
var _berserk: bool = false
var _attack_count: int = 0
var _war_cry_t: float = 2.0

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
# Wandering & awareness (D-046): idle enemies roam their room; they engage on sight (or hearing range) from far
# away, and give up after losing sight of the player for a while
const HEARING_RADIUS := 6.0
const LOSE_SIGHT_SEC := 4.0
const LEASH_MULT := 2.2
var _wander_target: Vector3 = Vector3.INF
var _wander_pause: float = 0.0
var _unseen_t: float = 0.0
var _los_timer: float = 0.0
var _los_cached: bool = false
# Pathfinding (FB-014): enemies follow a tile path around walls/props and unstick themselves
var _path: Array[Vector2i] = []
var _path_i: int = 0
var _path_goal: Vector2i = Vector2i(-9999, -9999)
var _repath_t: float = 0.0
var _pull_i: int = 0
var _pull_t: float = 0.0
const PULL_LOOKAHEAD := 16
const DIRECT_WALK_DIST := 32.0
var _stuck_t: float = 0.0
var _sidestep_t: float = 0.0
var _sidestep_dir: Vector3 = Vector3.ZERO
var _last_pos: Vector3 = Vector3.ZERO
var _walk_timer: float = 0.0
var _walk_cached: bool = true
var _player_ref: Node3D = null
var _rng: SeededRng = null
var _on_attack_player: Callable = Callable()
var _on_shoot_projectile: Callable = Callable()
var _on_died: Callable = Callable()
var _on_dot_tick: Callable = Callable()
## FB-022 damage over time made visible: per-status body effects, a status line under the name, the health bar
## takes the colour of the worst damage-over-time, and ticks pop up as coloured numbers.
const STATUS_COLORS := {"burn": Color(1.0, 0.52, 0.14), "bleed": Color(0.9, 0.1, 0.1), "poison": Color(0.5, 1.0, 0.22),
	"chill": Color(0.55, 0.85, 1.0), "sunder": Color(0.85, 0.75, 0.6), "stun": Color(1.0, 0.95, 0.5)}
const STATUS_WORDS := {"burn": "BURNING", "bleed": "BLEEDING", "poison": "POISONED", "chill": "CHILLED", "sunder": "SUNDERED", "stun": "STUNNED"}
const DOT_POP_SEC := 0.5
var _status_fx: Dictionary = {}  ## status kind -> Node3D effect on the body
var _status_label: Label3D = null
var _dot_accum: Dictionary = {}  ## kind -> damage not yet shown as a number
var _dot_pop_t: float = 0.0


func setup(
	enemy_def: Dictionary,
	scaling_cfg: Dictionary,
	p_floor_number: int,
	p_room_id: int,
	p_spawn_pos: Vector3,
	p_layout: DungeonGenerator.FloorLayout,
	p_player: Node3D,
	p_rng: SeededRng,
	callbacks: Dictionary,
	p_level: int = 0
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
	_on_dot_tick = callbacks.get("dot_tick", Callable())

	# D-049: stats come from the enemy's level (each type has its own level range; floors pick levels)
	var pack := DataLoader.get_enemies_pack()
	level = p_level if p_level > 0 else EnemyLevels.roll_level(enemy_def, floor_number, pack, p_rng)
	var ls := EnemyLevels.scale_for(level, pack)
	var hp_scale := float(ls["health"])
	var dmg_scale := float(ls["damage"])
	var xp_scale := float(ls["xp"])
	var gold_scale := float(ls["gold"])
	traits.clear()
	for t in enemy_def.get("traits", []):
		traits[str(t["id"])] = t
	projectile_kind = str(enemy_def.get("projectile_kind", "arrow"))
	projectile_color = str(enemy_def.get("projectile_color", "#ffffff"))

	max_health = snappedf(float(enemy_def["max_health"]) * hp_scale, 1.0)
	current_health = max_health
	damage = snappedf(float(enemy_def["damage"]) * dmg_scale, 0.5)
	armor = float(enemy_def.get("armor", 5.0)) + float(ls["armor"])
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
	# FB-022 power-scale knobs: balance.json globals x the floor's power_scale x this type's own power_scale
	max_health = maxf(1.0, snappedf(max_health * PowerScale.enemy(enemy_def, "health", floor_number), 1.0))
	current_health = max_health
	damage = maxf(0.5, snappedf(damage * PowerScale.enemy(enemy_def, "damage", floor_number), 0.5))
	xp_reward = maxi(1, int(round(float(xp_reward) * PowerScale.enemy(enemy_def, "xp", floor_number))))
	gold_min = int(round(float(gold_min) * PowerScale.enemy(enemy_def, "gold", floor_number)))
	gold_max = int(round(float(gold_max) * PowerScale.enemy(enemy_def, "gold", floor_number)))
	loot_drop_chance = float(enemy_def.get("loot_drop_chance", 0.45))
	guaranteed_rarity = str(enemy_def.get("guaranteed_rarity", ""))
	_anim_time = _rng.next_float("ai") * TAU if _rng != null else 0.0

	state = AiState.DORMANT if is_boss else AiState.IDLE

	# FB-022 Champion: spawn_enemy marks a lair guardian with "_champion" (title); balance.json shapes it
	var champ: Dictionary = enemy_def.get("_champion", {})
	var ch_size := 1.0
	if not champ.is_empty() and not is_boss:
		var cc: Dictionary = PowerScale.cfg().get("champions", {})
		is_champion = true
		champion_title = str(champ.get("title", "the Champion"))
		display_name = "%s %s" % [display_name, champion_title]
		level += int(cc.get("level_add", 2))
		max_health = snappedf(max_health * float(cc.get("health_mult", 7.0)) * PowerScale.knob("champion_health"), 1.0)
		current_health = max_health
		damage = snappedf(damage * float(cc.get("damage_mult", 1.7)) * PowerScale.knob("champion_damage"), 0.5)
		armor += float(cc.get("armor_add", 6.0))
		xp_reward = int(round(float(xp_reward) * float(cc.get("xp_mult", 6.0))))
		gold_min = int(round(float(gold_min) * float(cc.get("gold_mult", 5.0))))
		gold_max = int(round(float(gold_max) * float(cc.get("gold_mult", 5.0))))
		loot_drop_chance = 1.0
		guaranteed_rarity = "rare"
		enrage_hp_threshold = float(cc.get("enrage_hp_threshold", 0.4))
		aggro_radius *= 1.2
		ch_size = float(cc.get("size_mult", 1.35))

	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
	if is_champion:
		add_to_group("champions")
	collision_layer = 1
	collision_mask = 1

	var radius := float(enemy_def.get("radius", 0.5)) * ch_size
	body_radius = radius
	_height = float(enemy_def.get("height", 1.85)) * ch_size
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
	var vscale := float(vdef.get("scale", 1.0)) * ch_size
	if not is_equal_approx(vscale, 1.0):
		visual.scale = Vector3.ONE * vscale
	if vdef.has("tint"):
		visual.set_tint(Color.html(str(vdef["tint"])), float(vdef.get("tint_strength", 0.25)))
	if is_champion:
		visual.set_tint(Color.html(str(PowerScale.cfg().get("champions", {}).get("tint", "#ffb02e"))), 0.22)
		var aura := VfxFactory.make_glow(Color(1.0, 0.62, 0.18), 0.9, 1.2)
		aura.position = Vector3(0.0, _height * 0.55, 0.0)
		add_child(aura)
	if vdef.has("shield"):
		var gl := visual.model.find_child("GripL*", true, false) as Node3D
		if gl != null:
			var sh := ModelLoader.instantiate_model(str(vdef["shield"]), Vector3(0.8, 0.8, 0.1))
			sh.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			gl.add_child(sh)
	if vdef.has("hand_glow"):
		var gh := visual.model.find_child("GripL*", true, false) as Node3D
		if gh != null:
			gh.add_child(VfxFactory.make_glow(Color.html(str(vdef["hand_glow"])), 0.28, 1.6))
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
		if archetype == "ranged" and projectile_kind == "arrow":
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
	if kind == "goblin":
		var hoop := visual.model.find_child("CandleHoop*", true, false) as Node3D
		if hoop != null:
			var rl := OmniLight3D.new()
			rl.light_color = Color(1.0, 0.68, 0.32)
			rl.light_energy = 1.1
			rl.omni_range = 3.5
			hoop.add_child(rl)
	global_position = spawn_pos


## FB-022: one billboarded quad drawn by a tiny shader (frame, trailing "recent damage" bar and the live fill).
## Billboarded StandardMaterial3D quads ignore node scale, so the old scaled-quad bar could never shrink: its fill
## only slid sideways and looked half full on a dying enemy. The shader reads the exact health ratio instead.
const HEALTH_BAR_SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, blend_mix;
uniform float ratio : hint_range(0.0, 1.0) = 1.0;
uniform float lag : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.86, 0.16, 0.12, 1.0);
uniform vec4 lag_color : source_color = vec4(1.0, 0.85, 0.55, 0.85);
uniform vec4 frame_color : source_color = vec4(0.02, 0.02, 0.03, 0.78);
const vec2 PAD = vec2(0.023, 0.21);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 c = frame_color;
	if (UV.x > PAD.x && UV.x < 1.0 - PAD.x && UV.y > PAD.y && UV.y < 1.0 - PAD.y) {
		float x = (UV.x - PAD.x) / (1.0 - 2.0 * PAD.x);
		if (x <= ratio) {
			c = fill_color;
		} else if (x <= lag) {
			c = lag_color;
		}
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""
static var _health_bar_shader: Shader = null
var _health_mat: ShaderMaterial = null


func _build_health_bar() -> void:
	_health_bar = Node3D.new()
	_health_bar.name = "HealthBar"
	_health_bar.position = Vector3(0.0, _height + 0.38, 0.0)
	add_child(_health_bar)
	if _health_bar_shader == null:
		_health_bar_shader = Shader.new()
		_health_bar_shader.code = HEALTH_BAR_SHADER
	_health_mat = ShaderMaterial.new()
	_health_mat.shader = _health_bar_shader
	_health_mat.render_priority = 3
	var q := QuadMesh.new()
	q.size = Vector2(0.86, 0.085)
	q.material = _health_mat
	_health_fill = MeshInstance3D.new()
	_health_fill.name = "Bar"
	_health_fill.mesh = q
	_health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(_health_fill)
	_name_label = Label3D.new()
	_name_label.text = "Lv %d  %s" % [level, display_name]
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
	_status_label = Label3D.new()
	_status_label.name = "StatusLine"
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.font_size = 22
	_status_label.pixel_size = 0.0042
	_status_label.outline_size = 8
	_status_label.outline_modulate = Color(0, 0, 0, 0.9)
	_status_label.position = Vector3(0, -0.11, 0)
	_status_label.render_priority = 4
	if UiTheme.font_ui_bold() != null:
		_status_label.font = UiTheme.font_ui_bold()
	_health_bar.add_child(_status_label)
	_health_bar.visible = false


## Pushes the exact health ratio to the bar right away (even while stunned or out of the AI's update path).
func _sync_bar_ratio() -> void:
	if _health_mat != null:
		_health_mat.set_shader_parameter("ratio", clampf(current_health / maxf(1.0, max_health), 0.0, 1.0))


## Fraction of the bar drawn as live health (what the player sees; FB-022 guard).
func health_bar_fill() -> float:
	return float(_health_mat.get_shader_parameter("ratio")) if _health_mat != null else -1.0


func _update_health_bar(delta: float, dist: float) -> void:
	if _health_bar == null:
		return
	var ratio := clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	_lag_ratio = move_toward(_lag_ratio, ratio, delta * 0.6) if _lag_ratio > ratio else ratio
	_health_mat.set_shader_parameter("ratio", ratio)
	_health_mat.set_shader_parameter("lag", _lag_ratio)
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
	_tick_statuses(delta)
	if state == AiState.DEAD:
		return
	if _stun_t > 0.0:
		# stunned / frozen: no thinking, no moving (knockback still slides the body)
		_stun_t = maxf(0.0, _stun_t - delta)
		velocity = Vector3(_knock_vel.x, -4.0 if not is_on_floor() else 0.0, _knock_vel.z)
		_knock_vel = _knock_vel.move_toward(Vector3.ZERO, delta * 18.0)
		move_and_slide()
		if visual != null:
			visual.play_state("idle_combat" if visual.has_anim("idle_combat") else "idle", 0.2, 0.15)
		return
	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta * _haste())
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
			retreat_dir = _steer_toward(spawn_pos, retreat_dir.length(), delta)
			velocity.x = retreat_dir.x * spd
			velocity.z = retreat_dir.z * spd
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
		if dist <= HEARING_RADIUS or (dist <= aggro_radius and _sees_player(delta)):
			state = AiState.CHASE
			_unseen_t = 0.0
			_wander_target = Vector3.INF
			if is_champion and not _roared and visual != null and visual.play_action("roar", 0.15):
				_roared = true
				_attack_timer = maxf(_attack_timer, 1.2)
		else:
			_wander(delta)
			return
	else:
		# Lose interest once the player is out of sight for a while or far beyond engagement range
		if not is_boss:
			_unseen_t = 0.0 if _sees_player(delta) else _unseen_t + delta
			if _unseen_t > LOSE_SIGHT_SEC or dist > aggro_radius * LEASH_MULT:
				state = AiState.IDLE
				_wander_pause = 1.0
				_attack_anim_started = false
				_wander(delta)
				return

	var eff_speed := move_speed * (enrage_speed_mult if enraged else 1.0) * _speed_mult()
	if traits.has("war_cry"):
		_war_cry_t -= delta
		if _war_cry_t <= 0.0:
			_war_cry_t = float(traits["war_cry"].get("every", 9.0))
			_do_war_cry()
	if visual != null and visual.oneshot == "roar":
		eff_speed = 0.0
	if dist <= attack_range:
		_face_dir(flat_to_player, delta)
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
		if _attack_timer <= 0.0 and (archetype != "ranged" or _sees_player(delta)):
			_perform_attack(flat_to_player)
	else:
		state = AiState.CHASE
		var dir := _steer_toward(player_pos, dist, delta)
		_face_dir(dir if dir.length() > 0.01 else flat_to_player, delta)
		var next_probe := global_position + dir * 1.1
		if not is_boss and _layout != null and _layout.is_world_in_safe_room(next_probe):
			state = AiState.FLEE_SAFE_ZONE
			velocity.x = -dir.x * eff_speed
			velocity.z = -dir.z * eff_speed
		else:
			velocity.x = dir.x * eff_speed
			velocity.z = dir.z * eff_speed

	velocity.y = -6.0 if not is_on_floor() else 0.0
	if _knock_vel.length_squared() > 0.01:
		velocity.x += _knock_vel.x
		velocity.z += _knock_vel.z
		_knock_vel = _knock_vel.move_toward(Vector3.ZERO, delta * 18.0)
	move_and_slide()
	_update_animation(delta, Vector2(velocity.x, velocity.z).length())


# --- D-049 status effects & traits ----------------------------------------------------------------------------
## Applies a status from a player's mastery ability: bleed / burn / poison (damage over time), chill (slow),
## freeze / stun (no action), sunder (armor loss), rally (war-cry buff from an ally).
func apply_status(kind: String, params: Dictionary) -> void:
	if state == AiState.DEAD:
		return
	match kind:
		"bleed", "burn":
			var cur: Dictionary = statuses.get(kind, {})
			statuses[kind] = {"dps": maxf(float(cur.get("dps", 0.0)), float(params.get("dps", 3.0))),
				"t": maxf(float(cur.get("t", 0.0)), float(params.get("duration", 3.0)))}
		"poison":
			var cur: Dictionary = statuses.get("poison", {"stacks": []})
			var stacks: Array = cur["stacks"]
			stacks.append({"dps": float(params.get("dps", 4.0)), "t": float(params.get("duration", 5.0))})
			while stacks.size() > maxi(1, int(params.get("stacks", 1))):
				stacks.pop_front()
			statuses["poison"] = {"stacks": stacks}
		"chill":
			var cur: Dictionary = statuses.get("chill", {})
			statuses["chill"] = {"slow": maxf(float(cur.get("slow", 0.0)), float(params.get("slow", 0.3))),
				"t": maxf(float(cur.get("t", 0.0)), float(params.get("duration", 3.0)))}
		"freeze", "stun":
			if is_boss:
				_stun_t = maxf(_stun_t, float(params.get("duration", 1.0)) * 0.35)
			else:
				_stun_t = maxf(_stun_t, float(params.get("duration", 1.0)))
			_attack_anim_started = false
			if visual != null:
				visual.flash(Color(0.55, 0.85, 1.0) if kind == "freeze" else Color(1.0, 0.95, 0.5), 0.4)
		"sunder":
			statuses["sunder"] = {"armor": maxf(float(statuses.get("sunder", {}).get("armor", 0.0)), float(params.get("armor", 5.0))),
				"t": float(params.get("duration", 5.0))}
		"rally":
			statuses["rally"] = {"haste": float(params.get("haste", 1.3)), "damage": float(params.get("damage", 1.25)),
				"t": float(params.get("duration", 6.0))}
			if visual != null:
				visual.flash(Color(1.0, 0.8, 0.2), 0.3)


func has_status(kind: String) -> bool:
	return statuses.has(kind) or (kind in ["stun", "freeze"] and _stun_t > 0.0)


## Pushes the enemy away and interrupts its attack (mastery Shove / power shots).
func apply_knockback(dir: Vector3, force: float) -> void:
	if state == AiState.DEAD:
		return
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	_knock_vel = d * force * (0.35 if is_boss else 1.0)
	if not is_boss:
		_attack_timer = maxf(_attack_timer, 0.6)
		_attack_anim_started = false


func effective_armor() -> float:
	return maxf(0.0, armor - float(statuses.get("sunder", {}).get("armor", 0.0)))


func _speed_mult() -> float:
	var m := 1.0 - float(statuses.get("chill", {}).get("slow", 0.0))
	m *= float(statuses.get("rally", {}).get("haste", 1.0))
	if _berserk:
		m *= float(traits.get("berserk", {}).get("haste", 1.35))
	return maxf(0.2, m)


func _haste() -> float:
	var h := float(statuses.get("rally", {}).get("haste", 1.0))
	if _berserk:
		h *= float(traits.get("berserk", {}).get("haste", 1.35))
	return h * (1.0 - float(statuses.get("chill", {}).get("slow", 0.0)) * 0.5)


## Damage multiplier from rally / berserk.
func damage_mult() -> float:
	var m := float(statuses.get("rally", {}).get("damage", 1.0))
	if _berserk:
		m *= float(traits.get("berserk", {}).get("damage", 1.25))
	return m


func _tick_statuses(delta: float) -> void:
	_since_hurt += delta
	var dot := 0.0
	for k in ["bleed", "burn"]:
		if statuses.has(k):
			var st: Dictionary = statuses[k]
			var d := float(st["dps"]) * delta
			dot += d
			_dot_accum[k] = float(_dot_accum.get(k, 0.0)) + d
			st["t"] = float(st["t"]) - delta
			if float(st["t"]) <= 0.0:
				statuses.erase(k)
	if statuses.has("poison"):
		var stacks: Array = statuses["poison"]["stacks"]
		for i in range(stacks.size() - 1, -1, -1):
			var d := float(stacks[i]["dps"]) * delta
			dot += d
			_dot_accum["poison"] = float(_dot_accum.get("poison", 0.0)) + d
			stacks[i]["t"] = float(stacks[i]["t"]) - delta
			if float(stacks[i]["t"]) <= 0.0:
				stacks.remove_at(i)
		if stacks.is_empty():
			statuses.erase("poison")
	for k in ["chill", "sunder", "rally"]:
		if statuses.has(k):
			statuses[k]["t"] = float(statuses[k]["t"]) - delta
			if float(statuses[k]["t"]) <= 0.0:
				statuses.erase(k)
	if traits.has("regenerate") and _since_hurt > 4.0 and current_health < max_health:
		current_health = minf(max_health, current_health + float(traits["regenerate"].get("hps", 3.0)) * delta)
	_dot_pop_t -= delta
	if _dot_pop_t <= 0.0 and not _dot_accum.is_empty():
		_dot_pop_t = DOT_POP_SEC
		_pop_dot_numbers()
	_sync_status_visuals()
	if dot > 0.0:
		_dot_damage(dot)


## Shows the damage-over-time dealt since the last pop as one coloured number per kind (FB-022).
func _pop_dot_numbers() -> void:
	for k in _dot_accum.keys():
		var amt := float(_dot_accum[k])
		if amt >= 0.5:
			if _on_dot_tick.is_valid():
				_on_dot_tick.call(self, amt, str(k))
			if visual != null:
				visual.flash(STATUS_COLORS.get(k, Color.WHITE), 0.12)
	_dot_accum.clear()


## Active statuses as [kind, seconds left, stacks], worst damage-over-time first.
func status_list() -> Array:
	var out: Array = []
	for k in ["burn", "bleed", "poison", "chill", "sunder"]:
		if not statuses.has(k):
			continue
		if k == "poison":
			var mt := 0.0
			for st in statuses["poison"]["stacks"]:
				mt = maxf(mt, float(st["t"]))
			out.append([k, mt, (statuses["poison"]["stacks"] as Array).size()])
		else:
			out.append([k, float(statuses[k]["t"]), 1])
	if _stun_t > 0.0:
		out.append(["stun", _stun_t, 1])
	return out


## Keeps the body effects, status line and health-bar colour in step with the statuses.
func _sync_status_visuals() -> void:
	var active := {}
	for k in ["burn", "bleed", "poison", "chill"]:
		if statuses.has(k):
			active[k] = true
	for k in _status_fx.keys():
		if not active.has(k):
			var n: Node = _status_fx[k]
			if is_instance_valid(n):
				n.queue_free()
			_status_fx.erase(k)
	for k in active.keys():
		if not _status_fx.has(k) and is_inside_tree():
			_status_fx[k] = _make_status_fx(str(k))
	if _status_label != null:
		var parts: Array = []
		var lst := status_list()
		for e in lst:
			var word := str(STATUS_WORDS.get(e[0], str(e[0]).to_upper()))
			parts.append("%s%s %ds" % [word, (" ×%d" % int(e[2])) if int(e[2]) > 1 else "", int(ceil(float(e[1])))])
		_status_label.text = "  ·  ".join(parts)
		_status_label.modulate = STATUS_COLORS.get(lst[0][0], Color.WHITE) if not lst.is_empty() else Color.WHITE
	if _health_mat != null:
		var fill := Color(0.86, 0.16, 0.12, 1.0)
		for k in ["poison", "burn", "bleed"]:
			if statuses.has(k):
				var c: Color = STATUS_COLORS[k]
				fill = Color(c.r, c.g, c.b, 1.0).lerp(Color(1, 1, 1, 1), 0.12 + 0.12 * sin(_anim_time * 9.0))
				break
		_health_mat.set_shader_parameter("fill_color", fill)
	if not statuses.is_empty() or _stun_t > 0.0:
		_bar_visible_t = maxf(_bar_visible_t, 0.5)


func _make_status_fx(kind: String) -> Node3D:
	var h := _height
	var n: Node3D = null
	match kind:
		"burn":
			n = VfxFactory.make_fire(0.38, false)
			n.position = Vector3(0.0, h * 0.45, 0.0)
		"bleed":
			n = _drip_particles(Color(0.7, 0.02, 0.02), h)
		"poison":
			n = VfxFactory.make_magic_aura(STATUS_COLORS["poison"], body_radius * 1.1, 40)
			n.position = Vector3(0.0, h * 0.5, 0.0)
		"chill":
			n = VfxFactory.make_magic_aura(STATUS_COLORS["chill"], body_radius * 1.2, 28)
			n.position = Vector3(0.0, h * 0.55, 0.0)
	if n != null:
		n.name = "StatusFx_" + kind
		add_child(n)
	return n


## Blood drops falling from the body while bleeding.
func _drip_particles(col: Color, h: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.7
	p.local_coords = false
	p.position = Vector3(0.0, h * 0.6, 0.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = body_radius * 0.8
	m.direction = Vector3.DOWN
	m.spread = 15.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.6
	m.gravity = Vector3(0, -9.0, 0)
	m.scale_min = 0.6
	m.scale_max = 1.1
	m.color = col
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1)
	q.material = mat
	p.draw_pass_1 = q
	return p


func _dot_damage(amount: float) -> void:
	current_health = maxf(0.0, current_health - amount)
	_bar_visible_t = 4.0
	_since_hurt = 0.0
	_sync_bar_ratio()
	if current_health <= 0.0:
		take_damage(1.0)


func _do_war_cry() -> void:
	var wc: Dictionary = traits["war_cry"]
	var r := float(wc.get("radius", 12.0))
	if not is_inside_tree():
		return
	var any := false
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as EnemyActor
		if e == null or e == self or e.state == AiState.DEAD:
			continue
		if e.global_position.distance_to(global_position) <= r:
			e.apply_status("rally", wc)
			any = true
	if any and visual != null:
		visual.flash(Color(1.0, 0.85, 0.3), 0.3)
		if EventBus != null:
			EventBus.sfx_requested.emit("door_seal")


## Direction to move toward `target`: straight when close with a clear view, otherwise along an A* tile path
## around walls and props; sidesteps and re-plans when it stops making progress (FB-014).
func _steer_toward(target: Vector3, dist: float, delta: float) -> Vector3:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	# progress / stuck tracking
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	_last_pos = global_position
	_stuck_t = _stuck_t + delta if moved < move_speed * delta * 0.25 else maxf(0.0, _stuck_t - delta * 2.0)
	if _sidestep_t > 0.0:
		_sidestep_t -= delta
		return _sidestep_dir
	if _stuck_t > 0.8:
		_stuck_t = 0.0
		_sidestep_t = 0.45
		var side := Vector3(-flat.z, 0.0, flat.x).normalized()
		_sidestep_dir = side * (1.0 if (_rng == null or _rng.next_float("ai") < 0.5) else -1.0)
		_path.clear()
		return _sidestep_dir
	var my_t := _layout.world_to_tile(global_position) if _layout != null else Vector2i.ZERO
	var goal_t := _layout.world_to_tile(target) if _layout != null else Vector2i.ZERO
	var tile_gap := absi(goal_t.x - my_t.x) + absi(goal_t.y - my_t.y)
	# FB-022: walk straight at the target whenever the way is open (no zig-zag along tile centres)
	if _layout == null or tile_gap > 40 or ((dist < 9.0 or (dist < DIRECT_WALK_DIST and _layout.has_tile_los(my_t, goal_t))) and _walk_clear(target, delta)):
		_path.clear()
		return flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	_repath_t -= delta
	if _path.is_empty() or goal_t != _path_goal or _repath_t <= 0.0:
		_path = _layout.find_path(my_t, goal_t)
		_path_i = 1
		_path_goal = goal_t
		_pull_t = 0.0
		_repath_t = 0.6 + (float(get_instance_id() % 7) * 0.03)
	while _path_i < _path.size():
		var wp := _layout.tile_to_world(_path[_path_i])
		if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() > 0.7:
			break
		_path_i += 1
	if _path_i >= _path.size():
		return flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	# String-pull: head for the farthest waypoint still in a straight, open line (re-checked a few times a second)
	_pull_t -= delta
	if _pull_t <= 0.0:
		_pull_t = 0.2
		# visibility along a path is close to monotonic: binary-search the farthest waypoint in straight view
		var lo := _path_i
		var hi := mini(_path.size() - 1, _path_i + PULL_LOOKAHEAD)
		if not _layout.has_tile_los(my_t, _path[lo]):
			hi = lo
		while lo < hi:
			var mid := (lo + hi + 1) >> 1
			if _layout.has_tile_los(my_t, _path[mid]):
				lo = mid
			else:
				hi = mid - 1
		_pull_i = lo
	var aim_i := clampi(maxi(_pull_i, _path_i), 0, _path.size() - 1)
	var aim := goal_t if aim_i == _path.size() - 1 else _path[aim_i]
	var wp2 := target if aim == goal_t else _layout.tile_to_world(aim)
	var d := Vector3(wp2.x - global_position.x, 0.0, wp2.z - global_position.z)
	return d.normalized() if d.length() > 0.01 else (flat.normalized() if flat.length() > 0.01 else Vector3.ZERO)


## True when a body-height sweep (centre + both shoulders) to `target` hits no wall or prop: walk straight.
func _walk_clear(target: Vector3, delta: float) -> bool:
	_walk_timer -= delta
	if _walk_timer > 0.0:
		return _walk_cached
	_walk_timer = 0.25
	if not is_inside_tree():
		_walk_cached = true
		return true
	var space := get_world_3d().direct_space_state
	var to := Vector3(target.x, global_position.y, target.z) - global_position
	var side := Vector3(-to.z, 0.0, to.x).normalized() * maxf(0.3, body_radius * 0.85)
	var ex: Array[RID] = [get_rid()]
	if _player_ref is CollisionObject3D:
		ex.append((_player_ref as CollisionObject3D).get_rid())
	_walk_cached = true
	for off in [Vector3.ZERO, side, -side]:
		var a: Vector3 = global_position + Vector3(0.0, 0.45, 0.0) + off
		var q := PhysicsRayQueryParameters3D.create(a, a + to, 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and not (hit.get("collider") is EnemyActor):
			_walk_cached = false
			break
	return _walk_cached


## Idle roaming inside the enemy's own room: walk to a random spot, pause, repeat.
func _wander(delta: float) -> void:
	var speed := 0.0
	if _wander_pause > 0.0:
		_wander_pause -= delta
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		if _wander_target == Vector3.INF:
			_wander_target = _pick_wander_target()
		var to_t := _wander_target - global_position
		to_t.y = 0.0
		if to_t.length() < 0.6:
			_wander_target = Vector3.INF
			_wander_pause = _rng.next_float_range("ai", 1.2, 3.8) if _rng != null else 2.0
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			speed = move_speed * 0.38
			var dir := to_t.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_face_dir(to_t, delta)
	velocity.y = -4.0 if not is_on_floor() else 0.0
	move_and_slide()
	if speed > 0.0 and get_real_velocity().length() < speed * 0.2:
		_wander_target = Vector3.INF  # bumped into something: pick somewhere else
		_wander_pause = 0.6
	_update_animation(delta, Vector2(velocity.x, velocity.z).length())


func _pick_wander_target() -> Vector3:
	if _layout == null:
		return spawn_pos
	var room := _layout.get_room(room_id)
	if room.is_empty():
		return spawn_pos
	var rect: Rect2i = room["rect"]
	var inner := rect.grow(-1) if rect.size.x > 2 and rect.size.y > 2 else rect
	var tx := _rng.next_int_range("ai", inner.position.x, inner.end.x - 1) if _rng != null else inner.position.x
	var ty := _rng.next_int_range("ai", inner.position.y, inner.end.y - 1) if _rng != null else inner.position.y
	var jitter := Vector3(_rng.next_float_range("ai", -1.2, 1.2), 0.0, _rng.next_float_range("ai", -1.2, 1.2)) if _rng != null else Vector3.ZERO
	return _layout.tile_to_world(Vector2i(tx, ty)) + jitter + Vector3(0.0, global_position.y, 0.0)


## Line of sight to the player through the world geometry (cached for 0.2 s).
func _sees_player(delta: float) -> bool:
	_los_timer -= delta
	if _los_timer > 0.0:
		return _los_cached
	_los_timer = 0.2
	if not is_inside_tree() or _player_ref == null:
		_los_cached = false
		return false
	var from := global_position + Vector3(0.0, 1.5, 0.0)
	var to := _player_ref.global_position + Vector3(0.0, 1.3, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid(), (_player_ref as CollisionObject3D).get_rid()] if _player_ref is CollisionObject3D else [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_los_cached = hit.is_empty() or hit.get("collider") == _player_ref
	return _los_cached


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
	_since_hurt = 0.0
	if traits.has("berserk") and not _berserk and current_health > 0.0 \
			and current_health / max_health <= float(traits["berserk"].get("threshold", 0.4)):
		_berserk = true
		if visual != null:
			visual.set_tint(Color(1.0, 0.15, 0.1), 0.3)
	_hit_flash_timer = 0.22
	_bar_visible_t = 4.0
	_sync_bar_ratio()
	if visual != null:
		visual.flash(Color(1.0, 0.82, 0.7) if current_health > 0.0 else Color(1.0, 0.3, 0.2))
		var winding_up := _attack_anim_started and visual.oneshot == _attack_clip
		if current_health > 0.0 and not winding_up and not is_boss:
			visual.play_action("hit", 0.05)

	if (is_boss or is_champion) and not enraged and current_health > 0.0 and (current_health / max_health) <= enrage_hp_threshold:
		enraged = true
		if _boss_ember_light != null:
			_boss_ember_light.light_color = Color(1.0, 0.3, 0.1)
		if visual != null:
			visual.play_action("roar", 0.1, 1.3)
			if is_champion:
				visual.set_tint(Color(1.0, 0.2, 0.1), 0.3)
		if EventBus != null:
			EventBus.dungeon_ai_announcement.emit(
				"%s — %s ENRAGED!" % ["BOSS PHASE 2" if is_boss else "CHAMPION", display_name.to_upper()],
				"The Iron Warden's furnace core just hit overdrive. Time to block or dodge!" if is_boss
					else "It is faster and angrier now. Mostly angrier.",
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
	_attack_count += 1
	var eff_dmg := damage * (enrage_damage_mult if enraged else 1.0) * damage_mult()
	if archetype == "ranged" and _on_shoot_projectile.is_valid():
		var origin := global_position + Vector3(0.0, 1.45, 0.0) + flat_dir.normalized() * 0.4
		var target := _player_ref.global_position + Vector3(0.0, 1.2, 0.0)
		var vel := (target - origin).normalized() * projectile_speed
		if projectile_kind == "bomb":
			# lobbed pot: arcs onto where the player stands
			var flat := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
			var t := maxf(0.4, flat.length() / projectile_speed)
			vel = flat / t
			vel.y = ((target.y - 1.0) - origin.y + 0.5 * BOMB_GRAVITY * t * t) / t
		_on_shoot_projectile.call(self, origin, vel, eff_dmg)
	elif traits.has("ground_slam") and _attack_count % int(traits["ground_slam"].get("every", 3)) == 0:
		# every Nth blow cracks the floor: hits anywhere inside the slam radius
		var slam_r := float(traits["ground_slam"].get("radius", 3.5))
		var burst := VfxFactory.make_impact_burst(Color(0.6, 0.5, 0.35), 40, slam_r)
		get_parent().add_child(burst)
		burst.global_position = global_position + Vector3(0, 0.2, 0)
		if _player_ref.global_position.distance_to(global_position) <= slam_r and _on_attack_player.is_valid():
			_on_attack_player.call(self, eff_dmg * 1.3, flat_dir.normalized())
	elif _on_attack_player.is_valid():
		_on_attack_player.call(self, eff_dmg, flat_dir.normalized())
	if EventBus != null:
		EventBus.sfx_requested.emit("bow_release" if archetype == "ranged" else "sword_swing")


func _face_dir(flat_dir: Vector3, delta: float = 1.0) -> void:
	if flat_dir.length_squared() > 0.001:
		var target := atan2(flat_dir.x, flat_dir.z)
		rotation.y = lerp_angle(rotation.y, target, clampf(delta * 10.0, 0.0, 1.0))
