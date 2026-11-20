extends Node
## Comprehensive Animation Review Capture Harness.
## Captures smooth fixed-FPS frame sequences of EVERY animation in the game:
##   - First-person viewmodels: fp_sword_shield, fp_battleaxe, fp_bow, fp_spell_dual
##   - Third-person live gameplay: tp_gameplay
##   - Every rigged character (all clips with real weapons):
##       char_crawler, char_draugr, char_bone_archer, char_goblin_streamer, char_iron_warden, char_vendor
##   - World & prop animations: world_props
##
## Run via ./scripts/record-anim-review.sh [out_dir] [only_csv]

var out_dir: String = ""
var only: PackedStringArray = PackedStringArray()
var fps: int = 24
var dt: float = 1.0 / 24.0
var game: GameMain = null

var _overlay_layer: CanvasLayer = null
var _label_title: Label = null
var _label_sub: Label = null
var _stage_cam: Camera3D = null
var _stage_key: DirectionalLight3D = null
var _stage_fill: OmniLight3D = null
var _stage_rim: OmniLight3D = null


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://../art/anim_review")
	if not OS.get_environment("ANIM_OUT").is_empty():
		out_dir = OS.get_environment("ANIM_OUT")
	if not OS.get_environment("ANIM_FPS").is_empty():
		fps = maxi(10, int(OS.get_environment("ANIM_FPS")))
	dt = 1.0 / float(fps)
	if not OS.get_environment("ANIM_QUALITY").is_empty() and GameSettings != null:
		GameSettings.set_value("graphics", "quality", int(OS.get_environment("ANIM_QUALITY")), false)
	var env_only := OS.get_environment("ANIM_ONLY")
	if not env_only.is_empty():
		only = env_only.split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("_run")


func _want(clip_name: String) -> bool:
	return only.is_empty() or only.has(clip_name)


func _wait(n: int = 2) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 50
	add_child(_overlay_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.78)
	sb.border_color = Color(0.76, 0.60, 0.30, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	_overlay_layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	_label_title = Label.new()
	_label_title.add_theme_font_size_override("font_size", 18)
	_label_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56))
	vb.add_child(_label_title)
	_label_sub = Label.new()
	_label_sub.add_theme_font_size_override("font_size", 14)
	_label_sub.add_theme_color_override("font_color", Color(0.88, 0.86, 0.82))
	vb.add_child(_label_sub)


func _set_banner(title: String, sub: String) -> void:
	if _label_title != null:
		_label_title.text = title
	if _label_sub != null:
		_label_sub.text = sub


func _ensure_stage_rig() -> void:
	if _stage_cam != null:
		return
	_stage_cam = Camera3D.new()
	_stage_cam.fov = 44.0
	_stage_cam.near = 0.05
	add_child(_stage_cam)

	_stage_key = DirectionalLight3D.new()
	_stage_key.light_color = Color(1.0, 0.90, 0.76)
	_stage_key.light_energy = 1.15
	_stage_key.rotation_degrees = Vector3(-34, 32, 0)
	_stage_key.shadow_enabled = false
	add_child(_stage_key)

	_stage_fill = OmniLight3D.new()
	_stage_fill.light_color = Color(0.75, 0.82, 0.98)
	_stage_fill.light_energy = 1.4
	_stage_fill.omni_range = 10.0
	_stage_fill.shadow_enabled = false
	add_child(_stage_fill)

	_stage_rim = OmniLight3D.new()
	_stage_rim.light_color = Color(1.0, 0.72, 0.42)
	_stage_rim.light_energy = 1.6
	_stage_rim.omni_range = 10.0
	_stage_rim.shadow_enabled = false
	add_child(_stage_rim)


func _set_stage_active(active: bool) -> void:
	if _stage_cam != null:
		_stage_cam.current = active
	if game != null and game.player != null:
		if game.player.camera != null:
			game.player.camera.current = not active
		if game.player.fp_rig != null:
			game.player.fp_rig.visible = (not active) and (game.player.camera_mode == "first_person")
		if game.player.tp_mesh != null:
			game.player.tp_mesh.visible = (not active) and (game.player.camera_mode == "third_person")
	if _stage_key != null:
		_stage_key.visible = active
	if _stage_fill != null:
		_stage_fill.visible = active
	if _stage_rim != null:
		_stage_rim.visible = active
	if game != null and game.hud != null:
		game.hud.visible = not active


func _snap(clip_name: String, idx: int) -> void:
	var dir := out_dir.path_join(clip_name)
	DirAccess.make_dir_recursive_absolute(dir)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("frame_%04d.png" % idx))


func _look_player(from: Vector3, at: Vector3) -> void:
	game.player.global_position = from - Vector3(0, float(game.player.player_cfg["movement"]["eye_height"]), 0)
	var flat := Vector3(at.x - from.x, 0, at.z - from.z)
	game.player.rotation.y = atan2(-flat.x, -flat.z)
	var pitch := atan2(at.y - from.y, flat.length())
	game.player.pitch_rad = pitch
	game.player.head_pivot.rotation.x = pitch


func _room_center(room_id: int) -> Vector3:
	return game.current_layout.tile_to_world(game.current_layout.rooms[room_id]["center"])


func _clear_enemies() -> void:
	for c in game.enemies_root.get_children():
		if c is EnemyActor:
			(c as EnemyActor).global_position = Vector3(0, -80, 0)


func _find_corridor_start() -> Vector3:
	for y in range(game.current_layout.height):
		for x in range(game.current_layout.width):
			if game.current_layout.get_tile(x, y) == DungeonGenerator.TILE_CORRIDOR \
					and game.current_layout.get_tile(x, y - 1) == DungeonGenerator.TILE_CORRIDOR \
					and game.current_layout.get_tile(x, y - 2) == DungeonGenerator.TILE_CORRIDOR \
					and game.current_layout.get_tile(x, y - 3) == DungeonGenerator.TILE_CORRIDOR:
				return game.current_layout.tile_to_world(Vector2i(x, y))
	return _room_center(game.current_layout.entrance_room_id)


var _stage_room: Node3D = null


func _needs_full_game() -> bool:
	for k in ["fp_sword_shield", "fp_battleaxe", "fp_bow", "fp_spell_dual", "tp_gameplay", "world_props"]:
		if _want(k):
			return true
	return false


func _build_lightweight_stage() -> Vector3:
	DataLoader.ensure_loaded()
	_stage_room = Node3D.new()
	_stage_room.name = "NordicStageHall"
	add_child(_stage_room)
	var env := WorldEnvironment.new()
	var e := DungeonBuilder.build_environment(DataLoader.get_floor_config(1), 0)
	e.glow_enabled = false
	env.environment = e
	_stage_room.add_child(env)
	var ts := 4.0
	for gx in range(-1, 2):
		for gz in range(-1, 3):
			var fl := ModelLoader.instantiate_model("res://assets/models/kit/floor_%s.glb" % ["a", "b", "c"][absi(gx + gz * 3) % 3])
			fl.position = Vector3(gx * ts, 0.0, gz * ts)
			_stage_room.add_child(fl)
	for gx in range(-1, 2):
		var wb := ModelLoader.instantiate_model("res://assets/models/kit/wall_%s.glb" % ["a", "b", "c"][absi(gx) % 3])
		wb.position = Vector3(gx * ts, 0.0, -1.5 * ts)
		_stage_room.add_child(wb)
	for gz in range(-1, 3):
		var wl := ModelLoader.instantiate_model("res://assets/models/kit/wall_%s.glb" % ["a", "b", "c"][absi(gz) % 3])
		wl.position = Vector3(-1.5 * ts, 0.0, gz * ts)
		wl.rotation.y = PI * 0.5
		_stage_room.add_child(wl)
	for px in [-4.0, 4.0]:
		var pil := ModelLoader.instantiate_model("res://assets/models/kit/pillar.glb")
		pil.position = Vector3(px, 0.0, -4.5)
		_stage_room.add_child(pil)
	var braz := ModelLoader.instantiate_model("res://assets/models/props/brazier.glb")
	braz.position = Vector3(-2.6, 0.0, -3.5)
	_stage_room.add_child(braz)
	return Vector3.ZERO


func _run() -> void:
	_build_overlay()
	_ensure_stage_rig()
	var ent := Vector3.ZERO

	if _needs_full_game():
		game = GameMain.new()
		game.run_seed = 20261118
		game.auto_load_save_on_ready = false
		add_child(game)
		await _wait(6)
		game.set_physics_process(false)
		game.tutorial_sys.set_enabled(false)
		game._sync_tutorial_hud()
		game.hud.clear_transient_messages()
		game.hud.update_boss_bar(false)
		_clear_enemies()
		ent = _room_center(game.current_layout.entrance_room_id)
	else:
		ent = _build_lightweight_stage()
		await _wait(3)

	if _want("fp_sword_shield"):
		await _rec_fp_sword_shield(ent)
	if _want("fp_battleaxe"):
		await _rec_fp_battleaxe(ent)
	if _want("fp_bow"):
		await _rec_fp_bow(ent)
	if _want("fp_spell_dual"):
		await _rec_fp_spell_dual(ent)
	if _want("tp_gameplay"):
		await _rec_tp_gameplay(ent)

	if _want("char_crawler"):
		await _rec_character_reel("char_crawler", "crawler", "PLAYER CRAWLER (3RD PERSON)", ent, 1.84, 1.84,
			["idle", "idle_combat", "walk", "run", "attack", "attack_2h", "block", "cast", "draw_hold", "bow_shoot", "hit", "death"])
	if _want("char_draugr"):
		await _rec_character_reel("char_draugr", "draugr", "HOLLOW DRAUGR RAIDER", ent, 1.86, 1.86,
			["idle", "idle_combat", "walk", "run", "attack", "hit", "death"])
	if _want("char_bone_archer"):
		await _rec_character_reel("char_bone_archer", "bone_archer", "CRYPT BONE ARCHER", ent, 1.82, 1.82,
			["idle", "idle_combat", "walk", "run", "shoot", "attack", "hit", "death"])
	if _want("char_goblin_streamer"):
		await _rec_character_reel("char_goblin_streamer", "goblin_streamer", "SPONSORED GOBLIN STREAMER", ent, 1.62, 1.25,
			["idle", "idle_combat", "walk", "run", "attack", "hit", "death"])
	if _want("char_iron_warden"):
		await _rec_character_reel("char_iron_warden", "iron_warden", "THE IRON WARDEN (BOSS)", ent, 3.05, 2.95,
			["idle", "idle_combat", "walk", "run", "roar", "slam", "attack", "hit", "death"])
	if _want("char_vendor"):
		await _rec_character_reel("char_vendor", "vendor", "SAFE ROOM MERCHANT", ent, 1.78, 1.78,
			["idle", "talk", "walk", "hit", "death"])

	if _want("world_props"):
		await _rec_world_props(ent)

	print("[anim-review] Capture complete -> %s" % out_dir)
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# First-Person Viewmodel Clips
# ---------------------------------------------------------------------------

func _rec_fp_sword_shield(ent: Vector3) -> void:
	_set_stage_active(false)
	game.player.set_camera_mode("first_person")
	game.player.quick_equip_preset(1)
	game.player._equip_raise = 0.0
	game.player.stamina = game.player.max_stamina
	_look_player(ent + Vector3(0.0, 1.62, 5.4), ent + Vector3(0.0, 1.48, -6.0))
	game.hud.clear_transient_messages()
	var f := 0

	# 1. Idle breathing
	_set_banner("FIRST-PERSON · SWORD & SHIELD", "Idle Breathing")
	for _i in range(int(0.8 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1

	# 2. Walk forward (0.85s = ~4.5m across entrance hall, clear of walls)
	_set_banner("FIRST-PERSON · SWORD & SHIELD", "Walk Forward")
	for _i in range(int(0.85 * fps)):
		game.player.step_simulation(dt, false, {"move_vec": Vector2(0.0, -1.0)})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1

	# 3. Sprint forward (reset to back of hall so sprint stays in open space)
	_look_player(ent + Vector3(0.0, 1.62, 5.4), ent + Vector3(0.0, 1.48, -6.0))
	_set_banner("FIRST-PERSON · SWORD & SHIELD", "Sprint")
	for _i in range(int(0.85 * fps)):
		game.player.step_simulation(dt, false, {"move_vec": Vector2(0.0, -1.0), "sprint": true})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1

	# 4. Light Combo: Forehand + Backhand
	_look_player(ent + Vector3(0.0, 1.62, 3.2), ent + Vector3(0.0, 1.45, -6.0))
	for _i in range(6):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
	_set_banner("FIRST-PERSON · SWORD & SHIELD", "Light Slash #1 (Forehand)")
	game.player.handle_hand_press("right_hand")
	game.player.step_simulation(dt, false, {})
	game.player.handle_hand_release("right_hand")
	for _i in range(int(0.75 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1

	_set_banner("FIRST-PERSON · SWORD & SHIELD", "Light Slash #2 (Backhand Riposte)")
	game.player.handle_hand_press("right_hand")
	game.player.step_simulation(dt, false, {})
	game.player.handle_hand_release("right_hand")
	for _i in range(int(0.75 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1

	# 5. Power Attack Charge + Cleave
	_set_banner("FIRST-PERSON · SWORD & SHIELD", "Power Attack (Charge -> Cleave)")
	game.player.stamina = game.player.max_stamina
	game.player.handle_hand_press("right_hand")
	for _i in range(int(0.55 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1
	game.player.handle_hand_release("right_hand")
	for i in range(int(0.9 * fps)):
		if i == int(0.22 * fps):
			game.player.on_melee_hit(true)
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1

	# 6. Shield Block Raise, Impact Recoil, Lower
	_set_banner("FIRST-PERSON · SWORD & SHIELD", "Shield Block Raise -> Impact -> Lower")
	for i in range(int(1.25 * fps)):
		if i == int(0.55 * fps):
			game.player._left_action_t = 0.24
			game.player._left_action_dur = 0.24
			game.player._camera_kick = 0.38
		game.player.step_simulation(dt, false, {"left_held": i < int(0.95 * fps)})
		await _wait(1)
		_snap("fp_sword_shield", f); f += 1

	print("[anim-review] Captured fp_sword_shield (%d frames)" % f)


func _rec_fp_battleaxe(ent: Vector3) -> void:
	_set_stage_active(false)
	game.player.set_camera_mode("first_person")
	game.player.quick_equip_preset(2)
	game.player.stamina = game.player.max_stamina
	_look_player(ent + Vector3(0.0, 1.62, 5.4), ent + Vector3(0.0, 1.48, -6.0))
	game.hud.clear_transient_messages()
	var f := 0

	_set_banner("FIRST-PERSON · TWO-HANDED BATTLEAXE", "Equip Raise & Idle Carry")
	for _i in range(int(0.8 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_battleaxe", f); f += 1

	_set_banner("FIRST-PERSON · TWO-HANDED BATTLEAXE", "Walk Forward")
	for _i in range(int(0.85 * fps)):
		game.player.step_simulation(dt, false, {"move_vec": Vector2(0.0, -1.0)})
		await _wait(1)
		_snap("fp_battleaxe", f); f += 1

	_look_player(ent + Vector3(0.0, 1.62, 5.4), ent + Vector3(0.0, 1.48, -6.0))
	_set_banner("FIRST-PERSON · TWO-HANDED BATTLEAXE", "Sprint")
	for _i in range(int(0.8 * fps)):
		game.player.step_simulation(dt, false, {"move_vec": Vector2(0.0, -1.0), "sprint": true})
		await _wait(1)
		_snap("fp_battleaxe", f); f += 1

	_look_player(ent + Vector3(0.0, 1.62, 3.2), ent + Vector3(0.0, 1.45, -6.0))
	for _i in range(6):
		game.player.step_simulation(dt, false, {})
		await _wait(1)

	_set_banner("FIRST-PERSON · TWO-HANDED BATTLEAXE", "Light Diagonal Cleave #1")
	game.player.handle_hand_press("right_hand")
	game.player.step_simulation(dt, false, {})
	game.player.handle_hand_release("right_hand")
	for _i in range(int(0.95 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_battleaxe", f); f += 1

	_set_banner("FIRST-PERSON · TWO-HANDED BATTLEAXE", "Light Cross-Cleave #2")
	game.player.stamina = game.player.max_stamina
	game.player.handle_hand_press("right_hand")
	game.player.step_simulation(dt, false, {})
	game.player.handle_hand_release("right_hand")
	for _i in range(int(0.95 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_battleaxe", f); f += 1

	_set_banner("FIRST-PERSON · TWO-HANDED BATTLEAXE", "Power Overhead Slam (Charge -> Cleave)")
	game.player.stamina = game.player.max_stamina
	game.player.handle_hand_press("right_hand")
	for _i in range(int(0.55 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_battleaxe", f); f += 1
	game.player.handle_hand_release("right_hand")
	for _i in range(int(1.05 * fps)):
		game.player.step_simulation(dt, false, {})
		await _wait(1)
		_snap("fp_battleaxe", f); f += 1

	print("[anim-review] Captured fp_battleaxe (%d frames)" % f)


func _rec_fp_bow(ent: Vector3) -> void:
	_set_stage_active(false)
	game.player.set_camera_mode("first_person")
	game.player.quick_equip_preset(4)
	game.player.stamina = game.player.max_stamina
	_look_player(ent + Vector3(0.0, 1.62, 4.6), ent + Vector3(0.0, 1.48, -6.0))
	game.hud.clear_transient_messages()
	var f := 0

	_set_banner("FIRST-PERSON · HUNTING BOW", "Equip Raise -> Idle -> Walk")
	for i in range(int(1.4 * fps)):
		var mv := Vector2(0.0, -1.0) if i >= int(0.75 * fps) else Vector2.ZERO
		game.player.step_simulation(dt, false, {"move_vec": mv})
		await _wait(1)
		_snap("fp_bow", f); f += 1

	_set_banner("FIRST-PERSON · HUNTING BOW", "Full Draw -> Hold -> Release + String Twang")
	game.player.handle_hand_press("right_hand")
	for _i in range(int(1.25 * fps)):
		game.step_simulation(dt, {})
		await _wait(1)
		_snap("fp_bow", f); f += 1
	game.player.handle_hand_release("right_hand")
	for _i in range(int(0.95 * fps)):
		game.step_simulation(dt, {})
		await _wait(1)
		_snap("fp_bow", f); f += 1

	_set_banner("FIRST-PERSON · HUNTING BOW", "Quick Follow-up Shot")
	game.player.handle_hand_press("right_hand")
	for _i in range(int(0.65 * fps)):
		game.step_simulation(dt, {})
		await _wait(1)
		_snap("fp_bow", f); f += 1
	game.player.handle_hand_release("right_hand")
	for _i in range(int(0.8 * fps)):
		game.step_simulation(dt, {})
		await _wait(1)
		_snap("fp_bow", f); f += 1

	print("[anim-review] Captured fp_bow (%d frames)" % f)


func _rec_fp_spell_dual(ent: Vector3) -> void:
	_set_stage_active(false)
	game.player.set_camera_mode("first_person")
	game.player.quick_equip_preset(3)
	game.player._equip_raise = 0.0
	game.player.magicka = game.player.max_magicka
	game.player.stamina = game.player.max_stamina
	_look_player(ent + Vector3(0.0, 1.62, 3.6), ent + Vector3(0.0, 1.48, -6.0))
	game.hud.clear_transient_messages()
	var f := 0

	_set_banner("FIRST-PERSON · SWORD & SPELL", "Left Firebolt Cast x2 -> Right Sword Slash")
	for i in range(int(2.5 * fps)):
		if i == int(0.45 * fps) or i == int(1.2 * fps):
			game.player.magicka = game.player.max_magicka
			game.player.handle_hand_press("left_hand")
		elif i == int(1.85 * fps):
			game.player.handle_hand_press("right_hand")
		elif i == int(1.85 * fps) + 1:
			game.player.handle_hand_release("right_hand")
		game.step_simulation(dt, {})
		await _wait(1)
		_snap("fp_spell_dual", f); f += 1

	# Dual-wield two weapons (left alternating + right!)
	var cleaver_def := DataLoader.get_item_def("sponsored_blade_ratings")
	if cleaver_def.is_empty():
		cleaver_def = DataLoader.get_item_def("iron_longsword")
	var off_w := LootGenerator.make_base_item_instance(cleaver_def, "qa_dual_left")
	game.player.equipment["left_hand"] = off_w
	game.player.refresh_hand_visuals()
	game.player._equip_raise = 0.0
	_set_banner("FIRST-PERSON · DUAL WIELD", "Left Slash #1 -> Right Slash -> Left Slash #2")
	for i in range(int(2.4 * fps)):
		if i == int(0.3 * fps) or i == int(1.55 * fps):
			game.player.stamina = game.player.max_stamina
			game.player.handle_hand_press("left_hand")
		elif i == int(0.95 * fps):
			game.player.stamina = game.player.max_stamina
			game.player.handle_hand_press("right_hand")
		elif i == int(0.95 * fps) + 1:
			game.player.handle_hand_release("right_hand")
		game.step_simulation(dt, {})
		await _wait(1)
		_snap("fp_spell_dual", f); f += 1

	print("[anim-review] Captured fp_spell_dual (%d frames)" % f)


# ---------------------------------------------------------------------------
# Third-Person Live Gameplay
# ---------------------------------------------------------------------------

func _rec_tp_gameplay(ent: Vector3) -> void:
	_set_stage_active(false)
	game.player.quick_equip_preset(1)
	game.player.set_camera_mode("third_person")
	game.player.stamina = game.player.max_stamina
	game.player.magicka = game.player.max_magicka
	_look_player(ent + Vector3(0.3, 1.62, 2.4), ent + Vector3(0.0, 1.4, -6.0))
	game.hud.clear_transient_messages()
	var f := 0

	_set_banner("THIRD-PERSON GAMEPLAY", "Combat Guard -> Walk -> Sprint -> Turn")
	for i in range(int(2.4 * fps)):
		var inp := {}
		if i >= int(0.40 * fps) and i < int(1.25 * fps):
			inp["move_vec"] = Vector2(0.0, -0.55)
		elif i >= int(1.25 * fps) and i < int(1.95 * fps):
			inp["move_vec"] = Vector2(0.0, -1.0)
			inp["sprint"] = true
		if i >= int(1.4 * fps) and i < int(2.0 * fps):
			game.player.rotation.y += 0.03
		game.step_simulation(dt, inp)
		await _wait(1)
		_snap("tp_gameplay", f); f += 1

	# Re-center cleanly in middle of entrance hall for unobstructed 3rd-person combat showcase
	_look_player(ent + Vector3(0.0, 1.62, 1.0), ent + Vector3(-1.2, 1.4, -6.0))
	_set_banner("THIRD-PERSON GAMEPLAY", "1H Attack -> Block -> 2H Axe -> Spell -> Bow Shoot")
	for i in range(int(4.8 * fps)):
		var inp := {}
		if i == int(0.15 * fps):
			game.player.handle_hand_press("right_hand")
		elif i == int(0.15 * fps) + 1:
			game.player.handle_hand_release("right_hand")
		elif i >= int(0.95 * fps) and i < int(1.65 * fps):
			inp["left_held"] = true
		elif i == int(1.75 * fps):
			game.player.quick_equip_preset(2)
			game.player.stamina = game.player.max_stamina
			game.player.handle_hand_press("right_hand")
		elif i == int(1.75 * fps) + 1:
			game.player.handle_hand_release("right_hand")
		elif i == int(2.95 * fps):
			game.player.quick_equip_preset(3)
			game.player.magicka = game.player.max_magicka
			game.player.handle_hand_press("left_hand")
		elif i == int(3.65 * fps):
			game.player.quick_equip_preset(4)
			game.player.handle_hand_press("right_hand")
		elif i == int(4.25 * fps):
			game.player.handle_hand_release("right_hand")
		game.step_simulation(dt, inp)
		await _wait(1)
		_snap("tp_gameplay", f); f += 1

	game.player.set_camera_mode("first_person")
	print("[anim-review] Captured tp_gameplay (%d frames)" % f)


# ---------------------------------------------------------------------------
# Rigged Character Full Animation Reels (Every Clip, Real Weapons, Floor Contact)
# ---------------------------------------------------------------------------

func _equip_showcase_weapons(cv: CharacterVisual, kind: String, mode: String = "default") -> Dictionary:
	for grip_name in ["GripR", "GripL"]:
		var g := cv.model.find_child(grip_name + "*", true, false) as Node3D
		if g != null:
			for c in g.get_children():
				c.queue_free()
	var gr := cv.model.find_child("GripR*", true, false) as Node3D
	var gl := cv.model.find_child("GripL*", true, false) as Node3D
	var bow_rig := {}
	match kind:
		"crawler":
			if mode == "bow":
				if gl != null:
					var b := ModelLoader.instantiate_model("res://assets/models/gear/hunting_bow.glb", Vector3(0.05, 1.4, 0.1))
					gl.add_child(b)
					bow_rig = _init_showcase_bow(b, gr)
			elif mode == "2h":
				if gr != null:
					gr.add_child(ModelLoader.instantiate_model("res://assets/models/gear/battleaxe.glb", Vector3(0.05, 1.2, 0.05)))
			elif mode == "cast":
				if gr != null:
					gr.add_child(ModelLoader.instantiate_model("res://assets/models/gear/iron_sword.glb", Vector3(0.05, 0.9, 0.05)))
				if gl != null:
					gl.add_child(VfxFactory.make_glow(Color(1.0, 0.45, 0.15), 0.35, 1.8))
			else:
				if gr != null:
					gr.add_child(ModelLoader.instantiate_model("res://assets/models/gear/iron_sword.glb", Vector3(0.05, 0.9, 0.05)))
				if gl != null:
					var sh := ModelLoader.instantiate_model("res://assets/models/gear/round_shield.glb", Vector3(0.8, 0.8, 0.1))
					sh.rotation_degrees = Vector3(0.0, 90.0, 0.0)
					gl.add_child(sh)
		"draugr":
			if gr != null:
				gr.add_child(ModelLoader.instantiate_model("res://assets/models/gear/battleaxe.glb", Vector3(0.05, 1.2, 0.05)))
		"bone_archer":
			if gl != null:
				var b := ModelLoader.instantiate_model("res://assets/models/gear/hunting_bow.glb", Vector3(0.05, 1.4, 0.1))
				gl.add_child(b)
				bow_rig = _init_showcase_bow(b, gr)
		"goblin_streamer":
			if gr != null:
				var cl := ModelLoader.instantiate_model("res://assets/models/gear/ratings_cleaver.glb", Vector3(0.05, 0.7, 0.05))
				cl.scale = Vector3.ONE * 0.75
				gr.add_child(cl)
			var ring := cv.model.find_child("RingLight*", true, false) as Node3D
			if ring != null and ring.get_child_count() == 0:
				var rl := OmniLight3D.new()
				rl.light_color = Color(1.0, 0.35, 0.85)
				rl.light_energy = 1.2
				rl.omni_range = 3.5
				ring.add_child(rl)
		"iron_warden":
			if gr != null:
				var axe := ModelLoader.instantiate_model("res://assets/models/gear/battleaxe.glb", Vector3(0.05, 1.2, 0.05))
				axe.scale = Vector3.ONE * 2.1
				gr.add_child(axe)
			var core := cv.model.find_child("CoreSocket*", true, false) as Node3D
			if core != null and core.get_child_count() == 0:
				core.add_child(VfxFactory.make_glow(Color(1.0, 0.45, 0.15), 0.9, 1.4))
	return bow_rig


func _init_showcase_bow(b: Node3D, gr: Node3D) -> Dictionary:
	var st := b.find_child("StringTop*", true, false) as Node3D
	var sb := b.find_child("StringBottom*", true, false) as Node3D
	var arr := ModelLoader.instantiate_model("res://assets/models/gear/arrow.glb", Vector3(0.02, 0.7, 0.02))
	arr.visible = false
	b.add_child(arr)
	return {
		"bow": b,
		"st": st,
		"sb": sb,
		"tip_t": st.position if st != null else Vector3.ZERO,
		"tip_b": sb.position if sb != null else Vector3.ZERO,
		"rest_z": st.position.z if st != null else 0.0,
		"arrow": arr,
		"gr": gr,
	}


func _update_showcase_bow(bow_rig: Dictionary, drawing: bool) -> void:
	if bow_rig.is_empty():
		return
	var b: Node3D = bow_rig["bow"]
	var st: Node3D = bow_rig["st"]
	var sb: Node3D = bow_rig["sb"]
	var arr: Node3D = bow_rig["arrow"]
	var gr: Node3D = bow_rig["gr"]
	var rest_z: float = float(bow_rig["rest_z"])
	var nock_local := Vector3(0.0, 0.0, rest_z)
	if drawing and gr != null and is_instance_valid(gr) and is_instance_valid(b):
		var p_local := b.to_local(gr.global_position)
		var pull_z := clampf(p_local.z, rest_z - 0.52, rest_z)
		nock_local = Vector3(clampf(p_local.x, -0.04, 0.04), clampf(p_local.y, -0.05, 0.08), pull_z)
	if st != null and sb != null:
		EnemyActor._aim_bow_seg(st, bow_rig["tip_t"], nock_local)
		EnemyActor._aim_bow_seg(sb, bow_rig["tip_b"], nock_local)
	if arr != null:
		arr.visible = drawing
		if drawing:
			var rest_pt := Vector3(0.024, 0.055, 0.0)
			var dir := (rest_pt - nock_local).normalized()
			var y_ax := dir
			var x_ax := y_ax.cross(Vector3.UP).normalized()
			if x_ax.length() < 0.1:
				x_ax = Vector3.RIGHT
			var z_ax := x_ax.cross(y_ax).normalized()
			arr.transform = Transform3D(Basis(x_ax, y_ax, z_ax), nock_local + dir * 0.36)


func _aim_stage_at(pos: Vector3, height: float, angle_rad: float = 0.52) -> void:
	var dist := height * 1.78
	var cam_off := Vector3(sin(angle_rad) * dist, height * 0.58, cos(angle_rad) * dist)
	_stage_cam.global_position = pos + cam_off
	_stage_cam.look_at(pos + Vector3(0, height * 0.48, 0), Vector3.UP)
	_stage_fill.global_position = pos + Vector3(-1.8, height * 0.9, 2.2)
	_stage_rim.global_position = pos + Vector3(-1.4, height * 1.15, -2.0)


func _rec_character_reel(clip_name: String, kind: String, title: String, ent: Vector3, cam_height: float, body_height: float, clips: Array) -> void:
	_set_stage_active(true)
	var holder := Node3D.new()
	holder.position = ent + Vector3(0.0, 0.0, 0.0)
	add_child(holder)

	var cv := CharacterVisual.create(kind)
	holder.add_child(cv)
	var bow_rig := _equip_showcase_weapons(cv, kind, "default")
	await _wait(2)

	# True stride speed matching char_anims.py (4*stride_half / clip_duration) for 1:1 ground contact!
	var leg_len := body_height * 0.48
	var g_mult := 0.88 if kind == "vendor" else (1.08 if kind == "goblin_streamer" else 1.0)
	var walk_mps := (4.0 * 0.30 * leg_len * g_mult) / (32.0 / 30.0)
	var run_mps := (4.0 * 0.48 * leg_len * g_mult) / (20.0 / 30.0)

	var f := 0
	for anim_name_v in clips:
		var anim_name: String = str(anim_name_v)
		if not cv.has_anim(anim_name):
			continue
		if kind == "crawler":
			if anim_name in ["draw_hold", "bow_shoot"]:
				bow_rig = _equip_showcase_weapons(cv, kind, "bow")
			elif anim_name == "attack_2h":
				bow_rig = _equip_showcase_weapons(cv, kind, "2h")
			elif anim_name == "cast":
				bow_rig = _equip_showcase_weapons(cv, kind, "cast")
			else:
				bow_rig = _equip_showcase_weapons(cv, kind, "default")

		cv._dead = false
		cv.oneshot = ""
		cv.state = ""
		holder.position = ent + Vector3(0.0, 0.0, -1.8 if anim_name in ["walk", "run"] else 0.0)
		var a := cv.anim.get_animation(anim_name)
		var dur: float = a.length if a != null else 1.0
		var is_loop: bool = CharacterVisual.LOOPING.has(anim_name)
		var total_sec: float = maxf(1.4, dur * 1.45) if is_loop else (dur + (0.65 if anim_name == "death" else 0.32))
		var frames: int = int(round(total_sec * fps))

		_set_banner(title, "Clip: %s  (%.2fs)" % [anim_name, dur])
		if is_loop:
			cv.play_state(anim_name, 0.0, 1.0)
		else:
			cv.play_state("idle_combat" if cv.has_anim("idle_combat") else "idle", 0.0)
			cv.play_action(anim_name, 0.05, 1.0)

		var spd: float = walk_mps if anim_name == "walk" else (run_mps if anim_name == "run" else 0.0)
		for k in range(frames):
			if spd > 0.0:
				holder.position.z += spd * dt
			var ang: float = 0.72 if anim_name == "death" else (0.78 if anim_name in ["shoot", "draw_hold", "bow_shoot"] else 0.52)
			_aim_stage_at(holder.position, cam_height, ang)
			var is_draw: bool = (anim_name == "draw_hold") \
				or (anim_name == "bow_shoot" and cv.action_progress() < (2.5 / 24.0)) \
				or (anim_name == "shoot" and cv.action_progress() >= (9.0 / 46.0) and cv.action_progress() < (32.0 / 46.0))
			_update_showcase_bow(bow_rig, is_draw)
			await _wait(1)
			_snap(clip_name, f); f += 1

	holder.queue_free()
	await _wait(2)
	print("[anim-review] Captured %s (%d frames)" % [clip_name, f])


# ---------------------------------------------------------------------------
# World & Prop Animations
# ---------------------------------------------------------------------------

func _rec_world_props(ent: Vector3) -> void:
	_set_stage_active(true)
	var f := 0

	# 1. Chest opening
	var chest := InteractableObject.new()
	chest.setup("qa_chest", "chest", "Open Chest", {}, func(_i: InteractableObject, _a: Node3D) -> bool: return true)
	chest.position = ent + Vector3(0.0, 0.0, 0.0)
	var cm := ModelLoader.instantiate_model("res://assets/models/props/chest.glb", Vector3(1.0, 0.8, 0.6))
	chest.add_child(cm)
	chest.visual_root = cm
	add_child(chest)
	_aim_stage_at(chest.position, 1.15, 0.45)
	_set_banner("WORLD PROPS", "Chest Lid Opening (Weighted Hinge Settle)")
	await _wait(2)
	for i in range(int(1.25 * fps)):
		if i == 5:
			chest.trigger(game.player)
		await _wait(1)
		_snap("world_props", f); f += 1
	chest.queue_free()

	# 2. Lever throw (pivoted Handle only!) + Spike trap retract
	var lever := InteractableObject.new()
	lever.setup("qa_lever", "lever", "Pull Lever", {}, func(_i: InteractableObject, _a: Node3D) -> bool: return true)
	lever.position = ent + Vector3(-0.7, 0.0, 0.0)
	var lm := ModelLoader.instantiate_model("res://assets/models/props/lever.glb", Vector3(0.5, 1.3, 0.5))
	lever.add_child(lm)
	lever.visual_root = lm
	add_child(lever)
	var trap := ModelLoader.instantiate_model("res://assets/models/props/spike_trap.glb", Vector3(1.8, 0.35, 1.8))
	trap.position = ent + Vector3(0.95, 0.0, 0.0)
	add_child(trap)
	_aim_stage_at(ent + Vector3(0.15, 0.0, 0.0), 1.5, 0.55)
	_set_banner("WORLD PROPS", "Lever Handle Throw & Spike Trap Retraction")
	await _wait(2)
	for i in range(int(1.2 * fps)):
		if i == 5:
			lever.trigger(game.player)
			var tw := trap.create_tween()
			tw.tween_property(trap, "position:y", trap.position.y - 0.36, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await _wait(1)
		_snap("world_props", f); f += 1
	lever.queue_free()
	trap.queue_free()

	# 3. Urn search rock & settle
	var urn := InteractableObject.new()
	urn.setup("qa_urn", "urn", "Search Urn", {}, func(_i: InteractableObject, _a: Node3D) -> bool: return true)
	urn.position = ent + Vector3(0.0, 0.0, 0.0)
	var um := ModelLoader.instantiate_model("res://assets/models/props/urn.glb", Vector3(0.6, 0.9, 0.6))
	urn.add_child(um)
	urn.visual_root = um
	add_child(urn)
	_aim_stage_at(urn.position, 1.1, 0.45)
	_set_banner("WORLD PROPS", "Urn Search Rock & Settle")
	await _wait(2)
	for i in range(int(1.0 * fps)):
		if i == 4:
			urn.trigger(game.player)
		await _wait(1)
		_snap("world_props", f); f += 1
	urn.queue_free()

	# 4. Boss Portcullis gravity slam + metallic bounce & heavy winch raise
	if game.dungeon_builder.boss_gate_node != null:
		var bg := game.dungeon_builder.boss_gate_node
		var gp := bg.global_position
		var fwd := bg.global_transform.basis.z
		_stage_cam.global_position = gp + fwd * 4.8 + Vector3(1.1, 2.2, 0.0)
		_stage_cam.look_at(gp + Vector3(0, 1.8, 0), Vector3.UP)
		_stage_fill.global_position = gp + fwd * 3.0 + Vector3(-1.5, 2.5, 0)
		_stage_rim.global_position = gp - fwd * 2.0 + Vector3(1.5, 3.0, 0)
		_set_banner("WORLD PROPS", "Boss Portcullis Gravity Slam -> Winch Raise")
		for i in range(int(2.4 * fps)):
			if i == 5:
				game.dungeon_builder.seal_boss_arena()
			elif i == int(1.05 * fps):
				game.dungeon_builder.unlock_boss_and_vault()
			await _wait(1)
			_snap("world_props", f); f += 1

	# 5. Safe Room Sanctuary Beacon floating crystal + Merchant talking
	var sc := _room_center(game.current_layout.safe_room_id)
	_stage_cam.global_position = sc + Vector3(1.1, 1.65, 2.1)
	_stage_cam.look_at(sc + Vector3(-0.9, 1.35, -2.5), Vector3.UP)
	_stage_fill.global_position = sc + Vector3(0.0, 2.5, 1.5)
	_stage_rim.global_position = sc + Vector3(-2.5, 2.5, -1.0)
	if game.dungeon_builder.vendor_visual != null:
		game.dungeon_builder.vendor_visual.play_state("talk", 0.0)
	_set_banner("WORLD PROPS", "Safe Room Ward Crystal Hover & Merchant Talk")
	for _i in range(int(1.6 * fps)):
		await _wait(1)
		_snap("world_props", f); f += 1

	print("[anim-review] Captured world_props (%d frames)" % f)
