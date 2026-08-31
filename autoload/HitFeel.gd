extends Node

## Baseline hit feel (roadmap Phase 2.1): the "immediate hit" that has to land
## before buildcraft does anything. Two cheap, tunable effects driven by the
## combat signals every weapon already emits:
##
##   HIT-STOP    a brief Engine.time_scale dip on crits, elite hits and kills,
##               budgeted so a 550-bullet torrent cannot chain-freeze the game.
##   CAMERA PUNCH a short kick of the player's Camera2D offset toward the hit
##               (melee hardest, pellets lightest), decaying every frame.
##
## Every number is an export so tuning needs no code. Both effects respect the
## accessibility "reduced_motion" setting. Nothing here touches gameplay state:
## the stop is real-time bounded and restored on exit, the punch is an offset.

const STYLE_MELEE := &"melee"
const STYLE_RANGED := &"ranged"
const STYLE_MAGIC := &"magic"

@export var hit_stop_enabled := true
@export var camera_punch_enabled := true
## time_scale during a stop. Not zero: sound and VFX keep breathing.
@export_range(0.0, 0.5, 0.01) var stop_scale := 0.05
## Stop lengths in real milliseconds per trigger; the longest applicable wins.
@export var stop_ms := {
	"crit": 45,
	"elite": 30,
	"kill": 60,
	"melee": 35,
}
## A new stop within this window only extends the current one.
@export_range(30, 1000, 10) var min_stop_interval_ms := 120
## Camera kick in pixels per weapon style, and for kills.
@export var punch_px := {
	"melee": 9.0,
	"ranged": 3.5,
	"magic": 6.0,
	"kill": 6.0,
	"hurt": 12.0,
}
## punch_decay is expressed per frame at this reference rate, so the same
## number decays identically at any refresh rate. Not the physics tick rate:
## the punch decays in wall-clock time, deliberately (see _process).
const PUNCH_DECAY_REFERENCE_HZ: float = 60.0
@export_range(1.0, 40.0, 0.5) var punch_decay := 16.0
@export_range(0.0, 40.0, 0.5) var punch_max_px := 18.0

var _stop_until_msec := 0
var _last_stop_msec := -100000
var _stop_active := false
var _punch_offset := Vector2.ZERO
var _camera: Camera2D = null
var _counters := {
	"hits": 0,
	"stops_requested": 0,
	"stops_applied": 0,
	"punches": 0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RunEvents != null:
		RunEvents.player_hit_landed.connect(_on_player_hit_landed)
		RunEvents.enemy_killed.connect(_on_enemy_killed)
		RunEvents.player_damage_taken.connect(_on_player_damage_taken)


func _exit_tree() -> void:
	_release_stop()


func _process(delta: float) -> void:
	if _stop_active and Time.get_ticks_msec() >= _stop_until_msec:
		_release_stop()
	if _punch_offset != Vector2.ZERO:
		# Wall-clock decay: delta is scaled by the stop itself.
		var real_delta := delta / maxf(Engine.time_scale, 0.001)
		_punch_offset = _punch_offset.move_toward(Vector2.ZERO, punch_decay * PUNCH_DECAY_REFERENCE_HZ * real_delta)
		if _punch_offset.length_squared() < 0.01:
			_punch_offset = Vector2.ZERO
		_apply_punch()


# --- signal handlers --------------------------------------------------------

func _on_player_hit_landed(source: Node, _handle: int, position: Vector2, _amount: float, is_crit: bool, is_elite: bool) -> void:
	_counters["hits"] = int(_counters["hits"]) + 1
	var style := _current_style()
	# The cheap path: an ordinary pellet on an ordinary enemy does nothing
	# beyond a light punch. This handler runs per pellet per target.
	if is_crit or is_elite or style == STYLE_MELEE:
		var longest := 0
		if is_crit:
			longest = maxi(longest, int(stop_ms.get("crit", 0)))
		if is_elite:
			longest = maxi(longest, int(stop_ms.get("elite", 0)))
		if style == STYLE_MELEE:
			longest = maxi(longest, int(stop_ms.get("melee", 0)))
		request_stop(longest)
	var player := source as Node2D
	if player != null and is_instance_valid(player):
		punch_toward(player, position, float(punch_px.get(String(style), 3.5)))


func _on_enemy_killed(player: Node, _enemy: Node, position: Vector2) -> void:
	request_stop(int(stop_ms.get("kill", 0)))
	var player_2d := player as Node2D
	if player_2d != null and is_instance_valid(player_2d):
		punch_toward(player_2d, position, float(punch_px.get("kill", 6.0)))


func _on_player_damage_taken(player: Node, amount: float, position: Vector2) -> void:
	if amount <= 0.0:
		return
	var player_2d := player as Node2D
	if player_2d != null and is_instance_valid(player_2d):
		# Kick AWAY from the source of the damage.
		var away := (player_2d.global_position - position)
		punch_direction(player_2d, away, float(punch_px.get("hurt", 12.0)))


# --- effects ----------------------------------------------------------------

func request_stop(duration_ms: int) -> void:
	_counters["stops_requested"] = int(_counters["stops_requested"]) + 1
	if not hit_stop_enabled or duration_ms <= 0 or _reduced_motion():
		return
	var tree := get_tree()
	if tree != null and tree.paused:
		return
	var now := Time.get_ticks_msec()
	var until := now + duration_ms
	if _stop_active:
		# Inside the budget window: extend, never restart.
		_stop_until_msec = maxi(_stop_until_msec, until)
		return
	if now - _last_stop_msec < min_stop_interval_ms:
		return
	# Never clobber someone else's time_scale (menus, cinematics).
	if not is_equal_approx(Engine.time_scale, 1.0):
		return
	_stop_active = true
	_last_stop_msec = now
	_stop_until_msec = until
	Engine.time_scale = stop_scale
	_counters["stops_applied"] = int(_counters["stops_applied"]) + 1


func punch_toward(player: Node2D, target: Vector2, pixels: float) -> void:
	punch_direction(player, target - player.global_position, pixels)


func punch_direction(player: Node2D, direction: Vector2, pixels: float) -> void:
	if not camera_punch_enabled or pixels <= 0.0 or _reduced_motion():
		return
	var camera := _camera_for(player)
	if camera == null:
		return
	var dir := direction.normalized() if direction != Vector2.ZERO else Vector2.DOWN
	_punch_offset = (_punch_offset + dir * pixels).limit_length(punch_max_px)
	_counters["punches"] = int(_counters["punches"]) + 1
	_apply_punch()


func punch_offset() -> Vector2:
	return _punch_offset


func is_stopped() -> bool:
	return _stop_active


func get_debug_counters() -> Dictionary:
	return _counters.duplicate()


# --- internals --------------------------------------------------------------

func _release_stop() -> void:
	if not _stop_active:
		return
	_stop_active = false
	# Only restore what we set; another system may have taken over.
	if is_equal_approx(Engine.time_scale, stop_scale):
		Engine.time_scale = 1.0


func _apply_punch() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_camera.offset = _punch_offset


func _camera_for(player: Node2D) -> Camera2D:
	if _camera != null and is_instance_valid(_camera) and _camera.get_parent() == player:
		return _camera
	_camera = player.get_node_or_null("Camera2D") as Camera2D
	return _camera


func _current_style() -> StringName:
	if Global == null:
		return STYLE_RANGED
	var style := String(Global.get("selected_style_id"))
	match style:
		"melee":
			return STYLE_MELEE
		"magic":
			return STYLE_MAGIC
	return STYLE_RANGED


func _reduced_motion() -> bool:
	if SettingsManager == null:
		return false
	return bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
