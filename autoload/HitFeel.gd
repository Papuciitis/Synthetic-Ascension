extends Node

## Baseline hit feel (roadmap Phase 2.1): the "immediate hit" that has to land
## before buildcraft does anything. Two cheap, tunable effects:
##
##   HIT-STOP    a brief Engine.time_scale dip when an elite, a boss or a crit
##               kill lands.
##   CAMERA PUNCH a short kick of the player's Camera2D offset when the player
##               is hurt (away from the source) or an elite or boss dies
##               (toward the body), decaying every frame.
##
## The feedback budget (audit and research 2026-10-04, lesson 11): with 300
## enemies on screen, per-hit or per-kill feedback is noise, and the 2026-09-06
## playtest read exactly that as lag - it cut time to 5% for 60 ms on EVERY
## kill and let a new stop start 120 ms after the last, so at 7.5 kills/s about
## a third of wall time was frozen in a 5 Hz stutter. Only player-relevant
## events drive it now: elite and boss kills, crit kills and the player being
## hurt, never fodder. A stop dips to 25% (not 5%), at most once per 600 ms.
##
## Every number is an export so tuning needs no code. Both effects respect the
## accessibility "reduced_motion" setting and the "hit_feel" toggle. Nothing
## here touches gameplay state: the stop is real-time bounded and restored on
## exit, the punch is an offset.

@export var hit_stop_enabled := true
@export var camera_punch_enabled := true
## time_scale during a stop. Not zero, and not the old 0.05: at a quarter speed
## sound and VFX keep moving, so a stop reads as weight rather than a hitch.
@export_range(0.0, 0.5, 0.01) var stop_scale := 0.25
## Stop lengths in real milliseconds per trigger; the longest applicable wins.
@export var stop_ms := {
	"elite_kill": 45,
	"boss_kill": 45,
	"crit_kill": 30,
}
## A new stop needs this long since the last one STARTED; inside the window a
## trigger can only extend the current stop, and never past max_stop_ms.
@export_range(30, 2000, 10) var min_stop_interval_ms := 600
@export_range(10, 200, 5) var max_stop_ms := 60
## Camera kick in pixels: away from what hurt the player, toward a dying elite.
## A hurt kick scales from hurt_punch_min_px (a scratch) up to the "hurt"
## figure (a hit worth 15% of max HP or more).
@export var punch_px := {
	"hurt": 6.0,
	"elite_kill": 6.0,
}
@export_range(0.0, 10.0, 0.5) var hurt_punch_min_px := 2.5
## A contact swarm ticks every 0.5 s; one kick per tick is plenty, never more.
@export_range(0, 2000, 10) var hurt_punch_interval_ms := 250
## punch_decay is expressed per frame at this reference rate, so the same
## number decays identically at any refresh rate. Not the physics tick rate:
## the punch decays in wall-clock time, deliberately (see _process).
const PUNCH_DECAY_REFERENCE_HZ: float = 60.0
# Three pixels per 60 Hz reference frame leaves a 6 px kick a short two-frame
# ease. The previous 16 erased every authored kick in one frame, so the camera
# snapped out and back like a render hitch instead of punching (2026-09-06).
@export_range(1.0, 40.0, 0.5) var punch_decay := 3.0
@export_range(0.0, 40.0, 0.5) var punch_max_px := 8.0
## How long after a Lucky Crit attack its hits are watched for a crit kill.
## Crits are ~1% of attacks, so the per-hit signal is only listened to in
## these windows: while nothing listens, EnemyCombatService skips emitting it.
const CRIT_WATCH_MS := 900
## A crit hit and the kill it causes arrive in the same damage call.
const CRIT_KILL_MATCH_MS := 50

var _stop_until_msec := 0
var _last_stop_msec := -100000
var _stop_active := false
var _punch_offset := Vector2.ZERO
var _camera: Camera2D = null
var _player_ref: WeakRef = null
var _last_hurt_punch_msec := -100000
var _crit_watch_until_msec := 0
var _crit_handle := 0
var _crit_handle_msec := -100000
var _counters := {
	"kills_seen": 0,
	"stops_requested": 0,
	"stops_applied": 0,
	"punches": 0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if RunEvents != null:
		RunEvents.enemy_defeated.connect(_on_enemy_defeated)
		RunEvents.player_damage_taken.connect(_on_player_damage_taken)
		RunEvents.player_lucky_crit.connect(_on_player_lucky_crit)


func _exit_tree() -> void:
	_release_stop()
	_stop_crit_watch()


func _process(delta: float) -> void:
	if _stop_active and Time.get_ticks_msec() >= _stop_until_msec:
		_release_stop()
	if _crit_watch_until_msec != 0 and Time.get_ticks_msec() >= _crit_watch_until_msec:
		_stop_crit_watch()
	if _punch_offset != Vector2.ZERO:
		# Wall-clock decay: delta is scaled by the stop itself.
		var real_delta := delta / maxf(Engine.time_scale, 0.001)
		_punch_offset = _punch_offset.move_toward(Vector2.ZERO, punch_decay * PUNCH_DECAY_REFERENCE_HZ * real_delta)
		if _punch_offset.length_squared() < 0.01:
			_punch_offset = Vector2.ZERO
		_apply_punch()


# --- signal handlers --------------------------------------------------------

## Every defeat passes here (proxy and actor alike), so this must stay cheap
## for fodder: flag tests, one actor lookup (a boss grouped after it
## registered carries no boss flag) and a handle compare, then out.
func _on_enemy_defeated(context: RefCounted) -> void:
	if context == null:
		return
	_counters["kills_seen"] = int(_counters["kills_seen"]) + 1
	var flags := int(context.get("flags"))
	var handle := int(context.get("handle"))
	var elite := EnemyWorldTypes.has_flag(flags, EnemyWorldTypes.Flags.ELITE)
	var boss := not elite and _is_boss(flags, handle)
	var crit := (
		handle != 0
		and handle == _crit_handle
		and Time.get_ticks_msec() - _crit_handle_msec <= CRIT_KILL_MATCH_MS
	)
	if not elite and not boss and not crit:
		return
	var longest := 0
	if elite:
		longest = maxi(longest, int(stop_ms.get("elite_kill", 0)))
	if boss:
		longest = maxi(longest, int(stop_ms.get("boss_kill", 0)))
	if crit:
		longest = maxi(longest, int(stop_ms.get("crit_kill", 0)))
		_crit_handle = 0
	request_stop(longest)
	if elite or boss:
		var player := _player()
		if player != null:
			punch_toward(player, context.get("position") as Vector2, float(punch_px.get("elite_kill", 6.0)))


func _on_player_damage_taken(player: Node, amount: float, position: Vector2) -> void:
	if amount <= 0.0:
		return
	var player_2d := player as Node2D
	if player_2d == null or not is_instance_valid(player_2d):
		return
	var now := Time.get_ticks_msec()
	if now - _last_hurt_punch_msec < hurt_punch_interval_ms:
		return
	var max_hp := maxf(1.0, float(player_2d.get("max_hp")) if "max_hp" in player_2d else 100.0)
	var weight := clampf(amount / (0.15 * max_hp), 0.0, 1.0)
	var pixels := lerpf(hurt_punch_min_px, float(punch_px.get("hurt", 6.0)), weight)
	# Kick AWAY from the source of the damage.
	if punch_direction(player_2d, player_2d.global_position - position, pixels):
		_last_hurt_punch_msec = now


## A Lucky Crit attack is the only crit source. Its hits are watched for a
## short window so the kill it lands can be recognised as a crit kill.
func _on_player_lucky_crit(_player: Node, _position: Vector2, succeeded: bool) -> void:
	if not succeeded or not hit_stop_enabled:
		return
	_crit_watch_until_msec = Time.get_ticks_msec() + CRIT_WATCH_MS
	if RunEvents != null and not RunEvents.player_hit_landed.is_connected(_on_crit_watch_hit):
		RunEvents.player_hit_landed.connect(_on_crit_watch_hit)


func _on_crit_watch_hit(_source: Node, handle: int, _position: Vector2, _amount: float, is_crit: bool, _is_elite: bool) -> void:
	if is_crit:
		_crit_handle = handle
		_crit_handle_msec = Time.get_ticks_msec()


# --- effects ----------------------------------------------------------------

func request_stop(duration_ms: int) -> void:
	_counters["stops_requested"] = int(_counters["stops_requested"]) + 1
	if not hit_stop_enabled or duration_ms <= 0 or not _feel_allowed():
		return
	var tree := get_tree()
	if tree != null and tree.paused:
		return
	var now := Time.get_ticks_msec()
	var until := now + mini(duration_ms, max_stop_ms)
	if _stop_active:
		# Inside the budget window: extend, never restart, never past the cap.
		_stop_until_msec = mini(maxi(_stop_until_msec, until), _last_stop_msec + max_stop_ms)
		return
	if now - _last_stop_msec < min_stop_interval_ms:
		return
	# Never clobber someone else's time_scale: menus, the opening's slow
	# cards, Deadshot and JUDGEMENT all own it while they run, slower or not.
	if not is_equal_approx(Engine.time_scale, 1.0):
		return
	_stop_active = true
	_last_stop_msec = now
	_stop_until_msec = until
	Engine.time_scale = stop_scale
	_counters["stops_applied"] = int(_counters["stops_applied"]) + 1


func punch_toward(player: Node2D, target: Vector2, pixels: float) -> bool:
	return punch_direction(player, target - player.global_position, pixels)


func punch_direction(player: Node2D, direction: Vector2, pixels: float) -> bool:
	if not camera_punch_enabled or pixels <= 0.0 or not _feel_allowed():
		return false
	var camera := _camera_for(player)
	if camera == null:
		return false
	var dir := direction.normalized() if direction != Vector2.ZERO else Vector2.DOWN
	_punch_offset = (_punch_offset + dir * pixels).limit_length(punch_max_px)
	_counters["punches"] = int(_counters["punches"]) + 1
	_apply_punch()
	return true


func punch_offset() -> Vector2:
	return _punch_offset


func is_stopped() -> bool:
	return _stop_active


func is_watching_crits() -> bool:
	return RunEvents != null and RunEvents.player_hit_landed.is_connected(_on_crit_watch_hit)


func get_debug_counters() -> Dictionary:
	return _counters.duplicate()


# --- internals --------------------------------------------------------------

func _release_stop() -> void:
	if not _stop_active:
		return
	_stop_active = false
	# Only restore what we set; another system may have taken over since.
	if is_equal_approx(Engine.time_scale, stop_scale):
		Engine.time_scale = 1.0


func _stop_crit_watch() -> void:
	_crit_watch_until_msec = 0
	if RunEvents != null and RunEvents.player_hit_landed.is_connected(_on_crit_watch_hit):
		RunEvents.player_hit_landed.disconnect(_on_crit_watch_hit)


## Bosses register CRITICAL without OBJECTIVE or TUTORIAL (EnemyWorld's flag
## map); a boss grouped after it registered is caught by its groups.
func _is_boss(flags: int, handle: int) -> bool:
	if EnemyWorldTypes.has_flag(flags, EnemyWorldTypes.Flags.CRITICAL):
		if not EnemyWorldTypes.has_flag(flags, EnemyWorldTypes.Flags.OBJECTIVE) and not EnemyWorldTypes.has_flag(flags, EnemyWorldTypes.Flags.TUTORIAL):
			return true
	if handle == 0 or EnemyWorld == null or not EnemyWorld.is_valid_handle(handle):
		return false
	var actor := EnemyWorld.actor_for_handle(handle)
	return actor != null and (actor.is_in_group(&"boss_like") or actor.is_in_group(&"boss"))


func _player() -> Node2D:
	if _player_ref != null:
		var cached := _player_ref.get_ref() as Node2D
		if cached != null and cached.is_inside_tree():
			return cached
	var tree := get_tree()
	if tree == null:
		return null
	var found := tree.get_first_node_in_group(&"player") as Node2D
	_player_ref = weakref(found) if found != null else null
	return found


func _apply_punch() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_camera.offset = _punch_offset


func _camera_for(player: Node2D) -> Camera2D:
	if _camera != null and is_instance_valid(_camera) and _camera.get_parent() == player:
		return _camera
	_camera = player.get_node_or_null("Camera2D") as Camera2D
	return _camera


## Reduced Motion turns both effects off, and so does their own toggle.
func _feel_allowed() -> bool:
	if SettingsManager == null:
		return true
	if bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false)):
		return false
	return bool(SettingsManager.get_value(&"accessibility", &"hit_feel", true))
