extends ManifestationEffect

## Tithe Furnace - every eighth attack burns a Follower to empower itself, and
## refuses to spend below the reconstruction cost.
##
## Ordering: player.gd _fire_weapon() reads consume_attack_bonus() before it
## emits weapon_fired, so a bonus armed from on_attack is picked up by the NEXT
## shot. We therefore stoke the furnace on the seventh attack and the eighth is
## the one that lands empowered - which is what the rule promises.
##
## The refusal is not a failure case, it is the rule. Followers are money AND
## lives AND belief; a furnace that could eat your way back from a death would
## be a trap rather than a bargain.

const TITHE_INTERVAL: int = 8
const TITHE_BONUS: float = 2.20

const REFUSAL_POPUP_COOLDOWN: float = 2.5

const EMBER: Color = Color(1.0, 0.55, 0.15, 1.0)
const COLD: Color = Color(0.62, 0.68, 0.80, 1.0)

const VFX_EMBERS: GDScript = preload("res://assets/vfx/world/manifestations/VFX_TitheEmbers.gd")

## Join marker into the shared attack counter, not a private tally. The Furnace
## and Third Litany are the same noun - "every Nth attack" - differing only in
## what the Nth one costs.
var _cycle_start: int = 0
var _pending_bonus: float = 1.0
var _refusal_cd: float = 0.0
var _can_afford: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4063
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func _on_manifestation_ready() -> void:
	_refresh_affordability()


func tithe_interval() -> int:
	# threshold_scale() eases requirements by at most 22%: a maxed instance
	# tithes every sixth attack instead of every eighth.
	return clampi(int(round(float(TITHE_INTERVAL) * threshold_scale())), 6, TITHE_INTERVAL)


func tithe_multiplier() -> float:
	return 1.0 + TITHE_BONUS * potency()


func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	_target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	var attacks: int = _attacks_since_join()
	var interval: int = tithe_interval()
	# Modulo rather than a reset counter: a refused tithe must not shift the
	# rhythm, it just misses this cycle and tries again on the next eighth.
	if attacks % interval != interval - 1:
		return
	_try_tithe()


func on_followers_changed(_change: int, _reason: StringName) -> void:
	# compute_respawn_cost() runs a pow() and the cost itself scales with the
	# Follower count, so it is only correct - and only cheap - to recompute the
	# glow's affordability when Followers actually move. The binding check at
	# tithe time is still made fresh.
	_refresh_affordability()


func consume_attack_bonus() -> float:
	if _pending_bonus <= 1.0:
		return 1.0
	var bonus: float = _pending_bonus
	_pending_bonus = 1.0
	popup("FURNACE x%.1f" % bonus, EMBER, 1.5)
	return bonus


func _attacks_since_join() -> int:
	if state == null or not is_instance_valid(state):
		return 0
	return maxi(0, state.attack_index - _cycle_start)


func describe() -> String:
	return (
		"Every %d attacks the furnace burns 1 Follower and the next strike hits for %.0f%% damage. It refuses to tithe if spending would drop you below your reconstruction cost."
		% [tithe_interval(), tithe_multiplier() * 100.0]
	)


# ---------------------------------------------------------------------------

func _try_tithe() -> void:
	if Global == null:
		return
	var cost: int = int(Global.compute_respawn_cost())
	var have: int = int(Global.followers)
	if have - 1 < cost:
		_refuse(cost)
		return

	var result: Dictionary = Global.transaction_followers(
		-1,
		&"manifestation_tithe",
		{
			"manifestation": manifestation_id(),
			"slot": slot_index,
			"reconstruction_cost": cost,
		},
		true,
		true
	)
	# The ledger is the authority; never arm a bonus we did not actually pay for.
	if int(result.get("change", 0)) >= 0:
		return

	_pending_bonus = tithe_multiplier()
	var embers: Node2D = VFX_EMBERS.new() as Node2D
	if embers != null:
		spawn_world_node(embers, player_position())


func _refuse(cost: int) -> void:
	_can_afford = false
	if _refusal_cd > 0.0:
		return
	_refusal_cd = REFUSAL_POPUP_COOLDOWN
	popup("FURNACE REFUSES (%d TO REBUILD)" % cost, COLD, 1.25)


func _refresh_affordability() -> void:
	if Global == null:
		_can_afford = false
		return
	_can_afford = int(Global.followers) - 1 >= int(Global.compute_respawn_cost())


func _process(delta: float) -> void:
	_pulse += delta
	if _refusal_cd > 0.0:
		_refusal_cd = maxf(0.0, _refusal_cd - delta)
	global_position = player_position()
	queue_redraw()


func _draw() -> void:
	var interval: int = tithe_interval()
	var charged: int = _attacks_since_join() % interval
	var fill: float = clampf(float(charged) / float(maxi(1, interval - 1)), 0.0, 1.0)
	# The grate counts ATTACKS, so it carries the cadence identity hue rather
	# than the ember orange it used to share with Pilgrim's Momentum. COLD stays
	# authored: "the furnace cannot afford to fire" is the opposition the whole
	# overlay exists to show, and it must not become a shade of the same colour.
	var hot: Color = noun_colour() if _can_afford else COLD
	var breathe: float = 0.7 + 0.3 * sin(_pulse * (2.0 + 5.0 * fill))

	# A grate of coals under the player: they light up one per attack and the
	# whole thing goes cold and blue when the furnace cannot afford to fire.
	var radius: float = 21.0
	for i in range(interval):
		var angle: float = -PI * 0.5 + TAU * (float(i) / float(interval))
		var at: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		var lit: bool = i < charged
		var alpha: float = (0.55 * breathe if lit else 0.12)
		draw_circle(at, (3.2 if lit else 2.0), Color(hot.r, hot.g, hot.b, alpha))

	if _pending_bonus > 1.0:
		# Armed: the next shot carries the tithe, so say so loudly.
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.45, 0.55 * breathe), 3.0, true)
	elif fill > 0.0:
		draw_arc(Vector2.ZERO, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 32, Color(hot.r, hot.g, hot.b, 0.30), 2.0, true)
