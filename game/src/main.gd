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
var combat_resolver: CombatResolver = null

var dungeon_builder: DungeonBuilder = null
var player: PlayerController = null
var enemies_root: Node3D = null
var projectiles_root: Node3D = null
var corpses_root: Node3D = null
var ground_zones_root: Node3D = null
var barriers_root: Node3D = null
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
## D-049: the player's knowledge of every enemy type met (saved with the session, never rolled back by a floor reset)
var bestiary: Bestiary = Bestiary.new()
## D-049 Hunter's Focus: enemies and their projectiles run at this speed while a mastered bow is fully drawn
var world_time_scale: float = 1.0
var _bestiary_scan_t: float = 0.0
var boss_defeated_this_floor: bool = false
var player_in_safe_room: bool = false
## FB-022: safe rooms whose area map the player has already read this floor (room ids)
var maps_read: Dictionary = {}
var _trap_damage_cooldown: float = 0.0
var _spawn_anchor_pos: Vector3 = Vector3.ZERO
const ENEMY_ACTIVE_RADIUS := 70.0
const ENEMY_MATERIALIZE_RADIUS := 100.0
## FB-022: floor spawns not created yet (far from the player): [{"idx", "sp", "pos"}]
var _pending_spawns: Array = []
var _materialize_t: float = 0.0
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
var test_champions: bool = false  ## FB-022: Test Mode spawns enemies as champions (mini-bosses)
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
	bestiary.from_dict({})
	floor_timer = FloorTimer.new(DataLoader.get_world()["floor_timer"])
	snapshot_mgr = SnapshotManager.new()
	vendor_sys = VendorSystem.new(DataLoader.get_balance_pack())
	ai_director = DungeonAiDirector.new(DataLoader.get_dungeon_ai_pack())
	tutorial_sys = TutorialSystem.new(DataLoader.get_tutorials_pack())
	combat_resolver = CombatResolver.new(self)

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

	ground_zones_root = Node3D.new()
	ground_zones_root.name = "GroundZones"
	add_child(ground_zones_root)

	barriers_root = Node3D.new()
	barriers_root.name = "Barriers"
	add_child(barriers_root)

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
	inventory_menu.setup(player, close_all_menus, bestiary)

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
	maps_read.clear()
	ai_director.reset_floor_flags()
	floor_timer.reset()
	# D-039: every attempt at a floor replays from the same random state (combat rolls, AI, banners).
	rng.reseed(_floor_seed("attempt"))
	map_seen.clear()
	_last_player_tile = Vector2i(-999, -999)
	if hud != null:
		hud.clear_transient_messages()  # stale announcements from the previous floor / attempt don't linger

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

	# Refresh Safe Room Vendor stock deterministically for this floor (excluding already-owned non-stackables)
	var vendor_rng := SeededRng.new(int(("%d:vendor:%d" % [run_seed, floor_number]).hash()))
	vendor_sys.refresh_stock(DataLoader.get_items_pack(), DataLoader.get_rarities_pack(), floor_number, vendor_rng, _owned_non_stackable_ids())

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
		player.hotbar = (snap.get("hotbar", []) as Array).duplicate(true)
		if player.hotbar.size() != PlayerController.HOTBAR_SIZE:
			player.reset_hotbar()
		player.timed_effects.clear()
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
		"hotbar": player.hotbar.duplicate(true),
		"progression": progression.to_dict(),
		"timer": floor_timer.to_dict(),
		"tutorials": tutorial_sys.to_dict() if tutorial_sys != null else {},
		"boss_defeated": boss_defeated_this_floor,
		"map_seen": _map_seen_to_array(),
		"maps_read": maps_read.keys(),
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
	player.hotbar = (session.get("hotbar", []) as Array).duplicate(true)
	if player.hotbar.size() != PlayerController.HOTBAR_SIZE:
		player.reset_hotbar()
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
	materialize_nearby_enemies()
	player.recalculate_vitals(false)
	player.health = clampf(float(session.get("health", player.max_health)), 1.0, player.max_health)
	player.magicka = clampf(float(session.get("magicka", player.max_magicka)), 0.0, player.max_magicka)
	player.stamina = clampf(float(session.get("stamina", player.max_stamina)), 0.0, player.max_stamina)
	floor_timer.from_dict(session.get("timer", {}))
	for code in session.get("map_seen", []):
		var ci := int(code)
		map_seen[Vector2i(ci % 1000, ci / 1000)] = true
	for sid in session.get("maps_read", []):
		read_area_map(int(sid), false)
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
	elif event.is_action_pressed("quick_potion"):
		player.quick_drink_health_potion()
	else:
		# FB-022 hotbar: keys 1-8 equip a favourite weapon / spell / shield or use one of a stack
		for i in range(PlayerController.HOTBAR_SIZE):
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				if player.use_hotbar(i):
					_complete_tutorial("combat_hands")
					if str(player.equipment.get("right_hand", {}).get("weapon_type", "")) == "archery":
						_trigger_tutorial("archery_aim")
				if hud != null:
					hud.flash_hotbar_slot(i)
				break


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
	_materialize_t -= delta
	if _materialize_t <= 0.0:
		_materialize_t = 0.5
		materialize_nearby_enemies()
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
			return "Added %d gold (total: %d)." % [amt, player.gold],
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
		var sid := safe_room_at(player.global_position)
		if sid >= 0 and not maps_read.has(sid):
			read_area_map(sid)
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
	combat_resolver.resolve_player_melee_swing(swing)


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


func spawn_ground_zone(params: Dictionary, pos: Vector3) -> GroundZone:
	var zone := GroundZone.new()
	ground_zones_root.add_child(zone)
	zone.global_position = pos
	zone.setup(params)
	return zone


func spawn_barrier(params: Dictionary, pos: Vector3, yaw: float = 0.0) -> Barrier:
	var bar := Barrier.new()
	barriers_root.add_child(bar)
	bar.global_position = pos
	bar.rotation.y = yaw
	bar.setup(params)
	return bar


func _on_projectile_hit(proj: GameProjectile, body: Node3D, hit_pos: Vector3) -> void:
	combat_resolver.resolve_projectile_hit(proj, body, hit_pos)


func _apply_player_hit_to_enemy(enemy: EnemyActor, params: Dictionary, skill_name: String) -> void:
	combat_resolver.apply_player_hit_to_enemy(enemy, params, skill_name)


func _spawn_hit_feedback(pos: Vector3, dmg: float, crit: bool) -> void:
	combat_resolver.spawn_hit_feedback(pos, dmg, crit)


## FB-022: damage-over-time ticks pop up in the colour of their status (burn orange, bleed red, poison green).
func _on_enemy_dot_tick(enemy: EnemyActor, amount: float, kind: String) -> void:
	if not is_inside_tree() or enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	if GameSettings != null and not bool(GameSettings.get_value("gameplay", "show_damage_numbers")):
		return
	var lbl := Label3D.new()
	lbl.name = "DotNumber_" + kind
	lbl.text = "%d" % maxi(1, int(round(amount)))
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 40
	lbl.pixel_size = 0.004
	lbl.outline_size = 10
	lbl.modulate = EnemyActor.STATUS_COLORS.get(kind, Color.WHITE)
	lbl.outline_modulate = Color(0.05, 0.02, 0.0, 0.9)
	if UiTheme.font_heading() != null:
		lbl.font = UiTheme.font_heading()
	projectiles_root.add_child(lbl)
	var side := rng.next_float_range("ai", -0.45, 0.45)
	lbl.global_position = enemy.global_position + Vector3(side, enemy._height * 0.8, 0.0)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 0.7, 0), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


func _on_enemy_died(enemy: EnemyActor) -> void:
	# The boss's gates are opened FIRST, so nothing later in this handler (loot, corpse, VFX) can leave the
	# player sealed in the arena or locked out of the vault
	if enemy.is_boss:
		_on_boss_defeated()
	var eq_totals := LootGenerator.aggregate_equipment_stats(player.equipment)
	var legendary: Array = eq_totals["legendary_effects"]

	if legendary.has("blood_feast"):
		player.health = minf(player.max_health, player.health + float(DataLoader.get_legendary_effect_def("blood_feast").get("heal_on_kill", 12.0)))
	var bonus_gold := int(DataLoader.get_legendary_effect_def("grave_robber").get("bonus_gold_on_kill", 15)) if legendary.has("grave_robber") else 0

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

	# Spawn interactive Skyrim lootable corpse (D-060: inherent rarity + no-duplicate pool)
	var corpse := InteractableObject.new()
	var forced_r := enemy.guaranteed_rarity
	var has_item := not forced_r.is_empty() or loot_rng.next_float("loot") <= enemy.loot_drop_chance
	var source_prof := "boss" if enemy.is_boss else ("champion" if enemy.is_champion else "corpse")
	var loot_item := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_rarities_pack(), floor_number, loot_rng,
		forced_r, false, "", source_prof, _owned_and_corpse_non_stackable_ids()) if has_item else {}
	var corpse_id := "corpse_%s_%d" % [enemy.enemy_id, corpses_root.get_child_count()]
	corpse.setup(corpse_id, "corpse", "Search %s" % enemy.display_name, {
		"gold": gold_roll,
		"item": loot_item,
		"source_prof": source_prof,
		"forced_r": forced_r,
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

	if enemy.is_champion:
		_mark_poi_done("spawn_index", int(enemy.get_meta("spawn_index", -1)))
		if EventBus != null:
			EventBus.dungeon_ai_announcement.emit("CHAMPION SLAIN — %s" % enemy.display_name.to_upper(),
				"Its lair's treasure is yours. Search the body, too.", "warning")
			EventBus.sfx_requested.emit("level_up")

	if enemy.is_boss:
		_complete_tutorial("boss_arena")
		if EventBus != null:
			EventBus.boss_defeated.emit(enemy.display_name)
			EventBus.sfx_requested.emit("door_seal")
		_announce_ai("boss_defeated", {}, "warning", true)

	if EventBus != null:
		EventBus.enemy_killed.emit(enemy.enemy_id, enemy.xp_reward, gold_roll, enemy.is_boss)
	player.emit_stats()


func _owned_non_stackable_ids() -> Dictionary:
	if player == null:
		return {}
	return LootGenerator.collect_owned_non_stackable_ids(player.equipment, player.inventory)


func _owned_and_corpse_non_stackable_ids() -> Dictionary:
	var owned := _owned_non_stackable_ids()
	if corpses_root != null:
		for c in corpses_root.get_children():
			var inter := c as InteractableObject
			if inter != null and not inter.consumed:
				var it: Variant = inter.payload.get("item", {})
				if typeof(it) == TYPE_DICTIONARY and not (it as Dictionary).is_empty() and not InventoryStacks.is_stackable(it):
					owned[str((it as Dictionary).get("id", ""))] = true
	return owned


func _on_interactable_triggered(inter: InteractableObject, _actor: Node3D) -> bool:
	match inter.kind:
		"chest":
			if inter.interact_id.begins_with("chest_"):
				_mark_poi_done("chest_index", int(inter.interact_id.trim_prefix("chest_")))
			var tier := str(inter.payload.get("tier", "standard"))
			var chest_rng := _loot_rng_for(inter.interact_id)
			var rolled := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_rarities_pack(), floor_number, chest_rng,
				"", true, "", tier, _owned_non_stackable_ids())
			var gold_gain := chest_rng.next_int_range("loot", 25, 65) * floor_number
			if not rolled.is_empty() and InventoryStacks.is_stackable(rolled):
				gold_gain += chest_rng.next_int_range("loot", 30, 60) * floor_number
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
				var cons: Array = []
				for d in DataLoader.get_items_pack().get("items", []):
					if str(d.get("category", "")) == "consumable":
						cons.append(d)
				if not cons.is_empty():
					var p_pick: Dictionary = RarityTable.pick_entry_by_rarity(cons, floor_number, cont_rng, "loot")
					potion = LootGenerator.make_base_item_instance(DataLoader.get_item_def(str(p_pick["id"])), "pot_%d" % cont_rng.next_int_range("loot", 1000, 99999))
			_grant_loot(potion, gold_gain)
			# FB-022 / D-060: crates and urns hold ingredients picked by rarity
			if cont_rng.next_float("loot") < 0.5:
				var ingr: Array = []
				for d in DataLoader.get_items_pack().get("items", []):
					if str(d.get("category", "")) == "ingredient":
						ingr.append(d)
				if not ingr.is_empty():
					var pick: Dictionary = RarityTable.pick_entry_by_rarity(ingr, floor_number, cont_rng, "loot")
					var found := LootGenerator.make_base_item_instance(DataLoader.get_item_def(str(pick["id"])), "ingr_%d" % cont_rng.next_int_range("loot", 1000, 99999))
					found["count"] = cont_rng.next_int_range("loot", 1, 3)
					_grant_loot(found, 0)
			_complete_tutorial("looting")
			if EventBus != null: EventBus.sfx_requested.emit("chest_open")
			return true
		"corpse":
			var c_item: Dictionary = inter.payload.get("item", {})
			var c_gold := int(inter.payload.get("gold", 0))
			if not c_item.is_empty() and not InventoryStacks.is_stackable(c_item):
				var owned := _owned_non_stackable_ids()
				if owned.has(str(c_item.get("id", ""))):
					# Re-roll cleanly if player acquired this item between the kill and searching the corpse
					var reroll_rng := _loot_rng_for(inter.interact_id + "_reroll")
					c_item = LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_rarities_pack(), floor_number,
						reroll_rng, str(inter.payload.get("forced_r", "")), false, "", str(inter.payload.get("source_prof", "corpse")), owned)
			_grant_loot(c_item, c_gold)
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
		"area_map":
			# FB-022: study the safe room's wall map, then look at it on your own map
			_complete_tutorial("safe_room")
			var sid := safe_room_at(inter.global_position)
			if sid >= 0:
				read_area_map(sid)
			open_exclusive_menu("map")
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
		player.add_to_inventory(item)
		if EventBus != null:
			EventBus.item_acquired.emit(item)
		if str(item.get("rarity", "")) == "legendary":
			_announce_ai("legendary_loot", {"item_name": str(item.get("name", "Legendary Relic"))}, "warning")
	player.emit_stats()


func _spawn_floor_enemies(enemies_pack: Dictionary) -> void:
	boss_actor = null
	_pending_spawns.clear()
	var scaling: Dictionary = enemies_pack.get("floor_scaling", {})
	for spawn_idx in current_layout.enemy_spawns.size():
		var sp: Dictionary = current_layout.enemy_spawns[spawn_idx]
		var edef := DataLoader.get_enemy_def(str(sp["enemy_id"]))
		if edef.is_empty():
			continue
		var is_b := bool(edef.get("is_boss", false))
		var rec := {"idx": spawn_idx, "sp": sp, "pos": current_layout.tile_to_world(sp["tile"]) + Vector3(0.0, 0.45 if is_b else 0.1, 0.0)}
		if is_b:
			var enemy := _spawn_from_record(rec, scaling)
			if enemy != null:
				boss_actor = enemy
		else:
			_pending_spawns.append(rec)
	materialize_nearby_enemies()


## FB-022: with thousands of (weaker) enemies per floor, each one is only created once the player comes within
## ENEMY_MATERIALIZE_RADIUS of its spawn point. Spawns are seeded per index, so who appears where never changes.
func materialize_nearby_enemies() -> int:
	if player == null or _pending_spawns.is_empty():
		return 0
	var ppos := player.global_position
	var r2 := ENEMY_MATERIALIZE_RADIUS * ENEMY_MATERIALIZE_RADIUS
	var keep: Array = []
	var made := 0
	var scaling: Dictionary = DataLoader.get_enemies_pack().get("floor_scaling", {})
	for rec in _pending_spawns:
		var pos: Vector3 = rec["pos"]
		if Vector2(pos.x - ppos.x, pos.z - ppos.z).length_squared() <= r2:
			_spawn_from_record(rec, scaling)
			made += 1
		else:
			keep.append(rec)
	_pending_spawns = keep
	return made


func _spawn_from_record(rec: Dictionary, scaling: Dictionary) -> EnemyActor:
	var sp: Dictionary = rec["sp"]
	var opts := {}
	if bool(sp.get("champion", false)):
		opts["champion"] = {"title": str(sp.get("title", "the Champion"))}
	var enemy := spawn_enemy(str(sp["enemy_id"]), rec["pos"], int(sp["room_id"]),
		"enemy_%d_%s" % [int(rec["idx"]), str(sp["enemy_id"])], scaling, 0, opts)
	if enemy != null:
		enemy.set_meta("spawn_index", int(rec["idx"]))
	return enemy


## Creates one enemy (floor spawns and Test Mode). Returns null for an unknown enemy id.
func spawn_enemy(enemy_id: String, wpos: Vector3, room_id: int = -1, spawn_key: String = "", scaling: Dictionary = {}, level_override: int = 0, opts: Dictionary = {}) -> EnemyActor:
	var edef := DataLoader.get_enemy_def(enemy_id)
	if edef.is_empty():
		return null
	if opts.has("champion"):
		edef = edef.duplicate()
		edef["_champion"] = opts["champion"]
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
		"dot_tick": _on_enemy_dot_tick,
	}, lvl)
	return enemy


## An enemy's blow or shot reaching the crawler: blocks, shield & armor mastery effects and enemy traits (D-049).
func _enemy_hit_player(e: EnemyActor, dmg: float, melee: bool) -> void:
	combat_resolver.resolve_enemy_hit_player(e, dmg, melee)


## Arc Chain: lightning leaps from `first` to up to `jumps` nearby enemies, losing `falloff` each jump.
func chain_lightning(first: EnemyActor, from_pos: Vector3, damage: float, ch: Dictionary, hit_params: Dictionary, skill_name: String, col: Color) -> int:
	return combat_resolver.chain_lightning(first, from_pos, damage, ch, hit_params, skill_name, col)


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
		# FB-022: an engaged champion gets the big health bar too
		var champ := engaged_champion()
		if champ != null:
			hud.update_boss_bar(true, champ.display_name + (" [ENRAGED]" if champ.enraged else ""), champ.current_health, champ.max_health, "champion")
		else:
			hud.update_boss_bar(false)


## Safe room containing this world position (-1 if none).
func safe_room_at(wpos: Vector3) -> int:
	if current_layout == null:
		return -1
	var t := current_layout.world_to_tile(wpos)
	for sid in current_layout.safe_room_ids:
		var rr: Rect2i = current_layout.rooms[sid]["rect"]
		if rr.grow(1).has_point(t):
			return sid
	return -1


## FB-022: a safe room's wall map — inks every walkable tile within the reveal radius onto the player's map and
## reveals the treasure, champion lairs and landmarks inside it. Returns {"tiles", "treasure", "champions", "landmarks"}.
func read_area_map(safe_room_id: int, announce: bool = true) -> Dictionary:
	var out := {"tiles": 0, "treasure": 0, "champions": 0, "landmarks": 0}
	if current_layout == null or safe_room_id < 0 or safe_room_id >= current_layout.rooms.size():
		return out
	maps_read[safe_room_id] = true
	var c: Vector2i = current_layout.rooms[safe_room_id]["center"]
	var r := int(DataLoader.get_world().get("safe_room_map", {}).get("reveal_radius_tiles", 40))
	for y in range(maxi(0, c.y - r), mini(current_layout.height, c.y + r + 1)):
		for x in range(maxi(0, c.x - r), mini(current_layout.width, c.x + r + 1)):
			if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) > r * r:
				continue
			if current_layout.is_walkable(x, y):
				var t := Vector2i(x, y)
				if not map_seen.has(t):
					map_seen[t] = true
					out["tiles"] += 1
	for p in current_layout.pois:
		var pt: Vector2i = p["tile"]
		if (pt - c).length_squared() <= r * r and not bool(p["revealed"]):
			p["revealed"] = true
			out["champions" if str(p["kind"]) == "champion" else "treasure"] += 1
	for lm in current_layout.landmarks:
		var lt := current_layout.world_to_tile(lm["world_pos"])
		if (lt - c).length_squared() <= r * r and not bool(lm.get("discovered", false)):
			lm["discovered"] = true
			out["landmarks"] += 1
	if announce and EventBus != null:
		EventBus.dungeon_ai_announcement.emit("AREA MAP STUDIED",
			"Your map now shows the surrounding area: %d treasure, %d champion lair%s and %d landmark%s marked. Press M to look." % [
				out["treasure"], out["champions"], "" if out["champions"] == 1 else "s", out["landmarks"], "" if out["landmarks"] == 1 else "s"], "info")
	return out


## FB-022: crosses a point of interest off the map (looted chest, slain champion).
func _mark_poi_done(key: String, value: int) -> void:
	if current_layout == null or value < 0:
		return
	for p in current_layout.pois:
		if int(p.get(key, -1)) == value:
			p["done"] = true


## The nearest champion currently fighting the player (within 30 m), or null.
func engaged_champion() -> EnemyActor:
	if not is_inside_tree():
		return null
	var best: EnemyActor = null
	var bd := 30.0
	for n in get_tree().get_nodes_in_group("champions"):
		var e := n as EnemyActor
		if e == null or e.is_queued_for_deletion() or e.state not in [EnemyActor.AiState.CHASE, EnemyActor.AiState.ATTACK]:
			continue
		var d := e.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _announce_ai(event_key: String, vars: Dictionary, severity: String = "info", once_only: bool = false) -> void:
	var msg := ai_director.build_announcement(event_key, vars, rng, once_only)
	if not msg.is_empty() and EventBus != null:
		EventBus.dungeon_ai_announcement.emit(str(msg["title"]), str(msg["body"]), severity)
		EventBus.sfx_requested.emit("ai_chime")


func _clear_dynamic_entities() -> void:
	for parent_node in [enemies_root, projectiles_root, corpses_root, ground_zones_root, barriers_root]:
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
		"hotbar": player.hotbar.duplicate(true),
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
		"champion":
			# FB-022: the doorway of the nearest champion lair
			var best := 1e9
			for p in current_layout.pois:
				if str(p["kind"]) == "champion" and not bool(p["done"]):
					var d := (p["world_pos"] as Vector3).distance_to(player.global_position)
					if d < best:
						best = d
						room_id = int(current_layout.enemy_spawns[int(p["spawn_index"])]["room_id"])
	if room_id < 0:
		return "Unknown target '%s'. Options: entrance, combat, champion, safe, boss, vault, stairs." % target
	var tile: Vector2i = current_layout.rooms[room_id]["center"]
	if target == "champion":
		var rr: Rect2i = current_layout.rooms[room_id]["rect"]
		tile = Vector2i(rr.position.x, rr.end.y - 1)
	player.global_position = current_layout.tile_to_world(tile) + Vector3(0.0, 0.3, 0.0)
	materialize_nearby_enemies()
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
	var rarity := args[0].to_lower() if not args.is_empty() else ""
	var rolled := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_rarities_pack(), floor_number, rng, rarity, true, "", "", _owned_non_stackable_ids())
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
		var opts := {"champion": {"title": "the Test Subject"}} if test_champions else {}
		var e := spawn_enemy(enemy_id, test_front_point(4.5, side), -1, "", {}, 0, opts)
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


func test_give_item(item_id: String, _ignored_rarity: String = "") -> Dictionary:
	var def := DataLoader.get_item_def(item_id)
	if def.is_empty():
		return {}
	var item := LootGenerator.make_base_item_instance(def, "test_%s_%d" % [item_id, player.inventory.size()])
	if item.is_empty():
		return {}
	item = player.add_to_inventory(item)
	player.emit_stats()
	return item


func test_give_all_items(_ignored_rarity: String = "") -> void:
	for it in DataLoader.get_items_pack().get("items", []):
		test_give_item(str(it["id"]))


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


## Test Mode (D-049): adds mastery levels to every equipped item (unlocking their abilities).
func test_add_mastery(levels: int) -> void:
	for slot in player.equipment.keys():
		var it: Dictionary = player.equipment[slot]
		for _i in range(levels):
			MasterySystem.add_xp(it, float(MasterySystem.xp_to_next(MasterySystem.level_of(it))) + 0.01)
	player.recalculate_vitals(false)
	player.refresh_hand_visuals()
	player.emit_stats()


## Test Mode (D-049): marks every enemy type as studied in the Bestiary.
func test_reveal_bestiary() -> void:
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		var r := EnemyLevels.type_range(e)
		bestiary.record_seen(str(e["id"]), r.x, floor_number)
		bestiary.record_seen(str(e["id"]), r.y, floor_number)
		while bestiary.kills(str(e["id"])) < Bestiary.STUDY_KILLS:
			bestiary.record_kill(str(e["id"]), r.x, floor_number)


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

