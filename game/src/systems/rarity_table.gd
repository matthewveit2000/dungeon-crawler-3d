class_name RarityTable
extends RefCounted
## Tier 2 Pure System: Unified Inherent Rarity & Scarcity Table (D-048, D-055, D-060).
## Single source of truth for all procedurally generated things: items, enemies, rooms,
## chest tiers, traps, architecture variants, and dressing props.
## Drives spawn weights, deeper-floor rarity scaling, mastery ceilings, ability caps, and enemy rewards.

const DEFAULT_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]


static func rarities_from(pack: Dictionary = {}) -> Array:
	var arr: Array = pack.get("rarities", [])
	if not arr.is_empty():
		return arr
	if DataLoader != null:
		return DataLoader.get_rarities_pack().get("rarities", [])
	return []


static func rarity_order(pack: Dictionary = {}) -> Array:
	var ord: Array = pack.get("rarity_order", [])
	if not ord.is_empty():
		return ord
	if DataLoader != null:
		ord = DataLoader.get_rarities_pack().get("rarity_order", [])
		if not ord.is_empty():
			return ord
	return DEFAULT_ORDER


static func get_rarity(pack: Dictionary, rarity_id: String) -> Dictionary:
	for r in rarities_from(pack):
		if str(r.get("id", "")) == rarity_id:
			return r
	return {}


static func rarity_rank(rarity_id: String, pack: Dictionary = {}) -> int:
	var rdef := get_rarity(pack, rarity_id)
	if not rdef.is_empty() and rdef.has("rank"):
		return int(rdef["rank"])
	var idx := rarity_order(pack).find(rarity_id)
	return idx if idx >= 0 else 0


## Weight of a rarity tier on `floor_number` under an optional `source_profile` (from rarities.json).
## Deeper floors boost higher rarities via `floor_weight_growth`.
static func rarity_weight_for_floor(rdef: Dictionary, floor_number: int, source_profile: Dictionary = {}, pack: Dictionary = {}) -> float:
	if rdef.is_empty():
		return 0.0
	var rank := int(rdef.get("rank", rarity_rank(str(rdef.get("id", "common")), pack)))
	var min_r := str(source_profile.get("min_rarity", ""))
	if not min_r.is_empty() and rank < rarity_rank(min_r, pack):
		return 0.0
	var base_w := float(rdef.get("weight", 1.0))
	var growth := float(rdef.get("floor_weight_growth", 0.0))
	var w := base_w * (1.0 + growth * float(maxi(0, floor_number - 1)))
	var boost := float(source_profile.get("rarity_boost", 1.0))
	if boost > 1.0 and rank > 0:
		w *= pow(boost, float(rank))
	return maxf(0.0, w)


static func source_profile(pack: Dictionary, source_name: String) -> Dictionary:
	if source_name.is_empty():
		return {}
	var p := pack
	if p.is_empty() and DataLoader != null:
		p = DataLoader.get_rarities_pack()
	return (p.get("source_profiles", {}) as Dictionary).get(source_name, {})


## Picks a rarity definition deterministically for `floor_number`, optionally filtered to `allowed_rarities`
## or boosted by `source_name` ("standard", "rare", "vault_legendary", "champion", "boss", "vendor", ...).
static func pick_rarity(
	pack: Dictionary,
	floor_number: int,
	rng: SeededRng,
	forced_rarity: String = "",
	source_name: String = "",
	allowed_rarities: Array = [],
	stream: String = "loot"
) -> Dictionary:
	var rarities := rarities_from(pack)
	if not forced_rarity.is_empty():
		for r in rarities:
			if str(r["id"]) == forced_rarity:
				return r
	var prof := source_profile(pack, source_name)
	var weighted: Array = []
	for r in rarities:
		var rid := str(r["id"])
		if not allowed_rarities.is_empty() and not allowed_rarities.has(rid):
			continue
		var w := rarity_weight_for_floor(r, floor_number, prof, pack)
		if w <= 0.0:
			continue
		var copy: Dictionary = r.duplicate()
		copy["weight"] = w
		weighted.append(copy)
	if weighted.is_empty():
		# Fallback ignoring source min_rarity if allowed_rarities excluded everything above it
		for r in rarities:
			var rid := str(r["id"])
			if not allowed_rarities.is_empty() and not allowed_rarities.has(rid):
				continue
			var copy: Dictionary = r.duplicate()
			copy["weight"] = rarity_weight_for_floor(r, floor_number, {}, pack)
			weighted.append(copy)
	if weighted.is_empty():
		return rarities[0] if not rarities.is_empty() else {}
	return rng.pick_weighted(stream, weighted, "weight")


## Picks an entry from `entries` (each having a `"rarity"` field) by first rolling a rarity tier from
## `rarities.json` (across rarities present in `entries`) and then picking uniformly inside that tier.
## This ensures tier odds match `rarities.json` regardless of how many items/enemies/rooms sit in each tier.
static func pick_entry_by_rarity(
	entries: Array,
	floor_number: int,
	rng: SeededRng,
	stream: String = "gen",
	pack: Dictionary = {},
	source_name: String = ""
) -> Dictionary:
	if entries.is_empty():
		return {}
	if pack.is_empty() and DataLoader != null:
		pack = DataLoader.get_rarities_pack()
	var by_rarity: Dictionary = {}
	for e in entries:
		var er := str((e as Dictionary).get("rarity", "common"))
		if not by_rarity.has(er):
			by_rarity[er] = []
		(by_rarity[er] as Array).append(e)
	var chosen := pick_rarity(pack, floor_number, rng, "", source_name, by_rarity.keys(), stream)
	var pool: Array = by_rarity.get(str(chosen.get("id", "")), [])
	if pool.is_empty():
		return entries[0]
	return rng.pick_array(stream, pool)


## Effective spawn weight of a rarity-tagged entry (for tests or weighted inspection).
static func effective_spawn_weight(entry_def: Dictionary, floor_number: int = 1, pack: Dictionary = {}, source_name: String = "") -> float:
	if pack.is_empty() and DataLoader != null:
		pack = DataLoader.get_rarities_pack()
	var er := str(entry_def.get("rarity", "common"))
	var rdef := get_rarity(pack, er)
	if rdef.is_empty():
		return 1.0
	return rarity_weight_for_floor(rdef, floor_number, source_profile(pack, source_name), pack)


## Effective spawn weight for an enemy definition (returns 0 for bosses unless requested).
static func effective_enemy_spawn_weight(enemy_def: Dictionary, pack: Dictionary = {}, floor_number: int = 1) -> float:
	if bool(enemy_def.get("is_boss", false)):
		return 0.0
	return effective_spawn_weight(enemy_def, floor_number, pack)


## Reward multiplier for an enemy definition based on its rarity tag.
static func enemy_reward_multiplier(enemy_def: Dictionary, pack: Dictionary = {}) -> float:
	if pack.is_empty() and DataLoader != null:
		pack = DataLoader.get_rarities_pack()
	var er := str(enemy_def.get("rarity", "common"))
	var rdef := get_rarity(pack, er)
	return float(rdef.get("enemy_reward_mult", 1.0)) if not rdef.is_empty() else 1.0


## Mastery level ceiling for an item or rarity id (D-060: lower rarities cap earlier).
static func mastery_max_level(item_or_rarity: Variant, pack: Dictionary = {}) -> int:
	if pack.is_empty() and DataLoader != null:
		pack = DataLoader.get_rarities_pack()
	var rid := str(item_or_rarity.get("rarity", "common")) if typeof(item_or_rarity) == TYPE_DICTIONARY else str(item_or_rarity)
	var rdef := get_rarity(pack, rid)
	if not rdef.is_empty() and rdef.has("mastery_max_level"):
		return int(rdef["mastery_max_level"])
	return 10


## Maximum mastery ability entries allowed for an item or rarity id.
static func max_abilities(item_or_rarity: Variant, pack: Dictionary = {}) -> int:
	if pack.is_empty() and DataLoader != null:
		pack = DataLoader.get_rarities_pack()
	var rid := str(item_or_rarity.get("rarity", "common")) if typeof(item_or_rarity) == TYPE_DICTIONARY else str(item_or_rarity)
	var rdef := get_rarity(pack, rid)
	if not rdef.is_empty() and rdef.has("max_abilities"):
		return int(rdef["max_abilities"])
	return 6


## Inherent item gold value (fixed per item definition; no floor_mult).
static func compute_item_value(item_def: Dictionary) -> int:
	return maxi(1, int(item_def.get("base_value", item_def.get("value", 25))))
