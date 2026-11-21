extends Node
## Tier 1 Autoload: Loads and caches all Tier 3 JSON data packs from res://data/.
## Never hardcodes game values; exposes typed lookup helpers for Tier 2 systems.

const DATA_FILES := {
	"world": "res://data/world.json",
	"player": "res://data/player.json",
	"items": "res://data/items.json",
	"affixes": "res://data/affixes.json",
	"enemies": "res://data/enemies.json",
	"dungeon_ai": "res://data/dungeon_ai.json",
	"progression": "res://data/progression.json",
	"tutorials": "res://data/tutorials.json",
	"setpieces": "res://data/setpieces.json",
	"mastery": "res://data/mastery.json",
	"balance": "res://data/balance.json",
}

var _packs: Dictionary = {}
var _items_by_id: Dictionary = {}
var _enemies_by_id: Dictionary = {}
var _rarities_by_id: Dictionary = {}
var _legendary_by_id: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	ensure_loaded()


func ensure_loaded() -> void:
	if _loaded:
		return
	reload_all()


func reload_all() -> void:
	_packs.clear()
	_items_by_id.clear()
	_enemies_by_id.clear()
	_rarities_by_id.clear()
	_legendary_by_id.clear()

	for key in DATA_FILES.keys():
		var path: String = DATA_FILES[key]
		_packs[key] = _load_json(path)

	for item in _packs.get("items", {}).get("items", []):
		_items_by_id[str(item["id"])] = item

	for enemy in _packs.get("enemies", {}).get("enemies", []):
		_enemies_by_id[str(enemy["id"])] = enemy

	for rarity in _packs.get("affixes", {}).get("rarities", []):
		_rarities_by_id[str(rarity["id"])] = rarity

	for eff in _packs.get("affixes", {}).get("legendary_effects", []):
		_legendary_by_id[str(eff["id"])] = eff

	_loaded = true


func get_pack(pack_name: String) -> Dictionary:
	ensure_loaded()
	return _packs.get(pack_name, {})


func get_world() -> Dictionary:
	return get_pack("world")


func get_player() -> Dictionary:
	return get_pack("player")


func get_items_pack() -> Dictionary:
	return get_pack("items")


func get_affixes_pack() -> Dictionary:
	return get_pack("affixes")


func get_enemies_pack() -> Dictionary:
	return get_pack("enemies")


func get_dungeon_ai_pack() -> Dictionary:
	return get_pack("dungeon_ai")


func get_progression_pack() -> Dictionary:
	return get_pack("progression")


func get_tutorials_pack() -> Dictionary:
	return get_pack("tutorials")


func get_setpieces_pack() -> Dictionary:
	return get_pack("setpieces")


func get_mastery_pack() -> Dictionary:
	return get_pack("mastery")


## FB-022: ids renamed when the game dropped its old TV-show theme. Saves made before still load: every lookup and
## the save-normaliser map an old id to its new one.
const LEGACY_IDS := {
	"sponsored_gauntlets_boom": "thunderclap_gauntlets",
	"sponsored_blade_ratings": "gravefeast_cleaver",
	"goblin_influencer": "goblin_gloryhound",
	"goblin_hype_man": "goblin_hollerer",
	"vampiric_viewers": "blood_feast",
	"tax_rebate_gold": "grave_robber",
}


static func current_id(id: String) -> String:
	return str(LEGACY_IDS.get(id, id))


func get_item_def(item_id: String) -> Dictionary:
	ensure_loaded()
	return _items_by_id.get(current_id(item_id), {})


func get_all_item_defs() -> Array:
	ensure_loaded()
	return _packs.get("items", {}).get("items", [])


func get_enemy_def(enemy_id: String) -> Dictionary:
	ensure_loaded()
	return _enemies_by_id.get(current_id(enemy_id), {})


func get_rarity_def(rarity_id: String) -> Dictionary:
	ensure_loaded()
	return _rarities_by_id.get(rarity_id, {})


func get_legendary_effect_def(effect_id: String) -> Dictionary:
	ensure_loaded()
	return _legendary_by_id.get(current_id(effect_id), {})


func get_floor_config(floor_number: int) -> Dictionary:
	var floors: Array = get_world().get("floors", [])
	if floors.is_empty():
		return {}
	for f in floors:
		if int(f.get("floor_number", 0)) == floor_number:
			return f
	# Cycle smoothly for deeper floors beyond explicitly defined entries
	var idx := (maxi(1, floor_number) - 1) % floors.size()
	var fallback: Dictionary = floors[idx].duplicate(true)
	fallback["floor_number"] = floor_number
	return fallback


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: Missing data pack '%s'" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataLoader: Invalid JSON object in '%s'" % path)
		return {}
	return parsed
