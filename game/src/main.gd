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
var debug_overlay: DebugOverlay = null

var boss_actor: EnemyActor = null
var boss_defeated_this_floor: bool = false
var player_in_safe_room: bool = false
var quest_bounty_claimed: bool = false
var _trap_damage_cooldown: float = 0.0
var _spawn_anchor_pos: Vector3 = Vector3.ZERO
var _initialized: bool = false


func _ready() -> void:
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
	})

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

	if capture_snapshot:
		snapshot_mgr.capture_floor_entry_snapshot(_build_snapshot_payload())

	_clear_dynamic_entities()
	var world_pack := DataLoader.get_world()
	var enemies_pack := DataLoader.get_enemies_pack()
	var floor_cfg := DataLoader.get_floor_config(floor_number)

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
	}
	return snapshot_mgr.save_session_to_file(session, save_path)


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
	progression.from_dict(session.get("progression", {}))
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
	debug_overlay.visible = false
	set_menu_pause(true, menu_name)
	match menu_name:
		"inventory":
			inventory_menu.open_menu()
			_complete_tutorial("inventory_pause")
		"vendor":
			vendor_menu.open_menu()
			_complete_tutorial("safe_room")
		"pause":
			var status := "Floor %d  •  %s  •  Lv %d  •  %dg" % [floor_number, floor_timer.get_formatted_clock(), progression.level, player.gold]
			pause_menu.open_menu(status, tutorial_sys.enabled if tutorial_sys != null else false)
		"console":
			debug_overlay.open_console()


func close_all_menus() -> void:
	inventory_menu.visible = false
	vendor_menu.visible = false
	pause_menu.visible = false
	debug_overlay.visible = false
	set_menu_pause(false, "")


func _open_exclusive_menu(menu_name: String) -> void:
	open_exclusive_menu(menu_name)


func _close_all_menus() -> void:
	close_all_menus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_menu_paused:
		player.apply_mouse_look((event as InputEventMouseMotion).relative)
		return

	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_H and not is_menu_paused and tutorial_sys != null:
			tutorial_sys.dismiss_current()
			_sync_tutorial_hud()
			return

	if event.is_action_pressed("toggle_console"):
		if active_menu_name == "console":
			close_all_menus()
		else:
			open_exclusive_menu("console")
		return

	if event.is_action_pressed("toggle_pause"):
		if is_menu_paused:
			close_all_menus()
		else:
			open_exclusive_menu("pause")
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
	var tick_res := floor_timer.tick(delta, is_menu_paused)
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

	# 2. Step Player & Enemy AI
	player.step_simulation(delta, is_menu_paused, input_override)
	var enemy_nearby := false
	for child in enemies_root.get_children():
		if child is EnemyActor:
			var ea := child as EnemyActor
			ea.step_ai(delta, is_menu_paused)
			if not ea.is_boss and ea.global_position.distance_to(player.global_position) <= 10.5:
				enemy_nearby = true

	# Contextual low-friction tutorial triggers
	if player.global_position.distance_to(_spawn_anchor_pos) > 2.4:
		_complete_tutorial("movement_camera")
	if enemy_nearby:
		_trigger_tutorial("combat_hands")
	if tutorial_sys != null and tutorial_sys.tick(delta, is_menu_paused):
		_sync_tutorial_hud()

	# 3. Check Safe Room, Boss Arena Threshold, and Spike Traps
	_check_zone_triggers(delta)
	dungeon_builder.update_light_budget()

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

	# Boss Arena threshold lockdown (D-022)
	if not boss_defeated_this_floor and not dungeon_builder.boss_arena_sealed:
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
	var reach := float(weapon.get("range_meters", 2.6))
	var half_arc_cos := cos(deg_to_rad(float(DataLoader.get_player()["combat"]["melee_arc_degrees"]) * 0.5))
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
		if dist > reach + 0.6:
			continue
		if dist > 0.2 and fwd.dot(delta.normalized()) < half_arc_cos:
			continue
		_apply_player_hit_to_enemy(enemy, {
			"base_damage": float(weapon.get("damage", 16.0)),
			"bonus_damage": float(swing["bonus_damage"]),
			"damage_multiplier": float(swing["damage_multiplier"]),
			"is_power_attack": bool(swing["is_power_attack"]),
			"crit_chance": float(swing["crit_chance"]),
			"crit_multiplier": float(swing["crit_multiplier"]),
			"sponsored_effects": swing["sponsored_effects"],
		}, str(swing["skill_name"]))
		hit_any = true

	if hit_any and EventBus != null:
		EventBus.sfx_requested.emit("sword_hit")


func _on_spawn_projectile(params: Dictionary) -> void:
	if bool(params.get("from_player", false)) and str(params.get("kind", "")) == "arrow":
		_complete_tutorial("archery_aim")
	var proj := GameProjectile.new()
	projectiles_root.add_child(proj)
	proj.global_position = params["origin"]
	proj.setup(params, _on_projectile_hit)


func _on_projectile_hit(proj: GameProjectile, body: Node3D, hit_pos: Vector3) -> void:
	if proj.from_player:
		if body is EnemyActor:
			_apply_player_hit_to_enemy(body as EnemyActor, {
				"base_damage": proj.damage,
				"crit_chance": proj.crit_chance,
				"crit_multiplier": proj.crit_multiplier,
				"sponsored_effects": proj.sponsored_effects,
			}, proj.skill_name)
			if proj.chain_radius > 0.0:
				for other in enemies_root.get_children():
					if other is EnemyActor and other != body:
						if (other as EnemyActor).global_position.distance_to(hit_pos) <= proj.chain_radius:
							(other as EnemyActor).take_damage(proj.damage * 0.65)
							break
		if proj.splash_radius > 0.0:
			for other in enemies_root.get_children():
				if other is EnemyActor and other != body:
					if (other as EnemyActor).global_position.distance_to(hit_pos) <= proj.splash_radius:
						(other as EnemyActor).take_damage(proj.damage * 0.55)
	else:
		if body == player:
			player.take_damage(proj.damage)


func _apply_player_hit_to_enemy(enemy: EnemyActor, params: Dictionary, skill_name: String) -> void:
	var attack_params := params.duplicate(true)
	attack_params["target_armor"] = enemy.armor
	var res := CombatMath.resolve_attack(attack_params, DataLoader.get_player(), rng)
	var dmg := float(res["final_damage"])
	enemy.take_damage(dmg)
	if hud != null:
		hud.trigger_hit_marker()

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


func _on_enemy_died(enemy: EnemyActor) -> void:
	var eq_totals := LootGenerator.aggregate_equipment_stats(player.equipment)
	var sponsored: Array = eq_totals["sponsored_effects"]

	if sponsored.has("vampiric_viewers"):
		player.health = minf(player.max_health, player.health + float(DataLoader.get_sponsored_effect_def("vampiric_viewers").get("heal_on_kill", 12.0)))
	var bonus_gold := int(DataLoader.get_sponsored_effect_def("tax_rebate_gold").get("bonus_gold_on_kill", 15)) if sponsored.has("tax_rebate_gold") else 0

	var gold_roll := rng.next_int_range("loot", enemy.gold_min, enemy.gold_max)
	gold_roll = int(round(float(gold_roll) * (1.0 + float(eq_totals["gold_find_bonus"])))) + bonus_gold

	var lvls := progression.add_xp(float(enemy.xp_reward))
	for l in lvls:
		if EventBus != null:
			EventBus.level_up_occurred.emit(l)

	# Spawn interactive Skyrim lootable corpse
	var corpse := InteractableObject.new()
	var forced_r := enemy.guaranteed_rarity
	var has_item := not forced_r.is_empty() or rng.next_float("loot") <= enemy.loot_drop_chance
	var loot_item := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), floor_number, rng, forced_r) if has_item else {}
	corpse.setup("corpse_%s" % enemy.enemy_id, "corpse", "Loot %s" % enemy.display_name, {
		"gold": gold_roll,
		"item": loot_item,
	}, _on_interactable_triggered, Vector3(1.1, 0.7, 1.1))
	corpse.position = enemy.global_position
	var pile := ModelLoader.instantiate_model("res://assets/models/batch1/chest.glb", Vector3(0.7, 0.4, 0.6))
	pile.scale = Vector3(0.55, 0.45, 0.55)
	corpse.add_child(pile)
	corpses_root.add_child(corpse)

	_announce_ai("first_kill", {}, "info", true)

	if enemy.is_boss:
		boss_defeated_this_floor = true
		boss_actor = null
		dungeon_builder.unlock_boss_and_vault()
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
			var forced := "sponsored" if tier == "vault_sponsored" else ("rare" if tier == "rare" else "")
			var rolled := LootGenerator.roll_loot(DataLoader.get_items_pack(), DataLoader.get_affixes_pack(), floor_number, rng, forced, true)
			var gold_gain := rng.next_int_range("loot", 25, 65) * floor_number
			_grant_loot(rolled, gold_gain)
			_complete_tutorial("looting")
			_trigger_tutorial("inventory_pause")
			if EventBus != null: EventBus.sfx_requested.emit("chest_open")
			return true
		"crate", "urn":
			var gold_gain := rng.next_int_range("loot", 6, 20)
			var potion: Dictionary = {}
			if rng.next_float("loot") < 0.35:
				potion = LootGenerator.make_base_item_instance(DataLoader.get_item_def("health_potion"), "pot_%d" % rng.next_int_range("loot", 1000, 99999))
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
		if str(item.get("rarity", "")) == "sponsored":
			_announce_ai("sponsored_loot", {"item_name": str(item.get("name", "Mythic Gear"))}, "warning")
	player.emit_stats()


func _spawn_floor_enemies(enemies_pack: Dictionary) -> void:
	boss_actor = null
	var scaling: Dictionary = enemies_pack.get("floor_scaling", {})
	for sp in current_layout.enemy_spawns:
		var edef := DataLoader.get_enemy_def(str(sp["enemy_id"]))
		if edef.is_empty():
			continue
		var enemy := EnemyActor.new()
		enemies_root.add_child(enemy)
		var y_off := 0.45 if bool(edef.get("is_boss", false)) else 0.1
		var wpos := current_layout.tile_to_world(sp["tile"]) + Vector3(0.0, y_off, 0.0)
		enemy.setup(edef, scaling, floor_number, int(sp["room_id"]), wpos, current_layout, player, rng, {
			"attack_player": func(_e: EnemyActor, dmg: float, _dir: Vector3) -> void: player.take_damage(dmg),
			"shoot_projectile": func(_e: EnemyActor, origin: Vector3, vel: Vector3, dmg: float) -> void:
				_on_spawn_projectile({
					"kind": "arrow",
					"origin": origin,
					"velocity": vel,
					"gravity": 2.0,
					"damage": dmg,
					"from_player": false,
				}),
			"died": _on_enemy_died,
		})
		if enemy.is_boss:
			boss_actor = enemy


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
	if room_id < 0:
		return "Unknown target '%s'. Options: entrance, safe, boss, vault, stairs." % target
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
	var rarity := args[0].to_lower() if not args.is_empty() else "sponsored"
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
