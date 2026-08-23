extends ManifestationPairEffect

## Debt Collector - fortune x ward.
##
## The keystone. Staying under the dying line becomes a deliberate, expensive
## strategy instead of a mistake you are climbing out of: while you are down
## there every Luck roll in the game is pinned to its ceiling, and every Lucky
## Crit bills you a believer for it.
##
## WHAT "EVERY LUCK ROLL SUCCEEDS" ACTUALLY IS, AND WHY IT IS NOT LITERAL.
## LuckResolver is static and global - there is no roll to intercept and no
## instance to override - and lucky_crit_chance() hard-caps at 8% no matter what
## it is fed. The honest tool a pair does have is the shared fortune ledger, so
## this publishes an overwhelming Luck contribution while the wound tier is
## DYING and clears it above. Every LuckResolver curve is asymptotic in Luck, so
## LUCK_WHILE_DYING sits all of them - Lucky Crits, drop quantity, rarity
## promotion, extra Followers, lucky evasion - on their respective ceilings at
## once. That is overwhelming Luck, not certainty, and describe() says so rather
## than repeating the catalog line's shorthand.
##
## HOW THE LUCK REACHES THE GAME.
## Every fortune rule publishes into one shared ledger, so the Run Sheet shows a
## single Luck pool rather than several invisible ones. The runner applies that
## pool during the stat pass, and player.gd writes Global.run_luck from the
## result - which is the only route by which anything reaches LuckResolver.
## Publishing is therefore the whole delivery; this rule adds nothing directly.

## Enough to put effective(luck) past 0.97 even against a NEG Luck curse
## dragging the run's base Luck negative. Rank raises the flood rather than the
## outcome, which is the correct shape for a keystone: getting the pair is the
## reward, and an R20 loadout must not out-luck the ceiling harder than an R0
## one can already reach.
const LUCK_WHILE_DYING: float = 18.0

## THE DEBT IS A WINDOW, NOT A STANCE.
##
## Without this the pair pinned every Luck curve in the game to its ceiling for
## as long as the player chose to sit under the line - and with Martyr Circuit
## (faster while wounded), Scar Tissue (healing is a trap) and Red Line (immune
## while wounded) all pointing the same way, four separate effects rewarded
## being nearly dead and NOTHING rewarded being healthy. The optimal play was to
## park at 19% HP and farm, which is the exact failure mode the design doc names
## twice.
##
## So the flood is paid at the moment you fall in, holds through a comeback, and
## then drains. A creditor collects; they do not fund you indefinitely. The
## clutch-comeback fantasy is untouched - those are decided in seconds - while
## camping quietly stops paying, the same shape Overtime uses on belief.
##
## Resets only by climbing back OUT of the wound, so topping up is the way to
## reopen it. That gives the ward nouns a reason to want health again.
const DEBT_GRACE: float = 7.0
const DEBT_WINDOW: float = 26.0
const DEBT_FLOOR: float = 0.12

## wound_tier() returns 3 at or below ManifestationState.WOUND_DYING. Named as a
## tier rather than compared against the fraction directly, so this pair and
## every ward rule agree on where the word "dying" is.
const DYING_TIER: int = 3

## The threshold the tooltip quotes, read from the shared vocabulary so the two
## cannot drift. NOTE it is 20%, not the catalog line's "a third" - describe()
## quotes the number the code actually uses.
const DYING_FRACTION: float = ManifestationState.WOUND_DYING

const COLLECT_REASON: StringName = &"manifestation_pair_debt"

## refresh_run_state() runs the whole stat pass. Crossing the line is rare, but
## a player regenerating across it, or being chipped at it by a swarm, would
## toggle every frame - so the flag flips immediately and only the recompute is
## coalesced. Never per frame, and never more than once per this.
const REFRESH_DEBOUNCE: float = 0.35

var _collecting: bool = false
var _held: float = 0.0
var _drain_cd: float = 0.0
var _called: bool = false
var _refresh_pending: bool = false
var _refresh_cd: float = 0.0
var _pulse: float = 0.0
var _drawn: bool = false


func _ready() -> void:
	# World space around the player: the player rotates to face its movement
	# vector and a debt ring that spun with it would be unreadable.
	top_level = true
	z_as_relative = false
	z_index = 4066
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func _on_manifestation_ready() -> void:
	_collecting = _is_collecting()
	_publish_luck()
	# Deliberately NOT a refresh here. The runner instantiates pairs from inside
	# refresh_effects(), which recompute_run_stats() calls one line before it
	# polls apply_to_stats() - so equipping into a dying run already lands this
	# pass, and calling back into the recompute would recurse. Anything else
	# (a pair lit by an inventory change with no stat pass behind it) is picked
	# up by the debounced request below.
	_refresh_pending = _collecting


func _exit_tree() -> void:
	if state != null and is_instance_valid(state):
		state.clear_contributions(contribution_key())


# ---------------------------------------------------------------------------
# The Luck flood
# ---------------------------------------------------------------------------

## How much of the flood is still owed to you, 1.0 down to DEBT_FLOOR.
func debt_fraction() -> float:
	if not _collecting:
		return 0.0
	if _held <= DEBT_GRACE:
		return 1.0
	var t: float = clampf((_held - DEBT_GRACE) / DEBT_WINDOW, 0.0, 1.0)
	return lerpf(1.0, DEBT_FLOOR, t)


## One accessor, so the ledger entry and the stat line can never disagree.
func luck_contribution() -> float:
	return LUCK_WHILE_DYING * potency() * debt_fraction()


func _publish_luck() -> void:
	if state == null or not is_instance_valid(state):
		return
	state.set_contribution(
		ManifestationState.CHANNEL_LUCK,
		contribution_key(),
		luck_contribution()
	)


func apply_to_stats(_s: Stats) -> void:
	# Publish only. The runner applies state.bonus_luck() during this same pass,
	# so adding the contribution here as well would double every point of it.
	_publish_luck()


func _is_collecting() -> bool:
	if state == null or not is_instance_valid(state):
		return false
	return state.wound_tier() >= DYING_TIER


func _request_stat_refresh() -> void:
	# Luck reaches LuckResolver only through Global.run_luck, and only a stat
	# recompute writes that. Crossing the line is the only moment it changes.
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("refresh_run_state"):
		player.call("refresh_run_state")


func _process(delta: float) -> void:
	if _refresh_cd > 0.0:
		_refresh_cd = maxf(0.0, _refresh_cd - delta)

	var collecting := _is_collecting()
	if collecting:
		_held += delta
		# The flood is only worth restating while it is actually moving; once it
		# has bottomed out the ledger entry is already correct.
		_drain_cd -= delta
		if _drain_cd <= 0.0 and _held > DEBT_GRACE and debt_fraction() > DEBT_FLOOR:
			_drain_cd = 0.5
			_publish_luck()
			_refresh_pending = true
		if not _called and debt_fraction() <= DEBT_FLOOR + 0.001:
			_called = true
			popup("DEBT CALLED", noun_colour(&"fortune"), 1.35)
	if collecting != _collecting:
		_collecting = collecting
		if collecting:
			_held = 0.0
			_called = false
		_publish_luck()
		_refresh_pending = true
		popup(
			"DEBT OPEN" if collecting else "DEBT CLOSED",
			noun_colour(&"ward") if collecting else noun_colour(&"fortune"),
			1.30
		)

	if _refresh_pending and _refresh_cd <= 0.0:
		_refresh_pending = false
		_refresh_cd = REFRESH_DEBOUNCE
		_request_stat_refresh()

	if _collecting:
		_drawn = true
		_pulse += delta
		global_position = player_position()
		queue_redraw()
	elif _drawn:
		# One last repaint to wipe the ring; after that a healthy player pays
		# nothing per frame beyond the tier read above.
		_drawn = false
		queue_redraw()


# ---------------------------------------------------------------------------
# The collection
# ---------------------------------------------------------------------------

func on_lucky_crit(_at: Vector2) -> void:
	if not _collecting or Global == null:
		return
	# No reconstruction floor, unlike the Tithe rules. That refusal is THEIR
	# drama; this one's is that it cannot be refused - a keystone that politely
	# stopped taking when the bill got frightening would not be a keystone.
	var result: Dictionary = Global.transaction_followers(
		-1,
		COLLECT_REASON,
		{"pair": manifestation_id(), "hp_fraction": _hp_fraction_for_ledger()},
		true,
		true
	)
	# transaction_followers() floors at zero, so an empty congregation reports no
	# change. The roll still succeeded: the collector takes what exists, it does
	# not put the player into arrears.
	if int(result.get("change", 0)) >= 0:
		return
	popup("DEBT COLLECTED", noun_colour(&"fortune"), 1.35)


func _hp_fraction_for_ledger() -> float:
	return state.hp_fraction() if (state != null and is_instance_valid(state)) else player_hp_fraction()


func describe() -> String:
	var luck: float = LUCK_WHILE_DYING * potency()
	# Static, pure and instance-free, so quoting the resolver is safe on the
	# detached node this renders on - and the tooltip cannot drift from the
	# maths the way a hand-copied percentage would.
	var reached: float = LuckResolver.lucky_crit_chance(luck) * 100.0
	var ceiling: float = LuckResolver.lucky_crit_chance(1.0e6) * 100.0
	return (
		"Fall to %d%% health and the debt opens: +%.0f Luck - enough to sit every Luck roll in the game on its ceiling, and Lucky Crits at %.1f%% against a hard cap of %.1f%%. Overwhelming, not certain. It holds for %ds and then drains over %ds to almost nothing, and only climbing back out reopens it - a creditor collects, it does not fund you. Every Lucky Crit takes 1 Follower: no refusal, and no respect for your reconstruction cost."
		% [
			int(round(DYING_FRACTION * 100.0)),
			luck,
			reached,
			ceiling,
			int(DEBT_GRACE),
			int(DEBT_WINDOW),
		]
	)


func _draw() -> void:
	if not _collecting:
		return
	# A collector's ring: ward red for the wound that opened it, fortune gold for
	# the ticks it is counting, and a hand that sweeps because the debt is live.
	var wound: Color = noun_colour(&"ward")
	var coin: Color = noun_colour(&"fortune")
	var breathe: float = 0.72 + 0.28 * sin(_pulse * 3.4)
	var radius: float = 30.0

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 44, Color(wound.r, wound.g, wound.b, 0.34 * breathe), 2.0, true)
	for i in range(8):
		var angle: float = -PI * 0.5 + TAU * (float(i) / 8.0)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(dir * (radius - 4.0), dir * (radius + 3.0), Color(coin.r, coin.g, coin.b, 0.42 * breathe), 1.6, true)

	var hand: float = -PI * 0.5 + fposmod(_pulse * 2.1, TAU)
	var tip: Vector2 = Vector2(cos(hand), sin(hand)) * (radius - 2.0)
	draw_line(Vector2.ZERO, tip, Color(coin.r, coin.g, coin.b, 0.55), 2.0, true)
