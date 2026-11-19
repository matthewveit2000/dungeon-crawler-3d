extends GutTest
## Full Headless 3D Gameplay Integration Suite (Phases 3–8).
## Spawns the actual GameMain 3D scene headlessly and verifies:
## - Fresh launch playability (Entrance, Safe Room, Boss Arena, Vault, Hidden Stairs all built)
## - 1st-person primary + 3rd-person camera toggle (D-012)
## - Left/right-hand equipping & quick loadouts + Spell/Bow/Melee combat (D-013)
## - Menu pause completely freezes the 5-day floor timer (D-016)
## - Safe Room repulsion forces pursuing enemies to FLEE (D-021)
## - Boss Arena seals on entry and unseals Boss Gate + Treasure Vault on boss defeat (D-022)
## - Floor Collapse AND Combat Death both restore Floor-Entry Snapshot cleanly (D-014, D-018)
## - Hidden Staircase descends to Floor 2 with zero preview & fresh 5-day clock (D-008)
## - Save-and-Quit round-trip resumes exact floor position, timer & snapshot (D-017)

const TEST_SAVE := "user://integration_save_test.json"

var game: GameMain = null


func before_each() -> void:
	SnapshotManager.delete_save_file(TEST_SAVE)
	game = GameMain.new()
	game.run_seed = 424242
	game.auto_load_save_on_ready = false
	game.save_path = TEST_SAVE
	add_child_autofree(game)


func after_each() -> void:
	SnapshotManager.delete_save_file(TEST_SAVE)


func test_fresh_launch_builds_complete_playable_3d_floor_and_camera_toggle() -> void:
	assert_not_null(game.current_layout)
	assert_not_null(game.player)
	assert_eq(game.floor_number, 1)
	assert_eq(game.player.camera_mode, "first_person", "D-012: Starts in first-person")
	assert_eq(game.player.toggle_camera_mode(), "third_person")
	assert_true(game.player.tp_mesh.visible, "3rd-person Blender crawler mesh visible in 3rd-person")
	assert_eq(game.player.toggle_camera_mode(), "first_person")
	assert_false(game.player.tp_mesh.visible, "3rd-person mesh hidden in 1st-person")
	assert_gt(game.enemies_root.get_child_count(), 5, "Floor 1 must spawn dungeon enemies + Floor Boss")


func test_menu_pause_freezes_5_day_timer_and_player_simulation() -> void:
	var before_sec := game.floor_timer.remaining_seconds
	game.set_menu_pause(true, "inventory")
	game.step_simulation(120.0)
	assert_almost_eq(game.floor_timer.remaining_seconds, before_sec, 0.001, "Menu pause must freeze 5-day clock")

	game.set_menu_pause(false, "")
	game.step_simulation(10.0)
	assert_lt(game.floor_timer.remaining_seconds, before_sec - 9.0)


func test_safe_room_entry_repels_pursuing_enemies() -> void:
	# Find a regular enemy and move player into Safe Room
	var regular: EnemyActor = null
	for child in game.enemies_root.get_children():
		if child is EnemyActor and not (child as EnemyActor).is_boss:
			regular = child as EnemyActor
			break
	assert_not_null(regular)
	regular.state = EnemyActor.AiState.CHASE

	game.run_console_command("teleport safe")
	game.step_simulation(0.1)
	assert_true(game.player_in_safe_room, "Player must be recognized inside Safe Room")
	assert_eq(regular.state, EnemyActor.AiState.FLEE_SAFE_ZONE, "D-021: Pursuing enemy must flee when player enters Safe Room")


func test_boss_arena_seals_on_entry_and_unlocks_vault_on_boss_defeat() -> void:
	assert_false(game.dungeon_builder.boss_arena_sealed)
	assert_false(game.dungeon_builder.vault_unlocked)
	assert_not_null(game.boss_actor)
	assert_eq(game.boss_actor.state, EnemyActor.AiState.DORMANT, "Boss must start dormant before arena entry")

	game.run_console_command("teleport boss")
	game.step_simulation(0.1)
	assert_true(game.dungeon_builder.boss_arena_sealed, "D-022: Boss Gate must slam shut on arena entry")
	assert_ne(game.boss_actor.state, EnemyActor.AiState.DORMANT, "Boss must wake on arena entry")

	# Defeat the Floor Boss
	game.boss_actor.take_damage(99999.0)
	assert_true(game.boss_defeated_this_floor)
	assert_false(game.dungeon_builder.boss_arena_sealed, "Boss Gate must unseal on boss defeat")
	assert_true(game.dungeon_builder.vault_unlocked, "Treasure Vault Gate must unlock on boss defeat")
	assert_gt(game.corpses_root.get_child_count(), 0, "Defeated boss must spawn lootable corpse")


func test_floor_collapse_and_combat_death_restore_floor_entry_snapshot() -> void:
	var entry_gold := game.player.gold
	var entry_bag_size := game.player.inventory.size()

	# Earn gold & sponsored loot during attempt, then trigger 5-day floor collapse
	game.run_console_command("add_gold 500")
	game.run_console_command("spawn_loot sponsored")
	assert_eq(game.player.gold, entry_gold + 500)
	assert_eq(game.player.inventory.size(), entry_bag_size + 1)

	game.run_console_command("advance_days 5.1")
	assert_eq(game.player.gold, entry_gold, "D-014: Collapse must restore floor-entry gold")
	assert_eq(game.player.inventory.size(), entry_bag_size, "D-014: Collapse must drop mid-floor loot")
	assert_almost_eq(game.floor_timer.get_days_remaining(), 5.0, 0.01, "Fresh 5-day timer after reset")

	# Now test Combat Death reset (D-018)
	game.run_console_command("add_gold 250")
	game.reset_floor_to_snapshot("death")
	assert_eq(game.player.gold, entry_gold, "D-018: Combat death must restore floor-entry snapshot")


func test_hidden_staircase_descends_to_floor_2_and_updates_snapshot() -> void:
	game.run_console_command("add_gold 150")
	var carried_gold := game.player.gold
	game.enter_floor(2, true)
	assert_eq(game.floor_number, 2)
	assert_almost_eq(game.floor_timer.get_days_remaining(), 5.0, 0.01)

	# Collapsing on Floor 2 keeps the gold we ENTERED Floor 2 with!
	game.run_console_command("add_gold 999")
	game.reset_floor_to_snapshot("collapse")
	assert_eq(game.floor_number, 2)
	assert_eq(game.player.gold, carried_gold, "Floor 2 reset keeps Floor 2 entry snapshot")


func test_save_and_quit_resumes_exact_mid_floor_state() -> void:
	game.run_console_command("add_gold 88")
	game.run_console_command("advance_days 1.5")
	var saved_days := game.floor_timer.get_days_remaining()
	assert_true(game.save_current_session())

	var game2 := GameMain.new()
	game2.auto_load_save_on_ready = true
	game2.save_path = TEST_SAVE
	add_child_autofree(game2)

	assert_eq(game2.player.gold, game.player.gold)
	assert_almost_eq(game2.floor_timer.get_days_remaining(), saved_days, 0.02)
	assert_eq(game2.floor_number, 1)


func test_combat_quick_loadouts_spells_and_archery_execute_cleanly() -> void:
	# Quick loadout 3: Sword + Firebolt spell
	game.player.quick_equip_preset(3)
	assert_eq(str(game.player.equipment["left_hand"]["id"]), "spell_firebolt")
	var mp_before := game.player.magicka
	game.player.handle_hand_press("left_hand")
	assert_lt(game.player.magicka, mp_before, "Casting Firebolt must spend Magicka")
	assert_gt(game.projectiles_root.get_child_count(), 0, "Firebolt must spawn 3D projectile")

	# Quick loadout 4: Hunting Bow (two-handed clears left hand)
	game.player.quick_equip_preset(4)
	assert_eq(str(game.player.equipment["right_hand"]["id"]), "hunting_bow")
	assert_false(game.player.equipment.has("left_hand"))
	game.player.handle_hand_press("right_hand")
	game.step_simulation(0.6)
	game.player.handle_hand_release("right_hand")
	assert_gte(game.projectiles_root.get_child_count(), 2, "Releasing drawn bow must fire 3D arrow")


func test_melee_combat_kills_enemy_grants_xp_skyrim_skill_use_and_corpse_loot() -> void:
	var target: EnemyActor = null
	for child in game.enemies_root.get_children():
		if child is EnemyActor and not (child as EnemyActor).is_boss:
			target = child as EnemyActor
			break
	assert_not_null(target, "Must have a regular enemy to fight")

	# Position player 1.5m in front of enemy facing directly at it (-Z forward)
	var enemy_pos := target.global_position
	game.player.global_position = enemy_pos + Vector3(0.0, 0.0, 1.5)
	game.player.rotation = Vector3.ZERO
	game.player.head_pivot.rotation = Vector3.ZERO
	game.player.quick_equip_preset(1)

	var start_hp: float = target.current_health
	var start_xp := game.progression.xp
	var start_skill_xp: float = float(game.progression.skill_xp.get("one_handed", 0.0))
	var start_skill_lvl := int(game.progression.skill_levels.get("one_handed", 1))
	var corpses_before := game.corpses_root.get_child_count()

	# Swing repeatedly (press + release for Light/Power attack) until enemy is defeated
	var swings := 0
	while is_instance_valid(target) and target.current_health > 0.0 and swings < 20:
		game.player.stamina = game.player.max_stamina
		game.player.handle_hand_press("right_hand")
		game.step_simulation(0.05)
		game.player.handle_hand_release("right_hand")
		game.step_simulation(0.75)
		swings += 1

	assert_lt(swings, 20, "Enemy should die within 20 melee swings")
	assert_gt(start_hp, 0.0)
	assert_true(not is_instance_valid(target) or target.current_health <= 0.0, "Enemy must be defeated by melee swings")
	assert_gt(game.progression.xp, start_xp, "Killing enemy must grant character XP")
	var used_one_handed := float(game.progression.skill_xp.get("one_handed", 0.0)) > start_skill_xp or int(game.progression.skill_levels.get("one_handed", 1)) > start_skill_lvl
	assert_true(used_one_handed, "Landing sword hits must advance Skyrim one-handed proficiency")
	assert_gt(game.corpses_root.get_child_count(), corpses_before, "Defeated enemy must drop lootable corpse")

	# Interact with the dropped corpse and collect gold
	var corpse := game.corpses_root.get_child(game.corpses_root.get_child_count() - 1) as InteractableObject
	assert_not_null(corpse)
	var gold_before := game.player.gold
	assert_true(corpse.trigger(game.player), "First corpse interaction must succeed")
	assert_gt(game.player.gold, gold_before, "Looting corpse must grant gold")
	assert_false(corpse.trigger(game.player), "Already-looted corpse must not grant loot twice")


func test_interactive_chest_quest_board_vendor_and_audit_console_shortcuts() -> void:
	# 1. Interactive Chest looting
	var chest: InteractableObject = null
	var quest_board: InteractableObject = null
	var vendor_inter: InteractableObject = null
	for node in get_tree().get_nodes_in_group("interactables"):
		if not (node is InteractableObject):
			continue
		var inter := node as InteractableObject
		if inter.kind == "chest" and chest == null:
			chest = inter
		elif inter.kind == "quest_board" and quest_board == null:
			quest_board = inter
		elif inter.kind == "vendor" and vendor_inter == null:
			vendor_inter = inter

	assert_not_null(chest, "Floor must spawn lootable chests")
	assert_not_null(quest_board, "Safe Room must spawn Quest Board")
	assert_not_null(vendor_inter, "Safe Room must spawn Vendor")

	var gold_before := game.player.gold
	var bag_before := game.player.inventory.size()
	assert_true(chest.trigger(game.player), "Opening chest must succeed")
	assert_gt(game.player.gold, gold_before, "Chest must grant gold")
	assert_gt(game.player.inventory.size(), bag_before, "Chest must grant rolled loot item")
	assert_false(chest.trigger(game.player), "Opened chest must not be lootable twice")

	# 2. Safe Room Quest Board advance
	var pre_bounty_gold := game.player.gold
	assert_true(quest_board.trigger(game.player))
	assert_eq(game.player.gold, pre_bounty_gold + 35, "Quest Board must grant +35g advance")

	# 3. Safe Room Vendor interaction pauses clock and supports buying
	assert_true(vendor_inter.trigger(game.player))
	assert_true(game.is_menu_paused, "Opening Vendor must pause the 5-day floor clock (D-016)")
	assert_eq(game.active_menu_name, "vendor")
	game.run_console_command("add_gold 500")
	var buy_res: Dictionary = game.vendor_sys.buy_item(0, game.player.gold, game.player.inventory)
	assert_true(bool(buy_res["ok"]), "Player should be able to buy from Safe Room Vendor")
	game.set_menu_pause(false, "")
	assert_false(game.is_menu_paused)

	# 4. Every Audit Console command from docs/PLAYTEST_GUIDE.md executes cleanly
	assert_true(game.run_console_command("help").contains("teleport"))
	assert_true(game.run_console_command("status").contains("Floor 1"))
	assert_true(game.run_console_command("god").contains("ON"))
	assert_true(game.run_console_command("god").contains("OFF"))
	assert_true(game.run_console_command("camera").contains("third_person"))
	assert_true(game.run_console_command("add_xp 250").contains("Granted"))
	assert_true(game.run_console_command("seed").contains("424242"))
	assert_true(game.run_console_command("kill_boss").contains("unlocked"))
	assert_true(game.boss_defeated_this_floor)
	assert_true(game.run_console_command("collapse").contains("Floor-Entry Snapshot"))

