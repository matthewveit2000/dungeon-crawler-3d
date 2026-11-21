extends Node
## Tier 1 Autoload: Loads and caches all Tier 3 JSON data packs from res://data/.
## Supports both single-file packs (res://data/<name>.json) and modular subfolder overlays
## (res://data/<name>/*.json) merged in sorted deterministic order (D-055).
## Never hardcodes game values; exposes typed lookup helpers for Tier 2 systems.

const DATA_FILES := {
	"world": "res://data/world.json",
	"player": "res://data/player.json",
	"items": "res://data/items.json",
	"affixes": "res://data/affixes.json",
	"rarities": "res://data/rarities.json",
	"themes": "res://data/themes.json",
	"abilities": "res://data/abilities.json",
	"enemies": "res://data/enemies.json",
	"dungeon_ai": "res://data/dungeon_ai.json",
	"progression": "res://data/progression.json",
	"tutorials": "res://data/tutorials.json",
	"setpieces": "res://data/setpieces.json",
	"mastery": "res://data/mastery.json",
	"balance": "res://data/balance.json",
}

## Optional modular subdirectories merged into the matching pack's list key (sorted by filename).
const MODULAR_DIRS := {
	"items": {"dir": "res://data/items", "array_key": "items"},
	"enemies": {"dir": "res://data/enemies", "array_key": "enemies"},
	"themes": {"dir": "res://data/themes", "array_key": "themes"},
	"abilities": {"dir": "res://data/abilities", "array_key": "abilities"},
}

var _packs: Dictionary = {}
var _items_by_id: Dictionary = {}
var _enemies_by_id: Dictionary = {}
var _rarities_by_id: Dictionary = {}
var _legendary_by_id: Dictionary = {}
var _themes_by_id: Dictionary = {}
var _abilities_by_id: Dictionary = {}
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
	_themes_by_id.clear()
	_abilities_by_id.clear()

	for key in DATA_FILES.keys():
		var path: String = DATA_FILES[key]
		_packs[key] = _load_json(path)

	for key in MODULAR_DIRS.keys():
		var cfg: Dictionary = MODULAR_DIRS[key]
		_merge_modular_dir(str(cfg["dir"]), _packs.get(key, {}), str(cfg["array_key"]))

	# Keep affixes pack in sync with rarities.json as single source of truth when affixes omits them
	var rar_pack: Dictionary = _packs.get("rarities", {})
	var aff_pack: Dictionary = _packs.get("affixes", {})
	if not rar_pack.is_empty():
		if not aff_pack.has("rarities"):
			aff_pack["rarities"] = rar_pack.get("rarities", [])
		if not aff_pack.has("loot_rarities_enabled"):
			aff_pack["loot_rarities_enabled"] = rar_pack.get("loot_rarities_enabled", [])

	for item in _packs.get("items", {}).get("items", []):
		_items_by_id[str(item["id"])] = item

	for enemy in _packs.get("enemies", {}).get("enemies", []):
		_enemies_by_id[str(enemy["id"])] = enemy

	var rarity_list: Array = rar_pack.get("rarities", [])
	if rarity_list.is_empty():
		rarity_list = aff_pack.get("rarities", [])
	for rarity in rarity_list:
		_rarities_by_id[str(rarity["id"])] = rarity

	for eff in aff_pack.get("legendary_effects", []):
		_legendary_by_id[str(eff["id"])] = eff

	for theme in _packs.get("themes", {}).get("themes", []):
		_themes_by_id[str(theme["id"])] = theme

	for ability in _packs.get("abilities", {}).get("abilities", []):
		_abilities_by_id[str(ability["id"])] = ability

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


func get_rarities_pack() -> Dictionary:
	return get_pack("rarities")


func get_themes_pack() -> Dictionary:
	return get_pack("themes")


func get_abilities_pack() -> Dictionary:
	return get_pack("abilities")


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


func get_theme_def(theme_id: String) -> Dictionary:
	ensure_loaded()
	return _themes_by_id.get(theme_id, {})


func get_ability_def(ability_id: String) -> Dictionary:
	ensure_loaded()
	return _abilities_by_id.get(ability_id, {})


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


static func _merge_modular_dir(dir_path: String, target_pack: Dictionary, array_key: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.ends_with(".json"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	if files.is_empty():
		return
	var dest: Array = target_pack.get(array_key, [])
	var seen_ids: Dictionary = {}
	for existing in dest:
		if existing is Dictionary and (existing as Dictionary).has("id"):
			seen_ids[str(existing["id"])] = true
	for f in files:
		var extra := _load_json(dir_path.path_join(f))
		var entries: Array = extra.get(array_key, [])
		for entry in entries:
			if entry is Dictionary:
				var eid := str((entry as Dictionary).get("id", ""))
				if not eid.is_empty() and not seen_ids.has(eid):
					seen_ids[eid] = true
					dest.append(entry)
	target_pack[array_key] = dest


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
