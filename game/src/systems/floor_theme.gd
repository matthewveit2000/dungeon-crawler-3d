class_name FloorTheme
extends RefCounted
## Tier 2 Pure System: First-class Floor Theme resolver (D-055 / IDEA-008).
## Merges theme defaults from themes.json (with optional `extends` inheritance) and per-floor overrides
## from world.json so DungeonBuilder, DungeonGenerator, and LootGenerator can be driven cleanly by themes.

const DEFAULT_KIT_DIR := "res://assets/models/kit/"
const DEFAULT_PROPS_DIR := "res://assets/models/props/"
const DEFAULT_WALL_VARIANTS := [["wall_a", 0.3], ["wall_b", 0.3], ["wall_c", 0.24], ["wall_niche", 0.09], ["wall_damaged", 0.07]]
const DEFAULT_TORCH_WALL_VARIANTS := ["wall_a", "wall_b", "wall_c"]
const DEFAULT_FLOOR_VARIANTS := ["floor_a", "floor_b", "floor_c"]

var id: String = "nordic_catacombs"
var theme_name: String = "Nordic Catacombs"
var kit_dir: String = DEFAULT_KIT_DIR
var props_dir: String = DEFAULT_PROPS_DIR
var ambient_color: String = "#1a1f28"
var fog_color: String = "#11151d"
var fog_density: float = 0.014
var torch_color: String = "#ffa34d"
var safe_zone_color: String = "#45e6b8"
var boss_color: String = "#e04838"
var wall_variants: Array = DEFAULT_WALL_VARIANTS
var torch_wall_variants: Array = DEFAULT_TORCH_WALL_VARIANTS
var floor_variants: Array = DEFAULT_FLOOR_VARIANTS
var ceiling_primary: String = "ceiling_a"
var ceiling_alt: String = "ceiling_b"
var ceiling_alt_chance: float = 0.08
var dressing: Dictionary = {}
var dressing_depth: Dictionary = {}
var dressing_collide: Dictionary = {}
var enemy_tags: Array = []
var loot_tags: Array = []
var raw: Dictionary = {}


## Resolves a FloorTheme from a floor config dictionary and themes pack (merges `extends` + floor overrides).
static func resolve(floor_cfg: Dictionary, themes_pack: Dictionary = {}) -> FloorTheme:
	var pack := themes_pack
	if pack.is_empty() and DataLoader != null:
		pack = DataLoader.get_themes_pack()

	var by_id: Dictionary = {}
	for t in pack.get("themes", []):
		by_id[str(t.get("id", ""))] = t

	var default_id := str(pack.get("default_theme_id", "nordic_catacombs"))
	var target_id := str(floor_cfg.get("theme_id", default_id))
	var merged: Dictionary = _merge_inheritance(by_id, target_id, default_id)

	# Per-floor overrides in world.json take precedence over theme defaults
	for key in ["ambient_color", "fog_color", "fog_density", "torch_color", "safe_zone_color", "boss_color",
			"kit_dir", "props_dir", "enemy_tags", "loot_tags"]:
		if floor_cfg.has(key):
			merged[key] = floor_cfg[key]

	var theme := FloorTheme.new()
	theme.id = target_id
	theme.theme_name = str(merged.get("name", target_id))
	theme.kit_dir = str(merged.get("kit_dir", DEFAULT_KIT_DIR))
	theme.props_dir = str(merged.get("props_dir", DEFAULT_PROPS_DIR))
	theme.ambient_color = str(merged.get("ambient_color", "#1a1f28"))
	theme.fog_color = str(merged.get("fog_color", "#11151d"))
	theme.fog_density = float(merged.get("fog_density", 0.014))
	theme.torch_color = str(merged.get("torch_color", "#ffa34d"))
	theme.safe_zone_color = str(merged.get("safe_zone_color", "#45e6b8"))
	theme.boss_color = str(merged.get("boss_color", "#e04838"))
	if not (merged.get("wall_variants", []) as Array).is_empty():
		theme.wall_variants = merged["wall_variants"]
	if not (merged.get("torch_wall_variants", []) as Array).is_empty():
		theme.torch_wall_variants = merged["torch_wall_variants"]
	if not (merged.get("floor_variants", []) as Array).is_empty():
		theme.floor_variants = merged["floor_variants"]
	theme.ceiling_primary = str(merged.get("ceiling_primary", "ceiling_a"))
	theme.ceiling_alt = str(merged.get("ceiling_alt", "ceiling_b"))
	theme.ceiling_alt_chance = float(merged.get("ceiling_alt_chance", 0.08))
	theme.dressing = merged.get("dressing", {})
	theme.dressing_depth = merged.get("dressing_depth", {})
	var raw_col: Dictionary = merged.get("dressing_collide", {})
	for k in raw_col.keys():
		var v: Variant = raw_col[k]
		if v is Vector3:
			theme.dressing_collide[k] = v
		elif v is Array and (v as Array).size() >= 3:
			theme.dressing_collide[k] = Vector3(float(v[0]), float(v[1]), float(v[2]))
	theme.enemy_tags = merged.get("enemy_tags", [])
	theme.loot_tags = merged.get("loot_tags", [])
	theme.raw = merged
	return theme


static func _merge_inheritance(by_id: Dictionary, target_id: String, fallback_id: String) -> Dictionary:
	var lookup := target_id if by_id.has(target_id) else fallback_id
	if not by_id.has(lookup):
		return {}
	var chain: Array[Dictionary] = []
	var seen: Dictionary = {}
	var cur := lookup
	while not cur.is_empty() and by_id.has(cur) and not seen.has(cur):
		seen[cur] = true
		var d: Dictionary = by_id[cur]
		chain.push_front(d)
		cur = str(d.get("extends", ""))
	var out: Dictionary = {}
	for d in chain:
		for k in d.keys():
			if k != "extends":
				out[k] = d[k]
	return out


func dressing_for_role(role: String, fallback: Dictionary = {}) -> Array:
	if dressing.has(role):
		return dressing[role]
	if dressing.has("combat"):
		return dressing["combat"]
	if fallback.has(role):
		return fallback[role]
	return fallback.get("combat", [])


func prop_depth(kind: String, fallback: float = 0.8) -> float:
	return float(dressing_depth.get(kind, fallback))


func has_prop_collider(kind: String) -> bool:
	return dressing_collide.has(kind)


func prop_collider(kind: String) -> Vector3:
	return dressing_collide.get(kind, Vector3.ZERO)


## Returns a dictionary compatible with DungeonBuilder.build_environment().
func to_env_config() -> Dictionary:
	return {
		"ambient_color": ambient_color,
		"fog_color": fog_color,
		"fog_density": fog_density,
		"torch_color": torch_color,
		"safe_zone_color": safe_zone_color,
		"boss_color": boss_color,
	}


## Optional theme tag filter for future themed enemy pools (empty tags = allow all, zero change to current floors).
func matches_enemy(enemy_def: Dictionary) -> bool:
	if enemy_tags.is_empty():
		return true
	var etags: Array = enemy_def.get("theme_tags", [])
	if etags.is_empty():
		return true
	for t in enemy_tags:
		if etags.has(t):
			return true
	return false


## Optional theme tag filter for future themed loot pools (empty tags = allow all).
func matches_item(item_def: Dictionary) -> bool:
	if loot_tags.is_empty():
		return true
	var itags: Array = item_def.get("theme_tags", [])
	if itags.is_empty():
		return true
	for t in loot_tags:
		if itags.has(t):
			return true
	return false
