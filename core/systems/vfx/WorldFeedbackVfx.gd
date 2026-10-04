extends Node

## World feedback bursts on run events (autoload): an enemy death puff, a
## bigger elite death, a dash wisp, a Q / V cast flash. Item pickups call
## VfxBursts directly from the pickup. Capped per frame so a chain kill
## reads as a shower, not a frame.
##
## Hit confirmation (audit 2026-10-04, change 5) also lives here, because it
## needs a clock and the enemy feedback path (EnemyLifecycle) has none: a
## materialized enemy that survives a hit flashes white for 0.07 s, and every
## crit plus one in three ordinary hits throws a hit spark. Proxies flash in
## their own renderer.

const DEATHS_PER_FRAME := 10
## Hit sparks: every crit and one ordinary hit in HIT_SPARK_EVERY, at most
## HIT_SPARKS_PER_FRAME per frame (the burst pool caps live sparks at 64).
const HIT_SPARK_EVERY := 3
const HIT_SPARKS_PER_FRAME := 12
## The white flash: modulate this bright for this long. Overbright modulate
## reaches the batched actor sprites too - EnemyProxyRenderer multiplies the
## actor's modulate into each instance colour every frame.
const FLASH_MS := 70
const FLASH_BRIGHTNESS := 2.2
const MAX_FLASHES := 128
const FLASH_SLOT_META := &"_hit_flash_slot"

var enabled := true
var _deaths_this_frame := 0
var _sparks_this_frame := 0
var _hits_since_spark := 0
# Live flashes as parallel arrays keyed by instance id, so a node freed
# mid-flash is never touched again and nothing is allocated per hit.
var _flash_ids := PackedInt64Array()
var _flash_ends := PackedInt64Array()
var _flash_bases := PackedColorArray()


func _ready() -> void:
	if RunEvents == null:
		return
	RunEvents.enemy_defeated.connect(_on_enemy_defeated)
	RunEvents.player_dashed.connect(_on_player_dashed)
	RunEvents.player_ability_activated.connect(_on_ability_activated)
	VfxBursts.warm()


func _exit_tree() -> void:
	# Hand every flashed node its own colour back before going.
	for i in range(_flash_ids.size()):
		_restore_flash(i)
	_flash_ids.clear()
	_flash_ends.clear()
	_flash_bases.clear()


func _process(_delta: float) -> void:
	_deaths_this_frame = 0
	_sparks_this_frame = 0
	if not _flash_ids.is_empty():
		_expire_flashes(Time.get_ticks_msec())


func _on_enemy_defeated(context: RefCounted) -> void:
	if not enabled or context == null or _deaths_this_frame >= DEATHS_PER_FRAME:
		return
	_deaths_this_frame += 1
	var flags := int(context.get("flags"))
	var elite := (flags & EnemyWorldTypes.Flags.ELITE) != 0
	var position: Vector2 = context.get("position")
	VfxBursts.play(&"elite_death" if elite else &"death", position, 1.15 if elite else 1.0)


func _on_player_dashed(_player: Node, from: Vector2, direction: Vector2) -> void:
	if not enabled:
		return
	VfxBursts.play(&"dash", from, 1.0, Color.WHITE, -direction)


func _on_ability_activated(player: Node, slot: StringName, _id: String, _cooldown: float) -> void:
	if not enabled or not (player is Node2D):
		return
	VfxBursts.play(&"cast", (player as Node2D).global_position, 1.6 if slot == &"v" else 1.0)


# --- hit confirmation ---------------------------------------------------------

## One hit that a materialized enemy survived (EnemyLifecycle feedback). The
## spark flies along `direction` (the shot's travel, or away from the player).
func note_enemy_hit(position: Vector2, critical: bool, direction: Vector2 = Vector2.ZERO) -> void:
	if not enabled:
		return
	_hits_since_spark += 1
	if not critical and _hits_since_spark < HIT_SPARK_EVERY:
		return
	if _sparks_this_frame >= HIT_SPARKS_PER_FRAME:
		return
	_hits_since_spark = 0
	_sparks_this_frame += 1
	var tint := Color(1.0, 0.86, 0.45, 1.0) if critical else Color.WHITE
	VfxBursts.play(&"hit_spark", position, 1.35 if critical else 1.0, tint, direction)


## Flashes `node` white for FLASH_MS (a repeat inside a live flash only
## extends it). The caller rate-limits per enemy; Combat Flashes off skips it
## and Reduced dims it.
func flash_hit(node: CanvasItem) -> void:
	if not enabled or node == null or not is_instance_valid(node):
		return
	var strength := _flash_strength()
	if strength <= 1.0:
		return
	var until := Time.get_ticks_msec() + FLASH_MS
	var id := node.get_instance_id()
	var slot := int(node.get_meta(FLASH_SLOT_META, -1))
	if slot >= 0 and slot < _flash_ids.size() and _flash_ids[slot] == id:
		_flash_ends[slot] = until
		return
	if _flash_ids.size() >= MAX_FLASHES:
		return
	var base := node.modulate
	# A node already at the flash colour (a stale slot) would otherwise be
	# restored to the flash itself.
	if base.r > 1.01 or base.g > 1.01 or base.b > 1.01:
		base = Color(1.0, 1.0, 1.0, base.a)
	_flash_ids.append(id)
	_flash_ends.append(until)
	_flash_bases.append(base)
	node.set_meta(FLASH_SLOT_META, _flash_ids.size() - 1)
	node.modulate = Color(base.r * strength, base.g * strength, base.b * strength, base.a)


func live_flash_count() -> int:
	return _flash_ids.size()


func is_flashing(node: Object) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var slot := int(node.get_meta(FLASH_SLOT_META, -1))
	return slot >= 0 and slot < _flash_ids.size() and _flash_ids[slot] == node.get_instance_id()


func _expire_flashes(now: int) -> void:
	var i := _flash_ids.size() - 1
	while i >= 0:
		if now >= _flash_ends[i]:
			_restore_flash(i)
			_remove_flash(i)
		i -= 1


func _restore_flash(slot: int) -> void:
	var node := instance_from_id(_flash_ids[slot]) as CanvasItem
	if node == null or not is_instance_valid(node):
		return
	node.modulate = _flash_bases[slot]
	if node.has_meta(FLASH_SLOT_META):
		node.remove_meta(FLASH_SLOT_META)


## Swap-remove, re-pointing the moved node at its new slot.
func _remove_flash(slot: int) -> void:
	var last := _flash_ids.size() - 1
	if slot != last:
		_flash_ids[slot] = _flash_ids[last]
		_flash_ends[slot] = _flash_ends[last]
		_flash_bases[slot] = _flash_bases[last]
		var moved := instance_from_id(_flash_ids[slot])
		if moved != null and is_instance_valid(moved):
			moved.set_meta(FLASH_SLOT_META, slot)
	_flash_ids.resize(last)
	_flash_ends.resize(last)
	_flash_bases.resize(last)


func _flash_strength() -> float:
	return 1.0 + (FLASH_BRIGHTNESS - 1.0) * AccessibilityPresentation.current_flash_alpha(1.0)
