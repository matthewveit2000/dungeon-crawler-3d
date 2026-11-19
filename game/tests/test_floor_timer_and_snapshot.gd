extends GutTest
## Automated Tests for 5-Day Floor Timer (D-006), Menu Pause (D-016),
## Floor-Entry Snapshot Reset (D-014, D-018), and Save-and-Quit Persistence (D-017).

const TEST_SAVE_PATH := "user://test_save_roundtrip.json"


func after_each() -> void:
	SnapshotManager.delete_save_file(TEST_SAVE_PATH)


func test_5_day_timer_pauses_cleanly_and_collapses_at_zero() -> void:
	var timer := FloorTimer.new(DataLoader.get_world()["floor_timer"])
	assert_almost_eq(timer.get_days_remaining(), 5.0, 0.001)
	assert_eq(timer.get_current_day_number(), 1)

	# Menu pause must completely freeze countdown
	var paused_res := timer.tick(600.0, true)
	assert_almost_eq(timer.get_days_remaining(), 5.0, 0.001)
	assert_false(bool(paused_res["collapsed_now"]))

	# Advancing 2.5 days triggers the 3.0-day warning threshold
	var warn_res := timer.advance_days(2.5)
	assert_almost_eq(float(warn_res["warning_days_left"]), 3.0, 0.01)
	assert_eq(timer.get_current_day_number(), 3)

	# Advancing remaining 2.5 days triggers collapse
	var col_res := timer.advance_days(2.5)
	assert_true(bool(col_res["collapsed_now"]))
	assert_true(timer.collapsed)
	assert_almost_eq(timer.remaining_seconds, 0.0, 0.001)


func test_floor_entry_snapshot_restores_pre_floor_state_and_drops_failed_attempt_loot() -> void:
	var sm := SnapshotManager.new()
	var entry_state := {
		"floor_number": 2,
		"run_seed": 9991,
		"gold": 120,
		"equipment": {"right_hand": {"id": "iron_longsword"}},
		"inventory": [{"id": "health_potion"}],
		"progression": {"level": 3, "xp": 45.0},
	}
	sm.capture_floor_entry_snapshot(entry_state)

	# Mutate live state as if player picked up mid-floor gear & leveled up, then died / collapsed
	entry_state["gold"] = 999
	entry_state["inventory"].append({"id": "sponsored_blade_ratings"})
	entry_state["progression"]["level"] = 5

	var restored := sm.restore_floor_entry_snapshot()
	assert_eq(int(restored["gold"]), 120, "Snapshot must restore pre-floor gold")
	assert_eq(restored["inventory"].size(), 1, "Snapshot must discard loot found during failed floor attempt")
	assert_eq(int(restored["progression"]["level"]), 3, "Snapshot must restore floor-entry level")


func test_save_and_quit_round_trip_preserves_mid_floor_position_timer_and_snapshot() -> void:
	var sm := SnapshotManager.new()
	sm.capture_floor_entry_snapshot({
		"floor_number": 1,
		"run_seed": 54321,
		"gold": 75,
		"equipment": {},
		"inventory": [],
		"progression": {"level": 1},
	})
	var session := {
		"floor_number": 1,
		"run_seed": 54321,
		"player_pos": [12.5, 0.0, 28.0],
		"player_yaw": 1.25,
		"gold": 210,
		"timer": {"remaining_seconds": 4321.5, "collapsed": false, "triggered_warnings": [3.0]},
		"boss_defeated": true,
	}
	assert_true(sm.save_session_to_file(session, TEST_SAVE_PATH))

	var sm2 := SnapshotManager.new()
	var loaded := sm2.load_session_from_file(TEST_SAVE_PATH)
	assert_eq(int(loaded["gold"]), 210)
	assert_almost_eq(float(loaded["timer"]["remaining_seconds"]), 4321.5, 0.01)
	assert_true(bool(loaded["boss_defeated"]))
	assert_eq(int(sm2.restore_floor_entry_snapshot()["gold"]), 75, "Floor-entry snapshot must survive Save-and-Quit")
