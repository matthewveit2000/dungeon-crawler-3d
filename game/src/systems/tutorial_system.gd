class_name TutorialSystem
extends RefCounted
## Tier 2 Pure System: Low-Friction Toggleable Interactive Tutorial Mode (D-030).
## Surfaces brief, non-blocking contextual walkthrough hints the FIRST time a player
## interacts with each mechanic, auto-completes when performed, and never interrupts flow.

var enabled: bool = true
var auto_dismiss_seconds: float = 14.0
var _topics_by_id: Dictionary = {}
var seen_ids: Dictionary = {}
var completed_ids: Dictionary = {}
var current_topic_id: String = ""
var current_timer: float = 0.0
var _queue: Array[String] = []


func _init(tutorials_cfg: Dictionary) -> void:
	enabled = bool(tutorials_cfg.get("default_enabled", true))
	auto_dismiss_seconds = float(tutorials_cfg.get("auto_dismiss_seconds", 14.0))
	for topic in tutorials_cfg.get("topics", []):
		_topics_by_id[str(topic["id"])] = topic


func set_enabled(p_enabled: bool) -> void:
	enabled = p_enabled
	if not enabled:
		current_topic_id = ""
		current_timer = 0.0
		_queue.clear()


func reset_tutorials() -> void:
	seen_ids.clear()
	completed_ids.clear()
	current_topic_id = ""
	current_timer = 0.0
	_queue.clear()


func trigger_hint(topic_id: String) -> Dictionary:
	if not enabled or not _topics_by_id.has(topic_id):
		return {}
	if seen_ids.has(topic_id) or completed_ids.has(topic_id):
		return {}
	seen_ids[topic_id] = true
	if current_topic_id.is_empty():
		current_topic_id = topic_id
		current_timer = auto_dismiss_seconds
		return get_active_hint()
	if not _queue.has(topic_id):
		_queue.append(topic_id)
	return {}


func complete_hint(topic_id: String) -> bool:
	if not _topics_by_id.has(topic_id):
		return false
	completed_ids[topic_id] = true
	seen_ids[topic_id] = true
	_queue.erase(topic_id)
	if current_topic_id == topic_id:
		_advance_queue()
		return true
	return false


func dismiss_current() -> void:
	if not current_topic_id.is_empty():
		seen_ids[current_topic_id] = true
		_advance_queue()


func tick(delta: float, is_paused: bool = false) -> bool:
	if not enabled or is_paused or current_topic_id.is_empty():
		return false
	current_timer -= delta
	if current_timer <= 0.0:
		_advance_queue()
		return true
	return false


func get_active_hint() -> Dictionary:
	if not enabled or current_topic_id.is_empty():
		return {}
	var base: Dictionary = _topics_by_id.get(current_topic_id, {})
	if base.is_empty():
		return {}
	var res := base.duplicate(true)
	res["remaining_sec"] = current_timer
	res["completed_count"] = completed_ids.size()
	res["total_count"] = _topics_by_id.size()
	return res


func _advance_queue() -> void:
	if _queue.is_empty():
		current_topic_id = ""
		current_timer = 0.0
	else:
		current_topic_id = _queue.pop_front()
		current_timer = auto_dismiss_seconds


func to_dict() -> Dictionary:
	return {
		"enabled": enabled,
		"seen_ids": seen_ids.keys(),
		"completed_ids": completed_ids.keys(),
	}


func from_dict(data: Dictionary) -> void:
	enabled = bool(data.get("enabled", true))
	seen_ids.clear()
	completed_ids.clear()
	for k in data.get("seen_ids", []):
		seen_ids[str(k)] = true
	for k in data.get("completed_ids", []):
		completed_ids[str(k)] = true
	current_topic_id = ""
	current_timer = 0.0
	_queue.clear()
