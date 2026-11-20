class_name BestiaryPage
extends HBoxContainer
## Character menu tab 3 — the Bestiary (D-049).
## Left: every enemy type in the game; ones you have never met are "???". Right: the selected entry with a
## live 3D portrait and knowledge that fills in as you hunt it (see Bestiary: sighted -> slain -> studied).

const TRAIT_INFO := {
	"shield_front": ["Shield Wall", "Blocks most damage from the front unless you power attack or flank it."],
	"frost_strike": ["Frost Strike", "Its hits slow you for a few seconds."],
	"lifedrain": ["Life Drain", "Heals itself with the damage it deals."],
	"regenerate": ["Regeneration", "Regains health whenever it is left alone for a few seconds."],
	"berserk": ["Berserk", "Goes into a frenzy at low health: faster and harder hitting."],
	"war_cry": ["War Cry", "Its shrieks make nearby enemies faster and stronger."],
	"ground_slam": ["Ground Slam", "Every few blows it cracks the floor, hitting everything around it."],
	"hex_bolt": ["Hex Bolt", "Slow homing curses that slow you on impact."],
	"bomb_throw": ["Firebombs", "Lobs pots that burst where they land."],
}
const TIER_NAMES := ["Unknown", "Sighted", "Slain", "Studied"]

var bestiary: Bestiary = null
var _list: VBoxContainer = null
var _detail: VBoxContainer = null
var _count_lbl: Label = null
var _selected: String = ""
var _vp: SubViewport = null
var _world: Node3D = null
var _portrait: CharacterVisual = null


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	lv.add_child(UiTheme.label("BESTIARY", 22, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading()))
	_count_lbl = UiTheme.label("", 15, UiTheme.COL_MUTED, UiTheme.font_ui())
	lv.add_child(_count_lbl)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	sc.add_child(_list)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UiTheme.panel_style("frame"))
	add_child(right)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 14)
	right.add_child(rh)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(240, 360)
	svc.stretch = true
	rh.add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(240, 360)
	svc.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 4.3)
	cam.fov = 36.0
	_world.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_color = Color(1.0, 0.85, 0.65)
	key.light_energy = 1.8
	_world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.0, -1.5)
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 2.5
	rim.omni_range = 5.0
	_world.add_child(rim)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.45, 0.4)
	e.ambient_light_energy = 0.8
	we.environment = e
	_world.add_child(we)
	var dsc := ScrollContainer.new()
	dsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rh.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	dsc.add_child(_detail)


func _process(delta: float) -> void:
	if is_visible_in_tree() and _portrait != null and is_instance_valid(_portrait):
		_portrait.rotation.y += delta * 0.4


static func all_enemies() -> Array:
	var out: Array = []
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("level_min", 1)) < int(b.get("level_min", 1)) or (int(a.get("level_min", 1)) == int(b.get("level_min", 1)) and str(a["id"]) < str(b["id"])))
	return out


func refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var all := all_enemies()
	var known := bestiary.discovered_count() if bestiary != null else 0
	_count_lbl.text = "%d / %d creatures discovered" % [known, all.size()]
	if _selected.is_empty():
		for e in all:
			if bestiary != null and bestiary.knowledge(str(e["id"])) > 0:
				_selected = str(e["id"])
				break
	for e in all:
		var id := str(e["id"])
		var tier := bestiary.knowledge(id) if bestiary != null else 0
		var b := UiTheme.button(("%s" % str(e["name"])) if tier > 0 else "???", 0, 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = id == _selected
		if tier > 0:
			b.text += "   ·  %d slain" % bestiary.kills(id)
		b.pressed.connect(func() -> void:
			_selected = id
			refresh())
		_list.add_child(b)
	_show_entry(_selected)


func _show_entry(id: String) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var edef := DataLoader.get_enemy_def(id)
	var tier := bestiary.knowledge(id) if bestiary != null and not id.is_empty() else 0
	_set_portrait(edef, tier)
	if edef.is_empty() or tier == 0:
		_detail.add_child(UiTheme.label("???", 30, UiTheme.COL_MUTED, UiTheme.font_heading()))
		_detail.add_child(UiTheme.body("You have not met this creature yet. Something is down here, waiting to be discovered.", 17, UiTheme.COL_MUTED, true))
		return
	var e: Dictionary = bestiary.entries.get(id, {})
	_detail.add_child(UiTheme.label(str(edef["name"]), 28, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_heading()))
	_detail.add_child(UiTheme.label("%s  ·  %d slain  ·  first met on floor %d" % [TIER_NAMES[tier].to_upper(), int(e.get("kills", 0)), int(e.get("first_floor", 1))],
		14, UiTheme.COL_CYAN, UiTheme.font_ui_bold()))
	_detail.add_child(UiTheme.divider())
	_detail.add_child(UiTheme.body("“%s”" % str(edef.get("lore", "")), 17, UiTheme.COL_TEXT, true))
	var lv := "Seen at level %d" % int(e.get("min_level", 1)) if int(e.get("min_level", 1)) == int(e.get("max_level", 1)) \
		else "Seen at levels %d – %d" % [int(e.get("min_level", 1)), int(e.get("max_level", 1))]
	if tier >= 3:
		lv += "   ·   known range %d – %d" % [int(edef.get("level_min", 1)), int(edef.get("level_max", 1))]
	_detail.add_child(UiTheme.label(lv, 16, UiTheme.COL_MUTED, UiTheme.font_ui()))
	if tier < 2:
		_detail.add_child(UiTheme.body("Slay one to learn its strength and abilities.", 16, UiTheme.COL_MUTED, true))
		return
	# Stats at the lowest and highest level seen
	var pack := DataLoader.get_enemies_pack()
	var grid := GridContainer.new()
	var lo := int(e.get("min_level", 1))
	var hi := int(e.get("max_level", 1))
	grid.columns = 3 if hi > lo else 2
	grid.add_theme_constant_override("h_separation", 18)
	_detail.add_child(grid)
	var heads := ["", "Lv %d" % lo, "Lv %d" % hi] if hi > lo else ["", "Lv %d" % lo]
	for h in heads:
		grid.add_child(UiTheme.label(h, 14, UiTheme.COL_FAINT, UiTheme.font_ui_bold()))
	var sl := EnemyLevels.scale_for(lo, pack)
	var sh := EnemyLevels.scale_for(hi, pack)
	for row in [["Health", float(edef["max_health"]) * float(sl["health"]), float(edef["max_health"]) * float(sh["health"])],
			["Damage", float(edef["damage"]) * float(sl["damage"]), float(edef["damage"]) * float(sh["damage"])],
			["Armor", float(edef.get("armor", 0.0)) + float(sl["armor"]), float(edef.get("armor", 0.0)) + float(sh["armor"])]]:
		grid.add_child(UiTheme.label(str(row[0]), 16, UiTheme.COL_TEXT, UiTheme.font_ui()))
		grid.add_child(UiTheme.label("%d" % int(row[1]), 16, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_ui_bold()))
		if hi > lo:
			grid.add_child(UiTheme.label("%d" % int(row[2]), 16, UiTheme.COL_GOLD_BRIGHT, UiTheme.font_ui_bold()))
	var style := "Ranged" if str(edef.get("archetype", "")) == "ranged" else ("Charger" if str(edef.get("archetype", "")) == "charger" else "Melee")
	_detail.add_child(UiTheme.label("%s  ·  speed %.1f  ·  notices you from %d m" % [style, float(edef.get("move_speed", 3.5)), int(edef.get("aggro_radius", 20))],
		15, UiTheme.COL_MUTED, UiTheme.font_ui()))
	var traits: Array = edef.get("traits", [])
	if not traits.is_empty():
		_detail.add_child(UiTheme.label("ABILITIES", 15, UiTheme.COL_GOLD, UiTheme.font_ui_bold()))
		for t in traits:
			var info: Array = TRAIT_INFO.get(str(t["id"]), [str(t["id"]).capitalize(), ""])
			var r := UiTheme.label("◆ %s — %s" % [info[0], info[1]], 15, UiTheme.COL_CYAN, UiTheme.font_ui())
			r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detail.add_child(r)
	if tier >= 3:
		_detail.add_child(UiTheme.label("WEAKNESS", 15, UiTheme.COL_GOLD, UiTheme.font_ui_bold()))
		_detail.add_child(UiTheme.body(str(edef.get("weakness", "")), 16, UiTheme.COL_GOOD, true))
	else:
		_detail.add_child(UiTheme.body("Slay %d to discover its weakness (%d / %d)." % [Bestiary.STUDY_KILLS, int(e.get("kills", 0)), Bestiary.STUDY_KILLS], 15, UiTheme.COL_MUTED, true))


func _set_portrait(edef: Dictionary, tier: int) -> void:
	if _portrait != null and is_instance_valid(_portrait):
		_portrait.queue_free()
		_portrait = null
	if edef.is_empty():
		return
	var vdef: Dictionary = edef.get("visual", {})
	_portrait = CharacterVisual.create(str(vdef.get("kind", "draugr")))
	var h := float(edef.get("height", 1.85))
	_portrait.scale = Vector3.ONE * clampf(1.9 / maxf(0.5, h), 0.6, 1.4)
	_world.add_child(_portrait)
	_portrait.play_state("idle_combat" if _portrait.has_anim("idle_combat") else "idle", 0.0)
	if tier == 0:
		_portrait.set_tint(Color(0.0, 0.0, 0.0), 0.97)  # unknown: a black silhouette
	elif vdef.has("tint"):
		_portrait.set_tint(Color.html(str(vdef["tint"])), float(vdef.get("tint_strength", 0.25)))
	var w := str(vdef.get("weapon", ""))
	if not w.is_empty() and tier > 0:
		var grip := _portrait.model.find_child(("GripL" if str(vdef.get("weapon_hand", "r")) == "l" else "GripR") + "*", true, false) as Node3D
		if grip != null:
			var wm := ModelLoader.instantiate_model(w, Vector3(0.1, 0.8, 0.1))
			wm.scale = Vector3.ONE * float(vdef.get("weapon_scale", 1.0))
			grip.add_child(wm)
