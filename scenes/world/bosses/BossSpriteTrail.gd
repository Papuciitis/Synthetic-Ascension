extends Node2D
## A finite trail assembled from raster sprites, rather than engine lines.
const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
var follow: Node2D
var width := 7.5
var alpha := 0.4
var fade_time := 0.14
var _points: Array[Vector2] = []
var _segments: Array[Sprite2D] = []
var _fading := false
var _elapsed := 0.0

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 205
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in range(9):
		var segment := Sprite2D.new()
		segment.texture = VfxKit.texture("streak")
		segment.visible = false
		add_child(segment)
		_segments.append(segment)

func stop_and_fade() -> void:
	_fading = true
	follow = null

func _process(delta: float) -> void:
	if not Scope.is_valid_attack(self):
		queue_free()
		return
	if is_instance_valid(follow):
		var pos := follow.global_position
		if _points.is_empty() or _points.back().distance_to(pos) >= 16.0:
			_points.append(pos)
			if _points.size() > 10:
				_points.pop_front()
	else:
		_fading = true
	if _fading:
		_elapsed += delta
		if _elapsed >= fade_time:
			queue_free()
			return
	var fade := 1.0 - clampf(_elapsed / maxf(0.001, fade_time), 0.0, 1.0)
	for i in range(_segments.size()):
		var segment := _segments[i]
		segment.visible = i + 1 < _points.size()
		if not segment.visible or segment.texture == null:
			continue
		var start := _points[i]
		var finish := _points[i + 1]
		segment.position = (start + finish) * 0.5
		segment.rotation = (finish - start).angle()
		segment.scale = Vector2(start.distance_to(finish) / segment.texture.get_width(), width / VfxKit.STREAK_CONTENT_H)
		var intensity := float(i + 1) / float(maxi(1, _points.size() - 1))
		segment.modulate = Color(1.0, 0.83, 0.56, AccessibilityPresentation.current_flash_alpha(alpha * intensity * fade * fade))
