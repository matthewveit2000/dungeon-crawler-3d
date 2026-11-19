extends GutTest
## Automated tests for Low-Friction Toggleable Tutorial Mode (D-030)
## and Hybrid Procedural + Handcrafted Setpiece World Builder (D-029).


func before_all() -> void:
	DataLoader.ensure_loaded()


func test_tutorial_first_time_triggers_and_auto_completes() -> void:
	var tut := TutorialSystem.new(DataLoader.get_tutorials_pack())
	assert_true(tut.enabled, "Tutorial mode starts enabled by default from tutorials.json")

	var first := tut.trigger_hint("movement_camera")
	assert_false(first.is_empty(), "First-time movement hint should display")
	assert_eq(str(first["id"]), "movement_camera")

	# Re-triggering an already seen topic should NOT annoy the player again
	var dup := tut.trigger_hint("movement_camera")
	assert_true(dup.is_empty(), "Already-seen topic must never re-trigger")

	# Queue a second topic while first is showing
	var queued := tut.trigger_hint("combat_hands")
	assert_true(queued.is_empty(), "Second hint queues cleanly without overwriting active card")

	# Completing first auto-advances queue to combat_hands
	assert_true(tut.complete_hint("movement_camera"))
	var active := tut.get_active_hint()
	assert_eq(str(active.get("id", "")), "combat_hands", "Completing active hint advances queued hint")
	assert_eq(int(active.get("completed_count", 0)), 1)


func test_tutorial_toggle_off_dismiss_reset_and_serialize() -> void:
	var tut := TutorialSystem.new(DataLoader.get_tutorials_pack())
	tut.trigger_hint("looting")
	assert_false(tut.get_active_hint().is_empty())

	# Pressing H / dismissing hides immediately
	tut.dismiss_current()
	assert_true(tut.get_active_hint().is_empty())

	# Toggling OFF suppresses future triggers completely
	tut.set_enabled(false)
	assert_true(tut.trigger_hint("safe_room").is_empty(), "Disabled tutorial mode suppresses hints")
	assert_true(tut.get_active_hint().is_empty())

	# Serialization round-trip preserves toggle & seen/completed state
	tut.set_enabled(true)
	tut.complete_hint("safe_room")
	var saved := tut.to_dict()
	var loaded := TutorialSystem.new(DataLoader.get_tutorials_pack())
	loaded.from_dict(saved)
	assert_true(loaded.enabled)
	assert_true(loaded.completed_ids.has("safe_room"))
	assert_true(loaded.trigger_hint("safe_room").is_empty(), "Loaded completed topic stays completed")

	# Reset allows experiencing tutorials again on demand
	loaded.reset_tutorials()
	assert_false(loaded.trigger_hint("safe_room").is_empty(), "Reset tutorials allow re-triggering")


func test_handcrafted_setpieces_pack_and_builder_integration() -> void:
	var sp_pack := DataLoader.get_setpieces_pack()
	var sp_map: Dictionary = sp_pack.get("setpieces", {})
	for required_key in ["entrance", "safe_room", "boss_arena", "vault", "stairs"]:
		assert_true(sp_map.has(required_key), "setpieces.json must define handcrafted setpiece '%s'" % required_key)
		var props: Array = sp_map[required_key].get("props", [])
		assert_gt(props.size(), 0, "Setpiece '%s' must contain curated props" % required_key)
		for p in props:
			var mpath := str(p.get("model", ""))
			assert_true(FileAccess.file_exists(mpath), "Setpiece model must exist on disk: %s" % mpath)

	# Build a real procedural + handcrafted floor and verify setpiece props spawn!
	var world_pack := DataLoader.get_world()
	var enemies_pack := DataLoader.get_enemies_pack()
	var layout := DungeonGenerator.generate(world_pack, enemies_pack, 1, 20261118)
	var builder := DungeonBuilder.new()
	add_child_autofree(builder)
	var rng := SeededRng.new(99911)
	builder.build_floor(layout, DataLoader.get_floor_config(1), func(_i: InteractableObject, _a: Node3D) -> bool: return true, rng)
	assert_gte(builder.spawned_setpiece_props, 15, "Handcrafted setpieces should place rich curated props across Entrance, Safe Room, Boss Arena, Vault & Stairs")
