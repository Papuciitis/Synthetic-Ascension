extends Node

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

func _run() -> void:
	var path := "res://core/systems/telemetry/BalanceLedger.gd"
	_check(ResourceLoader.exists(path), "balance ledger is available")
	if ResourceLoader.exists(path):
		var ledger = load(path).new()
		ledger.start({"capture_id": "fixture"}, 100, 2)
		ledger.transaction(100, 50, 150, "combat_influence", {})
		ledger.transaction(150, -20, 130, "shop_buy", {})
		ledger.transaction(130, 20, 150, "ascension_refund", {})
		var s: Dictionary = ledger.summary()
		_check(s.totals.followers_earned == 50 and s.totals.followers_spent == 20, "refund does not masquerade as earnings")
		_check(s.totals.followers_adjustments == 20 and s.totals.followers_close == 150, "wallet reconciles including refunds")
		ledger.enemy_seen(101, "brute", false, 25.0)
		ledger.enemy_damage(101, 10.0, 10.0, 1, 0, true)
		ledger.advance(2.0, "gameplay")
		ledger.advance(10.0, "paused")
		ledger.enemy_damage(101, 15.0, 90.0, 3, 2, true)
		ledger.enemy_defeated(101)
		ledger.enemy_defeated(101)
		s = ledger.summary()
		_check(s.totals.enemy_hp_removed == 25.0 and s.totals.enemy_overkill == 75.0, "actual enemy HP loss and overkill are separate")
		_check(s.totals.kills == 1 and s.totals.resolved_hits == 4 and s.totals.critical_hits == 2, "batched hits and duplicate death cannot inflate counts")
		_check(s.totals.enemies["brute"].ttk_seconds == 2.0, "enemy TTK excludes pauses")
		ledger.player_damage(100.0, 50.0, 20.0, "brute", "hit")
		ledger.player_heal(30.0, 30.0, 5.0, "pickup", false)
		ledger.player_heal(10.0, 0.0, 0.0, "regen", true)
		s = ledger.summary()
		_check(s.totals.player_hp_lost == 20.0 and s.totals.player_overkill == 30.0, "lethal incoming hit only charges remaining health")
		_check(s.totals.healing == 5.0 and s.totals.heal_overflow == 25.0 and s.totals.heal_blocked == 10.0, "healing overflow and sealed healing are separate")
		ledger.change_segment(3, "completed")
		ledger.advance(4.0, "hub")
		ledger.transaction(150, -10, 140, "shop_buy", {})
		s = ledger.summary()
		_check(s.segments.size() == 2 and s.segments[0].followers_close == 150 and s.segments[1].followers_open == 150, "segment balances carry over without duplicated income")
		_check(s.totals.seconds_gameplay == 2.0 and s.totals.seconds_paused == 10.0 and s.totals.seconds_hub == 4.0, "clock modes remain independent")
		ledger.enemy_seen(102, "brute", false, 40.0)
		ledger.enemy_damage(102, 1.0, 1.0, 1, 0, false)
		ledger.enemy_removed(102, "streamed_out")
		_check(ledger.summary().totals.kills == 1, "despawning a wounded enemy is not a kill")
		ledger.max_pending_records = 4
		ledger.take_records()
		for i in range(10):
			ledger.transaction(140 + i, 1, 141 + i, "combat_influence", {})
		s = ledger.summary()
		_check(ledger.take_records().size() <= 4 and s.dropped_records > 0, "history is bounded with explicit loss reporting")
		_check(s.totals.followers_close == 150 and s.totals.followers_earned == 60, "history pressure never drops accounting")
		ledger.transaction(999, 1, 1000, "system_sync", {})
		_check(ledger.summary().wallet_discontinuities == 1, "unobserved wallet changes are flagged")
		# Outcomes the player's damage path reports besides a plain hit: a lethal
		# hit a rule intercepted still removed real health; a rule-made miss is
		# an avoided hit like an evasion.
		var outcomes = load(path).new()
		outcomes.start({}, 0, 2)
		outcomes.player_damage(50.0, 50.0, 9.0, "brute", "intercepted")
		outcomes.player_damage(10.0, 0.0, 0.0, "brute", "missed")
		outcomes.player_damage(10.0, 0.0, 0.0, "brute", "evaded")
		var oc: Dictionary = outcomes.summary().totals
		_check(oc.player_hp_lost == 9.0 and oc.player_overkill == 41.0 and oc.player_damage_before_defenses == 50.0 and oc.intercepted_hits == 1, "an intercepted lethal hit charges the health it removed and counts once")
		_check(oc.missed_hits == 1 and oc.evaded_hits == 1 and oc.player_damage_by_source.get("brute", 0.0) == 9.0, "a rule-made miss is an avoided hit, not HP loss")
		# Health reconciliation: canonical changes sum to the sampled HP; a
		# gap is reported as unexplained, never balanced away; reconstruction
		# starts a new life at its restored HP.
		var lives = load(path).new()
		lives.start({}, 0, 2)
		lives.begin_life(100.0, 100.0, "capture_start")
		lives.record_health_change({"category": "hit", "source_id": "brute", "hp_before": 100.0, "hp_after": 70.0, "max_hp_before": 100.0, "max_hp_after": 100.0, "requested": 30.0, "reason": "hit"})
		lives.record_health_change({"category": "heal", "source_id": "heal:pickup", "hp_before": 70.0, "hp_after": 80.0, "max_hp_before": 100.0, "max_hp_after": 100.0, "requested": 10.0, "reason": "pickup"})
		lives.record_health_change({"category": "cost", "source_id": "manifestation_pair:death_rattle", "hp_before": 80.0, "hp_after": 75.0, "max_hp_before": 100.0, "max_hp_after": 100.0, "requested": 5.0, "reason": "held_beat"})
		lives.observe_hp(75.0, 100.0)
		var hs: Dictionary = lives.health_summary()
		_check(float(hs.current_life.expected_hp) == 75.0 and float(hs.current_life.residual) == 0.0 and lives.summary().totals.hp_paid == 5.0, "hit, heal and cost reconcile and the cost is paid HP once")
		lives.observe_hp(60.0, 100.0)
		hs = lives.health_summary()
		_check(int(hs.current_life.unexplained_checks) == 1 and float(hs.current_life.unexplained_hp_delta) == -15.0 and float(hs.current_life.expected_hp) == 60.0, "a sampled gap is reported as unexplained and the expectation resyncs")
		lives.end_life("death")
		lives.record_health_change({"category": "respawn", "source_id": "player:reconstruction", "hp_before": 0.0, "hp_after": 100.0, "max_hp_before": 100.0, "max_hp_after": 100.0, "requested": 100.0, "reason": "respawn"})
		hs = lives.health_summary()
		_check(int(hs.lives_completed) == 1 and int(hs.current_life.life_id) == 2 and float(hs.current_life.hp_start) == 100.0 and String(hs.lives[0].ended_reason) == "death", "reconstruction closes the dead life and baselines the next")
		_check(lives.summary().schema_version == 2, "the summary declares schema 2")
		var funded = load(path).new()
		funded.start({}, 100, 2)
		funded.transaction(100, 13200, 13300, "dev_grant", {"source": "ascension route"})
		funded.transaction(13300, -12000, 1300, "ascension_purchase", {})
		funded.transaction(1300, 25, 1325, "combat_influence", {})
		var fd: Dictionary = funded.summary().totals
		_check(fd.followers_earned == 25 and fd.followers_debug == 13200 and fd.followers_spent == 12000, "developer funding is its own bucket, never earned income")
		_check(fd.followers_open + fd.followers_earned - fd.followers_spent + fd.followers_adjustments + fd.followers_debug == fd.followers_close and funded.summary().wallet_discontinuities == 0, "the wallet reconciles through debug grants")
		var trade = load(path).new()
		trade.start({}, 100, 2)
		trade.transaction(100, -20, 80, "trade", {"buy_value": 50, "sell_value": 30})
		trade.transaction(80, 0, 80, "trade", {"buy_value": 40, "sell_value": 40})
		var trade_totals: Dictionary = trade.summary().totals
		_check(trade_totals.followers_earned == 70 and trade_totals.followers_spent == 90 and trade_totals.followers_close == 80, "mixed and even exchanges retain gross sales and purchase values")
		var promoted = load(path).new()
		promoted.start({}, 0, 2)
		promoted.enemy_seen(1, "brute", false, 25.0)
		promoted.enemy_seen(2, "brute", false, 50.0)
		promoted.enemy_seen(1, "brute", true, 100.0)
		promoted.enemy_damage(1, 100.0, 100.0, 1, 0, true)
		promoted.enemy_defeated(1)
		var rows: Dictionary = promoted.summary().totals.enemies
		_check(rows.has("brute [elite]") and rows["brute [elite]"].seen == 1 and rows["brute [elite]"].hp_max == 100.0 and rows["brute [elite]"].kills == 1, "deferred elite promotion updates cohort and HP without double counting")
		_check(rows["brute"].seen == 1 and rows["brute"].hp_min == 50.0, "promotion removes obsolete normal HP samples")
	# --- Run truth (integration pass 2026-09-26): milestones on the segment
	# clock, companion absorption, population aggregates, per-segment procs.
	var truth = load("res://core/systems/telemetry/BalanceLedger.gd").new()
	truth.start({"capture_id": "truth"}, 0, 4)
	truth.advance(12.0, "gameplay")
	truth.truth_mark("primary_completed_at")
	truth.advance(8.0, "gameplay")
	truth.truth_mark("primary_completed_at")
	truth.truth_mark("resonance_full_at")
	var row: Dictionary = truth.summary().segments[0]
	_check(is_equal_approx(float(row.truth.primary_completed_at), 12.0), "a truth milestone stamps the segment clock once (%.1f)" % float(row.truth.primary_completed_at))
	_check(is_equal_approx(float(row.truth.resonance_full_at), 20.0), "later milestones read the advanced clock")
	truth.player_damage(30.0, 10.0, 0.0, "brute", "absorbed")
	truth.player_damage(30.0, 20.0, 20.0, "brute", "hit")
	row = truth.summary().segments[0]
	_check(is_equal_approx(float(row.damage_absorbed), 10.0) and int(row.absorbed_hits) == 1, "companion absorption is counted, not dropped")
	_check(is_equal_approx(float(row.player_hp_lost), 20.0), "the absorbed hit never counts as HP loss")
	truth.truth_perf_sample({"active": 100, "undrawn": 0, "overflow_queue": 0, "capacity": 4096}, {"logical": 30, "materialized": 12, "data_only": 18})
	truth.truth_perf_sample({"active": 5000, "undrawn": 904, "overflow_queue": 3, "capacity": 8192}, {"logical": 60, "materialized": 20, "data_only": 40})
	row = truth.summary().segments[0]
	var perf: Dictionary = row.truth.perf
	_check(int(perf.samples) == 2 and int(perf.projectiles_max) == 5000 and is_equal_approx(float(perf.projectiles_sum), 5100.0), "population aggregate keeps sums and maxima")
	_check(int(perf.undrawn_max) == 904 and int(perf.overflow_queue_max) == 3 and int(perf.sim_capacity_max_seen) == 8192, "render-budget honesty rides the run truth")
	truth.truth_counters("ascension", {"BR.meltdowns": 2.0})
	truth.change_segment(5, "completed")
	truth.truth_mark("primary_completed_at")
	var segs: Array = truth.summary().segments
	_check(segs[0].truth.procs.ascension["BR.meltdowns"] == 2.0, "segment procs live on their own segment's row")
	_check(is_equal_approx(float(segs[1].truth.primary_completed_at), 0.0) and segs[1].truth.procs.is_empty(), "a new segment opens a fresh truth block")
	# The recorder's delta helper: cumulative counters become per-segment
	# deltas, and a counter reset (engine rebuild) clamps instead of going
	# negative.
	BalanceRecorder._proc_baselines.clear()
	var d1: Dictionary = BalanceRecorder._truth_delta("t", {"shells": 7.0})
	var d2: Dictionary = BalanceRecorder._truth_delta("t", {"shells": 10.0})
	var d3: Dictionary = BalanceRecorder._truth_delta("t", {"shells": 2.0})
	_check(d1.get("shells") == 7.0 and d2.get("shells") == 3.0, "cumulative counters become per-segment deltas")
	_check(d3.get("shells") == 2.0, "a rebuilt engine's reset counter clamps, never negative")
	BalanceRecorder._proc_baselines.clear()

	print("BalanceLedgerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
