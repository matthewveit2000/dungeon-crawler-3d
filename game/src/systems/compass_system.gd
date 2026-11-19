class_name CompassSystem
extends RefCounted
## Tier 2 Pure System: Skyrim Top Compass Bar landmark discovery & normalized bearing math (D-016).


static func update_discoveries(landmarks: Array[Dictionary], player_pos: Vector3, compass_cfg: Dictionary) -> Array[Dictionary]:
	var disc_radius := float(compass_cfg.get("discovery_radius_meters", 28.0))
	var newly_discovered: Array[Dictionary] = []
	for lm in landmarks:
		if bool(lm.get("discovered", false)):
			continue
		var pos: Vector3 = lm["world_pos"]
		var flat_dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		if flat_dist <= disc_radius:
			lm["discovered"] = true
			newly_discovered.append(lm)
	return newly_discovered


static func compute_visible_markers(
	landmarks: Array[Dictionary],
	player_pos: Vector3,
	player_forward: Vector3,
	compass_cfg: Dictionary
) -> Array[Dictionary]:
	var visible_radius := float(compass_cfg.get("visible_radius_meters", 64.0))
	var half_fov := deg_to_rad(float(compass_cfg.get("fov_degrees", 110.0)) * 0.5)
	var fwd := Vector2(player_forward.x, player_forward.z).normalized()
	if fwd.length_squared() < 0.001:
		fwd = Vector2(0.0, -1.0)
	var right := Vector2(-fwd.y, fwd.x)

	var markers: Array[Dictionary] = []
	for lm in landmarks:
		var pos: Vector3 = lm["world_pos"]
		var delta := Vector2(pos.x - player_pos.x, pos.z - player_pos.z)
		var dist := delta.length()
		var is_disc := bool(lm.get("discovered", false))
		if not is_disc and dist > visible_radius:
			continue
		var dir := delta.normalized() if dist > 0.01 else fwd
		var angle := atan2(dir.dot(right), dir.dot(fwd))
		if absf(angle) > half_fov:
			continue
		var norm_x := clampf(angle / maxf(0.01, half_fov), -1.0, 1.0)
		markers.append({
			"id": str(lm["id"]),
			"label": str(lm["label"]) if is_disc else "?",
			"icon": str(lm["icon"]) if is_disc else "?",
			"normalized_x": norm_x,
			"distance": snappedf(dist, 0.1),
			"discovered": is_disc,
		})
	return markers


static func get_cardinal_markers(player_forward: Vector3, compass_cfg: Dictionary) -> Array[Dictionary]:
	var half_fov := deg_to_rad(float(compass_cfg.get("fov_degrees", 110.0)) * 0.5)
	var fwd := Vector2(player_forward.x, player_forward.z).normalized()
	if fwd.length_squared() < 0.001:
		fwd = Vector2(0.0, -1.0)
	var right := Vector2(-fwd.y, fwd.x)
	var cardinals := [
		{"label": "N", "dir": Vector2(0.0, -1.0)},
		{"label": "E", "dir": Vector2(1.0, 0.0)},
		{"label": "S", "dir": Vector2(0.0, 1.0)},
		{"label": "W", "dir": Vector2(-1.0, 0.0)},
	]
	var out: Array[Dictionary] = []
	for c in cardinals:
		var d: Vector2 = c["dir"]
		var angle := atan2(d.dot(right), d.dot(fwd))
		if absf(angle) <= half_fov:
			out.append({
				"label": str(c["label"]),
				"normalized_x": clampf(angle / maxf(0.01, half_fov), -1.0, 1.0),
			})
	return out
