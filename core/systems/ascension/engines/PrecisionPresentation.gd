extends Node2D
## One bounded, visual-only painter for a Precision engine. It observes the
## accepted aim/plot state; every release is reported after damage resolves.
const Art := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")
const MAX_RELEASES := 18
const RELEASE_SECONDS := 0.34
const BEAM := preload("res://assets/textures/vfx/ranged/beam_core.png")
const CAP := preload("res://assets/textures/vfx/ranged/beam_cap.png")
const SIGHT := preload("res://assets/world/objectives/painted/precision_sight_v1.png")
var _engine: WeakRef
var _releases: Array[Dictionary] = []
var _state: Dictionary = {}
var _was_visible := false

func setup(engine: RefCounted) -> void:
	_engine = weakref(engine)
	z_index = -1
	show_behind_parent = true
	if RunEvents != null and not RunEvents.player_life_event.is_connected(_on_player_life_event):
		RunEvents.player_life_event.connect(_on_player_life_event)

func _on_player_life_event(player: Node, kind: StringName) -> void:
	var engine: RefCounted = _engine.get_ref() if _engine != null else null
	if kind != &"death" or engine == null:
		return
	var runner: Node = engine.get("runner")
	if runner != null and player == runner.get("_player"):
		# Death can pause the tree before the next process callback.
		_releases.clear()
		_state.clear()
		_was_visible = false
		queue_redraw()

func release(from: Vector2, to: Vector2, radius: float, judgment: bool, seal_at: Vector2 = Vector2.INF) -> void:
	# Burst/Encore/recalculation builds share the same fixed painter capacity.
	if _releases.size() >= MAX_RELEASES:
		_releases.pop_front()
	_releases.append({"from": from, "to": to, "radius": radius, "judgment": judgment, "seal_at": from if seal_at == Vector2.INF else seal_at, "age": 0.0})
	queue_redraw()

func _process(delta: float) -> void:
	var engine: RefCounted = _engine.get_ref() if _engine != null else null
	if engine == null or not is_instance_valid(engine.get("runner")):
		queue_free()
		return
	var runner: Node = engine.get("runner")
	if engine not in runner.get("engines"):
		queue_free()
		return
	var player: Node = runner.get("_player")
	if player != null and player.get("is_dead") == true:
		_releases.clear()
		_state.clear()
	else:
		_state = engine.call("presentation_state")
		for index in range(_releases.size() - 1, -1, -1):
			_releases[index]["age"] = float(_releases[index]["age"]) + delta
			if float(_releases[index]["age"]) >= RELEASE_SECONDS:
				_releases.remove_at(index)
	var active := not _releases.is_empty() or not _state.is_empty()
	if active or _was_visible:
		queue_redraw()
	_was_visible = active

func _draw() -> void:
	var inverse := get_global_transform().affine_inverse()
	draw_set_transform_matrix(inverse)
	var gold := Color(0.91, 0.75, 0.4, 0.8)
	for lane: Array in _state.get("aim", []):
		_lane(lane[0], lane[1], float(lane[2]), Color(0.91, 0.75, 0.4, 0.48), false)
	var plots: Array = _state.get("plots", [])
	for lane: Array in plots:
		_lane(lane[0], lane[1], float(lane[2]), Color(0.8, 0.78, 0.98, 0.58), false)
	if _state.has("origin"):
		var origin: Vector2 = _state["origin"]
		var progress := float(_state.get("progress", 0.0))
		var half := 29.0 if Art.reduced_motion() else lerpf(37.0, 27.0, progress)
		_seal(origin, half, Color(1.0, 0.94, 0.75, 0.9))
		draw_arc(origin, 32.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, gold, 2.0, true)
		if _state.get("plotting", false):
			for index in range(3):
				var at := origin + Vector2((float(index) - 1.0) * 13.0, 45.0)
				draw_circle(at, 3.0, Color(0.94, 0.85, 1.0, 0.9) if index < plots.size() else Color(0.2, 0.15, 0.23, 0.9))
	for entry: Dictionary in _releases:
		var age := float(entry["age"]) / RELEASE_SECONDS
		var fade := 1.0 - age
		var judgment := bool(entry["judgment"])
		var accent := AccessibilityPresentation.current_flash_alpha(1.0)
		# The steady honest lane remains with Combat Flashes Off; the bright
		# release overlay and expanding ornament follow the preference.
		var color := Color(0.84, 0.76, 1.0, 0.82 * fade) if judgment else Color(1.0, 0.89, 0.58, 0.9 * fade)
		_lane(entry["from"], entry["to"], float(entry["radius"]), color, true)
		var start: Vector2 = entry["from"]
		var end: Vector2 = entry["to"]
		var seal_at: Vector2 = entry["seal_at"]
		var direction := (end - start).normalized()
		if accent > 0.0 and age < 0.45:
			# Painted energy stays inside the true lane. The wider muzzle is
			# a local source ornament, distinct from its authoritative edges.
			draw_set_transform_matrix(inverse * Transform2D(direction.angle(), start))
			var width := float(entry["radius"]) * 2.0
			draw_texture_rect(BEAM, Rect2(Vector2(0, -width * 0.5), Vector2(start.distance_to(end), width)), false, Color(1.0, 0.93, 0.72, accent * fade * 0.82))
			draw_set_transform_matrix(inverse)
			var cap_half := 31.0 if judgment else 23.0
			draw_texture_rect(CAP, Rect2(seal_at - Vector2.ONE * cap_half, Vector2.ONE * cap_half * 2.0), false, Color(1.0, 0.92, 0.7, accent * fade * 0.7))
		var seal_size := 35.0 if Art.reduced_motion() else lerpf(27.0, 47.0, age)
		_seal(seal_at, seal_size, Color(1.0, 0.94, 0.8, fade * (0.45 + accent * 0.4)))
		# Quiet brass residue reads as an aftermath without filling the lane.
		var normal := direction.orthogonal()
		for index in range(5):
			var at := start.lerp(end, (float(index) + 0.5) / 5.0)
			var off := float(entry["radius"]) + 3.0
			draw_line(at + normal * off, at + normal * off + direction * 9.0, Color(0.73, 0.56, 0.28, fade * 0.45), 1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _lane(from: Vector2, to: Vector2, radius: float, color: Color, filled: bool) -> void:
	var normal := (to - from).normalized().orthogonal() * radius
	if filled:
		draw_line(from, to, Color(0.08, 0.05, 0.035, color.a * 0.55), radius * 2.0 + 2.0, true)
		draw_line(from, to, Color(color.r, color.g, color.b, color.a * 0.18), radius * 2.0, true)
	for side in [-1.0, 1.0]:
		var off: Vector2 = normal * float(side)
		draw_line(from + off, to + off, Color(0.025, 0.02, 0.03, color.a * 0.8), 3.5, true)
		draw_line(from + off, to + off, color, 1.5, true)
	if not filled:
		draw_dashed_line(from, to, Color(color.r, color.g, color.b, color.a * 0.65), 1.0, 15.0, true, true)

func _seal(at: Vector2, half: float, color: Color) -> void:
	draw_texture_rect(SIGHT, Rect2(at - Vector2.ONE * half, Vector2.ONE * half * 2.0), false, color)
