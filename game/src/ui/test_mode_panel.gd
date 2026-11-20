class_name TestModePanel
extends MenuScreen
## Test Mode tools (D-047), opened with F1 in a Test Mode session. Every spawner and switch calls the public
## `GameMain.test_*` API, so anything done here can also be scripted in automated tests:
##   Enemies — spawn any enemy (incl. the boss) 1/3/5 at a time in front of you, kill nearby, clear, freeze AI.
##   Items   — any item at any rarity straight into the bag, everything at once, gold, potions.
##   World   — chests (standard/rare/vault), crates, urns, levers, spike traps, braziers, lights, stairwells,
##             safe-room kits and every handcrafted room setpiece, placed where you are looking.
##   Player  — god mode, infinite stamina/magicka, level ups, full heal, first/third person, die (floor reset).
##   Floor   — teleport to every room type, open/close boss gates, clock, advance days, collapse, change floor,
##             switch between the compact test floor and a real vast floor.

var _game: GameMain = null
var _close_cb: Callable = Callable()
var _status: Label = null
var _rarity: String = "rare"
var _count: int = 1
var _tabs: TabContainer = null


func _ready() -> void:
	build_base(25, true)
	_build_ui()


func setup(game: GameMain, close_cb: Callable) -> void:
	_game = game
	_close_cb = close_cb


func open_menu() -> void:
	_refresh_status()
	show_animated()


func _btn(parent: Control, text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := UiTheme.button(text, min_w, 16)
	b.pressed.connect(func() -> void:
		cb.call()
		_refresh_status())
	parent.add_child(b)
	return b


func _grid(tab_name: String, cols: int = 4) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	var g := GridContainer.new()
	g.columns = cols
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	return g


func _section(g: GridContainer, text: String) -> void:
	var v := g.get_parent() as VBoxContainer
	var lbl := UiTheme.label(text, 17, UiTheme.COL_GOLD, UiTheme.font_heading())
	v.add_child(lbl)
	var ng := GridContainer.new()
	ng.columns = g.columns
	ng.add_theme_constant_override("h_separation", 8)
	ng.add_theme_constant_override("v_separation", 8)
	v.add_child(ng)
	g.set_meta("next", ng)


func _next(g: GridContainer) -> GridContainer:
	return g.get_meta("next", g) as GridContainer


func _build_ui() -> void:
	var v := make_frame(Vector2(980, 600), "TEST MODE")
	_status = UiTheme.label("", 15, UiTheme.COL_MUTED, UiTheme.font_ui())
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(940, 470)
	v.add_child(_tabs)

	# --- Enemies ---
	var ge := _grid("Enemies", 4)
	for n in [1, 3, 5]:
		var nn: int = n
		_btn(ge, "Count: %d" % nn, func() -> void: _count = nn)
	_btn(ge, "Kill nearby (25 m)", func() -> void: _game.test_kill_enemies(25.0))
	_section(ge, "Spawn in front of you")
	for e in DataLoader.get_enemies_pack().get("enemies", []):
		var eid := str(e["id"])
		_btn(_next(ge), str(e.get("name", eid)), func() -> void: _game.test_spawn_enemy(eid, _count))
	_section(ge, "Control")
	var gc := _next(ge)
	_btn(gc, "Kill all", func() -> void: _game.test_kill_enemies())
	_btn(gc, "Remove all", func() -> void: _game.test_clear_enemies())
	_btn(gc, "Freeze / unfreeze AI", func() -> void: _game.test_toggle("ai"))

	# --- Items ---
	var gi := _grid("Items", 5)
	for r in DataLoader.get_affixes_pack().get("rarities", []):
		var rid := str(r["id"])
		_btn(gi, "Rarity: %s" % str(r.get("label", rid)), func() -> void: _rarity = rid)
	_section(gi, "Add to your bag (selected rarity)")
	for it in DataLoader.get_items_pack().get("items", []):
		var iid := str(it["id"])
		_btn(_next(gi), str(it.get("name", iid)), func() -> void: _game.test_give_item(iid, _rarity))
	_section(gi, "Bulk")
	var gb := _next(gi)
	_btn(gb, "Every item", func() -> void: _game.test_give_all_items(_rarity))
	_btn(gb, "+1,000 gold", func() -> void:
		_game.player.gold += 1000
		_game.player.emit_stats())
	_btn(gb, "5 health potions", func() -> void:
		for _i in range(5):
			_game.test_give_item("health_potion"))
	_btn(gb, "Open inventory", func() -> void: _game.open_exclusive_menu("inventory"))

	# --- World ---
	var gw := _grid("World", 4)
	var names := {"chest": "Chest", "rare_chest": "Rare chest", "vault_chest": "Vault chest", "crate": "Crate", "urn": "Urn",
		"lever": "Trap lever", "spike_trap": "Spike trap", "brazier": "Brazier", "torch_light": "Light",
		"stairs": "Stairwell (descend)", "safe_room_kit": "Safe room (vendor, board, ward)",
		"setpiece:entrance": "Room: arrival hall", "setpiece:safe_room": "Room: safe room decor",
		"setpiece:boss_arena": "Room: boss arena decor", "setpiece:vault": "Room: vault decor", "setpiece:stairs": "Room: stair chamber"}
	for k in DungeonBuilder.TEST_OBJECTS:
		var kind: String = k
		_btn(gw, str(names.get(kind, kind)), func() -> void: _game.test_spawn_object(kind))

	# --- Player ---
	var gp := _grid("Player", 4)
	_btn(gp, "God mode on/off", func() -> void: _game.test_toggle("god"))
	_btn(gp, "Infinite stamina/magicka", func() -> void: _game.test_toggle("resources"))
	_btn(gp, "+1 level", func() -> void: _game.test_add_levels(1))
	_btn(gp, "+5 levels", func() -> void: _game.test_add_levels(5))
	_btn(gp, "Full heal", func() -> void: _game.player.recalculate_vitals(true))
	_btn(gp, "First / third person", func() -> void: _game.test_toggle("camera"))
	_btn(gp, "Die (floor reset)", func() -> void:
		_close_cb.call()
		_game.reset_floor_to_snapshot("death"))

	# --- Floor ---
	var gf := _grid("Floor", 4)
	for t in ["entrance", "combat", "safe", "boss", "vault", "stairs"]:
		var tgt: String = t
		_btn(gf, "Go to %s" % tgt, func() -> void:
			_game.test_teleport(tgt)
			_close_cb.call())
	_btn(gf, "Open boss + vault gates", func() -> void: _game.dungeon_builder.unlock_boss_and_vault())
	_btn(gf, "Pause / run floor clock", func() -> void: _game.test_toggle("clock"))
	_btn(gf, "Advance 1 day", func() -> void: _game.run_console_command("advance_days 1"))
	_btn(gf, "Collapse floor now", func() -> void:
		_close_cb.call()
		_game.reset_floor_to_snapshot("collapse"))
	_btn(gf, "Rebuild test floor", func() -> void: _game.test_set_floor(_game.floor_number, false))
	_btn(gf, "Real vast floor", func() -> void: _game.test_set_floor(_game.floor_number, true))
	_btn(gf, "Next floor", func() -> void: _game.test_set_floor(_game.floor_number + 1, _game.test_vast_floor))
	_btn(gf, "Previous floor", func() -> void: _game.test_set_floor(_game.floor_number - 1, _game.test_vast_floor))

	var close := UiTheme.button("Close  [F1]", 0, 18)
	close.pressed.connect(func() -> void: _close_cb.call())
	v.add_child(close)


func _refresh_status() -> void:
	if _game == null or _status == null:
		return
	var p := _game.player
	_status.text = "Floor %d (%s)  ·  Level %d  ·  %d gold  ·  %d items  ·  God %s  ·  AI %s  ·  Clock %s  ·  Infinite %s  ·  Spawn count %d  ·  Rarity %s" % [
		_game.floor_number, "vast floor" if _game.test_vast_floor else "test floor", _game.progression.level, p.gold, p.inventory.size(),
		"ON" if p.god_mode else "off", "frozen" if _game.test_ai_frozen else "live",
		"paused" if _game.test_clock_paused else "running", "ON" if _game.test_infinite_resources else "off", _count, _rarity]
