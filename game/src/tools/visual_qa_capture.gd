extends Node
## Automated Player-POV Visual & Motion QA Capture Tool (D-028).
## Boots the real GameMain 3D scene in a 1280x720 window (via Xvfb + OpenGL3),
## moves through real gameplay scenarios, opens actual menus, saves PNG screenshots
## & a 36-frame sequential combat motion clip to art/visual_qa/, and exits cleanly.

var out_dir: String = ""
var game: GameMain = null


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://../art/visual_qa")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("frames"))

	game = GameMain.new()
	game.run_seed = 20261118
	game.auto_load_save_on_ready = false
	add_child(game)
	call_deferred("_run_capture_sequence")


func _wait_frames(n: int = 3) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _save_shot(filename: String) -> void:
	await _wait_frames(3)
	var img: Image = get_viewport().get_texture().get_image()
	var path := out_dir.path_join(filename)
	img.save_png(path)
	print("[visual-qa] Captured: %s (%dx%d)" % [filename, img.get_width(), img.get_height()])


func _run_capture_sequence() -> void:
	await _wait_frames(6)
	# Drive simulation 100% deterministically so awaits between frames never erase swing/block poses!
	game.set_physics_process(false)

	# 1. Arrival Hall Entrance — 1st-person Sword & Shield + Active Tutorial Card (D-030)
	game.player.quick_equip_preset(1)
	var ent_center: Vector3 = game.current_layout.tile_to_world(game.current_layout.rooms[game.current_layout.entrance_room_id]["center"])
	game.player.global_position = ent_center + Vector3(0.0, 0.25, 2.8)
	game.player.look_at(ent_center + Vector3(0.0, 1.35, -3.0), Vector3.UP)
	game.player.head_pivot.rotation.x = -0.05
	game.step_simulation(0.05)
	await _save_shot("01_fp_sword_shield_entrance.png")

	# 2. First-person mid-swing with glowing golden blade streak!
	game.player.handle_hand_press("right_hand")
	game.step_simulation(0.04)
	game.player.handle_hand_release("right_hand")
	for _i in range(4):
		game.step_simulation(0.032)
	await _save_shot("02_fp_sword_swing.png")

	# Finish recovery before block shot
	for _i in range(10):
		game.step_simulation(0.04)

	# 3. First-person tactical Shield Block stance (with left_held override!)
	for _i in range(12):
		game.step_simulation(0.04, {"left_held": true})
	await _save_shot("03_fp_shield_block.png")
	for _i in range(8):
		game.step_simulation(0.04, {"left_held": false})

	# 4. Loadout 3: Sword + Compact Arcane Firebolt Orb
	game.player.quick_equip_preset(3)
	game.step_simulation(0.05)
	await _save_shot("04_fp_sword_spell.png")

	# 5. Loadout 4: Hunting Bow Drawn with Nocked Arrow & FOV Zoom
	game.player.quick_equip_preset(4)
	game.player.handle_hand_press("right_hand")
	for _i in range(14):
		game.step_simulation(0.06)
	await _save_shot("05_fp_bow_drawn.png")
	game.player.handle_hand_release("right_hand")

	# 6. Third-person Over-the-Shoulder (V) centered cleanly in Arrival Hall showing sculpted Nordic Crawler
	game.player.quick_equip_preset(1)
	game.player.global_position = ent_center + Vector3(0.0, 0.25, -0.4)
	game.player.look_at(ent_center + Vector3(0.0, 1.25, -6.0), Vector3.UP)
	game.player.head_pivot.rotation.x = -0.08
	game.player.toggle_camera_mode()
	game.step_simulation(0.05)
	await _save_shot("06_third_person_view.png")
	game.player.toggle_camera_mode()

	# 7. Handcrafted Safe Room Sanctuary (Warm Hearth + Merchant Stall + Robed Vendor + Emerald Beacon!)
	game.run_console_command("teleport safe")
	var safe_center: Vector3 = game.current_layout.tile_to_world(game.current_layout.rooms[game.current_layout.safe_room_id]["center"])
	game.player.global_position = safe_center + Vector3(0.2, 0.3, 4.2)
	game.player.look_at(safe_center + Vector3(-0.6, 1.35, -2.0), Vector3.UP)
	game.player.head_pivot.rotation.x = -0.04
	game.step_simulation(0.05)
	await _save_shot("07_safe_room.png")

	# 8. Handcrafted Boss Arena facing the Towering Iron Warden on the Rune Dais (+ Boss HP Bar!)
	game.run_console_command("teleport boss")
	if game.boss_actor != null and is_instance_valid(game.boss_actor):
		game.player.global_position = game.boss_actor.global_position + Vector3(0.0, 0.3, 5.8)
		game.player.look_at(game.boss_actor.global_position + Vector3(0.0, 1.85, 0.0), Vector3.UP)
		game.player.head_pivot.rotation.x = 0.05
	game.step_simulation(0.05)
	await _save_shot("08_boss_arena.png")

	# 9. Menus (ACTUAL open_exclusive_menu calls so menus render cleanly!)
	game.run_console_command("spawn_loot sponsored")
	game.run_console_command("add_xp 260")
	game.open_exclusive_menu("inventory")
	await _save_shot("09_inventory_menu.png")

	game.open_exclusive_menu("vendor")
	await _save_shot("10_vendor_menu.png")

	game.open_exclusive_menu("pause")
	await _save_shot("11_pause_menu.png")
	game.close_all_menus()

	# 10. 36-Frame Fluid Combat Motion Capture Sequence (walk -> slash combo -> block -> spell cast facing Boss!)
	game.run_console_command("teleport boss")
	game.player.quick_equip_preset(1)
	if game.boss_actor != null and is_instance_valid(game.boss_actor):
		game.player.global_position = game.boss_actor.global_position + Vector3(0.0, 0.3, 5.6)
		game.player.look_at(game.boss_actor.global_position + Vector3(0.0, 1.75, 0.0), Vector3.UP)
		game.player.head_pivot.rotation.x = 0.03

	for f in range(36):
		var inp: Dictionary = {"move_vec": Vector2(0.35 if f < 16 else -0.35, -0.35 if f < 10 else 0.15)}
		if f == 5:
			game.player.handle_hand_press("right_hand")
		elif f == 7:
			game.player.handle_hand_release("right_hand")
		elif f == 15:
			game.player.handle_hand_press("right_hand")
		elif f == 17:
			game.player.handle_hand_release("right_hand")
		elif f >= 21 and f < 28:
			inp["left_held"] = true
		elif f == 29:
			game.player.quick_equip_preset(3)
			game.player.handle_hand_press("left_hand")
		game.step_simulation(1.0 / 20.0, inp)
		await _wait_frames(1)
		var fimg: Image = get_viewport().get_texture().get_image()
		fimg.save_png(out_dir.path_join("frames/frame_%03d.png" % f))
	print("[visual-qa] Captured 36 sequential motion frames.")

	get_tree().quit(0)
