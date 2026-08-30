extends Node2D
class_name RitualInterference

## Ritual interference (roadmap §8.1 "local rules temporarily change", Phase
## 2.7): while the district collapses, one rule bends inside a sigil drawn on
## the ground. Here the rule is THE DEAD RISE - anything killed inside the ring
## stands back up after revive_delay as a revenant of the same archetype at a
## fraction of its health, once. Built from script (ring + a listener on
## RunEvents.enemy_defeated) like CursedVault so it needs no scene; the
## EncounterDirector places one ahead of travel like any other beat and it
## ends itself after duration, or when the director despawns it.
##
## Cost discipline: the defeat listener is connected only while the ritual is
## alive and does one distance check per kill before anything else; revenants
## go through the spawner's beat API (protected specials, capped) and carry
## REVENANT_META so their own death never rises again. The ring redraws
## through pulse_redraw() at 30 Hz - or once a second with no breathing under
## the accessibility reduced_motion setting - and wipes once when it ends.

signal expired(ritual: RitualInterference)

const COLOUR := Color(0.55, 0.92, 0.62, 1.0)
const REVENANT_META := &"ritual_revenant"
const TEACH := "Kills inside the sigil rise once, weakened. Fight outside it, or kill them twice."
## Steady-state ring redraw cadence (the ManifestationEffect idiom), and the
## slower step used while motion is reduced.
const PULSE_REDRAW_MS := 33
const STATIC_REDRAW_MS := 1000

## Kills within this many px of the sigil's centre rise.
@export var radius := 420.0
## Seconds the rule holds before the ring wipes.
@export var duration := 30.0
## Seconds a corpse lies still before it stands.
@export var revive_delay := 1.6
## A revenant's max HP as a fraction of its archetype's current (threat-scaled) max.
@export_range(0.05, 1.0, 0.05) var revenant_hp_fraction := 0.35
## Rises per ritual; corpses still waiting count against it.
@export_range(1, 32, 1) var max_revenants := 8
## The revenant's sprite tint: the tell on the thing itself.
@export var revenant_tint := Color(0.55, 1.0, 0.70, 0.92)

## Seam for tests: actor_provider(handle: int) -> Node stands in for EnemyWorld.
var actor_provider: Callable = Callable()

var _spawner: Node = null
var _time_left := 0.0
var _pending: Array[Dictionary] = []
var _raised := 0
var _expired := false
var _reduced_motion := false
var _last_pulse_bucket: int = -1


func _ready() -> void:
	add_to_group(&"ritual_interference")
	z_index = 5
	_time_left = duration
	_reduced_motion = _read_reduced_motion()
	if RunEvents != null and RunEvents.has_signal("enemy_defeated"):
		var cb := Callable(self, "_on_enemy_defeated")
		if not RunEvents.enemy_defeated.is_connected(cb):
			RunEvents.enemy_defeated.connect(cb)
	set_process(true)
	queue_redraw()


## Called by the EncounterDirector once placed. `teach` is true for the first
## ritual of the run, so the rule is explained once per run at first sight.
func setup(spawner: Node, teach: bool = false) -> void:
	_spawner = spawner
	if teach and RunEvents != null and RunEvents.has_signal("tutorial_tip"):
		RunEvents.tutorial_tip.emit(TEACH, 4.0)


func _process(delta: float) -> void:
	if _expired:
		return
	_time_left -= delta
	if not _pending.is_empty():
		_tick_pending(delta)
	if _time_left <= 0.0:
		expire(&"duration")
		return
	if _reduced_motion:
		_bucket_redraw(STATIC_REDRAW_MS)
	else:
		pulse_redraw()


func contains(world_pos: Vector2) -> bool:
	return world_pos.distance_squared_to(global_position) <= radius * radius


func is_expired() -> bool:
	return _expired


func raised() -> int:
	return _raised


func pending() -> int:
	return _pending.size()


func time_left() -> float:
	return _time_left


## The director's ending verb for any beat member (its abort path).
func despawn(reason: StringName = &"beat_aborted") -> void:
	expire(reason)


func expire(reason: StringName = &"duration") -> void:
	if _expired:
		return
	_expired = true
	_pending.clear()
	set_process(false)
	if RunEvents != null and RunEvents.has_signal("enemy_defeated"):
		var cb := Callable(self, "_on_enemy_defeated")
		if RunEvents.enemy_defeated.is_connected(cb):
			RunEvents.enemy_defeated.disconnect(cb)
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_counter_event(&"encounter", &"ritual_expired", 1, {
			"reason": String(reason),
			"raised": _raised,
		})
	expired.emit(self)
	# One last wipe before the node goes.
	queue_redraw()
	queue_free()


# --- the rule ---------------------------------------------------------------

func _on_enemy_defeated(context: RefCounted) -> void:
	if _expired or context == null or _raised + _pending.size() >= max_revenants:
		return
	var pos: Variant = context.get("position")
	if not (pos is Vector2) or not contains(pos as Vector2):
		return
	var actor := _actor_for(int(context.get("handle")))
	# A data-only proxy has no actor to read an archetype from (the far path
	# skips its drops too), and a revenant rises only once.
	if actor == null or not is_instance_valid(actor) or actor.has_meta(REVENANT_META):
		return
	var scene_path: String = actor.scene_file_path
	if scene_path.is_empty():
		return
	_pending.append({
		"scene": scene_path,
		"pos": pos as Vector2,
		"t": revive_delay,
		"enemy_id": String(context.get("spec_id")),
	})
	# A state change, not steady state: a corpse marker appears.
	queue_redraw()


func _tick_pending(delta: float) -> void:
	var i := 0
	while i < _pending.size():
		var entry: Dictionary = _pending[i]
		entry["t"] = float(entry["t"]) - delta
		if float(entry["t"]) > 0.0:
			i += 1
			continue
		_pending.remove_at(i)
		_raise(entry)


func _raise(entry: Dictionary) -> void:
	var spawner := _resolve_spawner()
	if spawner == null or not spawner.has_method("spawn_beat_member"):
		return
	var pos: Vector2 = entry["pos"]
	var node := spawner.call("spawn_beat_member", String(entry["scene"]), pos, false) as Node
	if node == null:
		# Spawning is off or the beat cap is full: the corpse stays down.
		queue_redraw()
		return
	node.set_meta(REVENANT_META, true)
	_raised += 1
	# The spawner adds the member deferred; configure after its _ready so the
	# fraction applies to the threat-scaled maximum and the tint outlives the
	# spawn-time reset.
	call_deferred(&"_configure_revenant", node)
	if BattleText != null and BattleText.has_method("popup"):
		BattleText.popup(pos, "IT RISES", COLOUR, 1.15)
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_counter_event(&"encounter", &"revenant_raised", 1, {
			"enemy_id": String(entry["enemy_id"]),
		})
	queue_redraw()


func _configure_revenant(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("configure_health"):
		var max_hp: Variant = node.get("max_hp")
		if max_hp is float or max_hp is int:
			node.call("configure_health", maxf(1.0, float(max_hp) * revenant_hp_fraction), true)
	if node.has_node("Sprite2D"):
		var sprite := node.get_node("Sprite2D") as CanvasItem
		if sprite != null:
			sprite.modulate = revenant_tint


func _actor_for(handle: int) -> Node:
	if actor_provider.is_valid():
		return actor_provider.call(handle) as Node
	if handle == 0 or EnemyWorld == null or not EnemyWorld.has_method("actor_for_handle"):
		return null
	return EnemyWorld.actor_for_handle(handle) as Node


func _resolve_spawner() -> Node:
	if _spawner != null and is_instance_valid(_spawner):
		return _spawner
	_spawner = get_tree().get_first_node_in_group(&"enemy_spawner")
	return _spawner


func _read_reduced_motion() -> bool:
	if SettingsManager == null:
		return false
	return bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))


# --- the tell ---------------------------------------------------------------

func pulse_redraw() -> void:
	_bucket_redraw(PULSE_REDRAW_MS)


func _bucket_redraw(bucket_ms: int) -> void:
	# Wall-clock buckets, so the ring shares its redraw frames with the
	# manifestation overlays instead of drifting out of phase with them.
	var bucket := int(Time.get_ticks_msec() / bucket_ms)
	if bucket == _last_pulse_bucket:
		return
	_last_pulse_bucket = bucket
	queue_redraw()


func _draw() -> void:
	if _expired:
		return
	var breathe := 1.0
	if not _reduced_motion:
		breathe = 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) * 0.004)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(COLOUR.r, COLOUR.g, COLOUR.b, 0.45 * breathe), 2.0, true)
	draw_circle(Vector2.ZERO, radius, Color(COLOUR.r, COLOUR.g, COLOUR.b, 0.05 * breathe))
	# Sigil ticks at the cardinals, so the ring reads as a rite and not a zone.
	var glyph := Color(COLOUR.r, COLOUR.g, COLOUR.b, 0.85 * breathe)
	for k in range(4):
		var dir := Vector2.RIGHT.rotated(float(k) * TAU * 0.25)
		draw_line(dir * (radius - 16.0), dir * (radius + 16.0), glyph, 2.0, true)
	# The time left drains around the ring, like the vault's hold arc.
	var frac := clampf(_time_left / maxf(duration, 0.001), 0.0, 1.0)
	if frac > 0.0:
		draw_arc(Vector2.ZERO, radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, Color(COLOUR.r, COLOUR.g, COLOUR.b, 0.6), 3.0, true)
	# Corpses about to stand: a small mark where each will rise.
	for entry in _pending:
		draw_arc(to_local(entry["pos"] as Vector2), 10.0, 0.0, TAU, 12, glyph, 2.0, true)
