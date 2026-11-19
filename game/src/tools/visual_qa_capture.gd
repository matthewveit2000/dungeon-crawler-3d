extends Node
## Automated Player-POV Visual & Motion QA Capture (D-028).
## Boots the real game (and title screen) in a 1280x720 window, stages representative gameplay
## moments, opens every menu, and saves screenshots + a sequential combat clip to art/visual_qa/.
## Run via ./scripts/run-visual-qa.sh (Vulkan Forward+ by default; RENDER=opengl3 for the fallback).

var out_dir: String = ""
var game: GameMain = null
var only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://../art/visual_qa")
	# QA_OUT redirects captures (quick pose / layout iterations); QA_QUALITY overrides the preset (0-3)
	if not OS.get_environment("QA_OUT").is_empty():
		out_dir = OS.get_environment("QA_OUT")
	if not OS.get_environment("QA_QUALITY").is_empty() and GameSettings != null:
		GameSettings.set_value("graphics", "quality", int(OS.get_environment("QA_QUALITY")), false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))
	var env_only := OS.get_environment("QA_ONLY")
	if not env_only.is_empty():
		only = env_only.split(",")
	call_deferred("_run")


func _want(tag: String) -> bool:
	return only.is_empty() or only.has(tag)


func _wait(n: int = 3) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _shot(filename: String, settle: int = 3) -> void:
	await _wait(settle)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(filename))
	print("[visual-qa] Captured: %s" % filename)


func _look(from: Vector3, at: Vector3) -> void:
	game.player.global_position = from - Vector3(0, float(game.player.player_cfg["movement"]["eye_height"]), 0)
	var flat := Vector3(at.x - from.x, 0, at.z - from.z)
	game.player.rotation.y = atan2(-flat.x, -flat.z)
	var pitch := atan2(at.y - from.y, flat.length())
	game.player.pitch_rad = pitch
	game.player.head_pivot.rotation.x = pitch


func _step(n: int, dt: float = 0.033, inp: Dictionary = {}) -> void:
	for _i in range(n):
		game.player.step_simulation(dt, false, inp)


func _enemy(prefix: String) -> EnemyActor:
	for c in game.enemies_root.get_children():
		if c is EnemyActor and str((c as EnemyActor).enemy_id).begins_with(prefix):
			return c
	return null


func _room_center(room_id: int) -> Vector3:
	return game.current_layout.tile_to_world(game.current_layout.rooms[room_id]["center"])


func _run() -> void:
	# --- Title screen -------------------------------------------------------------
	if _want("title"):
		var title := TitleScreen.new()
		add_child(title)
		await _wait(50)
		await _shot("00_title_screen.png", 2)
		title.queue_free()
		await _wait(2)

	game = GameMain.new()
	game.run_seed = 20261118
	game.auto_load_save_on_ready = false
	add_child(game)
	await _wait(8)
	game.set_physics_process(false)
	var ent := _room_center(game.current_layout.entrance_room_id)
	if not _want("fp"):
		game.tutorial_sys.set_enabled(false)
		game._sync_tutorial_hud()

	if _want("fp"):
		game.player.quick_equip_preset(1)
		_look(ent + Vector3(0.0, 1.62, 3.4), ent + Vector3(0.0, 1.5, -6.0))
		_step(6)
		await _shot("01_fp_sword_shield.png", 8)
		# The field guide card is shown once above; hide it so the remaining shots show the scene
		game.tutorial_sys.set_enabled(false)
		game._sync_tutorial_hud()
		game.player.handle_hand_press("right_hand")
		_step(1)
		game.player.handle_hand_release("right_hand")
		_step(5, 0.033)
		await _shot("02_fp_sword_swing.png", 1)
		_step(20)
		_step(12, 0.04, {"left_held": true})
		await _shot("03_fp_shield_block.png", 2)
		_step(8, 0.04, {"left_held": false})
		game.player.quick_equip_preset(3)
		_step(6)
		await _shot("04_fp_sword_spell.png", 10)
		game.player.quick_equip_preset(4)
		game.player.handle_hand_press("right_hand")
		_step(22, 0.05)
		await _shot("05_fp_bow_drawn.png", 4)
		game.player.handle_hand_release("right_hand")
		_step(10)
		game.player.quick_equip_preset(2)
		_step(6)
		await _shot("05b_fp_battleaxe.png", 4)
		game.player.quick_equip_preset(1)
		_step(4)

	if _want("tp"):
		game.hud.clear_transient_messages()  # each scene group starts from a clean HUD, whatever ran before
		game.player.quick_equip_preset(1)
		_look(ent + Vector3(0.6, 1.62, 1.4), ent + Vector3(0.0, 1.4, -6.0))
		game.player.set_camera_mode("third_person")
		_step(4)
		await _shot("06_third_person.png", 10)
		game.player.set_camera_mode("first_person")
		_step(2)

	if _want("enemies"):
		game.hud.clear_transient_messages()
		# Stage a draugr mid-attack right in front of the player
		var d := _enemy("draugr")
		if d != null:
			_look(ent + Vector3(0.0, 1.62, 3.0), ent + Vector3(0.0, 1.3, -2.0))
			d.global_position = ent + Vector3(0.2, 0.05, 0.6)
			d.rotation.y = 0.0
			d.state = EnemyActor.AiState.ATTACK
			d.visual.play_state("idle_combat", 0.0)
			await _wait(4)
			d.visual.play_action("attack", 0.05)
			await _shot("07_draugr_attack.png", 9)
			d.global_position = Vector3(0, -50, 0)
		var a := _enemy("bone_archer")
		var g := _enemy("goblin")
		_look(ent + Vector3(-1.5, 1.62, 3.5), ent + Vector3(0.5, 1.2, -3.0))
		if a != null:
			a.global_position = ent + Vector3(1.6, 0.05, -2.6)
			a.rotation.y = -0.3
			a.visual.play_action("shoot", 0.05)
		if g != null:
			g.global_position = ent + Vector3(-0.4, 0.05, -1.0)
			g.rotation.y = 0.35
			g.visual.play_state("run", 0.0)
		await _shot("08_archer_and_goblin.png", 20)
		for e in [a, g]:
			if e != null:
				e.global_position = Vector3(0, -50, 0)

	if _want("corridor"):
		game.hud.clear_transient_messages()
		# find a corridor tile with a torch nearby
		var best := Vector2i(-1, -1)
		for y in range(game.current_layout.height):
			for x in range(game.current_layout.width):
				if game.current_layout.get_tile(x, y) == DungeonGenerator.TILE_CORRIDOR and game.current_layout.get_tile(x, y - 1) == DungeonGenerator.TILE_CORRIDOR \
						and game.current_layout.get_tile(x, y - 2) == DungeonGenerator.TILE_CORRIDOR and game.current_layout.get_tile(x, y - 3) == DungeonGenerator.TILE_CORRIDOR:
					best = Vector2i(x, y)
					break
			if best.x >= 0:
				break
		if best.x >= 0:
			var p := game.current_layout.tile_to_world(best)
			game.player.quick_equip_preset(1)
			_look(p + Vector3(0.0, 1.62, 1.5), p + Vector3(0.0, 1.6, -12.0))
			_step(3)
			await _shot("09_corridor.png", 10)

	if _want("safe"):
		game.hud.clear_transient_messages()
		var sc := _room_center(game.current_layout.safe_room_id)
		_look(sc + Vector3(1.4, 1.62, 4.6), sc + Vector3(-1.2, 1.3, -2.6))
		game.step_simulation(0.05)
		await _shot("10_safe_room.png", 14)

	if _want("boss") and game.boss_actor != null:
		var b := game.boss_actor
		var bc := b.global_position
		game.dungeon_builder.seal_boss_arena()
		_look(bc + Vector3(0.0, 1.62, 7.4), bc + Vector3(0.0, 2.2, 0.0))
		b.wake_boss()
		game.hud.clear_transient_messages()
		game.step_simulation(0.05)
		game._update_hud_navigation()
		await _shot("11_boss_arena.png", 22)

	if _want("menus"):
		game.run_console_command("spawn_loot sponsored")
		game.run_console_command("spawn_loot rare")
		game.run_console_command("spawn_loot epic")
		game.run_console_command("spawn_loot uncommon")
		game.run_console_command("add_xp 260")
		game.open_exclusive_menu("inventory")
		game.inventory_menu._selected_idx = game.player.inventory.size() - 4
		game.inventory_menu.refresh()
		await _shot("12_inventory.png", 8)
		game.inventory_menu._tabs.current_tab = 1
		await _shot("13_skills_perks.png", 6)
		game.open_exclusive_menu("vendor")
		game.vendor_menu._sel_side = "stock"
		game.vendor_menu._sel_idx = 0
		game.vendor_menu.refresh()
		await _shot("14_vendor.png", 6)
		for t in game.current_layout.landmarks:
			t["discovered"] = true
		for y in range(game.current_layout.height):
			for x in range(game.current_layout.width):
				if game.current_layout.is_walkable(x, y) and (x + y * 3) % 5 != 0:
					game.map_seen[Vector2i(x, y)] = true
		game.open_exclusive_menu("map")
		await _shot("15_map.png", 6)
		game.open_exclusive_menu("pause")
		await _shot("16_pause_menu.png", 8)
		game.pause_menu._show_section("settings")
		await _shot("17_settings.png", 6)
		game.close_all_menus()
		game.death_screen.show_reset("death", 1)
		game.death_screen._t = 4.0
		await _shot("18_death_screen.png", 4)
		game.death_screen.visible = false

	if _want("motion"):
		game.close_all_menus()
		game.hud.clear_transient_messages()
		game.hud.update_boss_bar(false)  # the boss woken for shot 11 is in another room
		game.player.quick_equip_preset(1)
		var d2 := _enemy("draugr")
		_look(ent + Vector3(0.0, 1.62, 3.2), ent + Vector3(0.0, 1.3, -2.0))
		if d2 != null:
			# Stand the draugr at its real attack range from where the walk-in ends
			d2.global_position = ent + Vector3(0.0, 0.05, -1.8)
			d2.rotation.y = 0.0
		for f in range(40):
			var inp: Dictionary = {"move_vec": Vector2(0.0, -0.25 if f < 3 else 0.0)}
			if f == 4 or f == 16:
				game.player.handle_hand_press("right_hand")
			elif f == 5 or f == 17:
				game.player.handle_hand_release("right_hand")
			elif f >= 26 and f < 34:
				inp["left_held"] = true
			if d2 != null and f == 22:
				d2.visual.play_action("attack", 0.05)
			if d2 != null and (f == 8 or f == 19):
				d2.visual.play_action("hit", 0.05)
				game.player.on_melee_hit(false)
				game._spawn_hit_feedback(d2.global_position + Vector3(0, 1.3, 0), 17.0 + f, f == 19)
			game.player.step_simulation(1.0 / 20.0, false, inp)
			await _wait(1)
			var fimg: Image = get_viewport().get_texture().get_image()
			fimg.save_png(out_dir.path_join("frames/frame_%03d.png" % f))
		print("[visual-qa] Captured 40 sequential motion frames.")

	if _want("clips"):
		await _record_clips(ent)

	get_tree().quit(0)


## Extra showcase clips (QA_ONLY=clips): each is saved to clips/<name>/frame_NNN.png and encoded by the caller.
## Run with --fixed-fps 20 so animation and simulation advance exactly 1/20 s per captured frame.
func _clip_frame(name: String, f: int) -> void:
	await _wait(1)
	var dir := out_dir.path_join("clips/" + name)
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("frame_%03d.png" % f))


## QA_CLIPS=bow,spell limits which showcase clips are recorded.
func _clip_want(name: String) -> bool:
	var only_clips := OS.get_environment("QA_CLIPS")
	return only_clips.is_empty() or only_clips.split(",").has(name)


func _sim(inp: Dictionary = {}) -> void:
	game.step_simulation(1.0 / 20.0, inp)


func _record_clips(ent: Vector3) -> void:
	game.close_all_menus()
	game.hud.update_boss_bar(false)
	var dt := 1.0 / 20.0

	# 1. Walking a torch-lit corridor
	var best := Vector2i(-1, -1)
	for y in range(game.current_layout.height):
		for x in range(game.current_layout.width):
			if game.current_layout.get_tile(x, y) == DungeonGenerator.TILE_CORRIDOR and game.current_layout.get_tile(x, y - 1) == DungeonGenerator.TILE_CORRIDOR \
					and game.current_layout.get_tile(x, y - 2) == DungeonGenerator.TILE_CORRIDOR and game.current_layout.get_tile(x, y - 3) == DungeonGenerator.TILE_CORRIDOR:
				best = Vector2i(x, y)
				break
		if best.x >= 0:
			break
	if best.x >= 0 and _clip_want("corridor_walk"):
		var cp := game.current_layout.tile_to_world(best)
		game.player.quick_equip_preset(1)
		_look(cp + Vector3(0.0, 1.62, 2.0), cp + Vector3(0.0, 1.6, -12.0))
		game.hud.clear_transient_messages()
		for f in range(44):
			game.player.step_simulation(dt, false, {"move_vec": Vector2(0.0, -1.0)})
			await _clip_frame("corridor_walk", f)
	print("[visual-qa] Captured clip: corridor_walk")

	# 2. Bow: draw, hold, loose (twice)
	if _clip_want("bow"):
		game.player.quick_equip_preset(4)
		_look(ent + Vector3(0.0, 1.62, 3.4), ent + Vector3(0.0, 1.5, -6.0))
		game.hud.clear_transient_messages()
		for f in range(48):
			if f == 2 or f == 28:
				game.player.handle_hand_press("right_hand")
			elif f == 20 or f == 44:
				game.player.handle_hand_release("right_hand")
			_sim()
			await _clip_frame("bow", f)
		print("[visual-qa] Captured clip: bow")

	# 3. Sword & firebolt: cast twice from the off hand, then a sword cut
	if _clip_want("spell"):
		game.player.quick_equip_preset(3)
		_look(ent + Vector3(0.0, 1.62, 3.4), ent + Vector3(0.0, 1.5, -6.0))
		game.hud.clear_transient_messages()
		for f in range(40):
			if f == 3 or f == 18:
				game.player.handle_hand_press("left_hand")
			elif f == 30:
				game.player.handle_hand_press("right_hand")
			elif f == 31:
				game.player.handle_hand_release("right_hand")
			_sim()
			await _clip_frame("spell", f)
		print("[visual-qa] Captured clip: spell")

	# 4. Two-handed battleaxe: light chop, then a held power cleave
	if _clip_want("battleaxe"):
		game.player.quick_equip_preset(2)
		_look(ent + Vector3(0.0, 1.62, 3.4), ent + Vector3(0.0, 1.5, -6.0))
		game.hud.clear_transient_messages()
		for f in range(44):
			if f == 3 or f == 20:
				game.player.handle_hand_press("right_hand")
			elif f == 4 or f == 30:
				game.player.handle_hand_release("right_hand")
			_sim()
			await _clip_frame("battleaxe", f)
		print("[visual-qa] Captured clip: battleaxe")

	# 5. Third person: walk forward, turn, swing
	if _clip_want("third_person"):
		game.player.quick_equip_preset(1)
		_look(ent + Vector3(0.6, 1.62, 2.6), ent + Vector3(0.0, 1.4, -6.0))
		game.player.set_camera_mode("third_person")
		game.hud.clear_transient_messages()
		for f in range(48):
			var inp: Dictionary = {"move_vec": Vector2(0.0, -1.0) if f < 26 else Vector2.ZERO}
			if f >= 18 and f < 30:
				game.player.rotation.y += 0.035
			if f == 32:
				game.player.handle_hand_press("right_hand")
			elif f == 33:
				game.player.handle_hand_release("right_hand")
			_sim(inp)
			await _clip_frame("third_person", f)
		game.player.set_camera_mode("first_person")
		print("[visual-qa] Captured clip: third_person")

	# 6. The Iron Warden: roar, then a ground slam (animation only, AI paused)
	if game.boss_actor != null and _clip_want("boss"):
		var b := game.boss_actor
		var bc := b.global_position
		game.player.quick_equip_preset(1)
		_look(bc + Vector3(0.8, 1.62, 4.6), bc + Vector3(0.0, 2.3, 0.0))
		b.visual.play_state("idle_combat", 0.0)
		game.hud.clear_transient_messages()
		for f in range(64):
			if f == 2:
				b.visual.play_action("roar", 0.1)
			elif f == 40:
				b.visual.play_action("slam", 0.1)
			game.player.step_simulation(dt, false, {})
			await _clip_frame("boss", f)
	print("[visual-qa] Captured clip: boss")
