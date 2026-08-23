extends ManifestationEffect

## Fever Litany - the anti-Third-Litany.
##
## Every other cadence rule pays you for WAITING: Third Litany wants you to let
## a beat resolve, Stored Violence wants you not to attack at all. This one pays
## for the opposite, so the cadence noun contains a real argument rather than
## three variations on patience. Rolling this next to Stored Violence is a
## deliberate conflict, the same way Anchor Rite and Pilgrim's Momentum are.

## Consecutive attacks inside this window stack Fever. Deliberately shorter than
## Third Litany's resolve window, so the two cannot both be satisfied.
const CHAIN_WINDOW: float = ManifestationState.CADENCE_CHAIN_WINDOW
const HASTE_PER_STACK: float = 0.06
const MAX_STACKS: int = 6

const FEVER_TINT: Color = Color(1.0, 0.44, 0.22, 1.0)

var _stacks: int = 0
var _last_seen_attack: int = -1
var _drawn_stacks: int = -1


func _on_manifestation_ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4059
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func max_haste() -> float:
	return HASTE_PER_STACK * potency() * float(MAX_STACKS)


func chain_window() -> float:
	# threshold_scale() eases requirements, and here the requirement is how
	# quickly you have to keep firing - so a ranked item is more forgiving.
	return CHAIN_WINDOW / maxf(threshold_scale(), 0.01)


func get_haste_multiplier() -> float:
	return 1.0 + HASTE_PER_STACK * potency() * float(_stacks)


func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	_target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if state == null or not is_instance_valid(state):
		return
	# The shared counter has already advanced for this attack, so the clock read
	# here is the gap BEFORE it - which is exactly the gap being judged.
	_stacks = mini(_stacks + 1, MAX_STACKS) if _chain_held() else 1
	_last_seen_attack = state.attack_index


func _chain_held() -> bool:
	if _last_seen_attack < 0:
		return false
	return state.time_since_attack <= chain_window()


func _process(delta: float) -> void:
	if state == null or not is_instance_valid(state):
		return
	global_position = player_position()

	# The chain breaks on its own once the window lapses; nothing has to fire.
	if _stacks > 0 and state.time_since_attack > chain_window():
		_stacks = 0

	if _stacks != _drawn_stacks:
		_drawn_stacks = _stacks
		queue_redraw()
	elif _stacks > 0:
		queue_redraw()

	_pulse += delta


var _pulse: float = 0.0


func describe() -> String:
	return (
		"Attacks fired within %.2fs of the last stack Fever: +%d%% Haste each, up to +%d%%. Let the chain lapse and it all goes at once."
		% [chain_window(), int(round(HASTE_PER_STACK * potency() * 100.0)), int(round(max_haste() * 100.0))]
	)


func _draw() -> void:
	if _stacks <= 0:
		return
	var fill := float(_stacks) / float(MAX_STACKS)
	var breathe := 0.80 + 0.20 * sin(_pulse * (4.0 + 6.0 * fill))
	var tint := Color(FEVER_TINT.r, FEVER_TINT.g, FEVER_TINT.b, (0.22 + 0.42 * fill) * breathe)

	# A ring that closes as the chain builds, and ticks that burn off with it.
	draw_arc(Vector2.ZERO, 21.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 32, tint, 2.6, true)
	for i in range(_stacks):
		var angle := -PI * 0.5 + TAU * (float(i) / float(MAX_STACKS))
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(dir * 22.0, dir * (26.0 + 4.0 * breathe), tint, 2.0, true)
