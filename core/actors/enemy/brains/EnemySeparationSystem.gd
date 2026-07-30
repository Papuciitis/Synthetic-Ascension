extends Node
class_name EnemySeparationSystem

@export var cell_size: float = 64.0
@export var rebuild_every_ms: int = 250 # fallback only (when EnemyIndex autoload is not enabled)

# Fallback buckets (ONLY used if /root/EnemyIndex is missing)
var _buckets: Dictionary = {} # Vector2i -> Array[EnemyActor]
var _last_rebuild_msec: int = -999999

# Cache autoload reference
var _ei: Node = null

func _ready() -> void:
	add_to_group(&"enemy_sep")
	set_physics_process(false) # no per-frame rebuilds

func _get_ei() -> Node:
	if _ei == null or not is_instance_valid(_ei):
		_ei = get_node_or_null("/root/EnemyIndex")
		# If EnemyIndex exists, keep its cell size in sync with this node for consistent behavior.
		if _ei != null and is_instance_valid(_ei) and "cell_size" in _ei:
			_ei.set("cell_size", cell_size)
	return _ei

func _maybe_rebuild_fallback() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_rebuild_msec < rebuild_every_ms:
		return
	_last_rebuild_msec = now

	_buckets.clear()
	var cs: float = maxf(cell_size, 1.0)

	# This is a fallback path only; avoid in hot loops if possible.
	var enemies: Array = get_tree().get_nodes_in_group(&"enemies")
	for n in enemies:
		var e := n as EnemyActor
		if e == null or e.dead:
			continue
		var pos: Vector2 = e.global_position
		var cell := Vector2i(floori(pos.x / cs), floori(pos.y / cs))
		var arr = _buckets.get(cell)
		if arr == null:
			arr = []
			_buckets[cell] = arr
		arr.append(e)

func sample_sep(e: EnemyActor, radius: float, max_neighbors: int = 8) -> Vector2:
	if e == null or not is_instance_valid(e) or e.dead:
		return Vector2.ZERO
	if radius <= 0.0:
		return Vector2.ZERO

	var ei := _get_ei()
	if ei != null and is_instance_valid(ei) and ei.has_method("sample_sep"):
		return ei.call("sample_sep", e, radius, max_neighbors) as Vector2

	# fallback buckets
	_maybe_rebuild_fallback()

	var cs: float = maxf(cell_size, 1.0)
	var pos: Vector2 = e.global_position
	var cx: int = floori(pos.x / cs)
	var cy: int = floori(pos.y / cs)
	var cell_range: int = max(1, ceili(radius / cs))

	var r2: float = radius * radius
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0

	for oy in range(-cell_range, cell_range + 1):
		for ox in range(-cell_range, cell_range + 1):
			var cell := Vector2i(cx + ox, cy + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var other := n as EnemyActor
				if other == null or other == e or other.dead:
					continue
				var d: Vector2 = pos - other.global_position
				var d2: float = d.length_squared()
				if d2 <= 0.0001 or d2 > r2:
					continue
				sum += d / d2 # inverse-square push (strong close, weak far)
				count += 1
				if count >= max_neighbors:
					break
			if count >= max_neighbors:
				break
		if count >= max_neighbors:
			break

	return (sum.normalized() if sum.length_squared() > 0.0001 else Vector2.ZERO)

func count_allies(e: EnemyActor, radius: float, max_count: int = 999) -> int:
	if e == null or not is_instance_valid(e) or e.dead:
		return 0
	if radius <= 0.0:
		return 0

	var ei := _get_ei()
	if ei != null and is_instance_valid(ei) and ei.has_method("count_allies"):
		return int(ei.call("count_allies", e, radius, max_count))

	_maybe_rebuild_fallback()

	var cs: float = maxf(cell_size, 1.0)
	var pos: Vector2 = e.global_position
	var cx: int = floori(pos.x / cs)
	var cy: int = floori(pos.y / cs)
	var cell_range: int = max(1, ceili(radius / cs))

	var r2: float = radius * radius
	var count: int = 0

	for oy in range(-cell_range, cell_range + 1):
		for ox in range(-cell_range, cell_range + 1):
			var cell := Vector2i(cx + ox, cy + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var other := n as EnemyActor
				if other == null or other == e or other.dead:
					continue
				if pos.distance_squared_to(other.global_position) > r2:
					continue
				count += 1
				if count >= max_count:
					return count
	return count
