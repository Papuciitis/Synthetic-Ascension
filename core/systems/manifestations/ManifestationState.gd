extends Node2D
class_name ManifestationState

## Shared blackboard for every equipped Manifestation.
##
## Manifestations are independent rules, but several of them deliberately talk
## about the SAME nouns - Momentum, Stability, Shards, the Mark, Misfortune.
## Those nouns live here exactly once, so "crit makes shards" and "full halo
## launches shards" can be rolled on two unrelated items and still form an
## engine. Producers raise a source count; the resource only exists (and only
## shows in the HUD) while something is actually producing it.

## A noun reached its full mark, or was spent. Pairs that fire on "the other
## noun's payoff just happened" cannot express that through slot-ordered hooks -
## by the time a pair is dispatched the resource is already gone. The HUD's
## per-noun pulse reads the same two signals.
@warning_ignore("unused_signal")
signal resource_filled(noun: StringName)
@warning_ignore("unused_signal")
signal resource_spent(noun: StringName, amount: float)

const MarkVfx = preload("res://assets/vfx/world/manifestations/VFX_SigilMark.gd")

const SHARD_ORBIT_RADIUS: float = 46.0
const SHARD_ORBIT_SPEED: float = 2.3
const SHARD_HIT_RADIUS: float = 22.0
const SHARD_HIT_COOLDOWN: float = 0.32
const SHARD_SWEEP_INTERVAL: float = 0.08

const MOMENTUM_DECAY_PER_SEC: float = 0.85

## Pixels of unbroken travel that fill Momentum on their own, for ANY rule that
## claims the noun.
##
## The noun owns its resource; rules own the verbs that spend it. Previously
## exactly one rule produced Momentum and three spent it, so rolling a spender
## without the producer - about five times in six - gave the player a rule that
## could physically never fire, sitting next to a meter pinned at 0%. Worse, the
## prerequisite weighting then made a SECOND spender likelier. A dead item with
## an explanatory-looking bar is the worst thing this layer can hand someone in
## their first ten minutes.
##
## Deliberately slower than Pilgrim's Momentum's own fill, so the specialist is
## still visibly the specialist.
const MOMENTUM_BASE_FILL_DISTANCE: float = 704.0
const STABILITY_DECAY_PER_SEC: float = 1.60

# --- the noun registry ------------------------------------------------------
#
# A NOUN is what a rule tags itself with; a CHANNEL is one stored value. Most
# nouns own exactly one channel, but Momentum owns two opposite poles -
# Momentum builds while you run and Stability while you stand - because they are
# one movement decision with a sign, not two unrelated meters. Splitting them
# into separate nouns is what made "these two items hate each other" read as an
# accident instead of the design.
#
# Claiming, dormancy, decay, caps and the HUD readout are all driven from here,
# so adding a noun is one entry rather than an edit to four parallel match
# blocks that were guaranteed to drift apart.
#
# `field` names the script variable that stores the value. Structurally richer
# channels (the orbit, the Mark) keep their typed storage and declare
# KIND_CUSTOM; only those two need a branch in _reset_channel()/_meter_text().
#
# `cap` is authoritative and readable with NO instance, because rule tooltips
# render through ManifestationCatalog.describe() on a detached node.

const KIND_FRACTION: int = 0
const KIND_COUNT: int = 1
const KIND_CUSTOM: int = 2
const KIND_SECONDS: int = 3

## Decay gates. A noun decays only while its gate condition holds.
const DECAY_NEVER: StringName = &""
const DECAY_WHEN_STILL: StringName = &"still"
const DECAY_WHEN_MOVING: StringName = &"moving"

## noun -> the channels it owns. These five keys are the complete tag
## vocabulary; every rule declares one or two of them.
##
## FROZEN AT FIVE. Authored pair payoffs are a function of the noun set, so a
## sixth noun is not one more thing to write - it is five more.
const NOUNS: Dictionary = {
	&"momentum": [&"momentum", &"stability"],
	&"shard": [&"shard", &"mark"],
	&"fortune": [&"misfortune"],
	&"cadence": [&"attack_index", &"time_since_attack"],
	&"ward": [&"time_since_hit"],
}

const CHANNELS: Dictionary = {
	&"momentum": {
		"label": "MOMENTUM",
		"kind": KIND_FRACTION,
		"field": &"momentum",
		"cap": 1.0,
		"full_at": 0.999,
		"decay_per_sec": MOMENTUM_DECAY_PER_SEC,
		"decay_when": DECAY_WHEN_STILL,
	},
	&"stability": {
		"label": "STABILITY",
		"kind": KIND_FRACTION,
		"field": &"stability",
		"cap": 1.0,
		"full_at": 0.999,
		"decay_per_sec": STABILITY_DECAY_PER_SEC,
		"decay_when": DECAY_WHEN_MOVING,
	},
	&"misfortune": {
		"label": "MISFORTUNE",
		"kind": KIND_COUNT,
		"field": &"misfortune",
		# The bank cap lives here, not on the rule that happens to produce it.
		# A second producer that clamped to its own private constant would bank
		# past this and have the excess consumed and silently thrown away.
		"cap": 25,
		"full_at": 25,
		"decay_per_sec": 0.0,
		"decay_when": DECAY_NEVER,
	},
	&"shard": {
		"label": "SHARDS",
		"kind": KIND_CUSTOM,
		"field": &"shards",
		"decay_per_sec": 0.0,
		"decay_when": DECAY_NEVER,
	},
	&"mark": {
		"label": "MARK",
		"kind": KIND_CUSTOM,
		"field": &"marked_handle",
		"decay_per_sec": 0.0,
		"decay_when": DECAY_NEVER,
	},
	# Cadence: three rules each kept a private copy of these two numbers, and a
	# fourth would have kept a fourth. The counter is what makes "every third
	# attack" and "every eighth attack" the same noun rather than two
	# coincidences, and it is why an echo can carry another rule's rhythm.
	&"attack_index": {
		"label": "ATTACKS",
		"kind": KIND_COUNT,
		"field": &"attack_index",
		"meter": false,
		"decay_per_sec": 0.0,
		"decay_when": DECAY_NEVER,
	},
	&"time_since_attack": {
		"label": "CADENCE",
		"kind": KIND_SECONDS,
		"field": &"time_since_attack",
		"decay_per_sec": 0.0,
		"decay_when": DECAY_NEVER,
	},
	&"time_since_hit": {
		"label": "COMPOSURE",
		"kind": KIND_SECONDS,
		"full_at": COMPOSURE_SECONDS,
		"field": &"time_since_hit",
		"decay_per_sec": 0.0,
		"decay_when": DECAY_NEVER,
	},
}

## Where "wounded" and "dying" are, owned once. Two ward rules that each picked
## their own thresholds would disagree about the same word.
const WOUND_HEALTHY: float = 0.70
const WOUND_WOUNDED: float = 0.40
const WOUND_DYING: float = 0.20

## Shared retaliation cooldown. A packed swarm resolves many contacts in one
## frame; without one shared gate, two ward rules answer the same instant twice.
const RETALIATION_COOLDOWN: float = 0.12

## How long an attack takes to "resolve" for rhythm purposes. Owned here for the
## same reason the wound tiers are: a rule that talks about BREAKING a rhythm
## needs the same threshold as the rule that defines one, or the two disagree
## about the word and the player can learn neither.
const CADENCE_RESOLVE_WINDOW: float = 0.30
## Consecutive attacks inside this gap are a chain rather than separate beats.
## Strictly longer than the resolve window, so "held the beat" and "kept the
## chain" remain distinguishable states.
const CADENCE_CHAIN_WINDOW: float = 0.42

## Luck the layer contributes, summed through the ledger so several fortune
## rules stack predictably instead of each writing Stats directly.
const CHANNEL_LUCK: StringName = &"luck"
## Evasion the layer contributes. Lives here rather than being summed in the
## runner, so it is one shared budget with one clamp.
const CHANNEL_EVASION: StringName = &"evasion"
const EVASION_CLAMP: float = 0.45

var player: Node2D = null

# --- raw movement telemetry (always tracked; costs one length() per frame) ---
var distance_since_stop: float = 0.0
var still_time: float = 0.0
var is_moving: bool = false
var distance_travelled_total: float = 0.0

# --- shared resources -------------------------------------------------------
var momentum: float = 0.0
var stability: float = 0.0
var misfortune: int = 0

# --- the Mark ---------------------------------------------------------------
var marked_handle: int = 0
var mark_time_left: float = 0.0

## The Mark is shared, so its world marker is owned here rather than by whichever
## rule happened to place it. Rule-owned marker ownership meant a second Mark
## rule either duplicated forty lines of adoption/hand-off bookkeeping or left
## the Mark live but invisible when the owning item was unequipped.
var _mark_vfx: Node2D = null

# --- cadence ----------------------------------------------------------------
var attack_index: int = 0
var time_since_attack: float = 999.0

## COMPOSURE - what makes the ward noun's clock mean something.
##
## time_since_hit was written every hit and read by absolutely nothing, so the
## HUD rendered "WARD 12.4s" - a number that changed and did not matter. It also
## left the ward nouns lopsided: Martyr Circuit is faster wounded, Scar Tissue
## makes healing a trap, Red Line is immune wounded and Debt Collector floods
## Luck wounded. Four effects rewarded being nearly dead and NOTHING rewarded
## being healthy, so the whole noun pointed at parking on the dying line.
##
## Go this long unhurt and the next hit that lands is blunted, once. Available to
## anything that claims ward, because it is the noun's property and not one
## rule's. The bar now fills toward something, and staying untouched is finally
## worth what taking hits is worth.
const COMPOSURE_SECONDS: float = 6.0
const COMPOSURE_REDUCTION: float = 0.45

# --- ward -------------------------------------------------------------------
var time_since_hit: float = 999.0
var _retaliation_cd: float = 0.0

# --- fortune ----------------------------------------------------------------
var lucky_crits: int = 0
var lucky_crit_failures: int = 0

# --- shards -----------------------------------------------------------------
const BASE_SHARD_CAP: int = 4
const BASE_SHARD_DAMAGE_MULT: float = 0.55

## Contribution channels. Deliberately methods rather than variables: several
## rules raise the same number and any of them may be unequipped first, so a
## rule that ASSIGNED would silently clobber the others with no way to restore
## what it overwrote. Making them unassignable turns that into a parse error.
const CHANNEL_SHARD_CAP: StringName = &"shard_cap"
const CHANNEL_SHARD_DAMAGE: StringName = &"shard_damage"

var shards: Array[Dictionary] = []
var _shard_sweep: float = 0.0
var _shard_spin: float = 0.0

## noun -> claimer count. A noun with no claimers stays dormant: it accepts no
## value and never shows in the HUD.
var _sources: Dictionary = {}

## channel -> { owner_key -> amount }. See CHANNEL_* above.
var _contributions: Dictionary = {}

var last_attack_gap: float = 999.0
var _momentum_odometer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _has_last_position: bool = false
var _drew_shards: bool = false

# Named re-entrancy latches shared by every copy of a rule. A per-instance flag
# only stops a rule re-entering ITSELF; two copies of the same rule in different
# slots would still cross-trigger and multiply their own payout.
var _exclusive: Dictionary = {}


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4070
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func bind_player(p: Node2D) -> void:
	player = p
	_has_last_position = false


# ---------------------------------------------------------------------------
# Source registration. An effect claims the resources it speaks about in
# _ready() and releases them in _exit_tree(); unclaimed resources stay dormant.
# ---------------------------------------------------------------------------

func claim(resource: StringName, amount: int = 1) -> void:
	if not NOUNS.has(resource):
		push_warning("[Manifestations] unknown noun claimed: %s" % String(resource))
		return
	var count: int = maxi(0, int(_sources.get(resource, 0)) + amount)
	_sources[resource] = count
	if count <= 0:
		for channel in (NOUNS[resource] as Array):
			_reset_channel(channel)


func release(resource: StringName) -> void:
	claim(resource, -1)


## Atomic re-claim for an equipped-set change.
##
## Claim BEFORE release, always. Dropping a noun to zero claimers resets it, so
## releasing first and claiming second would wipe the player's bank every time
## they swapped one momentum ring for another. (Today the effect nodes are
## queue_free()d, so their release happens to land after the incoming claim -
## this makes that ordering deliberate instead of accidental.)
func claim_batch(added: Array, removed: Array) -> void:
	for noun in added:
		claim(noun)
	for noun in removed:
		release(noun)


# ---------------------------------------------------------------------------
# Contribution ledger
#
# Every rule that raises a shared number registers what IT contributes, keyed by
# its own identity. Setting the same key again re-levels (rank-up), and removal
# is one clear_contributions() - no delta arithmetic for a rule to get wrong,
# and no ordering dependency between two copies of the same rule.
# ---------------------------------------------------------------------------

func set_contribution(channel: StringName, owner_key: StringName, amount: float) -> void:
	if owner_key == &"":
		return
	var by_owner: Dictionary = _contributions.get(channel, {})
	by_owner[owner_key] = amount
	_contributions[channel] = by_owner


func clear_contributions(owner_key: StringName) -> void:
	if owner_key == &"":
		return
	for channel in _contributions:
		(_contributions[channel] as Dictionary).erase(owner_key)


func contribution_total(channel: StringName) -> float:
	var by_owner: Variant = _contributions.get(channel, null)
	if not (by_owner is Dictionary):
		return 0.0
	var total := 0.0
	for amount in (by_owner as Dictionary).values():
		total += float(amount)
	return total


func shard_cap() -> int:
	return maxi(1, BASE_SHARD_CAP + int(round(contribution_total(CHANNEL_SHARD_CAP))))


func shard_damage_mult() -> float:
	return maxf(0.0, BASE_SHARD_DAMAGE_MULT + contribution_total(CHANNEL_SHARD_DAMAGE))


func _reset_channel(channel: StringName) -> void:
	# Only channels with structural backing need a branch; a plain scalar is
	# handled by the default and costs nothing to add.
	match channel:
		&"shard":
			shards.clear()
		&"mark":
			clear_mark()
		_:
			var entry: Dictionary = CHANNELS[channel]
			var field := String(entry["field"])
			match int(entry["kind"]):
				KIND_COUNT:
					set(field, 0)
				KIND_SECONDS:
					# A clock resets to "long ago", not to "just now" - zero
					# would read as an attack that never happened.
					set(field, 999.0)
				_:
					set(field, 0.0)


## The noun that owns a channel, for gating and display.
static func noun_for_channel(channel: StringName) -> StringName:
	for noun in NOUNS:
		if (NOUNS[noun] as Array).has(channel):
			return noun
	return &""


## Returns false when `key` is already inside its exclusive section. Callers
## that get true MUST call end_exclusive(key) on every path out.
func begin_exclusive(key: StringName) -> bool:
	if bool(_exclusive.get(key, false)):
		return false
	_exclusive[key] = true
	return true


func end_exclusive(key: StringName) -> void:
	_exclusive[key] = false


func is_exclusive_held(key: StringName) -> bool:
	return bool(_exclusive.get(key, false))


func has_source(resource: StringName) -> bool:
	return int(_sources.get(resource, 0)) > 0


func source_count(resource: StringName) -> int:
	return int(_sources.get(resource, 0))


## Authoritative cap for a noun, readable with no instance so rule tooltips
## (which render detached) can quote the real number.
static func noun_cap(resource: StringName) -> float:
	var entry: Variant = CHANNELS.get(resource, null)
	if entry is Dictionary and (entry as Dictionary).has("cap"):
		return float((entry as Dictionary)["cap"])
	return 0.0


# ---------------------------------------------------------------------------
# Momentum / Stability
# ---------------------------------------------------------------------------

func add_momentum(amount: float) -> void:
	if not has_source(&"momentum"):
		return
	var before := momentum
	momentum = clampf(momentum + amount, 0.0, noun_cap(&"momentum"))
	if momentum > 0.0:
		note_channel_touched(&"momentum")
	if before < 0.999 and momentum >= 0.999:
		resource_filled.emit(&"momentum")


func consume_momentum() -> float:
	var spent := momentum
	momentum = 0.0
	if spent > 0.0:
		resource_spent.emit(&"momentum", spent)
	return spent


func add_stability(amount: float) -> void:
	# Stability is the other pole of the Momentum noun, not a noun of its own.
	if not has_source(&"momentum"):
		return
	var before := stability
	stability = clampf(stability + amount, 0.0, noun_cap(&"stability"))
	if stability > 0.0:
		note_channel_touched(&"stability")
	if before < 0.999 and stability >= 0.999:
		resource_filled.emit(&"momentum")


func break_stability() -> void:
	stability = 0.0


# ---------------------------------------------------------------------------
# Cadence
# ---------------------------------------------------------------------------

## One beat of the shared rhythm. Called for every real attack AND for every
## echo a rule fires, so a rule that repeats your attack carries another rule's
## rhythm forward instead of being invisible to it.
func note_attack() -> void:
	if not has_source(&"cadence"):
		return
	# The gap that PRECEDED this attack. Read inside on_attack, time_since_attack
	# is always exactly 0.0 - the runner advances the beat before it dispatches -
	# so any rule judging "did the chain hold?" against it was answering itself.
	last_attack_gap = time_since_attack
	time_since_attack = 0.0
	note_channel_touched(&"time_since_attack")
	advance_beat()


## Advance the shared beat WITHOUT touching the rhythm clock.
##
## For anything that supplies a beat the player did not fire - walking a stride,
## an echo the world produced. note_attack() zeroes time_since_attack, which is
## a different resource entirely: Stored Violence charges off that gap, so a
## walked beat every second kept its charge under 30% forever, and Fever Litany
## reads it to decide whether the chain held, so walking pinned the fever at max
## for free. A beat and a gap are not the same event and must not be one call.
func advance_beat() -> void:
	if not has_source(&"cadence"):
		return
	attack_index += 1
	note_channel_touched(&"attack_index")
	resource_spent.emit(&"cadence", 1.0)


## Beat inside a cycle of `beats`, 0-based. The shared counter is what lets
## "every third attack" and "every eighth attack" be the same noun.
func beat_in_cycle(beats: int) -> int:
	if beats <= 1:
		return 0
	return attack_index % beats


# ---------------------------------------------------------------------------
# Ward
# ---------------------------------------------------------------------------

func hp_fraction() -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	var hp: Variant = player.get("hp")
	var max_hp: Variant = player.get("max_hp")
	if (hp is float or hp is int) and (max_hp is float or max_hp is int) and float(max_hp) > 0.0:
		return clampf(float(hp) / float(max_hp), 0.0, 1.0)
	return 1.0


## 0 healthy, 1 hurt, 2 wounded, 3 dying. Shared so two ward rules agree on
## where the words are.
func wound_tier() -> int:
	var fraction := hp_fraction()
	if fraction > WOUND_HEALTHY:
		return 0
	if fraction > WOUND_WOUNDED:
		return 1
	if fraction > WOUND_DYING:
		return 2
	return 3


func note_hit_taken() -> void:
	if not has_source(&"ward"):
		return
	time_since_hit = 0.0


## Is a blunted hit banked right now? Read-only; the HUD and describe() use it.
func composure_ready() -> bool:
	return has_source(&"ward") and time_since_hit >= COMPOSURE_SECONDS


## Multiplier for the hit that is landing, spending the guard if one is banked.
## Called from ManifestationRunner.get_damage_taken_multiplier(), which player.gd
## polls exactly once per landed hit - after the evade roll, so an evaded hit
## never burns it.
func consume_composure() -> float:
	if not composure_ready():
		return 1.0
	time_since_hit = 0.0
	resource_spent.emit(&"ward", 1.0)
	return 1.0 - COMPOSURE_REDUCTION


## Shared gate for "something connected with you, answer it once".
func try_retaliate() -> bool:
	if _retaliation_cd > 0.0:
		return false
	_retaliation_cd = RETALIATION_COOLDOWN
	return true


func bonus_evasion() -> float:
	return clampf(contribution_total(CHANNEL_EVASION), 0.0, EVASION_CLAMP)


# ---------------------------------------------------------------------------
# Fortune
# ---------------------------------------------------------------------------

func note_lucky_crit(succeeded: bool) -> void:
	if not has_source(&"fortune"):
		return
	if succeeded:
		lucky_crits += 1
	else:
		lucky_crit_failures += 1


func bonus_luck() -> float:
	return contribution_total(CHANNEL_LUCK)


# ---------------------------------------------------------------------------
# Misfortune
# ---------------------------------------------------------------------------

func add_misfortune(amount: int = 1) -> void:
	if not has_source(&"fortune"):
		return
	# Clamped to the registry cap, so what is banked is exactly what a consumer
	# can pay out. The old 999 clamp let a second producer bank points that
	# consume_misfortune() then zeroed without ever paying for them.
	var before := misfortune
	misfortune = clampi(misfortune + amount, 0, int(noun_cap(&"misfortune")))
	if misfortune > 0:
		note_channel_touched(&"misfortune")
	if before < misfortune and misfortune >= int(noun_cap(&"misfortune")):
		resource_filled.emit(&"fortune")


func consume_misfortune() -> int:
	var spent := misfortune
	misfortune = 0
	if spent > 0:
		resource_spent.emit(&"fortune", float(spent))
	return spent


# ---------------------------------------------------------------------------
# The Mark
# ---------------------------------------------------------------------------

func set_mark(handle: int, duration: float) -> void:
	# The Mark is a channel of the shard noun - the Sigil already spends the orbit.
	if not has_source(&"shard"):
		return
	var retarget := handle != marked_handle
	marked_handle = handle
	mark_time_left = maxf(mark_time_left, duration)
	note_channel_touched(&"mark")
	if retarget:
		_release_mark_vfx()
	if _mark_vfx == null or not is_instance_valid(_mark_vfx):
		_mark_vfx = spawn_world_node(MarkVfx.new() as Node2D, mark_position())
	if _mark_vfx != null:
		_mark_vfx.call(&"setup", marked_handle, mark_time_left)


func clear_mark() -> void:
	marked_handle = 0
	mark_time_left = 0.0
	_release_mark_vfx()


## Ends the Mark with its death flourish. Clears first, so the enemies the
## blast kills cannot re-enter a kill hook that still sees a live Mark.
func detonate_mark(at: Vector2, radius: float) -> void:
	var vfx := _mark_vfx
	_mark_vfx = null
	marked_handle = 0
	mark_time_left = 0.0
	if vfx != null and is_instance_valid(vfx):
		vfx.call(&"detonate", at, radius)


func _release_mark_vfx() -> void:
	if _mark_vfx != null and is_instance_valid(_mark_vfx):
		_mark_vfx.call(&"release")
	_mark_vfx = null


## Spawns a presentation node into the live scene. Lives here because the state
## outlives any individual rule, so a visual that belongs to a shared noun is
## not orphaned when the rule that triggered it is unequipped.
func spawn_world_node(node: Node2D, world_position: Vector2) -> Node2D:
	if node == null:
		return null
	var host: Node = get_tree().current_scene if get_tree() != null else null
	if host == null:
		node.queue_free()
		return null
	host.add_child(node)
	node.global_position = world_position
	return node


func is_marked(handle: int) -> bool:
	return marked_handle != 0 and handle == marked_handle and mark_time_left > 0.0


func mark_position() -> Vector2:
	if marked_handle == 0 or EnemyCombat == null:
		return Vector2.ZERO
	return EnemyCombat.position_for_handle(marked_handle)


# ---------------------------------------------------------------------------
# Shards
# ---------------------------------------------------------------------------

func shard_count() -> int:
	return shards.size()


func shards_full() -> bool:
	return shards.size() >= shard_cap()


func add_shard(count: int = 1) -> int:
	if not has_source(&"shard"):
		return 0
	var added := 0
	for _i in range(maxi(1, count)):
		if shards.size() >= shard_cap():
			break
		shards.append({
			"angle": randf() * TAU,
			"radius": SHARD_ORBIT_RADIUS * randf_range(0.86, 1.14),
			"cd": 0.0,
			"age": 0.0,
		})
		added += 1
	if added > 0:
		note_channel_touched(&"shard")
	if added > 0 and shards_full():
		resource_filled.emit(&"shard")
	return added


func take_shards(count: int = -1) -> int:
	var taken: int = shards.size() if count < 0 else mini(count, shards.size())
	if taken <= 0:
		return 0
	shards.resize(shards.size() - taken)
	resource_spent.emit(&"shard", float(taken))
	return taken


func shard_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var origin := _origin()
	for shard in shards:
		var angle := float(shard.get("angle", 0.0)) + _shard_spin
		out.append(origin + Vector2(cos(angle), sin(angle)) * float(shard.get("radius", SHARD_ORBIT_RADIUS)))
	return out


# ---------------------------------------------------------------------------
# Popup staggering
#
# Every rule's popup spawns at the player, so a single kill that trips four
# rules renders four lines on top of each other and the player reads none of
# them. Slots are per-FRAME rather than per-rule: only simultaneous popups
# collide, and one rule firing repeatedly still gets the same position every
# time, which is what makes a repeated line readable as a repeat.
# ---------------------------------------------------------------------------

const POPUP_STAGGER: float = 16.0

var _popup_frame: int = -1
var _popup_slot: int = 0


## Vertical offset for the next popup fired this frame. Positive is DOWN, so
## the first caller of the frame keeps the highest line.
func next_popup_offset() -> Vector2:
	var frame := Engine.get_process_frames()
	if frame != _popup_frame:
		_popup_frame = frame
		_popup_slot = 0
	var offset := Vector2(0.0, POPUP_STAGGER * float(_popup_slot))
	_popup_slot += 1
	return offset


# ---------------------------------------------------------------------------
# Shared helpers every Manifestation may use
# ---------------------------------------------------------------------------

func player_base_damage() -> float:
	if player == null or not is_instance_valid(player):
		return 12.0
	var raw: Variant = player.get("base_weapon_damage")
	if raw is float or raw is int:
		return float(raw)
	return 12.0


func player_power_multiplier() -> float:
	if player == null or not is_instance_valid(player):
		return 1.0
	var stats: Variant = player.get("stats")
	if stats is Object:
		var power: Variant = (stats as Object).get("power")
		if power is float or power is int:
			return 1.0 + float(power)
	return 1.0


func scaled_attack_damage(multiplier: float) -> float:
	return maxf(0.0, player_base_damage() * multiplier * player_power_multiplier())


func damage_radius(center: Vector2, radius: float, damage: float, knockback: float = 0.0) -> int:
	if EnemyCombat == null or damage <= 0.0:
		return 0
	var handles: Array[int] = []
	EnemyCombat.gather_in_radius(center, radius, handles)
	for handle in handles:
		EnemyCombat.apply_damage(handle, damage, 1, player)
		if knockback > 0.0:
			var offset := EnemyCombat.position_for_handle(handle) - center
			if offset.length_squared() > 0.01:
				EnemyCombat.apply_knockback(handle, offset.normalized() * knockback)
	return handles.size()


func aim_direction() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.RIGHT
	var pivot := player.get_node_or_null("AimPivot") as Node2D
	if pivot != null:
		return Vector2.RIGHT.rotated(pivot.global_rotation)
	return Vector2.RIGHT.rotated(player.global_rotation)


func nearest_enemy_direction(from: Vector2, max_range: float = 900.0) -> Vector2:
	if EnemyCombat == null:
		return Vector2.ZERO
	var handle := EnemyCombat.nearest_enemy(from, max_range)
	if handle == EnemyWorldTypes.INVALID_HANDLE:
		return Vector2.ZERO
	var offset := EnemyCombat.position_for_handle(handle) - from
	if offset.length_squared() < 0.01:
		return Vector2.ZERO
	return offset.normalized()


# ---------------------------------------------------------------------------
# HUD readout - what the Run Sheet shows so the player can read their engine.
# ---------------------------------------------------------------------------

func get_meters() -> Array[Dictionary]:
	# Allocates a dict and formats a String per live noun, so this is the
	# once-a-change readout, not a per-frame one. A HUD that ticks should read
	# noun_value()/noun_is_full() instead.
	var out: Array[Dictionary] = []
	for noun in NOUNS:
		if not has_source(noun):
			continue
		for channel in (NOUNS[noun] as Array):
			if channel == &"mark" and mark_time_left <= 0.0:
				continue
			if not bool((CHANNELS[channel] as Dictionary).get("meter", true)):
				continue
			# A noun nothing in this loadout can produce has no business
			# rendering a bar. "SHARDS 0/4" that never moves teaches the player
			# that the counter is decoration, which poisons every meter beside
			# it. Whole-noun granularity on purpose: Momentum and Stability are
			# two poles of one decision and must light together.
			if not bool(_touched.get(noun, false)) and noun_value(channel) <= 0.0:
				continue
			out.append({
				"noun": noun,
				"channel": channel,
				"label": String(CHANNELS[channel]["label"]),
				"text": _meter_text(channel),
				"full": noun_is_full(channel),
			})
	return out


## Live value of a noun as a plain number, allocation-free.
## Channels that have actually moved this run. Used to hide meters for
## resources no equipped rule can produce.
var _touched: Dictionary = {}


func note_channel_touched(channel: StringName) -> void:
	for noun: StringName in NOUNS:
		if (NOUNS[noun] as Array).has(channel):
			_touched[noun] = true
			return


func noun_value(channel: StringName) -> float:
	match channel:
		&"shard":
			return float(shards.size())
		&"mark":
			return mark_time_left
		_:
			if not CHANNELS.has(channel):
				return 0.0
			return float(get(String(CHANNELS[channel]["field"])))


func noun_is_full(channel: StringName) -> bool:
	match channel:
		&"shard":
			return shards_full()
		&"mark":
			return mark_time_left > 0.0
		_:
			var entry: Variant = CHANNELS.get(channel, null)
			if not (entry is Dictionary) or not (entry as Dictionary).has("full_at"):
				return false
			return noun_value(channel) >= float((entry as Dictionary)["full_at"])


## Formatted value for one channel. Public so a HUD that only rewrites when the
## number actually moved can share the Run Sheet's formatting instead of
## inventing a second one that drifts away from it.
func channel_text(channel: StringName) -> String:
	return _meter_text(channel)


## The channel a noun is shown as when only one number fits: the first METERED
## channel it owns, in declaration order. Momentum over Stability, the cadence
## clock over the raw attack counter.
static func headline_channel(noun: StringName) -> StringName:
	for channel in (NOUNS.get(noun, []) as Array):
		if bool((CHANNELS[channel] as Dictionary).get("meter", true)):
			return channel
	return &""


func _meter_text(channel: StringName) -> String:
	match channel:
		&"shard":
			return "%d/%d" % [shards.size(), shard_cap()]
		&"mark":
			return "%.1fs" % mark_time_left
		_:
			var entry: Dictionary = CHANNELS[channel]
			match int(entry["kind"]):
				KIND_FRACTION:
					return "%d%%" % int(round(noun_value(channel) * 100.0))
				KIND_SECONDS:
					return "%.1fs" % minf(noun_value(channel), 99.0)
				_:
					return str(int(noun_value(channel)))


# ---------------------------------------------------------------------------

func _origin() -> Vector2:
	if player != null and is_instance_valid(player):
		return player.global_position
	return global_position


func _process(delta: float) -> void:
	_track_movement(delta)
	_tick_mark(delta)
	_tick_shards(delta)

	_tick_momentum()
	_tick_decay(delta)

	# Cadence and ward clocks. Both count UP and are reset by an event, so they
	# are not decay - a decaying clock would silently forget how long it has
	# been since you last attacked.
	if has_source(&"cadence"):
		time_since_attack += delta
	if has_source(&"ward"):
		time_since_hit += delta
	if _retaliation_cd > 0.0:
		_retaliation_cd = maxf(0.0, _retaliation_cd - delta)

	# An empty orbit has nothing to paint; repaint once on the transition so the
	# last shard actually disappears.
	if has_source(&"shard") and (not shards.is_empty() or _drew_shards):
		_drew_shards = not shards.is_empty()
		queue_redraw()


func _tick_momentum() -> void:
	# Travel fills Momentum for anything that claims the noun, so a spender is
	# never inert on its own.
	if not has_source(&"momentum") or not is_moving:
		_momentum_odometer = distance_since_stop
		return
	var travelled := distance_since_stop - _momentum_odometer
	_momentum_odometer = distance_since_stop
	if travelled <= 0.0:
		return
	add_momentum(travelled / MOMENTUM_BASE_FILL_DISTANCE)


func _tick_decay(delta: float) -> void:
	# Momentum bleeds while planted, Stability bleeds while running: the two
	# poles of one movement decision. Both gates are registry data, so a new
	# decaying noun is an entry rather than another branch here.
	for channel in CHANNELS:
		var entry: Dictionary = CHANNELS[channel]
		var rate := float(entry.get("decay_per_sec", 0.0))
		if rate <= 0.0 or not has_source(noun_for_channel(channel)):
			continue
		var gate := StringName(entry.get("decay_when", DECAY_NEVER))
		if gate == DECAY_WHEN_STILL and is_moving:
			continue
		if gate == DECAY_WHEN_MOVING and not is_moving:
			continue
		var field := String(entry["field"])
		var value := float(get(field))
		if value <= 0.0:
			continue
		set(field, maxf(0.0, value - rate * delta))


func _track_movement(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		is_moving = false
		return
	var here := player.global_position
	if not _has_last_position:
		_last_position = here
		_has_last_position = true
		return
	var step := here.distance_to(_last_position)
	_last_position = here
	# A frame-rate independent "actually moving" test: 12 px/s of real travel.
	is_moving = step > 12.0 * delta
	if is_moving:
		distance_since_stop += step
		distance_travelled_total += step
		still_time = 0.0
	else:
		still_time += delta
		if still_time > 0.18:
			distance_since_stop = 0.0


func _tick_mark(delta: float) -> void:
	if mark_time_left <= 0.0:
		return
	mark_time_left -= delta
	if mark_time_left <= 0.0:
		clear_mark()
		return
	# A Mark whose enemy despawned, or was finished by a burn tick that credits
	# a different source, never reaches the kill hook. Drop it as soon as the
	# handle stops being real, or the rule keeps charging its damage penalty
	# for a target that no longer exists.
	if marked_handle != 0 and EnemyWorld != null and not EnemyWorld.is_valid_handle(marked_handle):
		clear_mark()


func _tick_shards(delta: float) -> void:
	if shards.is_empty():
		return
	_shard_spin = fposmod(_shard_spin + SHARD_ORBIT_SPEED * delta, TAU)
	for shard in shards:
		shard["cd"] = maxf(0.0, float(shard.get("cd", 0.0)) - delta)
		shard["age"] = float(shard.get("age", 0.0)) + delta

	_shard_sweep -= delta
	if _shard_sweep > 0.0:
		return
	_shard_sweep = SHARD_SWEEP_INTERVAL
	if EnemyCombat == null:
		return

	var damage := scaled_attack_damage(shard_damage_mult())
	if damage <= 0.0:
		return
	var origin := _origin()
	var handles: Array[int] = []
	# apply_damage re-enters this system synchronously: a kill can reach a rule
	# that spends the whole orbit and another that forges fresh shards into it.
	# Bound the sweep to the shards that existed when it started, re-check the
	# array every step, and stamp the cooldown BEFORE dealing damage so a shard
	# can never fire twice in one sweep.
	var sweep_count := shards.size()
	for index in range(sweep_count):
		if index >= shards.size():
			break
		var shard: Dictionary = shards[index]
		if float(shard.get("cd", 0.0)) > 0.0:
			continue
		var angle := float(shard.get("angle", 0.0)) + _shard_spin
		var pos := origin + Vector2(cos(angle), sin(angle)) * float(shard.get("radius", SHARD_ORBIT_RADIUS))
		handles.clear()
		EnemyCombat.gather_in_radius(pos, SHARD_HIT_RADIUS, handles)
		if handles.is_empty():
			continue
		shard["cd"] = SHARD_HIT_COOLDOWN
		EnemyCombat.apply_damage(handles[0], damage, 1, player)


func _draw() -> void:
	if shards.is_empty():
		return
	var origin := _origin()
	# The orbit is the canonical shard visual, so it takes the noun's identity
	# hue from the registry; the deeper blue glow behind it stays authored.
	var core := ManifestationNouns.colour(&"shard")
	core.a = 0.95
	var glow := Color(0.25, 0.70, 1.0, 0.40)
	for shard in shards:
		var angle := float(shard.get("angle", 0.0)) + _shard_spin
		var radius := float(shard.get("radius", SHARD_ORBIT_RADIUS))
		var pos := origin + Vector2(cos(angle), sin(angle)) * radius - global_position
		var spark := 0.85 + 0.15 * sin(float(shard.get("age", 0.0)) * 9.0)
		draw_circle(pos, 9.0 * spark, Color(glow.r, glow.g, glow.b, glow.a))
		var facing := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5))
		var side := Vector2(-facing.y, facing.x)
		draw_colored_polygon(PackedVector2Array([
			pos + facing * 7.5,
			pos + side * 3.6,
			pos - facing * 7.5,
			pos - side * 3.6,
		]), Color(core.r, core.g, core.b, core.a * spark))
