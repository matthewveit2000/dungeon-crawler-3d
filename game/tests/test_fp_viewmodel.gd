extends GutTest
## First-person viewmodel rules (D-040), checked from the player's point of view in rig (camera) space:
## forearms always run back toward the player, cuts travel edge-first out in front of the camera, both fists
## sit on the battleaxe's leather wraps, spell palms face the target, and the drawn bow sits left of the
## crosshair with the arrow nocked only while drawing.

const DT := 1.0 / 120.0
## Forearm direction in each arm mesh's own space (wrist -> elbow), see build_gear.py
const GRIP_FOREARM := Vector3(0.0, -0.571, 0.821)
const OPEN_FOREARM := Vector3(0.0, -0.217, 0.976)

var p: PlayerController = null


func before_each() -> void:
	DataLoader.ensure_loaded()
	p = PlayerController.new()
	add_child_autofree(p)
	p.setup(DataLoader.get_player(), ProgressionSystem.new(DataLoader.get_progression_pack()), SeededRng.new(3), {})
	p.set_camera_mode("first_person")


func _settle(preset: int) -> void:
	p.quick_equip_preset(preset)
	p._equip_raise = 0.0
	for _i in range(60):
		p.step_simulation(DT, false, {})


func _forearm(anchor: Node3D, local_dir: Vector3) -> Vector3:
	return (anchor.transform.basis * local_dir).normalized()


func _weapon_basis() -> Basis:
	return p.fp_right_anchor.transform.basis * p._fp_right_weapon_holder.transform.basis


## Starts a right-hand attack (power = held past the charge time) and returns the min forearm "toward the
## player" component (rig +Z) seen over the whole swing, for the right (and left, for two-handers) arm.
## Hoisting a weapon overhead legitimately brings the elbows level with the fists (z ~ 0); an inverted arm
## (elbow well out in front of the hand, like the old palm-backwards spell arms at z ~ -1) must never happen.
func _swing_min_forearm_z(power: bool, two_hand: bool) -> float:
	p.stamina = p.max_stamina
	p._right_cooldown = 0.0
	p.handle_hand_press("right_hand")
	var hold := 0.5 if power else DT
	var t := 0.0
	var min_z := 1.0
	while t < hold:
		p.step_simulation(DT, false, {})
		t += DT
		min_z = minf(min_z, _forearm(p.fp_right_anchor, GRIP_FOREARM).z)
	p.handle_hand_release("right_hand")
	for _i in range(int(1.0 / DT)):
		p.step_simulation(DT, false, {})
		min_z = minf(min_z, _forearm(p.fp_right_anchor, GRIP_FOREARM).z)
		if two_hand:
			min_z = minf(min_z, _forearm(p.fp_left_anchor, GRIP_FOREARM).z)
	return min_z


## Starts a light right-hand attack and steps until the swing reaches normalized time u.
func _light_swing_to(u: float) -> void:
	p.stamina = p.max_stamina
	p._right_cooldown = 0.0
	p.handle_hand_press("right_hand")
	p.step_simulation(DT, false, {})
	p.handle_hand_release("right_hand")
	while 1.0 - p._right_swing_t / p._right_swing_dur < u:
		p.step_simulation(DT, false, {})


func test_forearms_never_point_away_from_the_player_during_any_attack() -> void:
	_settle(1)
	for power in [false, false, true]:
		var mz := _swing_min_forearm_z(power, false)
		assert_gt(mz, -0.2, "sword elbow never swings out ahead of the fist (power=%s, min z=%.2f)" % [power, mz])
	_settle(2)
	for power in [false, false, true]:
		var mz := _swing_min_forearm_z(power, true)
		assert_gt(mz, -0.2, "battleaxe elbows never swing out ahead of the fists (power=%s, min z=%.2f)" % [power, mz])


func test_battleaxe_edge_faces_forward_at_rest_and_leads_the_chop() -> void:
	_settle(2)
	var edge_rest := _weapon_basis().x.normalized()
	assert_gt(edge_rest.dot(Vector3.FORWARD), 0.5, "idle axe edge faces away from the player, not sideways (%s)" % edge_rest)
	_light_swing_to(0.46)
	var edge_hit := _weapon_basis().x.normalized()
	var travel := Vector3(-0.45, -0.89, 0.0).normalized()
	assert_gt(edge_hit.dot(travel), 0.8, "opening chop drives down-left edge-first at impact (%s)" % edge_hit)


func test_both_fists_sit_on_the_battleaxe_leather_wraps() -> void:
	_settle(2)
	var w := p.fp_right_anchor.transform * p._fp_right_weapon_holder.transform
	var r_local := w.affine_inverse() * p.fp_right_anchor.position
	var l_local := w.affine_inverse() * p.fp_left_anchor.position
	assert_almost_eq(Vector2(r_local.x, r_local.z).length(), 0.0, 0.005, "right fist centred on the haft")
	assert_almost_eq(Vector2(l_local.x, l_local.z).length(), 0.0, 0.005, "left fist centred on the haft")
	assert_between(r_local.y, 0.42, 0.60, "right fist on the upper leather wrap (y=%.2f)" % r_local.y)
	assert_between(l_local.y, -0.25, -0.05, "left fist on the lower leather wrap (y=%.2f)" % l_local.y)


func test_sword_cut_extends_out_in_front_of_the_player() -> void:
	_settle(1)
	_light_swing_to(0.42)
	var blade := _weapon_basis().y.normalized()
	assert_lt(blade.z, -0.5, "at impact the blade points away from the camera into the world (%s)" % blade)
	assert_lt(p.fp_right_anchor.position.z, -0.45, "the sword hand is extended out in front at impact")


func test_spell_palms_face_the_target_with_the_back_of_the_hand_toward_the_player() -> void:
	_settle(3)
	var palm := -p.fp_left_anchor.transform.basis.z.normalized()
	assert_gt(palm.dot(Vector3.FORWARD), 0.7, "idle spell palm faces the target (%s)" % palm)
	assert_gt(_forearm(p.fp_left_anchor, OPEN_FOREARM).z, 0.5, "spell forearm runs back toward the player")
	p.magicka = p.max_magicka
	p.handle_hand_press("left_hand")
	while 1.0 - p._left_action_t / p._left_action_dur < 0.42:
		p.step_simulation(DT, false, {})
	palm = -p.fp_left_anchor.transform.basis.z.normalized()
	assert_gt(palm.dot(Vector3.FORWARD), 0.9, "the cast thrusts the open palm at the crosshair (%s)" % palm)
	assert_lt(p.fp_left_anchor.position.z, -0.6, "the casting hand pushes out toward the target")


func test_drawn_bow_stands_upright_left_of_the_crosshair() -> void:
	_settle(4)
	assert_false(p._fp_nocked_arrow.visible, "no arrow nocked at idle")
	p.handle_hand_press("right_hand")
	for _i in range(int(1.2 / DT)):
		p.step_simulation(DT, false, {})
	assert_true(p._fp_nocked_arrow.visible)
	assert_lt(p.fp_left_anchor.position.x, -0.03, "bow hand sits left of the crosshair at full draw")
	assert_gt(p.fp_left_anchor.transform.basis.y.normalized().dot(Vector3.UP), 0.95, "bow stands upright at full draw")
	assert_gt(p.fp_right_anchor.position.z, -0.2, "drawing hand is pulled back to the cheek")
	p.handle_hand_release("right_hand")
	p.step_simulation(DT, false, {})
	assert_false(p._fp_nocked_arrow.visible, "the arrow leaves the string on release")
