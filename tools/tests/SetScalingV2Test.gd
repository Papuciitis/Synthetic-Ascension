extends Node

# Balance plan Task 4: continuous set growth with independent channels.
#
# Pins, in order:
#   1. Mean effective rank: banked meter counts (R6 + R6.5 -> 6.25) and the
#      accessory slots never enter a set's average or count.
#   2. The profile's exact anchors (stat 2.5 / damage 2.85 at mean R15), the
#      neutral profile at R0, the continued slope past R30, the bounded
#      channels past R15 and the rate asymptote.
#   3. Tier bonuses through SetRunner: Gravemarch 2-piece HP 45 and 2+6-piece
#      armour 8.75 at mean R15, its movement drawback fixed, Conduit's
#      movement/haste on the rate channel, R0 unchanged from the authored data.
#   4. Each channel is applied once per effect: the slam's landed damage at
#      R15 is exactly `damage` times the R0 slam, never damage x potency.
#   5. A fractional feed through the real Inventory API updates the live
#      effects' scaling without recreating nodes or resetting their bank
#      and cooldown.
#   6. Lattice and Mass Arrest counts through the real weapon_fired and
#      damage_dealt paths stay inside their authored ranges at R30 and R100.
#   7. Overclock refresh never compounds: repeated kills hold one multiplier
#      and the duration is reset, not extended.
#   8. A slam that banks more than it needs cannot chain into a second
#      Verdict inside the internal cooldown, at any rank.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/SetScalingV2Test.tscn

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const MASS_ARREST := "res://effects/gravemarch/scenes/GravemarchMassArrest.tscn"
const ECHO_BUFFER := "res://effects/lattice/scenes/LatticeEchoBuffer.tscn"
const SUNDERSTEP := "res://effects/gravemarch/scenes/GravemarchSunderstep.tscn"
const OVERCLOCK := "res://effects/conduit/scenes/ConduitOverclockAndFeedback.tscn"
# High enough that no fixture enemy can die: a death pays followers into Global.
const FIXTURE_HP := 50000.0


## Stands in for the player the way SetRunnerTest does; also counts the
## magic impacts Lattice asks the player to spawn.
class TestPlayer:
	extends Node2D
	var base_weapon_damage: float = 20.0
	var stats: Stats = null
	var ranged_bullet_scene: PackedScene = null
	var magic_spawns: int = 0

	func _spawn_magic(_pos: Vector2, _dmg: float) -> void:
		magic_spawns += 1


var _passes := 0
var _failures := 0
var _spawned: Array[int] = []
var _bullet_scene: PackedScene = null


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _near(a: float, b: float, tolerance: float = 0.0005) -> bool:
	return absf(a - b) <= tolerance


func _run() -> void:
	var damage_connections := RunEvents.damage_dealt.get_connections().size()
	var fired_connections := RunEvents.weapon_fired.get_connections().size()
	var killed_connections := RunEvents.enemy_killed.get_connections().size()
	var enemies_at_start: int = EnemyWorld.active_count()
	_bullet_scene = _plain_bullet_scene()
	_test_mean_rank()
	_test_profile()
	await _test_tier_bonuses()
	await _test_channel_applied_once()
	await _test_fractional_feed_keeps_live_effects()
	await _test_counts_bounded()
	await _test_overclock_never_compounds()
	await _test_bank_chain_bounded()
	_cleanup_enemies()
	await get_tree().process_frame
	_check(
		RunEvents.damage_dealt.get_connections().size() == damage_connections
		and RunEvents.weapon_fired.get_connections().size() == fired_connections
		and RunEvents.enemy_killed.get_connections().size() == killed_connections,
		"every set effect released its RunEvents hooks",
	)
	_check(EnemyWorld.active_count() == enemies_at_start, "the suite leaves no fixture enemies behind")
	print("SetScalingV2Test: %d passed, %d failed" % [_passes, _failures])
	print("passes=%d failures=%d" % [_passes, _failures])
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
	# Zeroed deltas: only the set tiers may move a stat in this suite.
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _set_piece(set_id: String, slot: int, rarity: int = 0, meter: float = 0.0) -> ItemInstance:
	var inst := ItemInstance.from_roll(
		_make_data("%s_piece_%d" % [set_id, slot], slot, set_id),
		rarity, ItemInstance.Polarity.POS, 0.0, false
	)
	inst.upgrade_meter = meter
	return inst


func _wardrobe(set_id: String, count: int, rarity: int = 0) -> Inventory:
	var inv := Inventory.new()
	for i in range(count):
		inv.set_item(i, _set_piece(set_id, i, rarity))
	return inv


## A bullet stand-in: the effects only position it, set damage/velocity and
## group it, so a bare Node2D lets the suite count shots without physics.
func _plain_bullet_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "PlainBullet"
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _host() -> TestPlayer:
	var host := TestPlayer.new()
	host.stats = Stats.new()
	host.ranged_bullet_scene = _bullet_scene
	add_child(host)
	return host


func _runner_for(host: Node) -> SetRunner:
	var runner := SetRunner.new()
	host.add_child(runner)
	return runner


func _effect_with_id(runner: SetRunner, effect_id: StringName) -> Node:
	for child in runner.get_children():
		if child.get("effect_id") == effect_id:
			child.set_process(false)
			return child
	return null


func _spawn(id: StringName, position: Vector2) -> int:
	var handle: int = EnemyWorld.create_enemy(SpawnState.new(
		id, "res://%s.tscn" % String(id), position, FIXTURE_HP, 0.0, 4.0, 0
	))
	_spawned.append(handle)
	return handle


func _cleanup_enemies() -> void:
	for handle in _spawned:
		EnemyWorld.remove_enemy(handle, &"set_scaling_test")
	_spawned.clear()


func _damage_taken(handle: int) -> float:
	return FIXTURE_HP - EnemyWorld.get_health(handle)


func _drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()


func _bullets() -> Array:
	return get_tree().get_nodes_in_group("player_projectile")


func _clear_bullets() -> void:
	for bullet in _bullets():
		_drop(bullet)


func _applied(set_id: String, count: int, rarity: int) -> Dictionary:
	var host := _host()
	var runner := _runner_for(host)
	var stats := Stats.new()
	var base := Stats.new()
	runner.apply_sets_to_stats(stats, _wardrobe(set_id, count, rarity))
	var delta := {
		"max_hp": stats.max_hp - base.max_hp,
		"armor": stats.armor - base.armor,
		"move_speed": stats.move_speed - base.move_speed,
		"power": stats.power - base.power,
		"haste": stats.haste - base.haste,
		"luck": stats.luck - base.luck,
	}
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	return delta


# ---------------------------------------------------------------------------
# 1. Mean effective rank
# ---------------------------------------------------------------------------

func _test_mean_rank() -> void:
	var inv := Inventory.new()
	inv.set_item(0, _set_piece("gravemarch", 0, 6, 0.0))
	inv.set_item(1, _set_piece("gravemarch", 1, 6, 0.5))
	_check(_near(inv.get_set_rarity_average(&"gravemarch"), 6.25), "two R6 members with meters 0 and 0.5 average 6.25, not 6.0")
	inv.set_item(6, _set_piece("gravemarch", 6, 30, 0.9))
	inv.set_item(7, _set_piece("gravemarch", 7, 30, 0.9))
	_check(_near(inv.get_set_rarity_average(&"gravemarch"), 6.25), "a set-tagged offhand and ring never enter the set's average")
	_check(int(inv.get_set_counts().get(&"gravemarch", 0)) == 2, "nor its piece count")
	inv.set_item(2, _set_piece("gravemarch", 2, 6, 0.999999))
	_check(inv.get_set_rarity_average(&"gravemarch") < 6.5 + 1e-4 and inv.get_set_rarity_average(&"gravemarch") > 6.4, "a nearly full meter counts as nearly one rank, never a whole one")
	var negative := Inventory.new()
	negative.set_item(0, _set_piece("lattice", 0, 0, 0.0))
	negative.items[0].rarity = -1
	_check(is_zero_approx(negative.get_set_rarity_average(&"lattice")), "a negative rank clamps to zero in the average")
	_check(is_zero_approx(Inventory.new().get_set_rarity_average(&"conduit")), "an empty wardrobe averages zero")


# ---------------------------------------------------------------------------
# 2. Profile anchors and bounds
# ---------------------------------------------------------------------------

func _test_profile() -> void:
	var fifteen := SetScaling.profile(15.0)
	_check(_near(float(fifteen.stat), 2.5) and _near(float(fifteen.damage), 2.85), "mean R15: stat 2.5, damage 2.85")
	var zero := SetScaling.profile(0.0)
	var neutral_ok := true
	for name in SetScaling.CHANNELS:
		if not _near(float(zero[name]), 1.0):
			neutral_ok = false
	_check(neutral_ok, "mean R0 is neutral on every channel")
	var one := SetScaling.profile(1.0)
	_check(_near(float(one.stat), 1.0) and _near(float(one.damage), 1.5) and _near(float(one.rate), 1.0), "R1: stats unchanged, damage 1.5, rate not yet started")
	_check(_near(float(one.control), RarityMath.potency(1.0)) and _near(float(one.density), RarityMath.potency(1.0)) and _near(float(one.frequency), RarityMath.potency(1.0)), "R1's bounded channels equal the old potency")
	var six := SetScaling.profile(6.0)
	_check(_near(float(six.stat), 1.5) and _near(float(six.damage), 2.025), "R6: stat 1.5, damage 2.025")
	var thirty := SetScaling.profile(30.0)
	_check(_near(float(thirty.stat), 4.0) and _near(float(thirty.damage), 4.2), "R30: stat 4.0, damage 4.2")
	var forty_five := SetScaling.profile(45.0)
	_check(_near(float(forty_five.stat), 5.5) and _near(float(forty_five.damage), 5.55), "past R30 the last slope continues (R45: stat 5.5, damage 5.55)")
	var bound := RarityMath.potency(15.0)
	_check(
		_near(float(thirty.control), bound) and _near(float(SetScaling.profile(100.0).density), bound) and _near(float(SetScaling.profile(1000.0).frequency), bound),
		"control, density and frequency stop growing at R15 (%.3f)" % bound,
	)
	_check(_near(float(fifteen.control), bound), "and at R15 they equal potency(15) exactly")
	var thirteen := SetScaling.profile(13.0)
	_check(_near(float(thirteen.rate), 1.0 + 0.5 * (1.0 - exp(-1.0))), "rate is 1 + 0.5(1 - e^-1) one time constant past R1")
	_check(float(SetScaling.profile(10000.0).rate) <= 1.5 + 1e-9 and float(SetScaling.profile(10000.0).rate) > 1.499, "and never exceeds 1.5")
	var monotone := true
	var previous := SetScaling.profile(0.0)
	for step in range(1, 120):
		var current := SetScaling.profile(float(step) * 0.5)
		for name in SetScaling.CHANNELS:
			if float(current[name]) < float(previous[name]) - 1e-9:
				monotone = false
		previous = current
	_check(monotone, "every channel is non-decreasing in mean rank")
	var nan_profile := SetScaling.profile(NAN)
	_check(_near(float(nan_profile.stat), 1.0) and _near(float(nan_profile.damage), 1.0), "a non-finite mean rank reads as neutral")
	_check(_near(float(SetScaling.profile(-3.0).damage), 1.0), "and so does a negative one")


# ---------------------------------------------------------------------------
# 3. Tier bonuses through SetRunner
# ---------------------------------------------------------------------------

func _test_tier_bonuses() -> void:
	var two := _applied("gravemarch", 2, 15)
	_check(_near(float(two.max_hp), 45.0), "Gravemarch 2-piece at mean R15 gives +45 HP (18 x 2.5): %.2f" % float(two.max_hp))
	_check(_near(float(two.armor), 5.0), "and +5 armour")
	_check(_near(float(two.move_speed), -6.0), "while its movement drawback stays exactly -6")
	var six := _applied("gravemarch", 6, 15)
	_check(_near(float(six.armor), 8.75), "Gravemarch 2+6-piece armour at mean R15 is 8.75 (3.5 x 2.5): %.3f" % float(six.armor))
	_check(_near(float(six.max_hp), 45.0) and _near(float(six.power), 0.05), "six pieces keep the 45 HP and scale the 4-piece Power to +5%%")
	var zero := _applied("gravemarch", 6, 0)
	_check(
		_near(float(zero.max_hp), 18.0) and _near(float(zero.armor), 3.5) and _near(float(zero.power), 0.02) and _near(float(zero.move_speed), -6.0),
		"at mean R0 the authored numbers apply unchanged",
	)
	var one := _applied("gravemarch", 2, 1)
	_check(_near(float(one.max_hp), 18.0), "R1 is the flat start of the stat curve, so the HP bonus is still 18")
	var conduit_zero := _applied("conduit", 2, 0)
	var conduit_fifteen := _applied("conduit", 2, 15)
	var rate := float(SetScaling.profile(15.0).rate)
	_check(
		_near(float(conduit_fifteen.move_speed), float(conduit_zero.move_speed) * rate, 0.001)
			and _near(float(conduit_fifteen.haste), float(conduit_zero.haste) * rate, 0.0001),
		"Conduit's 2-piece movement and haste grow on the rate channel (x%.3f)" % rate,
	)
	var lattice_thirty := _applied("lattice", 2, 30)
	var lattice_zero := _applied("lattice", 2, 0)
	_check(
		_near(float(lattice_thirty.power), float(lattice_zero.power) * 4.0, 0.0001)
			and _near(float(lattice_thirty.move_speed), float(lattice_zero.move_speed) * float(SetScaling.profile(30.0).rate), 0.001),
		"Lattice's Power rides the stat channel and its movement the rate channel",
	)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 4. A channel is applied once per effect
# ---------------------------------------------------------------------------

func _slam_damage_at(rarity: int) -> float:
	var host := _host()
	var runner := _runner_for(host)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("gravemarch", 6, rarity))
	var arrest := _effect_with_id(runner, &"gravemarch_6_verdict")
	var target := _spawn(&"channel_target", Vector2(40.0, 0.0))
	var needed := float(arrest.call("_damage_needed"))
	RunEvents.damage_dealt.emit(host, needed)
	arrest.call("_process", float(arrest.get("pull_time")) + 0.01)
	var landed := _damage_taken(target)
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	return landed


func _test_channel_applied_once() -> void:
	var host := _host()
	var runner := _runner_for(host)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("gravemarch", 6, 15))
	var arrest := _effect_with_id(runner, &"gravemarch_6_verdict")
	var step := _effect_with_id(runner, &"gravemarch_4_sunderstep")
	_check(arrest != null and step != null, "fixture: a full R15 Gravemarch runs both effects")
	var expected := SetScaling.profile(15.0)
	var same := true
	for name in SetScaling.CHANNELS:
		if not _near(float(arrest.call("channel", name)), float(expected[name])) or not _near(float(step.call("channel", name)), float(expected[name])):
			same = false
	_check(same, "both effects carry the R15 profile on every channel")
	_check(_near(float(arrest.call("channel", "unknown")), 1.0), "an unknown channel reads as 1")
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	var at_zero := _slam_damage_at(0)
	var at_fifteen := _slam_damage_at(15)
	_check(at_zero > 0.0, "fixture: the R0 slam lands (%.1f)" % at_zero)
	_check(
		_near(at_fifteen / maxf(at_zero, 0.001), 2.85, 0.01),
		"the R15 slam lands exactly damage x the R0 slam (%.1f / %.1f = %.3f), never damage x potency" % [at_fifteen, at_zero, at_fifteen / maxf(at_zero, 0.001)],
	)
	# Aftershock timers from those slams must settle before the next test.
	await get_tree().create_timer(1.2).timeout
	_cleanup_enemies()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 5. A fractional feed updates live effects in place
# ---------------------------------------------------------------------------

func _test_fractional_feed_keeps_live_effects() -> void:
	var host := _host()
	var runner := _runner_for(host)
	var inv := _wardrobe("gravemarch", 6, 6)
	var before := Stats.new()
	runner.apply_sets_to_stats(before, inv)
	var arrest := _effect_with_id(runner, &"gravemarch_6_verdict")
	var step := _effect_with_id(runner, &"gravemarch_4_sunderstep")
	var arrest_id := arrest.get_instance_id()
	var step_id := step.get_instance_id()
	arrest.call("debug_set_bank", 40.0)
	arrest.set("_active_cd", 5.0)
	var damage_before := float(arrest.call("channel", "damage"))
	_check(_near(float(arrest.get("set_avg_rarity")), 6.0), "fixture: six R6 pieces read as mean 6.0")
	var fed: bool = inv.feed_roll_into(0, 0.5)
	_check(fed, "the real feed API accepts a roll into an equipped set piece")
	var meter := float(inv.items[0].upgrade_meter)
	_check(meter > 0.0 and meter < 1.0 and int(inv.items[0].rarity) == 6, "and banks it as meter without a rank-up (%.3f)" % meter)
	var after := Stats.new()
	runner.apply_sets_to_stats(after, inv)
	var expected_mean := 6.0 + meter / 6.0
	_check(_near(float(arrest.get("set_avg_rarity")), expected_mean, 1e-4) and _near(float(step.get("set_avg_rarity")), expected_mean, 1e-4), "the live effects see the new fractional mean (%.4f)" % expected_mean)
	_check(float(arrest.call("channel", "damage")) > damage_before, "and their damage channel moved with it")
	_check(
		_effect_with_id(runner, &"gravemarch_6_verdict").get_instance_id() == arrest_id
			and _effect_with_id(runner, &"gravemarch_4_sunderstep").get_instance_id() == step_id,
		"without recreating either effect node",
	)
	_check(_near(float(arrest.get("_bank")), 40.0) and _near(float(arrest.get("_active_cd")), 5.0), "and without touching the bank or the Verdict cooldown")
	_check(after.max_hp > before.max_hp and after.armor > before.armor, "the tier bonuses also grew with the fraction (%.2f -> %.2f HP)" % [before.max_hp, after.max_hp])
	_check(_near(after.move_speed, before.move_speed), "while the movement drawback did not move")
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 6. Counts through the real event paths stay in their authored ranges
# ---------------------------------------------------------------------------

func _lattice_counts_at(rarity: int) -> Dictionary:
	var host := _host()
	var runner := _runner_for(host)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("lattice", 6, rarity))
	var echo := _effect_with_id(runner, &"lattice_6_index_commit")
	_clear_bullets()
	for i in range(3):
		RunEvents.weapon_fired.emit(host, &"ranged", Vector2.ZERO, Vector2(200.0 + 40.0 * i, 30.0 * i), 1.0, 1.0)
	var bullets := _bullets().size()
	_clear_bullets()
	host.magic_spawns = 0
	for i in range(3):
		RunEvents.weapon_fired.emit(host, &"magic", Vector2.ZERO, Vector2(200.0 + 40.0 * i, 30.0 * i), 1.0, 1.0)
	var magic := host.magic_spawns
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	_drop(echo) if is_instance_valid(echo) else null
	return {"bullets": bullets, "magic": magic}


func _shrapnel_at(rarity: int) -> int:
	var host := _host()
	var runner := _runner_for(host)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("gravemarch", 6, rarity))
	var arrest := _effect_with_id(runner, &"gravemarch_6_verdict")
	RunEvents.weapon_fired.emit(host, &"ranged", Vector2.ZERO, Vector2(100.0, 0.0), 1.0, 1.0)
	_clear_bullets()
	RunEvents.damage_dealt.emit(host, float(arrest.call("_damage_needed")))
	arrest.call("_process", float(arrest.get("pull_time")) + 0.01)
	var count := _bullets().size()
	_clear_bullets()
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	return count


func _test_counts_bounded() -> void:
	var zero := _lattice_counts_at(0)
	var thirty := _lattice_counts_at(30)
	var hundred := _lattice_counts_at(100)
	_check(int(zero.bullets) == 12, "Index Commit at R0 fires 3 nodes x 4 bullets through weapon_fired (%d)" % int(zero.bullets))
	_check(int(thirty.bullets) == 21, "at R30 it fires the authored maximum of 3 x 7 (%d)" % int(thirty.bullets))
	_check(int(hundred.bullets) == int(thirty.bullets), "and R100 fires exactly as many as R30")
	# 3 node impacts + 3 edges x hits (2..4).
	_check(int(zero.magic) == 9, "the magic triangle at R0 spawns 3 + 3 x 2 impacts (%d)" % int(zero.magic))
	_check(int(thirty.magic) == 15, "at R30 it spawns 3 + 3 x 4 (%d)" % int(thirty.magic))
	_check(int(hundred.magic) == int(thirty.magic), "and no more at R100")
	var shrapnel_zero := _shrapnel_at(0)
	var shrapnel_thirty := _shrapnel_at(30)
	var shrapnel_hundred := _shrapnel_at(100)
	_check(shrapnel_zero == 12, "a ranged Verdict at R0 throws 12 shrapnel bullets (%d)" % shrapnel_zero)
	_check(shrapnel_thirty == 22 and shrapnel_hundred == 22, "and 22 at both R30 and R100 (%d / %d)" % [shrapnel_thirty, shrapnel_hundred])
	await get_tree().create_timer(1.2).timeout
	_cleanup_enemies()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 7. Overclock refresh never compounds
# ---------------------------------------------------------------------------

func _test_overclock_never_compounds() -> void:
	var host := _host()
	var runner := _runner_for(host)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("conduit", 6, 15))
	var overclock := _effect_with_id(runner, &"conduit_6_overclock_feedback")
	_check(overclock != null, "fixture: a full R15 Conduit runs Overclock")
	var duration := float(overclock.get("overclock_duration"))
	var rate := float(SetScaling.profile(15.0).rate)
	var expected_move := 1.0 + float(overclock.get("overclock_move_gain")) * rate
	var expected_haste := 1.0 + float(overclock.get("overclock_haste_gain")) * rate
	RunEvents.enemy_killed.emit(host, null, Vector2(100.0, 0.0))
	_check(_near(runner.get_move_speed_multiplier(), expected_move, 1e-4) and _near(runner.get_haste_multiplier(), expected_haste, 1e-4), "one kill overclocks by gain x rate (x%.3f move, x%.3f haste)" % [expected_move, expected_haste])
	RunEvents.enemy_killed.emit(host, null, Vector2(100.0, 0.0))
	RunEvents.enemy_killed.emit(host, null, Vector2(100.0, 0.0))
	_check(_near(runner.get_move_speed_multiplier(), expected_move, 1e-4) and _near(runner.get_haste_multiplier(), expected_haste, 1e-4), "two more kills in the same instant change nothing")
	_check(_near(float(overclock.get("_overclock_time")), duration), "and the timer is reset to the duration, not extended")
	overclock.call("_process", duration * 0.6)
	RunEvents.enemy_killed.emit(host, null, Vector2(100.0, 0.0))
	_check(_near(float(overclock.get("_overclock_time")), duration) and _near(runner.get_move_speed_multiplier(), expected_move, 1e-4), "a refresh mid-window restarts the clock at the same multiplier")
	overclock.call("_process", duration + 0.05)
	_check(_near(runner.get_move_speed_multiplier(), 1.0) and _near(runner.get_haste_multiplier(), 1.0), "and it expires back to 1.0")
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	var far := _host()
	var far_runner := _runner_for(far)
	far_runner.apply_sets_to_stats(Stats.new(), _wardrobe("conduit", 6, 1000))
	var far_overclock := _effect_with_id(far_runner, &"conduit_6_overclock_feedback")
	RunEvents.enemy_killed.emit(far, null, Vector2.ZERO)
	_check(far_runner.get_move_speed_multiplier() <= 1.0 + float(far_overclock.get("overclock_move_gain")) * 1.5 + 1e-6, "even at R1000 the overclock never exceeds gain x 1.5")
	far_runner.apply_sets_to_stats(Stats.new(), null)
	_drop(far)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# 8. The bank cannot chain Verdicts inside the internal cooldown
# ---------------------------------------------------------------------------

func _test_bank_chain_bounded() -> void:
	var host := _host()
	var runner := _runner_for(host)
	runner.apply_sets_to_stats(Stats.new(), _wardrobe("gravemarch", 6, 15))
	var arrest := _effect_with_id(runner, &"gravemarch_6_verdict")
	var needed := float(arrest.call("_damage_needed"))
	var needed_far := 0.0
	arrest.call("set_set_scaling", &"gravemarch", 6, 1000.0, 1.0)
	needed_far = float(arrest.call("_damage_needed"))
	arrest.call("set_set_scaling", &"gravemarch", 6, 15.0, 1.0)
	_check(needed >= 60.0 and _near(needed_far, needed), "the bank threshold stops falling past R15 and never drops under 60 (%.1f)" % needed)
	# A dense pack: one slam credits far more than one threshold.
	var pack: Array[int] = []
	for i in range(16):
		pack.append(_spawn(&"pack_%d" % i, Vector2(30.0 + 6.0 * float(i), 0.0)))
	var pull_time := float(arrest.get("pull_time"))
	var internal_cd := float(arrest.get("base_internal_cd"))
	RunEvents.damage_dealt.emit(host, needed)
	_check(int(arrest.get("_mode")) == 1, "fixture: filling the bank starts a Verdict")
	arrest.call("_process", pull_time + 0.01)
	_check(int(arrest.get("_mode")) == 0, "the pull ended and the slam landed")
	var banked := float(arrest.get("_bank"))
	_check(banked > needed * 3.0, "the slam's own credited damage banked more than three thresholds (%.0f vs %.0f)" % [banked, needed])
	var landed := _damage_taken(pack[0])
	arrest.call("_process", 0.05)
	RunEvents.damage_dealt.emit(host, 1.0)
	_check(int(arrest.get("_mode")) == 0 and _near(_damage_taken(pack[0]), landed), "but no second Verdict starts inside the internal cooldown")
	arrest.call("_process", internal_cd)
	_check(int(arrest.get("_mode")) == 0, "the cooldown alone starts nothing")
	RunEvents.damage_dealt.emit(host, 1.0)
	_check(int(arrest.get("_mode")) == 1, "the next credited hit after the cooldown does, so the chain rate is one per %.2f s at any rank" % internal_cd)
	runner.apply_sets_to_stats(Stats.new(), null)
	_drop(host)
	await get_tree().create_timer(1.2).timeout
	_cleanup_enemies()
	await get_tree().process_frame
