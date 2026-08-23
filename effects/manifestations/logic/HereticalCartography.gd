extends ManifestationEffect

## Heretical Cartography - walking somewhere you have never been pays, the
## bonus stacks, and finishing a secondary keeps the whole map alive.
##
## Delivery: both halves ride apply_to_stats(), which is only read during a full
## recompute_run_stats(). That is deliberate rather than lazy. Luck has no
## polled channel at all - Global.run_luck is written only at the end of
## recompute_run_stats(), so nothing but a recompute can make a Luck bonus reach
## LuckResolver. Since we are already paying for one recompute per stack change,
## Power rides along in the same pass instead of adding a second delivery route
## that would report a different number to the Run Sheet than the tooltip.
##
## The recompute is driven ONLY when the stack COUNT changes: on a first entry,
## on a secondary, and on expiry. Refreshing timers at cap changes no number, so
## it never triggers one, and _process never does.

const MAX_STACKS: int = 5
const STACK_SECONDS: float = 20.0
const LUCK_PER_STACK: float = 0.06
const POWER_PER_STACK: float = 0.05

const CHART: Color = Color(0.55, 0.95, 0.80, 1.0)

const VFX_MARK: GDScript = preload("res://assets/vfx/world/manifestations/VFX_CartographyMark.gd")

## Remaining seconds per stack, oldest first.
var _stacks: Array[float] = []
var _pulse: float = 0.0


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4064
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func stack_seconds() -> float:
	return STACK_SECONDS * potency()


func luck_bonus() -> float:
	return LUCK_PER_STACK * potency() * float(_stacks.size())


func power_bonus() -> float:
	return POWER_PER_STACK * potency() * float(_stacks.size())


func on_building_entered(first_visit: bool) -> void:
	# Re-entering a cleared building is not exploration; only virgin ground pays.
	if not first_visit:
		return
	_add_stack(false, "UNCHARTED")


func on_secondary_completed(_objective_id: int) -> void:
	_add_stack(true, "SURVEYED")


## Luck goes through the shared fortune ledger; Power stays on this rule.
## Routing Luck through the ledger is what makes several fortune rules stack
## predictably - the Run Sheet can show one pool instead of guessing which rule
## contributed what, and Overtime Gospel's Luck lands in the same number.
func _publish_luck() -> void:
	if state == null or not is_instance_valid(state):
		return
	state.set_contribution(
		ManifestationState.CHANNEL_LUCK,
		contribution_key(),
		luck_bonus()
	)


func _exit_tree() -> void:
	if state != null and is_instance_valid(state):
		state.clear_contributions(contribution_key())


func apply_to_stats(s: Stats) -> void:
	# Luck reaches the game through the ledger and the runner reads that BEFORE
	# this hook runs, so it is published at the point of change in _restat().
	# Only Power is this rule's own contribution to the stat pass.
	if s == null or _stacks.is_empty():
		return

	s.power += power_bonus()


func describe() -> String:
	var luck: float = LUCK_PER_STACK * potency() * 100.0
	var power: float = POWER_PER_STACK * potency() * 100.0
	return (
		"Entering a building for the first time grants +%.0f%% Luck and +%.0f%% Power for %.0fs, stacking %d times (+%.0f%% Luck, +%.0f%% Power). Completing a secondary adds a stack and refreshes them all."
		% [
			luck,
			power,
			stack_seconds(),
			MAX_STACKS,
			luck * float(MAX_STACKS),
			power * float(MAX_STACKS),
		]
	)


# ---------------------------------------------------------------------------

func _add_stack(refresh_all: bool, shout: String) -> void:
	var duration: float = stack_seconds()
	if refresh_all:
		for i in range(_stacks.size()):
			_stacks[i] = duration

	var grew: bool = false
	if _stacks.size() < MAX_STACKS:
		_stacks.append(duration)
		grew = true
	else:
		# At cap the oldest chart is redrawn instead: the bonus is unchanged, so
		# this deliberately does NOT pay for a recompute.
		_stacks.remove_at(0)
		_stacks.append(duration)

	popup("%s x%d" % [shout, _stacks.size()], CHART, 1.3)
	var mark: Node2D = VFX_MARK.new() as Node2D
	if mark != null:
		mark.call(&"setup", _stacks.size(), MAX_STACKS)
		spawn_world_node(mark, player_position())

	if grew:
		_restat()


func _restat() -> void:
	# Publish BEFORE asking for the recompute. The runner folds
	# state.bonus_luck() into the stat pass before it iterates apply_to_stats(),
	# so publishing from inside that hook meant the ledger was always one
	# recompute behind: the player saw "UNCHARTED x1" and a tooltip promising
	# +6% Luck while Global.run_luck had not moved, and kept the full five-stack
	# Luck after the last chart expired. Power was correct, so the two halves of
	# one rule disagreed.
	_publish_luck()
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("refresh_run_state"):
		return
	player.call("refresh_run_state")


func _process(delta: float) -> void:
	if _stacks.is_empty():
		return

	var lost: bool = false
	var i: int = _stacks.size() - 1
	while i >= 0:
		_stacks[i] -= delta
		if _stacks[i] <= 0.0:
			_stacks.remove_at(i)
			lost = true
		i -= 1

	_pulse += delta
	global_position = player_position()
	queue_redraw()

	# One recompute for however many stacks fell off this frame.
	if lost:
		popup("CHART FADES", Color(CHART.r * 0.7, CHART.g * 0.7, CHART.b * 0.7, 1.0), 1.0)
		_restat()


func _draw() -> void:
	if _stacks.is_empty():
		return
	var duration: float = maxf(0.001, stack_seconds())
	var radius: float = 30.0
	# Identity hue from the noun registry. CHART survives as the rule's own
	# accent for the popup, which is not part of the overlay.
	var chart: Color = noun_colour()

	for i in range(_stacks.size()):
		var left: float = clampf(_stacks[i] / duration, 0.0, 1.0)
		var angle: float = -PI * 0.5 + TAU * (float(i) / float(MAX_STACKS))
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var at: Vector2 = dir * radius
		# Each stack is a survey chevron; it dims and shrinks as its timer runs
		# out, so an about-to-expire chart is readable before it costs you.
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var reach: float = 4.0 + 4.0 * left
		var alpha: float = 0.25 + 0.6 * left
		draw_polyline(PackedVector2Array([
			at + side * reach - dir * reach * 0.5,
			at + dir * reach * 0.75,
			at - side * reach - dir * reach * 0.5,
		]), Color(chart.r, chart.g, chart.b, alpha), 2.0, true)

	var breathe: float = 0.55 + 0.45 * sin(_pulse * 1.8)
	var sweep: float = TAU * (float(_stacks.size()) / float(MAX_STACKS))
	draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + sweep, 40, Color(chart.r, chart.g, chart.b, 0.14 * breathe), 1.5, true)
