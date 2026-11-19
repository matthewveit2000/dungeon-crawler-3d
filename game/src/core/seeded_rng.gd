class_name SeededRng
extends RefCounted
## Deterministic named-stream PRNG manager.
## Prevents unseeded randomness anywhere in the codebase and guarantees
## reproducible floor generation, loot rolls, combat crits, and AI behavior.

var _master_seed: int = 1337
var _streams: Dictionary = {}


func _init(master_seed: int = 1337) -> void:
	reseed(master_seed)


func reseed(master_seed: int) -> void:
	_master_seed = master_seed
	_streams.clear()


func get_master_seed() -> int:
	return _master_seed


func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng := RandomNumberGenerator.new()
		rng.seed = _derive_seed(_master_seed, stream_name)
		_streams[stream_name] = rng
	return _streams[stream_name]


func next_float(stream_name: String) -> float:
	return stream(stream_name).randf()


func next_float_range(stream_name: String, min_val: float, max_val: float) -> float:
	return stream(stream_name).randf_range(min_val, max_val)


func next_int_range(stream_name: String, min_val: int, max_val: int) -> int:
	return stream(stream_name).randi_range(min_val, max_val)


func pick_array(stream_name: String, items: Array) -> Variant:
	if items.is_empty():
		return null
	var idx := next_int_range(stream_name, 0, items.size() - 1)
	return items[idx]


func pick_weighted(stream_name: String, items: Array, weight_key: String = "weight") -> Variant:
	if items.is_empty():
		return null
	var total := 0.0
	for item in items:
		total += maxf(0.0, float(item.get(weight_key, 0.0)))
	if total <= 0.0:
		return items[0]
	var roll := next_float(stream_name) * total
	var acc := 0.0
	for item in items:
		acc += maxf(0.0, float(item.get(weight_key, 0.0)))
		if roll <= acc:
			return item
	return items[items.size() - 1]


static func _derive_seed(base_seed: int, label: String) -> int:
	var combined := "%d::%s" % [base_seed, label]
	return int(combined.hash())
