class_name LootGenerator
extends RefCounted
## Tier 2 Pure System: Inherent-Rarity Loot Rolling & No-Duplicate Gear Pool (D-049, D-060).
## Every item has one fixed inherent rarity and fixed base stats (no random affixes or floor_mult).
## Non-stackable items are pulled from the loot pool while owned; exhausted rarity pools step downward
## (never upward) and fall back to stackable consumables/ingredients when no eligible gear remains.


static func make_base_item_instance(item_def: Dictionary, instance_id: String = "") -> Dictionary:
	var inst := item_def.duplicate(true)
	inst["instance_id"] = instance_id if not instance_id.is_empty() else str(item_def["id"])
	var r_id := str(item_def.get("rarity", "common"))
	var r_def := RarityTable.get_rarity({}, r_id)
	inst["rarity"] = r_id
	inst["rarity_label"] = str(r_def.get("label", r_id.capitalize()))
	inst["rarity_color"] = str(r_def.get("color", "#d8dce3"))
	inst["value"] = RarityTable.compute_item_value(item_def)
	if MasterySystem.is_masterable(inst):
		inst["mastery_level"] = 1
		inst["mastery_xp"] = 0.0
	return inst


## Returns {item_id: true} for every non-stackable item currently equipped or in the player's bag.
static func collect_owned_non_stackable_ids(equipment: Dictionary, inventory: Array) -> Dictionary:
	var owned: Dictionary = {}
	for item in equipment.values():
		if typeof(item) == TYPE_DICTIONARY and not (item as Dictionary).is_empty() and not InventoryStacks.is_stackable(item):
			owned[str(item.get("id", ""))] = true
	for item in inventory:
		if typeof(item) == TYPE_DICTIONARY and not (item as Dictionary).is_empty() and not InventoryStacks.is_stackable(item):
			owned[str(item.get("id", ""))] = true
	owned.erase("")
	return owned


static func roll_loot(
	items_pack: Dictionary,
	rarities_pack: Dictionary,
	floor_number: int,
	rng: SeededRng,
	forced_rarity: String = "",
	exclude_consumables: bool = false,
	forced_item_id: String = "",
	source_profile: String = "",
	excluded_ids: Dictionary = {}
) -> Dictionary:
	var all_items: Array = items_pack.get("items", [])
	if all_items.is_empty():
		return {}

	if not forced_item_id.is_empty():
		for item in all_items:
			if str(item.get("id", "")) == forced_item_id:
				var uid := "%s_%d" % [forced_item_id, rng.next_int_range("loot", 10000, 999999)]
				return make_base_item_instance(item, uid)
		return {}

	var rar_pack := rarities_pack if not rarities_pack.is_empty() else (DataLoader.get_rarities_pack() if DataLoader != null else {})
	var by_rarity: Dictionary = {}
	var stackables_by_rarity: Dictionary = {}

	for item in all_items:
		var iid := str(item.get("id", ""))
		var r := str(item.get("rarity", "common"))
		if InventoryStacks.is_stackable(item):
			if not stackables_by_rarity.has(r):
				stackables_by_rarity[r] = []
			(stackables_by_rarity[r] as Array).append(item)
			if exclude_consumables:
				continue
		elif excluded_ids.has(iid):
			# D-060: Owned non-stackables are pulled from the pool
			continue
		if not by_rarity.has(r):
			by_rarity[r] = []
		(by_rarity[r] as Array).append(item)

	var order := RarityTable.rarity_order(rar_pack)
	var chosen_rarity: Dictionary = RarityTable.pick_rarity(rar_pack, floor_number, rng, forced_rarity, source_profile, [], "loot")
	var target_r := str(chosen_rarity.get("id", "common"))
	var target_idx := order.find(target_r)
	if target_idx < 0:
		target_idx = 0

	# Try target rarity; if empty (all items of that tier already owned), step downward — never upward.
	var picked_pool: Array = []
	for idx in range(target_idx, -1, -1):
		var r_id := str(order[idx])
		var cand: Array = by_rarity.get(r_id, [])
		if not cand.is_empty():
			picked_pool = cand
			break

	# If no unowned non-stackables exist at target_r or below, fall back to a stackable consumable/ingredient.
	if picked_pool.is_empty():
		for idx in range(target_idx, -1, -1):
			var r_id := str(order[idx])
			var sc: Array = stackables_by_rarity.get(r_id, [])
			if not sc.is_empty():
				picked_pool = sc
				break
	if picked_pool.is_empty():
		for r_id in order:
			var sc: Array = stackables_by_rarity.get(str(r_id), [])
			if not sc.is_empty():
				picked_pool = sc
				break
	if picked_pool.is_empty():
		return {}

	var base_def: Dictionary = rng.pick_array("loot", picked_pool)
	var uid2 := "%s_%d" % [str(base_def["id"]), rng.next_int_range("loot", 10000, 999999)]
	return make_base_item_instance(base_def, uid2)


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
