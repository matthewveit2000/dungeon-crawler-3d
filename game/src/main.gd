class_name GameMain
extends Node3D
## Master Game Coordinator wiring Tier 1 Core, Tier 2 Pure Rules, 3D World,
## Low-Friction Toggleable Tutorial Mode (D-030), and Skyrim Dark-Fantasy UI.
## Boots immediately into a playable Floor 1 Nordic-ruin labyrinth (or resumes saved session).

var run_seed: int = 20261118
var floor_number: int = 1
var is_menu_paused: bool = false
var active_menu_name: String = ""
var auto_load_save_on_ready: bool = true
var save_path: String = SnapshotManager.DEFAULT_SAVE_PATH

var rng: SeededRng = null
var progression: ProgressionSystem = null
var floor_timer: FloorTimer = null
var snapshot_mgr: SnapshotManager = null
var vendor_sys: VendorSystem = null
var ai_director: DungeonAiDirector = null
var tutorial_sys: TutorialSystem = null

var dungeon_builder: DungeonBuilder = null
var player: PlayerController = null
var enemies_root: Node3D = null
var projectiles_root: Node3D = null
var corpses_root: Node3D = null
var current_layout: DungeonGenerator.FloorLayout = null

var hud: GameHud = null
var inventory_menu: InventoryMenu = null
var vendor_menu: VendorMenu = null
var pause_menu: PauseMenu = null
var map_menu: MapMenu = null
var death_screen: DeathScreen = null
var debug_overlay: DebugOverlay = null
## Explored tiles for the map's fog of war (saved with the session).
var map_seen: Dictionary = {}
var _last_player_tile: Vector2i = Vector2i(-999, -999)

var boss_actor: EnemyActor = null
## D-049: crawler knowledge of every enemy type met (saved with the session, never rolled back by a floor reset)
var bestiary: Bestiary = Bestiary.new()
## D-049 Hunter's Focus: enemies and their projectiles run at this speed while a mastered bow is fully drawn
var world_time_scale: float = 1.0
var _bestiary_scan_t: float = 0.0
var boss_defeated_this_floor: bool = false
var player_in_safe_room: bool = false
var quest_bounty_claimed: bool = false
var _trap_damage_cooldown: float = 0.0
var _spawn_anchor_pos: Vector3 = Vector3.ZERO
const ENEMY_ACTIVE_RADIUS := 70.0
var _initialized: bool = false

# --- Test Mode (D-047) -------------------------------------------------------------------------------
## Set by the title screen's "Test Mode" button before the game scene loads.
static var launch_test_mode: bool = false
const TEST_SAVE_PATH := "user://test_mode_save.json"
var test_mode: bool = false
var test_panel: TestModePanel = null
var test_ai_frozen: bool = false
var test_clock_paused: bool = false
var test_infinite_resources: bool = false
var test_vast_floor: bool = false  ## Test Mode on a real vast floor instead of the compact test floor


func _ready() -> void:
	if launch_test_mode:
		launch_test_mode = false
		test_mode = true
	if test_mode:
		# Test Mode never touches the real expedition save
		save_path = TEST_SAVE_PATH
		auto_load_save_on_ready = false
		test_clock_paused = true
	initialize_game(run_seed, auto_load_save_on_ready)


func initialize_game(p_seed: int = 20261118, try_load_save: bool = true) -> void:
	if _initialized:
		return
	_initialized = true
	DataLoader.ensure_loaded()
	run_seed = p_seed
	rng = SeededRng.new(run_seed)
	progression = ProgressionSystem.new(DataLoader.get_progression_pack())
	floor_timer = FloorTimer.new(DataLoader.get_world()["floor_timer"])
	snapshot_mgr = SnapshotManager.new()
	vendor_sys = VendorSystem.new(DataLoader.get_affixes_pack())
	ai_director = DungeonAiDirector.new(DataLoader.get_dungeon_ai_pack())
	tutorial_sys = TutorialSystem.new(DataLoader.get_tutorials_pack())

	dungeon_builder = DungeonBuilder.new()
	dungeon_builder.name = "DungeonBuilder"
	add_child(dungeon_builder)

	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)

	projectiles_root = Node3D.new()
	projectiles_root.name = "Projectiles"
	add_child(projectiles_root)

	corpses_root = Node3D.new()
	corpses_root.name = "Corpses"
	add_child(corpses_root)

	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.setup(DataLoader.get_player(), progression, rng, {
		"melee_swing": _on_player_melee_swing,
		"spawn_projectile": _on_spawn_projectile,
		"item_used": func(item: Dictionary, event: String) -> void: grant_item_xp(item, event, 1),
		"player_damaged": func(_dmg: float) -> void:
			if hud != null:
				hud.trigger_damage_flash(),
	})
	dungeon_builder.set_light_focus_target(player)

	hud = GameHud.new()
	add_child(hud)

	inventory_menu = InventoryMenu.new()
	add_child(inventory_menu)
	inventory_menu.setup(player, close_all_menus)

	vendor_menu = VendorMenu.new()
	add_child(vendor_menu)
	vendor_menu.setup(player, vendor_sys, close_all_menus)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup({
		"resume": close_all_menus,
		"toggle_camera": func() -> void:
			player.toggle_camera_mode()
			_complete_tutorial("movement_camera"),
		"toggle_tutorial": func() -> bool:
			tutorial_sys.set_enabled(not tutorial_sys.enabled)
			_sync_tutorial_hud()
			return tutorial_sys.enabled,
		"reset_tutorials": func() -> void:
			tutorial_sys.reset_tutorials()
			tutorial_sys.set_enabled(true)
			_trigger_tutorial("movement_camera")
			_sync_tutorial_hud(),
		"save": func() -> bool: return save_current_session(),
		"save_quit": _on_save_and_quit,
		"save_and_quit": _on_save_and_quit,
		"reset_floor": func() -> void:
			close_all_menus()
			reset_floor_to_snapshot("manual_reset"),
		"quit_to_title": _on_quit_to_title,
	})

	map_menu = MapMenu.new()
	add_child(map_menu)
	map_menu.setup(close_all_menus)

	if test_mode:
		hud.set_test_mode(true)
		test_panel = TestModePanel.new()
		add_child(test_panel)
		test_panel.setup(self, close_all_menus)

	death_screen = DeathScreen.new()
	add_child(death_screen)
	# The HUD steps aside while the death / collapse card is up
	death_screen.visibility_changed.connect(func() -> void:
		if hud != null:
			hud.visible = not death_screen.visible
	)

	if GameSettings != null and not GameSettings.changed.is_connected(_on_settings_changed):
		GameSettings.changed.connect(_on_settings_changed)

	debug_overlay = DebugOverlay.new()
	add_child(debug_overlay)
	debug_overlay.setup(run_console_command, close_all_menus)

	if EventBus != null:
		if not EventBus.player_died.is_connected(_on_player_died):
			EventBus.player_died.connect(_on_player_died)
		if not EventBus.level_up_occurred.is_connected(_on_level_up):
			EventBus.level_up_occurred.connect(_on_level_up)
		if not EventBus.interaction_prompt_changed.is_connected(_on_prompt_changed):
			EventBus.interaction_prompt_changed.connect(_on_prompt_changed)

	# Resume saved mid-floor session if one exists (D-017)
	var resumed := false
	if try_load_save and FileAccess.file_exists(save_path):
		resumed = load_saved_session()

	if not resumed:
		enter_floor(1, true)

	if AudioManager != null:
		AudioManager.start_ambience("dungeon_ambience")
	_capture_mouse(true)


func enter_floor(target_floor: int, capture_snapshot: bool = true) -> void:
	floor_number = target_floor
	boss_defeated_this_floor = false
	player_in_safe_room = false
	quest_bounty_claimed = false
	ai_director.reset_floor_flags()
	floor_timer.reset()
	# D-039: every attempt at a floor replays from the same random state (combat rolls, AI, banners).
	rng.reseed(_floor_seed("attempt"))
	map_seen.clear()
	_last_player_tile = Vector2i(-999, -999)
	if hud != null:
		hud.clear_transient_messages()  # stale broadcasts from the previous floor / attempt don't linger

	if capture_snapshot:
		snapshot_mgr.capture_floor_entry_snapshot(_build_snapshot_payload())

	_clear_dynamic_entities()
	var world_pack := DataLoader.get_world()
	var enemies_pack := DataLoader.get_enemies_pack()
	var floor_cfg := DataLoader.get_floor_config(floor_number)

	if test_mode and not test_vast_floor:
		current_layout = DungeonGenerator.generate_test_floor(world_pack, enemies_pack, floor_number, run_seed)
	else:
		current_layout = DungeonGenerator.generate(world_pack, enemies_pack, floor_number, run_seed)
	var build_rng := SeededRng.new(int(("%d:build:%d" % [run_seed, floor_number]).hash()))
	dungeon_builder.build_floor(current_layout, floor_cfg, _on_interactable_triggered, build_rng)

	# Refresh Safe Room Vendor stock deterministically for this floor
	var vendor_rng := SeededRng.new(int(("%d:vendor:%d" % [run_seed, floor_number]).hash()))
	vendor_sys.refresh_stock(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), floor_number, vendor_rng)

	# Place player at Entrance room center
	var ent_center: Vector2i = current_layout.rooms[current_layout.entrance_room_id]["center"]
	player.global_position = current_layout.tile_to_world(ent_center) + Vector3(0.0, 0.25, 0.0)
	_spawn_anchor_pos = player.global_position
	dungeon_builder.update_streaming(player.global_position, true)
	player.velocity = Vector3.ZERO
	player.recalculate_vitals(true)

	_spawn_floor_enemies(enemies_pack)

	if hud != null:
		hud.update_boss_bar(false)
		hud.set_zone_banner("", Color.WHITE)

	var fname := str(floor_cfg.get("name", "Floor %d" % floor_number))
	if EventBus != null:
		EventBus.floor_entered.emit(floor_number, fname, run_seed)
	_announce_ai("floor_enter", {"floor": floor_number}, "info")
	if floor_number == 1:
		_trigger_tutorial("movement_camera")
	_update_hud_navigation()


## D-039: Deterministic per-floor seed so the same floor plays out identically on every attempt.
func _floor_seed(label: String) -> int:
	return int(("%d:%s:%d" % [run_seed, label, floor_number]).hash())


## D-039: Each container / enemy rolls its loot from its own seed, so its contents never depend on
## the order the player opened things or how many fights happened first.
func _loot_rng_for(source_key: String) -> SeededRng:
	return SeededRng.new(int(("%d:loot:%d:%s" % [run_seed, floor_number, source_key]).hash()))


func reset_floor_to_snapshot(reason: String) -> void:
	# D-014 & D-018: Both floor collapse and combat death restore Floor-Entry Snapshot with a fresh 5-day floor!
	if snapshot_mgr.has_snapshot():
		var snap := snapshot_mgr.restore_floor_entry_snapshot()
		floor_number = int(snap.get("floor_number", floor_number))
		run_seed = int(snap.get("run_seed", run_seed))
		player.gold = int(snap.get("gold", 75))
		player.equipment = snap.get("equipment", {}).duplicate(true)
		player.inventory.clear()
		for item in snap.get("inventory", []):
			player.inventory.append(item.duplicate(true))
		player.normalize_equipment()
		progression.from_dict(snap.get("progression", {}))
		player.refresh_hand_visuals()

	if reason == "collapse":
		_announce_ai("floor_collapse", {"floor": floor_number}, "danger")
		if EventBus != null:
			EventBus.sfx_requested.emit("collapse_rumble")
	elif reason == "death":
		_announce_ai("player_death", {"floor": floor_number}, "danger")
		if EventBus != null:
			EventBus.sfx_requested.emit("collapse_rumble")

	enter_floor(floor_number, false)
	if death_screen != null and reason in ["death", "collapse"]:
		death_screen.show_reset(reason, floor_number)
	if EventBus != null:
		EventBus.floor_reset_completed.emit(floor_number, reason)


func save_current_session() -> bool:
	var session := {
		"floor_number": floor_number,
		"run_seed": run_seed,
		"player_pos": [player.global_position.x, player.global_position.y, player.global_position.z],
		"player_yaw": player.rotation.y,
		"player_pitch": player.pitch_rad,
		"health": player.health,
		"magicka": player.magicka,
		"stamina": player.stamina,
		"gold": player.gold,
		"equipment": player.equipment.duplicate(true),
		"inventory": player.inventory.duplicate(true),
		"progression": progression.to_dict(),
		"timer": floor_timer.to_dict(),
		"tutorials": tutorial_sys.to_dict() if tutorial_sys != null else {},
		"boss_defeated": boss_defeated_this_floor,
		"map_seen": _map_seen_to_array(),
		"bestiary": bestiary.to_dict(),
	}
	return snapshot_mgr.save_session_to_file(session, save_path)


func _map_seen_to_array() -> Array:
	var out: Array = []
	for t in map_seen.keys():
		out.append(t.y * 1000 + t.x)
	return out


func load_saved_session() -> bool:
	var session := snapshot_mgr.load_session_from_file(save_path)
	if session.is_empty():
		return false
	run_seed = int(session.get("run_seed", run_seed))
	floor_number = int(session.get("floor_number", 1))
	player.gold = int(session.get("gold", 75))
	player.equipment = session.get("equipment", {}).duplicate(true)
	player.inventory.clear()
	for item in session.get("inventory", []):
		player.inventory.append(item.duplicate(true))
	player.normalize_equipment()
	progression.from_dict(session.get("progression", {}))
	bestiary.from_dict(session.get("bestiary", {}))
	if tutorial_sys != null and session.has("tutorials"):
		tutorial_sys.from_dict(session["tutorials"])
	player.refresh_hand_visuals()

	enter_floor(floor_number, not snapshot_mgr.has_snapshot())

	var pos_arr: Array = session.get("player_pos", [])
	if pos_arr.size() == 3:
		player.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	player.rotation.y = float(session.get("player_yaw", 0.0))
	player.pitch_rad = float(session.get("player_pitch", 0.0))
	player.head_pivot.rotation.x = player.pitch_rad
	player.recalculate_vitals(false)
	player.health = clampf(float(session.get("health", player.max_health)), 1.0, player.max_health)
	player.magicka = clampf(float(session.get("magicka", player.max_magicka)), 0.0, player.max_magicka)
	player.stamina = clampf(float(session.get("stamina", player.max_stamina)), 0.0, player.max_stamina)
	floor_timer.from_dict(session.get("timer", {}))
	for code in session.get("map_seen", []):
		var ci := int(code)
		map_seen[Vector2i(ci % 1000, ci / 1000)] = true
	if bool(session.get("boss_defeated", false)):
		boss_defeated_this_floor = true
		dungeon_builder.unlock_boss_and_vault()
		if boss_actor != null and is_instance_valid(boss_actor):
			boss_actor.queue_free()
			boss_actor = null
	player.emit_stats()
	_sync_tutorial_hud()
	_update_hud_navigation()
	return true


func set_menu_pause(paused: bool, menu_name: String = "") -> void:
	is_menu_paused = paused
	active_menu_name = menu_name if paused else ""
	_capture_mouse(not paused)
	if EventBus != null:
		EventBus.menu_pause_changed.emit(is_menu_paused, active_menu_name)


func open_exclusive_menu(menu_name: String) -> void:
	inventory_menu.visible = false
	vendor_menu.visible = false
	pause_menu.visible = false
	map_menu.visible = false
	debug_overlay.visible = false
	if test_panel != null:
		test_panel.visible = false
	set_menu_pause(true, menu_name)
	match menu_name:
		"inventory":
			inventory_menu.open_menu()
			_complete_tutorial("inventory_pause")
		"vendor":
			vendor_menu.open_menu()
			_complete_tutorial("safe_room")
		"pause":
			var fcfg := DataLoader.get_floor_config(floor_number)
			var status := "Floor %d  ·  %s\n%s\nLevel %d  ·  %d gold  ·  %d items carried" % [floor_number, str(fcfg.get("name", "")),
				floor_timer.get_formatted_clock().replace("|", "·"), progression.level, player.gold, player.inventory.size()]
			pause_menu.open_menu(status, tutorial_sys.enabled if tutorial_sys != null else false)
		"map":
			var fc := DataLoader.get_floor_config(floor_number)
			var found := 0
			for lm in current_layout.landmarks:
				if bool(lm.get("discovered", false)):
					found += 1
			map_menu.open_map(current_layout, map_seen, player.global_position, -player.rotation.y,
				"Floor %d  ·  %s" % [floor_number, str(fc.get("name", ""))],
				"%s\nLandmarks found: %d / %d" % [floor_timer.get_formatted_clock().replace("|", "·"), found, current_layout.landmarks.size()])
		"console":
			debug_overlay.open_console()
		"test":
			if test_panel != null:
				test_panel.open_menu()


func close_all_menus() -> void:
	inventory_menu.visible = false
	vendor_menu.visible = false
	pause_menu.visible = false
	map_menu.visible = false
	debug_overlay.visible = false
	if test_panel != null:
		test_panel.visible = false
	set_menu_pause(false, "")


func _open_exclusive_menu(menu_name: String) -> void:
	open_exclusive_menu(menu_name)


func _close_all_menus() -> void:
	close_all_menus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_menu_paused:
		player.apply_mouse_look((event as InputEventMouseMotion).relative)
		return

	if event.is_action_pressed("dismiss_hint") and not is_menu_paused and tutorial_sys != null:
		tutorial_sys.dismiss_current()
		_sync_tutorial_hud()
		return

	if test_mode and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_F1:
		if active_menu_name == "test":
			close_all_menus()
		else:
			open_exclusive_menu("test")
		return

	if event.is_action_pressed("toggle_console"):
		if active_menu_name == "console":
			close_all_menus()
		else:
			open_exclusive_menu("console")
		return

	if event.is_action_pressed("toggle_pause"):
		if active_menu_name == "pause" and pause_menu.back():
			return
		if is_menu_paused:
			close_all_menus()
		else:
			open_exclusive_menu("pause")
		return

	if event.is_action_pressed("toggle_map"):
		if active_menu_name == "map":
			close_all_menus()
		elif not is_menu_paused:
			open_exclusive_menu("map")
		return

	if event.is_action_pressed("toggle_inventory"):
		if active_menu_name == "inventory":
			close_all_menus()
		else:
			open_exclusive_menu("inventory")
		return

	if is_menu_paused:
		return

	if event.is_action_pressed("toggle_camera"):
		player.toggle_camera_mode()
		_complete_tutorial("movement_camera")
	elif event.is_action_pressed("interact"):
		player.trigger_interact()
	elif event.is_action_pressed("right_hand_action"):
		player.handle_hand_press("right_hand")
		_complete_tutorial("combat_hands")
	elif event.is_action_released("right_hand_action"):
		player.handle_hand_release("right_hand")
	elif event.is_action_pressed("left_hand_action"):
		player.handle_hand_press("left_hand")
		_complete_tutorial("combat_hands")
	elif event.is_action_pressed("quick_loadout_1"):
		player.quick_equip_preset(1)
		_complete_tutorial("combat_hands")
	elif event.is_action_pressed("quick_loadout_2"):
		player.quick_equip_preset(2)
		_complete_tutorial("combat_hands")
	elif event.is_action_pressed("quick_loadout_3"):
		player.quick_equip_preset(3)
		_complete_tutorial("combat_hands")
	elif event.is_action_pressed("quick_loadout_4"):
		player.quick_equip_preset(4)
		_complete_tutorial("combat_hands")
		_trigger_tutorial("archery_aim")
	elif event.is_action_pressed("quick_potion"):
		player.quick_drink_health_potion()


func _physics_process(delta: float) -> void:
	step_simulation(delta)


func step_simulation(delta: float, input_override: Dictionary = {}) -> void:
	if current_layout == null or player == null:
		return

	# 1. Tick 5-Day Collapse Clock (freezes completely when paused — D-016)
	var tick_res := floor_timer.tick(delta, is_menu_paused or test_clock_paused)
	if float(tick_res["warning_days_left"]) > 0.0:
		_announce_ai("time_warning", {"days_left": str(tick_res["warning_days_left"])}, "warning")
		_trigger_tutorial("floor_clock")
	if bool(tick_res["collapsed_now"]):
		if EventBus != null:
			EventBus.floor_collapsed.emit(floor_number)
		reset_floor_to_snapshot("collapse")
		return

	if is_menu_paused:
		return

	if test_infinite_resources:
		player.stamina = player.max_stamina
		player.magicka = player.max_magicka
	# 2. Step Player & Enemy AI
	player.step_simulation(delta, is_menu_paused, input_override)
	world_time_scale = player.bullet_time_scale()
	GameProjectile.world_time_scale = world_time_scale
	var enemy_delta := delta * world_time_scale
	_bestiary_scan_t -= delta
	var scan := _bestiary_scan_t <= 0.0
	if scan:
		_bestiary_scan_t = 0.4
	var enemy_nearby := false
	var ppos := player.global_position
	for child in enemies_root.get_children():
		if child is EnemyActor:
			var ea := child as EnemyActor
			# Vast floors (D-044): enemies far from the player are frozen and hidden (no AI, no animation)
			var near := ea.global_position.distance_squared_to(ppos) <= ENEMY_ACTIVE_RADIUS * ENEMY_ACTIVE_RADIUS
			if near != ea.visible:
				ea.visible = near
				ea.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
			if not near:
				continue
			ea.step_ai(enemy_delta, is_menu_paused or test_ai_frozen)
			if scan and ea.state in [EnemyActor.AiState.CHASE, EnemyActor.AiState.ATTACK]:
				_bestiary_sighting(ea)
			if not ea.is_boss and ea.global_position.distance_to(player.global_position) <= 10.5:
				enemy_nearby = true

	# Contextual low-friction tutorial triggers
	if player.global_position.distance_to(_spawn_anchor_pos) > 2.4:
		_complete_tutorial("movement_camera")
	if enemy_nearby:
		_trigger_tutorial("combat_hands")
	if tutorial_sys != null and tutorial_sys.tick(delta, is_menu_paused):
		_sync_tutorial_hud()

	_update_map_seen()

	# 3. Check Safe Room, Boss Arena Threshold, and Spike Traps
	_check_zone_triggers(delta)

	# 4. Update Skyrim Compass Bar, Floor Clock & Boss HP Bar
	_update_hud_navigation()


func run_console_command(command_line: String) -> String:
	return DebugConsole.execute(command_line, {
		"teleport": _cmd_teleport,
		"advance_days": _cmd_advance_days,
		"collapse": func(_a: Array[String]) -> String:
			reset_floor_to_snapshot("collapse")
			return "Triggered Floor Collapse -> reset to Floor-Entry Snapshot.",
		"kill_player": func(_a: Array[String]) -> String:
			player.god_mode = false
			player.take_damage(99999.0)
			return "Killed player -> reset to Floor-Entry Snapshot.",
		"kill_boss": func(_a: Array[String]) -> String:
			if boss_actor == null or not is_instance_valid(boss_actor):
				return "Floor Boss is already defeated."
			var bname := boss_actor.display_name
			boss_actor.take_damage(99999.0)
			return "Defeated %s -> Boss Gate & Treasure Vault unlocked!" % bname,
		"spawn_loot": _cmd_spawn_loot,
		"add_gold": func(args: Array[String]) -> String:
			var amt := int(args[0]) if not args.is_empty() else 100
			player.gold += amt
			player.emit_stats()
			return "Added %d Syndicate Gold (total: %d)." % [amt, player.gold],
		"add_xp": func(args: Array[String]) -> String:
			var amt := float(args[0]) if not args.is_empty() else 120.0
			var lvls := progression.add_xp(amt)
			for l in lvls:
				if EventBus != null: EventBus.level_up_occurred.emit(l)
			return "Granted %.0f XP (Lv %d)." % [amt, progression.level],
		"god": func(_a: Array[String]) -> String:
			player.god_mode = not player.god_mode
			return "God Mode: %s" % ("ON" if player.god_mode else "OFF"),
		"camera": func(_a: Array[String]) -> String:
			return "Camera Mode: %s" % player.toggle_camera_mode(),
		"seed": _cmd_seed,
		"status": func(_a: Array[String]) -> String:
			return "Floor %d | Seed %d | %s | HP %.0f/%.0f | Gold %d | Pos %s" % [
				floor_number, run_seed, floor_timer.get_formatted_clock(),
				player.health, player.max_health, player.gold, str(player.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
			],
	})


func _check_zone_triggers(delta: float) -> void:
	# Safe Room entry/exit
	var in_safe := current_layout.is_world_in_safe_room(player.global_position)
	if in_safe and not player_in_safe_room:
		player_in_safe_room = true
		if EventBus != null:
			EventBus.safe_room_entered.emit()
		_announce_ai("safe_room_discovered", {}, "info", true)
		_trigger_tutorial("safe_room")
	elif not in_safe and player_in_safe_room:
		player_in_safe_room = false
		if EventBus != null:
			EventBus.safe_room_exited.emit()

	# Boss gate watchdog: once the boss is dead or gone by any route, the arena and vault must be open
	if not boss_defeated_this_floor and not _boss_alive():
		_on_boss_defeated()
	elif boss_defeated_this_floor and (dungeon_builder.boss_arena_sealed or not dungeon_builder.vault_unlocked):
		dungeon_builder.unlock_boss_and_vault()
	elif _boss_alive() and boss_actor.global_position.y < -3.0:
		# A boss that slipped out of the world would keep the arena sealed forever: put it back on its dais
		boss_actor.global_position = current_layout.tile_to_world(current_layout.rooms[current_layout.boss_room_id]["center"]) + Vector3(0.0, 0.45, 0.0)
		boss_actor.velocity = Vector3.ZERO

	# Boss Arena threshold lockdown (D-022) — only ever with a living boss inside
	if not boss_defeated_this_floor and not dungeon_builder.boss_arena_sealed and _boss_alive():
		if current_layout.is_world_in_boss_arena(player.global_position):
			dungeon_builder.seal_boss_arena()
			if boss_actor != null and is_instance_valid(boss_actor):
				boss_actor.wake_boss()
				if EventBus != null:
					EventBus.boss_arena_sealed.emit(boss_actor.display_name)
					EventBus.sfx_requested.emit("door_seal")
				_announce_ai("boss_arena_sealed", {}, "danger", true)
				_trigger_tutorial("boss_arena")

	# Spike Traps
	_trap_damage_cooldown = maxf(0.0, _trap_damage_cooldown - delta)
	if _trap_damage_cooldown <= 0.0 and dungeon_builder.is_player_on_active_trap(player.global_position):
		_trap_damage_cooldown = 1.2
		player.take_damage(14.0)


func _on_player_melee_swing(swing: Dictionary) -> void:
	var weapon: Dictionary = swing["weapon"]
	var abil: Dictionary = swing.get("abilities", {})
	var is_power := bool(swing["is_power_attack"])
	var reach := float(weapon.get("range_meters", 2.6)) + float(swing.get("dash_distance", 0.0))
	var arc := float(DataLoader.get_player()["combat"]["melee_arc_degrees"])
	if abil.has("cleave"):
		arc = maxf(arc, float(abil["cleave"].get("arc", 150.0)))
	if is_power and abil.has("whirlwind"):
		arc = 360.0
	var half_arc_cos := cos(deg_to_rad(arc * 0.5)) if arc < 359.0 else -2.0
	var fwd := player.get_forward_vector()
	fwd.y = 0.0
	fwd = fwd.normalized()

	var hit_any := false
	for child in enemies_root.get_children():
		if not (child is EnemyActor):
			continue
		var enemy := child as EnemyActor
		var delta := enemy.global_position - player.global_position
		delta.y = 0.0
		var dist := delta.length()
		# Reach is measured to the target's body edge, so big enemies (the boss) can't out-range the player
		if dist > reach + maxf(0.6, enemy.body_radius + 0.1):
			continue
		if dist > 0.2 and fwd.dot(delta.normalized()) < half_arc_cos:
			continue
		_apply_player_hit_to_enemy(enemy, {
			"base_damage": MasterySystem.stat(weapon, "damage", 16.0),
			"bonus_damage": float(swing["bonus_damage"]),
			"damage_multiplier": float(swing["damage_multiplier"]),
			"is_power_attack": is_power,
			"crit_chance": float(swing["crit_chance"]),
			"crit_multiplier": float(swing["crit_multiplier"]),
			"sponsored_effects": swing["sponsored_effects"],
			"abilities": abil,
			"item": swing.get("item", {}),
			"melee": true,
			"passives": swing.get("passives", {}),
			"from_dir": delta.normalized(),
		}, str(swing["skill_name"]))
		if is_power and abil.has("knockback") and is_instance_valid(enemy):
			enemy.apply_knockback(delta, float(abil["knockback"].get("force", 6.0)))
		hit_any = true

	# Earthbreaker: power attacks shatter the ground around you
	if is_power and abil.has("ground_slam"):
		var gs: Dictionary = abil["ground_slam"]
		var r := float(gs.get("radius", 3.5))
		var burst := VfxFactory.make_impact_burst(Color(0.7, 0.6, 0.45), 46, r)
		projectiles_root.add_child(burst)
		burst.global_position = player.global_position + Vector3(0, 0.2, 0)
		for child in enemies_root.get_children():
			var e := child as EnemyActor
			if e != null and is_instance_valid(e) and e.global_position.distance_to(player.global_position) <= r:
				_apply_player_hit_to_enemy(e, {
					"base_damage": MasterySystem.stat(weapon, "damage", 16.0) * float(gs.get("damage", 0.6)),
					"damage_multiplier": float(swing["damage_multiplier"]),
					"crit_chance": 0.0,
					"item": swing.get("item", {}),
				}, str(swing["skill_name"]))
				if is_instance_valid(e):
					e.apply_knockback(e.global_position - player.global_position, 4.0)
				hit_any = true
		player.add_shake(0.6)

	if hit_any:
		if abil.has("frenzy"):
			player.register_frenzy_hit(abil["frenzy"])
		elif swing.get("passives", {}).has("frenzy"):
			player.register_frenzy_hit(swing["passives"]["frenzy"])
		player.on_melee_hit(bool(swing["is_power_attack"]))
		if EventBus != null:
			EventBus.sfx_requested.emit("sword_hit")


func _on_spawn_projectile(params: Dictionary) -> void:
	if bool(params.get("from_player", false)) and str(params.get("kind", "")) == "arrow":
		_complete_tutorial("archery_aim")
	var proj := GameProjectile.new()
	projectiles_root.add_child(proj)
	proj.global_position = params["origin"]
	proj.setup(params, _on_projectile_hit)
	if params.has("shooter"):
		proj.set_meta("shooter", params["shooter"])
	if bool(params.get("full_draw", false)):
		proj.set_meta("full_draw", true)


func _on_projectile_hit(proj: GameProjectile, body: Node3D, hit_pos: Vector3) -> void:
	if proj.from_player:
		var abil: Dictionary = proj.abilities
		var item := player.find_item_by_uid(proj.item_uid)
		var hit_params := {
			"base_damage": proj.damage,
			"crit_chance": proj.crit_chance,
			"crit_multiplier": proj.crit_multiplier,
			"sponsored_effects": proj.sponsored_effects,
			"abilities": abil,
			"item": item,
		}
		if body is EnemyActor:
			var target := body as EnemyActor
			_apply_player_hit_to_enemy(target, hit_params, proj.skill_name)
			if abil.has("power_shot") and proj.get_meta("full_draw", false) and is_instance_valid(target):
				target.apply_knockback(proj.velocity, float(abil["power_shot"].get("force", 4.0)))
			# Arc Chain: leap to the nearest enemies not yet struck
			if abil.has("chain") or proj.chain_radius > 0.0:
				var ch: Dictionary = abil.get("chain", {"jumps": 1, "radius": proj.chain_radius, "falloff": 0.65})
				chain_lightning(target, hit_pos, proj.damage, ch, hit_params, proj.skill_name, Color.html("#58c8ff"))
		var splash_r := proj.splash_radius
		var splash_k := 0.55
		if abil.has("explode"):
			splash_r = maxf(splash_r, float(abil["explode"].get("radius", 3.5)))
			splash_k = float(abil["explode"].get("damage", 0.6))
		if splash_r > 0.0:
			var boom := VfxFactory.make_impact_burst(proj._color, 40, splash_r * 1.2)
			projectiles_root.add_child(boom)
			boom.global_position = hit_pos
			var sp := hit_params.duplicate()
			sp["base_damage"] = proj.damage * splash_k
			for other in enemies_root.get_children():
				if other is EnemyActor and other != body and is_instance_valid(other):
					if (other as EnemyActor).global_position.distance_to(hit_pos) <= splash_r + 0.5:
						_apply_player_hit_to_enemy(other as EnemyActor, sp, proj.skill_name)
	else:
		var shooter: Variant = proj.get_meta("shooter", null)
		var sh: EnemyActor = shooter as EnemyActor if is_instance_valid(shooter) else null
		if body == player:
			_enemy_hit_player(sh, proj.damage, false)
		# Goblin bombs burst wherever they land
		elif proj.splash_radius > 0.0 and player.global_position.distance_to(hit_pos) <= proj.splash_radius:
			_enemy_hit_player(sh, proj.damage, false)


func _apply_player_hit_to_enemy(enemy: EnemyActor, params: Dictionary, skill_name: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.state == EnemyActor.AiState.DEAD:
		return
	var abil: Dictionary = params.get("abilities", {})
	var item: Dictionary = params.get("item", {})
	var attack_params := params.duplicate(false)
	attack_params.erase("abilities")
	attack_params.erase("item")
	attack_params.erase("passives")
	attack_params["target_armor"] = enemy.effective_armor()
	# Executioner
	if abil.has("execute") and enemy.current_health / maxf(1.0, enemy.max_health) <= float(abil["execute"].get("threshold", 0.3)):
		attack_params["damage_multiplier"] = float(attack_params.get("damage_multiplier", 1.0)) * (1.0 + float(abil["execute"].get("bonus", 0.5)))
	var res := CombatMath.resolve_attack(attack_params, DataLoader.get_player(), rng)
	var dmg := float(res["final_damage"])
	# Draugr Shieldwarden: frontal hits glance off the shield unless it is a power attack (D-049 trait)
	if enemy.traits.has("shield_front") and not bool(params.get("is_power_attack", false)):
		var to_player := player.global_position - enemy.global_position
		var facing := enemy.global_transform.basis.z
		if Vector2(facing.x, facing.z).normalized().dot(Vector2(to_player.x, to_player.z).normalized()) > 0.3:
			dmg *= 1.0 - float(enemy.traits["shield_front"].get("reduction", 0.7))
			if EventBus != null:
				EventBus.sfx_requested.emit("shield_block")
	var hit_pos := enemy.global_position + Vector3(0.0, 1.2 if not enemy.is_boss else 2.0, 0.0)
	enemy.set_meta("last_hit_uid", str(item.get("instance_id", "")))
	_bestiary_sighting(enemy)
	var enemy_level := enemy.level
	enemy.take_damage(dmg)
	# On-hit mastery effects (only while the target lives)
	if is_instance_valid(enemy) and enemy.state != EnemyActor.AiState.DEAD:
		for k in ["bleed", "burn", "poison", "chill", "sunder"]:
			if abil.has(k):
				enemy.apply_status(k, abil[k])
		if abil.has("fire_arrows"):
			enemy.apply_status("burn", abil["fire_arrows"])
		for k in ["freeze", "stun"]:
			if abil.has(k) and rng.next_float("combat") < float(abil[k].get("chance", 0.15)):
				enemy.apply_status(k, abil[k])
		var pas: Dictionary = params.get("passives", {})
		if bool(params.get("melee", false)) and pas.has("ember_touch"):
			enemy.apply_status("burn", pas["ember_touch"])
	var heal_frac := float(abil.get("lifesteal", {}).get("fraction", 0.0)) + float(abil.get("siphon", {}).get("fraction", 0.0))
	if bool(params.get("melee", false)):
		heal_frac += float(params.get("passives", {}).get("blood_pact", {}).get("fraction", 0.0))
	if heal_frac > 0.0:
		player.health = minf(player.max_health, player.health + dmg * heal_frac)
	if not item.is_empty():
		grant_item_xp(item, "hit", enemy_level)
	if hud != null:
		hud.trigger_hit_marker()
	_spawn_hit_feedback(hit_pos, dmg, bool(res.get("is_crit", false)))

	# Skyrim use-to-improve proficiency gain on landing a hit!
	var s_res := progression.record_skill_use(skill_name)
	if bool(s_res.get("skill_leveled_up", false)) and EventBus != null:
		EventBus.skill_improved.emit(skill_name, int(s_res["new_skill_level"]))
	for lvl in s_res.get("char_levels_gained", []):
		if EventBus != null:
			EventBus.level_up_occurred.emit(int(lvl))

	# Sponsored Explosive Crits shockwave!
	if bool(res["trigger_explosive_crits"]):
		var eff := DataLoader.get_sponsored_effect_def("explosive_crits")
		var aoe_r := float(eff.get("aoe_radius", 3.5))
		var aoe_d := float(eff.get("bonus_aoe_damage", 14.0))
		for other in enemies_root.get_children():
			if other is EnemyActor and is_instance_valid(other):
				if (other as EnemyActor).global_position.distance_to(enemy.global_position) <= aoe_r:
					(other as EnemyActor).take_damage(aoe_d)


func _spawn_hit_feedback(pos: Vector3, dmg: float, crit: bool) -> void:
	if not is_inside_tree():
		return
	var burst := VfxFactory.make_impact_burst(Color(1.0, 0.75, 0.4) if not crit else Color(1.0, 0.9, 0.3), 18 if not crit else 34, 3.6)
	projectiles_root.add_child(burst)
	burst.global_position = pos
	if GameSettings != null and not bool(GameSettings.get_value("gameplay", "show_damage_numbers")):
		return
	var lbl := Label3D.new()
	lbl.text = ("%d!" if crit else "%d") % int(round(dmg))
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 64 if crit else 44
	lbl.pixel_size = 0.004
	lbl.outline_size = 12
	lbl.modulate = Color(1.0, 0.86, 0.3) if crit else Color(1.0, 0.95, 0.88)
	lbl.outline_modulate = Color(0.1, 0.02, 0.0, 0.9)
	if UiTheme.font_heading() != null:
		lbl.font = UiTheme.font_heading()
	projectiles_root.add_child(lbl)
	var jitter := Vector3(rng.next_float_range("ai", -0.3, 0.3), 0.0, rng.next_float_range("ai", -0.3, 0.3))
	lbl.global_position = pos + jitter
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 0.9, 0), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(lbl.queue_free)


func _on_enemy_died(enemy: EnemyActor) -> void:
	# The boss's gates are opened FIRST, so nothing later in this handler (loot, corpse, VFX) can leave the
	# player sealed in the arena or locked out of the vault
	if enemy.is_boss:
		_on_boss_defeated()
	var eq_totals := LootGenerator.aggregate_equipment_stats(player.equipment)
	var sponsored: Array = eq_totals["sponsored_effects"]

	if sponsored.has("vampiric_viewers"):
		player.health = minf(player.max_health, player.health + float(DataLoader.get_sponsored_effect_def("vampiric_viewers").get("heal_on_kill", 12.0)))
	var bonus_gold := int(DataLoader.get_sponsored_effect_def("tax_rebate_gold").get("bonus_gold_on_kill", 15)) if sponsored.has("tax_rebate_gold") else 0

	var loot_rng := _loot_rng_for(str(enemy.get_meta("spawn_key", enemy.enemy_id)))
	var gold_roll := loot_rng.next_int_range("loot", enemy.gold_min, enemy.gold_max)
	gold_roll = int(round(float(gold_roll) * (1.0 + float(eq_totals["gold_find_bonus"])))) + bonus_gold

	var scholar := float(eq_totals.get("passives", {}).get("scholar", {}).get("xp", 0.0))
	var lvls := progression.add_xp(float(enemy.xp_reward) * (1.0 + scholar))
	# D-049: Bestiary kill + mastery XP for the item that landed the killing blow and every worn piece
	var kills := bestiary.record_kill(enemy.enemy_id, enemy.level, floor_number)
	if kills == Bestiary.STUDY_KILLS and EventBus != null:
		EventBus.dungeon_ai_announcement.emit("BESTIARY: %s STUDIED" % enemy.display_name.to_upper(),
			"%d slain. Its weakness is now in your Bestiary." % kills, "info")
	elif kills == 1 and EventBus != null:
		EventBus.dungeon_ai_announcement.emit("BESTIARY: FIRST %s SLAIN" % enemy.display_name.to_upper(),
			"Its stats and abilities are now recorded in your Bestiary.", "info")
	var killer := player.find_item_by_uid(str(enemy.get_meta("last_hit_uid", "")))
	if not killer.is_empty():
		grant_item_xp(killer, "kill", enemy.level)
	for slot in player.equipment.keys():
		if not str(slot).ends_with("_hand"):
			grant_item_xp(player.equipment[slot], "worn_kill", enemy.level)
	for l in lvls:
		if EventBus != null:
			EventBus.level_up_occurred.emit(l)

	# Spawn interactive Skyrim lootable corpse
	var corpse := InteractableObject.new()
	var forced_r := enemy.guaranteed_rarity
	var has_item := not forced_r.is_empty() or loot_rng.next_float("loot") <= enemy.loot_drop_chance
	var loot_item := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), floor_number, loot_rng,
		LootGenerator.world_rarity(DataLoader.get_affixes_pack(), forced_r)) if has_item else {}
	corpse.setup("corpse_%s" % enemy.enemy_id, "corpse", "Search %s" % enemy.display_name, {
		"gold": gold_roll,
		"item": loot_item,
	}, _on_interactable_triggered, Vector3(1.2, 0.8, 1.2))
	corpse.position = enemy.global_position
	corpse.rotation.y = enemy.rotation.y
	var body := enemy.detach_visual()
	if body != null:
		corpse.add_child(body)
		body.transform = Transform3D.IDENTITY
		corpse.visual_root = body
	var ccol := corpse.get_child(0) as CollisionShape3D
	if ccol != null and not enemy.is_boss:
		ccol.position = Vector3(0.0, 0.4, -0.7)
	corpses_root.add_child(corpse)
	var dust := VfxFactory.make_impact_burst(Color(0.6, 0.55, 0.45), 18, 2.0)
	projectiles_root.add_child(dust)
	dust.global_position = enemy.global_position + Vector3(0, 0.3, 0)

	_announce_ai("first_kill", {}, "info", true)

	if enemy.is_boss:
		_complete_tutorial("boss_arena")
		if EventBus != null:
			EventBus.boss_defeated.emit(enemy.display_name)
			EventBus.sfx_requested.emit("door_seal")
		_announce_ai("boss_defeated", {}, "warning", true)

	if EventBus != null:
		EventBus.enemy_killed.emit(enemy.enemy_id, enemy.xp_reward, gold_roll, enemy.is_boss)
	player.emit_stats()


func _on_interactable_triggered(inter: InteractableObject, _actor: Node3D) -> bool:
	match inter.kind:
		"chest":
			var tier := str(inter.payload.get("tier", "standard"))
			var forced := "legendary" if tier == "vault_legendary" else ("rare" if tier == "rare" else "")
			var chest_rng := _loot_rng_for(inter.interact_id)
			var rolled := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), floor_number, chest_rng,
				LootGenerator.world_rarity(DataLoader.get_affixes_pack(), forced), true)
			var gold_gain := chest_rng.next_int_range("loot", 25, 65) * floor_number
			_grant_loot(rolled, gold_gain)
			_complete_tutorial("looting")
			_trigger_tutorial("inventory_pause")
			if EventBus != null: EventBus.sfx_requested.emit("chest_open")
			return true
		"crate", "urn":
			var cont_rng := _loot_rng_for(inter.interact_id)
			var gold_gain := cont_rng.next_int_range("loot", 6, 20)
			var potion: Dictionary = {}
			if cont_rng.next_float("loot") < 0.35:
				potion = LootGenerator.make_base_item_instance(DataLoader.get_item_def("health_potion"), "pot_%d" % cont_rng.next_int_range("loot", 1000, 99999))
			_grant_loot(potion, gold_gain)
			_complete_tutorial("looting")
			if EventBus != null: EventBus.sfx_requested.emit("chest_open")
			return true
		"corpse":
			_grant_loot(inter.payload.get("item", {}), int(inter.payload.get("gold", 0)))
			_complete_tutorial("looting")
			_trigger_tutorial("inventory_pause")
			if EventBus != null: EventBus.sfx_requested.emit("chest_open")
			return true
		"lever":
			dungeon_builder.disarm_traps()
			_complete_tutorial("looting")
			if EventBus != null:
				EventBus.sfx_requested.emit("door_seal")
				EventBus.dungeon_ai_announcement.emit("TRAPS DISARMED", "Floor spike grates retracted safely.", "info")
			return true
		"vendor":
			open_exclusive_menu("vendor")
			return true
		"quest_board":
			_complete_tutorial("safe_room")
			if not quest_bounty_claimed:
				quest_bounty_claimed = true
				player.gold += 35
				player.emit_stats()
				if EventBus != null:
					EventBus.dungeon_ai_announcement.emit(
						"SYNDICATE BOUNTY ACCEPTED (+35g ADVANCE)",
						"Locate the hidden Stairwell before Day 5 ends — or risk the sealed Boss Arena for Mythic Vault loot.",
						"info"
					)
			return true
		"stairs":
			# D-008: Descend directly with zero preview of the next floor!
			_complete_tutorial("stairs_descent")
			call_deferred("enter_floor", floor_number + 1, true)
			return true
	return false


func _grant_loot(item: Dictionary, gold_gain: int) -> void:
	if gold_gain > 0:
		player.gold += gold_gain
	if not item.is_empty():
		player.inventory.append(item)
		if EventBus != null:
			EventBus.item_acquired.emit(item)
		if str(item.get("rarity", "")) == "legendary":
			_announce_ai("sponsored_loot", {"item_name": str(item.get("name", "Mythic Gear"))}, "warning")
	player.emit_stats()


func _spawn_floor_enemies(enemies_pack: Dictionary) -> void:
	boss_actor = null
	var scaling: Dictionary = enemies_pack.get("floor_scaling", {})
	for spawn_idx in current_layout.enemy_spawns.size():
		var sp: Dictionary = current_layout.enemy_spawns[spawn_idx]
		var edef := DataLoader.get_enemy_def(str(sp["enemy_id"]))
		if edef.is_empty():
			continue
		var y_off := 0.45 if bool(edef.get("is_boss", false)) else 0.1
		var enemy := spawn_enemy(str(sp["enemy_id"]), current_layout.tile_to_world(sp["tile"]) + Vector3(0.0, y_off, 0.0),
			int(sp["room_id"]), "enemy_%d_%s" % [spawn_idx, str(sp["enemy_id"])], scaling)
		if enemy != null and enemy.is_boss:
			boss_actor = enemy


## Creates one enemy (floor spawns and Test Mode). Returns null for an unknown enemy id.
func spawn_enemy(enemy_id: String, wpos: Vector3, room_id: int = -1, spawn_key: String = "", scaling: Dictionary = {}, level_override: int = 0) -> EnemyActor:
	var edef := DataLoader.get_enemy_def(enemy_id)
	if edef.is_empty():
		return null
	if scaling.is_empty():
		scaling = DataLoader.get_enemies_pack().get("floor_scaling", {})
	var enemy := EnemyActor.new()
	var key := spawn_key if not spawn_key.is_empty() else "spawned_%s_%d" % [enemy_id, enemies_root.get_child_count()]
	enemy.set_meta("spawn_key", key)
	enemies_root.add_child(enemy)
	# D-049: deterministic level per spawn (same seed -> same levels every attempt, D-039)
	var lvl := EnemyLevels.roll_level(edef, floor_number, DataLoader.get_enemies_pack(), _loot_rng_for("level_" + key))
	if level_override > 0:
		lvl = level_override
	enemy.setup(edef, scaling, floor_number, room_id, wpos, current_layout, player, rng, {
		"attack_player": func(e: EnemyActor, dmg: float, _dir: Vector3) -> void: _enemy_hit_player(e, dmg, true),
		"shoot_projectile": func(e: EnemyActor, origin: Vector3, vel: Vector3, dmg: float) -> void:
			var pk := e.projectile_kind
			_on_spawn_projectile({
				"kind": "arrow" if pk == "arrow" else "spell",
				"color": e.projectile_color,
				"origin": origin,
				"velocity": vel,
				"gravity": EnemyActor.BOMB_GRAVITY if pk == "bomb" else (0.0 if pk == "hex" else 2.0),
				"damage": dmg,
				"from_player": false,
				"splash_radius": float(e.traits.get("bomb_throw", {}).get("radius", 0.0)),
				"shooter": e,
			}),
		"died": _on_enemy_died,
	}, lvl)
	return enemy


## An enemy's blow or shot reaching the crawler: blocks, shield & armor mastery effects and enemy traits (D-049).
func _enemy_hit_player(e: EnemyActor, dmg: float, melee: bool) -> void:
	var res := player.take_damage(dmg)
	if bool(res.get("dodged", false)):
		return
	var alive := e != null and is_instance_valid(e) and e.state != EnemyActor.AiState.DEAD
	var guard := player.blocking_item() if bool(res.get("was_blocked", false)) else {}
	if not guard.is_empty():
		grant_item_xp(guard, "block", e.level if alive else 1)
		var ga := MasterySystem.abilities(guard)
		if alive and melee and ga.has("bash"):
			e.apply_status("stun", {"duration": float(ga["bash"].get("duration", 0.8))})
		if alive and melee and ga.has("reflect"):
			e.take_damage(dmg * float(ga["reflect"].get("fraction", 0.3)))
	else:
		for slot in player.equipment.keys():
			if not str(slot).ends_with("_hand"):
				grant_item_xp(player.equipment[slot], "hit_taken", e.level if alive else 1)
	alive = e != null and is_instance_valid(e) and e.state != EnemyActor.AiState.DEAD
	if not alive:
		return
	var pas: Dictionary = LootGenerator.aggregate_equipment_stats(player.equipment).get("passives", {})
	if melee and pas.has("thorns"):
		e.take_damage(float(pas["thorns"].get("damage", 5.0)))
	if not is_instance_valid(e) or e.state == EnemyActor.AiState.DEAD:
		return
	var taken := float(res.get("final_damage", 0.0))
	if e.traits.has("frost_strike") and taken > 0.0:
		player.apply_slow(float(e.traits["frost_strike"].get("slow", 0.4)), float(e.traits["frost_strike"].get("duration", 2.5)))
	if e.traits.has("hex_bolt") and taken > 0.0:
		player.apply_slow(float(e.traits["hex_bolt"].get("slow", 0.3)), float(e.traits["hex_bolt"].get("duration", 2.5)))
	if e.traits.has("lifedrain") and taken > 0.0:
		e.current_health = minf(e.max_health, e.current_health + taken * float(e.traits["lifedrain"].get("fraction", 0.5)))


## Arc Chain: lightning leaps from `first` to up to `jumps` nearby enemies, losing `falloff` each jump.
func chain_lightning(first: EnemyActor, from_pos: Vector3, damage: float, ch: Dictionary, hit_params: Dictionary, skill_name: String, col: Color) -> int:
	var struck: Array = [first]
	var cur_pos := from_pos
	var dmg := damage
	var hits := 0
	for _j in range(int(ch.get("jumps", 1))):
		dmg *= float(ch.get("falloff", 0.7))
		var best: EnemyActor = null
		var best_d := float(ch.get("radius", 6.0))
		for other in enemies_root.get_children():
			var o := other as EnemyActor
			if o == null or not is_instance_valid(o) or struck.has(o) or o.state == EnemyActor.AiState.DEAD:
				continue
			var d := o.global_position.distance_to(cur_pos)
			if d <= best_d:
				best = o
				best_d = d
		if best == null:
			break
		struck.append(best)
		var to := best.global_position + Vector3(0, 1.2, 0)
		var arc := VfxFactory.make_impact_burst(col, 16, 2.0)
		projectiles_root.add_child(arc)
		arc.global_position = to
		var p := hit_params.duplicate()
		p["base_damage"] = dmg
		_apply_player_hit_to_enemy(best, p, skill_name)
		cur_pos = to
		hits += 1
	return hits


## Adds mastery XP to an equipped item and announces new levels / newly discovered abilities (D-049).
func grant_item_xp(item: Dictionary, event: String, enemy_level: int = 1) -> void:
	if item.is_empty() or not MasterySystem.is_masterable(item):
		return
	var res := MasterySystem.add_xp(item, MasterySystem.xp_for(event, enemy_level))
	if res["levels"].is_empty():
		return
	var lvl := int(res["levels"][-1])
	if EventBus != null:
		if res["unlocked"].is_empty():
			EventBus.dungeon_ai_announcement.emit("%s — MASTERY %d" % [str(item.get("name", "Item")).to_upper(), lvl],
				"Stronger with every use. Next discovery at mastery %s." % (str(MasterySystem.next_unlock_level(item)) if MasterySystem.next_unlock_level(item) > 0 else "—"), "info")
		else:
			var names: Array = []
			for e in res["unlocked"]:
				names.append(MasterySystem.ability_name(str(e["ability"])))
			var e0: Dictionary = res["unlocked"][0]
			var p0: Dictionary = e0.duplicate()
			p0.erase("level")
			EventBus.dungeon_ai_announcement.emit("NEW ABILITY — %s" % ", ".join(names).to_upper(),
				"%s reached mastery %d: %s" % [str(item.get("name", "Item")), lvl, MasterySystem.describe(str(e0["ability"]), p0)], "warning")
			EventBus.sfx_requested.emit("level_up")
	player.recalculate_vitals(false)
	player.emit_stats()


## First sighting of an enemy type adds it to the Bestiary (D-049).
func _bestiary_sighting(e: EnemyActor) -> void:
	if e == null or not is_instance_valid(e) or e.has_meta("bestiary_seen"):
		return
	e.set_meta("bestiary_seen", true)
	if bestiary.record_seen(e.enemy_id, e.level, floor_number) and EventBus != null:
		EventBus.dungeon_ai_announcement.emit("NEW ENEMY — %s" % e.display_name.to_upper(),
			"Level %d. Added to your Bestiary (Character menu)." % e.level, "warning")


## Marks the floor boss beaten and opens the arena and vault gates (idempotent).
func _on_boss_defeated() -> void:
	boss_defeated_this_floor = true
	boss_actor = null
	dungeon_builder.unlock_boss_and_vault()


## True while the floor boss is alive and fightable inside its arena.
func _boss_alive() -> bool:
	return boss_actor != null and is_instance_valid(boss_actor) and not boss_actor.is_queued_for_deletion() \
		and boss_actor.state != EnemyActor.AiState.DEAD and boss_actor.current_health > 0.0


func _on_player_died() -> void:
	call_deferred("reset_floor_to_snapshot", "death")


func _on_level_up(new_level: int) -> void:
	_announce_ai("level_up", {"level": new_level}, "info")
	_trigger_tutorial("inventory_pause")
	if EventBus != null:
		EventBus.sfx_requested.emit("level_up")


func _on_prompt_changed(prompt: String) -> void:
	if not prompt.is_empty():
		_trigger_tutorial("looting")


func _update_map_seen() -> void:
	if current_layout == null:
		return
	var t := current_layout.world_to_tile(player.global_position)
	if t == _last_player_tile:
		return
	_last_player_tile = t
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) + absi(dy) > 2:
				continue
			var n := t + Vector2i(dx, dy)
			if current_layout.is_walkable(n.x, n.y):
				map_seen[n] = true
	for room in current_layout.rooms:
		var rect: Rect2i = room["rect"]
		if rect.has_point(t):
			for yy in range(rect.position.y, rect.end.y):
				for xx in range(rect.position.x, rect.end.x):
					map_seen[Vector2i(xx, yy)] = true
			break


func _on_settings_changed(section: String, key: String, _value: Variant) -> void:
	if section == "graphics" and key in ["quality", "brightness"] and dungeon_builder != null:
		dungeon_builder.refresh_environment_quality()


func _on_quit_to_title() -> void:
	save_current_session()
	if DisplayServer.get_name() != "headless" and is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _on_save_and_quit() -> void:
	save_current_session()
	if DisplayServer.get_name() != "headless":
		get_tree().quit()


func _trigger_tutorial(topic_id: String) -> void:
	if tutorial_sys == null:
		return
	var shown := tutorial_sys.trigger_hint(topic_id)
	if not shown.is_empty():
		_sync_tutorial_hud()


func _complete_tutorial(topic_id: String) -> void:
	if tutorial_sys == null:
		return
	if tutorial_sys.complete_hint(topic_id):
		_sync_tutorial_hud()


func _sync_tutorial_hud() -> void:
	if hud == null or tutorial_sys == null:
		return
	hud.update_tutorial_hint(tutorial_sys.get_active_hint())


func _update_hud_navigation() -> void:
	if current_layout == null or hud == null or player == null:
		return
	var compass_cfg: Dictionary = DataLoader.get_world()["compass"]
	var newly := CompassSystem.update_discoveries(current_layout.landmarks, player.global_position, compass_cfg)
	for lm in newly:
		if str(lm.get("kind", "")) == "stairs":
			_trigger_tutorial("stairs_descent")
		if EventBus != null:
			EventBus.dungeon_ai_announcement.emit("LANDMARK DISCOVERED: %s" % str(lm["label"]).to_upper(), "Marked on your compass bar.", "info")
	var fwd := player.get_forward_vector()
	var markers := CompassSystem.compute_visible_markers(current_layout.landmarks, player.global_position, fwd, compass_cfg)
	var yaw_rad := wrapf(-player.rotation.y, 0.0, TAU)
	hud.update_compass(yaw_rad, markers)
	hud.update_minimap(current_layout, map_seen, player.global_position, -player.rotation.y)
	var fcfg := DataLoader.get_floor_config(floor_number)
	hud.update_clock(floor_number, str(fcfg.get("name", "Dungeon")), floor_timer.get_formatted_clock())

	# Boss Health Bar visibility when Boss Arena is engaged
	if boss_actor != null and is_instance_valid(boss_actor) and (dungeon_builder.boss_arena_sealed or boss_actor.state != EnemyActor.AiState.DORMANT):
		var bname := boss_actor.display_name + (" [ENRAGED]" if boss_actor.enraged else "")
		hud.update_boss_bar(true, bname, boss_actor.current_health, boss_actor.max_health)
	else:
		hud.update_boss_bar(false)


func _announce_ai(event_key: String, vars: Dictionary, severity: String = "info", once_only: bool = false) -> void:
	var msg := ai_director.build_announcement(event_key, vars, rng, once_only)
	if not msg.is_empty() and EventBus != null:
		EventBus.dungeon_ai_announcement.emit(str(msg["title"]), str(msg["body"]), severity)
		EventBus.sfx_requested.emit("ai_chime")


func _clear_dynamic_entities() -> void:
	for parent_node in [enemies_root, projectiles_root, corpses_root]:
		if parent_node == null:
			continue
		for c in parent_node.get_children():
			c.queue_free()
	boss_actor = null


func _build_snapshot_payload() -> Dictionary:
	return {
		"floor_number": floor_number,
		"run_seed": run_seed,
		"gold": player.gold,
		"equipment": player.equipment.duplicate(true),
		"inventory": player.inventory.duplicate(true),
		"progression": progression.to_dict(),
	}


func _capture_mouse(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _cmd_teleport(args: Array[String]) -> String:
	if args.is_empty() or current_layout == null:
		return "Usage: teleport <entrance|safe|boss|vault|stairs>"
	var target := args[0].to_lower()
	var room_id := -1
	match target:
		"entrance": room_id = current_layout.entrance_room_id
		"safe": room_id = current_layout.safe_room_id
		"boss": room_id = current_layout.boss_room_id
		"vault": room_id = current_layout.vault_room_id
		"stairs": room_id = current_layout.stairs_room_id
		"combat":
			for r in current_layout.rooms:
				if str(r["role"]) == "combat":
					room_id = int(r["id"])
					break
	if room_id < 0:
		return "Unknown target '%s'. Options: entrance, combat, safe, boss, vault, stairs." % target
	var tile: Vector2i = current_layout.rooms[room_id]["center"]
	player.global_position = current_layout.tile_to_world(tile) + Vector3(0.0, 0.3, 0.0)
	_update_hud_navigation()
	return "Teleported to %s (%s)." % [target, str(tile)]


func _cmd_advance_days(args: Array[String]) -> String:
	var days := float(args[0]) if not args.is_empty() else 1.0
	var res := floor_timer.advance_days(days)
	if bool(res["collapsed_now"]):
		reset_floor_to_snapshot("collapse")
		return "Advanced %.2f days -> Floor Collapsed and reset to Floor-Entry Snapshot!" % days
	_update_hud_navigation()
	return "Advanced %.2f days -> %s" % [days, floor_timer.get_formatted_clock()]


func _cmd_spawn_loot(args: Array[String]) -> String:
	var rarity := args[0].to_lower() if not args.is_empty() else "legendary"
	var rolled := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), floor_number, rng, rarity, true)
	if rolled.is_empty():
		return "Failed to roll loot."
	_grant_loot(rolled, 0)
	return "Granted [%s] %s to backpack." % [str(rolled.get("rarity", "")).to_upper(), str(rolled.get("name", ""))]


func _cmd_seed(args: Array[String]) -> String:
	if args.is_empty():
		return "Current run seed: %d" % run_seed
	run_seed = int(args[0])
	enter_floor(floor_number, true)
	return "Regenerated Floor %d with seed %d." % [floor_number, run_seed]


# ---------------------------------------------------------------------------
# Test Mode API (D-047) — used by the F1 Test Mode panel and by automated tests
# ---------------------------------------------------------------------------

## A point `dist` metres in front of the player at floor level (offset sideways by `side`).
func test_front_point(dist: float = 3.0, side: float = 0.0) -> Vector3:
	var fwd := player.get_forward_vector()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var p := player.global_position + fwd * dist + right * side
	return Vector3(p.x, 0.1, p.z)


func test_spawn_enemy(enemy_id: String, count: int = 1) -> Array:
	var out: Array = []
	for i in range(count):
		var side := (float(i) - float(count - 1) * 0.5) * 1.8
		var e := spawn_enemy(enemy_id, test_front_point(4.5, side), -1)
		if e != null:
			if e.is_boss:
				boss_actor = e
				boss_defeated_this_floor = false
				e.wake_boss()
			out.append(e)
	return out


func test_kill_enemies(radius: float = 1e9) -> int:
	var n := 0
	for c in enemies_root.get_children():
		var e := c as EnemyActor
		if e != null and e.state != EnemyActor.AiState.DEAD and e.global_position.distance_to(player.global_position) <= radius:
			e.take_damage(1e9)
			n += 1
	return n


func test_clear_enemies() -> void:
	for c in enemies_root.get_children():
		c.queue_free()
	boss_actor = null


func test_give_item(item_id: String, rarity: String = "common") -> Dictionary:
	var def := DataLoader.get_item_def(item_id)
	if def.is_empty():
		return {}
	var item: Dictionary
	if str(def.get("category", "")) == "consumable":
		item = LootGenerator.make_base_item_instance(def, "test_%s_%d" % [item_id, player.inventory.size()])
	else:
		item = LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), floor_number,
			SeededRng.new(player.inventory.size() + 1), rarity, false, item_id)
	if item.is_empty():
		return {}
	player.inventory.append(item)
	player.emit_stats()
	return item


func test_give_all_items(rarity: String = "rare") -> void:
	for it in DataLoader.get_items_pack().get("items", []):
		test_give_item(str(it["id"]), rarity)


func test_spawn_object(kind: String) -> Node3D:
	var yaw := player.rotation.y + PI
	return dungeon_builder.spawn_test_object(kind, test_front_point(3.0), yaw, _on_interactable_triggered)


func test_add_levels(n: int) -> void:
	for _i in range(n):
		var lv := progression.add_xp(progression.xp_for_next_level() - progression.xp + 0.01)
		for l in lv:
			if EventBus != null:
				EventBus.level_up_occurred.emit(l)
	player.recalculate_vitals(true)
	player.emit_stats()


func test_teleport(target: String) -> String:
	return run_console_command("teleport " + target)


func test_set_floor(n: int, vast: bool) -> void:
	test_vast_floor = vast
	enter_floor(maxi(1, n), true)


func test_toggle(flag: String) -> bool:
	match flag:
		"god":
			player.god_mode = not player.god_mode
			return player.god_mode
		"ai":
			test_ai_frozen = not test_ai_frozen
			return test_ai_frozen
		"clock":
			test_clock_paused = not test_clock_paused
			return test_clock_paused
		"resources":
			test_infinite_resources = not test_infinite_resources
			return test_infinite_resources
		"camera":
			player.toggle_camera_mode()
			return player.camera_mode == "third_person"
	return false

