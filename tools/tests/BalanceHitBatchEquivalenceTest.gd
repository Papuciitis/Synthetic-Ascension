extends Node

## BalanceRecorder folds a frame's hits into the ledger at once (FPS audit
## 2026-10-04, item 5). The ledger must end up exactly where per-hit
## enemy_damage calls left it - totals, segment rows, attribution, kills,
## first-hit clocks, last and lethal provenance - up to float summation
## order. This test replays one randomized combat script both ways: hits of
## several provenances (native, tree casts, status, unknown, mixed batches),
## credited and not, lethal hits followed by their defeat, removals and an
## elite promotion mid-frame, frames of one to forty hits.

const Ledger := preload("res://core/systems/telemetry/BalanceLedger.gd")

var _passes := 0
var _failures := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _payload(kind: int) -> Variant:
	match kind:
		0:
			var ledger := HitLedger.new()
			ledger.tags = AscensionTags.native("ranged", "bullet")
			ledger.hit_count = 1 + _rng.randi_range(0, 2)
			ledger.critical_hits = _rng.randi_range(0, 1)
			return ledger
		1:
			var ledger := HitLedger.new()
			var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "BAV", "rupture", 1, 1.0)
			tags.append("cast:rupture:%d" % _rng.randi_range(1, 3))
			ledger.tags = tags
			ledger.hit_count = 1
			return ledger
		2:
			return BalanceAttribution.status(&"burn")
		3:
			return null
		_:
			var ledger := HitLedger.new()
			ledger.hit_count = 2
			ledger.contributions = [
				{"tags": AscensionTags.native("ranged", "bullet"), "damage": 3.0},
				{"tags": AscensionTags.native("melee", "slash"), "damage": 2.0},
			]
			return ledger


func _approx_equal(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b):
		if (a is float or a is int) and (b is float or b is int):
			return "" if absf(float(a) - float(b)) <= 1e-6 * maxf(1.0, absf(float(a))) else "%s: %s vs %s" % [path, str(a), str(b)]
		return "%s: type %s vs %s" % [path, type_string(typeof(a)), type_string(typeof(b))]
	if a is Dictionary:
		var da := a as Dictionary
		var db := b as Dictionary
		if da.size() != db.size():
			return "%s: %d keys vs %d (%s vs %s)" % [path, da.size(), db.size(), str(da.keys()), str(db.keys())]
		for key in da:
			if not db.has(key):
				return "%s: missing %s" % [path, str(key)]
			var diff := _approx_equal(da[key], db[key], "%s.%s" % [path, str(key)])
			if not diff.is_empty():
				return diff
		return ""
	if a is Array:
		var aa := a as Array
		var ab := b as Array
		if aa.size() != ab.size():
			return "%s: %d items vs %d" % [path, aa.size(), ab.size()]
		for i in range(aa.size()):
			var diff := _approx_equal(aa[i], ab[i], "%s[%d]" % [path, i])
			if not diff.is_empty():
				return diff
		return ""
	if a is float:
		return "" if absf(float(a) - float(b)) <= 1e-6 * maxf(1.0, absf(float(a))) else "%s: %s vs %s" % [path, str(a), str(b)]
	return "" if a == b else "%s: %s vs %s" % [path, str(a), str(b)]


func _run() -> void:
	_rng.seed = 20261004
	var recorder := get_node("/root/BalanceRecorder")
	var player := Node2D.new()
	add_child(player)
	var stranger := Node2D.new()
	add_child(stranger)
	var reference := Ledger.new()
	reference.start({}, 0, 2)
	var batched := Ledger.new()
	batched.start({}, 0, 2)
	var saved_ledger: Variant = recorder.get("_ledger")
	var saved_player: Variant = recorder.get("_player_ref")
	recorder.set("_ledger", batched)
	recorder.set("_player_ref", weakref(player))

	var health := {}
	var next_handle := 100
	var alive: Array[int] = []
	for i in range(12):
		var h := next_handle
		next_handle += 1
		health[h] = 400.0
		alive.append(h)
		reference.enemy_seen(h, "grunt", false, 400.0, true)
		batched.enemy_seen(h, "grunt", false, 400.0, true)

	var frames := 480
	var hits_total := 0
	var kills_total := 0
	for frame in range(frames):
		reference.advance(1.0 / 60.0, "gameplay")
		batched.advance(1.0 / 60.0, "gameplay")
		var events := _rng.randi_range(1, 40)
		for e in range(events):
			if alive.is_empty():
				break
			var roll := _rng.randf()
			var h := alive[_rng.randi_range(0, alive.size() - 1)]
			if roll < 0.04:
				# Elite promotion mid-frame: the profile changes under pending hits.
				reference.enemy_seen(h, "grunt", true, 400.0)
				recorder.call("_on_enemy_registered", h)
				batched.enemy_seen(h, "grunt", true, 400.0)
				continue
			if roll < 0.06:
				# Removal (retirement) mid-frame.
				reference.enemy_removed(h, "retired")
				recorder.call("_on_enemy_removing", h, &"retired")
				alive.erase(h)
				var replacement := next_handle
				next_handle += 1
				health[replacement] = 400.0
				alive.append(replacement)
				reference.enemy_seen(replacement, "grunt", false, 400.0)
				recorder.call("_on_enemy_registered", replacement)
				batched.enemy_seen(replacement, "grunt", false, 400.0)
				continue
			var payload: Variant = _payload(_rng.randi_range(0, 4))
			var before := float(health[h])
			var adjusted := _rng.randf_range(1.0, 60.0)
			var applied := minf(adjusted, before)
			var source: Node = player if _rng.randf() < 0.8 else stranger
			var hit := payload as HitLedger
			var provenance := BalanceAttribution.from_payload(payload)
			var lethal := applied >= before - 0.000001
			reference.enemy_damage(h, applied, adjusted, hit.hit_count if hit != null else 1, hit.critical_hits if hit != null else 0, source == player, provenance, lethal)
			recorder.call("_on_enemy_damaged", h, applied, adjusted, before, source, payload)
			hits_total += 1
			health[h] = before - applied
			if float(health[h]) <= 0.0:
				var context := EnemyDeathContext.new(h, &"grunt", Vector2.ZERO, 0, source, {})
				reference.enemy_defeated(h)
				recorder.call("_on_enemy_defeated", context)
				alive.erase(h)
				kills_total += 1
				var fresh := next_handle
				next_handle += 1
				health[fresh] = 400.0
				alive.append(fresh)
				reference.enemy_seen(fresh, "grunt", false, 400.0)
				recorder.call("_on_enemy_registered", fresh)
				batched.enemy_seen(fresh, "grunt", false, 400.0)
		# The deferred fold that closes the frame.
		recorder.call("_fold_hits")
		if frame % 30 == 29:
			reference.flush_window()
			batched.flush_window()
	_check(hits_total > 1000 and kills_total > 50, "the script exercised real combat (%d hits, %d kills)" % [hits_total, kills_total])
	var diff := _approx_equal(reference.summary(), batched.summary(), "summary")
	if not diff.is_empty():
		push_error(diff)
	_check(diff.is_empty(), "the folded ledger matches per-hit enemy_damage (totals, rows, attribution, kills)")
	var reference_records := reference.take_records()
	var batched_records := batched.take_records()
	var record_diff := _approx_equal(reference_records, batched_records, "records")
	if not record_diff.is_empty():
		push_error(record_diff)
	_check(record_diff.is_empty(), "and wrote the same metric windows and records (%d)" % reference_records.size())

	# Per-hit cost through the recorder (the fold amortized over a frame of
	# eight hits) versus a per-hit ledger update.
	var bench_ledger := Ledger.new()
	bench_ledger.start({}, 0, 2)
	recorder.set("_ledger", bench_ledger)
	for h in range(8):
		bench_ledger.enemy_seen(h + 1, "grunt", false, 1.0e9)
	var payload: Variant = _payload(0)
	var started := Time.get_ticks_usec()
	for frame in range(500):
		for h in range(8):
			recorder.call("_on_enemy_damaged", h + 1, 1.0, 1.0, 1.0e9, player, payload)
		recorder.call("_fold_hits")
	var batched_usec := float(Time.get_ticks_usec() - started) / 4000.0
	var direct_ledger := Ledger.new()
	direct_ledger.start({}, 0, 2)
	for h in range(8):
		direct_ledger.enemy_seen(h + 1, "grunt", false, 1.0e9)
	started = Time.get_ticks_usec()
	for frame in range(500):
		for h in range(8):
			var hit := payload as HitLedger
			direct_ledger.enemy_damage(h + 1, 1.0, 1.0, hit.hit_count, hit.critical_hits, true, BalanceAttribution.from_payload(payload), false)
	var direct_usec := float(Time.get_ticks_usec() - started) / 4000.0
	print("BalanceHitBatchEquivalenceTest: per hit %.2f us (per-hit ledger update) vs %.2f us (recorder append + frame fold)" % [direct_usec, batched_usec])
	_check(batched_usec < direct_usec, "the frame fold is cheaper per hit")

	recorder.set("_ledger", saved_ledger)
	recorder.set("_player_ref", saved_player)
	print("BalanceHitBatchEquivalenceTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
