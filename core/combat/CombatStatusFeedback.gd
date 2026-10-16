extends RefCounted

## Application-only presentation gate shared by authoritative enemy handles
## and legacy actors. Nothing ticks here: callers announce state transitions,
## while repeated applications are quiet and a dense fight has a fixed budget.
const StatusIcons := preload("res://core/combat/CombatStatusIcons.gd")
const COOLDOWN_MS := 1500
const MAX_PER_FRAME := 8
const MAX_TARGETS := 512
const PRUNE_INTERVAL_MS := 500
const VIEW_MARGIN := 80.0

# Positive keys are generation-bearing EnemyWorld handles. Negative keys
# identify actors that have no authoritative world record.
static var _targets: Dictionary = {}
static var _budget_frame := -1
static var _frame_count := 0
static var _next_prune_at := 0


static func notify_handle(handle: int, id: StringName) -> bool:
	if EnemyWorld == null or not EnemyWorld.is_valid_handle(handle) or EnemyWorld.is_dying(handle):
		return false
	return notify_at(EnemyWorld.get_position(handle), id, handle)


static func notify_actor(actor: Node2D, id: StringName) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return false
	if "dead" in actor and bool(actor.get("dead")):
		return false
	if EnemyWorld != null:
		var handle := EnemyWorld.handle_for_actor(actor)
		if handle != 0:
			return notify_handle(handle, id)
	return notify_at(actor.global_position, id, -int(actor.get_instance_id()))


static func notify_at(pos: Vector2, id: StringName, target_key: int) -> bool:
	if BattleText == null or not BattleText.callouts_enabled() or not StatusIcons.known(id):
		return false
	# A headless suite or a world without an active camera still receives
	# feedback. A real camera culls positions beyond the visible fight.
	var viewport := BattleText.get_viewport()
	if viewport != null and viewport.get_camera_2d() != null:
		if not viewport.get_visible_rect().grow(VIEW_MARGIN).has_point(viewport.get_canvas_transform() * pos):
			return false
	var now := Time.get_ticks_msec()
	var frame := Engine.get_process_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_frame_count = 0
	if _frame_count >= MAX_PER_FRAME:
		return false
	var statuses: Dictionary = _targets.get(target_key, {})
	if statuses.has(id) and now - int(statuses[id]) < COOLDOWN_MS:
		return false
	if now >= _next_prune_at or (not _targets.has(target_key) and _targets.size() >= MAX_TARGETS):
		_prune_expired(now)
		_next_prune_at = now + PRUNE_INTERVAL_MS
	if not _targets.has(target_key):
		if _targets.size() >= MAX_TARGETS:
			_evict_oldest_target()
		statuses = {}
		_targets[target_key] = statuses
	statuses[id] = now
	_frame_count += 1
	BattleText.status_popup(pos, id)
	return true


static func _prune_expired(now: int) -> void:
	for target: int in _targets.keys():
		var statuses: Dictionary = _targets[target]
		for id: StringName in statuses.keys():
			if now - int(statuses[id]) >= COOLDOWN_MS:
				statuses.erase(id)
		if statuses.is_empty():
			_targets.erase(target)


static func _evict_oldest_target() -> void:
	var oldest_key := 0
	var oldest_time := 9223372036854775807
	for target: int in _targets:
		var newest := 0
		for stamp: int in _targets[target].values():
			newest = maxi(newest, stamp)
		if newest < oldest_time:
			oldest_time = newest
			oldest_key = target
	_targets.erase(oldest_key)


static func clear() -> void:
	_targets.clear()
	_budget_frame = -1
	_frame_count = 0
	_next_prune_at = 0
