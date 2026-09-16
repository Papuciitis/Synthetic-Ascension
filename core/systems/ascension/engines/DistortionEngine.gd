extends AscensionEngine
class_name DistortionEngine
## Distortion: named rolls, Twice, scars, Misfire, the Causal Debt ledger,
## Coin, Payday and REWRITE.
##
## Debt is a saved damage amount due later: Magic Core hits deposit 25% of
## their actual damage (Late Payment: Melee and Ranged Core hits 12.5%), up
## to eight buckets per target, same-source packets merged into the nearest
## due bucket. Interest grows a bucket 15%/s simple to +45%. Maturity pays
## the bucket as a Magic payload ("debt" flag). Review corrections: during
## REWRITE a matured bucket stays "paid, collectable" for 1.5 s so unpaid-
## Debt consumers (Death Debt, Loaded Coin, Pass It On) still find it (F3);
## Payday counts deposits in the last 4 s (F11); Lucky Crit is not a named
## roll but Heads observes real crits (F5).

const DEBT_FRACTION := 0.25
const DEBT_LATE_FRACTION := 0.125
const DEBT_DUE := 2.0
const DEBT_BUCKETS := 8
const DEBT_PP := 0.3
const INTEREST_RATE := 0.15
const INTEREST_CAP := 0.45
const COLLECTABLE_WINDOW := 1.5
const SCAR_LIFE := 5.0
const SCAR_MAX := 12
const SCAR_RADIUS := 40.0
const PAYDAY_DEPOSITS := 20
const PAYDAY_WINDOW := 4.0
const PAYDAY_BOSS_MATURED := 8
const TWICE_CHANCE := 0.20
const TWICE_DELAY := 0.35
const MISFIRE_CHANCE := 0.15

var _clock: float = 0.0
var _volley: int = 0
var debts: Dictionary = {}              # handle -> Array of buckets {amount, due, source, born, v, passed, collect_until}
var _deposit_times: Array[float] = []
var _matured_times: Array[float] = []
var scars: Array = []                   # {pos, magnitude, life}
var _echoes: Array = []                 # {delay, pos, damage, radius, root, pp, flags}
var _fading: Dictionary = {}            # handle -> {rate, left, last_tick}
var _slows: Dictionary = {}             # handle -> {left, base_speed}
var _scar_cooldown: Dictionary = {}     # handle -> clock of last scar
var _seen_projectiles: Dictionary = {}  # id -> true (Misfire judged)
var _denial_bonus: float = 0.0
var _reroll_used: bool = false
var _loaded_payload: bool = false
var _bad_luck_boost: bool = false
var _dice_payment_cd: float = 0.0
var _contradicted: Dictionary = {}      # "handle:path" -> true

var heads_left: float = 0.0
var tails_left: float = 0.0
var _coin_paid: float = 0.0
var _coin_refunded: float = 0.0
var _coin_boss_damage: float = 0.0
var _tails_stacks: int = 0
var _double_window: float = 0.0
var _double_used: bool = false
var _penny_alternate: bool = false
var _coin_tagged: Dictionary = {}       # handle -> true (Loaded Coin)

var payday_left: float = 0.0
var payday_recovery: float = 0.0
var rewrite_left: float = 0.0
var _rewrite_kills: int = 0
var _rewrite_big_damage: float = 0.0
# Undo (DTF1): a one-second window of enemy damage that can be rewound.
var _undo_cd: float = 0.0
var _undo_window: Array = []          # [{t, source_handle, applied}]
var _self_debts: Array = []           # [{amount, due, contributor, cancelled, paused}]
# Fixed Coin (DTE1): the Heads refund bank.
var _heads_bank: float = 0.0
var _last_faces: Array = []
var _slow_zone_set: bool = false

var counters: Dictionary = {"twice": 0, "rerolls": 0, "scars": 0, "scar_releases": 0, "misfires": 0, "misfire_rolls": 0, "deposits": 0, "matured": 0, "debt_damage": 0.0, "back_pays": 0, "pass_ons": 0, "self_debt": 0, "compound": 0, "contradictions": 0, "coins": 0, "heads": 0, "tails": 0, "pennies": 0, "loaded_blasts": 0, "paydays": 0, "rewrites": 0, "misfortune_added": 0, "guarantees": 0, "dice_payments": 0, "fading_ticks": 0}


func discipline() -> String:
	return "DT"


func wants_hit_history() -> bool:
	return has("DTV2")


## REWRITE: normals' melee swings miss. A "swing" is damage from a normal
## enemy adjacent to the player (contact, or a source within 1.5R); ranged
## hits and elite/boss attacks still land.
func damage_taken_multiplier_for(source: Node, kind: StringName) -> float:
	if rewrite_left <= 0.0 or source == null or not is_instance_valid(source):
		return 1.0
	if kind == &"contact_swarm":
		return 0.0
	var handle := EnemyCombat.handle_for_actor(source)
	if handle == 0 or not runner.is_normal(handle):
		return 1.0
	if runner.enemy_position(handle).distance_to(runner.player_position()) <= 1.5 * AscensionRunner.R:
		return 0.0
	return 1.0


## Undo and Fixed Coin watch the damage the player actually took.
func on_player_damage_resolved(source: Node, _raw: float, applied: float, _kind: StringName) -> void:
	if heads_left > 0.0 and has("DTE1"):
		_heads_bank += 0.3 * applied
	if not has("DTF1"):
		return
	var handle := EnemyCombat.handle_for_actor(source) if source != null and is_instance_valid(source) else 0
	_undo_window.append({"t": _clock, "source": handle, "applied": applied})
	while not _undo_window.is_empty() and _clock - float(_undo_window[0]["t"]) > 1.0:
		_undo_window.pop_front()
	if _undo_cd > 0.0:
		return
	var max_hp := float(runner.player().get("max_hp"))
	var total := 0.0
	var by_source: Dictionary = {}
	for entry in _undo_window:
		total += float(entry["applied"])
		by_source[entry["source"]] = float(by_source.get(entry["source"], 0.0)) + float(entry["applied"])
	if total < 0.25 * max_hp or float(runner.player().get("hp")) <= 0.0:
		return
	_undo_cd = 12.0
	_undo_window.clear()
	var greatest := 0
	var greatest_amount := 0.0
	for source_handle in by_source:
		if float(by_source[source_handle]) > greatest_amount:
			greatest_amount = float(by_source[source_handle])
			greatest = int(source_handle)
	var lost := float(runner.player().get("max_hp")) - float(runner.player().get("hp"))
	var restored := minf(total, lost)
	runner.heal_player(restored, &"undo")
	_self_debts.append({"amount": restored, "due": _clock + 3.0, "contributor": greatest, "cancelled": 0.0, "dealt": 0.0, "paused": false})
	counters["undos"] = int(counters.get("undos", 0)) + 1
	if BattleText != null:
		BattleText.popup(runner.player_position(), "UNDO", Color(0.8, 0.9, 1.0, 1.0), 1.4)


func _tick_self_debts(delta: float) -> void:
	_undo_cd = maxf(0.0, _undo_cd - delta)
	if _self_debts.is_empty():
		return
	var paused := tails_left > 0.0 and has("DTE1")
	for i in range(_self_debts.size() - 1, -1, -1):
		var debt: Dictionary = _self_debts[i]
		if paused:
			debt["due"] = float(debt["due"]) + delta
			continue
		if _clock >= float(debt["due"]):
			var owed := float(debt["amount"]) * (1.0 - clampf(float(debt["cancelled"]), 0.0, 1.0))
			if owed > 0.0:
				runner.pay_health(owed, &"undo_debt")
			_self_debts.remove_at(i)


## Killing the greatest contributor cancels half of a self-Debt; each 2D dealt
## to it cancels another 10%. With Fixed Coin, cancelled Debt during Tails
## becomes a 2R blast worth 1D per 5% max HP cancelled.
func _cancel_self_debt(handle: int, dealt: float, killed: bool) -> void:
	if _self_debts.is_empty():
		return
	var max_hp := float(runner.player().get("max_hp"))
	for debt in _self_debts:
		if int(debt["contributor"]) != handle:
			continue
		var before := float(debt["cancelled"])
		if killed:
			debt["cancelled"] = minf(1.0, before + 0.5)
		else:
			debt["dealt"] = float(debt["dealt"]) + dealt
			while float(debt["dealt"]) >= 2.0 * D() and float(debt["cancelled"]) < 1.0:
				debt["dealt"] = float(debt["dealt"]) - 2.0 * D()
				debt["cancelled"] = minf(1.0, float(debt["cancelled"]) + 0.1)
		var cancelled_amount := float(debt["amount"]) * (float(debt["cancelled"]) - before)
		if cancelled_amount > 0.0 and tails_left > 0.0 and has("DTE1") and max_hp > 0.0:
			var blast := D() * (cancelled_amount / max_hp) / 0.05
			runner.spawn_impact(runner.enemy_position(handle) if runner.enemy_alive(handle) else runner.player_position(), blast, AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DTE1", "impact", 1, 0.4), 2.0 * AscensionRunner.R)


func claimed_nouns() -> Array[StringName]:
	var nouns: Array[StringName] = []
	if has("DT10"):
		nouns.append(&"fortune")
	return nouns


func D() -> float:
	return runner.native_damage()


# ---------------------------------------------------------------- rolls

## Ordinary modifiers first (Roll Chance sink, Denial), Snake Eyes last.
func modify_roll_chance(name: StringName, chance: float) -> float:
	var value := chance
	if has("DTS1"):
		var r := float(rank("DTS1"))
		value += 0.25 * r / (r + 80.0)
	if name == &"misfire" and has("DT05"):
		value += _denial_bonus
	if has("DTQ1") and heads_left > 0.0 and _is_core_check(name):
		value = minf(0.95, value + 0.40)
	if has("DTK2"):
		value = 0.5
	return value


func _is_core_check(name: StringName) -> bool:
	return name in [&"twice", &"second_chance_fallback", &"contradiction"]


func wants_guarantee(name: StringName, _proc_power: float) -> bool:
	if name == &"misfire":
		return false
	if _is_core_check(name):
		if heads_left > 0.0 and not has("DTQ1"):
			counters["guarantees"] = int(counters["guarantees"]) + 1
			return true
		if rewrite_left > 0.0:
			counters["guarantees"] = int(counters["guarantees"]) + 1
			return true
	elif rewrite_left > 0.0 and has("DTV1"):
		return true
	if has("DT10") and runner.misfortune() >= 5:
		if runner.spend_misfortune(5):
			_bad_luck_boost = true
			counters["guarantees"] = int(counters["guarantees"]) + 1
			return true
	return false


func wants_reroll(name: StringName) -> bool:
	if not has("DT02") or _reroll_used or name == &"misfire":
		return false
	_reroll_used = true
	counters["rerolls"] = int(counters["rerolls"]) + 1
	return true


func on_roll(name: StringName, success: bool, chance: float) -> void:
	if name == &"misfire":
		return
	if chance >= 1.0:
		return  # guaranteed outcomes neither fail nor reward
	if success:
		if has("DTK1"):
			_loaded_payload = true
	else:
		if has("DT10"):
			runner.add_misfortune(1)
			counters["misfortune_added"] = int(counters["misfortune_added"]) + 1
		if has("DTK1") and _dice_payment_cd <= 0.0:
			_dice_payment_cd = 0.5
			counters["dice_payments"] = int(counters["dice_payments"]) + 1
			runner.pay_health_lethal(0.01 * float(runner.player().get("max_hp")), &"loaded_dice")


## Payload scaling from Loaded Dice and Bad Luck, consumed once.
func _payload_boost() -> Dictionary:
	var damage := 1.0
	var pp := 1.0
	if _loaded_payload:
		_loaded_payload = false
		damage *= 1.0 + 0.5 * runner.keystone_bonus()
		pp *= 1.0 + 0.5 * runner.keystone_bonus()
	if _bad_luck_boost:
		_bad_luck_boost = false
		pp *= 2.0
	return {"damage": damage, "pp": minf(1.0, pp)}


# ---------------------------------------------------------------- native strikes

func decorate_native_impact(impact: Node) -> void:
	var tags: PackedStringArray = impact.get_meta(AscensionTags.META_KEY, PackedStringArray())
	tags = AscensionTags.with_flag(tags, "core_strike")
	impact.set_meta(AscensionTags.META_KEY, tags)
	if tails_left > 0.0:
		impact.radius = float(impact.radius) * (1.0 + 0.4 * float(maxi(1, _tails_stacks)))


func on_native_fire(style: String, _origin: Vector2, target: Vector2, _power: float, _haste: float) -> void:
	_volley += 1
	_reroll_used = false
	if style != "magic":
		return
	var base_damage := D()
	var radius := 0.6 * AscensionRunner.R
	# Twice: a named 20% roll to repeat the strike's geometry.
	var twice_owned := has("DT01")
	var forced := (heads_left > 0.0 or rewrite_left > 0.0)
	if twice_owned or forced:
		var success := forced or runner.roll(&"twice", TWICE_CHANCE, 1.0)
		if success:
			var boost := _payload_boost()
			_echoes.append({"delay": TWICE_DELAY, "pos": target, "damage": 0.5 * base_damage * float(boost["damage"]), "radius": radius, "root": "DT01", "pp": 0.5 * float(boost["pp"]), "flags": PackedStringArray()})
			counters["twice"] = int(counters["twice"]) + 1
	elif has("DT02") or has("DT10"):
		# The fallback check while no other named chance is owned.
		if runner.roll(&"second_chance_fallback", 0.20, 1.0):
			var boost := _payload_boost()
			_echoes.append({"delay": 0.3, "pos": target, "damage": 0.4 * base_damage * float(boost["damage"]), "radius": radius, "root": "DT02", "pp": 0.5 * float(boost["pp"]), "flags": PackedStringArray()})
	if has("DT11"):
		_scar_tissue(target, radius)


func _scar_tissue(center: Vector2, radius: float) -> void:
	var touched: Array = []
	for scar in scars:
		if (scar["pos"] as Vector2).distance_to(center) <= radius + SCAR_RADIUS:
			touched.append(scar)
	for scar in touched:
		scars.erase(scar)
		counters["scar_releases"] = int(counters["scar_releases"]) + 1
		var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DT11", "impact", 1, 0.4, PackedStringArray(["scar_release"]))
		runner.spawn_impact(scar["pos"], 0.5 * D() + float(scar["magnitude"]), tags, AscensionRunner.R)
		for handle in runner.enemies_in_radius(scar["pos"], AscensionRunner.R):
			deposit(handle, 0.5 * D(), "DT11", false)


# ---------------------------------------------------------------- hits

func on_hit(hit: Dictionary) -> void:
	var handle := int(hit["handle"])
	var tags: PackedStringArray = hit["tags"]
	var core_strike := AscensionTags.has_flag(tags, "core_strike")
	var is_debt := AscensionTags.has_flag(tags, "debt")
	var applied := float(hit["applied"])
	if hit["core"] == "magic" and core_strike:
		if has("DT03"):
			_apply_fading(handle)
		if has("DT08"):
			_apply_slow(handle)
		if has("DT06") and not is_debt:
			deposit(handle, DEBT_FRACTION * applied, "core", rewrite_left > 0.0)
		if heads_left > 0.0 and bool(hit["crit"]):
			deposit(handle, 0.5 * D(), "heads", false, true)
		if tails_left > 0.0:
			deposit(handle, 0.3 * D() * float(maxi(1, _tails_stacks)), "tails", false)
	elif core_strike and has("DTA") and not is_debt and has("DT06"):
		deposit(handle, DEBT_LATE_FRACTION * applied, "late", rewrite_left > 0.0)
	if (heads_left > 0.0 or tails_left > 0.0) and has("DTE2"):
		_coin_tagged[handle] = true
	if hit["family"] == AscensionTags.FAMILY_TREE and has("DT08") and not is_debt:
		_contradiction(hit, handle)
	if has("DTF1") and not _self_debts.is_empty():
		_cancel_self_debt(handle, applied, false)
	if bool(hit["is_boss"]) and (heads_left > 0.0 or tails_left > 0.0):
		_coin_boss_damage += applied
		while _coin_boss_damage >= 3.0 * D():
			_coin_boss_damage -= 3.0 * D()
			_coin_refund()


func _apply_fading(handle: int) -> void:
	var rate := 0.15 * D()
	_fading[handle] = {"rate": rate, "left": 2.0, "tick": 0.0}
	runner.status_of(handle)["fading"] = true


func _apply_slow(handle: int) -> void:
	if not _slows.has(handle):
		var base := EnemyWorld.get_speed(handle)
		_slows[handle] = {"left": 2.0, "base": base}
		EnemyWorld.set_speed(handle, base * 0.85)
	else:
		(_slows[handle] as Dictionary)["left"] = 2.0
	runner.status_of(handle)["slow"] = true


func ordinary_statuses(handle: int) -> Array[String]:
	var out: Array[String] = []
	if _fading.has(handle):
		out.append("fading")
	if _slows.has(handle):
		out.append("slow")
	if EnemyStatus.has_status(handle, &"burn"):
		out.append("burn")
	if EnemyStatus.has_status(handle, &"bleed"):
		out.append("bleed")
	return out


func _contradiction(hit: Dictionary, handle: int) -> void:
	var key := "%d:%s" % [handle, String(hit["path"])]
	if _contradicted.has(key):
		return
	var statuses := ordinary_statuses(handle)
	if statuses.size() < 2:
		return
	_contradicted[key] = true
	counters["contradictions"] = int(counters["contradictions"]) + 1
	var remaining := 0.0
	# Consume the shorter of the engine's own statuses; burn stays with its service.
	var fading_left := float((_fading.get(handle, {}) as Dictionary).get("left", INF))
	var slow_left := float((_slows.get(handle, {}) as Dictionary).get("left", INF))
	if fading_left <= slow_left and _fading.has(handle):
		remaining = fading_left * float((_fading[handle] as Dictionary)["rate"])
		_fading.erase(handle)
		runner.clear_status(handle, "fading")
	elif _slows.has(handle):
		_end_slow(handle)
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DT08", "impact", int(hit["gen"]) + 1, 0.4)
	runner.spawn_impact(hit["position"], 0.8 * D() + remaining, tags, AscensionRunner.R * 0.6)


func _end_slow(handle: int) -> void:
	var record: Dictionary = _slows.get(handle, {})
	if not record.is_empty() and runner.enemy_alive(handle):
		EnemyWorld.set_speed(handle, float(record["base"]))
	_slows.erase(handle)
	runner.clear_status(handle, "slow")


# ---------------------------------------------------------------- Debt ledger

## Saves `amount` as Debt on `handle`. `source` groups packets for merging.
func deposit(handle: int, amount: float, source: String, immediate: bool, v_created: bool = false) -> void:
	if amount <= 0.0 or not runner.enemy_alive(handle):
		return
	var buckets: Array = debts.get(handle, [])
	debts[handle] = buckets
	var due := _clock + (0.0 if immediate else DEBT_DUE)
	var merged := false
	if not buckets.is_empty():
		var best: Dictionary = {}
		var best_gap := INF
		for bucket in buckets:
			if String(bucket["source"]) == source and bucket["collect_until"] == null:
				var gap: float = absf(float(bucket["due"]) - due)
				if gap < best_gap:
					best_gap = gap
					best = bucket
		if not best.is_empty():
			best["amount"] = float(best["amount"]) + amount
			best["due"] = minf(float(best["due"]), due)
			merged = true
	if not merged:
		if buckets.size() >= DEBT_BUCKETS:
			var oldest: Dictionary = buckets[0]
			oldest["amount"] = float(oldest["amount"]) + amount
		else:
			buckets.append({"amount": amount, "due": due, "source": source, "born": _clock, "v": v_created or rewrite_left > 0.0, "passed": false, "collect_until": null})
	counters["deposits"] = int(counters["deposits"]) + 1
	_deposit_times.append(_clock)
	# No BattleText line here: the runner already draws "DEBT n  due" over
	# every indebted enemy, and a popup keyed by handle would overwrite that
	# enemy's damage numbers (BattleText merges by key across both).


func _interest(bucket: Dictionary) -> float:
	if not has("DT07"):
		return 1.0
	return 1.0 + minf(INTEREST_CAP, INTEREST_RATE * (_clock - float(bucket["born"])))


## Pending plus collectable Debt on a target, with interest.
func unpaid_debt(handle: int) -> float:
	var total := 0.0
	for bucket in debts.get(handle, []):
		total += float(bucket["amount"]) * _interest(bucket)
	return total


## Spends a target's unpaid Debt (pending and collectable) and returns it.
func collect_debt(handle: int) -> float:
	var total := unpaid_debt(handle)
	debts.erase(handle)
	return total


## Death Debt (MM2): with Pass It On, the ordinary shares travel first; the
## rest is collected and the buckets are marked paid, so Interest never bills
## the player for them.
func collect_for_death_debt(handle: int) -> float:
	var total := unpaid_debt(handle)
	if total <= 0.0:
		return 0.0
	if has("DTF2"):
		var passed := 0
		for other in runner.enemies_in_radius(runner.enemy_position(handle), 3.0 * AscensionRunner.R, handle):
			if passed >= 3:
				break
			_add_packet(other, 0.4 * total, "passed", _clock + 0.5, true)
			passed += 1
		if passed > 0:
			counters["pass_ons"] = int(counters["pass_ons"]) + 1
	debts.erase(handle)
	return total


func pending_bucket_count() -> int:
	var count := 0
	for handle in debts:
		for bucket in debts[handle]:
			if bucket["collect_until"] == null:
				count += 1
	return count


func _tick_debts(delta: float) -> void:
	_dice_payment_cd = maxf(0.0, _dice_payment_cd - delta)
	while not _deposit_times.is_empty() and _clock - _deposit_times[0] > PAYDAY_WINDOW:
		_deposit_times.remove_at(0)
	while not _matured_times.is_empty() and _clock - _matured_times[0] > PAYDAY_WINDOW:
		_matured_times.remove_at(0)
	for handle in debts.keys():
		var buckets: Array = debts.get(handle, [])
		if not runner.enemy_alive(int(handle)):
			_debt_on_corpse(int(handle), buckets)
			continue
		# Damage callbacks can collect, replace or extend this ledger, or kill
		# another debtor from the outer key snapshot.
		for bucket in buckets.duplicate():
			if not is_same(debts.get(handle), buckets):
				break
			if not buckets.has(bucket):
				continue
			if bucket["collect_until"] != null:
				if _clock >= float(bucket["collect_until"]):
					buckets.erase(bucket)
				continue
			if _clock >= float(bucket["due"]):
				# Settle before emitting damage so kills only inherit unpaid Debt.
				if rewrite_left > 0.0:
					bucket["collect_until"] = _clock + COLLECTABLE_WINDOW
				else:
					buckets.erase(bucket)
				_mature(int(handle), bucket, true)
		if buckets.is_empty() and is_same(debts.get(handle), buckets):
			debts.erase(handle)


func _mature(handle: int, bucket: Dictionary, natural: bool) -> void:
	var amount := float(bucket["amount"]) * _interest(bucket)
	if has("DTS2"):
		amount *= 1.0 + 0.005 * sqrt(float(rank("DTS2")))
	if rewrite_left > 0.0 and has("DTV3"):
		amount *= 2.0
	counters["matured"] = int(counters["matured"]) + 1
	counters["debt_damage"] = float(counters["debt_damage"]) + amount
	var flags := PackedStringArray(["debt"])
	if bool(bucket["v"]):
		flags.append("v")
	var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DT06", "debt", 1, DEBT_PP, flags)
	var dealt := runner.damage_enemy(handle, amount, tags)
	if natural:
		_matured_times.append(_clock)
		if dealt > 0.0:
			runner.add_action_charge(1.0, bool(bucket["v"]))
		if has("DTC") and payday_recovery <= 0.0 and payday_left <= 0.0:
			var crowd := _deposit_times.size() >= PAYDAY_DEPOSITS
			var lone := _matured_times.size() >= PAYDAY_BOSS_MATURED
			if crowd or lone:
				_payday()


func _debt_on_corpse(handle: int, buckets: Array) -> void:
	# The target died before paying: Pass It On, Back Pay, or Interest's bill.
	var position := runner.enemy_position(handle)
	var unpaid := 0.0
	var unpaid_count := 0
	for bucket in buckets:
		if bucket["collect_until"] == null:
			unpaid += float(bucket["amount"]) * _interest(bucket)
			unpaid_count += 1
	debts.erase(handle)
	if unpaid <= 0.0:
		return
	if has("DTF2"):
		var receivers := runner.enemies_in_radius(position, 3.0 * AscensionRunner.R, handle)
		var passed := 0
		for other in receivers:
			if passed >= 3:
				break
			_add_packet(other, 0.4 * unpaid, "passed", _clock + 0.5, true)
			passed += 1
		if passed > 0:
			counters["pass_ons"] = int(counters["pass_ons"]) + 1
			return
	if has("DT09"):
		var target := runner.nearest_enemy(position, 3.0 * AscensionRunner.R, handle)
		if target != 0 and runner.enemy_alive(target):
			counters["back_pays"] = int(counters["back_pays"]) + 1
			_add_packet(target, 0.75 * unpaid, "backpay", _clock, true)
			return
	if has("DT07"):
		counters["self_debt"] = int(counters["self_debt"]) + 1
		var max_hp := float(runner.player().get("max_hp"))
		runner.pay_health(minf(0.08, 0.01 * float(unpaid_count)) * max_hp, &"interest")


func _add_packet(handle: int, amount: float, source: String, due: float, passed: bool) -> void:
	if not runner.enemy_alive(handle) or amount <= 0.0:
		return
	var buckets: Array = debts.get(handle, [])
	debts[handle] = buckets
	if buckets.size() >= DEBT_BUCKETS:
		(buckets[0] as Dictionary)["amount"] = float((buckets[0] as Dictionary)["amount"]) + amount
		return
	buckets.append({"amount": amount, "due": due, "source": source, "born": _clock, "v": rewrite_left > 0.0, "passed": passed, "collect_until": null})


func _payday() -> void:
	counters["paydays"] = int(counters["paydays"]) + 1
	payday_left = 0.5
	payday_recovery = 8.0
	runner.note_catastrophe("DTC")
	if BattleText != null:
		BattleText.popup(runner.player_position(), "PAYDAY", Color(1.0, 0.85, 0.2, 1.0), 1.6)
	# Oldest first over 0.5 s: reschedule every pending bucket into the window.
	var all: Array = []
	for handle in debts:
		for bucket in debts[handle]:
			if bucket["collect_until"] == null:
				all.append(bucket)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["born"]) < float(b["born"]))
	for i in range(all.size()):
		(all[i] as Dictionary)["due"] = _clock + 0.5 * float(i) / float(maxi(all.size(), 1))


# ---------------------------------------------------------------- kills

func on_kill(hit: Dictionary, _context: RefCounted) -> void:
	var handle := int(hit["handle"])
	var position: Vector2 = hit["position"]
	var tags: PackedStringArray = hit["tags"]
	var by_debt := AscensionTags.has_flag(tags, "debt")
	if has("DTF1") and not _self_debts.is_empty():
		_cancel_self_debt(handle, 0.0, true)
	if has("DTV2") and rewrite_left > 0.0 and not AscensionTags.has_flag(tags, "replay"):
		_replay(handle, position)
	if has("DTE2") and _coin_tagged.has(handle):
		_coin_tagged.erase(handle)
		var owed := collect_debt(handle)
		counters["loaded_blasts"] = int(counters["loaded_blasts"]) + 1
		var blast := 0.75 * owed if owed > 0.0 else 0.5 * D()
		runner.spawn_impact(position, blast, AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DTE2", "impact", int(hit["gen"]) + 1, 0.4), 1.5 * AscensionRunner.R)
	if debts.has(handle):
		_debt_on_corpse(handle, debts[handle])
	if by_debt and has("DT12"):
		var seeded := 0
		for other in runner.enemies_in_radius(position, 2.0 * AscensionRunner.R, handle):
			if ordinary_statuses(other).size() >= 2:
				_add_packet(other, 0.5 * float(hit["applied"]), "compound", _clock + 1.0, false)
				seeded += 1
		if seeded > 0:
			counters["compound"] = int(counters["compound"]) + 1
	if heads_left > 0.0 or tails_left > 0.0:
		_coin_refund()
		if has("DTQ6") and not AscensionTags.has_flag(tags, "v"):
			_bad_penny(position, handle)
	if rewrite_left > 0.0:
		_rewrite_kills += 1
	_fading.erase(handle)
	_slows.erase(handle)


## Replay (DTV2): each real death during REWRITE repeats its last three
## non-Replay hits at the corpse, 35% damage, original geometry, P 0.3.
func _replay(handle: int, position: Vector2) -> void:
	var history: Array = runner.hit_history(handle)
	for entry in history:
		var damage := 0.35 * float(entry["damage"])
		if damage <= 0.0:
			continue
		var core := AscensionTags.value_of(entry["tags"], "core")
		if core.is_empty():
			core = "magic"
		var tags := AscensionTags.make(core, AscensionTags.FAMILY_TREE, "DTV2", String(entry["kind"]), 2, 0.3, PackedStringArray(["v", "replay"]))
		if String(entry["kind"]) == "slash":
			runner.spawn_slash(position, entry["dir"], damage, tags, float(entry["arc"]), float(entry["radius"]))
		else:
			runner.spawn_impact(position, damage, tags, float(entry["radius"]))
		counters["replays"] = int(counters.get("replays", 0)) + 1


func _bad_penny(position: Vector2, victim: int) -> void:
	var target := runner.nearest_enemy(position, 3.0 * AscensionRunner.R, victim)
	if target == 0 or not runner.enemy_alive(target):
		return
	counters["pennies"] = int(counters["pennies"]) + 1
	_penny_alternate = not _penny_alternate
	if _penny_alternate:
		deposit(target, 0.6 * D(), "penny", true)
	else:
		runner.spawn_impact(runner.enemy_position(target), D(), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DTQ6", "impact", 2, 0.3), AscensionRunner.R)


# ---------------------------------------------------------------- scars, fading, misfire, echoes

func add_scar(position: Vector2, magnitude: float) -> void:
	counters["scars"] = int(counters["scars"]) + 1
	if scars.size() >= SCAR_MAX:
		var nearest: Dictionary = scars[0]
		var best := INF
		for scar in scars:
			var distance := (scar["pos"] as Vector2).distance_to(position)
			if distance < best:
				best = distance
				nearest = scar
		nearest["magnitude"] = float(nearest["magnitude"]) + magnitude
		nearest["life"] = SCAR_LIFE
		return
	scars.append({"pos": position, "magnitude": magnitude, "life": SCAR_LIFE})


func _tick_scars(delta: float) -> void:
	for i in range(scars.size() - 1, -1, -1):
		var scar: Dictionary = scars[i]
		scar["life"] = float(scar["life"]) - delta
		if float(scar["life"]) <= 0.0:
			scars.remove_at(i)


func _tick_fading(delta: float) -> void:
	for handle in _fading.keys():
		var record: Dictionary = _fading[handle]
		if not runner.enemy_alive(int(handle)):
			_fading.erase(handle)
			continue
		record["left"] = float(record["left"]) - delta
		record["tick"] = float(record["tick"]) + delta
		if float(record["tick"]) >= 0.5:
			record["tick"] = 0.0
			counters["fading_ticks"] = int(counters["fading_ticks"]) + 1
			runner.damage_enemy(int(handle), 0.5 * float(record["rate"]), AscensionTags.make("magic", AscensionTags.FAMILY_TREE, "DT03", "fading", 1, 0.0))
		if float(record["left"]) <= 0.0:
			_fading.erase(handle)
			runner.clear_status(int(handle), "fading")
			if runner.enemy_alive(int(handle)):
				_residue_scar(int(handle), float(record["rate"]))
	for handle in _slows.keys():
		var record: Dictionary = _slows[handle]
		record["left"] = float(record["left"]) - delta
		if float(record["left"]) <= 0.0 or not runner.enemy_alive(int(handle)):
			var alive := runner.enemy_alive(int(handle))
			_end_slow(int(handle))
			if alive:
				_residue_scar(int(handle), 0.3 * D())


func _residue_scar(handle: int, rate: float) -> void:
	if not has("DT03"):
		return
	if _clock - float(_scar_cooldown.get(handle, -INF)) < 1.0:
		return
	_scar_cooldown[handle] = _clock
	add_scar(runner.enemy_position(handle), maxf(0.3 * D(), rate))


func _tick_misfire(_delta: float) -> void:
	if not has("DT04") and not (rewrite_left > 0.0):
		return
	var nearby: Array = []
	var radius := AscensionRunner.R
	var center := runner.player_position()
	if rewrite_left > 0.0:
		var rect := runner.camera_rect()
		center = rect.get_center()
		radius = rect.size.length() * 0.5
	ProjectileManager.enemy_projectiles_in_radius(center, radius, nearby)
	for bullet in nearby:
		var id := int(bullet["id"])
		if _seen_projectiles.has(id):
			continue
		_seen_projectiles[id] = true
		if rewrite_left > 0.0:
			ProjectileManager.remove_projectile(id)
			add_scar(bullet["position"], 0.3 * D())
			continue
		counters["misfire_rolls"] = int(counters["misfire_rolls"]) + 1
		if runner.roll(&"misfire", MISFIRE_CHANCE, 1.0):
			counters["misfires"] = int(counters["misfires"]) + 1
			runner.add_action_charge(1.0)
			ProjectileManager.remove_projectile(id)
			add_scar(bullet["position"], 0.3 * D())
			_denial_bonus = 0.0
		elif has("DT05"):
			_denial_bonus = minf(0.25, _denial_bonus + 0.05)
	if _seen_projectiles.size() > 4096:
		_seen_projectiles.clear()


func _tick_echoes(delta: float) -> void:
	if _echoes.is_empty():
		return
	var due: Array = []
	for echo in _echoes:
		echo["delay"] = float(echo["delay"]) - delta
		if float(echo["delay"]) <= 0.0:
			due.append(echo)
	for echo in due:
		_echoes.erase(echo)
		var tags := AscensionTags.make("magic", AscensionTags.FAMILY_TREE, String(echo["root"]), "impact", 1, float(echo["pp"]), echo["flags"])
		runner.spawn_impact(echo["pos"], float(echo["damage"]), tags, float(echo["radius"]))


# ---------------------------------------------------------------- Coin (Q)

func activate_q(id: String) -> Dictionary:
	if id != "DTQ":
		return {"ok": false, "message": "NOT DISTORTION", "cooldown": 0.0}
	if _double_window > 0.0 and not _double_used and has("DTQ2"):
		_double_used = true
		_double_window = 0.0
		_flip(false)
		return {"ok": true, "message": "AGAIN", "cooldown": runner.q_cooldown_left}
	counters["coins"] = int(counters["coins"]) + 1
	_coin_paid = 0.0
	_coin_refunded = 0.0
	_coin_boss_damage = 0.0
	_double_used = false
	if has("DTQ3"):
		_house_edge()
	var flips := 2 if has("DTQ4") else 1
	if runner.encore_cast and not _last_faces.is_empty():
		# Encore repeats the opening cast's faces; health is paid only once.
		for face in _last_faces:
			_flip(true, bool(face), true)
		return {"ok": true, "message": "ENCORE", "cooldown": 0.0}
	# An automatic (Reaction / Method) Coin uses a chosen face, never a blind
	# Tails payment at the densest moment (review F7).
	var chosen := has("DTQ5") or runner.reaction_cast or runner.automatic_cast
	_last_faces.clear()
	for _i in range(flips):
		_flip(chosen)
	return {"ok": true, "message": "HEADS" if heads_left > 0.0 and tails_left <= 0.0 else ("TAILS" if tails_left > 0.0 and heads_left <= 0.0 else "BOTH"), "cooldown": 9.0}


func _flip(chosen_heads: bool, forced_face: bool = false, free: bool = false) -> void:
	var heads_chance := 0.75 if has("DTQ1") else 0.5
	var heads := chosen_heads or runner.rng().randf() < heads_chance
	if free:
		heads = forced_face
	else:
		_last_faces.append(heads)
	var scale := 0.5 if has("DTQ5") else 1.0
	if heads:
		counters["heads"] = int(counters["heads"]) + 1
		var duration := (4.0 if has("DTQ1") else 3.0) * scale
		heads_left = maxf(heads_left, duration) if heads_left <= 0.0 else heads_left + duration
		if BattleText != null:
			BattleText.popup(runner.player_position(), "HEADS", Color(1.0, 0.9, 0.4, 1.0), 1.3)
	else:
		counters["tails"] = int(counters["tails"]) + 1
		_tails_stacks += 1
		var paid := 0.0 if free else runner.pay_health(0.12 * float(runner.player().get("hp")), &"coin_tails")
		_coin_paid += paid
		tails_left = 3.0 * scale
		_double_window = 1.0
		if BattleText != null:
			BattleText.popup(runner.player_position(), "TAILS", Color(1.0, 0.4, 0.4, 1.0), 1.3)


func _house_edge() -> void:
	var consumed: Array = []
	ProjectileManager.consume_enemy_projectiles_in_radius(runner.player_position(), 2.0 * AscensionRunner.R, consumed)
	var index := 0
	while index < consumed.size():
		var group := mini(4, consumed.size() - index)
		add_scar(consumed[index]["position"], 0.2 * D() * float(group))
		index += group


func _coin_refund() -> void:
	var max_hp := float(runner.player().get("max_hp"))
	var room := _coin_paid - _coin_refunded
	if room <= 0.0:
		return
	var amount := minf(0.01 * max_hp, room)
	_coin_refunded += amount
	runner.heal_player(amount, &"coin")


func _tick_coin(delta: float) -> void:
	if heads_left > 0.0:
		heads_left = maxf(0.0, heads_left - delta)
		if heads_left <= 0.0 and has("DTE1") and _heads_bank > 0.0 and float(runner.player().get("hp")) > 0.0:
			# Fixed Coin: the Heads refund lands when the state ends, if alive.
			runner.heal_player(_heads_bank, &"fixed_coin")
			counters["heads_refunds"] = int(counters.get("heads_refunds", 0)) + 1
			_heads_bank = 0.0
	if tails_left > 0.0:
		tails_left = maxf(0.0, tails_left - delta)
		if tails_left <= 0.0:
			_tails_stacks = 0
	if _double_window > 0.0:
		_double_window = maxf(0.0, _double_window - delta)
	if heads_left <= 0.0 and tails_left <= 0.0 and not _coin_tagged.is_empty():
		_coin_tagged.clear()


# ---------------------------------------------------------------- REWRITE (V)

func activate_v(id: String) -> Dictionary:
	if id != "DTV":
		return {"ok": false, "message": "NOT DISTORTION", "cooldown": 0.0}
	counters["rewrites"] = int(counters["rewrites"]) + 1
	rewrite_left = 4.0
	_rewrite_kills = 0
	_rewrite_big_damage = 0.0
	var rect := runner.camera_rect()
	for handle in runner.enemies_in_radius(rect.get_center(), rect.size.length() * 0.5):
		if rect.has_point(runner.enemy_position(handle)):
			deposit(handle, D(), "rewrite", true, true)
	if BattleText != null:
		BattleText.popup(runner.player_position(), "REWRITE", Color(0.8, 0.5, 1.0, 1.0), 1.8)
	return {"ok": true, "message": "REWRITE", "cooldown": 0.0}


func _tick_rewrite(delta: float) -> void:
	if rewrite_left <= 0.0:
		return
	rewrite_left = maxf(0.0, rewrite_left - delta)
	if rewrite_left <= 0.0:
		runner.note_revelation_ended("DTV")
	if rewrite_left <= 0.0 and has("DTV3"):
		var carrying := 0
		for handle in debts:
			for bucket in debts[handle]:
				if bool(bucket["v"]):
					carrying += 1
					break
		var bill := minf(0.70, 0.40 + 0.02 * float(carrying))
		bill -= 0.01 * float(_rewrite_kills)
		bill = maxf(0.0, bill)
		runner.pay_health_lethal(bill * float(runner.player().get("max_hp")), &"the_bill")


# ---------------------------------------------------------------- tick, multipliers, HUD

func tick(delta: float) -> void:
	_clock += delta
	if payday_left > 0.0:
		payday_left = maxf(0.0, payday_left - delta)
	if payday_recovery > 0.0:
		payday_recovery = maxf(0.0, payday_recovery - delta)
	_tick_coin(delta)
	_tick_rewrite(delta)
	_tick_self_debts(delta)
	if has("DT05"):
		ProjectileManager.set_enemy_slow_zone(runner.player_position(), AscensionRunner.R, 0.7)
		_slow_zone_set = true
	elif _slow_zone_set:
		ProjectileManager.clear_enemy_slow_zone()
		_slow_zone_set = false
	_tick_echoes(delta)
	_tick_fading(delta)
	_tick_debts(delta)
	_tick_scars(delta)
	_tick_misfire(delta)
	if _contradicted.size() > 2048:
		_contradicted.clear()


func power_multiplier(core: String) -> float:
	if core == "magic" and tails_left > 0.0:
		return 1.0 + 0.6 * float(maxi(1, _tails_stacks))
	return 1.0


func hud_state(slot: String) -> Dictionary:
	var state := {}
	if slot == "q":
		if heads_left > 0.0:
			state["combat_text"] = "HEADS %.1fs" % heads_left
		elif tails_left > 0.0:
			state["combat_text"] = "TAILS %.1fs" % tails_left
		else:
			state["combat_text"] = "DEBT %d" % int(round(_total_debt()))
	elif slot == "v":
		if rewrite_left > 0.0:
			state["combat_text"] = "REWRITE %.1fs" % rewrite_left
		elif payday_left > 0.0:
			state["combat_text"] = "PAYDAY"
	return state


func _total_debt() -> float:
	var total := 0.0
	for handle in debts:
		total += unpaid_debt(int(handle))
	return total


func collect_draw_points(out: Array) -> void:
	for scar in scars:
		out.append([scar["pos"], SCAR_RADIUS * 0.5, Color(0.7, 0.4, 1.0, 0.22)])
	for echo in _echoes:
		out.append([echo["pos"], float(echo["radius"]), Color(0.6, 0.8, 1.0, 0.15)])
	for handle in debts:
		if runner.enemy_alive(int(handle)):
			var soonest := INF
			for bucket in debts[handle]:
				if bucket["collect_until"] == null:
					soonest = minf(soonest, float(bucket["due"]) - _clock)
			var label := "DEBT %d" % int(round(unpaid_debt(int(handle))))
			if soonest != INF:
				label += " %.1fs" % maxf(0.0, soonest)
			out.append([runner.enemy_position(int(handle)), 2.0, Color(0.8, 0.6, 1.0, 0.9), label])


func describe() -> Dictionary:
	var out := counters.duplicate()
	out["debt_total"] = _total_debt()
	out["buckets"] = pending_bucket_count()
	out["scars_live"] = scars.size()
	out["heads_left"] = heads_left
	out["tails_left"] = tails_left
	out["rewrite_left"] = rewrite_left
	out["misfortune"] = runner.misfortune()
	return out
