extends ManifestationPairEffect

## Tithe Rhythm - cadence x fortune.
##
## Population becomes ammunition on a clock. The beat the cadence rules already
## empower is the beat that spends a believer to fire twice, and a kill inside
## the return window buys them back - so the rule is sustainable exactly while
## you are actually killing with the shots it is paying for.
##
## THE REFUSAL IS THE RULE, not a failure case. Followers are money AND lives
## AND belief; a tithe that could eat your way past your own reconstruction
## would be a trap rather than a bargain. This matches Tithe Furnace's floor
## exactly, deliberately: two rules that spend the same currency must refuse in
## the same place or the player learns two different rules.
##
## THE BEAT is state.beat_in_cycle(BEATS) - the SHARED counter, not a private
## join marker. That is the point of the pairing: this fires on the same beat
## Third Litany empowers, so "your empowered beat" means one beat rather than
## two rhythms drifting past each other. repeat_player_attack() advances the
## shared counter too, so the echo carries the rhythm forward for every cadence
## rule instead of being invisible to them.
##
## THAT HAS A CONSEQUENCE WORTH KNOWING, and it is kept on purpose: the echo
## spends a beat, so after the first tithe the pair comes back around every TWO
## real attacks rather than every three, and Third Litany accelerates with it.
## The tithe compounds exactly as fast as the player can pay for it, and the
## reconstruction floor - not an authored cooldown - is what stops it. The
## tooltip quotes both: the rule (every 3rd beat), because that is the thing
## the player controls, and the two-attack cadence it settles into, because a
## rule that visibly fires faster than its own text reads as broken.

const BEATS: int = 3

## A full second shot at rank 0 - "fire a second time", as authored - which
## rarity then sharpens. The conversion IS the payoff, so this is the one number
## potency touches.
const ECHO_DAMAGE: float = 1.0

## How long after the second shot a kill still counts as ITS kill.
##
## Flat, deliberately not scaled by rank. A window that grew would make the
## tithe free at high rarity, and "ammunition you have to earn back" stops being
## a decision the moment it always refunds.
## Was 0.50, which in a horde is "always": something dies within half a second
## of every shot you fire, so the tithe refunded unconditionally and a tithe
## that always refunds is not a tithe. Tight enough now that the believer comes
## back when the doubled beat actually did the work, and stays spent when it
## did not.
const RETURN_WINDOW: float = 0.28

const REFUSAL_POPUP_COOLDOWN: float = 2.5

const SPEND_REASON: StringName = &"manifestation_pair_tithe"
## A distinct reason for the return leg: the Follower ledger is audited, and a
## refund that shared the spend's reason would be indistinguishable from a bug
## that paid Followers out of thin air.
const RETURN_REASON: StringName = &"manifestation_pair_tithe_return"

const COLD: Color = Color(0.62, 0.68, 0.80, 1.0)

const VFX_EMBERS: GDScript = preload("res://assets/vfx/world/manifestations/VFX_TitheEmbers.gd")

## A believer is owed back only while their shot is still resolving. One flag,
## not a counter: exactly one Follower was spent, so at most one comes back.
var _owed: bool = false
var _last_tithe_index: int = -1
var _return_left: float = 0.0
var _refusal_cd: float = 0.0


func _ready() -> void:
	set_process(true)


func echo_multiplier() -> float:
	return ECHO_DAMAGE * potency()


func on_attack(
	style_id: StringName,
	_origin: Vector2,
	target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if state == null or not is_instance_valid(state):
		return
	# attack_index 0 means "no attack has been counted yet", which is not the top
	# of a cycle. Without this a stalled counter would read as beat 0 on every
	# single shot and tithe a Follower per attack - the failure mode has to be
	# "never fires", the same way every join-marker rule degrades.
	if state.attack_index <= 0:
		return
	if state.beat_in_cycle(BEATS) != 0:
		return
	# Its own echo advances the shared counter, so a three-beat cycle was
	# arriving every TWO real attacks - the rule was firing half again as often
	# as it is authored to, which is a permanent doubling of attack rate rather
	# than a rhythm. Gate on beats that have actually elapsed since the last
	# tithe, so the echo carries every OTHER rule's rhythm forward (which is the
	# point of a shared counter) without shortening its own.
	if _last_tithe_index >= 0 and state.attack_index - _last_tithe_index < BEATS:
		return
	_last_tithe_index = state.attack_index
	_try_tithe(style_id, target)


## The honest approximation, and it is one: nothing in the damage path carries
## "which shot killed this", so a kill is credited to the second shot if it
## lands within RETURN_WINDOW of it. The runner has already filtered to kills
## the player caused, so the window is the only slack - and it is generous in
## the player's favour, which is the right direction for a refund.
func on_kill(_context: EnemyDeathContext) -> void:
	if not _owed or _return_left <= 0.0:
		return
	_owed = false
	_return_left = 0.0
	if Global == null:
		return
	Global.transaction_followers(
		1,
		RETURN_REASON,
		{"pair": manifestation_id()},
		true,
		true
	)
	popup("BELIEVER RETURNS", noun_colour(&"fortune"), 1.30)


func _process(delta: float) -> void:
	if _refusal_cd > 0.0:
		_refusal_cd = maxf(0.0, _refusal_cd - delta)
	if _return_left <= 0.0:
		return
	_return_left = maxf(0.0, _return_left - delta)
	if _return_left <= 0.0:
		# Silent: the shot missed, and a "you lost a Follower" line on top of the
		# spend line the player already read would be the same news twice.
		_owed = false


func _try_tithe(style_id: StringName, target: Vector2) -> void:
	if Global == null:
		return
	var cost: int = int(Global.compute_respawn_cost())
	var have: int = int(Global.followers)
	if have - 1 < cost:
		_refuse(cost)
		return

	var result: Dictionary = Global.transaction_followers(
		-1,
		SPEND_REASON,
		{
			"pair": manifestation_id(),
			"beat": BEATS,
			"reconstruction_cost": cost,
		},
		true,
		true
	)
	# The ledger is the authority; never fire a shot we did not actually pay for.
	if int(result.get("change", 0)) >= 0:
		return

	# Armed BEFORE the echo, because a melee echo can resolve its damage inside
	# repeat_player_attack() and the kill it causes would otherwise arrive with
	# no window open to refund into.
	_owed = true
	_return_left = RETURN_WINDOW
	repeat_player_attack(style_id, target, echo_multiplier())

	var embers: Node2D = VFX_EMBERS.new() as Node2D
	if embers != null:
		spawn_world_node(embers, player_position())
	# Merged against itself: at speed this line repeats a couple of times a
	# second and says the same thing each time. The return line stays unmerged,
	# because it is different news.
	popup("TITHE - SECOND SHOT", noun_colour(&"fortune"), 1.25, int(get_instance_id()))


func _refuse(cost: int) -> void:
	if _refusal_cd > 0.0:
		return
	_refusal_cd = REFUSAL_POPUP_COOLDOWN
	popup("TITHE REFUSES (%d TO REBUILD)" % cost, COLD, 1.20)


func describe() -> String:
	return (
		"Every %d beats - %d attacks once it is running, since the second shot is itself a beat - the beat spends 1 Follower to fire a second time for %d%% of your attack damage. A kill within %.2fs returns them. It refuses to spend if that would drop you below your reconstruction cost."
		% [BEATS, BEATS - 1, int(round(echo_multiplier() * 100.0)), RETURN_WINDOW]
	)
