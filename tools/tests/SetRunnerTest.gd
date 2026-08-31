extends Node

# Audit 2026-08-28 (test coverage gaps), Top-15 gap #5:
#   "Set effects + SetRunner - ConduitOverclockAndFeedback, GravemarchMassArrest,
#    GravemarchSunderstep, LatticeAfterstrike are only string-scanned; SetRunner
#    tier activation (0 methods called) is core build identity."
# HIGH rows: effects/conduit/scenes/ConduitOverclockAndFeedback.gd,
# effects/gravemarch/scenes/GravemarchMassArrest.gd,
# effects/gravemarch/scenes/GravemarchSunderstep.gd,
# effects/lattice/scenes/LatticeAfterstrike.gd (all "source-scan only"), plus
# data/sets/SetRunner.gd ("player.tscn only; 0 of 5 methods").
#
# What the player relies on, and what is pinned here:
#   1. Counting     - which equipped slots make a set (Inventory.get_set_counts,
#                     get_set_rarity_average, get_set_strength) and the authored
#                     2/4/6 breakpoints (SetData.active_tiers/next_tier).
#   2. Activation   - SetRunner.apply_sets_to_stats turns those counts into live
#                     effect nodes: which scenes exist at each count, that a
#                     running effect is NOT rebuilt when another piece is added,
#                     that crossing back down frees it, and that the tier stat
#                     deltas land on the Stats the player walks around with.
#   3. Behaviour    - one real gameplay outcome per set-effect scene, driven
#                     through the same RunEvents signals the game emits and
#                     asserted on EnemyWorld state (health, knockback, stun).
#   4. End to end   - the real player.tscn: equipping set pieces into
#                     Global.run_inventory lights the tiers and moves the stats.
#
# Nothing here asserts draw calls, frame counts or log text. Effects are driven
# by calling _process(dt) with an explicit dt (the shape EnemyAreaEffectTest
# uses) so the suite is independent of engine frame pacing; the only real-time
# waits are the Mass Arrest aftershock timers, which are polled to a generous
# deadline.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/SetRunnerTest.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")

const AFTERSTRIKE := "res://effects/lattice/scenes/LatticeAfterstrike.tscn"
const ECHO_BUFFER := "res://effects/lattice/scenes/LatticeEchoBuffer.tscn"
const ARC_BOLTS := "res://effects/conduit/scenes/ConduitArcBolts.tscn"
const OVERCLOCK := "res://effects/conduit/scenes/ConduitOverclockAndFeedback.tscn"
const SUNDERSTEP := "res://effects/gravemarch/scenes/GravemarchSunderstep.tscn"
const MASS_ARREST := "res://effects/gravemarch/scenes/GravemarchMassArrest.tscn"

# High enough that no fixture enemy can die: a death runs the proxy death path,
# which pays out followers and would mutate Global.
const FIXTURE_HP := 5000.0

const STAT_FIELDS: Array[StringName] = [&"max_hp", &"armor", &"move_speed", &"power", &"haste", &"luck"]


## Stands in for the player: the four set effects only ever read
## base_weapon_damage, stats, ranged_bullet_scene and global_position off it,
## and compare identity against the node RunEvents names.
class TestPlayer:
	extends Node2D
	var base_weapon_damage: float = 20.0
	var stats: Stats = null
	var ranged_bullet_scene: PackedScene = null


var _passes := 0
var _failures := 0
var _spawned: Array[int] = []
var _weapon_fired_connections := 0
var _damage_dealt_connections := 0
var _enemy_killed_connections := 0


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
	_weapon_fired_connections = RunEvents.weapon_fired.get_connections().size()
	_damage_dealt_connections = RunEvents.damage_dealt.get_connections().size()
	_enemy_killed_connections = RunEvents.enemy_killed.get_connections().size()
	var enemies_at_start: int = EnemyWorld.active_count()

	_test_set_counting()
	_test_authored_breakpoints()
	await _test_tier_activation()
	await _test_tier_stat_contributions()
	_test_afterstrike()
	_test_sunderstep()
	await _test_mass_arrest()
	await _test_conduit_overclock_and_feedback()
	await _test_real_player_tiers()

	_cleanup_enemies()
	await get_tree().process_frame
	_check(
		RunEvents.weapon_fired.get_connections().size() == _weapon_fired_connections
		and RunEvents.damage_dealt.get_connections().size() == _damage_dealt_connections
		and RunEvents.enemy_killed.get_connections().size() == _enemy_killed_connections,
		"every set effect released its RunEvents hooks - none keeps firing after it is unworn",
	)
	_check(EnemyWorld.active_count() == enemies_at_start, "the suite leaves no fixture enemies behind")

	print("SetRunnerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _make_data(item_id: String, slot: int, set_id: String) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.set_id = set_id
	# Zeroed deltas: the only stat movement in this suite must come from the
	# set tiers, never from the fixture items that carry the set id.
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _set_piece(set_id: String, slot: int, rarity: int = 0) -> ItemInstance:
	# roll_manifestation=false: fixtures must not consume Global RNG state.
	return ItemInstance.from_roll(
		_make_data("%s_piece_%d" % [set_id, slot], slot, set_id),
		rarity, ItemInstance.Polarity.POS, 0.0, false
	)


func _plain_piece(slot: int) -> ItemInstance:
	return ItemInstance.from_roll(_make_data("plain_%d" % slot, slot, ""), 0, ItemInstance.Polarity.POS, 0.0, false)


func _wardrobe(set_id: String, count: int, rarity: int = 0) -> Inventory:
	var inv := Inventory.new()
	for i in range(count):
		inv.set_item(i, _set_piece(set_id, i, rarity))
	return inv


func _spawn(id: StringName, position: Vector2) -> int:
	var handle: int = EnemyWorld.create_enemy(SpawnState.new(
		id, "res://%s.tscn" % String(id), position, FIXTURE_HP, 0.0, 4.0, 0
	))
	_spawned.append(handle)
	return handle


func _cleanup_enemies() -> void:
	for handle in _spawned:
		EnemyWorld.remove_enemy(handle, &"set_runner_test")
	_spawned.clear()


func _damage_taken(handle: int) -> float:
	return FIXTURE_HP - EnemyWorld.get_health(handle)


## Knockback is accumulated in world storage and never decays without a
## simulation, so every push has to be read as a delta.
func _push(handle: int) -> Vector2:
	return EnemyWorld.get_knockback_velocity(handle)


## Builds the effect the way SetRunner does: instantiate the authored scene,
## put it in the tree, then setup_set(player, set_id, count, avg_rarity,
## strength). Automatic processing is off so every tick is an explicit dt.
func _build_effect(scene_path: String, host: Node, set_id: StringName, count: int) -> Node:
	var effect: Node = (load(scene_path) as PackedScene).instantiate()
	add_child(effect)
	effect.call("setup_set", host, set_id, count, 0.0, 1.0)
	effect.set_process(false)
	return effect


func _drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()


func _await_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Polls until the condition holds or the deadline passes. Deliberately
## generous: another cluster is changing how often world nodes process.
func _await_until(condition: Callable, timeout_seconds: float = 3.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return bool(condition.call())


## Records who RunEvents credits for damage while it is armed. The credit is
## what the player's lifesteal and the Manifestation on-hit rules read.
var _credit_log: Array = [] # [[source: Node, amount: float], ...]
var _credit_cb: Callable = Callable()


func _start_credit_recorder() -> Array:
	_credit_log = []
	_credit_cb = Callable(self, "_on_damage_credited")
	RunEvents.damage_dealt.connect(_credit_cb)
	return _credit_log


func _end_credit_recorder() -> void:
	if _credit_cb.is_valid() and RunEvents.damage_dealt.is_connected(_credit_cb):
		RunEvents.damage_dealt.disconnect(_credit_cb)
	_credit_cb = Callable()


func _on_damage_credited(source: Node, amount: float) -> void:
	_credit_log.append([source, amount])


func _credited_to(log: Array, source: Node) -> float:
	var total := 0.0
	for entry in log:
		if entry[0] == source:
			total += float(entry[1])
	return total


func _press_set_active(effect: Node) -> void:
	# The one production trigger for both set actives: R, polled in _process.
	# The frame await is required, not cosmetic: is_action_just_pressed answers
	# for the whole process frame, so without it the next manual _process would
	# read the same press again.
	Input.action_press(&"set_active")
	effect.call("_process", 0.016)
	Input.action_release(&"set_active")
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 1. Counting: which equipped pieces make a set
# ---------------------------------------------------------------------------

func _test_set_counting() -> void:
	var inv := Inventory.new()
	_check(inv.get_set_counts().is_empty(), "an empty wardrobe counts no set pieces")

	inv.set_item(0, _set_piece("gravemarch", 0))
	inv.set_item(1, _set_piece("gravemarch", 1))
	_check(int(inv.get_set_counts().get(&"gravemarch", 0)) == 2, "two equipped Gravemarch pieces count as two")

	inv.set_item(Inventory.SLOT_OFFHAND, _set_piece("gravemarch", Inventory.SLOT_OFFHAND))
	inv.set_item(Inventory.SLOT_RING, _set_piece("gravemarch", Inventory.SLOT_RING))
	_check(
		int(inv.get_set_counts().get(&"gravemarch", 0)) == 2,
		"a set piece worn in the offhand or ring slot never counts toward the set",
	)

	inv.set_item(2, _plain_piece(2))
	_check(int(inv.get_set_counts().get(&"gravemarch", 0)) == 2, "an item with no set id is not counted")

	inv.set_item(3, _set_piece("conduit", 3))
	var mixed: Dictionary = inv.get_set_counts()
	_check(
		int(mixed.get(&"gravemarch", 0)) == 2 and int(mixed.get(&"conduit", 0)) == 1,
		"two sets worn at once are counted independently (%s)" % [mixed],
	)

	inv.set_item(1, null)
	_check(int(inv.get_set_counts().get(&"gravemarch", 0)) == 1, "unequipping a piece drops the count")
	inv.set_item(0, null)
	_check(not inv.get_set_counts().has(&"gravemarch"), "the last piece removed drops the set entirely")

	# Rarity: strength is the average rank of the worn pieces, on the same
	# potency curve every other rarity payout uses.
	var rich := Inventory.new()
	rich.set_item(0, _set_piece("lattice", 0, 4))
	rich.set_item(1, _set_piece("lattice", 1, 0))
	_check(is_equal_approx(rich.get_set_rarity_average(&"lattice"), 2.0), "set rarity averages the worn pieces")
	_check(
		is_equal_approx(rich.get_set_strength(&"lattice"), RarityMath.potency(2.0)),
		"set strength is the rarity potency curve (%.4f)" % rich.get_set_strength(&"lattice"),
	)
	_check(rich.get_set_strength(&"lattice") > 1.0, "ranked-up pieces make the set stronger than neutral")
	_check(
		is_equal_approx(rich.get_set_strength(&"gravemarch"), 1.0),
		"a set with nothing worn sits at the neutral strength 1.0",
	)
	rich.set_item(1, _set_piece("lattice", 1, 4))
	_check(
		is_equal_approx(rich.get_set_rarity_average(&"lattice"), 4.0),
		"ranking the second piece up raises the average, not just the total",
	)


# ---------------------------------------------------------------------------
# 2. The authored breakpoints every set identity is built on
# ---------------------------------------------------------------------------

func _test_authored_breakpoints() -> void:
	for sid: StringName in [&"conduit", &"gravemarch", &"lattice"]:
		var data := Global.set_db.get(sid, null) as SetData
		_check(data != null, "%s is loaded into the set database" % sid)
		if data == null:
			continue

		var thresholds: Array = []
		for tier: SetTier in data.sorted_tiers():
			thresholds.append(tier.required_count)
		_check(thresholds == [2, 4, 6], "%s breaks at 2/4/6 pieces (%s)" % [sid, thresholds])
		_check(data.max_pieces() == 6, "%s is complete at six pieces" % sid)

		_check(data.active_tiers(0).is_empty(), "%s: nothing worn activates nothing" % sid)
		_check(data.active_tiers(1).is_empty(), "%s: one piece is still below the first breakpoint" % sid)
		_check(data.active_tiers(2).size() == 1, "%s: the second piece opens exactly one tier" % sid)
		_check(data.active_tiers(3).size() == 1, "%s: an odd count holds at the tier below it" % sid)
		_check(data.active_tiers(4).size() == 2, "%s: four pieces hold both lower tiers at once" % sid)
		_check(data.active_tiers(6).size() == 3, "%s: six pieces hold all three tiers at once" % sid)
		_check(data.active_tiers(9).size() == 3, "%s: more pieces than authored cannot open a fourth tier" % sid)

		var opened: Array = []
		for tier: SetTier in data.active_tiers(6):
			opened.append(tier.required_count)
		_check(opened == [2, 4, 6], "%s reports its live tiers low to high (%s)" % [sid, opened])

		var next_from_none := data.next_tier(0)
		var next_from_two := data.next_tier(2)
		_check(next_from_none != null and next_from_none.required_count == 2, "%s: the first goal is two pieces" % sid)
		_check(next_from_two != null and next_from_two.required_count == 4, "%s: at two the next goal is four" % sid)
		_check(data.next_tier(6) == null, "%s: a complete set has nothing left to reach" % sid)


# ---------------------------------------------------------------------------
# 3. SetRunner: counts -> live effect nodes
# ---------------------------------------------------------------------------

## Scene paths of the live effects, as plain sorted Strings (StringName sorts
## by interned pointer, which is not stable across runs).
func _effect_keys(runner: SetRunner) -> Array:
	var keys: Array = []
	for key in runner.get_active_effect_keys():
		keys.append(String(key))
	keys.sort()
	return keys


func _effect_with_id(runner: SetRunner, effect_id: StringName) -> Node:
	for child in runner.get_children():
		if child.get("effect_id") == effect_id:
			return child
	return null


func _test_tier_activation() -> void:
	var host := TestPlayer.new()
	add_child(host)
	var runner := SetRunner.new()
	host.add_child(runner)

	var added: Array[Node] = []
	var removed: Array[Node] = []
	runner.effect_added.connect(func(node: Node) -> void: added.append(node))
	runner.effect_removed.connect(func(node: Node) -> void: removed.append(node))

	var inv := Inventory.new()
	runner.apply_sets_to_stats(Stats.new(), inv)
	_check(_effect_keys(runner).is_empty(), "an empty wardrobe runs no set effect")
	_check(added.is_empty(), "and announces nothing")

	# Gravemarch, piece by piece.
	inv.set_item(0, _set_piece("gravemarch", 0))
	runner.apply_sets_to_stats(Stats.new(), inv)
	_check(_effect_keys(runner).is_empty(), "one Gravemarch piece runs no effect")

	inv.set_item(1, _set_piece("gravemarch", 1))
	runner.apply_sets_to_stats(Stats.new(), inv)
	_check(_effect_keys(runner).is_empty(), "the Gravemarch 2-piece is stats only - still no effect node")

	inv.set_item(2, _set_piece("gravemarch", 2))
	runner.apply_sets_to_stats(Stats.new(), inv)
	_check(_effect_keys(runner).is_empty(), "three pieces stay below the effect breakpoint")

	inv.set_item(3, _set_piece("gravemarch", 3))
	runner.apply_sets_to_stats(Stats.new(), inv)
	_check(_effect_keys(runner) == [SUNDERSTEP], "the fourth piece brings Sunderstep to life (%s)" % [_effect_keys(runner)])
	_check(added.size() == 1 and added[0].get("effect_id") == &"gravemarch_4_sunderstep", "and the runner announces it once")

	var sunderstep: Node = _effect_with_id(runner, &"gravemarch_4_sunderstep")
	_check(sunderstep != null and sunderstep.get_parent() == runner, "the effect lives under the SetRunner")
	_check(sunderstep != null and sunderstep.get("player") == host, "and is handed the player the runner hangs off")
	_check(sunderstep != null and sunderstep.get("source_set_id") == &"gravemarch", "and knows which set it came from")
	_check(sunderstep != null and int(sunderstep.get("set_count")) == 4, "and how many pieces are worn")
	_check(sunderstep != null and is_equal_approx(float(sunderstep.get("set_strength")), 1.0), "and how strong they are")

	inv.set_item(4, _set_piece("gravemarch", 4))
	runner.apply_sets_to_stats(Stats.new(), inv)
	_check(_effect_keys(runner) == [SUNDERSTEP], "a fifth piece adds no new effect")
	_check(
		_effect_with_id(runner, &"gravemarch_4_sunderstep") == sunderstep,
		"and the running effect is the same node - adding a piece never restarts it",
	)
	_check(int(sunderstep.get("set_count")) == 5, "though its piece count is refreshed in place")

	inv.set_item(5, _set_piece("gravemarch", 5))
	runner.apply_sets_to_stats(Stats.new(), inv)
	_check(
		_effect_keys(runner) == [MASS_ARREST, SUNDERSTEP],
		"the sixth piece opens Mass Arrest alongside Sunderstep (%s)" % [_effect_keys(runner)],
	)
	_check(
		_effect_with_id(runner, &"gravemarch_4_sunderstep") == sunderstep,
		"completing the set still does not restart the tier-4 effect",
	)
	_check(added.size() == 2 and removed.is_empty(), "two effects announced, nothing removed yet")

	# Rarity moves scaling without rebuilding the node.
	var upgraded := _wardrobe("gravemarch", 6, 4)
	runner.apply_sets_to_stats(Stats.new(), upgraded)
	_check(
		_effect_with_id(runner, &"gravemarch_4_sunderstep") == sunderstep,
		"ranking the pieces up does not rebuild the effect",
	)
	_check(
		is_equal_approx(float(sunderstep.get("set_strength")), RarityMath.potency(4.0)),
		"but the live effect picks up the new set strength (%.4f)" % float(sunderstep.get("set_strength")),
	)
	_check(is_equal_approx(float(sunderstep.get("set_avg_rarity")), 4.0), "and the new average rarity")

	# Crossing back down frees exactly the tier that closed.
	var mass_arrest: Node = _effect_with_id(runner, &"gravemarch_6_verdict")
	upgraded.set_item(5, null)
	runner.apply_sets_to_stats(Stats.new(), upgraded)
	_check(_effect_keys(runner) == [SUNDERSTEP], "unequipping the sixth piece closes Mass Arrest (%s)" % [_effect_keys(runner)])
	_check(removed.size() == 1 and removed[0] == mass_arrest, "and the runner announces exactly that node")
	_check(_effect_with_id(runner, &"gravemarch_4_sunderstep") == sunderstep, "while the tier-4 effect keeps running")

	upgraded.set_item(4, null)
	upgraded.set_item(3, null)
	runner.apply_sets_to_stats(Stats.new(), upgraded)
	_check(_effect_keys(runner).is_empty(), "dropping under four closes Sunderstep too")
	_check(removed.size() == 2, "and that removal is announced as well")

	# Switching sets swaps the whole effect list.
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("lattice", 4))
	_check(_effect_keys(runner) == [AFTERSTRIKE], "a Lattice 4-piece runs Afterstrike (%s)" % [_effect_keys(runner)])
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("conduit", 6))
	_check(
		_effect_keys(runner) == [ARC_BOLTS, OVERCLOCK],
		"changing wardrobe to a full Conduit swaps in its two effects (%s)" % [_effect_keys(runner)],
	)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("lattice", 6))
	_check(
		_effect_keys(runner) == [AFTERSTRIKE, ECHO_BUFFER],
		"a full Lattice runs Afterstrike and the Echo Buffer (%s)" % [_effect_keys(runner)],
	)

	# Two half-sets: each contributes its own tiers.
	var split := Inventory.new()
	for i in range(4):
		split.set_item(i, _set_piece("conduit", i))
	split.set_item(4, _set_piece("lattice", 4))
	split.set_item(5, _set_piece("lattice", 5))
	runner.apply_sets_to_stats(Stats.new(), split)
	_check(
		_effect_keys(runner) == [ARC_BOLTS],
		"a Conduit 4 + Lattice 2 split runs only the Conduit effect (%s)" % [_effect_keys(runner)],
	)

	# No inventory at all: everything shuts down.
	runner.apply_sets_to_stats(Stats.new(), null)
	_check(_effect_keys(runner).is_empty(), "a null inventory shuts every set effect down")

	# refresh_effects is the compatibility entry point and must reach the same
	# live set as the stat pass.
	runner.refresh_effects(_wardrobe("gravemarch", 6))
	_check(
		_effect_keys(runner) == [MASS_ARREST, SUNDERSTEP],
		"refresh_effects reaches the same live effects as the stat pass (%s)" % [_effect_keys(runner)],
	)
	runner.refresh_effects(null)
	_check(_effect_keys(runner).is_empty(), "and refresh_effects(null) shuts them down too")

	await get_tree().process_frame
	_drop(host)


# ---------------------------------------------------------------------------
# 4. Tier stat deltas land on the Stats the player walks around with
# ---------------------------------------------------------------------------

func _accumulate(total: StatDelta, mods: StatDelta) -> void:
	total.max_hp += mods.max_hp
	total.armor += mods.armor
	total.move_speed += mods.move_speed
	total.power += mods.power
	total.haste += mods.haste
	total.luck += mods.luck


func _expected_tier_delta(set_id: StringName, count: int) -> StatDelta:
	var total := StatDelta.new()
	var data := Global.set_db.get(set_id, null) as SetData
	if data == null:
		return total
	for tier: SetTier in data.active_tiers(count):
		if tier.mods != null:
			_accumulate(total, tier.mods)
	return total


func _applied_delta(set_id: StringName, count: int) -> Dictionary:
	var host := TestPlayer.new()
	add_child(host)
	var runner := SetRunner.new()
	host.add_child(runner)
	var base := Stats.new()
	var stats := Stats.new()
	runner.apply_sets_to_stats(stats, _wardrobe(String(set_id), count))
	var delta: Dictionary = {}
	for field in STAT_FIELDS:
		delta[field] = float(stats.get(field)) - float(base.get(field))
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	return delta


func _test_tier_stat_contributions() -> void:
	for sid: StringName in [&"conduit", &"gravemarch", &"lattice"]:
		for count in [0, 1, 2, 3, 4, 5, 6]:
			var applied: Dictionary = _applied_delta(sid, count)
			var expected := _expected_tier_delta(sid, count)
			var ok := true
			for field in STAT_FIELDS:
				if not is_equal_approx(float(applied[field]), float(expected.get(field))):
					ok = false
			_check(ok, "%s at %d pieces applies exactly its live tiers' stat deltas" % [sid, count])
			await get_tree().process_frame

	# Cumulative, not replacing: the six-piece keeps what the two-piece gave.
	var gm_two: Dictionary = _applied_delta(&"gravemarch", 2)
	var gm_four: Dictionary = _applied_delta(&"gravemarch", 4)
	var gm_six: Dictionary = _applied_delta(&"gravemarch", 6)
	await get_tree().process_frame
	_check(
		is_equal_approx(float(gm_six["max_hp"]), float(gm_two["max_hp"])) and float(gm_two["max_hp"]) > 0.0,
		"Gravemarch keeps its 2-piece health all the way to six pieces (+%.1f)" % float(gm_two["max_hp"]),
	)
	_check(
		float(gm_six["armor"]) > float(gm_four["armor"]) and is_equal_approx(float(gm_four["armor"]), float(gm_two["armor"])),
		"and the sixth piece is where its extra armor arrives (%.2f -> %.2f)" % [float(gm_four["armor"]), float(gm_six["armor"])],
	)
	_check(float(gm_four["power"]) > float(gm_two["power"]), "the fourth piece is where its power arrives")

	# Identity, not balance numbers: the direction each set trades in.
	_check(
		float(gm_two["max_hp"]) > 0.0 and float(gm_two["armor"]) > 0.0 and float(gm_two["move_speed"]) < 0.0,
		"Gravemarch trades movement for bulk from its first breakpoint",
	)
	var cd_two: Dictionary = _applied_delta(&"conduit", 2)
	_check(
		float(cd_two["move_speed"]) > 0.0 and float(cd_two["haste"]) > 0.0,
		"Conduit buys movement and haste from its first breakpoint",
	)
	var lt_two: Dictionary = _applied_delta(&"lattice", 2)
	_check(
		float(lt_two["move_speed"]) > 0.0 and float(lt_two["power"]) > 0.0,
		"Lattice buys movement and power from its first breakpoint",
	)

	# The set pass is additive onto whatever the earlier stat steps produced.
	var host := TestPlayer.new()
	add_child(host)
	var runner := SetRunner.new()
	host.add_child(runner)
	var carried := Stats.new()
	carried.max_hp = 250.0
	carried.armor = 7.0
	runner.apply_sets_to_stats(carried, _wardrobe("gravemarch", 2))
	_check(
		is_equal_approx(carried.max_hp, 250.0 + float(gm_two["max_hp"]))
		and is_equal_approx(carried.armor, 7.0 + float(gm_two["armor"])),
		"set tiers add onto the stats the earlier passes already built (%.1f hp, %.2f armor)" % [carried.max_hp, carried.armor],
	)
	await get_tree().process_frame
	_drop(host)


# ---------------------------------------------------------------------------
# 5. LatticeAfterstrike - the delayed echo at the aim point
# ---------------------------------------------------------------------------

func _test_afterstrike() -> void:
	var player := TestPlayer.new()
	add_child(player)
	var stranger := TestPlayer.new()
	add_child(stranger)

	var effect := _build_effect(AFTERSTRIKE, player, &"lattice", 4)
	var delay := float(effect.get("delay"))
	var base_cd := float(effect.get("base_cd"))

	var target := Vector2(600.0, 0.0)
	var near_target := _spawn(&"afterstrike_near", target + Vector2(100.0, 0.0))
	var far_target := _spawn(&"afterstrike_far", target + Vector2(250.0, 0.0))
	var melee_point := _spawn(&"afterstrike_melee", player.global_position.lerp(target, 0.55))

	# Someone else's shot is not the player's echo.
	RunEvents.weapon_fired.emit(stranger, &"ranged", Vector2.ZERO, target, 1.0, 1.0)
	effect.call("_process", delay + 0.05)
	_check(
		is_zero_approx(_damage_taken(near_target)) and is_zero_approx(_damage_taken(melee_point)),
		"another node's weapon fire places no Afterstrike",
	)

	RunEvents.weapon_fired.emit(player, &"ranged", Vector2.ZERO, target, 1.0, 1.0)
	_check(is_zero_approx(_damage_taken(near_target)), "the strike is delayed - firing alone damages nothing")

	var push_before := _push(near_target)
	effect.call("_process", delay + 0.01)
	var echo_damage := _damage_taken(near_target)
	_check(echo_damage > 0.0, "after its delay the echo lands on an enemy at the aim point (%.1f)" % echo_damage)
	_check(is_zero_approx(_damage_taken(far_target)), "and spares an enemy outside its radius")
	_check(
		(_push(near_target) - push_before).x > 0.0,
		"the echo pushes the enemy away from the point it detonated on",
	)
	_check(is_zero_approx(_damage_taken(melee_point)), "a ranged echo detonates at the aim point, not next to the player")

	# The cooldown is real: firing again immediately places nothing.
	RunEvents.weapon_fired.emit(player, &"ranged", Vector2.ZERO, target, 1.0, 1.0)
	effect.call("_process", delay + 0.01)
	_check(
		is_equal_approx(_damage_taken(near_target), echo_damage),
		"a second shot inside the cooldown places no second echo",
	)

	# Once the cooldown is spent it arms again, and a melee shot re-centres the
	# echo between the player and the aim point.
	effect.call("_process", base_cd)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, target, 1.0, 1.0)
	effect.call("_process", delay + 0.01)
	_check(_damage_taken(melee_point) > 0.0, "once the cooldown is spent the next shot echoes again")
	_check(
		is_equal_approx(_damage_taken(near_target), echo_damage),
		"and a melee echo lands short of the aim point, near the player",
	)

	# Set strength scales the payout: a ranked-up Lattice echoes harder.
	var strong := _build_effect(AFTERSTRIKE, player, &"lattice", 4)
	strong.call("set_set_scaling", &"lattice", 4, 4.0, RarityMath.potency(4.0))
	_drop(effect)
	var strong_target := _spawn(&"afterstrike_strong", Vector2(-600.0, 0.0))
	var credited := _start_credit_recorder()
	RunEvents.weapon_fired.emit(player, &"ranged", Vector2.ZERO, Vector2(-600.0, 0.0), 1.0, 1.0)
	strong.call("_process", delay + 0.01)
	_end_credit_recorder()
	_check(
		_damage_taken(strong_target) > echo_damage,
		"a ranked-up Lattice echoes harder (%.1f vs %.1f)" % [_damage_taken(strong_target), echo_damage],
	)
	_check(
		_credited_to(credited, player) > 0.0,
		"the echo's damage is credited to the player, so lifesteal and on-hit rules see it",
	)

	_drop(strong)
	_drop(stranger)
	_drop(player)
	_cleanup_enemies()


# ---------------------------------------------------------------------------
# 6. GravemarchSunderstep - the stomp around the player
# ---------------------------------------------------------------------------

func _test_sunderstep() -> void:
	var player := TestPlayer.new()
	add_child(player)
	player.global_position = Vector2.ZERO

	var effect := _build_effect(SUNDERSTEP, player, &"gravemarch", 4)
	var base_cd := float(effect.get("base_cd"))

	var inside := _spawn(&"sunderstep_inside", Vector2(100.0, 0.0))
	var outside := _spawn(&"sunderstep_outside", Vector2(300.0, 0.0))

	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	var stomp_damage := _damage_taken(inside)
	_check(stomp_damage > 0.0, "an attack stomps enemies standing next to the player (%.1f)" % stomp_damage)
	_check(is_zero_approx(_damage_taken(outside)), "and spares enemies outside the stomp radius")
	_check(_push(inside).x > 0.0, "the stomp throws them away from the player")
	_check(EnemyWorld.get_stun_time(inside) > 0.0, "and briefly stuns them")
	_check(
		_push(outside) == Vector2.ZERO and is_zero_approx(EnemyWorld.get_stun_time(outside)),
		"an enemy outside the radius is neither pushed nor stunned",
	)

	# The stomp fires around the player, not at the aim point: aiming the other
	# way still hits the enemy standing on top of you.
	effect.call("_process", base_cd)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(-900.0, 0.0), 1.0, 1.0)
	_check(
		_damage_taken(inside) > stomp_damage,
		"the stomp is centred on the player, so where the shot was aimed does not matter",
	)

	var after_two := _damage_taken(inside)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_check(is_equal_approx(_damage_taken(inside), after_two), "a shot inside the cooldown does not stomp again")

	# Haste shortens the proc cooldown - that is what the set's haste buys.
	effect.call("_process", 0.80)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_check(
		is_equal_approx(_damage_taken(inside), after_two),
		"without haste the stomp is still on cooldown 0.8s after the last one",
	)
	effect.call("_process", base_cd)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 2.0)
	var after_hasted := _damage_taken(inside)
	effect.call("_process", 0.80)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_check(
		_damage_taken(inside) > after_hasted,
		"a hasted attack shortens the stomp cooldown, so 0.8s later it stomps again",
	)

	# Power carries into the stomp.
	effect.call("_process", base_cd)
	var before_power := _damage_taken(inside)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 3.0, 1.0)
	_check(
		_damage_taken(inside) - before_power > stomp_damage,
		"the player's power multiplier carries into the stomp's damage",
	)

	# Damage credit. A set effect's damage is the PLAYER's damage: that is what
	# the style lifesteal (player.gd `_on_style_damage_dealt`, bound to
	# RunEvents.damage_dealt) and every Manifestation `on_hit` rule
	# (ManifestationRunner._signal_wiring -> RunEvents.player_hit_landed) hang
	# off. An effect that damages without naming the player silently switches
	# both off for that half of a build's output.
	var credited := _start_credit_recorder()
	effect.call("_process", base_cd)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_end_credit_recorder()
	_check(
		_credited_to(credited, player) > 0.0,
		"the stomp's damage is credited to the player, so lifesteal and on-hit rules see it",
	)

	_drop(effect)
	_drop(player)
	_cleanup_enemies()


# ---------------------------------------------------------------------------
# 7. GravemarchMassArrest - bank damage, pull, slam, aftershocks, Verdict
# ---------------------------------------------------------------------------

func _test_mass_arrest() -> void:
	var player := TestPlayer.new()
	add_child(player)
	player.stats = Stats.new()
	var stranger := TestPlayer.new()
	add_child(stranger)

	var effect := _build_effect(MASS_ARREST, player, &"gravemarch", 6)
	var needed := float(effect.call("_damage_needed"))
	var pull_time := float(effect.get("pull_time"))

	var core := _spawn(&"arrest_core", Vector2(50.0, 0.0))
	var ring := _spawn(&"arrest_ring", Vector2(250.0, 0.0))
	var outer := _spawn(&"arrest_outer", Vector2(320.0, 0.0))
	var away := _spawn(&"arrest_away", Vector2(900.0, 0.0))

	# Banking.
	RunEvents.damage_dealt.emit(stranger, needed * 4.0)
	effect.call("_process", 0.05)
	_check(is_zero_approx(_damage_taken(core)), "damage dealt by anything but the player never fills the bank")

	RunEvents.damage_dealt.emit(player, needed * 0.5)
	effect.call("_process", 0.05)
	_check(is_zero_approx(_damage_taken(core)), "a half-full bank does not trigger the arrest")
	_check(_push(core) == Vector2.ZERO, "and nothing is pulled while the bank is still filling")

	# Crossing the threshold starts the pull.
	RunEvents.damage_dealt.emit(player, needed * 0.5)
	_check(is_zero_approx(_damage_taken(core)), "filling the bank starts the arrest, which pulls before it hurts")
	var core_push := _push(core)
	var ring_push := _push(ring)
	effect.call("_process", 0.10)
	_check((_push(core) - core_push).x < 0.0, "the arrest drags nearby enemies toward the player")
	_check((_push(ring) - ring_push).x < 0.0, "including enemies out at the edge of the pull")
	_check(_push(outer) == Vector2.ZERO, "an enemy beyond the pull radius is left alone")
	_check(is_zero_approx(_damage_taken(core)), "the pull itself deals no damage")

	# The slam.
	var credited := _start_credit_recorder()
	effect.call("_process", pull_time)
	_end_credit_recorder()
	var slam_damage := _damage_taken(core)
	_check(slam_damage > 0.0, "when the pull ends the arrest slams (%.1f)" % slam_damage)
	_check(
		_credited_to(credited, player) > 0.0,
		"the slam's damage is credited to the player, so lifesteal and on-hit rules see it",
	)
	_check(EnemyWorld.get_stun_time(core) > 0.0, "and stuns what it caught")
	_check(is_zero_approx(_damage_taken(ring)), "the slam is tighter than the pull - an enemy at its edge is not slammed")
	_check(is_zero_approx(_damage_taken(away)), "and an enemy across the arena is untouched")

	# Melee aftershocks: rings that step outward past the slam.
	var reached_ring: bool = await _await_until(func() -> bool: return _damage_taken(ring) > 0.0, 3.0)
	_check(reached_ring, "the melee follow-up sends aftershocks out past the slam radius")
	var reached_outer: bool = await _await_until(func() -> bool: return _damage_taken(outer) > 0.0, 3.0)
	_check(reached_outer, "and a later aftershock reaches further still")
	await _await_seconds(0.5)
	_check(
		_damage_taken(ring) > _damage_taken(outer),
		"the nearer ring is caught by more aftershocks than the far one (%.1f vs %.1f)"
			% [_damage_taken(ring), _damage_taken(outer)],
	)
	_check(_damage_taken(core) > slam_damage, "and everything the slam caught is caught by the aftershocks too")
	_check(is_zero_approx(_damage_taken(away)), "no aftershock reaches across the arena")

	_drop(effect)

	# Taking the sixth piece off mid-arrest: the real unequip path, through the
	# SetRunner, while aftershocks are still scheduled. They must never land -
	# the set is not worn any more - and the world must be left intact.
	var host := TestPlayer.new()
	add_child(host)
	host.stats = Stats.new()
	var runner := SetRunner.new()
	host.add_child(runner)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("gravemarch", 6))
	var worn: Node = _effect_with_id(runner, &"gravemarch_6_verdict")
	_check(worn != null, "fixture: a full Gravemarch runs Mass Arrest through the runner")
	for child in runner.get_children():
		child.set_process(false)

	var core_before_unequip := _damage_taken(core)
	var ring_before := _damage_taken(ring)
	var outer_before := _damage_taken(outer)
	RunEvents.damage_dealt.emit(host, needed)
	worn.call("_process", pull_time + 0.05)
	_check(_damage_taken(core) > core_before_unequip, "fixture: the worn set's arrest slammed")
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("gravemarch", 5))
	_check(not _effect_keys(runner).has(MASS_ARREST), "unequipping mid-arrest closes Mass Arrest")
	await _await_seconds(1.0)
	_check(
		is_equal_approx(_damage_taken(ring), ring_before) and is_equal_approx(_damage_taken(outer), outer_before),
		"and its scheduled aftershocks never land, because the set is no longer worn",
	)
	_drop(host)

	# Verdict, the active: spend part of the bank early.
	var active := _build_effect(MASS_ARREST, player, &"gravemarch", 6)
	var cd_reports: Array[float] = []
	var failures: Array[String] = []
	active.connect("active_cd_changed", func(time_left: float, _max_cd: float) -> void: cd_reports.append(time_left))
	active.connect("active_failed", func(message: String) -> void: failures.append(message))

	var idle_state: Dictionary = active.call("get_active_state")
	_check(not bool(idle_state["ready"]), "Verdict is not ready on an empty bank")
	var core_before_active := _damage_taken(core)
	await _press_set_active(active)
	_check(not failures.is_empty(), "pressing it on an empty bank refuses out loud")
	active.call("_process", pull_time + 0.05)
	_check(is_equal_approx(_damage_taken(core), core_before_active), "and nothing is arrested")

	var fraction := float(active.get("active_bank_fraction"))
	RunEvents.damage_dealt.emit(player, needed * fraction)
	var ready_state: Dictionary = active.call("get_active_state")
	_check(bool(ready_state["ready"]), "banking the active's share makes Verdict ready")
	_check(
		float(ready_state["resource_value"]) >= float(ready_state["resource_max"]),
		"and the HUD reads the bank as full for the active",
	)
	_check(is_zero_approx(float(ready_state["cooldown_left"])), "with no cooldown left")

	failures.clear()
	cd_reports.clear()
	await _press_set_active(active)
	var spent_state: Dictionary = active.call("get_active_state")
	_check(failures.is_empty(), "pressing it with the bank filled is accepted")
	_check(float(spent_state["cooldown_left"]) > 0.0, "Verdict goes on cooldown when it fires")
	_check(not cd_reports.is_empty() and cd_reports.back() > 0.0, "and reports that cooldown to the HUD")
	_check(
		float(spent_state["resource_value"]) < float(ready_state["resource_value"]),
		"and the bank it spent is gone (%.0f -> %.0f)" % [float(ready_state["resource_value"]), float(spent_state["resource_value"])],
	)
	_check(not bool(spent_state["ready"]), "so it is not ready again straight away")

	var active_push := _push(core)
	active.call("_process", 0.10)
	_check((_push(core) - active_push).x < 0.0, "the forced Verdict pulls like the automatic one")
	var core_before_slam := _damage_taken(core)
	active.call("_process", pull_time)
	_check(_damage_taken(core) > core_before_slam, "and slams like the automatic one")

	failures.clear()
	await _press_set_active(active)
	_check(not failures.is_empty(), "a second press while it is on cooldown refuses")

	_drop(active)
	_drop(stranger)
	_drop(player)
	_cleanup_enemies()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 8. ConduitOverclockAndFeedback - kills speed you up and prime a discharge
# ---------------------------------------------------------------------------

func _test_conduit_overclock_and_feedback() -> void:
	# Part A goes through a real SetRunner: the overclock the player feels is
	# the runner's multiplier, not the effect's.
	var host := TestPlayer.new()
	add_child(host)
	var runner := SetRunner.new()
	host.add_child(runner)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("conduit", 6))
	for child in runner.get_children():
		child.set_process(false)

	var overclock: Node = _effect_with_id(runner, &"conduit_6_overclock_feedback")
	_check(overclock != null, "a full Conduit runs Overclock through the SetRunner")

	_check(
		is_equal_approx(runner.get_move_speed_multiplier(), 1.0) and is_equal_approx(runner.get_haste_multiplier(), 1.0),
		"before a kill the set adds no runtime multiplier",
	)
	RunEvents.enemy_killed.emit(host, null, Vector2(120.0, 0.0))
	var move_mul := runner.get_move_speed_multiplier()
	var haste_mul := runner.get_haste_multiplier()
	_check(move_mul > 1.0, "a kill overclocks the player's movement (x%.2f)" % move_mul)
	_check(haste_mul > 1.0, "and their haste (x%.2f)" % haste_mul)
	_check(
		is_equal_approx(move_mul, float(overclock.get("overclock_move_mul")))
		and is_equal_approx(haste_mul, float(overclock.get("overclock_haste_mul"))),
		"the runner hands the player exactly the effect's overclock",
	)

	overclock.call("_process", float(overclock.get("overclock_duration")) + 0.05)
	_check(
		is_equal_approx(runner.get_move_speed_multiplier(), 1.0) and is_equal_approx(runner.get_haste_multiplier(), 1.0),
		"the overclock expires and the multipliers come back to 1.0",
	)

	RunEvents.enemy_killed.emit(host, null, Vector2(120.0, 0.0))
	_check(runner.get_move_speed_multiplier() > 1.0, "the next kill overclocks again")
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("conduit", 4))
	_check(
		is_equal_approx(runner.get_move_speed_multiplier(), 1.0),
		"taking the sixth piece off ends the overclock at once",
	)
	await get_tree().process_frame
	_drop(host)

	# Part B drives the effect on its own, so the tier-4 Arc Bolts that share
	# the weapon_fired hook cannot be mistaken for the discharge.
	var player := TestPlayer.new()
	add_child(player)
	player.stats = Stats.new()
	var stranger := TestPlayer.new()
	add_child(stranger)
	var effect := _build_effect(OVERCLOCK, player, &"conduit", 6)

	var lash_targets: int = int(effect.get("melee_lash_targets"))
	var lashed: Array[int] = []
	for i in range(lash_targets + 1):
		lashed.append(_spawn(StringName("conduit_lash_%d" % i), Vector2(30.0 * float(i + 1), 0.0)))
	var beyond_lash := _spawn(&"conduit_beyond", Vector2(400.0, 0.0))

	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_check(is_zero_approx(_damage_taken(lashed[0])), "an ordinary attack with nothing primed discharges nothing")

	RunEvents.enemy_killed.emit(stranger, null, Vector2.ZERO)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_check(is_zero_approx(_damage_taken(lashed[0])), "someone else's kill primes nothing")

	# The Conduit set used to damage with no source, unlike Afterstrike,
	# Sunderstep and Mass Arrest, which all pass (handle, dmg, 1, player).
	# EnemyCombatService gates RunEvents.damage_dealt and player_hit_landed on
	# `source != null`, so an entire set's damage fed neither the style
	# lifesteal nor any Manifestation on_hit rule - a whole build engine
	# silently disconnected. Found by this suite, fixed with it.
	var credited := _start_credit_recorder()
	RunEvents.enemy_killed.emit(player, null, Vector2.ZERO)
	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_end_credit_recorder()
	var lash_damage := _damage_taken(lashed[0])
	_check(lash_damage > 0.0, "a kill primes the next melee attack into a cleave (%.1f)" % lash_damage)
	var cleave_total := 0.0
	for handle in lashed:
		cleave_total += _damage_taken(handle)
	_check(
		cleave_total > 0.0 and is_equal_approx(_credited_to(credited, player), cleave_total),
		"and every point of the cleave is credited to the player, so the engine sees it (%.1f of %.1f)"
			% [_credited_to(credited, player), cleave_total]
	)
	var struck := 0
	for handle in lashed:
		if _damage_taken(handle) > 0.0:
			struck += 1
	_check(struck == lash_targets, "the cleave lashes exactly its target cap (%d struck of %d in range)" % [struck, lashed.size()])
	_check(is_zero_approx(_damage_taken(lashed[lash_targets])), "and the furthest of the crowd is the one it drops")
	_check(is_zero_approx(_damage_taken(beyond_lash)), "an enemy outside the lash radius is never touched")
	_check(EnemyWorld.get_stun_time(lashed[0]) > 0.0, "each lashed enemy is briefly stunned")
	_check(_push(lashed[0]).x > 0.0, "and pushed away from the player")

	RunEvents.weapon_fired.emit(player, &"melee", Vector2.ZERO, Vector2(200.0, 0.0), 1.0, 1.0)
	_check(
		is_equal_approx(_damage_taken(lashed[0]), lash_damage),
		"the discharge is spent - the shot after it is an ordinary attack again",
	)

	# Part C: the active, Circuit Feedback.
	var close := _spawn(&"conduit_close", Vector2(0.0, 100.0))
	var beyond := _spawn(&"conduit_beyond_active", Vector2(0.0, 300.0))
	var cd_reports: Array[float] = []
	var failures: Array[String] = []
	effect.connect("active_cd_changed", func(time_left: float, _max_cd: float) -> void: cd_reports.append(time_left))
	effect.connect("active_failed", func(message: String) -> void: failures.append(message))

	var ready_state: Dictionary = effect.call("get_active_state")
	_check(bool(ready_state["ready"]), "Circuit Feedback is ready with no charge required")

	await _press_set_active(effect)
	_check(failures.is_empty(), "pressing it is accepted")
	_check(_damage_taken(close) > 0.0, "and it pulses damage into the enemies around the player")
	_check(EnemyWorld.get_stun_time(close) > 0.0, "stunning them")
	_check(_push(close).y > 0.0, "and throwing them outward")
	_check(is_zero_approx(_damage_taken(beyond)), "an enemy outside the pulse is untouched")
	var spent_state: Dictionary = effect.call("get_active_state")
	_check(float(spent_state["cooldown_left"]) > 0.0, "the pulse goes on cooldown")
	_check(not bool(spent_state["ready"]), "so it is not ready again")
	_check(not cd_reports.is_empty() and cd_reports.back() > 0.0, "and the cooldown is reported to the HUD")

	var pulse_damage := _damage_taken(close)
	await _press_set_active(effect)
	_check(not failures.is_empty(), "a second press on cooldown refuses")
	_check(is_equal_approx(_damage_taken(close), pulse_damage), "and pulses nothing")

	effect.call("_process", float(spent_state["cooldown_left"]) + 0.05)
	var recovered: Dictionary = effect.call("get_active_state")
	_check(bool(recovered["ready"]), "when the cooldown runs out it is ready again")
	failures.clear()
	await _press_set_active(effect)
	_check(failures.is_empty() and _damage_taken(close) > pulse_damage, "and pulses again")

	_drop(effect)
	_drop(stranger)
	_drop(player)
	_cleanup_enemies()


# ---------------------------------------------------------------------------
# 9. The real player: equipping set pieces lights the tiers and moves the stats
# ---------------------------------------------------------------------------

func _test_real_player_tiers() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_inventory = Inventory.new()

	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame

	var runner := player.get_node_or_null("SetRunner") as SetRunner
	_check(runner != null, "player.tscn carries the SetRunner its stat pass routes sets through")
	if runner == null:
		remove_child(player)
		player.free()
		Global.run_inventory = saved_inventory
		Global.permanent_augment_ids = saved_augments
		return

	var baseline: Stats = (player.get("stats") as Stats).copy()
	_check(_effect_keys(runner).is_empty(), "a run that starts with nothing equipped runs no set effect")

	for i in range(4):
		Global.run_inventory.set_item(i, _set_piece("gravemarch", i))
	var four: Stats = (player.get("stats") as Stats).copy()
	_check(
		_effect_keys(runner) == [SUNDERSTEP],
		"equipping four Gravemarch pieces in the run inventory lights Sunderstep on the real player (%s)" % [_effect_keys(runner)],
	)
	var expected_four := _expected_tier_delta(&"gravemarch", 4)
	_check(
		is_equal_approx(four.max_hp - baseline.max_hp, expected_four.max_hp)
		and is_equal_approx(four.armor - baseline.armor, expected_four.armor)
		and is_equal_approx(four.move_speed - baseline.move_speed, expected_four.move_speed),
		"and the player's stats move by the live tiers' deltas (hp %+.1f, armor %+.2f, speed %+.1f)"
			% [four.max_hp - baseline.max_hp, four.armor - baseline.armor, four.move_speed - baseline.move_speed],
	)
	_check(
		is_equal_approx(float(player.get("max_hp")), four.max_hp) and is_equal_approx(float(player.get("speed")), four.move_speed),
		"the set's health and movement reach the fields the player actually moves and survives on",
	)
	_check(
		Global.last_stat_ledger.any(func(row: Dictionary) -> bool: return String(row.get("label", "")) == "SETS"),
		"and the Run Sheet ledger records the set step",
	)

	for i in range(4, 6):
		Global.run_inventory.set_item(i, _set_piece("gravemarch", i))
	var six: Stats = (player.get("stats") as Stats).copy()
	_check(
		_effect_keys(runner) == [MASS_ARREST, SUNDERSTEP],
		"completing the set lights Mass Arrest too (%s)" % [_effect_keys(runner)],
	)
	_check(six.armor > four.armor, "and the sixth piece's armor lands on the player (%.2f -> %.2f)" % [four.armor, six.armor])

	Global.run_inventory.set_item(0, null)
	_check(_effect_keys(runner) == [SUNDERSTEP], "taking one piece off closes the six-piece effect on the real player")
	var five: Stats = (player.get("stats") as Stats).copy()
	_check(is_equal_approx(five.armor, four.armor), "and its armor is taken back off the player")

	for i in range(6):
		Global.run_inventory.set_item(i, null)
	_check(_effect_keys(runner).is_empty(), "stripping the wardrobe shuts every set effect down")
	var stripped: Stats = player.get("stats") as Stats
	_check(
		is_equal_approx(stripped.max_hp, baseline.max_hp)
		and is_equal_approx(stripped.armor, baseline.armor)
		and is_equal_approx(stripped.move_speed, baseline.move_speed),
		"and the player is back to exactly the stats they started the run with",
	)

	await get_tree().process_frame
	remove_child(player)
	player.free()
	Global.run_inventory = saved_inventory
	Global.permanent_augment_ids = saved_augments
