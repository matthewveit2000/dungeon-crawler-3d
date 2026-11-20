extends Node3D
## First-Person Pose Probe — fast iteration tool for first-person viewmodel animation.
## Drives a bare PlayerController through each first-person move and saves sampled frames as
## 3-up strips: [player's view | side view from the right | top-down view] so hand/weapon
## orientation can be judged in 3D, not just from the camera.
##
## Run via ./scripts/fp-pose-probe.sh [out_dir] [only_csv]
## Sequences: sword, axe, spell, bow, shield, dual

const W := 560
const H := 315

var out_dir := ""
var only: PackedStringArray = PackedStringArray()
var player: PlayerController = null
var _side_vp: SubViewport = null
var _side_cam: Camera3D = null
var _top_vp: SubViewport = null
var _top_cam: Camera3D = null
var _fp_vp: SubViewport = null
var _dt := 1.0 / 30.0
var _seq := ""
var _idx := 0
var _label := ""


func _ready() -> void:
	out_dir = OS.get_environment("PROBE_OUT")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("res://../art/fp_probe")
	var env_only := OS.get_environment("PROBE_ONLY")
	if not env_only.is_empty():
		only = env_only.split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("_run")


func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)


func _wait(n: int = 1) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _build_stage() -> void:
	DataLoader.ensure_loaded()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.15, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.52, 0.5)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 25, 0)
	key.light_energy = 1.3
	add_child(key)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.28, 0.24)
	fl.material_override = fm
	add_child(fl)
	# Distant reference wall with a grid so the sightline / crosshair is easy to judge
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(30, 8, 0.2)
	wall.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.42, 0.38, 0.34)
	wall.material_override = wm
	wall.position = Vector3(0, 4, -8)
	add_child(wall)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	cs.shape = box
	cs.position.y = -0.5
	col.add_child(cs)
	add_child(col)


func _make_vp(fov: float, ortho: bool = false) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.02
	if ortho:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 1.4
	vp.add_child(cam)
	cam.current = true
	return [vp, cam]


func _run() -> void:
	_build_stage()
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	var prog := ProgressionSystem.new(DataLoader.get_progression_pack())
	player.setup(DataLoader.get_player(), prog, SeededRng.new(7), {})
	player.global_position = Vector3(0, 0, 0)
	player.max_stamina = 9999.0
	player.max_magicka = 9999.0
	var a := _make_vp(70.0)
	_fp_vp = a[0]
	var fp_cam: Camera3D = a[1]
	fp_cam.fov = player.camera.fov
	fp_cam.near = player.camera.near
	var b := _make_vp(40.0, true)
	_side_vp = b[0]
	_side_cam = b[1]
	var c := _make_vp(40.0, true)
	_top_vp = c[0]
	_top_cam = c[1]
	await _wait(3)

	if _want("sword"):
		await _seq_sword()
	if _want("axe"):
		await _seq_axe()
	if _want("spell"):
		await _seq_spell()
	if _want("bow"):
		await _seq_bow()
	if _want("shield"):
		await _seq_shield()
	if _want("dual"):
		await _seq_dual()
	print("[fp-probe] done -> %s" % out_dir)
	get_tree().quit(0)


func _begin(seq: String, preset: int) -> void:
	_seq = seq
	_idx = 0
	DirAccess.make_dir_recursive_absolute(out_dir.path_join(seq))
	player.set_camera_mode("first_person")
	if preset > 0:
		player.quick_equip_preset(preset)
	player.refresh_hand_visuals()
	player._equip_raise = 0.0
	player.stamina = player.max_stamina
	player.magicka = player.max_magicka
	for _i in range(20):
		player.step_simulation(_dt, false, {})
	await _wait(1)


func _sync_cams() -> void:
	var ct := player.camera.global_transform
	# FP copy (so all three views come from one rendered frame)
	(_fp_vp.get_child(0) as Camera3D).global_transform = ct
	(_fp_vp.get_child(0) as Camera3D).fov = player.camera.fov
	# Side view: from the player's right, level with the hands, looking left
	var focus := ct * Vector3(0.0, -0.22, -0.45)
	_side_cam.global_transform = Transform3D(Basis(), ct * Vector3(1.6, -0.22, -0.45)).looking_at(focus, ct.basis.y)
	# Top view: from above the hands looking down, camera forward = screen up
	_top_cam.global_transform = Transform3D(Basis(), ct * Vector3(0.0, 1.6, -0.45)).looking_at(focus, -ct.basis.z)


## Simulates `secs` seconds; saves a strip every `every` simulated frames.
func _sim(label: String, secs: float, input: Dictionary = {}, every: int = 3) -> void:
	_label = label
	var n := int(round(secs / _dt))
	for i in range(n):
		player.step_simulation(_dt, false, input)
		if every > 0 and i % every == 0:
			await _snap()


func _snap() -> void:
	_sync_cams()
	await _wait(1)
	var img := Image.create(W * 3, H, false, Image.FORMAT_RGBA8)
	var views := [_fp_vp, _side_vp, _top_vp]
	for k in range(3):
		var vi: Image = (views[k] as SubViewport).get_texture().get_image()
		vi.convert(Image.FORMAT_RGBA8)
		img.blit_rect(vi, Rect2i(0, 0, W, H), Vector2i(W * k, 0))
	# crosshair marker on the FP view
	for d in range(-6, 7):
		img.set_pixel(W / 2 + d, H / 2, Color(0, 1, 0))
		img.set_pixel(W / 2, H / 2 + d, Color(0, 1, 0))
	img.save_png(out_dir.path_join(_seq).path_join("%03d_%s.png" % [_idx, _label]))
	_idx += 1


func _press_release(hand: String) -> void:
	player._right_cooldown = 0.0
	player._left_cooldown = 0.0
	player.handle_hand_press(hand)
	player.step_simulation(_dt, false, {})
	player.handle_hand_release(hand)


func _seq_sword() -> void:
	await _begin("sword", 1)
	await _sim("idle", 0.2, {}, 3)
	_press_release("right_hand")
	await _sim("light1", 0.5, {}, 1)
	await _sim("settle", 0.2, {}, 0)
	_press_release("right_hand")
	await _sim("light2", 0.5, {}, 1)
	await _sim("settle", 0.3, {}, 0)
	player._right_cooldown = 0.0
	player.handle_hand_press("right_hand")
	await _sim("charge", 0.6, {}, 4)
	player.handle_hand_release("right_hand")
	await _sim("power", 0.65, {}, 1)


func _seq_axe() -> void:
	await _begin("axe", 2)
	await _sim("idle", 0.2, {}, 3)
	_press_release("right_hand")
	await _sim("light1", 0.62, {}, 1)
	await _sim("settle", 0.2, {}, 0)
	_press_release("right_hand")
	await _sim("light2", 0.62, {}, 1)
	await _sim("settle", 0.3, {}, 0)
	player._right_cooldown = 0.0
	player.handle_hand_press("right_hand")
	await _sim("charge", 0.6, {}, 4)
	player.handle_hand_release("right_hand")
	await _sim("power", 0.72, {}, 1)


func _seq_spell() -> void:
	await _begin("spell", 3)
	await _sim("idle", 0.2, {}, 3)
	player.handle_hand_press("left_hand")
	await _sim("castL", 0.42, {}, 2)
	# right-hand spell: swap the sword for a spell in the right hand
	player._equip_by_id_if_owned("spell_chain_spark", "right_hand")
	player._equip_raise = 0.0
	await _sim("settle", 0.5, {}, 0)
	await _sim("idleRL", 0.1, {}, 3)
	player.handle_hand_press("right_hand")
	await _sim("castR", 0.42, {}, 2)


func _seq_bow() -> void:
	await _begin("bow", 4)
	await _sim("idle", 0.2, {}, 3)
	player.handle_hand_press("right_hand")
	await _sim("draw", 1.2, {}, 4)
	player.handle_hand_release("right_hand")
	await _sim("release", 0.9, {}, 3)


func _seq_shield() -> void:
	await _begin("shield", 1)
	await _sim("block", 0.5, {"left_held": true}, 3)
	await _sim("lower", 0.4, {}, 3)


func _seq_dual() -> void:
	await _begin("dual", 1)
	var cleaver := DataLoader.get_item_def("sponsored_blade_ratings")
	player.equipment["left_hand"] = LootGenerator.make_base_item_instance(cleaver, "probe_left")
	player.refresh_hand_visuals()
	player._equip_raise = 0.0
	await _sim("idle", 0.2, {}, 3)
	player.handle_hand_press("left_hand")
	await _sim("left1", 0.45, {}, 2)
	player._left_cooldown = 0.0
	player.handle_hand_press("left_hand")
	await _sim("left2", 0.45, {}, 2)

