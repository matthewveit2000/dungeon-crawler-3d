class_name FloorTimer
extends RefCounted
## Tier 2 Pure System: 5 In-Game Day Floor Collapse Timer (D-006, D-016).
## 5 in-game days per floor at ~30 real minutes per in-game day (from world.json).
## Freezes cleanly when any Skyrim menu is open; emits threshold warnings and collapse state.

var days_per_floor: int = 5
var seconds_per_day: float = 1800.0
var remaining_seconds: float = 9000.0
var _warning_thresholds: Array[float] = []
var _triggered_warnings: Dictionary = {}
var collapsed: bool = false


func _init(timer_cfg: Dictionary) -> void:
	days_per_floor = int(timer_cfg.get("days_per_floor", 5))
	seconds_per_day = float(timer_cfg.get("real_seconds_per_in_game_day", 1800.0))
	_warning_thresholds.clear()
	for w in timer_cfg.get("warning_thresholds_days_left", [3.0, 1.0, 0.25]):
		_warning_thresholds.append(float(w))
	reset()


func reset() -> void:
	remaining_seconds = float(days_per_floor) * seconds_per_day
	_triggered_warnings.clear()
	collapsed = false


func tick(delta: float, is_paused: bool = false) -> Dictionary:
	var result := {"collapsed_now": false, "warning_days_left": -1.0}
	if is_paused or collapsed or delta <= 0.0:
		return result

	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	var days_left := get_days_remaining()

	for threshold in _warning_thresholds:
		if days_left <= threshold and not _triggered_warnings.has(threshold) and remaining_seconds > 0.0:
			_triggered_warnings[threshold] = true
			result["warning_days_left"] = threshold

	if remaining_seconds <= 0.0:
		collapsed = true
		result["collapsed_now"] = true
	return result


func advance_days(days: float) -> Dictionary:
	return tick(days * seconds_per_day, false)


func get_days_remaining() -> float:
	return remaining_seconds / maxf(1.0, seconds_per_day)


func get_elapsed_days() -> float:
	return float(days_per_floor) - get_days_remaining()


func get_current_day_number() -> int:
	return clampi(int(floor(get_elapsed_days())) + 1, 1, days_per_floor)


func get_formatted_clock() -> String:
	var elapsed := get_elapsed_days()
	var day_num := get_current_day_number()
	var frac_day: float = elapsed - floorf(elapsed)
	var total_hours: float = frac_day * 24.0
	var hh := int(floorf(total_hours)) % 24
	var mm := int(floorf((total_hours - floorf(total_hours)) * 60.0)) % 60
	return "Day %d / %d  (%02d:%02d)  |  %.2fd until collapse" % [day_num, days_per_floor, hh, mm, get_days_remaining()]


func to_dict() -> Dictionary:
	var triggered_list: Array = []
	for k in _triggered_warnings.keys():
		triggered_list.append(float(k))
	return {
		"remaining_seconds": remaining_seconds,
		"collapsed": collapsed,
		"triggered_warnings": triggered_list,
	}


func from_dict(data: Dictionary) -> void:
	remaining_seconds = clampf(float(data.get("remaining_seconds", float(days_per_floor) * seconds_per_day)), 0.0, float(days_per_floor) * seconds_per_day)
	collapsed = bool(data.get("collapsed", remaining_seconds <= 0.0))
	_triggered_warnings.clear()
	for w in data.get("triggered_warnings", []):
		_triggered_warnings[float(w)] = true
