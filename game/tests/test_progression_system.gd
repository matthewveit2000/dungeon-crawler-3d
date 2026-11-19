extends GutTest
## Automated Tests for Hybrid Progression (D-019): XP Level-Ups + Skyrim Use-to-Improve Skills.


func test_xp_grants_level_up_attribute_and_perk_points() -> void:
	var prog := ProgressionSystem.new(DataLoader.get_progression_pack())
	assert_eq(prog.level, 1)
	var gained := prog.add_xp(150.0)
	assert_eq(gained, [2])
	assert_eq(prog.attribute_points, 1)
	assert_eq(prog.perk_points, 1)

	assert_true(prog.spend_attribute("health"))
	assert_false(prog.spend_attribute("health"), "Cannot overspend attribute points")
	assert_true(prog.unlock_perk("armsman"))
	assert_false(prog.unlock_perk("armsman"), "Cannot unlock duplicate perk")

	var bonuses := prog.get_derived_bonuses()
	assert_almost_eq(float(bonuses["health_bonus"]), 15.0, 0.01)
	assert_almost_eq(float(bonuses["damage_multiplier_bonus"]), 0.15, 0.001)


func test_skyrim_use_to_improve_raises_proficiency_and_character_xp() -> void:
	var prog := ProgressionSystem.new(DataLoader.get_progression_pack())
	var leveled := false
	for i in range(6):
		var res := prog.record_skill_use("one_handed")
		if bool(res["skill_leveled_up"]):
			leveled = true
	assert_true(leveled, "Repeated sword usage must improve one_handed skill")
	assert_gt(int(prog.skill_levels["one_handed"]), 1)
	assert_gt(prog.get_proficiency_damage_multiplier("one_handed"), 1.0)
	assert_gt(prog.xp, 0.0, "Skill improvement must contribute character XP")


func test_serialization_round_trip() -> void:
	var a := ProgressionSystem.new(DataLoader.get_progression_pack())
	a.add_xp(400.0)
	a.spend_attribute("magicka")
	a.unlock_perk("arcane_surge")
	a.record_skill_use("destruction", 5.0)
	var data := a.to_dict()

	var b := ProgressionSystem.new(DataLoader.get_progression_pack())
	b.from_dict(data)
	assert_eq(b.level, a.level)
	assert_eq(b.spent_attributes["magicka"], a.spent_attributes["magicka"])
	assert_eq(b.unlocked_perks, a.unlocked_perks)
	assert_eq(b.skill_levels["destruction"], a.skill_levels["destruction"])
