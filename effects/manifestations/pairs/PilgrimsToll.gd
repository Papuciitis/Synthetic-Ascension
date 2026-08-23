extends ManifestationPairEffect

## Pilgrim's Toll - fortune x momentum.
##
## Fortune's texture is the roll; momentum's is the run. The toll pays the roll
## out of the run: cover the distance and the next thing you touch is Marked
## outright - no elite requirement, no Luck roll, and no tagging hit spent to
## earn it, which is what Predestination Sigil normally charges for the same
## noun.
##
## THE SHARD CLAIM. The Mark is a channel of the SHARD noun, so set_mark() is a
## no-op unless something claims shard - and neither of this pair's two nouns
## does. It therefore claims shard itself, but only for as long as its own Mark
## is live, and releases it the instant the Mark ends. Claiming for the whole
## run would work too and is one line shorter, but it would park an empty
## "SHARDS 0/4" meter on the Run Sheet of a player who owns no shard rule and
## advertise an orbit they cannot fill. The claim is refcounted, so holding it
## next to a real shard rule is invisible to that rule.

# The world is authored on a 32 px grid (VisionRig.cell_size_px), so a design
# "metre" is 32 px of travel.
const PIXELS_PER_METRE: float = 32.0
const TOLL_METRES: float = 20.0
const TOLL_DISTANCE: float = TOLL_METRES * PIXELS_PER_METRE

## Long enough to walk the Mark down. threshold_scale() eases requirements, and
## here the eased requirement is how long you have to reach what you tagged, so
## it divides rather than multiplies - exactly as Predestination Sigil does it.
const MARK_BASE_DURATION: float = 8.0

const ARM_FLASH: float = 0.45
const GLYPH_ORIGIN := Vector2(0.0, -40.0)
const GLYPH_RADIUS: float = 6.5

## Where the last toll was paid, on the unbroken-run odometer. The next one is
## measured from there, so a single very long run can pay more than once without
## a stop, and a stop simply restarts the measurement from zero.
var _paid_at: float = 0.0
var _armed: bool = false
var _shard_claimed: bool = false
var _arm_flash: float = 0.0
var _t: float = 0.0
var _drawn_fraction: float = -1.0
var _drawn_armed: bool = false


func _on_manifestation_ready() -> void:
	# World-space draw: the player rotates to face its movement vector and the
	# toll glyph must not spin with it.
	top_level = true
	z_as_relative = false
	z_index = 4066
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if state != null and is_instance_valid(state):
		# Seed from the running odometer: coming online mid-sprint must not arm
		# instantly off metres the pair was not live through.
		_paid_at = state.distance_since_stop
	if player != null and is_instance_valid(player):
		global_position = player.global_position
	set_process(true)


func _exit_tree() -> void:
	_release_shard_claim()


func toll_distance() -> float:
	return maxf(1.0, TOLL_DISTANCE * threshold_scale())


func mark_duration() -> float:
	return MARK_BASE_DURATION / maxf(threshold_scale(), 0.5)


func _process(delta: float) -> void:
	_t += delta
	_arm_flash = maxf(0.0, _arm_flash - delta)
	if state == null or not is_instance_valid(state):
		return
	global_position = player_position()

	var travelled: float = state.distance_since_stop
	if travelled < _paid_at:
		# The run broke and the state restarted its odometer, so the next toll
		# is measured from zero. An ALREADY armed toll deliberately survives:
		# it was earned by running, and you have to stop to fight anything with
		# it. A toll that evaporated the moment you planted your feet would
		# almost never be collectable.
		_paid_at = 0.0

	if not _armed and travelled - _paid_at >= toll_distance():
		_armed = true
		_arm_flash = ARM_FLASH
		popup("TOLL DUE", noun_colour(&"fortune"), 1.25)

	_release_shard_claim_if_spent()
	_repaint_if_changed()


func on_hit(handle: int, _at: Vector2, _amount: float, _is_crit: bool, _is_elite: bool) -> void:
	if not _armed or handle == 0:
		return
	if state == null or not is_instance_valid(state):
		return
	# A live Mark is never stolen. Predestination Sigil spends a hit on an elite
	# to place its Mark; yanking that onto whatever trash the player clipped
	# next would make this pair actively worse than not owning it. The toll
	# stays armed and collects itself the moment the current Mark ends.
	if state.mark_time_left > 0.0:
		return
	if not _hold_shard_claim():
		return

	state.set_mark(handle, mark_duration())
	if state.marked_handle != handle:
		# Refused - something else owns the Mark this frame. Give the claim back
		# rather than sitting on a noun this pair is not using.
		_release_shard_claim()
		return

	_armed = false
	_arm_flash = 0.0
	_paid_at = state.distance_since_stop
	popup("TOLL PAID", noun_colour(&"fortune"), 1.35)


# ---------------------------------------------------------------------------
# The transient shard claim
# ---------------------------------------------------------------------------

func _hold_shard_claim() -> bool:
	if _shard_claimed:
		return true
	if state == null or not is_instance_valid(state):
		return false
	state.claim(&"shard")
	_shard_claimed = true
	return true


func _release_shard_claim_if_spent() -> void:
	if not _shard_claimed:
		return
	if state != null and is_instance_valid(state) and state.mark_time_left > 0.0:
		return
	_release_shard_claim()


func _release_shard_claim() -> void:
	if not _shard_claimed:
		return
	_shard_claimed = false
	if state != null and is_instance_valid(state):
		# Refcounted: this only drops the noun to dormant when nothing else
		# claims it, and in that case there is no orbit and no Mark to reset.
		state.release(&"shard")


func _repaint_if_changed() -> void:
	# Hundreds of enemies share this frame, so the glyph repaints only while it
	# is actually animating or the run gauge has visibly moved.
	var fraction: float = clampf((state.distance_since_stop - _paid_at) / toll_distance(), 0.0, 1.0)
	var animating: bool = _armed or _arm_flash > 0.0
	if animating or _drawn_armed or absf(fraction - _drawn_fraction) > 0.01:
		_drawn_armed = animating
		_drawn_fraction = fraction
		queue_redraw()


func describe() -> String:
	return (
		"Run %.0f m without stopping and the next enemy you hit is Marked for %.1fs on contact - no elite needed, no Luck roll, no hit spent to place it. The next toll needs the distance again."
		% [toll_distance() / PIXELS_PER_METRE, mark_duration()]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var fortune: Color = noun_colour(&"fortune")
	var momentum: Color = noun_colour(&"momentum")

	if not _armed:
		var fraction: float = clampf(_drawn_fraction, 0.0, 1.0)
		if fraction <= 0.01:
			return
		# The run toward the toll, in MOMENTUM: this half of the pair is the
		# distance, and it is the half the player is currently paying.
		draw_arc(
			GLYPH_ORIGIN,
			GLYPH_RADIUS,
			-PI * 0.5,
			-PI * 0.5 + TAU * fraction,
			20,
			Color(momentum.r, momentum.g, momentum.b, 0.22 + 0.45 * fraction),
			1.8,
			true
		)
		return

	# Armed: a struck coin turning above the player, FORTUNE coloured, because
	# what is banked now is the roll you no longer have to make.
	var pulse: float = 0.84 + 0.16 * sin(_t * 6.5)
	var turn: float = 0.35 + 0.65 * absf(sin(_t * 2.1))
	var radius: float = GLYPH_RADIUS * 1.35 * pulse
	draw_circle(GLYPH_ORIGIN, radius * 1.7, Color(fortune.r, fortune.g, fortune.b, 0.14 * pulse))
	# The turn is a squash on the draw transform rather than a rebuilt point
	# array: an armed toll can sit spinning for a long time, and this repaints
	# every frame it does.
	draw_set_transform(GLYPH_ORIGIN, 0.0, Vector2(turn, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(fortune.r, fortune.g, fortune.b, 0.90), 1.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _arm_flash > 0.0:
		var f: float = _arm_flash / ARM_FLASH
		draw_arc(
			GLYPH_ORIGIN,
			radius + 16.0 * (1.0 - f),
			0.0,
			TAU,
			24,
			Color(fortune.r, fortune.g, fortune.b, 0.70 * f),
			2.0,
			true
		)
