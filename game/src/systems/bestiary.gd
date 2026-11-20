class_name Bestiary
extends RefCounted
## Tier 2 Pure System — the Bestiary (D-049).
## Records every enemy type the crawler has met. Knowledge grows in tiers, so meeting a new monster is a
## discovery and hunting it fills in its page:
##   0 unknown  — a "???" silhouette
##   1 sighted  — name, look and lore
##   2 slain    — (1 kill) its stats per level, its level range seen so far and its traits
##   3 studied  — (STUDY_KILLS kills) its weakness
## The Bestiary is crawler knowledge, not floor state: it is saved with the session and is NOT rolled back
## by a floor reset.

const STUDY_KILLS := 5

var entries: Dictionary = {}  ## enemy_id -> {"seen", "kills", "min_level", "max_level", "first_floor"}


## Returns true if this sighting discovered a brand-new enemy type.
func record_seen(enemy_id: String, level: int, floor_number: int) -> bool:
	var e: Dictionary = entries.get(enemy_id, {})
	var is_new := e.is_empty() or not bool(e.get("seen", false))
	if e.is_empty():
		e = {"seen": true, "kills": 0, "min_level": level, "max_level": level, "first_floor": floor_number}
	e["seen"] = true
	e["min_level"] = mini(int(e.get("min_level", level)), level)
	e["max_level"] = maxi(int(e.get("max_level", level)), level)
	entries[enemy_id] = e
	return is_new


## Returns the new kill count for that enemy type.
func record_kill(enemy_id: String, level: int, floor_number: int) -> int:
	record_seen(enemy_id, level, floor_number)
	var e: Dictionary = entries[enemy_id]
	e["kills"] = int(e.get("kills", 0)) + 1
	entries[enemy_id] = e
	return int(e["kills"])


func knowledge(enemy_id: String) -> int:
	var e: Dictionary = entries.get(enemy_id, {})
	if e.is_empty() or not bool(e.get("seen", false)):
		return 0
	var k := int(e.get("kills", 0))
	if k >= STUDY_KILLS:
		return 3
	return 2 if k >= 1 else 1


func kills(enemy_id: String) -> int:
	return int(entries.get(enemy_id, {}).get("kills", 0))


func discovered_count() -> int:
	var n := 0
	for k in entries.keys():
		if bool(entries[k].get("seen", false)):
			n += 1
	return n


func to_dict() -> Dictionary:
	return entries.duplicate(true)


func from_dict(d: Dictionary) -> void:
	entries = d.duplicate(true)
