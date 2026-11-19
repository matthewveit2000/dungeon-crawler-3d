extends GutTest
## Headless checks for the redesigned presentation layer: every menu opens and refreshes with live
## data, item comparison/sort/filter logic, map fog-of-war tracking, rigged characters expose their
## animation clips & weapon sockets, enemy corpses keep the animated body, chest lids open on loot.

const TEST_SAVE := "user://ui_visual_test_save.json"
var game: GameMain = null


func before_each() -> void:
	SnapshotManager.delete_save_file(TEST_SAVE)
	game = GameMain.new()
	game.run_seed = 515151
	game.auto_load_save_on_ready = false
	game.save_path = TEST_SAVE
	add_child_autofree(game)


func after_each() -> void:
	SnapshotManager.delete_save_file(TEST_SAVE)


func test_all_menus_open_refresh_and_close() -> void:
	game.run_console_command("spawn_loot sponsored")
	game.run_console_command("spawn_loot rare")
	for menu in ["inventory", "vendor", "map", "pause"]:
		game.open_exclusive_menu(menu)
		assert_true(game.is_menu_paused, "%s pauses the game (D-016)" % menu)
		assert_eq(game.active_menu_name, menu)
		game.close_all_menus()
		assert_false(game.is_menu_paused)
	game.open_exclusive_menu("inventory")
	game.inventory_menu._filter = "weapons"
	game.inventory_menu._sort = "rarity"
	game.inventory_menu.refresh()
	game.inventory_menu._tabs.current_tab = 1
	game.inventory_menu._show_tab(1)
	game.open_exclusive_menu("pause")
	game.pause_menu._show_section("settings")
	assert_true(game.pause_menu.is_settings_open(), "Settings panel opens inside pause")
	assert_true(game.pause_menu.back(), "Esc/back closes the sub-panel first")
	assert_false(game.pause_menu.is_settings_open())
	game.close_all_menus()


func test_inventory_unequip_and_vendor_sell_commons() -> void:
	var p := game.player
	var before := p.inventory.size()
	assert_true(p.equipment.has("left_hand"))
	assert_true(p.unequip_slot("left_hand"), "Unequip moves item to bag")
	assert_false(p.equipment.has("left_hand"))
	assert_eq(p.inventory.size(), before + 1)
	game.open_exclusive_menu("vendor")
	var gold_before := p.gold
	game.vendor_menu._sell_commons()
	assert_gt(p.gold, gold_before, "Sell All Common converts common gear to gold")
	for it in p.inventory:
		if str(it.get("rarity", "common")) == "common":
			assert_true(str(it.get("category", "")) == "consumable" or str(it.get("category", "")) == "spell", "Only consumables/spells remain common")


func test_item_info_comparison_sort_and_filters() -> void:
	var sword := LootGenerator.make_base_item_instance(DataLoader.get_item_def("iron_longsword"), "a")
	var better := sword.duplicate(true)
	better["instance_id"] = "b"
	better["damage"] = float(sword["damage"]) + 10.0
	var card := ItemInfo.build_card(better, sword)
	add_child_autofree(card)
	var texts: Array[String] = []
	var stack: Array[Node] = [card]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Label:
			texts.append((n as Label).text)
	var joined := " | ".join(texts)
	assert_string_contains(joined, "better", "Comparison marks the upgrade")
	assert_true(ItemInfo.matches_filter(sword, "weapons"))
	assert_false(ItemInfo.matches_filter(sword, "consumables"))
	var entries := [[0, {"name": "B", "rarity": "common", "value": 5}], [1, {"name": "A", "rarity": "epic", "value": 50}]]
	ItemInfo.sort_items(entries, "rarity")
	assert_eq(str(entries[0][1]["rarity"]), "epic")
	ItemInfo.sort_items(entries, "name")
	assert_eq(str(entries[0][1]["name"]), "A")


func test_map_fog_of_war_tracks_exploration_and_persists() -> void:
	game.step_simulation(0.05)
	assert_gt(game.map_seen.size(), 4, "Entrance room is inked on the map immediately")
	var seen_before := game.map_seen.size()
	game.run_console_command("teleport safe")
	game.step_simulation(0.05)
	assert_gt(game.map_seen.size(), seen_before, "Visiting the Safe Room reveals it")
	assert_true(game.save_current_session())
	var n := game.map_seen.size()
	game.map_seen.clear()
	assert_true(game.load_saved_session())
	assert_eq(game.map_seen.size(), n, "Explored map survives save & load")


func test_rigged_characters_expose_clips_and_sockets() -> void:
	for kind in ["crawler", "draugr", "bone_archer", "goblin_streamer", "iron_warden", "vendor"]:
		var cv := CharacterVisual.create(kind)
		add_child_autofree(cv)
		assert_not_null(cv.anim, "%s has an AnimationPlayer" % kind)
		assert_not_null(cv.skeleton, "%s has a Skeleton3D" % kind)
		for clip in ["idle", "walk", "run", "attack", "hit", "death"]:
			assert_true(cv.has_anim(clip), "%s has clip '%s'" % [kind, clip])
		assert_not_null(cv.model.find_child("GripR*", true, false), "%s exposes a right-hand weapon socket" % kind)
	var boss := CharacterVisual.create("iron_warden")
	add_child_autofree(boss)
	assert_true(boss.has_anim("roar") and boss.has_anim("slam"), "Boss has roar & slam")


func test_enemy_death_leaves_animated_lootable_body() -> void:
	var target: EnemyActor = null
	for c in game.enemies_root.get_children():
		if c is EnemyActor and not (c as EnemyActor).is_boss:
			target = c
			break
	assert_not_null(target)
	assert_not_null(target.visual, "Enemy uses a rigged CharacterVisual")
	var corpses := game.corpses_root.get_child_count()
	target.take_damage(99999.0)
	assert_eq(game.corpses_root.get_child_count(), corpses + 1)
	var corpse := game.corpses_root.get_child(game.corpses_root.get_child_count() - 1) as InteractableObject
	assert_not_null(corpse.visual_root, "Corpse keeps the fallen body")
	assert_true(corpse.visual_root is CharacterVisual)
	assert_eq((corpse.visual_root as CharacterVisual).oneshot, "death", "Death clip plays on the corpse")


func test_chest_lid_opens_when_looted() -> void:
	var chest: InteractableObject = null
	for c in game.dungeon_builder.get_child(0).get_children():
		if c is InteractableObject and (c as InteractableObject).kind == "chest":
			chest = c
			break
	assert_not_null(chest)
	var lid := chest.visual_root.find_child("Lid*", true, false) as Node3D
	assert_not_null(lid, "Chest model exports a separate hinged lid")
	assert_true(chest.trigger(game.player))
	await get_tree().create_timer(0.7).timeout
	assert_lt(lid.rotation.x, -1.0, "Lid swings open after looting")


func test_dungeon_is_dressed_and_lit() -> void:
	assert_gt(game.dungeon_builder.torch_count, 10, "Torches line the halls")
	assert_gt(game.dungeon_builder.spawned_dressing_props, 5, "Rooms receive procedural dressing")
	assert_not_null(game.dungeon_builder.environment_node, "Environment is built")
	var env := game.dungeon_builder.environment_node.environment
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX)
	var low := DungeonBuilder.build_environment(DataLoader.get_floor_config(1), 0)
	var high := DungeonBuilder.build_environment(DataLoader.get_floor_config(1), 2)
	assert_false(low.volumetric_fog_enabled, "Low quality skips volumetric fog")
	assert_true(high.volumetric_fog_enabled and high.ssao_enabled and high.ssil_enabled, "High quality enables fog, SSAO & SSIL")


func test_death_screen_appears_after_combat_death() -> void:
	game.reset_floor_to_snapshot("death")
	assert_true(game.death_screen.visible, "Death screen overlays the reset")
	assert_string_contains(game.death_screen._title.text, "FALLEN")


func test_death_screen_hides_hud_until_dismissed() -> void:
	assert_true(game.hud.visible)
	game.reset_floor_to_snapshot("death")
	assert_false(game.hud.visible, "HUD steps aside while the death card is up")
	game.death_screen.visible = false
	assert_true(game.hud.visible, "HUD returns when the card closes")


func test_hud_labels_both_hands_for_two_handed_weapons_and_bows() -> void:
	var p := game.player
	p.quick_equip_preset(2)
	p.emit_stats()
	assert_eq(game.hud._left_name.text, "Both hands", "Two-handed weapon occupies the off hand")
	assert_eq(game.hud._left_hint.text, "Two-handed grip")
	p.quick_equip_preset(4)
	p.emit_stats()
	assert_eq(game.hud._left_name.text, "Both hands", "Bow occupies the off hand")
	assert_string_contains(game.hud._right_hint.text, "draw")
	p.quick_equip_preset(1)
	p.emit_stats()
	assert_ne(game.hud._left_name.text, "Both hands", "Shield shows its own name again")
	assert_eq(game.hud._left_hint.text, "RMB  ·  Block")


func _force_size(ctrl: Control, sz: Vector2) -> void:
	# Pin the menu root to exactly 1280x720 regardless of the headless window size
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ctrl.size = sz


func _assert_fits(ctrl: Control, bounds: Rect2, what: String) -> void:
	var r := ctrl.get_global_rect()
	assert_true(r.position.x >= bounds.position.x - 1.0 and r.end.x <= bounds.end.x + 1.0 and r.end.y <= bounds.end.y + 1.0,
		"%s fits on a 1280x720 screen (rect %s)" % [what, r])


func test_menus_fit_a_720p_screen() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	game.run_console_command("spawn_loot sponsored")
	game.run_console_command("spawn_loot epic")
	game.open_exclusive_menu("inventory")
	_force_size(game.inventory_menu.root, bounds.size)
	for _i in range(4):
		await get_tree().process_frame
	_assert_fits(game.inventory_menu._inv_page, bounds, "Inventory columns")
	var tabs := game.inventory_menu._tabs
	assert_true(tabs.get_tab_rect(1).end.x <= tabs.size.x + 1.0, "Both character tabs are fully visible")
	game.open_exclusive_menu("pause")
	_force_size(game.pause_menu.root, bounds.size)
	for _i in range(4):
		await get_tree().process_frame
	_assert_fits(game.pause_menu._first_btn.get_parent() as Control, bounds, "Pause action column")
	game.pause_menu._show_section("settings")
	for _i in range(4):
		await get_tree().process_frame
	_assert_fits(game.pause_menu._settings, bounds, "Settings panel")
	game.close_all_menus()


func test_low_preset_skips_dust_motes_instead_of_zero_particles() -> void:
	var prev := VfxFactory.quality
	VfxFactory.quality = 0
	assert_null(VfxFactory.make_dust(Vector3(8, 3, 8)), "Low preset builds no dust emitter (a 0-particle emitter is an engine error)")
	VfxFactory.quality = 2
	var dust := VfxFactory.make_dust(Vector3(8, 3, 8))
	assert_not_null(dust)
	assert_gt(dust.amount, 0)
	dust.free()
	VfxFactory.quality = prev
