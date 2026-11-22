class_name FloorTheme
extends RefCounted
## Tier 2 Pure System: First-class Floor Theme resolver (D-055, D-060).
## Merges theme defaults from themes.json (with optional `extends` inheritance) and per-floor overrides
## from world.json so DungeonBuilder and DungeonGenerator are cleanly driven by themes and rarities.

const DEFAULT_KIT_DIR := "res://assets/models/kit/"
const DEFAULT_PROPS_DIR := "res://assets/models/props/"
const DEFAULT_WALL_VARIANTS := [
	{"id": "wall_a", "rarity": "common"},
	{"id": "wall_b", "rarity": "common"},
	{"id": "wall_c", "rarity": "common"},
	{"id": "wall_niche", "rarity": "rare"},
	{"id": "wall_damaged", "rarity": "uncommon"},
]
const DEFAULT_TORCH_WALL_VARIANTS := ["wall_a", "wall_b", "wall_c"]
const DEFAULT_FLOOR_VARIANTS := [
	{"id": "floor_a", "rarity": "common"},
	{"id": "floor_b", "rarity": "common"},
	{"id": "floor_c", "rarity": "uncommon"},
]
const DEFAULT_CEILING_VARIANTS := [
	{"id": "ceiling_a", "rarity": "common"},
	{"id": "ceiling_b", "rarity": "rare"},
]

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
var ceiling_variants: Array = DEFAULT_CEILING_VARIANTS
var room_variants: Array = []
var chest_tiers: Array = []
var trap_types: Array = []
var container_types: Array = []
var dressing_props: Array = []
var dressing: Dictionary = {}
var dressing_depth: Dictionary = {}
var dressing_collide: Dictionary = {}
var enemy_tags: Array = []
var loot_tags: Array = []
var raw: Dictionary = {}


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
	if not (merged.get("ceiling_variants", []) as Array).is_empty():
		theme.ceiling_variants = merged["ceiling_variants"]
	theme.room_variants = merged.get("room_variants", [])
	theme.chest_tiers = merged.get("chest_tiers", [])
	theme.trap_types = merged.get("trap_types", [])
	theme.container_types = merged.get("container_types", [])
	theme.dressing_props = merged.get("dressing_props", [])
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


func pick_room_variant(floor_number: int, rng: SeededRng, rar_pack: Dictionary = {}) -> Dictionary:
	if room_variants.is_empty():
		return {"id": "barrow_chamber", "name": "Barrow Chamber", "rarity": "common", "chest_chance": 0.5, "chest_tier": "standard", "trap_chance": 0.1, "containers_max": 2, "enemy_count_delta": 0}
	return RarityTable.pick_entry_by_rarity(room_variants, floor_number, rng, "gen", rar_pack)


func pick_chest_tier(floor_number: int, rng: SeededRng, rar_pack: Dictionary = {}) -> Dictionary:
	if chest_tiers.is_empty():
		return {"id": "standard", "rarity": "common", "label": "Iron-Bound Chest"}
	return RarityTable.pick_entry_by_rarity(chest_tiers, floor_number, rng, "gen", rar_pack)


func chest_tier_def(tier_id: String) -> Dictionary:
	for c in chest_tiers:
		if str((c as Dictionary).get("id", "")) == tier_id:
			return c
	return {}


func pick_wall_variant(floor_number: int, rng: SeededRng, rar_pack: Dictionary = {}) -> String:
	var picked := RarityTable.pick_entry_by_rarity(wall_variants, floor_number, rng, "gen", rar_pack)
	return str(picked.get("id", "wall_a"))


func pick_floor_variant(floor_number: int, rng: SeededRng, rar_pack: Dictionary = {}) -> String:
	var picked := RarityTable.pick_entry_by_rarity(floor_variants, floor_number, rng, "gen", rar_pack)
	return str(picked.get("id", "floor_a"))


func pick_ceiling_variant(floor_number: int, rng: SeededRng, rar_pack: Dictionary = {}) -> String:
	var picked := RarityTable.pick_entry_by_rarity(ceiling_variants, floor_number, rng, "gen", rar_pack)
	return str(picked.get("id", "ceiling_a"))


func pick_container_kind(floor_number: int, rng: SeededRng, rar_pack: Dictionary = {}) -> String:
	if container_types.is_empty():
		return "crate" if rng.next_float("gen") < 0.5 else "urn"
	var picked := RarityTable.pick_entry_by_rarity(container_types, floor_number, rng, "gen", rar_pack)
	return str(picked.get("id", "crate"))


func pick_trap_kind(floor_number: int, rng: SeededRng, rar_pack: Dictionary = {}) -> String:
	if trap_types.is_empty():
		return "spike_trap"
	var picked := RarityTable.pick_entry_by_rarity(trap_types, floor_number, rng, "gen", rar_pack)
	return str(picked.get("id", "spike_trap"))


func pick_dressing_prop(role: String, floor_number: int, rng: SeededRng, preferred_props: Array = [], rar_pack: Dictionary = {}) -> String:
	var cands: Array = []
	for p in dressing_props:
		var pd: Dictionary = p
		var roles: Array = pd.get("roles", [])
		if roles.is_empty() or roles.has(role):
			cands.append(pd)
	if cands.is_empty() and not dressing_props.is_empty():
		cands = dressing_props
	if cands.is_empty():
		return "barrel"
	if not preferred_props.is_empty():
		var pref_cands: Array = []
		for p in cands:
			if preferred_props.has(str((p as Dictionary).get("id", ""))):
				pref_cands.append(p)
		if not pref_cands.is_empty() and rng.next_float("gen") < 0.72:
			cands = pref_cands
	var picked := RarityTable.pick_entry_by_rarity(cands, floor_number, rng, "gen", rar_pack)
	return str(picked.get("id", "barrel"))


func dressing_for_role(role: String, fallback: Dictionary = {}, floor_number: int = 1) -> Array:
	if not dressing_props.is_empty():
		var out: Array = []
		for p in dressing_props:
			var pd: Dictionary = p
			var roles: Array = pd.get("roles", [])
			if roles.is_empty() or roles.has(role):
				out.append([str(pd["id"]), RarityTable.effective_spawn_weight(pd, floor_number)])
		if not out.is_empty():
			return out
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


func to_env_config() -> Dictionary:
	return {
		"ambient_color": ambient_color,
		"fog_color": fog_color,
		"fog_density": fog_density,
		"torch_color": torch_color,
		"safe_zone_color": safe_zone_color,
		"boss_color": boss_color,
	}


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
