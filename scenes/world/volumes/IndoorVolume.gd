extends Area2D
class_name IndoorVolume

@export var cell_size_px: int = 64
@export var cell_tl: Vector2i = Vector2i.ZERO
@export var size_cells: Vector2i = Vector2i(1, 1)
@export var building_id: int = 0
@export var secondary_objective_id: int = 0

@onready var _shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

# ------------------------------------------------------------
# Exploration loot (spawn-on-enter so you can't miss it)
# ------------------------------------------------------------
@export_group("Exploration Loot")
@export var exploration_loot_enabled: bool = true
@export var small_loot_chance: float = 0.22
@export var large_area_threshold_cells: int = 320  # size_cells.x * size_cells.y >= this => "dungeon"
@export var small_count_min: int = 1
@export var small_count_max: int = 1
@export var large_count_min: int = 1
@export var large_count_max: int = 3
@export var small_rarity_min: int = 3
@export var small_rarity_max: int = 6
@export var large_rarity_min: int = 5
@export var large_rarity_max: int = 8
@export var small_rarity_bonus_per_segment: int = 0
@export var large_rarity_bonus_per_segment: int = 1
@export var large_loot_chance: float = 1.0
@export var force_large_loot: bool = false
@export var site_area_cells: int = 0
@export var scatter_radius_px: float = 90.0
@export var pickup_delay: float = 0.15
@export var require_walkable: bool = true
@export var pos_attempts: int = 14
# Reward interiors keep ambient spawns out (their encounters own the room).
# Playfield interiors - the Segment 1 facility - set this false so ambient
# pressure can spawn inside the building instead of in the void outside it.
@export var ambient_spawn_excluded: bool = true
@export var ready_retry_interval: float = 0.10
@export var ready_retry_timeout: float = 3.0

@export_group("Local Encounter")
@export var local_encounter_enabled: bool = false
@export_range(1, 12, 1) var local_encounter_count: int = 5
@export var local_encounter_delay: float = 0.35

@export var pickup_scene: PackedScene = preload("res://scenes/world/pickups/ItemPickup.tscn")

var _loot_attempted: bool = false
var _loot_retry_pending: bool = false
var _loot_wait_elapsed: float = 0.0
var _encounter_started: bool = false
var _encounter_completed: bool = false
var _encounter_remaining: int = 0
var _encounter_enemy_ids: Array[int] = []
var _presentation_entry := Vector2.ZERO
var _presentation_outward := Vector2.DOWN
var _presentation_width := 0.0
var _presentation_enabled := false
var _player_inside := false
var _entry_sign: Label
var _room_sign: Label
var _room_floor: Polygon2D
var _reward_refs: Array[WeakRef] = []


func _ready() -> void:
	# This volume is only used for detecting if the player is indoors.
	monitoring = true
	monitorable = true
	add_to_group(&"indoor_volume")
	_update_shape()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_sync_exploration_presentation()


func _exit_tree() -> void:
	_set_encounter_active(false)


func configure(tl: Vector2i, sz: Vector2i, cs: int, id: int, loot_cfg: Dictionary = {}) -> void:
	cell_tl = tl
	size_cells = sz
	cell_size_px = cs
	building_id = id
	_apply_loot_config(loot_cfg)
	_update_shape()


func _apply_loot_config(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	exploration_loot_enabled = bool(cfg.get("exploration_loot_enabled", exploration_loot_enabled))
	small_loot_chance = float(cfg.get("small_loot_chance", small_loot_chance))
	large_loot_chance = float(cfg.get("large_loot_chance", large_loot_chance))
	small_count_min = int(cfg.get("small_count_min", small_count_min))
	small_count_max = int(cfg.get("small_count_max", small_count_max))
	large_count_min = int(cfg.get("large_count_min", large_count_min))
	large_count_max = int(cfg.get("large_count_max", large_count_max))
	small_rarity_min = int(cfg.get("small_rarity_min", small_rarity_min))
	small_rarity_max = int(cfg.get("small_rarity_max", small_rarity_max))
	large_rarity_min = int(cfg.get("large_rarity_min", large_rarity_min))
	large_rarity_max = int(cfg.get("large_rarity_max", large_rarity_max))
	small_rarity_bonus_per_segment = int(cfg.get("small_rarity_bonus_per_segment", small_rarity_bonus_per_segment))
	large_rarity_bonus_per_segment = int(cfg.get("large_rarity_bonus_per_segment", large_rarity_bonus_per_segment))
	force_large_loot = bool(cfg.get("force_large_loot", force_large_loot))
	site_area_cells = int(cfg.get("site_area_cells", site_area_cells))
	scatter_radius_px = float(cfg.get("scatter_radius_px", scatter_radius_px))
	pickup_delay = float(cfg.get("pickup_delay", pickup_delay))
	require_walkable = bool(cfg.get("require_walkable", require_walkable))
	pos_attempts = int(cfg.get("pos_attempts", pos_attempts))
	local_encounter_enabled = bool(cfg.get("local_encounter_enabled", local_encounter_enabled))
	local_encounter_count = int(cfg.get("local_encounter_count", local_encounter_count))
	secondary_objective_id = int(cfg.get("secondary_objective_id", secondary_objective_id))


func _update_shape() -> void:
	if _shape == null:
		return
	var w: float = float(maxi(1, size_cells.x) * cell_size_px)
	var h: float = float(maxi(1, size_cells.y) * cell_size_px)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	_shape.shape = rect
	# Place the Area2D at the center of the rectangle.
	global_position = Vector2(float(cell_tl.x * cell_size_px) + w * 0.5, float(cell_tl.y * cell_size_px) + h * 0.5)


func _on_body_entered(b: Node) -> void:
	if b != null and b.is_in_group(&"player"):
		_player_inside = true
		_sync_exploration_presentation.call_deferred()
	if b != null and b.is_in_group("player") and RunEvents != null:
		# Exploration hook. first_visit is keyed on the stable seeded
		# building_id, not on this node: chunks are streamed, so a volume the
		# player walks away from is freed and rebuilt fresh. A node-local flag
		# would let an exploration rule be farmed by pacing a chunk boundary.
		# An unauthored volume (building_id 0) never counts as a first visit.
		var first_visit: bool = (
			Global != null
			and Global.has_method("note_building_visit")
			and bool(Global.call("note_building_visit", building_id))
		)
		RunEvents.player_entered_building.emit(self, first_visit)
	if _loot_attempted:
		return
	if not exploration_loot_enabled:
		return
	if b == null or not b.is_in_group("player"):
		return
	if local_encounter_enabled and not _encounter_completed:
		_set_encounter_active(true)
		if not _encounter_started:
			_activate_local_encounter()
		return
	_try_spawn_loot()


func _on_body_exited(b: Node) -> void:
	if b != null and b.is_in_group("player"):
		_player_inside = false
		_sync_exploration_presentation()
		_set_encounter_active(false)

func contains_world_point(world_point: Vector2) -> bool:
	var size_px := Vector2(float(maxi(1, size_cells.x) * cell_size_px), float(maxi(1, size_cells.y) * cell_size_px))
	return Rect2(global_position - size_px * 0.5, size_px).has_point(world_point)

func _activate_local_encounter() -> void:
	_encounter_started = true
	_sync_exploration_presentation()
	if local_encounter_delay > 0.0:
		await get_tree().create_timer(local_encounter_delay, false).timeout
	if not is_inside_tree():
		return
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner") as EnemySpawner
	if spawner == null or not spawner.has_method("spawn_local_encounter"):
		_finish_local_encounter()
		return
	var size_px := Vector2(float(maxi(1, size_cells.x) * cell_size_px), float(maxi(1, size_cells.y) * cell_size_px))
	var inset := Vector2(float(cell_size_px) * 1.5, float(cell_size_px) * 1.5)
	var encounter_rect := Rect2(global_position - size_px * 0.5 + inset, size_px - inset * 2.0)
	var spawned: Array = spawner.spawn_local_encounter(encounter_rect, local_encounter_count, self)
	_encounter_remaining = spawned.size()
	_encounter_enemy_ids.clear()
	if _encounter_remaining <= 0:
		_finish_local_encounter()
		return
	for enemy_variant in spawned:
		var enemy := enemy_variant as Node
		if enemy == null:
			_encounter_remaining -= 1
			continue
		_encounter_enemy_ids.append(enemy.get_instance_id())
		enemy.tree_exited.connect(_on_local_enemy_left.bind(enemy), CONNECT_ONE_SHOT)
	_sync_exploration_presentation()
	if _encounter_remaining <= 0:
		_finish_local_encounter()

func _on_local_enemy_left(enemy: Node) -> void:
	# tree_exited fires for deaths AND for enemies culled/streamed out
	# alive; only deaths may advance the encounter, otherwise the secondary
	# auto-completes while the player is somewhere else entirely.
	if enemy == null or not _encounter_enemy_ids.has(enemy.get_instance_id()):
		return # stale connection from an aborted earlier encounter
	var died: bool = (
		is_instance_valid(enemy)
		and "dead" in enemy and bool(enemy.get("dead"))
	)
	if not died:
		_abort_local_encounter()
		return
	_encounter_remaining = maxi(0, _encounter_remaining - 1)
	_sync_exploration_presentation()
	if _encounter_remaining <= 0:
		_finish_local_encounter()

func _abort_local_encounter() -> void:
	# Re-entering the building re-arms a fresh encounter.
	if _encounter_completed:
		return
	_encounter_started = false
	_encounter_remaining = 0
	_encounter_enemy_ids.clear()
	_sync_exploration_presentation()

func _finish_local_encounter() -> void:
	if _encounter_completed:
		return
	_encounter_completed = true
	_set_encounter_active(false)
	_notify_secondary_completed()
	_try_spawn_loot()
	_sync_exploration_presentation()


func _set_encounter_active(active: bool) -> void:
	for enemy_id in _encounter_enemy_ids:
		var enemy := instance_from_id(enemy_id) as Node
		if enemy != null and is_instance_valid(enemy):
			enemy.set_meta("interior_active", active)


func _notify_secondary_completed() -> void:
	if secondary_objective_id <= 0:
		return
	if RunEvents != null and RunEvents.has_signal("secondary_objective_completed"):
		RunEvents.secondary_objective_completed.emit(secondary_objective_id)
	secondary_objective_id = 0

func _try_spawn_loot() -> void:
	if _loot_attempted:
		return
	if not exploration_loot_enabled:
		_loot_attempted = true
		return
	if building_id == 0:
		_loot_attempted = true
		return
	if Global != null and Global.has_claimed_loot(building_id):
		_loot_attempted = true
		return
	if pickup_scene == null or Global == null or Global.item_db.is_empty():
		_schedule_loot_retry()
		return

	# Multi-chunk sites pass their total area so every streamed slice agrees on
	# large-site classification while sharing the same deterministic building ID.
	var local_area_cells: int = maxi(0, size_cells.x) * maxi(0, size_cells.y)
	var effective_area_cells: int = maxi(local_area_cells, site_area_cells)
	var is_large: bool = force_large_loot or effective_area_cells >= large_area_threshold_cells

	# Deterministic roll per building/volume.
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed((Global.attempt_world_seed if Global != null else 1337), building_id)

	# Luck sweetens exploration: the roll itself stays seeded per building,
	# but the threshold shifts with the player's CURRENT Luck — outcomes can
	# differ depending on when the building streams in, which is acceptable
	# for "the universe treats you better".
	var chance: float = clampf(
		(large_loot_chance if is_large else small_loot_chance)
			+ LuckResolver.secondary_event_bonus(Global.run_luck if Global != null else 0.0),
		0.0,
		1.0
	)
	_loot_attempted = true
	if rng.randf() > chance:
		return

	var n_min: int = (large_count_min if is_large else small_count_min)
	var n_max: int = (large_count_max if is_large else small_count_max)
	var segment: int = int(Global.attempt_segment) if Global != null else 1
	var rarity_bonus: int = (large_rarity_bonus_per_segment if is_large else small_rarity_bonus_per_segment) * maxi(0, segment - 1)
	var r_min: int = (large_rarity_min if is_large else small_rarity_min) + rarity_bonus
	var r_max: int = (large_rarity_max if is_large else small_rarity_max) + rarity_bonus

	if _spawn_loot(rng, n_min, n_max, r_min, r_max):
		if Global != null:
			Global.claim_loot(building_id)
		# Plain loot rooms (no local encounter) complete their secondary the
		# moment the room pays out; encounter rooms already notified when the
		# fight cleared, and the id resets to 0 after the first emission.
		_notify_secondary_completed()
	else:
		_loot_attempted = false
		_schedule_loot_retry()


func _schedule_loot_retry() -> void:
	if _loot_retry_pending or _loot_attempted:
		return
	if _loot_wait_elapsed >= ready_retry_timeout:
		_loot_attempted = true
		push_warning("Indoor loot could not initialize for building %d" % building_id)
		return
	_loot_retry_pending = true
	var timer := get_tree().create_timer(maxf(0.02, ready_retry_interval))
	timer.timeout.connect(_retry_loot_spawn)


func _retry_loot_spawn() -> void:
	_loot_retry_pending = false
	_loot_wait_elapsed += maxf(0.02, ready_retry_interval)
	_try_spawn_loot()


func _spawn_loot(rng: RandomNumberGenerator, n_min: int, n_max: int, r_min: int, r_max: int) -> bool:
	var keys: Array = Global.item_db.keys()
	if keys.is_empty():
		return false

	var n: int = rng.randi_range(maxi(1, n_min), maxi(1, n_max))
	var made := false

	for _i in range(n):
		var item_key = Global.pick_weighted_item_id(rng, keys)
		var item_id_str: String = str(item_key)
		var data: ItemData = Global.get_item_data(item_id_str)
		if data == null:
			continue

		var context: ItemDropContext = Global.build_item_drop_context(r_min, r_max, &"indoor", 1)
		var inst: ItemInstance = ItemGenerator.create_instance(data, context, rng)

		var p := pickup_scene.instantiate() as ItemPickup
		if p == null:
			continue

		p.item_instance = inst
		p.item_id = str(data.id)
		p.amount = 1
		p.pickup_delay = pickup_delay
		p.is_exploration_loot = true

		var spawn_pos: Vector2 = _pick_pos_in_volume(rng)
		if spawn_pos == Vector2.INF:
			p.free()
			continue
		p.global_position = spawn_pos
		_reward_refs.append(weakref(p))
		p.tree_entered.connect(_sync_exploration_presentation)
		p.tree_exited.connect(_sync_exploration_presentation)

		get_tree().current_scene.call_deferred("add_child", p)
		made = true

	return made


func _pick_pos_in_volume(rng: RandomNumberGenerator) -> Vector2:
	var w_px: float = float(maxi(1, size_cells.x) * cell_size_px)
	var h_px: float = float(maxi(1, size_cells.y) * cell_size_px)
	var half := Vector2(w_px * 0.5, h_px * 0.5)

	var cm: Node = get_tree().get_first_node_in_group("chunk_manager")

	for _k in range(maxi(1, pos_attempts)):
		# Pick inside the rectangle (biased toward center).
		var rx := rng.randf_range(-half.x * 0.75, half.x * 0.75)
		var ry := rng.randf_range(-half.y * 0.75, half.y * 0.75)
		var jitter := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.0, scatter_radius_px)
		var pos := global_position + Vector2(rx, ry) + jitter

		if not require_walkable or cm == null or not is_instance_valid(cm):
			return pos

		if cm.has_method("world_to_cell") and cm.has_method("is_cell_walkable"):
			var cell: Vector2i = cm.call("world_to_cell", pos)
			if bool(cm.call("is_cell_walkable", cell)):
				return pos

	if cm != null and is_instance_valid(cm) and cm.has_method("is_cell_walkable") and cm.has_method("cell_to_world_center"):
		var center_cell: Vector2i = cm.call("world_to_cell", global_position) as Vector2i
		var best_cell: Vector2i = Vector2i.ZERO
		var best_distance: float = INF
		var found: bool = false
		for y in range(cell_tl.y, cell_tl.y + size_cells.y):
			for x in range(cell_tl.x, cell_tl.x + size_cells.x):
				var cell := Vector2i(x, y)
				if not bool(cm.call("is_cell_walkable", cell)):
					continue
				var distance: float = Vector2(cell - center_cell).length_squared()
				if distance < best_distance:
					best_distance = distance
					best_cell = cell
					found = true
		if found:
			return cm.call("cell_to_world_center", best_cell) as Vector2

	return Vector2.INF


func _mix_seed(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h


## The parcel supplies its real carved doorway. No detection, collision, or
## encounter rule depends on this visual pose.
func configure_presentation_entry(world_point: Vector2, outward: Vector2, width_px: float) -> void:
	_presentation_enabled = exploration_loot_enabled and (local_encounter_enabled or secondary_objective_id > 0)
	_presentation_entry = to_local(world_point)
	_presentation_outward = outward.normalized()
	_presentation_width = width_px
	if not _presentation_enabled:
		return
	_entry_sign = _make_exploration_label("BuildingEntrySign")
	_entry_sign.position = _presentation_entry + _presentation_outward * (float(cell_size_px) * 0.8 + 16.0) - Vector2(190, 12)
	_room_sign = _make_exploration_label("BuildingSecurityStatus")
	_room_sign.position = Vector2(-190, -float(size_cells.y * cell_size_px) * 0.32)
	_room_floor = Polygon2D.new()
	_room_floor.name = "ServiceRoomFloorTone"
	var half := Vector2(size_cells) * float(cell_size_px) * 0.5
	_room_floor.polygon = PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	_room_floor.color = Color(0.075, 0.065, 0.05, 0.16)
	_room_floor.z_index = -80
	add_child(_room_floor)
	_sync_exploration_presentation()
	queue_redraw()


func presentation_status() -> String:
	if _encounter_completed:
		return "Security cleared · loot on floor" if _has_floor_reward() else "Security cleared"
	if local_encounter_enabled:
		if _encounter_started:
			return "%d security remaining" % _encounter_remaining if _encounter_remaining > 0 else "Security arriving"
		return "Enter and clear security"
	return "Loot on floor" if _has_floor_reward() else ("Room searched" if _loot_attempted else "Enter and search")


func _has_floor_reward() -> bool:
	for reference in _reward_refs:
		var pickup := reference.get_ref() as Node
		if pickup != null and is_instance_valid(pickup) and pickup.is_inside_tree() and not pickup.is_queued_for_deletion():
			return true
	return false


func _make_exploration_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.size = Vector2(380, 58)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.69))
	label.add_theme_color_override("font_outline_color", Color(0.055, 0.05, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 3
	add_child(label)
	return label


func _sync_exploration_presentation() -> void:
	if not _presentation_enabled or _entry_sign == null:
		return
	var status := presentation_status()
	_entry_sign.text = status
	_entry_sign.visible = not _player_inside
	_room_sign.text = status
	_room_sign.visible = _player_inside
	queue_redraw()


func _draw() -> void:
	if not _presentation_enabled:
		return
	var side := _presentation_outward.orthogonal()
	var half_span := _presentation_width * 0.5
	var dark := Color(0.08, 0.075, 0.055, 0.9)
	var stone := Color(0.56, 0.55, 0.45, 0.85)
	var at := _presentation_entry
	# Broad modest threshold follows the existing hole; nothing blocks the door.
	draw_line(at - side * half_span, at + side * half_span, dark, 12.0, true)
	draw_line(at - side * half_span, at + side * half_span, stone, 5.0, true)
	for direction in [-1.0, 1.0]:
		var jamb: Vector2 = at + side * (half_span + 7.0) * float(direction)
		draw_line(jamb - _presentation_outward * 14.0, jamb + _presentation_outward * 14.0, dark, 10.0, true)
		draw_line(jamb - _presentation_outward * 14.0, jamb + _presentation_outward * 14.0, stone, 4.0, true)
	# A plain supply/search plaque becomes an open (cleared) bracket.
	var plaque := at + _presentation_outward * 34.0
	draw_circle(plaque, 13, dark)
	var ink := Color(0.86, 0.8, 0.59)
	if _encounter_completed or _loot_attempted:
		draw_polyline(PackedVector2Array([plaque + Vector2(-7, -4), plaque + Vector2(-7, 5), plaque + Vector2(7, 5), plaque + Vector2(7, -4)]), ink, 2.0, true)
	else:
		draw_rect(Rect2(plaque - Vector2(6, 7), Vector2(12, 14)), ink, false, 2.0)
		draw_line(plaque + Vector2(-3, 0), plaque + Vector2(3, 0), ink, 2.0, true)
