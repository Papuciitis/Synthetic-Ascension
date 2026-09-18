extends Node

# Every player HP change must reconcile: the canonical health-change record
# emitted by each mutation owner (hits, heals, intentional costs, takebacks,
# stat-refresh clamps, reconstruction) is summed per life and compared with
# the sampled HP. This drives the real player, the real Death Rattle pair,
# the real Slow Heart curse and Regeneration Ring, and a real death, then
# checks the saved artifacts.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceHealthAccountingTest.tscn

const PLAYER = preload("res://core/actors/player/player.tscn")
const SLOW_HEART = preload("res://effects/items/logic/curses/SlowHeartCurse.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _battle_text_count() -> int:
	return int(BattleText.get("_count")) if BattleText != null else 0


func _battle_text_has(text: String) -> bool:
	if BattleText == null:
		return false
	var texts: PackedStringArray = BattleText.get("_texts")
	for i in range(int(BattleText.get("_count"))):
		if texts[i] == text:
			return true
	return false


func _life(recorder: Node) -> Dictionary:
	return recorder.get_summary().health.current_life


func _run() -> void:
	var recorder := get_node_or_null("/root/BalanceRecorder")
	_check(recorder != null, "runtime balance recorder is installed")
	if recorder == null:
		_finish()
		return
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(100)
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.stats = Stats.new()
	player.stats.armor = 0.0
	player.max_hp = 100.0
	player.hp = 100.0
	player.invulnerable_time = 0.0
	var mrunner := player.get_node("ManifestationRunner") as ManifestationRunner
	mrunner.set_process(false)
	var mstate: ManifestationState = mrunner.state
	mstate.set_process(false)
	var dir := "user://balance_health_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	_check(recorder.is_recording(), "explicit headless capture starts")
	var attacker := Node2D.new()
	add_child(attacker)

	# 1. A hit, a heal and an intentional cost each count once and reconcile.
	player.take_damage(30.0, attacker)
	player.heal(10.0, &"pickup")
	player.pay_health(5.0, &"test")
	recorder._capture_sample()
	var summary: Dictionary = recorder.get_summary()
	var t: Dictionary = summary.totals
	var life: Dictionary = summary.health.current_life
	_check(player.hp == 75.0 and float(life.expected_hp) == 75.0 and float(life.residual) == 0.0 and int(life.unexplained_checks) == 0, "100 - 30 hit + 10 heal - 5 cost reconciles to 75 (expected %.1f, residual %.3f)" % [float(life.expected_hp), float(life.residual)])
	_check(t.player_hp_lost == 30.0 and t.healing == 10.0 and t.hp_paid == 5.0, "hit loss, healing and paid HP are each counted once (%.1f / %.1f / %.1f)" % [t.player_hp_lost, t.healing, t.hp_paid])
	var cats: Dictionary = life.by_category
	_check(float(cats.hit.delta) == -30.0 and float(cats.heal.delta) == 10.0 and float(cats.cost.delta) == -5.0 and int(cats.hit.count) == 1, "the reconciliation ledger carries each category with its signed delta")
	_check(bool(recorder.get_summary().metadata.features.health_reconciliation) and int(summary.schema_version) == 2, "the capture declares schema 2 with health reconciliation measured")

	# 2. Death Rattle: the real pair on the real player. The toll is reported
	# as a cost with its own source; its semantics are untouched (no evasion
	# roll, no hit, no regeneration pause, one announcement, god mode ignored).
	player.take_damage(45.0, attacker)
	_check(player.hp == 30.0, "fixture: a hit leaves the player wounded at 30")
	mstate.claim(&"cadence")
	mstate.claim(&"ward")
	var def := ManifestationPairCatalog.get_def(&"death_rattle")
	var rattle: Node = def.logic.new()
	rattle.name = "death_rattle"
	add_child(rattle)
	rattle.setup_pair(player, mstate, def, 0.0)
	rattle.set_process(false)
	var beats: int = int(rattle.get_script().get_script_constant_map()["BEATS"])
	var cost: float = rattle.hold_cost()
	_check(cost == 5.0, "fixture: a held beat costs 5%% of 100 max HP (%.1f)" % cost)
	while mstate.beat_in_cycle(beats) != beats - 1:
		mstate.note_attack()
	mstate.time_since_attack = 0.0
	rattle.on_attack(&"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(bool(rattle.get("_hold_armed")), "fixture: the empowered beat is held while wounded")
	var rng_before: int = Global._rng.state
	var lost_before: float = recorder.get_summary().totals.player_hp_lost
	var regen_before: float = float(player.get("_melee_regen_block_left"))
	var texts_before := _battle_text_count()
	rattle.on_attack(&"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	summary = recorder.get_summary()
	life = summary.health.current_life
	_check(player.hp == 25.0 and summary.totals.hp_paid == 10.0, "panic-firing into the hold pays 5 HP and the recorder counts it as paid HP (hp %.1f, paid %.1f)" % [player.hp, summary.totals.hp_paid])
	_check(float((life.by_source as Dictionary).get("manifestation_pair:death_rattle", 0.0)) == -5.0 and float(life.expected_hp) == 25.0, "the toll is attributed to Death Rattle and reconciles")
	_check(Global._rng.state == rng_before and summary.totals.player_hp_lost == lost_before, "the toll rolls no evasion and is not a hit")
	_check(float(player.get("_melee_regen_block_left")) == regen_before, "the toll does not pause melee regeneration (pay_health semantics are not imposed)")
	_check(_battle_text_has("RATTLE -5") and _battle_text_count() <= texts_before + 2, "the toll announces itself once, without an extra popup")
	Global.debug_player_god_mode = true
	while mstate.beat_in_cycle(beats) != beats - 1:
		mstate.note_attack()
	mstate.time_since_attack = 0.0
	rattle.on_attack(&"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	rattle.on_attack(&"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	Global.debug_player_god_mode = false
	_check(player.hp == 20.0 and recorder.get_summary().totals.hp_paid == 15.0, "god mode does not exempt the rattle today, and the payment is still recorded (hp %.1f)" % player.hp)
	# The 1 HP floor: armed while affordable, paid after a hit left less. The
	# shared clock still reads the held value from the last hold, so it is
	# handed back (as the pair does after the resolve window) before arming;
	# and the ward noun claimed above has banked a Composure guard, which is
	# spent first so the fixture hit lands whole.
	mstate.time_since_attack = 0.0
	rattle.on_attack(&"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	_check(bool(rattle.get("_hold_armed")), "fixture: a hold is armed at 20 HP")
	mstate.time_since_hit = 0.0
	player.take_damage(17.0, attacker)
	_check(player.hp == 3.0, "fixture: a hit leaves 3 HP (%.2f)" % player.hp)
	rattle.on_attack(&"ranged", Vector2.ZERO, Vector2.RIGHT, 1.0, 1.0)
	life = _life(recorder)
	_check(player.hp == 1.0 and recorder.get_summary().totals.hp_paid == 17.0 and float(life.expected_hp) == 1.0, "the rattle never takes the last point: 2 paid, reconciled (hp %.1f, paid %.1f)" % [player.hp, recorder.get_summary().totals.hp_paid])
	remove_child(rattle)
	rattle.free()

	# 3. Healing takeback (Slow Heart) is an adjustment, and its release is
	# healing under the item's own source.
	var slow: Node = SLOW_HEART.new()
	slow.setup_with_item(player, null, -1)
	add_child(slow)
	slow.set_process(false)
	lost_before = recorder.get_summary().totals.player_hp_lost
	_check(player.hp == 1.0, "fixture: the takeback case starts at 1 HP (%.2f)" % player.hp)
	player.heal(20.0, &"pickup")
	summary = recorder.get_summary()
	life = summary.health.current_life
	_check(player.hp == 4.0 and summary.totals.healing == 30.0 and summary.totals.player_hp_lost == lost_before, "20 healing lands, Slow Heart takes back 17: applied healing stays 20 and nothing is enemy damage (hp %.1f)" % player.hp)
	_check(float((life.by_source as Dictionary).get("item:curse_slow_heart", 0.0)) == -17.0 and float(life.expected_hp) == 4.0, "the takeback is an adjustment attributed to the curse and reconciles")
	slow._process(1.0)
	summary = recorder.get_summary()
	_check(float((summary.totals.healing_by_source as Dictionary).get("item:curse_slow_heart", 0.0)) == 3.5 and float(summary.health.current_life.expected_hp) == 7.5 and player.hp == 7.5, "the released bank is healing under the curse's source (hp %.1f)" % player.hp)
	remove_child(slow)
	slow.free()
	var ring := RegenerationRingEffect.new()
	ring.setup_with_item(player, null, -1)
	add_child(ring)
	ring.set_process(false)
	ring._process(1.0)
	summary = recorder.get_summary()
	_check(float((summary.totals.healing_by_source as Dictionary).get("item:ring_regeneration", 0.0)) > 0.0 and float(summary.health.current_life.expected_hp) == player.hp, "Regeneration Ring healing carries a stable item source and reconciles")
	remove_child(ring)
	ring.free()

	# 4. A max-HP clamp during a stat refresh is an adjustment, not damage.
	player.heal(200.0, &"pickup")
	var healing_before: float = recorder.get_summary().totals.healing
	lost_before = recorder.get_summary().totals.player_hp_lost
	var shrunk := Stats.new()
	shrunk.max_hp = 70.0
	player.apply_run_stats(shrunk, false)
	life = _life(recorder)
	_check(player.hp == 70.0 and float((life.by_source as Dictionary).get("player:stats", 0.0)) == -30.0 and recorder.get_summary().totals.player_hp_lost == lost_before, "max HP 100 -> 70 at full health records a -30 adjustment, not enemy damage")
	var grown := Stats.new()
	grown.max_hp = 100.0
	player.apply_run_stats(grown, false)
	life = _life(recorder)
	_check(player.hp == 100.0 and float((life.by_source as Dictionary).get("player:stats", 0.0)) == 0.0 and recorder.get_summary().totals.healing == healing_before, "full-health preservation back to 100 is an adjustment, not healing (expected %.1f)" % float(life.expected_hp))
	recorder._capture_sample()
	_check(int(_life(recorder).unexplained_checks) == 0, "every change so far reconciled with the sampled HP")

	# 5. A real death and reconstruction close one life and baseline the next.
	player.stats.armor = 0.0
	player.invulnerable_time = 0.0
	player.take_damage(150.0, attacker)
	summary = recorder.get_summary()
	var health: Dictionary = summary.health
	_check(summary.totals.deaths == 1 and summary.totals.respawns == 1 and int(health.lives_completed) == 1, "a lethal hit closes the life; reconstruction starts the next")
	_check(int(health.current_life.life_id) == 2 and float(health.current_life.hp_start) == player.max_hp and float(health.current_life.expected_hp) == player.hp, "the new life baselines at the restored HP without counting it as healing (life %d)" % int(health.current_life.life_id))
	var closed: Dictionary = health.lives[0]
	_check(String(closed.ended_reason) == "death" and float(closed.hp_end) == 0.0 and String(closed.closed_reason) == "respawn", "the closed life records its death and terminal HP")

	# 6. An unrecorded write (a fixture assignment) is reported, never hidden.
	player.hp = 40.0
	recorder._capture_sample()
	recorder._capture_sample()
	life = _life(recorder)
	_check(int(life.unexplained_checks) == 1 and float(life.unexplained_hp_delta) == 40.0 - player.max_hp and float(life.expected_hp) == 40.0, "an HP change with no record shows as one unexplained check with its residual (%.1f)" % float(life.unexplained_hp_delta))

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and int(saved.schema_version) == 2 and int(saved.metadata.recorder_revision) == 2 and int(saved.metadata.balance_revision) == int(recorder.balance_revision()) and bool(saved.metadata.features.health_reconciliation) and bool(saved.metadata.features.incidents), "the saved summary separates recorder and balance revisions and declares feature coverage")
	_check(saved is Dictionary and int(saved.health.totals.unexplained_checks) == 1 and int(saved.health.lives_completed) == 1, "the saved summary carries the health reconciliation")
	var report := FileAccess.get_file_as_string(capture_path.path_join("report.md"))
	var headings: PackedStringArray = []
	for line in report.split("\n"):
		if line.begins_with("## "):
			headings.append(line)
	_check(report.contains("## Health reconciliation") and report.contains("## Recorder coverage"), "the report explains health reconciliation and recorder coverage (headings: %s)" % ", ".join(headings))
	var history := FileAccess.get_file_as_string(capture_path.path_join("events.jsonl"))
	_check(history.contains('"source_id":"manifestation_pair:death_rattle"') and history.contains('"kind":"health_unexplained"') and history.contains('"kind":"life_started"'), "the event history records the toll, the unexplained gap and life boundaries")
	attacker.free()
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	_finish()


func _finish() -> void:
	print("BalanceHealthAccountingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
