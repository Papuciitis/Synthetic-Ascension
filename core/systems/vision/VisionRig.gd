extends Node2D
class_name VisionRig

# Indoor-only Fog of War + Line of Sight (LoS)
# - Outdoors: always clear (no fog overlay, enemies always visible).
# - Indoors: 3 states per fog cell:
#   * Visible now  -> clear
#   * Seen before  -> gray (alpha_seen)
#   * Unseen       -> dark (alpha_unseen)
# - From outside, you can only see inside through real openings (e.g. door holes) via LoS.
# - Procedural-ready: any building just needs an IndoorVolume (Area2D in group "indoor_volume").

@export var cell_size_px: int = 32

# How far LoS goes (pixels). Applies when we actually have indoor cells on screen.
@export var indoor_range_px: float = 1800.0

# Ray fan quality (CPU cost is mostly ray count).
@export var indoor_rays: int = 160

# Optional: windows leak a bit beyond the first hit (0 disables extra rays).
@export var window_leak_px: float = 0.0

# Recompute budget.
@export var recompute_interval: float = 0.06
@export var min_move_px: float = 8.0

# How often we re-apply visibility to enemies/projectiles
@export var entity_update_interval: float = 0.05

# Fog alpha values (0 = transparent, 1 = opaque black).
@export_range(0.0, 1.0, 0.01) var alpha_seen: float = 0.70
@export_range(0.0, 1.0, 0.01) var alpha_unseen: float = 1.0

# Indoor vignette (optional, can be 0)
@export_range(0.0, 1.0, 0.01) var indoor_vignette_strength: float = 0.0

@export_group("Lightweight Vignette")
@export var lightweight_vignette_only: bool = true
@export_range(0.0, 1.0, 0.01) var vignette_pulse_add: float = 0.16
@export_range(0.01, 1.0, 0.01) var vignette_pulse_time: float = 0.18
@export_range(0.01, 1.5, 0.01) var vignette_fade_time: float = 0.24

# Exit Rite distortion (plan 2.8, vision "Exit Rite"): the ExitRite reports a
# level 0..1 on RunEvents.rite_distortion_changed as the hold climbs past its
# distortion_start_fraction, and the vignette ramps to it - strength up, the
# clear centre shrinking, black giving way to a colour. A static ramp: it only
# moves with the hold, so it never flickers and is safe under reduced_motion;
# the release back to nothing is the one tween, and it goes through the
# accessibility motion duration like every other. Level 0 renders the plain
# vignette exactly. Nothing here runs per frame.
@export_group("Rite Distortion")
## Vignette strength at full distortion (level 1).
@export_range(0.0, 1.0, 0.01) var distortion_strength_max: float = 0.55
## Where the darkening starts at level 1 (the material's inner_radius at 0).
@export_range(0.0, 1.0, 0.01) var distortion_inner_radius_min: float = 0.35
## The colour the edge darkens toward at level 1 (black at 0).
@export var distortion_tint_max: Color = Color(0.36, 0.08, 0.48, 1.0)
## A flat wash of the tint across the whole screen at level 1 (0 at 0).
@export_range(0.0, 0.5, 0.01) var distortion_wash_max: float = 0.10
## Fade back to nothing when the level drops to 0 (reset, lapse, death, clear).
@export_range(0.0, 2.0, 0.01) var distortion_release_time: float = 0.6

# Collision layers used by LoS raycasts.
# Walls are on layer 9 (256). Windows are on layer 10 (512).
const LAYER_FULL_WALL: int = 1 << 8   # 256
const LAYER_WINDOW_WALL: int = 1 << 9 # 512
const MASK_VISION_BLOCKERS: int = LAYER_FULL_WALL | LAYER_WINDOW_WALL

# Indoor volumes are simple Area2D rectangles.
const GROUP_INDOOR_VOLUME := &"indoor_volume"
const GROUP_PLAYER := &"player"
const GROUP_ENEMIES := &"enemies"
const GROUP_ENEMY_PROJECTILE := &"enemy_projectile"
const GROUP_COVER_WINDOW := &"cover_window"

# -----------------------------
# Runtime state
# -----------------------------
var _player: CharacterBody2D
var _camera: Camera2D

var _was_indoors: bool = false
var _vig_strength: float = 0.0
var _vig_tween: Tween = null

# Rite distortion: the level being shown, the level last reported, the release
# tween, and the material's own inner_radius to return to.
var _distortion_level: float = 0.0
var _distortion_target: float = 0.0
var _distortion_tween: Tween = null
var _base_inner_radius: float = 0.70

var _t_accum: float = 0.0
var _last_player_pos: Vector2 = Vector2.INF
var _last_cam_pos: Vector2 = Vector2.INF
var _ent_accum: float = 0.0

# Cached indoor rectangles (world and fog-cell coordinates).
var _indoor_rects_world: Array[Rect2] = []
var _indoor_rects_cells: Array[Rect2i] = []
var _indoor_refresh_t: float = 0.0

# Exposed masks (FogOfWar reads these)
var indoor_bounds: Rect2i = Rect2i()
var indoor_mask: PackedByteArray = PackedByteArray() # 0/1 for indoor cells in indoor_bounds

var visible_bounds: Rect2i = Rect2i()
var visible_mask: PackedByteArray = PackedByteArray() # 0/1 for visible indoor cells in visible_bounds

var vision_revision: int = 0

# Persistent "seen" memory (only for indoor cells).
var seen_grid: SeenGrid = SeenGrid.new(32)

@onready var fog: CanvasItem = get_node_or_null("FogLayer/FogOfWar") as CanvasItem
@onready var fog_layer: CanvasLayer = get_node_or_null("FogLayer") as CanvasLayer
@onready var vignette_rect: ColorRect = get_node_or_null("VignetteLayer/Vignette") as ColorRect

# Ray direction cache (avoids trig every recompute)
var _ray_dirs: PackedVector2Array = PackedVector2Array()
var _ray_dirs_count: int = -1


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(GROUP_PLAYER) as CharacterBody2D
	if _player != null:
		_camera = _player.get_node_or_null("Camera2D") as Camera2D

	_refresh_indoor_rects(true)
	_set_vignette_active(false)

	if lightweight_vignette_only:
		if fog_layer != null:
			fog_layer.visible = false
		if fog != null:
			fog.visible = false

	if vignette_rect != null:
		var mat := vignette_rect.material as ShaderMaterial
		if mat != null:
			# The scene's material is one resource shared by every rig the
			# scene ever instantiates, and nothing puts it back: a death or a
			# run's end pauses the tree under the release tween and the restart
			# frees the rig mid-fade, so the next run's rig would start from
			# whatever the last one wrote - a tinted, tighter vignette on the
			# indoor overlay, and a base inner_radius read off the ratchet.
			# Write to a copy of our own; the scene's values stay the defaults.
			mat = mat.duplicate() as ShaderMaterial
			vignette_rect.material = mat
			var inner: Variant = mat.get_shader_parameter("inner_radius")
			if inner is float or inner is int:
				_base_inner_radius = float(inner)
	if RunEvents != null and RunEvents.has_signal("rite_distortion_changed"):
		RunEvents.rite_distortion_changed.connect(_on_rite_distortion_changed)


func _process(dt: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(GROUP_PLAYER) as CharacterBody2D
		if _player == null:
			return
		_camera = _player.get_node_or_null("Camera2D") as Camera2D

	if _camera == null or not is_instance_valid(_camera):
		_camera = _player.get_node_or_null("Camera2D") as Camera2D
		if _camera == null:
			return

	
	# Lightweight mode: only track indoor volumes + vignette pulse (no fog/LoS).
	if lightweight_vignette_only:
		_indoor_refresh_t += dt
		if _indoor_refresh_t >= 1.0:
			_indoor_refresh_t = 0.0
			_refresh_indoor_rects(false)

		var now_indoors: bool = _is_point_in_any_indoor(_player.global_position)
		_update_lightweight_vignette(now_indoors)
		return

	# Refresh indoor rect cache occasionally (procedural buildings can add volumes).
	_indoor_refresh_t += dt
	if _indoor_refresh_t >= 1.0:
		_indoor_refresh_t = 0.0
		_refresh_indoor_rects(false)

	_t_accum += dt
	_ent_accum += dt

	var allow_recompute := false
	if _t_accum >= recompute_interval:
		_t_accum = 0.0
		allow_recompute = true

	# Throttle recompute if nothing relevant moved.
	var moved := false
	if _last_player_pos == Vector2.INF or _player.global_position.distance_to(_last_player_pos) >= min_move_px:
		moved = true
	if _last_cam_pos == Vector2.INF or _camera.global_position.distance_to(_last_cam_pos) >= float(cell_size_px) * 0.5:
		moved = true

	var do_recompute := allow_recompute and moved

	if moved:
		_last_player_pos = _player.global_position
		_last_cam_pos = _camera.global_position

	if do_recompute:
		var bounds := _camera_cell_bounds(6)
		_build_indoor_mask(bounds)

		# If there are no indoor cells on-screen, disable fog work entirely.
		if indoor_mask.is_empty():
			visible_bounds = Rect2i()
			visible_mask = PackedByteArray()
			_set_vignette_active(false)
			_show_all_entities_outdoors()
			return

		# Optional vignette only when the player is actually indoors.
		var player_indoors := _is_point_in_any_indoor(_player.global_position)
		_set_vignette_active(player_indoors)

		_recompute_visibility(bounds)
		vision_revision += 1
		if fog != null:
			fog.queue_redraw()

	# Keep entity visibility updated even if we didn't recompute this tick.
	if _ent_accum >= entity_update_interval:
		_ent_accum = 0.0
		_apply_visibility_to_entities()


# -----------------------------
# Public helpers
# -----------------------------
func get_camera() -> Camera2D:
	return _camera

func is_cell_seen(cell_x: int, cell_y: int) -> bool:
	return seen_grid.is_seen(Vector2i(cell_x, cell_y))

func get_indoor_rects_world() -> Array[Rect2]:
	return _indoor_rects_world

func get_indoor_rects_cells() -> Array[Rect2i]:
	return _indoor_rects_cells


# -----------------------------
# Internals
# -----------------------------
func _set_vignette_active(active: bool) -> void:
	if vignette_rect == null:
		return
	if not active or indoor_vignette_strength <= 0.001:
		# The rite's distortion keeps the rect up on its own.
		if _distortion_level <= 0.0:
			vignette_rect.visible = false
		return
	vignette_rect.visible = true
	_apply_vignette_strength(indoor_vignette_strength)



func _hide_vignette() -> void:
	if vignette_rect != null and _distortion_level <= 0.0:
		vignette_rect.visible = false

func _apply_vignette_strength(v: float) -> void:
	_vig_strength = v
	if vignette_rect == null:
		return
	var mat := vignette_rect.material as ShaderMaterial
	if mat != null:
		# The indoor strength and the rite's distortion share one uniform; the
		# stronger of the two shows, so neither can switch the other off.
		mat.set_shader_parameter("strength", maxf(v, distortion_strength_max * _distortion_level))


# -----------------------------
# Rite distortion
# -----------------------------
func _on_rite_distortion_changed(level: float) -> void:
	var target := clampf(level, 0.0, 1.0)
	if is_equal_approx(target, _distortion_target):
		return
	_distortion_target = target
	_kill_distortion_tween()
	if target > 0.0 or _distortion_level <= 0.0:
		# Rising with the hold, or falling with a drain: the ramp itself,
		# applied as reported. No animation of our own on top of it.
		_set_distortion_level(target)
		return
	# Back to nothing (reset, lapse, death, clear): one fade, instant when the
	# player asked for reduced motion.
	var duration := AccessibilityPresentation.current_motion_duration(distortion_release_time)
	if duration <= 0.02:
		_set_distortion_level(0.0)
		return
	_distortion_tween = create_tween()
	_distortion_tween.tween_method(Callable(self, "_set_distortion_level"), _distortion_level, 0.0, duration)


func _kill_distortion_tween() -> void:
	if _distortion_tween != null and _distortion_tween.is_running():
		_distortion_tween.kill()
	_distortion_tween = null


func _set_distortion_level(level: float) -> void:
	_distortion_level = clampf(level, 0.0, 1.0)
	if vignette_rect == null:
		return
	var mat := vignette_rect.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("inner_radius", lerpf(_base_inner_radius, distortion_inner_radius_min, _distortion_level))
	mat.set_shader_parameter("tint", Color.BLACK.lerp(distortion_tint_max, _distortion_level))
	mat.set_shader_parameter("wash", distortion_wash_max * _distortion_level)
	# Re-apply the indoor strength so the shared uniform picks the stronger.
	_apply_vignette_strength(_vig_strength)
	if _distortion_level > 0.0:
		vignette_rect.visible = true
	elif not _was_indoors or indoor_vignette_strength <= 0.001:
		vignette_rect.visible = false


func distortion_level() -> float:
	return _distortion_level

func _kill_vignette_tween() -> void:
	if _vig_tween != null and _vig_tween.is_running():
		_vig_tween.kill()
	_vig_tween = null

func _update_lightweight_vignette(now_indoors: bool) -> void:
	if vignette_rect == null or indoor_vignette_strength <= 0.001:
		return

	if now_indoors == _was_indoors:
		# Keep base strength while indoors.
		if now_indoors:
			if not vignette_rect.visible:
				vignette_rect.visible = true
			_apply_vignette_strength(indoor_vignette_strength)
		return

	_was_indoors = now_indoors
	_kill_vignette_tween()

	var mat := vignette_rect.material as ShaderMaterial
	if mat == null:
		return

	if now_indoors:
		vignette_rect.visible = true
		# Pulse: bump strength then settle to base.
		var peak := clampf(indoor_vignette_strength + vignette_pulse_add, 0.0, 1.0)
		_apply_vignette_strength(peak)
		_vig_tween = create_tween()
		_vig_tween.tween_method(Callable(self, "_apply_vignette_strength"), peak, indoor_vignette_strength, vignette_pulse_time)
	else:
		# Fade out then hide.
		var start := _vig_strength
		_vig_tween = create_tween()
		_vig_tween.tween_method(Callable(self, "_apply_vignette_strength"), start, 0.0, vignette_fade_time)
		_vig_tween.tween_callback(Callable(self, "_hide_vignette"))

func _refresh_indoor_rects(_force: bool) -> void:
	# Collect all IndoorVolume areas.
	# Procedural-friendly: generator can spawn new IndoorVolume nodes at runtime.
	var vols := get_tree().get_nodes_in_group(GROUP_INDOOR_VOLUME)

	_indoor_rects_world.clear()
	_indoor_rects_cells.clear()

	var cs: float = float(cell_size_px)
	for n in vols:
		var a := n as Area2D
		if a == null or not is_instance_valid(a):
			continue

		# Expect a RectangleShape2D in CollisionShape2D.
		var shape_node := a.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape == null:
			continue

		var world_rect := _area_rect_aabb(a, rect_shape.size)
		_indoor_rects_world.append(world_rect)

		# Convert to fog-cell rect.
		var tl := world_rect.position
		var size := world_rect.size
		var x0 := floori(tl.x / cs)
		var y0 := floori(tl.y / cs)
		var x1 := floori((tl.x + size.x - 0.001) / cs)
		var y1 := floori((tl.y + size.y - 0.001) / cs)
		var cell_rect := Rect2i(Vector2i(x0, y0), Vector2i((x1 - x0) + 1, (y1 - y0) + 1))
		_indoor_rects_cells.append(cell_rect)


func _area_rect_aabb(a: Area2D, size: Vector2) -> Rect2:
	# Build an axis-aligned rect in world space even if the Area is rotated/scaled.
	var half := size * 0.5
	var xf := a.global_transform
	var p0 := xf * Vector2(-half.x, -half.y)
	var p1 := xf * Vector2( half.x, -half.y)
	var p2 := xf * Vector2( half.x,  half.y)
	var p3 := xf * Vector2(-half.x,  half.y)

	var minx := minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var miny := minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var maxx := maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var maxy := maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	return Rect2(Vector2(minx, miny), Vector2(maxx - minx, maxy - miny))


func _is_point_in_any_indoor(p: Vector2) -> bool:
	for r in _indoor_rects_world:
		if r.has_point(p):
			return true
	return false


func _camera_view_range_px() -> float:
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: Vector2 = _camera.zoom
	if zoom.x == 0.0:
		zoom.x = 1.0
	if zoom.y == 0.0:
		zoom.y = 1.0
	var half: Vector2 = (vp_size * 0.5) * Vector2(1.0 / zoom.x, 1.0 / zoom.y)
	return half.length() + float(cell_size_px) * 2.0


func _camera_cell_bounds(margin_cells: int) -> Rect2i:
	var cell: float = float(cell_size_px)
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: Vector2 = _camera.zoom
	if zoom.x == 0.0:
		zoom.x = 1.0
	if zoom.y == 0.0:
		zoom.y = 1.0
	var half: Vector2 = (vp_size * 0.5) * Vector2(1.0 / zoom.x, 1.0 / zoom.y)
	var tl: Vector2 = _camera.global_position - half
	var br: Vector2 = _camera.global_position + half
	var x0: int = floori(tl.x / cell) - margin_cells
	var y0: int = floori(tl.y / cell) - margin_cells
	var x1: int = floori(br.x / cell) + margin_cells
	var y1: int = floori(br.y / cell) + margin_cells
	return Rect2i(Vector2i(x0, y0), Vector2i((x1 - x0) + 1, (y1 - y0) + 1))


func _build_indoor_mask(bounds: Rect2i) -> void:
	# Builds indoor_mask for the current camera bounds.
	# If no indoor cell intersects bounds, indoor_mask is emptied (FogOfWar can skip drawing).
	indoor_bounds = bounds
	var w := bounds.size.x
	var h := bounds.size.y
	if w <= 0 or h <= 0:
		indoor_mask = PackedByteArray()
		return

	var tmp := PackedByteArray()
	tmp.resize(w * h)

	var any := false
	for r in _indoor_rects_cells:
		var ir := r.intersection(bounds)
		if ir.size.x <= 0 or ir.size.y <= 0:
			continue
		any = true
		var sx := ir.position.x - bounds.position.x
		var sy := ir.position.y - bounds.position.y
		for y in range(ir.size.y):
			var row := (sy + y) * w
			for x in range(ir.size.x):
				tmp[row + sx + x] = 1

	if not any:
		indoor_mask = PackedByteArray()
	else:
		indoor_mask = tmp


func _ensure_ray_dirs(ray_count: int) -> void:
	if ray_count == _ray_dirs_count and _ray_dirs.size() == ray_count:
		return
	_ray_dirs_count = ray_count
	_ray_dirs = PackedVector2Array()
	_ray_dirs.resize(ray_count)
	for i in range(ray_count):
		var ang := (TAU * float(i)) / float(ray_count)
		_ray_dirs[i] = Vector2(cos(ang), sin(ang))


func _recompute_visibility(bounds: Rect2i) -> void:
	visible_bounds = bounds
	var w := bounds.size.x
	var h := bounds.size.y
	if w <= 0 or h <= 0:
		visible_mask = PackedByteArray()
		return

	visible_mask = PackedByteArray()
	visible_mask.resize(w * h)

	# No indoor => no need.
	if indoor_mask.is_empty():
		return

	var origin: Vector2 = _player.global_position

	var cam_range := _camera_view_range_px()
	var range_px: float = indoor_range_px
	if cam_range > 0.0:
		range_px = minf(range_px, cam_range)

	var ray_count := maxi(indoor_rays, 96)
	_ensure_ray_dirs(ray_count)

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	exclude.append(_player.get_rid())

	var endpoints := PackedVector2Array()
	endpoints.resize(ray_count)

	for i in range(ray_count):
		var dir := _ray_dirs[i]
		var to := origin + dir * range_px

		var rp := PhysicsRayQueryParameters2D.new()
		rp.from = origin
		rp.to = to
		rp.collision_mask = MASK_VISION_BLOCKERS
		rp.collide_with_bodies = true
		rp.collide_with_areas = true
		rp.exclude = exclude

		var hit := space.intersect_ray(rp)
		var hit_to := to

		if not hit.is_empty() and hit.has("position"):
			var hit_pos: Vector2 = hit["position"]
			var body: CollisionObject2D = hit.get("collider") as CollisionObject2D
			var is_window := false
			if body != null:
				is_window = body.is_in_group(GROUP_COVER_WINDOW) or ((body.collision_layer & LAYER_WINDOW_WALL) != 0)

			if window_leak_px > 0.0 and is_window:
				var leak_dist := minf(range_px, origin.distance_to(hit_pos) + window_leak_px)
				var leak_to := origin + dir * leak_dist

				var rp2 := PhysicsRayQueryParameters2D.new()
				rp2.from = hit_pos + dir * 2.0
				rp2.to = leak_to
				rp2.collision_mask = MASK_VISION_BLOCKERS
				rp2.collide_with_bodies = true
				rp2.collide_with_areas = true
				rp2.exclude = exclude.duplicate()
				if body != null:
					rp2.exclude.append(body.get_rid())

				var hit2 := space.intersect_ray(rp2)
				if not hit2.is_empty() and hit2.has("position"):
					hit_to = hit2["position"]
				else:
					hit_to = leak_to
			else:
				hit_to = hit_pos

		endpoints[i] = hit_to

	# Convert polygon to cell-space.
	var cell: float = float(cell_size_px)
	var poly_c := PackedVector2Array()
	poly_c.resize(ray_count)
	for i in range(ray_count):
		var p := endpoints[i]
		poly_c[i] = Vector2(p.x / cell, p.y / cell)

	# Scanline fill into visible_mask, clipped to bounds.
	var x0 := bounds.position.x
	var y0 := bounds.position.y
	var x1 := bounds.position.x + bounds.size.x - 1
	var y1 := bounds.position.y + bounds.size.y - 1

	var intersections: Array[float] = []

	for y in range(y0, y1 + 1):
		var y_line := float(y) + 0.5
		intersections.clear()

		for i in range(ray_count):
			var a := poly_c[i]
			var b := poly_c[(i + 1) % ray_count]
			if is_equal_approx(a.y, b.y):
				continue
			var ymin := minf(a.y, b.y)
			var ymax := maxf(a.y, b.y)
			if y_line < ymin or y_line >= ymax:
				continue
			var t := (y_line - a.y) / (b.y - a.y)
			var x := a.x + t * (b.x - a.x)
			intersections.append(x)

		if intersections.size() < 2:
			continue
		intersections.sort()

		for k in range(0, intersections.size() - 1, 2):
			var xL := intersections[k]
			var xR := intersections[k + 1]
			if xL > xR:
				var tmp := xL
				xL = xR
				xR = tmp

			var xs := int(ceil(xL - 0.5))
			var xe := int(floor(xR - 0.5))
			if xe < x0 or xs > x1:
				continue
			xs = maxi(xs, x0)
			xe = mini(xe, x1)

			var local_y := y - y0
			var row := local_y * w
			for x in range(xs, xe + 1):
				var local_x := x - x0
				var idx := row + local_x
				if indoor_mask[idx] == 0:
					continue
				visible_mask[idx] = 1
				seen_grid.mark_seen(Vector2i(x, y))


func _apply_visibility_to_entities() -> void:
	# Hide indoor enemies/projectiles that are not currently visible.
	# Outdoors are always visible (no fog outside).
	if indoor_mask.is_empty() or visible_mask.is_empty():
		_show_all_entities_outdoors()
		return

	var w := visible_bounds.size.x
	var h := visible_bounds.size.y
	var x0 := visible_bounds.position.x
	var y0 := visible_bounds.position.y
	var rects := _indoor_rects_world

	# Enemies
	for n in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var e := n as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if not _is_point_in_any_rect(e.global_position, rects):
			e.visible = true
			continue
		var c := Vector2i(floori(e.global_position.x / float(cell_size_px)), floori(e.global_position.y / float(cell_size_px)))
		var vx := c.x - x0
		var vy := c.y - y0
		if vx < 0 or vy < 0 or vx >= w or vy >= h:
			e.visible = false
			continue
		var idx := vy * w + vx
		e.visible = (visible_mask[idx] != 0)

	# Projectiles
	for n in get_tree().get_nodes_in_group(GROUP_ENEMY_PROJECTILE):
		var p := n as Node2D
		if p == null or not is_instance_valid(p):
			continue
		if not _is_point_in_any_rect(p.global_position, rects):
			p.visible = true
			continue
		var c2 := Vector2i(floori(p.global_position.x / float(cell_size_px)), floori(p.global_position.y / float(cell_size_px)))
		var vx2 := c2.x - x0
		var vy2 := c2.y - y0
		if vx2 < 0 or vy2 < 0 or vx2 >= w or vy2 >= h:
			p.visible = false
			continue
		var idx2 := vy2 * w + vx2
		p.visible = (visible_mask[idx2] != 0)


func _show_all_entities_outdoors() -> void:
	for n in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var e := n as Node2D
		if e != null and is_instance_valid(e):
			e.visible = true
	for n in get_tree().get_nodes_in_group(GROUP_ENEMY_PROJECTILE):
		var p := n as Node2D
		if p != null and is_instance_valid(p):
			p.visible = true


func _is_point_in_any_rect(p: Vector2, rects: Array[Rect2]) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false
