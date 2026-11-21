extends GutTest
## Automated regression suite for FB-025 / D-060 (Premade CC0 Animations Trial):
## Verifies the offline CC0 first-person animation bank, seamless power-attack continuity,
## ergonomic FP elbow posture during slashes, and all 6 rigged characters' premade clips.

const DT := 1.0 / 120.0


func test_fp_premade_animation_bank_loads_with_cc0_provenance_and_all_clips() -> void:
	var bank := ViewmodelRig.get_fp_bank()
	assert_eq(str(bank.get("schema", "")), "fp_premade_animations_v1", "FP bank schema version matches")
	assert_eq(str(bank.get("license", "")), "CC0-1.0", "FP bank is strictly CC0-1.0 (D-004)")

	var clips: Dictionary = bank.get("clips", {})
	var required_clips := [
		"sword_idle", "sword_walk", "sword_sprint",
		"sword_light_1", "sword_light_2", "sword_charge", "sword_power",
		"axe_idle", "axe_sprint",
		"axe_light_1", "axe_light_2", "axe_charge", "axe_power",
		"spell_idle_l", "spell_cast_l",
	]
	for cname in required_clips:
		assert_true(clips.has(cname), "FP bank includes premade clip '%s'" % cname)
		var c: Dictionary = clips[cname]
		assert_eq(str(c.get("license", "")), "CC0-1.0", "Clip '%s' is CC0-1.0" % cname)
		assert_false(str(c.get("source", "")).is_empty(), "Clip '%s' records upstream source provenance" % cname)
		assert_gte((c.get("frames", []) as Array).size(), 6, "Clip '%s' has dense sampled frames" % cname)

	var curves: Dictionary = bank.get("curves", {})
	for cv_name in ["bow_draw", "bow_release", "shield_hit"]:
		assert_true(curves.has(cv_name), "FP bank includes premade curve '%s'" % cv_name)
		assert_gte((curves[cv_name].get("samples", []) as Array).size(), 6, "Curve '%s' has dense samples" % cv_name)

	# Power charge end frame must seamlessly match power release frame 0
	var sw_ch_end: Vector3 = clips["sword_charge"]["frames"][-1][0]
	var sw_pw_start: Vector3 = clips["sword_power"]["frames"][0][0]
	assert_lt(sw_ch_end.distance_to(sw_pw_start), 0.005, "sword_charge flows seamlessly into sword_power")

	var ax_ch_end: Vector3 = clips["axe_charge"]["frames"][-1][0]
	var ax_pw_start: Vector3 = clips["axe_power"]["frames"][0][0]
	assert_lt(ax_ch_end.distance_to(ax_pw_start), 0.005, "axe_charge flows seamlessly into axe_power")


func test_fp_sword_elbows_stay_ergonomically_below_eye_during_slashes() -> void:
	DataLoader.ensure_loaded()
	var p := PlayerController.new()
	add_child_autofree(p)
	p.setup(DataLoader.get_player(), ProgressionSystem.new(DataLoader.get_progression_pack()), SeededRng.new(7), {})
	p.set_camera_mode("first_person")
	p.quick_equip_preset(1)
	p._equip_raise = 0.0
	for _i in range(40):
		p.step_simulation(DT, false, {})

	for step_kind in ["light_1", "light_2", "power"]:
		p.stamina = p.max_stamina
		p._right_cooldown = 0.0
		p.handle_hand_press("right_hand")
		var hold := 0.5 if step_kind == "power" else DT
		var t := 0.0
		while t < hold:
			p.step_simulation(DT, false, {})
			t += DT
		p.handle_hand_release("right_hand")
		var max_elbow_above_wrist := -99.0
		for _i in range(int(0.85 / DT)):
			p.step_simulation(DT, false, {})
			var elbow_pos := p.fp_right_anchor.transform * ViewmodelRig.FP_ELBOW_GRIP
			var wrist_pos := p.fp_right_anchor.position
			max_elbow_above_wrist = maxf(max_elbow_above_wrist, elbow_pos.y - wrist_pos.y)
		assert_lt(max_elbow_above_wrist, 0.10,
			"FP sword %s elbow never flips high above wrist (max dy=%.3f)" % [step_kind, max_elbow_above_wrist])


func test_all_rigged_characters_ship_premade_clips_with_motion_and_grounded_deaths() -> void:
	var expected := {
		"crawler": ["idle", "idle_combat", "idle_dual", "walk", "run", "attack", "attack_2h", "attack_dual", "attack_l", "block", "cast", "cast_r", "cast_dual", "bow_draw", "draw_hold", "bow_shoot", "hit", "death"],
		"draugr": ["idle", "idle_combat", "walk", "run", "attack", "hit", "death"],
		"bone_archer": ["idle", "idle_combat", "walk", "run", "shoot", "attack", "hit", "death"],
		"goblin": ["idle", "idle_combat", "walk", "run", "attack", "hit", "death"],
		"iron_warden": ["idle", "idle_combat", "walk", "run", "roar", "slam", "attack", "hit", "death"],
		"vendor": ["idle", "idle_combat", "walk", "run", "talk", "hit", "death"],
	}
	for kind in expected:
		var cv := CharacterVisual.create(kind)
		add_child_autofree(cv)
		await get_tree().process_frame
		assert_not_null(cv.anim, "%s has AnimationPlayer" % kind)
		for clip in expected[kind]:
			assert_true(cv.has_anim(clip), "%s exposes premade clip '%s'" % [kind, clip])
			var anim := cv.anim.get_animation(clip)
			assert_gt(anim.length, 0.4, "%s clip '%s' has real duration (%.2fs)" % [kind, clip, anim.length])

		# Verify death settles cleanly above the flagstones (no underground corpses)
		var skel := cv.model.find_child("GeneralSkeleton", true, false) as Skeleton3D
		if skel == null:
			skel = _find_skeleton(cv.model)
		assert_not_null(skel, "%s has Skeleton3D" % kind)
		var death_anim := cv.anim.get_animation("death")
		cv.anim.play("death", 0.0)
		cv.anim.seek(death_anim.length, true)
		cv.anim.pause()
		await get_tree().process_frame
		var hips_idx := skel.find_bone("hips")
		assert_gte(hips_idx, 0, "%s skeleton has hips bone" % kind)
		var hips_y := (skel.global_transform * skel.get_bone_global_pose(hips_idx)).origin.y - cv.global_position.y
		assert_gt(hips_y, 0.03, "%s death rests cleanly above floor (hips_y=%.3f)" % [kind, hips_y])


func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null
