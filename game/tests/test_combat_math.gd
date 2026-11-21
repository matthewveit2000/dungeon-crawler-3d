extends GutTest
## Automated Tests for Skyrim Left/Right-Hand Combat Math, Blocking, Bows & Legendary Crits.


func test_skyrim_left_right_hand_equipping_rules() -> void:
	var sword := DataLoader.get_item_def("iron_longsword")
	var shield := DataLoader.get_item_def("nordic_kite_shield")
	var axe := DataLoader.get_item_def("iron_war_axe")
	var firebolt := DataLoader.get_item_def("spell_firebolt")

	var eq: Dictionary = {}
	eq = CombatMath.equip_item_in_slots(eq, sword, "right_hand")
	eq = CombatMath.equip_item_in_slots(eq, shield, "left_hand")
	assert_eq(str(eq["right_hand"]["id"]), "iron_longsword")
	assert_eq(str(eq["left_hand"]["id"]), "nordic_kite_shield")

	# Two-handed weapon clears left hand
	eq = CombatMath.equip_item_in_slots(eq, axe)
	assert_eq(str(eq["right_hand"]["id"]), "iron_war_axe")
	assert_false(eq.has("left_hand"), "Two-handed weapon must clear offhand")

	# Equipping spell into left hand un-equips two-handed weapon
	eq = CombatMath.equip_item_in_slots(eq, firebolt, "left_hand")
	assert_eq(str(eq["left_hand"]["id"]), "spell_firebolt")
	assert_false(eq.has("right_hand"), "Equipping offhand must clear active two-handed weapon")

	# Sword + Spell works cleanly
	eq = CombatMath.equip_item_in_slots(eq, sword, "right_hand")
	assert_eq(str(eq["right_hand"]["id"]), "iron_longsword")
	assert_eq(str(eq["left_hand"]["id"]), "spell_firebolt")


func test_armor_mitigation_is_asymptotic_and_capped() -> void:
	var pcfg := DataLoader.get_player()
	assert_almost_eq(CombatMath.compute_armor_mitigation(0.0, pcfg), 0.0, 0.001)
	assert_almost_eq(CombatMath.compute_armor_mitigation(80.0, pcfg), 0.5, 0.001)
	assert_almost_eq(CombatMath.compute_armor_mitigation(99999.0, pcfg), 0.8, 0.001)


func test_blocking_and_power_attacks_and_legendary_crits() -> void:
	var pcfg := DataLoader.get_player()
	var rng_a := SeededRng.new(55)
	var rng_b := SeededRng.new(55)

	var normal := CombatMath.resolve_attack({
		"base_damage": 30.0,
		"crit_chance": 0.0,
		"target_armor": 0.0,
		"target_blocking": false,
	}, pcfg, rng_a)

	var blocked := CombatMath.resolve_attack({
		"base_damage": 30.0,
		"crit_chance": 0.0,
		"target_armor": 0.0,
		"target_blocking": true,
		"target_block_bonus": 0.15,
	}, pcfg, rng_b)

	assert_lt(float(blocked["final_damage"]), float(normal["final_damage"]) * 0.4)
	assert_gt(float(blocked["block_stamina_cost"]), 0.0)

	var rng_c := SeededRng.new(55)
	var legendary_crit := CombatMath.resolve_attack({
		"base_damage": 30.0,
		"is_power_attack": true,
		"crit_chance": 0.99,
		"crit_multiplier": 1.65,
		"legendary_effects": ["explosive_crits"],
	}, pcfg, rng_c)
	assert_true(bool(legendary_crit["is_crit"]))
	assert_true(bool(legendary_crit["trigger_explosive_crits"]))
	assert_gt(float(legendary_crit["final_damage"]), 70.0)


func test_bow_draw_ratio_scales_smoothly() -> void:
	var pcfg := DataLoader.get_player()
	assert_almost_eq(CombatMath.compute_bow_draw_ratio(0.05, pcfg), 0.0, 0.001)
	assert_gt(CombatMath.compute_bow_draw_ratio(0.5, pcfg), 0.3)
	assert_almost_eq(CombatMath.compute_bow_draw_ratio(2.0, pcfg), 1.0, 0.001)
