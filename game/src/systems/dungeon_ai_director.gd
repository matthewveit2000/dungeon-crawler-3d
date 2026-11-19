class_name DungeonAiDirector
extends RefCounted
## Tier 2 Pure System: Snarky Dungeon Crawler Carl–style Dungeon AI announcer (D-023).
## Pulls deterministic lines from game/data/dungeon_ai.json and formats event popups.

var _events: Dictionary = {}
var _triggered_once: Dictionary = {}


func _init(dungeon_ai_pack: Dictionary) -> void:
	_events = dungeon_ai_pack.get("events", {})


func reset_floor_flags() -> void:
	_triggered_once.erase("safe_room_discovered")
	_triggered_once.erase("boss_arena_sealed")
	_triggered_once.erase("boss_defeated")


func build_announcement(event_key: String, vars: Dictionary, rng: SeededRng, once_only: bool = false) -> Dictionary:
	if once_only and _triggered_once.has(event_key):
		return {}
	var pool: Array = _events.get(event_key, [])
	if pool.is_empty():
		return {}
	if once_only:
		_triggered_once[event_key] = true
	var picked: Dictionary = rng.pick_array("flavor", pool)
	var title := str(picked.get("title", "SYSTEM NOTICE"))
	var body := str(picked.get("body", ""))
	for k in vars.keys():
		var token := "{%s}" % str(k)
		var val := str(vars[k])
		title = title.replace(token, val)
		body = body.replace(token, val)
	return {"title": title, "body": body, "event_key": event_key}
