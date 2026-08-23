extends RefCounted
class_name ManifestationPairCatalog

## The complete pair matrix over the five nouns: C(5,2) = 10, all authored.
##
## Complete, not "the interesting ones". Hades authors every one of its 28
## god pairs and no god is a singleton; the moment a pair is missing, two nouns
## that a player has deliberately assembled do nothing and the rule they learned
## ("two lit nouns light their pair") stops being true.
##
## THRESHOLD: 2 distinct rules of noun A and 2 of noun B. One threshold, one
## vocabulary - two of a noun lights the noun, two lit nouns light their pair.
## Counting distinct RULES rather than instances is load-bearing: the runner
## deliberately supports two items carrying the same rule, and counting
## instances would let a doubled ring fake every pair of its noun.

const NOUN_THRESHOLD: int = 2

static var _defs: Dictionary = {}
static var _by_pair_key: Dictionary = {}


static func _ensure_built() -> void:
	if not _defs.is_empty():
		return

	var entries: Array[ManifestationPairDef] = [
		ManifestationPairDef.new(
			&"slipstream_foundry",
			"Slipstream Foundry",
			"While you are moving, your shards stop orbiting and string out behind you - each one holding where you left it before snapping back.",
			[&"momentum", &"shard"] as Array[StringName],
			preload("res://effects/manifestations/pairs/SlipstreamFoundry.gd")
		),
		ManifestationPairDef.new(
			&"marching_order",
			"Marching Order",
			"Distance advances your attack rhythm as if you had attacked. Stopping forfeits the beat instead of firing it early.",
			[&"momentum", &"cadence"] as Array[StringName],
			preload("res://effects/manifestations/pairs/MarchingOrder.gd")
		),
		ManifestationPairDef.new(
			&"red_line",
			"Red Line",
			"While wounded, spending Momentum pays out speed and one ignored hit instead of damage.",
			[&"momentum", &"ward"] as Array[StringName],
			preload("res://effects/manifestations/pairs/RedLine.gd")
		),
		ManifestationPairDef.new(
			&"pilgrims_toll",
			"Pilgrim's Toll",
			"The first enemy you touch after a long unbroken run is Marked outright - no Luck roll, no first hit.",
			[&"fortune", &"momentum"] as Array[StringName],
			preload("res://effects/manifestations/pairs/PilgrimsToll.gd")
		),
		ManifestationPairDef.new(
			&"loom",
			"Loom",
			"Your empowered beat fires the whole orbit at your aim and deals no weapon damage of its own.",
			[&"cadence", &"shard"] as Array[StringName],
			preload("res://effects/manifestations/pairs/Loom.gd")
		),
		ManifestationPairDef.new(
			&"reliquary_guard",
			"Reliquary Guard",
			"A hit that would land on you shatters a shard instead and you take none of it. An empty orbit is an unguarded one.",
			[&"shard", &"ward"] as Array[StringName],
			preload("res://effects/manifestations/pairs/ReliquaryGuard.gd")
		),
		ManifestationPairDef.new(
			&"bad_fortune_engine",
			"Bad Fortune Engine",
			"Every failed Luck roll forges a shard instead of banking Misfortune, and every success consumes two.",
			[&"fortune", &"shard"] as Array[StringName],
			preload("res://effects/manifestations/pairs/BadFortuneEngine.gd")
		),
		ManifestationPairDef.new(
			&"death_rattle",
			"Death Rattle",
			"While wounded, breaking your rhythm no longer forfeits the beat - it costs health to hold it.",
			[&"cadence", &"ward"] as Array[StringName],
			preload("res://effects/manifestations/pairs/DeathRattle.gd")
		),
		ManifestationPairDef.new(
			&"tithe_rhythm",
			"Tithe Rhythm",
			"Your empowered beat spends a Follower to fire a second time, and returns them if that shot kills.",
			[&"cadence", &"fortune"] as Array[StringName],
			preload("res://effects/manifestations/pairs/TitheRhythm.gd")
		),
		ManifestationPairDef.new(
			&"debt_collector",
			"Debt Collector",
			"Below a third health every Luck roll succeeds, and every success takes a Follower you cannot refuse.",
			[&"fortune", &"ward"] as Array[StringName],
			preload("res://effects/manifestations/pairs/DebtCollector.gd")
		),
	]

	for def in entries:
		_defs[def.id] = def
		_by_pair_key[def.pair_key()] = def


static func get_def(id: StringName) -> ManifestationPairDef:
	if id == &"":
		return null
	_ensure_built()
	return _defs.get(id, null) as ManifestationPairDef


static func all_ids() -> Array:
	_ensure_built()
	return _defs.keys()


static func for_nouns(a: StringName, b: StringName) -> ManifestationPairDef:
	_ensure_built()
	var pair: Array[StringName] = [a, b]
	pair.sort()
	return _by_pair_key.get(StringName("%s+%s" % [String(pair[0]), String(pair[1])]), null) as ManifestationPairDef


## Which pairs the given noun counts light up. `counts` is noun -> number of
## DISTINCT equipped rules declaring it (ManifestationRunner.get_noun_counts()).
static func active_for_counts(counts: Dictionary) -> Array[ManifestationPairDef]:
	_ensure_built()
	var lit: Array[StringName] = []
	for noun in counts:
		if int(counts[noun]) >= NOUN_THRESHOLD:
			lit.append(noun)
	lit.sort()

	var out: Array[ManifestationPairDef] = []
	for i in range(lit.size()):
		for j in range(i + 1, lit.size()):
			var def := for_nouns(lit[i], lit[j])
			if def != null:
				out.append(def)
	return out


## Tooltip/Run Sheet text with real numbers, rendered on a DETACHED node exactly
## like ManifestationCatalog.describe(): only `pair_definition` and the scaling
## helpers are readable, never `player`, `state` or the tree.
static func describe(id: StringName, mean_rarity: float = 0.0) -> String:
	var def := get_def(id)
	if def == null:
		return ""
	if def.logic == null:
		return def.rule
	var node: Object = def.logic.new()
	var effect := node as ManifestationPairEffect
	if effect == null:
		if node is Node:
			(node as Node).free()
		return def.rule
	effect.pair_definition = def
	effect.set_contributor_rarity(mean_rarity)
	var text: String = effect.describe()
	effect.free()
	return text if text.strip_edges() != "" else def.rule
