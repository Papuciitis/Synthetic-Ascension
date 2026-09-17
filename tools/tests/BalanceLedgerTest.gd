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
		var tr: Dictionary = trade.summary().totals
		_check(tr.followers_earned == 70 and tr.followers_spent == 90 and tr.followers_close == 80, "mixed and even exchanges retain gross sales and purchase values")
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
	print("BalanceLedgerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
