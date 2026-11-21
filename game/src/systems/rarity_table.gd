class_name RarityTable
extends RefCounted
## Tier 2 Pure System: Unified Rarity & Scarcity Table (D-048, D-049, D-055 / IDEA-011).
## Centralizes rarity definitions, drop/spawn weight resolution, floor scaling, and value multipliers
## across LootGenerator, VendorSystem, and future enemy/item scarcity pools.


## Returns the list of rarity definitions from either a dedicated rarities pack or a legacy affixes pack.
static func rarities_from(pack: Dictionary) -> Array:
	var arr: Array = pack.get("rarities", [])
	if not arr.is_empty():
		return arr
	if DataLoader != null:
		return DataLoader.get_rarities_pack().get("rarities", [])
	return []


## Rarities currently enabled for world drops (D-049: Common only until higher-rarity uniques are rolled out).
static func enabled_rarities(pack: Dictionary) -> Array:
	var en: Array = pack.get("loot_rarities_enabled", [])
	if en.is_empty() and DataLoader != null and pack.get("rarities", []).is_empty():
		en = DataLoader.get_rarities_pack().get("loot_rarities_enabled", [])
	if en.is_empty():
		for r in rarities_from(pack):
			en.append(str(r["id"]))
	return en


## Resolves a requested rarity against enabled world rarities (falls back to the highest enabled tier).
static func world_rarity(pack: Dictionary, requested: String) -> String:
	var en := enabled_rarities(pack)
	if requested.is_empty() or en.has(requested):
		return requested
	return str(en[-1]) if not en.is_empty() else "common"


## Looks up a single rarity definition by id.
static func get_rarity(pack: Dictionary, rarity_id: String) -> Dictionary:
	for r in rarities_from(pack):
		if str(r.get("id", "")) == rarity_id:
			return r
	return {}


## Picks a rarity definition deterministically (exact same weighting & RNG stream as LootGenerator).
static func pick_rarity(pack: Dictionary, floor_number: int, rng: SeededRng, forced_rarity: String = "") -> Dictionary:
	var rarities := rarities_from(pack)
	if not forced_rarity.is_empty():
		for r in rarities:
			if str(r["id"]) == forced_rarity:
				return r
	var weighted: Array = []
	var en := enabled_rarities(pack)
	for r in rarities:
		if not en.has(str(r["id"])):
			continue
		var copy: Dictionary = r.duplicate()
		var mult := float(r.get("stat_multiplier", 1.0))
		if mult > 1.0:
			copy["weight"] = float(copy["weight"]) * (1.0 + float(maxi(0, floor_number - 1)) * 0.25)
		weighted.append(copy)
	if weighted.is_empty():
		return {}
	return rng.pick_weighted("loot", weighted, "weight")


## Computes item gold value from base value, rarity multiplier, and floor multiplier.
static func compute_item_value(base_value: float, rarity_def: Dictionary, floor_mult: float) -> int:
	return int(round(base_value * float(rarity_def.get("value_multiplier", 1.0)) * floor_mult))


## Effective drop weight for an item entry (respects optional per-item rarity scarcity multiplier).
static func effective_item_drop_weight(item_def: Dictionary, pack: Dictionary = {}) -> float:
	var base_w := float(item_def.get("drop_weight", 10.0))
	var explicit_r := str(item_def.get("rarity_tier", ""))
	if explicit_r.is_empty():
		return base_w
	var rdef := get_rarity(pack, explicit_r)
	if rdef.is_empty():
		return base_w
	return base_w * (float(rdef.get("weight", 54.0)) / 54.0)


## Effective spawn weight for an enemy definition (neutral 1.0 when enemy has no explicit rarity tag).
static func effective_enemy_spawn_weight(enemy_def: Dictionary, pack: Dictionary = {}) -> float:
	var base_w := float(enemy_def.get("spawn_weight", 0.0))
	var er := str(enemy_def.get("rarity", ""))
	if er.is_empty():
		return base_w
	var rdef := get_rarity(pack, er)
	if rdef.is_empty():
		return base_w
	return base_w * float(rdef.get("enemy_spawn_weight_mult", 1.0))


## Reward multiplier for an enemy definition based on its rarity tag (1.0 if untagged / common).
static func enemy_reward_multiplier(enemy_def: Dictionary, pack: Dictionary = {}) -> float:
	var er := str(enemy_def.get("rarity", ""))
	if er.is_empty():
		return 1.0
	var rdef := get_rarity(pack, er)
	return float(rdef.get("enemy_reward_mult", 1.0)) if not rdef.is_empty() else 1.0
