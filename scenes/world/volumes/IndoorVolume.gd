extends Area2D
class_name IndoorVolume

@export var cell_size_px: int = 64
@export var cell_tl: Vector2i = Vector2i.ZERO
@export var size_cells: Vector2i = Vector2i(1, 1)
@export var building_id: int = 0

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
@export var scatter_radius_px: float = 90.0
@export var pickup_delay: float = 0.15
@export var require_walkable: bool = true
@export var pos_attempts: int = 14

@export var pickup_scene: PackedScene = preload("res://scenes/world/pickups/ItemPickup.tscn")

var _loot_attempted: bool = false


func _ready() -> void:
	# This volume is only used for detecting if the player is indoors.
	monitoring = true
	monitorable = true
	_update_shape()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func configure(tl: Vector2i, sz: Vector2i, cs: int, id: int) -> void:
	cell_tl = tl
	size_cells = sz
	cell_size_px = cs
	building_id = id
	_update_shape()


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
	if _loot_attempted:
		return
	if not exploration_loot_enabled:
		return
	if b == null or not b.is_in_group("player"):
		return

	_loot_attempted = true

	if building_id == 0:
		return
	if Global != null and Global.has_claimed_loot(building_id):
		return
	if pickup_scene == null or Global == null or Global.item_db.is_empty():
		return

	# Determine if this is a "big dungeon" volume.
	var area_cells: int = maxi(0, size_cells.x) * maxi(0, size_cells.y)
	var is_large: bool = area_cells >= large_area_threshold_cells

	# Deterministic roll per building/volume.
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed((Global.attempt_world_seed if Global != null else 1337), building_id)

	var chance: float = (1.0 if is_large else clampf(small_loot_chance, 0.0, 1.0))
	if rng.randf() > chance:
		return

	var n_min: int = (large_count_min if is_large else small_count_min)
	var n_max: int = (large_count_max if is_large else small_count_max)
	var r_min: int = (large_rarity_min if is_large else small_rarity_min)
	var r_max: int = (large_rarity_max if is_large else small_rarity_max)

	if _spawn_loot(rng, n_min, n_max, r_min, r_max):
		if Global != null:
			Global.claim_loot(building_id)


func _spawn_loot(rng: RandomNumberGenerator, n_min: int, n_max: int, r_min: int, r_max: int) -> bool:
	var keys: Array = Global.item_db.keys()
	if keys.is_empty():
		return false

	var n: int = rng.randi_range(maxi(1, n_min), maxi(1, n_max))
	var made := false

	for _i in range(n):
		var item_key = keys[rng.randi_range(0, keys.size() - 1)]
		var item_id_str: String = str(item_key)
		var data: ItemData = Global.get_item_data(item_id_str)
		if data == null:
			continue

		var rarity: int = rng.randi_range(r_min, r_max)

		var roll_pct: float = Global.roll_percent(Global.run_luck, data.pct_min, data.pct_max)
		var pol: int = (ItemInstance.Polarity.POS if roll_pct >= 0.0 else ItemInstance.Polarity.NEG)
		roll_pct = absf(roll_pct) * (1.0 if pol == ItemInstance.Polarity.POS else -1.0)

		var inst := ItemInstance.from_roll(data, rarity, pol, roll_pct)

		var p := pickup_scene.instantiate() as ItemPickup
		if p == null:
			continue

		p.item_instance = inst
		p.item_id = str(data.id)
		p.amount = 1
		p.pickup_delay = pickup_delay
		p.is_exploration_loot = true

		p.global_position = _pick_pos_in_volume(rng)

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

	return global_position


func _mix_seed(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h
