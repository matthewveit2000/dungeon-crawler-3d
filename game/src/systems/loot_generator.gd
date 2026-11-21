class_name LootGenerator
extends RefCounted
## Tier 2 Pure System: Rolls rarity-scaled gear, prefixes/suffixes, and legendary effects, plus aggregates
## Skyrim equipment-slot stats for the player.


static func make_base_item_instance(item_def: Dictionary, instance_id: String = "") -> Dictionary:
	var inst := item_def.duplicate(true)
	inst["instance_id"] = instance_id if not instance_id.is_empty() else str(item_def["id"])
	inst["rarity"] = str(item_def.get("forced_rarity", "common"))
	inst["affixes"] = []
	inst["value"] = int(item_def.get("base_value", 20))
	if MasterySystem.is_masterable(inst):
		inst["mastery_level"] = 1
		inst["mastery_xp"] = 0.0
	return inst


## Rarities the world may drop right now (D-049: Common only until higher-rarity loot is designed).
static func enabled_rarities(affixes_pack: Dictionary) -> Array:
	return RarityTable.enabled_rarities(affixes_pack)


## The rarity a world drop actually rolls at: a requested tier that is not enabled yet falls back to the best
## enabled one (so vaults and bosses still work, just Common for now).
static func world_rarity(affixes_pack: Dictionary, requested: String) -> String:
	return RarityTable.world_rarity(affixes_pack, requested)


static func roll_loot(
	items_pack: Dictionary,
	affixes_pack: Dictionary,
	floor_number: int,
	rng: SeededRng,
	forced_rarity: String = "",
	exclude_consumables: bool = false,
	forced_item_id: String = ""
) -> Dictionary:
	var candidates: Array = []
	for item in items_pack.get("items", []):
		if not forced_item_id.is_empty():
			if str(item.get("id", "")) == forced_item_id:
				candidates.append(item)
			continue
		if exclude_consumables and InventoryStacks.is_stackable(item):
			continue
		# Reserve the unique legendary relics for legendary rolls
		if str(item.get("forced_rarity", "")) == "legendary" and forced_rarity != "legendary":
			continue
		if int(item.get("floor_min", 1)) > floor_number:
			continue
		candidates.append(item)
	if candidates.is_empty():
		return {}

	var chosen_rarity: Dictionary = RarityTable.pick_rarity(affixes_pack, floor_number, rng, forced_rarity)

	# On a legendary roll, 50% chance to pick a named legendary relic if available
	var base_def: Dictionary = {}
	if str(chosen_rarity["id"]) == "legendary" and forced_item_id.is_empty():
		var uniques: Array = []
		for item in items_pack.get("items", []):
			if str(item.get("forced_rarity", "")) == "legendary":
				uniques.append(item)
		if not uniques.is_empty() and rng.next_float("loot") < 0.5:
			base_def = rng.pick_array("loot", uniques)
	if base_def.is_empty():
		# D-049: every item has its own drop weight, so some finds are everyday and some are rare discoveries
		var wc: Array = []
		for c in candidates:
			var cc: Dictionary = c.duplicate()
			cc["_w"] = RarityTable.effective_item_drop_weight(c, affixes_pack)
			wc.append(cc)
		var pick: Dictionary = rng.pick_weighted("loot", wc, "_w")
		base_def = DataLoader.get_item_def(str(pick["id"])) if not DataLoader.get_item_def(str(pick["id"])).is_empty() else pick

	var uid := "%s_%d" % [str(base_def["id"]), rng.next_int_range("loot", 10000, 999999)]
	var inst := make_base_item_instance(base_def, uid)
	if InventoryStacks.is_stackable(base_def):
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

	# Legendary rolls always carry a game-changing legendary_effect
	if r_id == "legendary" and str(inst.get("legendary_effect", "")).is_empty():
		var effs: Array = affixes_pack.get("legendary_effects", [])
		if not effs.is_empty():
			var chosen_eff: Dictionary = rng.pick_array("loot", effs)
			inst["legendary_effect"] = str(chosen_eff["id"])
			inst["legendary_label"] = str(chosen_eff["label"])

	if str(base_def.get("forced_rarity", "")) != "legendary":
		var base_name := str(base_def["name"])
		var full_name := base_name
		if not prefix_label.is_empty():
			full_name = "%s %s" % [prefix_label, full_name]
		if not suffix_label.is_empty():
			full_name = "%s %s" % [full_name, suffix_label]
		inst["name"] = full_name

	inst["value"] = RarityTable.compute_item_value(float(base_def.get("base_value", 25)), chosen_rarity, floor_mult)
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
		"legendary_effects": [],
	}
	var worn: Array = []
	for slot in equipment.keys():
		var item: Variant = equipment[slot]
		if typeof(item) != TYPE_DICTIONARY or item.is_empty():
			continue
		# D-049: mastery grows an item's core stats
		totals["armor"] += MasterySystem.stat(item, "armor")
		totals["bonus_damage"] += MasterySystem.stat(item, "bonus_damage")
		totals["bonus_health"] += MasterySystem.stat(item, "bonus_health")
		totals["bonus_magicka"] += MasterySystem.stat(item, "bonus_magicka")
		totals["bonus_stamina"] += MasterySystem.stat(item, "bonus_stamina")
		totals["bonus_crit_chance"] += float(item.get("bonus_crit_chance", 0.0))
		totals["cooldown_reduction"] = minf(0.45, float(totals["cooldown_reduction"]) + float(item.get("cooldown_reduction", 0.0)))
		totals["gold_find_bonus"] += float(item.get("gold_find_bonus", 0.0))
		totals["block_bonus"] += float(item.get("block_bonus", 0.0))
		if not str(slot).ends_with("_hand"):
			worn.append(item)
		var se := DataLoader.current_id(str(item.get("legendary_effect", "")))
		if not se.is_empty() and not totals["legendary_effects"].has(se):
			totals["legendary_effects"].append(se)
	# Passive mastery abilities of worn armor & accessories (D-049)
	var pas := MasterySystem.aggregate_passives(worn)
	totals["passives"] = pas
	totals["armor"] += float(pas.get("iron_skin", {}).get("armor", 0.0))
	totals["bonus_damage"] += float(pas.get("brutal", {}).get("damage", 0.0))
	totals["bonus_crit_chance"] += float(pas.get("keen_eye", {}).get("crit", 0.0))
	totals["cooldown_reduction"] = minf(0.45, float(totals["cooldown_reduction"]) + float(pas.get("quickness", {}).get("cooldown", 0.0)))
	totals["gold_find_bonus"] += float(pas.get("treasure", {}).get("gold", 0.0))
	return totals


static func _filter_affixes(pool: Array, category: String) -> Array:
	var out: Array = []
	for a in pool:
		var applies: Array = a.get("applies_to", [])
		if applies.has(category):
			out.append(a)
	return out
