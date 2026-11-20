class_name EnemyLevels
extends RefCounted
## Tier 2 Pure System — enemy levels (D-049).
## Each enemy type has its own level range (level_min..level_max). Each floor covers a level band; a type only
## spawns on floors whose band overlaps its range, and every spawn rolls a level inside that overlap. Stats scale
## with the level, so a level-6 draugr is a very different fight from a level-1 one.


## [lo, hi] level band covered by a floor.
static func floor_band(floor_number: int, pack: Dictionary) -> Vector2i:
	var b: Dictionary = pack.get("floor_level_band", {})
	var lo := int(b.get("start", 1)) + int(b.get("step", 3)) * maxi(0, floor_number - 1)
	return Vector2i(lo, lo + int(b.get("width", 4)) - 1)


static func type_range(edef: Dictionary) -> Vector2i:
	var lo := int(edef.get("level_min", 1))
	return Vector2i(lo, maxi(lo, int(edef.get("level_max", lo))))


## True when this enemy type can appear on the floor.
static func eligible(edef: Dictionary, floor_number: int, pack: Dictionary) -> bool:
	var band := floor_band(floor_number, pack)
	var r := type_range(edef)
	return r.x <= band.y and r.y >= band.x


## Level for one spawn: inside the type's range and (where they overlap) the floor's band.
static func roll_level(edef: Dictionary, floor_number: int, pack: Dictionary, rng: SeededRng) -> int:
	var band := floor_band(floor_number, pack)
	var r := type_range(edef)
	var lo := maxi(r.x, band.x)
	var hi := mini(r.y, band.y)
	if lo > hi:
		# floor outside the type's range (Test Mode spawns): clamp to the nearest end of the range
		return clampi(band.x, r.x, r.y)
	return rng.next_int_range("ai", lo, hi) if rng != null else lo


## Multipliers / additions for a level (level 1 = the base stats in enemies.json).
static func scale_for(level: int, pack: Dictionary) -> Dictionary:
	var s: Dictionary = pack.get("level_scaling", {})
	var n := float(maxi(0, level - 1))
	return {
		"health": 1.0 + float(s.get("health_per_level", 0.12)) * n,
		"damage": 1.0 + float(s.get("damage_per_level", 0.07)) * n,
		"armor": float(s.get("armor_per_level", 1.0)) * n,
		"xp": 1.0 + float(s.get("xp_per_level", 0.15)) * n,
		"gold": 1.0 + float(s.get("gold_per_level", 0.1)) * n,
	}
