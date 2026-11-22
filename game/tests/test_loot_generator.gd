extends GutTest
## Automated Tests for Inherent-Rarity Loot Rolling, No-Duplicate Pool & Stat Aggregation (D-060).


func test_legendary_loot_rolls_inherent_legendary_relic_with_effect() -> void:
	var items_pack := DataLoader.get_items_pack()
	var rarities_pack := DataLoader.get_rarities_pack()
	var rng := SeededRng.new(404)

	for i in range(10):
		var item := LootGenerator.roll_loot(items_pack, rarities_pack, 1, rng, "legendary", true)
		assert_eq(str(item["rarity"]), "legendary")
		assert_false(str(item.get("legendary_effect", "")).is_empty(), "Legendary loot must have a legendary_effect")
		assert_gt(int(item["value"]), 100)


func test_inherent_rarity_and_fixed_base_value_across_floors() -> void:
	var items_pack := DataLoader.get_items_pack()
	var rarities_pack := DataLoader.get_rarities_pack()

	var f1 := LootGenerator.roll_loot(items_pack, rarities_pack, 1, SeededRng.new(808), "rare", true, "long_dane_axe")
	var f4 := LootGenerator.roll_loot(items_pack, rarities_pack, 4, SeededRng.new(808), "rare", true, "long_dane_axe")
	assert_eq(str(f1["rarity"]), "rare")
	assert_eq(int(f1["value"]), int(f4["value"]), "D-060: fixed base value regardless of floor")
	assert_almost_eq(float(f1["damage"]), float(f4["damage"]), 0.01, "D-060: fixed base damage regardless of floor")
	assert_false(f1.has("affixes"), "D-060: no random affix rolls")


func test_aggregate_equipment_stats_sums_all_skyrim_slots() -> void:
	var eq := {
		"head": DataLoader.get_item_def("iron_horned_helm"),
		"chest": DataLoader.get_item_def("tattered_crawler_tunic"),
		"hands": DataLoader.get_item_def("thunderclap_gauntlets"),
		"ring": DataLoader.get_item_def("silver_focus_ring"),
		"amulet": DataLoader.get_item_def("bone_ward_amulet"),
	}
	var totals := LootGenerator.aggregate_equipment_stats(eq)
	# FB-022: worn items' level-1 passives count too (helm Iron Skin +2 armor, gauntlets Brutal +4 damage)
	assert_almost_eq(float(totals["armor"]), 42.0 + 2.0, 0.01)
	assert_almost_eq(float(totals["bonus_damage"]), 10.0 + 4.0, 0.01)
	assert_almost_eq(float(totals["bonus_health"]), 30.0, 0.01)
	assert_almost_eq(float(totals["bonus_magicka"]), 25.0, 0.01)
	assert_true(totals["legendary_effects"].has("explosive_crits"))
