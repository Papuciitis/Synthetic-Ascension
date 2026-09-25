extends PrecisionEngine
class_name PrecisionEngineV5
## Ranged V5 Precision (handoff 2026-09-25, spec §2): the V4 control loop with
## selective ordinary ranks, the Smart Rounds -15% test change and the Firing
## Squad boss fallback. Everything unlisted inherits the V4 behaviour.

## PRC boss fallback: one physical projectile root dealing >= 12D total to a
## single elite/boss across >= 3 separate physical hit events (spec §2.3).
const SQUAD_BOSS_DAMAGE_D := 12.0
const SQUAD_BOSS_HITS := 3

var _boss_roots: Dictionary = {}   # "cast|handle" -> {damage, hits}


func _read_threshold() -> float:
	return [3.0, 2.5, 2.0][clampi(rank("PR01"), 1, 3) - 1]


func _pierce_bonus() -> int:
	return [2, 3, 4, 5][clampi(rank("PR03"), 1, 4) - 1]


func _aim_seconds() -> float:
	return [0.80, 0.65, 0.50][clampi(rank("PR05"), 1, 3) - 1]


func _terrain_bounces() -> int:
	return clampi(rank("PR06"), 1, 2)


func _return_fraction() -> float:
	var ranked: float = [0.60, 0.75, 0.90][clampi(rank("PR07"), 1, 3) - 1]
	return maxf(ranked, 0.9 if has("PRK2") else 0.0)


func _split_angles() -> Array:
	match clampi(rank("PR09"), 1, 3):
		2:
			return [-24.0, 0.0, 24.0]
		3:
			return [-30.0, -10.0, 10.0, 30.0]
	return [-20.0, 20.0]


func _crossing_window() -> float:
	return 0.65 if rank("PR11") >= 2 else 0.50


func _spare_cap() -> int:
	return [3, 4, 6][clampi(rank("PR12"), 1, 3) - 1]


## Smart Rounds test change: -15% Core shot damage instead of -20% (§2.2).
func _smart_rounds_scale() -> float:
	return 0.85


## PR02 ranks: a Weak Point created by Far Shot consumes for +0.2D / +0.4D
## more; other Weak Points stay +1D (metadata, never stacking with PR01).
func modify_outgoing_damage(preview: Dictionary, raw: float) -> float:
	var damage := super.modify_outgoing_damage(preview, raw)
	var handle := int(preview["handle"])
	if damage > raw and rank("PR02") >= 2 and _exposed_at_hit.has(handle):
		if String(_exposed_origin.get(handle, "")) == "far_shot":
			damage += (0.4 if rank("PR02") >= 3 else 0.2) * D()
	return damage


## The boss fallback watches physical projectile hits per root on one durable
## target. Burn ticks and Q beams never qualify (no projectile id).
func on_hit(hit: Dictionary) -> void:
	super.on_hit(hit)
	if not has("PRC") or _squad_recovery > 0.0:
		return
	if int(hit["projectile_id"]) == 0 or hit["core"] != "ranged":
		return
	if not (bool(hit["is_elite"]) or bool(hit["is_boss"])):
		return
	var cast := AscensionTags.value_of(hit["tags"], "cast")
	if cast.is_empty():
		return
	var key := "%s|%d" % [cast, int(hit["handle"])]
	var record: Dictionary = _boss_roots.get(key, {"damage": 0.0, "hits": 0})
	record["damage"] = float(record["damage"]) + float(hit["applied"])
	record["hits"] = int(record["hits"]) + 1
	_boss_roots[key] = record
	if int(record["hits"]) >= SQUAD_BOSS_HITS and float(record["damage"]) >= SQUAD_BOSS_DAMAGE_D * D():
		_boss_roots.erase(key)
		counters["squad_boss_triggers"] = int(counters.get("squad_boss_triggers", 0)) + 1
		_firing_squad(cast)
	elif _boss_roots.size() > 128:
		_boss_roots.clear()


func on_kill(hit: Dictionary, context: RefCounted) -> void:
	super.on_kill(hit, context)
	var handle := int(hit["handle"])
	for key in _boss_roots.keys():
		if String(key).ends_with("|%d" % handle):
			_boss_roots.erase(key)


func describe() -> Dictionary:
	var out := super.describe()
	out["v5"] = true
	return out
