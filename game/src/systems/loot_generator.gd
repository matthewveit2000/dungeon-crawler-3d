class_name LootGenerator
extends RefCounted
## Tier 2 Pure System: Rolls rarity-scaled gear, prefixes/suffixes, and absurd Sponsored/Mythic
## effects, plus aggregates Skyrim equipment-slot stats for the player.


static func make_base_item_instance(item_def: Dictionary, instance_id: String = "") -> Dictionary:
	var inst := item_def.duplicate(true)
	inst["instance_id"] = instance_id if not instance_id.is_empty() else str(item_def["id"])
	inst["rarity"] = str(item_def.get("forced_rarity", "common"))
	inst["affixes"] = []
	inst["value"] = int(item_def.get("base_value", 20))
	return inst


static func roll_loot(
	items_pack: Dictionary,
	affixes_pack: Dictionary,
	floor_number: int,
	rng: SeededRng,
	forced_rarity: String = "",
	exclude_consumables: bool = false
) -> Dictionary:
	var candidates: Array = []
	for item in items_pack.get("items", []):
		if exclude_consumables and str(item.get("category", "")) == "consumable":
			continue
		# Reserve unique forced-sponsored items for sponsored rolls
		if str(item.get("forced_rarity", "")) == "sponsored" and forced_rarity != "sponsored":
			continue
		candidates.append(item)
	if candidates.is_empty():
		return {}

	var rarities: Array = affixes_pack.get("rarities", [])
	var chosen_rarity: Dictionary = {}
	if not forced_rarity.is_empty():
		for r in rarities:
			if str(r["id"]) == forced_rarity:
				chosen_rarity = r
				break
	if chosen_rarity.is_empty():
		# Shift weights modestly upward on deeper floors
		var weighted: Array = []
		for r in rarities:
			var copy: Dictionary = r.duplicate()
			var mult := float(r.get("stat_multiplier", 1.0))
			if mult > 1.0:
				copy["weight"] = float(copy["weight"]) * (1.0 + float(maxi(0, floor_number - 1)) * 0.25)
			weighted.append(copy)
		chosen_rarity = rng.pick_weighted("loot", weighted, "weight")

	# On Sponsored roll, 50% chance to pick a named Sponsored unique if available
	var base_def: Dictionary = {}
	if str(chosen_rarity["id"]) == "sponsored":
		var uniques: Array = []
		for item in items_pack.get("items", []):
			if str(item.get("forced_rarity", "")) == "sponsored":
				uniques.append(item)
		if not uniques.is_empty() and rng.next_float("loot") < 0.5:
			base_def = rng.pick_array("loot", uniques)
	if base_def.is_empty():
		base_def = rng.pick_array("loot", candidates)

	var uid := "%s_%d" % [str(base_def["id"]), rng.next_int_range("loot", 10000, 999999)]
	var inst := make_base_item_instance(base_def, uid)
	if str(base_def.get("category", "")) == "consumable":
		return inst

	var r_id := str(chosen_rarity["id"])
	var stat_mult := float(chosen_rarity["stat_multiplier"])
	var floor_mult := 1.0 + float(maxi(0, floor_number - 1)) * 0.14
	var total_mult := stat_mult * floor_mult

	inst["rarity"] = r_id
	inst["rarity_label"] = str(chosen_rarity["label"])
	inst["rarity_color"] = str(chosen_rarity["color"])
	if inst.has("damage"):
		inst["damage"] = snappedf(float(inst["damage"]) * total_mult, 0.1)
	if inst.has("armor"):
		inst["armor"] = snappedf(float(inst["armor"]) * total_mult, 0.1)
	if inst.has("heal_amount"):
		inst["heal_amount"] = snappedf(float(inst["heal_amount"]) * total_mult, 0.1)

	var affix_budget := int(chosen_rarity.get("affix_count", 0))
	var cat := str(base_def.get("category", ""))
	var used_affix_ids: Dictionary = {}
	var prefix_label := ""
	var suffix_label := ""

	var prefixes := _filter_affixes(affixes_pack.get("prefixes", []), cat)
	var suffixes := _filter_affixes(affixes_pack.get("suffixes", []), cat)

	for slot_idx in range(affix_budget):
		var pool := prefixes if (slot_idx % 2 == 0 and not prefixes.is_empty()) else suffixes
		if pool.is_empty():
			pool = prefixes if not prefixes.is_empty() else suffixes
		if pool.is_empty():
			break
		var picked: Dictionary = rng.pick_array("loot", pool)
		var aid := str(picked["id"])
		if used_affix_ids.has(aid):
			continue
		used_affix_ids[aid] = true
		var val := snappedf(rng.next_float_range("loot", float(picked["min"]), float(picked["max"])) * floor_mult, 0.01)
		var stat_key := str(picked["stat"])
		inst[stat_key] = float(inst.get(stat_key, 0.0)) + val
		inst["affixes"].append({"id": aid, "label": str(picked["label"]), "stat": stat_key, "value": val})
		if slot_idx == 0 and pool == prefixes and prefix_label.is_empty():
			prefix_label = str(picked["label"])
		elif pool == suffixes and suffix_label.is_empty():
			suffix_label = str(picked["label"])

	# Sponsored/Mythic rolls always carry a game-changing sponsored_effect
	if r_id == "sponsored" and str(inst.get("sponsored_effect", "")).is_empty():
		var effs: Array = affixes_pack.get("sponsored_effects", [])
		if not effs.is_empty():
			var chosen_eff: Dictionary = rng.pick_array("loot", effs)
			inst["sponsored_effect"] = str(chosen_eff["id"])
			inst["sponsored_label"] = str(chosen_eff["label"])

	if str(base_def.get("forced_rarity", "")) != "sponsored":
		var base_name := str(base_def["name"])
		var full_name := base_name
		if not prefix_label.is_empty():
			full_name = "%s %s" % [prefix_label, full_name]
		if not suffix_label.is_empty():
			full_name = "%s %s" % [full_name, suffix_label]
		if r_id == "sponsored":
			full_name = "Sponsored: %s" % full_name
		inst["name"] = full_name

	inst["value"] = int(round(float(base_def.get("base_value", 25)) * float(chosen_rarity.get("value_multiplier", 1.0)) * floor_mult))
	return inst


static func aggregate_equipment_stats(equipment: Dictionary) -> Dictionary:
	var totals := {
		"armor": 0.0,
		"bonus_damage": 0.0,
		"bonus_health": 0.0,
		"bonus_magicka": 0.0,
		"bonus_stamina": 0.0,
		"bonus_crit_chance": 0.0,
		"cooldown_reduction": 0.0,
		"gold_find_bonus": 0.0,
		"block_bonus": 0.0,
		"sponsored_effects": [],
	}
	for slot in equipment.keys():
		var item: Variant = equipment[slot]
		if typeof(item) != TYPE_DICTIONARY or item.is_empty():
			continue
		totals["armor"] += float(item.get("armor", 0.0))
		totals["bonus_damage"] += float(item.get("bonus_damage", 0.0))
		totals["bonus_health"] += float(item.get("bonus_health", 0.0))
		totals["bonus_magicka"] += float(item.get("bonus_magicka", 0.0))
		totals["bonus_stamina"] += float(item.get("bonus_stamina", 0.0))
		totals["bonus_crit_chance"] += float(item.get("bonus_crit_chance", 0.0))
		totals["cooldown_reduction"] = minf(0.45, float(totals["cooldown_reduction"]) + float(item.get("cooldown_reduction", 0.0)))
		totals["gold_find_bonus"] += float(item.get("gold_find_bonus", 0.0))
		totals["block_bonus"] += float(item.get("block_bonus", 0.0))
		var se := str(item.get("sponsored_effect", ""))
		if not se.is_empty() and not totals["sponsored_effects"].has(se):
			totals["sponsored_effects"].append(se)
	return totals


static func _filter_affixes(pool: Array, category: String) -> Array:
	var out: Array = []
	for a in pool:
		var applies: Array = a.get("applies_to", [])
		if applies.has(category):
			out.append(a)
	return out
