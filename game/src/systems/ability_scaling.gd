class_name AbilityScaling
extends RefCounted
## Tier 2 Pure System: Level-Based Enemy Ability Scaling (D-052, D-055).
## Resolves an enemy's active traits/abilities at a given spawned level by merging base `traits`
## with any `ability_tiers` whose `min_level <= level`.
## When an enemy definition has no `ability_tiers` (current roster), returns its base traits unchanged.


## Builds the active trait map {trait_id -> params Dictionary} for `enemy_def` at `level`.
static func resolve_traits(enemy_def: Dictionary, level: int) -> Dictionary:
	var out: Dictionary = {}
	for t in enemy_def.get("traits", []):
		var tid := str(t["id"])
		out[tid] = (t as Dictionary).duplicate(true)

	# Optional level-gated ability upgrades (D-052): each tier has `min_level` and `traits` (Array)
	var tiers: Array = enemy_def.get("ability_tiers", [])
	if tiers.is_empty():
		return out
	var sorted_tiers: Array = tiers.duplicate()
	sorted_tiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("min_level", 1)) < int(b.get("min_level", 1))
	)
	for tier in sorted_tiers:
		if level < int(tier.get("min_level", 1)):
			continue
		for upgrade in tier.get("traits", []):
			var uid := str(upgrade["id"])
			var merged: Dictionary = out.get(uid, {}).duplicate(true)
			for k in (upgrade as Dictionary).keys():
				merged[k] = upgrade[k]
			out[uid] = merged
	return out


## Returns the highest unlocked ability tier index (1-based; 1 = base) for Bestiary / UI display.
static func active_tier_for_level(enemy_def: Dictionary, level: int) -> int:
	var tier_num := 1
	for tier in enemy_def.get("ability_tiers", []):
		if level >= int(tier.get("min_level", 1)):
			tier_num += 1
	return tier_num
