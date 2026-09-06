extends Node

# Audit 2026-08-28 (test coverage gaps), Top-15 gap #3 / HIGH rows for
# core/systems/manifestations/ManifestationPairEffect.gd and all ten
# effects/manifestations/pairs/*.gd: ~2,100 lines of stat and damage rules
# "never constructed in a headless test; only display probes call grant_pair".
#
# This drives every pair the way ManifestationRunner does - def.logic.new(),
# add_child, setup_pair(player, state, def, mean_rarity) - against a real
# ManifestationState with its nouns claimed, and asserts the rule's OUTCOME:
# resources moved, HP and Followers moved, guards spent, ledger contributions
# published, signals emitted. Each pair also gets at least one edge: a re-arm
# window, a cap, or a threshold boundary.
#
# Deliberately NOT asserted anywhere: redraw or process frequency, frame
# counts, and the wording of describe() (ManifestationSystemTest's
# _test_rule_text_matches_the_code owns the text). Every pair is ticked by
# hand with a known delta, so nothing here depends on how often a node
# repaints or how a frame is scheduled.
#
# The last three sections pin the LIFECYCLE through the real runner, driven
# from a real Inventory: the 2+2 distinct-rule threshold that lights a pair,
# the release that puts it out, three lit nouns lighting all three of their
# pairs, and the doubled-rule case - one rule on two items counts once, so no
# pair lights, which is what the Run Sheet's box collapse depends on.
#
# Run: <godot> --headless --path . res://tools/tests/ManifestationPairBehaviourTest.tscn

var _passes := 0
var _failures := 0

# --- Global state this suite mutates, saved in _run and handed back at the end
var _saved_inventory: Inventory = null
var _saved_followers: int = 0
var _saved_segment: int = 1
var _saved_deaths: int = 0
var _saved_autosave_disabled: bool = false
var _saved_feedback: Dictionary = {}


## The minimum a pair reads off the player: a health bar, its signal, a weapon
## damage base, and the stat-pass entry point Debt Collector asks for. Same
## shape as ManifestationSystemTest.FakePlayer, plus what the pairs need.
class FakePlayer extends Node2D:
	@warning_ignore("unused_signal")
	signal hp_changed(current: float, max_hp: float)
	var hp: float = 100.0
	var max_hp: float = 100.0
	var base_weapon_damage: float = 12.0
	var hp_change_events: int = 0
	var refresh_requests: int = 0

	func _init() -> void:
		hp_changed.connect(_note_hp_changed)

	func _note_hp_changed(_current: float, _max_hp: float) -> void:
		hp_change_events += 1

	func refresh_run_state() -> void:
		refresh_requests += 1


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_save_global_state()

	_test_catalog_matrix_and_threshold()
	_test_pair_effect_base_contract()

	_test_slipstream_foundry()
	_test_marching_order()
	_test_red_line()
	_test_pilgrims_toll()
	_test_loom()
	_test_reliquary_guard()
	_test_bad_fortune_engine()
	_test_death_rattle()
	_test_tithe_rhythm()
	_test_debt_collector()

	_test_runner_lights_and_drops_a_pair()
	_test_runner_counts_distinct_rules_not_instances()
	_test_runner_lights_every_pair_of_three_lit_nouns()

	_restore_global_state()
	print("ManifestationPairBehaviourTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# Global state
# ---------------------------------------------------------------------------

func _save_global_state() -> void:
	_saved_inventory = Global.run_inventory
	_saved_followers = Global.followers
	_saved_segment = Global.attempt_segment
	_saved_deaths = Global.attempt_deaths_this_segment
	_saved_autosave_disabled = Global.debug_disable_autosave
	# Two pairs spend and refund Followers through Global.transaction_followers,
	# which marks the profile dirty. This suite must never write a real save.
	Global.debug_disable_autosave = true
	# Both callout channels on, unpersisted: this machine's saved settings must
	# not decide whether a pair's line exists.
	_saved_feedback = {
		&"damage_numbers": SettingsManager.get_value(&"accessibility", &"damage_numbers", true),
		&"ability_callouts": SettingsManager.get_value(&"accessibility", &"ability_callouts", true),
	}
	for key in _saved_feedback:
		SettingsManager.set_value(&"accessibility", key, true, false)


func _restore_global_state() -> void:
	_battle_text_reset()
	Global.run_inventory = _saved_inventory
	Global.followers = _saved_followers
	Global.attempt_segment = _saved_segment
	Global.attempt_deaths_this_segment = _saved_deaths
	Global.debug_disable_autosave = _saved_autosave_disabled
	for key in _saved_feedback:
		SettingsManager.set_value(&"accessibility", key, _saved_feedback[key], false)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _make_player(hp: float = 100.0, max_hp: float = 100.0) -> FakePlayer:
	var fake := FakePlayer.new()
	fake.hp = hp
	fake.max_hp = max_hp
	add_child(fake)
	return fake


## A shared state with the given nouns claimed and its own tick OFF: every case
## sets the telemetry it needs (odometer, clocks, the Mark) by hand, and the
## state's decay/movement pass would move those underneath the assertions.
func _make_state(fake: FakePlayer, nouns: Array) -> ManifestationState:
	var state := ManifestationState.new()
	add_child(state)
	state.bind_player(fake)
	state.set_process(false)
	for noun in nouns:
		state.claim(noun)
	return state


## Exactly ManifestationRunner._sync_pairs(): add_child first, then setup_pair
## with the mean contributor rarity. Process is switched off afterwards because
## _on_manifestation_ready() turns it on; every case ticks with a known delta.
func _make_pair(
	id: StringName,
	fake: FakePlayer,
	state: ManifestationState,
	mean_rarity: float = 0.0
) -> ManifestationPairEffect:
	var def := ManifestationPairCatalog.get_def(id)
	if def == null or def.logic == null:
		return null
	var node: Node = def.logic.new()
	var pair := node as ManifestationPairEffect
	if pair == null:
		node.free()
		return null
	pair.name = String(def.id)
	add_child(pair)
	pair.setup_pair(fake, state, def, mean_rarity)
	pair.set_process(false)
	return pair


## One tick of a known length. The pairs run their own timers (surge, guard,
## re-arm, forge, drain), so the deltas are the test's, never the frame's.
func _tick(node: Node, delta: float) -> void:
	if node != null and is_instance_valid(node):
		node.call(&"_process", delta)


## Removes and frees synchronously, so _exit_tree runs where the test expects
## it (Slipstream hands its held shards back, Reliquary Guard and Debt
## Collector clear their ledger entries) and nothing is left in the tree.
func _drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()


func _teardown(pairs: Array, state: ManifestationState, fake: FakePlayer) -> void:
	for pair in pairs:
		_drop(pair as Node)
	_drop(state)
	_drop(fake)


# ---------------------------------------------------------------------------
# BattleText
#
# Every line a pair says goes through the BattleText ring buffer; its entries
# are read back here the way a Label's text is. Reset between cases so "the
# newest RED LINE" is unambiguous - nothing expires between two synchronous
# calls, so an earlier case's line would otherwise still be in the buffer.
# ---------------------------------------------------------------------------

func _battle_text_reset() -> void:
	if BattleText == null:
		return
	BattleText.set("_count", 0)
	BattleText.set("_overwrite_slot", 0)


func _battle_text_index(text: String) -> int:
	if BattleText == null:
		return -1
	var texts: PackedStringArray = BattleText.get("_texts")
	for i in range(int(BattleText.get("_count"))):
		if texts[i] == text:
			return i
	return -1


func _battle_text_has(text: String) -> bool:
	return _battle_text_index(text) >= 0


func _battle_text_colour(text: String) -> Color:
	var index := _battle_text_index(text)
	if index < 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var colours: PackedColorArray = BattleText.get("_colors")
	return colours[index]


# ---------------------------------------------------------------------------
# Items, for the runner sections
# ---------------------------------------------------------------------------

func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


## roll_manifestation=false: fixtures must not consume Global RNG state, and
## the rule is assigned by hand so the loadout is exactly what the case needs.
func _make_item(slot: int, manifestation: StringName, rarity: int) -> ItemInstance:
	var inst := ItemInstance.from_roll(
		_make_data("pairfix_%s_%d" % [String(manifestation), slot], slot),
		rarity,
		ItemInstance.Polarity.POS,
		0.5,
		false
	)
	inst.manifestation_id = manifestation
	return inst


func _pair_ids(runner: ManifestationRunner) -> Array:
	var out: Array = []
	for entry in runner.get_active_pairs():
		out.append(String((entry as Dictionary).get("id", "")))
	out.sort()
	return out


# ---------------------------------------------------------------------------
# The matrix and its one threshold
# ---------------------------------------------------------------------------

func _test_catalog_matrix_and_threshold() -> void:
	var nouns: Array = ManifestationState.NOUNS.keys()
	_check(nouns.size() == 5, "fixture: the noun vocabulary is five (%d)" % nouns.size())

	var ids: Array = ManifestationPairCatalog.all_ids()
	_check(ids.size() == 10, "the pair matrix is complete: C(5,2) = 10 authored pairs (%d)" % ids.size())

	# Every unordered noun pair has exactly one def, reachable from either side.
	var complete := true
	var symmetric := true
	var covered: Dictionary = {}
	for i in range(nouns.size()):
		for j in range(i + 1, nouns.size()):
			var a: StringName = nouns[i]
			var b: StringName = nouns[j]
			var def := ManifestationPairCatalog.for_nouns(a, b)
			if def == null or def.logic == null:
				complete = false
				continue
			if ManifestationPairCatalog.for_nouns(b, a) != def:
				symmetric = false
			covered[def.id] = true
	_check(complete, "every noun combination resolves to a def with logic behind it")
	_check(symmetric, "and the lookup is order-independent")
	_check(covered.size() == 10, "the ten combinations reach ten distinct pairs (%d)" % covered.size())

	# The threshold, both sides of it.
	_check(ManifestationPairCatalog.NOUN_THRESHOLD == 2, "the threshold is two distinct rules per noun")
	_check(
		ManifestationPairCatalog.active_for_counts({&"momentum": 1, &"shard": 2}).is_empty(),
		"one rule of a noun lights nothing, however many the other noun has"
	)
	var lit_one := ManifestationPairCatalog.active_for_counts({&"momentum": 2, &"shard": 2})
	_check(
		lit_one.size() == 1 and lit_one[0].id == &"slipstream_foundry",
		"two and two light exactly their own pair (%d lit)" % lit_one.size()
	)
	var lit_three := ManifestationPairCatalog.active_for_counts({&"momentum": 2, &"shard": 2, &"cadence": 2})
	var lit_ids: Array = []
	for def in lit_three:
		lit_ids.append(String(def.id))
	lit_ids.sort()
	_check(
		lit_ids == ["loom", "marching_order", "slipstream_foundry"],
		"three lit nouns light all three of their pairs (%s)" % [lit_ids]
	)
	var lit_all := ManifestationPairCatalog.active_for_counts({
		&"momentum": 2, &"shard": 2, &"cadence": 2, &"fortune": 2, &"ward": 2,
	})
	_check(lit_all.size() == 10, "five lit nouns light the whole matrix (%d)" % lit_all.size())


func _test_pair_effect_base_contract() -> void:
	# ManifestationPairEffect: no slot, no item, so identity and scaling come
	# from the def and the contributor mean instead.
	var fake := _make_player()
	var state := _make_state(fake, [&"momentum", &"shard"])
	var pair := _make_pair(&"slipstream_foundry", fake, state, 0.0)
	_check(pair != null, "fixture: a pair is constructed the way the runner builds it")

	_check(
		pair.slot_index == Inventory.SLOT_COUNT,
		"a pair is pinned to sort LAST, after every slotted rule (slot_index %d)" % pair.slot_index
	)
	_check(pair.manifestation_id() == &"slipstream_foundry", "its id is the pair def's id")
	_check(
		pair.tags() == ManifestationPairCatalog.get_def(&"slipstream_foundry").nouns,
		"its nouns are the def's nouns (%s)" % [pair.tags()]
	)
	_check(pair.item == null, "it belongs to no item")
	_check(
		pair.contribution_key() == StringName("slipstream_foundry#%d" % Inventory.SLOT_COUNT),
		"and its ledger key is its own (%s)" % pair.contribution_key()
	)

	# Rarity is the contributor mean, handed in and re-levellable in place.
	_check(is_zero_approx(pair.effective_rarity()), "a pair with no ranked contributor scales at rank 0")
	pair.set_contributor_rarity(8.0)
	_check(is_equal_approx(pair.effective_rarity(), 8.0), "set_contributor_rarity re-levels it (%.1f)" % pair.effective_rarity())
	_check(pair.potency() > 1.0, "so potency grows with the contributors (%.3f)" % pair.potency())
	pair.set_contributor_rarity(-5.0)
	_check(is_zero_approx(pair.effective_rarity()), "a negative mean is floored at 0")

	# Detached, with no player and no state - the tooltip path.
	var described := 0
	for id_value in ManifestationPairCatalog.all_ids():
		var text := ManifestationPairCatalog.describe(id_value, 4.0)
		if text.strip_edges() != "":
			described += 1
	_check(described == 10, "all ten render their own rule text on a detached node (%d)" % described)

	_teardown([pair], state, fake)


# ---------------------------------------------------------------------------
# Slipstream Foundry - momentum x shard
# ---------------------------------------------------------------------------

func _test_slipstream_foundry() -> void:
	_battle_text_reset()
	var fake := _make_player()
	var state := _make_state(fake, [&"momentum", &"shard"])
	var pair := _make_pair(&"slipstream_foundry", fake, state, 0.0)
	var stride: float = pair.drop_distance()
	_check(stride > 0.0, "fixture: a stride is %.0f px of unbroken travel" % stride)

	var cap: int = state.shard_cap()
	_check(state.add_shard(cap) == cap, "fixture: the orbit starts full (%d shards)" % state.shard_count())

	# One stride of unbroken travel really removes a shard from the orbit.
	state.is_moving = true
	state.distance_since_stop = stride
	_tick(pair, 0.016)
	_check(
		state.shard_count() == cap - 1,
		"a stride pulls one shard out of the orbit (%d left)" % state.shard_count()
	)

	# Standing still drops nothing, however far the odometer already reads.
	state.is_moving = false
	_tick(pair, 0.016)
	_check(state.shard_count() == cap - 1, "standing still drops nothing")

	# Up to MAX_TRAIL are out at once; the cap holds the stride rather than
	# emptying the halo outright.
	state.is_moving = true
	state.distance_since_stop = stride * 2.0
	_tick(pair, 0.016)
	state.distance_since_stop = stride * 3.0
	_tick(pair, 0.016)
	var at_cap: int = state.shard_count()
	_check(at_cap == cap - 3, "three strides put three shards on the ground (%d left in orbit)" % at_cap)
	state.distance_since_stop = stride * 4.0
	_tick(pair, 0.016)
	_check(
		state.shard_count() == at_cap,
		"at the trail cap a further stride takes nothing more (%d left)" % state.shard_count()
	)

	# Held shards snap back after the hold, and the stride banked at the cap is
	# still there - the next drop follows as soon as a slot frees rather than a
	# full stride later.
	_tick(pair, 1.30)
	_check(
		state.shard_count() == cap,
		"every held shard snaps back into orbit after the hold (%d)" % state.shard_count()
	)
	state.distance_since_stop = stride * 4.0 + 1.0
	_tick(pair, 0.016)
	_check(
		state.shard_count() == cap - 1,
		"and the stride held at the cap pays out on the next pixel travelled (%d)" % state.shard_count()
	)

	# A shard on the ground is genuinely out of the orbit, so every consumer
	# sees the smaller number - Reliquary Guard's bar, Loom's volley.
	_check(
		state.shard_count() < cap and not state.shards_full(),
		"a grounded shard leaves the orbit short for every other rule"
	)

	# Losing the pair mid-stride hands the held shards back rather than
	# confiscating them.
	var held_before: int = state.shard_count()
	_drop(pair)
	_check(
		state.shard_count() == held_before + 1,
		"unequipping hands the held shards back to the orbit (%d -> %d)" % [held_before, state.shard_count()]
	)

	_teardown([], state, fake)


# ---------------------------------------------------------------------------
# Marching Order - momentum x cadence
# ---------------------------------------------------------------------------

func _test_marching_order() -> void:
	_battle_text_reset()
	var fake := _make_player()
	var state := _make_state(fake, [&"momentum", &"cadence"])
	var pair := _make_pair(&"marching_order", fake, state, 0.0)
	var stride: float = pair.stride_distance()
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"marching_order").logic.get_script_constant_map()
	var max_per_frame: int = int(consts["MAX_BEATS_PER_FRAME"])
	var forfeit_after: float = float(consts["FORFEIT_AFTER"])

	# The rhythm clock is set to a value only note_attack() would move.
	state.time_since_attack = 5.0
	state.last_attack_gap = 5.0
	var beats: Array = []
	state.resource_spent.connect(func(noun: StringName, amount: float) -> void:
		if noun == &"cadence":
			beats.append(amount))

	state.is_moving = true
	state.still_time = 0.0
	state.distance_since_stop = stride
	_tick(pair, 0.016)
	_check(state.attack_index == 1, "a stride writes one beat into the shared counter (%d)" % state.attack_index)
	_check(beats.size() == 1, "and the noun announces the beat it spent (%d)" % beats.size())

	# THE distinction: advance_beat(), never note_attack(). A walked beat must
	# not reset the rhythm clock, or Stored Violence never charges and Fever
	# Litany is pinned at max for free.
	_check(
		is_equal_approx(state.time_since_attack, 5.0),
		"a walked stride leaves the attack clock alone (%.2fs)" % state.time_since_attack
	)
	_check(is_equal_approx(state.last_attack_gap, 5.0), "and does not rewrite the last attack gap")

	# Beat-counting rules move; clock-reading rules do not.
	_check(state.beat_in_cycle(3) == 1, "the shared beat-of-3 advanced with the stride")

	# Bounded: a hitch that crosses many strides pays at most MAX_BEATS_PER_FRAME.
	var before: int = state.attack_index
	state.distance_since_stop = stride * 12.0
	_tick(pair, 0.016)
	_check(
		state.attack_index - before == max_per_frame,
		"a hitch across ten strides pays at most %d beats in one frame (%d)" % [max_per_frame, state.attack_index - before]
	)

	# Stopping FORFEITS the part-stride instead of cashing it early. Start from a
	# forfeited gauge so the part-stride under test is the only thing banked.
	state.still_time = forfeit_after
	_tick(pair, 0.016)
	var settled: int = state.attack_index
	var base: float = state.distance_since_stop

	state.still_time = 0.0
	state.is_moving = true
	state.distance_since_stop = base + stride * 0.5
	_tick(pair, 0.016)
	_check(state.attack_index == settled, "half a stride is not a beat")

	var stopped_at: float = state.distance_since_stop
	state.still_time = forfeit_after
	_tick(pair, 0.016)
	_check(state.attack_index == settled, "and stopping does not fire it early")

	state.still_time = 0.0
	state.is_moving = true
	state.distance_since_stop = stopped_at + stride * 0.9
	_tick(pair, 0.016)
	_check(
		state.attack_index == settled,
		"the banked half stride is gone: 0.9 of a stride after the stop still pays nothing"
	)
	state.distance_since_stop = stopped_at + stride
	_tick(pair, 0.016)
	_check(
		state.attack_index == settled + 1,
		"a full stride measured from the stop pays one beat (%d)" % (state.attack_index - settled)
	)

	# An unclaimed cadence noun cannot be walked into existence: dropping the
	# last claimer makes the noun dormant, and a stride does not wake it.
	state.release(&"cadence")
	_check(state.attack_index == 0, "fixture: a noun with no claimer resets (%d)" % state.attack_index)
	state.distance_since_stop += stride * 2.0
	_tick(pair, 0.016)
	_check(
		state.attack_index == 0,
		"with no cadence claimer a stride advances nothing (%d)" % state.attack_index
	)

	_teardown([pair], state, fake)


# ---------------------------------------------------------------------------
# Red Line - momentum x ward
# ---------------------------------------------------------------------------

func _test_red_line() -> void:
	_battle_text_reset()
	var fake := _make_player(30.0, 100.0)
	var state := _make_state(fake, [&"momentum", &"ward"])
	var pair := _make_pair(&"red_line", fake, state, 0.0)
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"red_line").logic.get_script_constant_map()
	var min_spend: float = float(consts["MIN_SPEND"])
	var rearm: float = float(consts["REARM_COOLDOWN"])
	var guard_time: float = float(consts["GUARD_TIME"])
	var power_during: float = float(consts["POWER_DURING_SURGE"])

	_check(state.wound_tier() >= 2, "fixture: 30%% HP is wounded (tier %d)" % state.wound_tier())
	_check(
		is_equal_approx(pair.get_move_speed_multiplier(), 1.0)
		and is_equal_approx(pair.get_power_multiplier(), 1.0)
		and is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"a dormant Red Line changes nothing"
	)

	# A full Momentum spend while wounded: surge, weapon cost, and the guard.
	state.add_momentum(1.0)
	_check(is_equal_approx(state.momentum, 1.0), "fixture: the pool is full")
	var spent: float = state.consume_momentum()
	_check(is_equal_approx(spent, 1.0), "fixture: the whole pool was spent")

	var peak: float = pair.get_move_speed_multiplier()
	_check(peak > 1.0, "spending Momentum wounded pays out speed (x%.3f)" % peak)
	_check(
		is_equal_approx(peak, 1.0 + pair.speed_bonus()),
		"the surge starts at its full value (%.3f vs %.3f)" % [peak, 1.0 + pair.speed_bonus()]
	)
	_check(
		is_equal_approx(pair.get_power_multiplier(), power_during),
		"and charges the weapon for it (%.2f)" % pair.get_power_multiplier()
	)
	_check(is_zero_approx(pair.get_damage_taken_multiplier()), "the guard makes the next hit free")
	_check(_battle_text_has("RED LINE"), "the payout announces itself")
	_check(
		_battle_text_colour("RED LINE").is_equal_approx(ManifestationNouns.colour(&"ward")),
		"in the ward colour, which is what says the guard is armed"
	)

	# The surge decays across its window rather than being a flat stat.
	_tick(pair, 0.60)
	var decayed: float = pair.get_move_speed_multiplier()
	_check(decayed > 1.0 and decayed < peak, "the surge decays across the window (x%.3f)" % decayed)

	# One hit, one guard: it is spent by the hit that landed, not by a timer.
	pair.on_damage_taken(9.0, Vector2.ZERO)
	_check(
		is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"the ignored hit spends the guard, exactly one hit's worth"
	)
	_check(_battle_text_has("SHRUGGED"), "and the eaten hit says so")

	# THE RE-ARM WINDOW. A second spend inside it buys the surge alone - the
	# popup colour is the only tell, so it is pinned.
	_battle_text_reset()
	state.add_momentum(1.0)
	state.consume_momentum()
	_check(
		is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"a spend inside the re-arm window arms no second guard"
	)
	_check(pair.get_move_speed_multiplier() > 1.0, "but still pays the surge")
	_check(
		_battle_text_colour("RED LINE").is_equal_approx(ManifestationNouns.colour(&"momentum")),
		"and says so in the momentum colour instead of the ward one"
	)

	# Past the cooldown the guard is available again.
	_tick(pair, rearm + 0.01)
	state.add_momentum(1.0)
	state.consume_momentum()
	_check(
		is_zero_approx(pair.get_damage_taken_multiplier()),
		"once %.0fs has passed the guard re-arms" % rearm
	)

	# An unspent guard expires quietly.
	_tick(pair, guard_time + 0.01)
	_check(
		is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"an unspent guard expires after %.0fs" % guard_time
	)
	_check(is_equal_approx(pair.get_power_multiplier(), 1.0), "and the weapon cost ends with the surge")

	# THRESHOLD: a dribble of Momentum buys nothing at all.
	_tick(pair, rearm + 0.01)
	state.add_momentum(min_spend - 0.05)
	state.consume_momentum()
	_check(
		is_equal_approx(pair.get_move_speed_multiplier(), 1.0)
		and is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"a spend under %d%% Momentum buys nothing" % int(round(min_spend * 100.0))
	)
	state.add_momentum(min_spend)
	state.consume_momentum()
	_check(
		pair.get_move_speed_multiplier() > 1.0 and is_zero_approx(pair.get_damage_taken_multiplier()),
		"a spend at exactly %d%% pays" % int(round(min_spend * 100.0))
	)

	# Another noun's spend is not Red Line's business.
	_tick(pair, rearm + 10.0)
	state.claim(&"cadence")
	state.advance_beat()
	_check(
		is_equal_approx(pair.get_move_speed_multiplier(), 1.0)
		and is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"a cadence spend does not trip a momentum pair"
	)
	state.release(&"cadence")

	# Healthy, it is inert however much is spent.
	fake.hp = 100.0
	_check(state.wound_tier() < 2, "fixture: full HP is not wounded")
	state.add_momentum(1.0)
	state.consume_momentum()
	_check(
		is_equal_approx(pair.get_move_speed_multiplier(), 1.0)
		and is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"a healthy player spending the whole pool gets nothing from this pair"
	)

	_teardown([pair], state, fake)


# ---------------------------------------------------------------------------
# Pilgrim's Toll - fortune x momentum
# ---------------------------------------------------------------------------

func _test_pilgrims_toll() -> void:
	_battle_text_reset()
	var fake := _make_player()
	# Deliberately NOT claiming shard: the toll claims it itself, only while its
	# own Mark is live, so a run with no shard rule never grows an empty orbit.
	var state := _make_state(fake, [&"fortune", &"momentum"])
	var pair := _make_pair(&"pilgrims_toll", fake, state, 0.0)
	var distance: float = pair.toll_distance()
	var duration: float = pair.mark_duration()
	_check(not state.has_source(&"shard"), "fixture: nothing in this loadout claims the shard noun")

	# Short of the distance the toll is not armed, and a hit Marks nothing.
	state.is_moving = true
	state.distance_since_stop = distance - 0.1
	_tick(pair, 0.016)
	pair.on_hit(4242, Vector2.ZERO, 5.0, false, false)
	_check(state.marked_handle == 0, "one pixel short of the run, a hit Marks nothing")
	_check(not state.has_source(&"shard"), "and no shard noun is claimed for a Mark that never happened")

	# The distance arms it.
	state.distance_since_stop = distance
	_tick(pair, 0.016)
	_check(_battle_text_has("TOLL DUE"), "the full run arms the toll")

	pair.on_hit(4242, Vector2.ZERO, 5.0, false, false)
	_check(state.is_marked(4242), "and the next enemy hit is Marked outright")
	_check(
		is_equal_approx(state.mark_time_left, duration),
		"for the toll's own duration (%.1fs)" % state.mark_time_left
	)
	_check(state.has_source(&"shard"), "the Mark's noun is claimed only while the Mark is live")
	_check(_battle_text_has("TOLL PAID"), "and the collection says so")

	# Paid: the next toll needs the distance again.
	pair.on_hit(777, Vector2.ZERO, 5.0, false, false)
	_check(state.marked_handle == 4242, "a spent toll does not Mark the next thing you touch")

	# The transient claim is handed back the instant the Mark ends.
	state.clear_mark()
	_tick(pair, 0.016)
	_check(
		not state.has_source(&"shard"),
		"the shard claim is released the instant the Mark ends"
	)

	# A LIVE MARK IS NEVER STOLEN. Predestination Sigil spends a hit on an elite
	# to place one; yanking it onto whatever the player clipped next would make
	# this pair worse than not owning it.
	_battle_text_reset()
	state.distance_since_stop = distance * 2.0
	_tick(pair, 0.016)
	_check(_battle_text_has("TOLL DUE"), "fixture: the toll is armed again")
	state.claim(&"shard")
	state.set_mark(999, 5.0)
	_check(state.is_marked(999), "fixture: another rule owns the Mark")
	pair.on_hit(4242, Vector2.ZERO, 5.0, false, false)
	_check(state.marked_handle == 999, "an armed toll never steals a live Mark")
	_check(not _battle_text_has("TOLL PAID"), "and does not report a collection it refused")

	# It stays armed and collects the moment the other Mark ends.
	state.clear_mark()
	state.release(&"shard")
	pair.on_hit(4242, Vector2.ZERO, 5.0, false, false)
	_check(state.is_marked(4242), "the refused toll is still armed and collects afterwards")
	state.clear_mark()
	_tick(pair, 0.016)

	# An ARMED toll survives stopping. It was earned by running, and you have to
	# stop to fight anything with it.
	_battle_text_reset()
	state.distance_since_stop = distance * 3.0
	_tick(pair, 0.016)
	_check(_battle_text_has("TOLL DUE"), "fixture: armed once more")
	state.is_moving = false
	state.distance_since_stop = 0.0
	_tick(pair, 0.016)
	pair.on_hit(555, Vector2.ZERO, 5.0, false, false)
	_check(state.is_marked(555), "an armed toll survives the run breaking and still collects")

	state.clear_mark()
	_tick(pair, 0.016)
	_drop(pair)
	_check(not state.has_source(&"shard"), "unequipping leaves no orphaned shard claim behind")

	_teardown([], state, fake)


# ---------------------------------------------------------------------------
# Loom - cadence x shard
# ---------------------------------------------------------------------------

func _shard_projectiles() -> Array:
	var out: Array = []
	var host: Node = get_tree().current_scene
	if host == null:
		return out
	for child in host.get_children():
		if child is ManifestationShardProjectile:
			out.append(child)
	return out


func _clear_shard_projectiles() -> void:
	for shard in _shard_projectiles():
		_drop(shard as Node)


func _test_loom() -> void:
	_battle_text_reset()
	_clear_shard_projectiles()
	_check(get_tree().current_scene != null, "fixture: launched shards have a world to spawn into")

	var fake := _make_player()
	var state := _make_state(fake, [&"cadence", &"shard"])
	var pair := _make_pair(&"loom", fake, state, 0.0)
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"loom").logic.get_script_constant_map()
	var beats: int = int(consts["BEATS"])
	var pierce: int = int(consts["LAUNCH_PIERCE"])

	state.add_shard(3)
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	_check(pair.is_armed(), "the beat before the empowered one, with an orbit, is armed")

	# Off the beat nothing is absorbed and the orbit is untouched.
	state.note_attack()
	_check(not pair.is_armed(), "one beat later it is not")
	_check(
		is_equal_approx(pair.absorb_attack_bonus(1.7), 1.0),
		"off the woven beat the shot keeps everything that empowered it"
	)
	_check(state.shard_count() == 3, "and the orbit is untouched")

	# On the beat: the weapon damage is suppressed and the whole orbit leaves.
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	var absorbed: float = pair.absorb_attack_bonus(1.0)
	_check(is_zero_approx(absorbed), "the woven beat deals no weapon damage of its own (x%.2f)" % absorbed)
	_check(state.shard_count() == 0, "and fires the whole orbit")
	_check(_battle_text_has("LOOM x3"), "announced with the count it was worth")

	var volley: Array = _shard_projectiles()
	_check(volley.size() == 3, "one projectile per shard left the orbit (%d)" % volley.size())
	var base_damage: float = 0.0
	var all_pierce := true
	for shard in volley:
		base_damage = float((shard as ManifestationShardProjectile).damage)
		if int((shard as ManifestationShardProjectile).max_hits) != pierce:
			all_pierce = false
	_check(all_pierce, "each one pierces %d" % pierce)
	_check(
		is_equal_approx(base_damage, state.scaled_attack_damage(pair.launch_damage_mult())),
		"at the pair's launch damage (%.1f)" % base_damage
	)
	_clear_shard_projectiles()

	# WHAT WAS SPENT TO ARM THE BEAT IS SPENT ON THE VOLLEY, not voided. A
	# Furnace that burned a Follower to empower this beat must not lose it.
	state.add_shard(2)
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	_check(is_zero_approx(pair.absorb_attack_bonus(2.5)), "a carried payout still suppresses the weapon")
	var carried: Array = _shard_projectiles()
	_check(carried.size() == 2, "fixture: two shards left the orbit (%d)" % carried.size())
	var carried_damage: float = float((carried[0] as ManifestationShardProjectile).damage) if not carried.is_empty() else 0.0
	_check(
		is_equal_approx(carried_damage, base_damage * 2.5),
		"and the volley carries the x2.5 that empowered it (%.1f vs %.1f)" % [carried_damage, base_damage * 2.5]
	)
	_clear_shard_projectiles()

	# A carried value below 1 cannot shrink the volley below its own damage.
	state.add_shard(1)
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	pair.absorb_attack_bonus(0.25)
	var floored: Array = _shard_projectiles()
	_check(
		not floored.is_empty()
		and is_equal_approx(float((floored[0] as ManifestationShardProjectile).damage), base_damage),
		"a carried multiplier below 1 is floored rather than shrinking the volley"
	)
	_clear_shard_projectiles()

	# EMPTY ORBIT: the beat fires as normal instead of being spent on nothing.
	_check(state.shard_count() == 0, "fixture: the orbit is empty")
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	_check(not pair.is_armed(), "an empty orbit is not armed")
	_check(
		is_equal_approx(pair.absorb_attack_bonus(1.9), 1.0),
		"and the empowered beat fires as a normal shot, keeping what empowered it"
	)
	_check(_shard_projectiles().is_empty(), "with nothing launched")

	_clear_shard_projectiles()
	_teardown([pair], state, fake)


# ---------------------------------------------------------------------------
# Reliquary Guard - shard x ward
# ---------------------------------------------------------------------------

func _test_reliquary_guard() -> void:
	_battle_text_reset()
	var fake := _make_player()
	var state := _make_state(fake, [&"shard", &"ward"])
	var base_cap: int = state.shard_cap()
	var pair := _make_pair(&"reliquary_guard", fake, state, 0.0)
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"reliquary_guard").logic.get_script_constant_map()
	var latch_timeout: float = float(consts["LATCH_TIMEOUT"])

	# The guard makes the orbit worth more, so it makes it bigger - through the
	# shared ledger, keyed by the pair, so ranking a contributor re-levels it.
	_check(
		state.shard_cap() == base_cap + pair.cap_bonus(),
		"the guard raises the shared orbit cap by %d (%d -> %d)" % [pair.cap_bonus(), base_cap, state.shard_cap()]
	)
	var small_bonus: int = pair.cap_bonus()
	pair.set_contributor_rarity(9.0)
	_check(pair.cap_bonus() > small_bonus, "a ranked contributor buys more slots (%d)" % pair.cap_bonus())
	_check(
		state.shard_cap() == base_cap + pair.cap_bonus(),
		"and the ledger re-levels in place rather than stacking a second entry (%d)" % state.shard_cap()
	)
	pair.set_contributor_rarity(0.0)

	# An empty orbit is an unguarded one.
	_check(state.shard_count() == 0, "fixture: the orbit is empty")
	_check(not pair.is_guarding(), "an empty orbit is an unguarded one")
	_check(is_equal_approx(pair.get_damage_taken_multiplier(), 1.0), "so a hit lands in full")

	# A hit that would land shatters a shard instead and deals nothing.
	state.add_shard(2)
	_check(pair.is_guarding(), "shards in orbit are a guard")
	_check(is_zero_approx(pair.get_damage_taken_multiplier()), "the poll nullifies the hit")
	pair.on_damage_taken(37.0, Vector2.ZERO)
	_check(state.shard_count() == 1, "and the hook spends exactly one shard (%d left)" % state.shard_count())
	_check(_battle_text_has("WARDED"), "every absorb says why the hit did nothing")

	# THE RATE LIMIT: a burst arriving in one instant costs one shard, not the
	# whole reliquary.
	_check(
		is_equal_approx(pair.get_damage_taken_multiplier(), 1.0),
		"the next hit inside the shatter cooldown is NOT nullified"
	)
	pair.on_damage_taken(37.0, Vector2.ZERO)
	_check(state.shard_count() == 1, "and costs no second shard (%d)" % state.shard_count())

	_tick(pair, pair.shatter_cooldown() + 0.01)
	_check(is_zero_approx(pair.get_damage_taken_multiplier()), "past the cooldown the guard is back")
	pair.on_damage_taken(37.0, Vector2.ZERO)
	_check(state.shard_count() == 0, "and spends the last shard (%d)" % state.shard_count())
	_check(not pair.is_guarding(), "an emptied orbit drops the guard")

	# A hit that reached the player by a path that never polled the multiplier
	# is not this guard's to charge for.
	state.add_shard(1)
	_tick(pair, pair.shatter_cooldown() + 0.01)
	pair.on_damage_taken(37.0, Vector2.ZERO)
	_check(
		state.shard_count() == 1,
		"a hit that never polled the guard costs no shard (%d)" % state.shard_count()
	)

	# The latch cannot outlive the hit it was armed for.
	_check(is_zero_approx(pair.get_damage_taken_multiplier()), "fixture: the guard commits")
	_tick(pair, latch_timeout + 0.01)
	pair.on_damage_taken(37.0, Vector2.ZERO)
	_check(
		state.shard_count() == 1,
		"a stale commit is dropped rather than charged to an unrelated hit (%d)" % state.shard_count()
	)

	# Losing the pair shrinks the cap back but never confiscates the halo.
	state.add_shard(state.shard_cap())
	var halo: int = state.shard_count()
	_check(halo > base_cap, "fixture: the orbit is above the unguarded cap (%d)" % halo)
	_drop(pair)
	_check(state.shard_cap() == base_cap, "unequipping shrinks the cap back (%d)" % state.shard_cap())
	_check(
		state.shard_count() == halo,
		"but the shards already earned are left alone (%d)" % state.shard_count()
	)

	_teardown([], state, fake)


# ---------------------------------------------------------------------------
# Bad Fortune Engine - fortune x shard
# ---------------------------------------------------------------------------

func _test_bad_fortune_engine() -> void:
	_battle_text_reset()
	_clear_shard_projectiles()
	var fake := _make_player()
	var state := _make_state(fake, [&"fortune", &"shard"])
	var pair := _make_pair(&"bad_fortune_engine", fake, state, 0.0)
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"bad_fortune_engine").logic.get_script_constant_map()
	var forge_cd: float = float(consts["FORGE_COOLDOWN"])
	var spend_per_crit: int = int(consts["SPEND_PER_CRIT"])

	var withdrawals: Array = []
	state.resource_spent.connect(func(noun: StringName, amount: float) -> void:
		if noun == &"fortune":
			withdrawals.append(amount))

	state.add_misfortune(3)
	pair.on_lucky_crit_failed()
	_check(state.shard_count() == 1, "a missed Luck roll forges a shard (%d)" % state.shard_count())
	_check(state.misfortune == 2, "and withdraws exactly one banked point to pay for it (%d)" % state.misfortune)
	_check(
		withdrawals.size() == 1 and is_equal_approx(withdrawals[0], 1.0),
		"the withdrawal is published on the fortune noun so the HUD can pulse it"
	)

	# THE FORGE COOLDOWN. Lucky Crit chance caps at 8%, so most attacks miss;
	# without this the orbit could never be run dry.
	pair.on_lucky_crit_failed()
	_check(
		state.shard_count() == 1 and state.misfortune == 2,
		"a second miss inside the forge cooldown forges nothing and banks the point"
	)
	_tick(pair, forge_cd + 0.01)
	pair.on_lucky_crit_failed()
	_check(
		state.shard_count() == 2 and state.misfortune == 1,
		"past the cooldown it forges again (%d shards, %d banked)" % [state.shard_count(), state.misfortune]
	)

	# A FULL ORBIT keeps the point banked - one economy's overflow is the
	# other's input rather than being thrown away.
	state.add_shard(state.shard_cap())
	_check(state.shards_full(), "fixture: the orbit is full (%d)" % state.shard_count())
	_tick(pair, forge_cd + 0.01)
	var banked_before: int = state.misfortune
	pair.on_lucky_crit_failed()
	_check(
		state.misfortune == banked_before,
		"a miss at a full orbit banks Misfortune exactly as it always did (%d)" % state.misfortune
	)

	# The consumer half. Two shards per success, clamped to what is in orbit.
	_battle_text_reset()
	var full: int = state.shard_count()
	pair.on_lucky_crit(Vector2.ZERO)
	_check(
		state.shard_count() == full - spend_per_crit,
		"a Lucky Crit spends %d shards (%d left)" % [spend_per_crit, state.shard_count()]
	)
	_check(_battle_text_has("BAD FORTUNE x%d" % spend_per_crit), "and says how many it fired")
	_check(_shard_projectiles().size() == spend_per_crit, "one projectile per shard spent")
	_clear_shard_projectiles()

	# CLAMP: a crit landing on a single shard fires that one rather than being
	# swallowed.
	state.take_shards()
	state.add_shard(1)
	_battle_text_reset()
	pair.on_lucky_crit(Vector2.ZERO)
	_check(state.shard_count() == 0, "a crit with one shard fires that one (%d left)" % state.shard_count())
	_check(_battle_text_has("BAD FORTUNE x1"), "and reports the one")
	_clear_shard_projectiles()

	# An empty orbit pays nothing at all.
	_battle_text_reset()
	pair.on_lucky_crit(Vector2.ZERO)
	_check(_shard_projectiles().is_empty(), "an empty orbit pays nothing on a Lucky Crit")
	_check(not _battle_text_has("BAD FORTUNE x1"), "and says nothing")

	# With no Misfortune banked the forge still works; it never goes negative.
	state.misfortune = 0
	_tick(pair, forge_cd + 0.01)
	pair.on_lucky_crit_failed()
	_check(
		state.shard_count() == 1 and state.misfortune == 0,
		"with an empty bank the forge still runs and the bank never goes negative (%d)" % state.misfortune
	)

	_clear_shard_projectiles()
	_teardown([pair], state, fake)


# ---------------------------------------------------------------------------
# Death Rattle - cadence x ward
# ---------------------------------------------------------------------------

func _arm_rattle(state: ManifestationState, pair: ManifestationPairEffect, beats: int) -> void:
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	state.time_since_attack = 0.0
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)


## Steps the rattle AND the shared clock together. The state's _process is off
## in this suite, but in the game time_since_attack advances every frame -
## and the restore resolves against the clock as it stands, so a frozen clock
## would make "hand the true value back" read as the held value instead.
func _tick_rattle(pair: ManifestationPairEffect, state: ManifestationState, seconds: float) -> void:
	var step := 0.01
	var left := seconds
	while left > 0.0:
		var dt := minf(step, left)
		state.time_since_attack += dt
		_tick(pair, dt)
		left -= dt


## Waits out any standing hold, which releases it and hands the shared clock
## back. Each case below starts from "no beat is being carried", so a hold left
## armed by the previous case can never be the thing that pays.
func _release_rattle_hold(pair: ManifestationPairEffect, resolve: float) -> void:
	_tick_rattle(pair, pair.state, resolve + 1.0)


func _test_death_rattle() -> void:
	_battle_text_reset()
	var fake := _make_player(30.0, 100.0)
	var state := _make_state(fake, [&"cadence", &"ward"])
	var pair := _make_pair(&"death_rattle", fake, state, 0.0)
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"death_rattle").logic.get_script_constant_map()
	var beats: int = int(consts["BEATS"])
	var resolve: float = float(consts["RESOLVE_WINDOW"])
	var held: float = float(consts["HELD_SECONDS"])
	var min_after: float = float(consts["MIN_HP_AFTER"])
	var cost: float = pair.hold_cost()

	_check(state.wound_tier() >= 2, "fixture: 30%% HP is wounded (tier %d)" % state.wound_tier())
	_check(cost > 0.0, "fixture: a held beat costs %.1f HP" % cost)

	# THE MECHANISM: the shared clock is held open across the empowered beat,
	# so every cadence rule reading it sees a beat that resolved.
	_arm_rattle(state, pair, beats)
	_check(
		is_equal_approx(state.time_since_attack, held),
		"the empowered beat is held open on the shared clock (%.2fs)" % state.time_since_attack
	)
	_check(state.time_since_attack >= resolve, "which is at or past what a cadence rule calls resolved")

	# Panic-firing into the hold is what bills for it.
	var hp_before: float = fake.hp
	var signals_before: int = fake.hp_change_events
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		is_equal_approx(hp_before - fake.hp, cost),
		"panic-firing into the hold bills %.1f HP (%.1f)" % [cost, hp_before - fake.hp]
	)
	_check(fake.hp_change_events == signals_before + 1, "and the health bar is told once")
	_check(_battle_text_has("RATTLE -%d" % maxi(1, int(round(cost)))), "the toll announces itself")

	# WAITING THE WINDOW OUT COSTS NOTHING, and the borrowed clock is handed
	# back rather than left permanently offset for the rules that read it.
	_arm_rattle(state, pair, beats)
	_check(is_equal_approx(state.time_since_attack, held), "fixture: the next beat is held")
	hp_before = fake.hp
	var waited: float = resolve + 0.20
	_tick_rattle(pair, state, waited)
	_check(
		is_equal_approx(state.time_since_attack, waited),
		"once the real gap outruns the window the TRUE clock is handed back, not the held one (%.2fs)"
		% state.time_since_attack
	)
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		is_equal_approx(fake.hp, hp_before),
		"and a beat the player waited out costs nothing (%.1f)" % fake.hp
	)

	# ONE SHARED CLOCK, BEST RESULT WINS (ruling 2026-09-06). An echo another
	# rule fires while the hold stands - Martyr Circuit's lands 0.09 s after the
	# shot, inside this window - resets the shared clock without the rattle
	# seeing an attack. Handing the rattle's stale gap back used to overwrite
	# that fresher clock; the restore is now a proposal, and the more recent
	# attack wins.
	_release_rattle_hold(pair, resolve)
	_arm_rattle(state, pair, beats)
	_check(is_equal_approx(state.time_since_attack, held), "fixture: the next beat is held again")
	_tick_rattle(pair, state, 0.09)
	state.note_attack() # the echo: the shared clock resets, the rattle's own gap does not
	_check(is_zero_approx(state.time_since_attack), "fixture: the echo reset the shared clock under the hold")
	_tick_rattle(pair, state, resolve + 0.20)
	_check(not bool(pair.get("_hold_armed")), "the hold released once the rattle's gap outran the window")
	_check(
		state.time_since_attack < float(pair.get("_gap")),
		"and handing the clock back keeps the echo's fresher reading, not the rattle's stale gap (%.2fs vs gap %.2fs)"
			% [state.time_since_attack, float(pair.get("_gap"))]
	)

	# ONLY the empowered beat is held. The beats between forfeit as usual, at
	# no cost - the tooltip implies otherwise on a quick read, the code does not.
	_release_rattle_hold(pair, resolve)
	state.note_attack()
	_check(state.beat_in_cycle(beats) != beats - 1, "fixture: this shot is not the one before the empowered beat")
	state.time_since_attack = 0.0
	hp_before = fake.hp
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		is_zero_approx(state.time_since_attack),
		"an ordinary beat is not held open (%.2fs)" % state.time_since_attack
	)
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(is_equal_approx(fake.hp, hp_before), "and panic-firing on it costs nothing")

	# A clock that already reads resolved needs no holding.
	_release_rattle_hold(pair, resolve)
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	state.time_since_attack = held + 0.5
	hp_before = fake.hp
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		is_equal_approx(state.time_since_attack, held + 0.5),
		"an already-resolved clock is left alone (%.2fs)" % state.time_since_attack
	)
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(is_equal_approx(fake.hp, hp_before), "and nothing is billed for a hold that was never placed")

	# Healthy, the rattle is silent.
	_release_rattle_hold(pair, resolve)
	fake.hp = 100.0
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	state.time_since_attack = 0.0
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		is_zero_approx(state.time_since_attack),
		"above the wounded line no beat is held (%.2fs)" % state.time_since_attack
	)

	# IT NEVER TAKES THE LAST POINT. Armed while affordable, then the player is
	# chipped down before they fire into it.
	_release_rattle_hold(pair, resolve)
	fake.hp = 30.0
	_arm_rattle(state, pair, beats)
	_check(is_equal_approx(state.time_since_attack, held), "fixture: the hold is placed while it is affordable")
	fake.hp = min_after + 2.0
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		is_equal_approx(fake.hp, min_after),
		"the toll is clamped down to the last point and no further (%.1f)" % fake.hp
	)
	_check(fake.hp > 0.0, "the player dies to what is chasing them, never to the bill")

	# Too poor to arm at all: refused up front rather than refunded later.
	_release_rattle_hold(pair, resolve)
	fake.hp = min_after + 0.5
	while state.beat_in_cycle(beats) != beats - 1:
		state.note_attack()
	state.time_since_attack = 0.0
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		is_zero_approx(state.time_since_attack),
		"a hold the player cannot afford is never armed (%.2fs)" % state.time_since_attack
	)

	_teardown([pair], state, fake)


# ---------------------------------------------------------------------------
# Tithe Rhythm - cadence x fortune
# ---------------------------------------------------------------------------

func _seek_tithe_beat(state: ManifestationState, beats: int) -> void:
	while state.attack_index <= 0 or state.beat_in_cycle(beats) != 0:
		state.note_attack()


func _test_tithe_rhythm() -> void:
	_battle_text_reset()
	var fake := _make_player()
	var state := _make_state(fake, [&"cadence", &"fortune"])
	var pair := _make_pair(&"tithe_rhythm", fake, state, 0.0)
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"tithe_rhythm").logic.get_script_constant_map()
	var beats: int = int(consts["BEATS"])
	var window: float = float(consts["RETURN_WINDOW"])

	Global.attempt_segment = 1
	Global.attempt_deaths_this_segment = 0
	Global.followers = 200
	var cost: int = int(Global.compute_respawn_cost())
	_check(cost > 0 and Global.followers - 1 >= cost, "fixture: the congregation can afford a tithe (%d, cost %d)" % [Global.followers, cost])

	# attack_index 0 is "no attack counted yet", not the top of a cycle - the
	# failure mode has to be "never fires", never "tithes on every shot".
	_check(state.attack_index == 0, "fixture: the counter has not started")
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(Global.followers == 200, "a stalled counter tithes nothing (%d)" % Global.followers)

	# The empowered beat spends a believer and fires a second time. The echo is
	# a real attack for rhythm purposes, so it advances the shared counter.
	_seek_tithe_beat(state, beats)
	var index_before: int = state.attack_index
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(Global.followers == 199, "the empowered beat spends exactly one Follower (%d)" % Global.followers)
	_check(
		state.attack_index == index_before + 1,
		"and the echo advances the shared beat for every cadence rule (%d -> %d)" % [index_before, state.attack_index]
	)
	_check(_battle_text_has("TITHE - SECOND SHOT"), "the spend announces itself")

	# A kill inside the window buys the believer back.
	pair.call(&"on_kill", null)
	_check(Global.followers == 200, "a kill inside the return window buys them back (%d)" % Global.followers)
	_check(_battle_text_has("BELIEVER RETURNS"), "and says so with its own line")

	# A second kill does not refund twice: one Follower was spent, at most one
	# comes back.
	pair.call(&"on_kill", null)
	_check(Global.followers == 200, "a second kill refunds nothing more (%d)" % Global.followers)

	# The window expiring is what makes the tithe a cost.
	_seek_tithe_beat(state, beats)
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(Global.followers == 199, "fixture: a second tithe is spent (%d)" % Global.followers)
	_tick(pair, window + 0.01)
	pair.call(&"on_kill", null)
	_check(
		Global.followers == 199,
		"a kill after the window closes returns nobody (%d)" % Global.followers
	)

	# BETWEEN BEATS, nothing: only the top of the cycle pays, which is what
	# "every 3rd beat" means to the player. Walked a full cycle past the last
	# tithe before probing, so the elapsed-beats gate below has already reopened
	# and the beat is the only thing left refusing - the two gates shadow each
	# other otherwise, and a probe taken right after the echo would prove
	# neither.
	for _i in range(beats):
		state.note_attack()
	var off_beat_followers: int = Global.followers
	while state.beat_in_cycle(beats) != 0:
		var off_beat: int = state.beat_in_cycle(beats)
		var index_off_beat: int = state.attack_index
		pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
		_check(
			Global.followers == off_beat_followers and state.attack_index == index_off_beat,
			"a shot on beat %d of the cycle tithes nothing and echoes nothing (%d believers, index %d)"
			% [off_beat, Global.followers, state.attack_index]
		)
		state.note_attack()

	# THE REFUSAL IS THE RULE: it will not spend past the reconstruction cost.
	# The cost is read at the moment of the spend and moves with the
	# congregation, so it is re-read here rather than reused from the fixture.
	_battle_text_reset()
	Global.followers = 10
	var floor_cost: int = int(Global.compute_respawn_cost())
	_check(
		Global.followers - 1 < floor_cost,
		"fixture: %d believers is one short of a reconstruction (%d)" % [Global.followers, floor_cost]
	)
	_seek_tithe_beat(state, beats)
	var refusal_index: int = state.attack_index
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		Global.followers == 10,
		"the tithe refuses to drop you below your reconstruction cost (%d)" % Global.followers
	)
	_check(
		state.attack_index == refusal_index,
		"a refused tithe fires no echo (%d)" % state.attack_index
	)
	_check(
		_battle_text_has("TITHE REFUSES (%d TO REBUILD)" % floor_cost),
		"and says what it would have cost to rebuild"
	)

	# THE ELAPSED-BEATS GATE, which is a regression guard and needs its own
	# position to be reached at all. The rule marks the beat it was ASKED on
	# before it tries to spend, and a refused ask fires no echo - so the counter
	# is still sitting on that very beat. A shot from there must tithe nothing
	# even once the congregation can afford it, because the gate counts beats
	# ELAPSED since the last ask, not the beat number; without it the rule pays
	# twice inside one beat, a permanent doubling of attack rate rather than a
	# rhythm. The refused ask is the only way to stand here: every ask the rule
	# accepts sits on a multiple of BEATS, and an ask that pays fires an echo
	# that carries the counter off the beat.
	Global.followers = floor_cost + 1
	_check(
		Global.followers - 1 >= int(Global.compute_respawn_cost()),
		"fixture: one believer above the floor (%d have, %d cost)" % [Global.followers, int(Global.compute_respawn_cost())]
	)
	_check(
		state.attack_index == refusal_index and state.beat_in_cycle(beats) == 0,
		"fixture: the refused ask left the counter on its own beat (%d, beat %d)" % [state.attack_index, state.beat_in_cycle(beats)]
	)
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		Global.followers == floor_cost + 1,
		"an affordable shot on the beat the last ask already marked tithes nothing (%d)" % Global.followers
	)
	_check(
		state.attack_index == refusal_index,
		"and that shot fires no echo either (%d)" % state.attack_index
	)

	# A full cycle later the same congregation pays: the gate counts beats, and
	# these are beats nothing else had to fire to produce.
	for _i in range(beats):
		state.note_attack()
	_check(
		state.attack_index - refusal_index == beats and state.beat_in_cycle(beats) == 0,
		"fixture: a full cycle has elapsed since the marked beat (%d)" % state.attack_index
	)
	pair.call(&"on_attack", &"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(
		Global.followers == floor_cost,
		"one believer above the floor is enough to pay once the cycle comes round (%d)" % Global.followers
	)

	_teardown([pair], state, fake)


# ---------------------------------------------------------------------------
# Debt Collector - fortune x ward
# ---------------------------------------------------------------------------

func _test_debt_collector() -> void:
	_battle_text_reset()
	var consts: Dictionary = ManifestationPairCatalog.get_def(&"debt_collector").logic.get_script_constant_map()
	var luck_while_dying: float = float(consts["LUCK_WHILE_DYING"])
	var grace: float = float(consts["DEBT_GRACE"])
	var window: float = float(consts["DEBT_WINDOW"])
	var floor_share: float = float(consts["DEBT_FLOOR"])

	# The boundary, from both sides. wound_tier() is 3 at or below WOUND_DYING.
	var fake := _make_player(ManifestationState.WOUND_DYING * 100.0 + 1.0, 100.0)
	var state := _make_state(fake, [&"fortune", &"ward"])
	var pair := _make_pair(&"debt_collector", fake, state, 0.0)
	_check(
		is_zero_approx(state.bonus_luck()),
		"one point above the dying line the debt is closed (%.2f Luck)" % state.bonus_luck()
	)

	fake.hp = ManifestationState.WOUND_DYING * 100.0
	_tick(pair, 0.016)
	_check(
		is_equal_approx(state.bonus_luck(), luck_while_dying),
		"at exactly %d%% health the debt opens with its full flood (%.2f)" % [int(round(ManifestationState.WOUND_DYING * 100.0)), state.bonus_luck()]
	)
	_check(_battle_text_has("DEBT OPEN"), "and announces itself")
	_check(fake.refresh_requests > 0, "the stat pass is asked to recompute, which is how the Luck reaches the game")

	# apply_to_stats PUBLISHES ONLY. The runner adds state.bonus_luck() during
	# the same pass, so writing Stats here would double every point.
	var stats := Stats.new()
	var luck_before_pass: float = state.bonus_luck()
	pair.apply_to_stats(stats)
	_check(
		is_zero_approx(stats.luck),
		"the pair writes nothing directly onto Stats (%.2f)" % stats.luck
	)
	_check(
		is_equal_approx(state.bonus_luck(), luck_before_pass),
		"the stat pass republishes the same one ledger entry (%.2f)" % state.bonus_luck()
	)

	# It holds through the grace, then drains. Ticked at a realistic step so the
	# 0.5s republish cadence is the one the pair actually runs at.
	for _i in range(int(grace / 0.1) - 5):
		_tick(pair, 0.1)
	_check(
		is_equal_approx(state.bonus_luck(), luck_while_dying),
		"the flood holds at full through the grace (%.2f)" % state.bonus_luck()
	)
	for _i in range(int((window + 4.0) / 0.1)):
		_tick(pair, 0.1)
	_check(
		is_equal_approx(pair.debt_fraction(), floor_share),
		"and drains to its floor over the window (%.3f)" % pair.debt_fraction()
	)
	_check(
		state.bonus_luck() < luck_while_dying * 0.20,
		"leaving almost nothing on the ledger (%.2f of %.2f)" % [state.bonus_luck(), luck_while_dying]
	)
	_check(_battle_text_has("DEBT CALLED"), "the drained debt says so")

	# Camping does not reopen it; only climbing out does.
	for _i in range(50):
		_tick(pair, 0.1)
	_check(
		is_equal_approx(pair.debt_fraction(), floor_share),
		"sitting under the line keeps paying the floor and no more (%.3f)" % pair.debt_fraction()
	)

	_battle_text_reset()
	fake.hp = 50.0
	_tick(pair, 0.1)
	_check(is_zero_approx(state.bonus_luck()), "climbing out closes the debt (%.2f)" % state.bonus_luck())
	_check(_battle_text_has("DEBT CLOSED"), "and says so")

	fake.hp = 10.0
	_tick(pair, 0.1)
	_check(
		is_equal_approx(state.bonus_luck(), luck_while_dying),
		"falling back in reopens it at full (%.2f)" % state.bonus_luck()
	)

	# THE COLLECTION: every Lucky Crit takes a believer, with no refusal - not
	# even for the reconstruction cost the Tithe rules respect.
	_battle_text_reset()
	Global.attempt_segment = 1
	Global.attempt_deaths_this_segment = 0
	Global.followers = 40
	pair.call(&"on_lucky_crit", Vector2.ZERO)
	_check(Global.followers == 39, "a Lucky Crit collects one Follower (%d)" % Global.followers)
	_check(_battle_text_has("DEBT COLLECTED"), "and the collection is announced")

	Global.followers = 1
	_check(
		int(Global.compute_respawn_cost()) > 1,
		"fixture: one believer is below the reconstruction cost (%d)" % int(Global.compute_respawn_cost())
	)
	pair.call(&"on_lucky_crit", Vector2.ZERO)
	_check(
		Global.followers == 0,
		"the collector takes the last one anyway - it cannot be refused (%d)" % Global.followers
	)

	_battle_text_reset()
	pair.call(&"on_lucky_crit", Vector2.ZERO)
	_check(Global.followers == 0, "an empty congregation is not put into arrears (%d)" % Global.followers)
	_check(not _battle_text_has("DEBT COLLECTED"), "and nothing is announced for a collection that took nothing")

	# Above the line it collects nothing.
	Global.followers = 40
	fake.hp = 90.0
	_tick(pair, 0.1)
	pair.call(&"on_lucky_crit", Vector2.ZERO)
	_check(Global.followers == 40, "a healthy player owes nothing on a Lucky Crit (%d)" % Global.followers)

	# Losing the pair takes its Luck off the shared ledger.
	fake.hp = 10.0
	_tick(pair, 0.1)
	_check(state.bonus_luck() > 0.0, "fixture: the debt is open again")
	_drop(pair)
	_check(is_zero_approx(state.bonus_luck()), "unequipping clears its ledger entry (%.2f)" % state.bonus_luck())

	_teardown([], state, fake)


# ---------------------------------------------------------------------------
# The lifecycle, through the real runner
# ---------------------------------------------------------------------------

## A player with a live ManifestationRunner bound to `inv`, exactly as the
## scene tree wires it: the runner is a child of the player and watches
## Global.run_inventory.
func _make_runner(inv: Inventory) -> ManifestationRunner:
	Global.run_inventory = inv
	var fake := _make_player()
	fake.name = "PairRunnerHost"
	var runner := ManifestationRunner.new()
	runner.name = "ManifestationRunner"
	fake.add_child(runner)
	runner.refresh_effects(inv)
	return runner


func _test_runner_lights_and_drops_a_pair() -> void:
	var inv := Inventory.new()
	# Two DISTINCT momentum rules and two DISTINCT shard rules: the 2+2 that
	# lights exactly one pair. Cadence stays at one claimer and lights nothing.
	inv.set_item(ManifestationCatalog.SLOT_MOVE, _make_item(ManifestationCatalog.SLOT_MOVE, &"sunder_wake", 2))
	inv.set_item(Inventory.SLOT_RING, _make_item(Inventory.SLOT_RING, &"pilgrims_momentum", 4))
	inv.set_item(ManifestationCatalog.SLOT_POWER, _make_item(ManifestationCatalog.SLOT_POWER, &"predestination_sigil", 6))
	var runner := _make_runner(inv)
	var host := runner.get_parent()

	_check(runner.active_count() == 3, "fixture: three rules are equipped (%d)" % runner.active_count())
	var counts: Dictionary = runner.get_noun_counts()
	_check(
		int(counts.get(&"momentum", 0)) == 2 and int(counts.get(&"shard", 0)) == 1,
		"one noun is lit and the other is one short (%s)" % [counts]
	)
	_check(runner.active_pair_count() == 0, "one short of the threshold lights nothing")

	# The fourth item crosses the threshold.
	inv.set_item(Inventory.SLOT_OFFHAND, _make_item(Inventory.SLOT_OFFHAND, &"splinter_dividend", 8))
	runner.refresh_effects(inv)
	_check(runner.active_pair_count() == 1, "the second shard rule lights the pair (%d)" % runner.active_pair_count())
	_check(_pair_ids(runner) == ["slipstream_foundry"], "and it is the pair those two nouns name (%s)" % [_pair_ids(runner)])

	var summary: Dictionary = runner.get_active_pairs()[0]
	_check(String(summary.get("name", "")) == "Slipstream Foundry", "the readout names it (%s)" % summary.get("name", ""))
	_check(
		String(summary.get("rule", "")).strip_edges() != "",
		"and carries the live rule text the Run Sheet renders"
	)

	# The pair claims the nouns it is built from, on top of the rules' claims.
	_check(
		_state_source_count(runner, &"momentum") == 3 and _state_source_count(runner, &"shard") == 3,
		"the live pair claims both its nouns (momentum %d, shard %d)"
		% [_state_source_count(runner, &"momentum"), _state_source_count(runner, &"shard")]
	)

	# Rank is the MEAN of the contributing rules, not the min or the max.
	var expected_mean: float = (2.0 + 4.0 + 6.0 + 8.0) / 4.0
	var live_pair: ManifestationPairEffect = null
	for child in runner.get_children():
		var candidate := child as ManifestationPairEffect
		if candidate != null:
			live_pair = candidate
	_check(live_pair != null, "fixture: the pair node is a child of the runner")
	if live_pair != null:
		_check(
			is_equal_approx(live_pair.effective_rarity(), expected_mean),
			"its rank is the mean of its contributors (%.2f vs %.2f)" % [live_pair.effective_rarity(), expected_mean]
		)
		_check(
			live_pair.slot_index == Inventory.SLOT_COUNT,
			"and it is dispatched after every slotted rule (%d)" % live_pair.slot_index
		)

	# Ranking a contributor re-levels the live pair in place rather than
	# rebuilding it.
	inv.get_at(ManifestationCatalog.SLOT_MOVE).rarity = 10
	runner.refresh_effects(inv)
	var relevelled: float = (10.0 + 4.0 + 6.0 + 8.0) / 4.0
	_check(runner.active_pair_count() == 1, "a rank-up does not churn the pair (%d)" % runner.active_pair_count())
	if live_pair != null and is_instance_valid(live_pair):
		_check(
			is_equal_approx(live_pair.effective_rarity(), relevelled),
			"it re-levels in place (%.2f vs %.2f)" % [live_pair.effective_rarity(), relevelled]
		)

	# Unequipping one contributor puts it out, and hands the noun claims back.
	inv.set_item(Inventory.SLOT_OFFHAND, null)
	runner.refresh_effects(inv)
	_check(runner.active_pair_count() == 0, "dropping below the threshold puts the pair out (%d)" % runner.active_pair_count())
	_check(runner.get_active_pairs().is_empty(), "and it leaves the readout")
	_check(
		_state_source_count(runner, &"momentum") == 2 and _state_source_count(runner, &"shard") == 1,
		"its noun claims are released with it (momentum %d, shard %d)"
		% [_state_source_count(runner, &"momentum"), _state_source_count(runner, &"shard")]
	)

	# Clearing the loadout leaves nothing behind.
	runner.refresh_effects(null)
	_check(
		runner.active_count() == 0 and runner.active_pair_count() == 0,
		"an emptied loadout leaves no rule and no pair alive"
	)

	_drop(host)
	Global.run_inventory = null


func _state_source_count(runner: ManifestationRunner, noun: StringName) -> int:
	return runner.state.source_count(noun) if runner.state != null else -1


func _test_runner_counts_distinct_rules_not_instances() -> void:
	# THE DOUBLED RING. The runner deliberately supports two items carrying one
	# rule; counting instances would let a doubled ring fake every pair of its
	# noun, and the Run Sheet's pair box would light off two copies of one rule.
	var inv := Inventory.new()
	inv.set_item(ManifestationCatalog.SLOT_MOVE, _make_item(ManifestationCatalog.SLOT_MOVE, &"sunder_wake", 3))
	inv.set_item(Inventory.SLOT_RING, _make_item(Inventory.SLOT_RING, &"sunder_wake", 3))
	inv.set_item(ManifestationCatalog.SLOT_POWER, _make_item(ManifestationCatalog.SLOT_POWER, &"predestination_sigil", 3))
	inv.set_item(Inventory.SLOT_OFFHAND, _make_item(Inventory.SLOT_OFFHAND, &"splinter_dividend", 3))
	var runner := _make_runner(inv)
	var host := runner.get_parent()

	_check(runner.active_count() == 4, "fixture: four items, one rule doubled (%d live rules)" % runner.active_count())
	var counts: Dictionary = runner.get_noun_counts()
	_check(
		int(counts.get(&"momentum", 0)) == 1,
		"two items carrying one rule count as ONE claimer of its noun (%d)" % int(counts.get(&"momentum", 0))
	)
	_check(int(counts.get(&"shard", 0)) == 2, "while two distinct shard rules count as two")
	_check(runner.active_pair_count() == 0, "so a doubled rule lights no pair (%d)" % runner.active_pair_count())

	# Swapping the duplicate for a DIFFERENT momentum rule lights it at once.
	inv.set_item(Inventory.SLOT_RING, _make_item(Inventory.SLOT_RING, &"pilgrims_momentum", 3))
	runner.refresh_effects(inv)
	_check(
		runner.active_pair_count() == 1 and _pair_ids(runner) == ["slipstream_foundry"],
		"a second DISTINCT rule of the noun lights it immediately (%s)" % [_pair_ids(runner)]
	)

	_drop(host)
	Global.run_inventory = null


func _test_runner_lights_every_pair_of_three_lit_nouns() -> void:
	var inv := Inventory.new()
	inv.set_item(ManifestationCatalog.SLOT_MOVE, _make_item(ManifestationCatalog.SLOT_MOVE, &"sunder_wake", 1))
	inv.set_item(Inventory.SLOT_RING, _make_item(Inventory.SLOT_RING, &"pilgrims_momentum", 1))
	inv.set_item(ManifestationCatalog.SLOT_POWER, _make_item(ManifestationCatalog.SLOT_POWER, &"predestination_sigil", 1))
	inv.set_item(Inventory.SLOT_OFFHAND, _make_item(Inventory.SLOT_OFFHAND, &"splinter_dividend", 1))
	inv.set_item(ManifestationCatalog.SLOT_HASTE, _make_item(ManifestationCatalog.SLOT_HASTE, &"third_litany", 1))
	var runner := _make_runner(inv)
	var host := runner.get_parent()

	var counts: Dictionary = runner.get_noun_counts()
	_check(
		int(counts.get(&"momentum", 0)) >= 2
		and int(counts.get(&"shard", 0)) >= 2
		and int(counts.get(&"cadence", 0)) >= 2,
		"fixture: three nouns are lit (%s)" % [counts]
	)
	_check(
		_pair_ids(runner) == ["loom", "marching_order", "slipstream_foundry"],
		"three lit nouns light all three of their pairs, no more (%s)" % [_pair_ids(runner)]
	)
	_check(runner.active_pair_count() == 3, "and the count agrees (%d)" % runner.active_pair_count())

	# A lit pair claims nouns, but pairs never light further pairs - the noun
	# count is read off the equipped RULES alone, or the matrix feeds itself.
	_check(
		int(runner.get_noun_counts().get(&"ward", 0)) == 0,
		"no pair claims a noun into the count that lights pairs (%s)" % [runner.get_noun_counts()]
	)

	_drop(host)
	Global.run_inventory = null
