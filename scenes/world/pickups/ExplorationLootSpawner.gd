extends Node2D
class_name ExplorationLootSpawner

@export var loot_id: int = 0

@export_group("Chance (deterministic)")
@export var spawn_chance: float = 1.0 # if caller already rolled, keep at 1.0

@export_group("Drops")
@export var count_min: int = 1
@export var count_max: int = 1
@export var rarity_min: int = 3
@export var rarity_max: int = 5
@export var rarity_bonus_per_segment: int = 0

@export_group("Scatter / Placement")
@export var scatter_radius: float = 28.0
@export var pickup_delay: float = 0.15
@export var require_walkable: bool = true
@export var pos_attempts: int = 12

@export_group("Spawn timing (robust)")
@export var max_wait_sec: float = 3.0        # wait for Global.item_db etc to be ready
@export var try_interval_sec: float = 0.10   # how often to retry while waiting

@export_group("Debug")
@export var debug_draw_marker: bool = true  # set true temporarily to verify spawner placement
@export var debug_marker_radius: float = 22.0

@export var pickup_scene: PackedScene = preload("res://scenes/world/pickups/ItemPickup.tscn")

var _cm: Node = null
var _rng: RandomNumberGenerator = null
var _elapsed: float = 0.0
var _should_spawn: bool = false
var _done: bool = false

func _ready() -> void:
	if loot_id == 0:
		queue_free()
		return

	_cm = get_tree().get_first_node_in_group("chunk_manager")
	_rng = RandomNumberGenerator.new()
	_rng.seed = _mix_seed((Global.attempt_world_seed if Global != null else 1337), loot_id)

	# Deterministic “has loot?” roll (caller can set spawn_chance=1 if already rolled).
	_should_spawn = (_rng.randf() <= clampf(spawn_chance, 0.0, 1.0))
	if not _should_spawn:
		queue_free()
		return

	# If already claimed (streaming duplication), bail.
	if Global != null and Global.has_claimed_loot(loot_id):
		queue_free()
		return

	# Use timers (not _process) so this still works even if parent chunks don't process.
	_try_spawn()

func _try_spawn() -> void:
	if _done:
		return
	if Global != null and Global.has_claimed_loot(loot_id):
		_done = true
		queue_free()
		return

	# Wait until DB is ready.
	if pickup_scene == null or Global == null or Global.item_db.is_empty():
		_elapsed += try_interval_sec
		if _elapsed >= max_wait_sec:
			_done = true
			queue_free()
			return
		var t := get_tree().create_timer(try_interval_sec)
		t.timeout.connect(_try_spawn)
		return

	# Spawn now.
	var spawned_any := _spawn_loot(_rng)
	if spawned_any and Global != null:
		Global.claim_loot(loot_id)

	_done = true
	queue_free()

func _spawn_loot(rng: RandomNumberGenerator) -> bool:
	if pickup_scene == null:
		return false
	if Global == null or Global.item_db.is_empty():
		return false

	var keys: Array = Global.item_db.keys()
	if keys.is_empty():
		return false

	var seg: int = (Global.attempt_segment if Global != null else 1)
	var bonus: int = rarity_bonus_per_segment * maxi(0, seg - 1)

	var n: int = rng.randi_range(maxi(1, count_min), maxi(1, count_max))
	var made := false

	for _i in range(n):
		var item_key = keys[rng.randi_range(0, keys.size() - 1)]
		var item_id_str: String = str(item_key)
		var data: ItemData = Global.get_item_data(item_id_str)
		if data == null:
			continue

		var rmin := rarity_min + bonus
		var rmax := rarity_max + bonus
		var rarity: int = rng.randi_range(rmin, rmax)

		var roll_pct: float = Global.roll_percent(Global.run_luck, data.pct_min, data.pct_max)
		var pol: int = (ItemInstance.Polarity.POS if roll_pct >= 0.0 else ItemInstance.Polarity.NEG)
		roll_pct = absf(roll_pct) * (1.0 if pol == ItemInstance.Polarity.POS else -1.0)

		var inst := ItemInstance.from_roll(data, rarity, pol, roll_pct)

		var p := pickup_scene.instantiate() as ItemPickup
		if p == null:
			continue

		# Ensure visuals initialize correctly (enemy drops also set both).
		p.item_instance = inst
		p.item_id = str(data.id)
		p.amount = 1
		p.pickup_delay = pickup_delay
		p.is_exploration_loot = true

		p.global_position = _pick_pos(rng)

		get_tree().current_scene.call_deferred("add_child", p)
		made = true

	return made

func _pick_pos(rng: RandomNumberGenerator) -> Vector2:
	if scatter_radius <= 0.01:
		return global_position

	if not require_walkable or _cm == null or not is_instance_valid(_cm):
		return global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.0, scatter_radius)

	# try to find a walkable cell near the spawner point
	for _k in range(maxi(1, pos_attempts)):
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		var r := rng.randf_range(0.0, scatter_radius)
		var pos := global_position + dir * r

		if _cm.has_method("world_to_cell") and _cm.has_method("is_cell_walkable"):
			var cell: Vector2i = _cm.call("world_to_cell", pos)
			if bool(_cm.call("is_cell_walkable", cell)):
				return pos

	return global_position

func _mix_seed(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h

func _draw() -> void:
	if not debug_draw_marker:
		return
	draw_arc(Vector2.ZERO, debug_marker_radius, 0.0, TAU, 48, Color(0.15, 1.0, 1.0, 0.95), 3.0, true)
	draw_line(Vector2(-debug_marker_radius, 0), Vector2(debug_marker_radius, 0), Color(0.15, 1.0, 1.0, 0.65), 2.0, true)
	draw_line(Vector2(0, -debug_marker_radius), Vector2(0, debug_marker_radius), Color(0.15, 1.0, 1.0, 0.65), 2.0, true)
