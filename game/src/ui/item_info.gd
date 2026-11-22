class_name ItemInfo
extends RefCounted
## Item presentation helpers shared by Inventory, Vendor and loot UI: readable stat lines,
## comparison deltas against the currently equipped item (green better / red worse), and a
## full detail card with icon, rarity, affixes, legendary effect, description and value.

const STAT_NAMES := {
	"damage": "Damage", "armor": "Armor", "block_bonus": "Block", "heal_health": "Restores Health",
	"heal_magicka": "Restores Magicka", "heal_stamina": "Restores Stamina", "heal_amount": "Heals", "magicka_cost": "Magicka Cost",
	"stamina_cost": "Stamina Cost", "bonus_damage": "Bonus Damage", "bonus_health": "Max Health",
	"bonus_magicka": "Max Magicka", "bonus_stamina": "Max Stamina", "bonus_crit_chance": "Critical Chance",
	"gold_find_bonus": "Gold Find", "cooldown_reduction": "Attack Speed", "splash_radius": "Blast Radius",
	"chain_radius": "Chain Range",
}
const LOWER_IS_BETTER := ["magicka_cost", "stamina_cost"]
const PERCENT_STATS := ["bonus_crit_chance", "gold_find_bonus", "cooldown_reduction", "block_bonus"]
const ORDER := ["damage", "armor", "block_bonus", "heal_health", "heal_magicka", "heal_stamina", "heal_amount", "magicka_cost", "stamina_cost",
	"bonus_damage", "bonus_health", "bonus_magicka", "bonus_stamina", "bonus_crit_chance", "cooldown_reduction", "gold_find_bonus",
	"splash_radius", "chain_radius"]


static func type_line(item: Dictionary) -> String:
	var cat := str(item.get("category", ""))
	var slot := str(item.get("slot", "")).replace("_", " ").capitalize()
	match cat:
		"weapon":
			var wt := str(item.get("weapon_type", "one_handed"))
			if wt == "archery":
				return "Bow  ·  Two-Handed"
			return "%s Weapon" % ("Two-Handed" if bool(item.get("two_handed", false)) else "One-Handed")
		"shield":
			return "Shield  ·  Off-Hand"
		"spell":
			return "Spell Tome  ·  %s" % str(item.get("weapon_type", "magic")).capitalize()
		"armor":
			return "Armor  ·  %s" % slot
		"accessory":
			return "Accessory  ·  %s" % slot
		"consumable":
			return "Consumable  ·  stacks"
		"ingredient":
			return "Ingredient  ·  stacks  ·  edible"
	return cat.capitalize()


static func fmt_stat(key: String, v: float) -> String:
	if key in PERCENT_STATS:
		return "%+.0f%%" % (v * 100.0) if absf(v) < 2.0 else "%+.0f%%" % v
	if key in ["damage", "armor", "heal_health", "heal_magicka", "heal_stamina", "heal_amount", "magicka_cost", "stamina_cost"]:
		return "%.0f" % v
	return "%+.0f" % v


static func stat_values(item: Dictionary) -> Dictionary:
	var out := {}
	for k in ORDER:
		if item.has(k) and (item[k] is float or item[k] is int) and absf(float(item[k])) > 0.0001:
			if k in MasterySystem.STAT_KEYS:
				out[k] = MasterySystem.stat(item, k)
			elif k in ["heal_health", "heal_magicka", "heal_stamina"]:
				out[k] = PowerScale.consumable_value(item, k)
			else:
				out[k] = float(item[k])
	return out


## Mastery section (D-049): level, XP toward the next level, discovered abilities and the undiscovered ones
## still waiting further up the track (shown only as "???" with the level that reveals them).
static func build_mastery(item: Dictionary) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	if not MasterySystem.is_masterable(item):
		return v
	var lvl := MasterySystem.level_of(item)
	var cap := MasterySystem.max_level_for(item)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiTheme.label("MASTERY %d / %d" % [lvl, cap], 17, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_ui_bold()))
	var need := MasterySystem.xp_to_next(lvl)
	var xp := float(item.get("mastery_xp", 0.0))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = float(need) if lvl < cap else 1.0
	bar.value = xp if lvl < cap else 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UiTheme.COL_GOLD
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	head.add_child(bar)
	head.add_child(UiTheme.label("%d / %d xp" % [int(xp), need] if lvl < cap else "MASTERED", 14, UiTheme.COL_MUTED, UiTheme.font_ui()))
	v.add_child(head)
	# FB-022: say exactly what has to happen to level this item up
	var how := UiTheme.label(MasterySystem.how_to_level(item), 15, UiTheme.COL_TEXT, UiTheme.font_ui())
	how.name = "HowToLevel"
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 260
	v.add_child(how)
	var shown := {}
	for e in MasterySystem.track(item):
		var el := int(e.get("level", 1))
		var ab := str(e.get("ability", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if el <= lvl:
			var p: Dictionary = e.duplicate()
			p.erase("level")
			var upgraded := shown.has(ab)
			shown[ab] = true
			row.add_child(UiTheme.icon_rect(UiTheme.tex("icon_diamond"), 12, UiTheme.COL_CYAN))
			var t := UiTheme.label("Lv %d  %s%s — %s" % [el, MasterySystem.ability_name(ab), " (upgraded)" if upgraded else "", MasterySystem.describe(ab, p)],
				15, UiTheme.COL_CYAN, UiTheme.font_ui())
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(t)
		else:
			row.add_child(UiTheme.icon_rect(UiTheme.tex("icon_diamond"), 12, UiTheme.COL_MUTED))
			row.add_child(UiTheme.label("Lv %d  ???  — keep using this item to discover it" % el, 15, UiTheme.COL_MUTED, UiTheme.font_ui()))
		v.add_child(row)
	return v


## Builds the detail card. compare: equipped item in the same slot (or {}).
static func build_card(item: Dictionary, compare: Dictionary = {}, price_text: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if item.is_empty():
		v.add_child(UiTheme.body("Select an item to inspect it.", 18, UiTheme.COL_MUTED, true))
		return v
	var rarity := str(item.get("rarity", "common"))
	var rc := UiTheme.rarity_color(rarity)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	top.add_child(UiTheme.item_slot(item, 96))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	top.add_child(tv)
	var nm := UiTheme.label(str(item.get("name", "Item")), 22, rc, UiTheme.font_heading())
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nm)
	tv.add_child(UiTheme.label(UiTheme.rarity_name(rarity).to_upper(), 14, rc.darkened(0.1), UiTheme.font_ui_bold()))
	tv.add_child(UiTheme.label(type_line(item), 16, UiTheme.COL_MUTED, UiTheme.font_ui()))
	v.add_child(UiTheme.divider())
	var mine := stat_values(item)
	var theirs := stat_values(compare) if not compare.is_empty() else {}
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	v.add_child(grid)
	for k in ORDER:
		if not mine.has(k) and not (theirs.has(k) and not compare.is_empty()):
			continue
		var val := float(mine.get(k, 0.0))
		grid.add_child(UiTheme.label(str(STAT_NAMES.get(k, k.capitalize())), 18, UiTheme.COL_TEXT, UiTheme.font_ui()))
		grid.add_child(UiTheme.label(fmt_stat(k, val), 18, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_ui_bold()))
		var dl := UiTheme.label("", 16, UiTheme.COL_MUTED, UiTheme.font_ui_semibold())
		if not compare.is_empty() and compare.get("instance_id", "") != item.get("instance_id", "_"):
			var d := val - float(theirs.get(k, 0.0))
			if absf(d) > 0.05:
				var better := d > 0.0
				if k in LOWER_IS_BETTER:
					better = not better
				var mag := fmt_stat(k, absf(d)).trim_prefix("+")
				dl.text = ("+" if d > 0.0 else "−") + mag + ("  better" if better else "  worse")
				dl.add_theme_color_override("font_color", UiTheme.COL_GOOD if better else UiTheme.COL_BAD)
		grid.add_child(dl)
	var affs: Array = item.get("affixes", [])
	if not affs.is_empty():
		for a in affs:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			r.add_child(UiTheme.icon_rect(UiTheme.tex("icon_diamond"), 12, UiTheme.COL_CYAN))
			r.add_child(UiTheme.label("%s  (%s %s)" % [str(a.get("label", "")), fmt_stat(str(a.get("stat", "")), float(a.get("value", 0.0))),
				str(STAT_NAMES.get(str(a.get("stat", "")), str(a.get("stat", "")).capitalize()))], 16, UiTheme.COL_CYAN, UiTheme.font_ui()))
			v.add_child(r)
	if MasterySystem.is_masterable(item):
		v.add_child(UiTheme.divider())
		v.add_child(build_mastery(item))
	var se := str(item.get("legendary_effect", ""))
	if not se.is_empty():
		var sp := PanelContainer.new()
		sp.add_theme_stylebox_override("panel", UiTheme.make_panel_style(Color(0.22, 0.14, 0.03, 0.8), Color(1.0, 0.68, 0.18, 0.9), 1, 4, 10, 6))
		var edef := DataLoader.get_legendary_effect_def(se)
		var sl := UiTheme.label("LEGENDARY EFFECT  ·  %s — %s" % [str(item.get("legendary_label", edef.get("label", se.replace("_", " ")))).to_upper(), str(edef.get("description", ""))], 15, Color(1.0, 0.78, 0.3), UiTheme.font_ui_bold())
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sp.add_child(sl)
		v.add_child(sp)
	# FB-022: timed effect of a potion / ingredient, and how many are in the stack
	var eff: Dictionary = item.get("effect", {})
	if not eff.is_empty():
		var ec := Color(1.0, 0.45, 0.38) if str(eff.get("kind", "buff")) == "debuff" else UiTheme.COL_CYAN
		var el := UiTheme.label("%s for %d s — %s" % [str(eff.get("name", "Effect")), int(eff.get("duration", 0)), effect_text(eff, PowerScale.item(item))],
			16, ec, UiTheme.font_ui_semibold())
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(el)
	if InventoryStacks.is_stackable(item) and InventoryStacks.count(item) > 1:
		v.add_child(UiTheme.label("In your pack: %d" % InventoryStacks.count(item), 15, UiTheme.COL_MUTED, UiTheme.font_ui()))
	var desc := str(item.get("description", ""))
	if not desc.is_empty():
		v.add_child(UiTheme.body("“%s”" % desc, 17, UiTheme.COL_MUTED, true))
	var foot := HBoxContainer.new()
	foot.add_child(UiTheme.icon_rect(UiTheme.tex("icon_coin"), 16, UiTheme.COL_GOLD))
	foot.add_child(UiTheme.label(price_text if not price_text.is_empty() else "Value %d gold" % int(item.get("value", item.get("base_value", 0))), 16, UiTheme.COL_GOLD, UiTheme.font_ui_semibold()))
	v.add_child(foot)
	return v


static func slot_for(item: Dictionary) -> String:
	var s := str(item.get("slot", ""))
	if s == "ring":
		return "ring_1"
	return s


static func matches_filter(item: Dictionary, f: String) -> bool:
	var cat := str(item.get("category", ""))
	match f:
		"weapons":
			return cat == "weapon" or cat == "shield"
		"apparel":
			return cat == "armor" or cat == "accessory"
		"magic":
			return cat == "spell"
		"consumables":
			return cat == "consumable" or cat == "ingredient"
	return true


static func sort_items(entries: Array, mode: String) -> void:
	var rank := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4}
	match mode:
		"rarity":
			entries.sort_custom(func(a: Array, b: Array) -> bool:
				return int(rank.get(str(a[1].get("rarity", "common")), 0)) > int(rank.get(str(b[1].get("rarity", "common")), 0)))
		"value":
			entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1].get("value", 0)) > int(b[1].get("value", 0)))
		"name":
			entries.sort_custom(func(a: Array, b: Array) -> bool: return str(a[1].get("name", "")) < str(b[1].get("name", "")))
		"type":
			entries.sort_custom(func(a: Array, b: Array) -> bool: return str(a[1].get("category", "")) < str(b[1].get("category", "")))
		_:
			entries.reverse()


## FB-022: readable text for a timed effect's numbers (e.g. "+25% movement speed").
static func effect_text(eff: Dictionary, power: float = 1.0) -> String:
	var parts: Array = []
	for k in eff.keys():
		if k in ["id", "name", "duration", "kind"]:
			continue
		var v := float(eff[k]) * power
		match str(k):
			"speed": parts.append("+%d%% movement speed" % int(round(v * 100.0)))
			"slow": parts.append("-%d%% movement speed" % int(round(v * 100.0)))
			"armor": parts.append("+%d armor" % int(round(v)))
			"hps": parts.append("+%s health per second" % ("%.0f" % v if is_equal_approx(v, round(v)) else "%.1f" % v))
			"magicka_regen": parts.append("+%s magicka per second" % ("%.0f" % v if is_equal_approx(v, round(v)) else "%.1f" % v))
			"stamina_regen": parts.append("+%s stamina per second" % ("%.0f" % v if is_equal_approx(v, round(v)) else "%.1f" % v))
			_: parts.append("%s %+.1f" % [str(k).capitalize(), v])
	return ", ".join(parts)
