extends GutTest
## Phase 1 Tests: SeededRng determinism, stream isolation, and weighted selection.


func test_same_seed_produces_identical_sequence() -> void:
	var a := SeededRng.new(4242)
	var b := SeededRng.new(4242)
	for i in range(25):
		assert_eq(a.next_int_range("gen", 0, 100000), b.next_int_range("gen", 0, 100000))
		assert_almost_eq(a.next_float("loot"), b.next_float("loot"), 0.000001)


func test_different_seeds_diverge() -> void:
	var a := SeededRng.new(100)
	var b := SeededRng.new(200)
	var matches := 0
	for i in range(15):
		if a.next_int_range("gen", 0, 100000) == b.next_int_range("gen", 0, 100000):
			matches += 1
	assert_lt(matches, 3, "Distinct seeds must not generate identical sequences")


func test_streams_are_isolated() -> void:
	var a := SeededRng.new(777)
	var b := SeededRng.new(777)
	for i in range(50):
		a.next_float("combat")
	assert_eq(a.next_int_range("gen", 0, 99999), b.next_int_range("gen", 0, 99999))


func test_pick_weighted_respects_zero_and_positive_weights() -> void:
	var rng := SeededRng.new(99)
	var entries := [
		{"id": "never", "weight": 0.0},
		{"id": "always", "weight": 10.0},
	]
	for i in range(20):
		var picked: Dictionary = rng.pick_weighted("loot", entries)
		assert_eq(picked["id"], "always")
