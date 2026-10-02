extends Node

# Cross-system invariants (Integration & Abuse Pass, chatgpt review §b-4):
# properties that must hold whatever the content does.
#   1. The V4 tree is a pinned control: byte-identical to the recorded hash.
#   2. refund(purchase(x)) restores the ledger's semantic state exactly and
#      returns every follower paid (at share 1.0), ranks included.
#   3. Followers can never go negative through any mutation path.
#   4. V5 Meltdown / Hot Core never sets jam_left; the only jam writer left
#      in V5 is Bullet Hell's (BRE2) authored shutdown.
#   5. The Big One counts only true call_shell Shells: shell-tagged blasts
#      that bypass call_shell, and beacon-flagged shells, never feed it.
#   6. The Exit Rite can never be READY (unlocked) with an unmet required
#      blocker — the full truth table of both builders' gate rules.
#   7. Witness strikes exist only for ledger-owned foreign Cores: without a
#      Gate, no amount of native fire manufactures one (engines credit
#      witness only through the runner's validated call).
# (Damage conservation through projectile overflow lives in
# ProjectileOverflowTest; item identity through trade+undo in HubWorldTest.)
#
# Run: <godot> --headless --path . res://tools/tests/InvariantsTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")

## The V4 control, byte-identical since the 2026-09-25 handoff began. If this
## fails, the V4 tree was edited — that is a design decision, not a tweak:
## re-pin only after confirming V4 baselines and saves were re-validated.
const TREE_V4_SHA256 := "370942ff1c172735b14b9507ef7af23c845e5e9c8e11d375d4319370291f0a5f"

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _fresh_ledger(native: String = "ranged") -> AscensionLedger:
	var db := AscensionTreeDB.shared_for("v5_ranged")
	return AscensionLedger.new(db, AscensionLedger.fresh_state(native, "v5_ranged"))


func _buy(ledger: AscensionLedger, id: String) -> int:
	var verdict := ledger.can_buy(id, 1000000)
	if not bool(verdict["ok"]):
		return -1
	ledger.record_purchase(id, int(verdict["cost"]))
	return int(verdict["cost"])


## The fields that define what the player OWNS and what future refunds pay.
## Audit fields (spent/refunded/history) legitimately record activity.
func _semantic_state(ledger: AscensionLedger) -> Dictionary:
	return {
		"owned": (ledger.state["owned"] as Dictionary).duplicate(true),
		"paid": (ledger.state["paid"] as Dictionary).duplicate(true),
		"paid_ranks": (ledger.state["paid_ranks"] as Dictionary).duplicate(true),
		"equipped": (ledger.state["equipped"] as Dictionary).duplicate(true),
		"cores": (ledger.state["cores"] as Array).duplicate(true),
	}


func _run() -> void:
	_test_v4_control_pinned()
	_test_refund_roundtrip()
	_test_followers_never_negative()
	await _test_new_runs_reach_v5()
	await _test_v5_meltdown_never_jams()
	await _test_big_one_purity()
	await _test_exit_rite_blockers()
	await _test_witness_needs_a_gate()
	print("InvariantsTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# --- 1: the V4 control is byte-identical.
func _test_v4_control_pinned() -> void:
	var tree_sha256 := FileAccess.get_sha256("res://data/ascension/tree_v4.json")
	_check(tree_sha256 == TREE_V4_SHA256, "the V4 tree is the pinned control (sha256 %s)" % tree_sha256.substr(0, 12))
	# And it still parses into the DB beside V5 (a corrupt pin is two bugs).
	_check(AscensionTreeDB.shared_for("v4") != null, "the V4 tree loads")
	_check(AscensionTreeDB.shared_for("v5_ranged") != null, "the V5 tree loads beside it")


# --- 2: purchase then refund is a complete round trip.
func _test_refund_roundtrip() -> void:
	var ledger := _fresh_ledger()
	var before := _semantic_state(ledger)
	var paid_total := 0

	var starter_cost := _buy(ledger, "BR01")
	_check(starter_cost >= 0, "the round trip can buy BR01 (cost %d)" % starter_cost)
	paid_total += maxi(0, starter_cost)
	# Rank 3 is gated on two OTHER unique locals of the discipline (RANK-03),
	# so the round trip carries real neighbours through the unwind too.
	for id in ["BR02", "BR04"]:
		var local_cost := _buy(ledger, id)
		_check(local_cost > 0, "the round trip can buy the local %s (cost %d)" % [id, local_cost])
		paid_total += maxi(0, local_cost)
	for _i in range(2):
		var rank_cost := _buy(ledger, "BR01")
		_check(rank_cost > 0, "the round trip can rank BR01 up (cost %d)" % rank_cost)
		paid_total += maxi(0, rank_cost)
	_check(ledger.rank("BR01") == 3, "BR01 stands at rank 3 before the unwind")

	# Unwind in reverse: exact rank downgrades first, then leaf refunds, then
	# the starter — no cascade needed, every follower accounted.
	var returned := ledger.downgrade_rank("BR01") + ledger.downgrade_rank("BR01")
	returned += ledger.refund("BR04", 1.0)
	returned += ledger.refund("BR02", 1.0)
	returned += ledger.refund("BR01", 1.0)
	_check(returned == paid_total, "every follower paid comes back at share 1.0 (%d of %d)" % [returned, paid_total])
	var after := _semantic_state(ledger)
	_check(after == before, "refund(purchase(x)) restores the semantic ledger state exactly")

	# The same property through refund() alone (no downgrades first).
	var ledger2 := _fresh_ledger()
	var before2 := _semantic_state(ledger2)
	var paid2 := 0
	paid2 += maxi(0, _buy(ledger2, "BR01"))
	paid2 += maxi(0, _buy(ledger2, "BR01"))
	var returned2 := ledger2.refund("BR01", 1.0)
	_check(returned2 == paid2, "refund alone repays rank receipts exactly (%d of %d)" % [returned2, paid2])
	_check(_semantic_state(ledger2) == before2, "and restores the semantic state without downgrades first")


# --- 3: no follower mutation path goes below zero.
func _test_followers_never_negative() -> void:
	var prior := int(Global.followers)
	Global.set_followers(10)
	Global.add_followers(-999999)
	_check(Global.followers == 0, "add_followers clamps at zero")
	Global.set_followers(-5)
	_check(Global.followers == 0, "set_followers clamps at zero")
	Global.set_followers(10)
	var result: Dictionary = Global.transaction_followers(-999999, &"invariant_test", {}, false, false)
	_check(int(result["new"]) == 0 and Global.followers == 0, "transaction_followers clamps at zero (change %d)" % int(result["change"]))
	_check(int(result["change"]) == -10, "the transaction reports the real, clamped change")
	Global.set_followers(prior)


# --- 4: V5 Meltdown is loud but never a Jam.
func _test_v5_meltdown_never_jams() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("BR01", 0)
	ledger.record_purchase("BR03", 400)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	var engine := _runner.engine_for("BR01") as BarrageEngineV5
	_check(engine != null and engine.claims_heat(), "the meltdown rig owns Hot Core")
	if engine == null:
		return
	engine.add_heat(150.0)
	_check(engine._meltdown_left > 0.0, "overheat begins a Meltdown")
	var jam_seen := false
	for _i in range(70):
		engine.tick(0.1)
		engine.add_heat(20.0)   # keep abusing the trigger through the lockout
		if engine.jam_left > 0.0 or engine.jammed():
			jam_seen = true
	_check(not jam_seen, "Meltdown, lockout and re-overheat never set jam_left")
	_check(int(engine.counters.get("jams", 0)) == 0, "the V4 jam counter never moves in V5")
	# The one authored exception: Bullet Hell's shutdown after a Burst.
	# Engines cache their owned set at refresh, so re-refresh and re-fetch.
	ledger.record_purchase("BRQ", 100)
	ledger.record_purchase("BRE2", 100)
	_runner.refresh()
	engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(engine != null and engine.has("BRE2"), "the rig re-arms with Bullet Hell")
	engine._complete_burst()
	_check(is_equal_approx(engine.jam_left, 1.5), "BRE2's authored shutdown remains the only V5 jam writer (%.1f)" % engine.jam_left)
	engine.jam_left = 0.0
	_player.queue_free()
	await get_tree().process_frame
	_player = null
	_runner = null


# --- 5: the Big One is fed only by true call_shell Shells.
func _test_big_one_purity() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("OR02", 0)
	ledger.record_purchase("OR01", 100)
	ledger.record_purchase("OR12", 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	var engine := _runner.engine_for("OR02") as OrdnanceEngineV5
	_check(engine != null, "the ordnance rig loads OrdnanceEngineV5")
	if engine == null:
		return
	var interval: int = engine._big_one_interval()
	# Shell-TAGGED blasts that bypass call_shell: mines, chains, anything a
	# renderer or tag rider could fabricate. None of them may feed the count.
	for _i in range(interval * 2):
		engine._blast(Vector2(120, 0), 10.0, 2.0, "OR05", 1.0, PackedStringArray(), 0, true, true)
	_check(engine._shell_count == 0 and int(engine.counters["big_ones"]) == 0, "shell-tagged blasts outside call_shell never feed the Big One")
	# Beacon-flagged shells are authored OUT of the count.
	for _i in range(interval * 2):
		engine.call_shell(Vector2(140, 0), 1.5, "OR01", 1.0, PackedStringArray(["beacon"]))
	_check(engine._shell_count == 0 and int(engine.counters["big_ones"]) == 0, "beacon shells never feed the Big One")
	# True Shells do, exactly on the authored interval.
	for i in range(interval):
		engine.call_shell(Vector2(160, 0))
	_check(engine._shell_count == interval and int(engine.counters["big_ones"]) == 1, "exactly %d true Shells raise exactly one Big One" % interval)
	_player.queue_free()
	await get_tree().process_frame
	_player = null
	_runner = null


# --- 6: the Exit Rite can never be READY past an unmet required blocker.
func _test_exit_rite_blockers() -> void:
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	add_child(rite)
	await get_tree().process_frame

	# SegmentProcBuilder's rule: primary + full resonance + every required
	# arena boss. All 16 requirement combinations, plus the not-required rows.
	var builder := SegmentProcBuilder.new()
	builder._exit_rite = rite
	var violations := 0
	for mask in range(16):
		builder._primary_completed = (mask & 1) != 0
		builder.resonance = 1.0 if (mask & 2) != 0 else 0.5
		builder._boss_required = true
		builder._boss_defeated = (mask & 4) != 0
		builder._miniboss_required = true
		builder._miniboss_defeated = (mask & 8) != 0
		builder._update_gate_lock()
		var all_met: bool = mask == 15
		if rite.locked != (not all_met):
			violations += 1
	builder._boss_required = false
	builder._miniboss_required = false
	builder._primary_completed = true
	builder.resonance = 1.0
	builder._boss_defeated = false
	builder._miniboss_defeated = false
	builder._update_gate_lock()
	if rite.locked:
		violations += 1
	_check(violations == 0, "SegmentProcBuilder: READY exactly when every required blocker is met (%d violations)" % violations)
	builder.free()

	# Level1Builder's rule: full resonance + the authored final plaza.
	var l1 := Level1Builder.new()
	l1._exit_rite = rite
	var had_plaza := Global.attempt_segment1_milestones.has(&"final_plaza")
	var l1_violations := 0
	for mask in range(4):
		l1.resonance = 1.0 if (mask & 1) != 0 else 0.5
		Global.attempt_segment1_milestones.erase(&"final_plaza")
		if (mask & 2) != 0:
			Global.attempt_segment1_milestones.append(&"final_plaza")
		l1._update_gate_lock()
		if rite.locked != (mask != 3):
			l1_violations += 1
	_check(l1_violations == 0, "Level1Builder: READY exactly at full resonance in the final plaza (%d violations)" % l1_violations)
	Global.attempt_segment1_milestones.erase(&"final_plaza")
	if had_plaza:
		Global.attempt_segment1_milestones.append(&"final_plaza")
	l1.free()
	rite.queue_free()
	await get_tree().process_frame


# --- 7: Witness strikes exist only for ledger-owned foreign Cores.
func _test_witness_needs_a_gate() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("BR01", 0)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	for _i in range(8):
		RunEvents.weapon_fired.emit(_player, &"ranged", _player.global_position, _player.global_position + Vector2(200, 0), 1.0, 1.0)
	_check(_runner.witness_strikes == 0, "without a Gate, native fire never manufactures a witness strike (%d)" % _runner.witness_strikes)
	_check(_runner.foreign_cores().is_empty(), "no foreign Core exists without a ledger-owned Gate")
	# The positive control: a real Gate makes the same fire witness.
	ledger.record_purchase("G1", 1600, "melee")
	_runner.refresh()
	for _i in range(8):
		RunEvents.weapon_fired.emit(_player, &"ranged", _player.global_position, _player.global_position + Vector2(200, 0), 1.0, 1.0)
	_check(_runner.witness_strikes > 0, "with a ledger-owned Gate the very same fire witnesses (%d)" % _runner.witness_strikes)
	_player.queue_free()
	await get_tree().process_frame
	_player = null
	_runner = null


# --- Finding 1 (playtest review): the ordinary new-run path reaches V5.
func _test_new_runs_reach_v5() -> void:
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	var ledger := Global.ascension_ledger()
	_check(ledger.is_v5() and ledger.tree_version() == "v5_ranged", "a plain new run creates a V5 ledger (%s)" % ledger.tree_version())
	ledger.record_purchase("BR01", 0)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_check(_runner.engine_for("BR01") is BarrageEngineV5, "the ordinary run instantiates the V5 engines")
	# The version survives an in-memory save round trip untouched.
	var save := SaveData.new()
	save.slot_index = 97
	Global.write_save(save)
	Global.apply_save(save)
	_check(Global.ascension_ledger().tree_version() == "v5_ranged", "the run keeps its tree version through save/load")
	# And the control stays selectable: the switch is honored, not hardwired.
	var previous := Global.new_run_tree_version
	Global.new_run_tree_version = "v4"
	Global.attempt_ascension = {}
	Global._ascension_ledger = null
	_check(not Global.ascension_ledger().is_v5(), "the V4 control remains one switch away")
	Global.new_run_tree_version = previous
	_player.queue_free()
	await get_tree().process_frame
	_player = null
	_runner = null
