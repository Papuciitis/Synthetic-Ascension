extends RefCounted
class_name ManifestationCatalog

## The curated Manifestation library.
##
## RNG only ever answers "which one did this item get?". It never assembles an
## effect out of dictionaries - every rule in here is handcrafted, and several
## deliberately share a `family` so that unrelated items accidentally build an
## engine (crit -> shard -> halo -> volley) without any set membership.
##
## Constraints this file enforces:
##   1. One Manifestation per item, ever.
##   2. Not every item rolls one; rings/offhands are the casino slots.
##   3. Slot weighting picks the POOL, not just the chance.

const SLOT_HP := 0
const SLOT_ARMOR := 1
const SLOT_MOVE := 2
const SLOT_POWER := 3
const SLOT_HASTE := 4
const SLOT_LUCK := 5
const SLOT_OFFHAND := 6
const SLOT_RING := 7

## Illustrative, not a balance commitment. Rings and offhands are where the
## run gets weird; main equipment stays mostly a reliable stat/set spine.
const SLOT_CHANCE: Dictionary = {
	SLOT_HP: 0.22,
	SLOT_ARMOR: 0.22,
	SLOT_MOVE: 0.26,
	SLOT_POWER: 0.35,
	SLOT_HASTE: 0.35,
	SLOT_LUCK: 0.30,
	SLOT_OFFHAND: 0.60,
	SLOT_RING: 0.70,
}

## A curse is unstable material: corrupted items develop anomalies more
## readily. Small on purpose - it is a reason to look at NEG items, not a
## reason to only wear them.
const NEG_CHANCE_BONUS: float = 0.08

## Luck bends the odds a little, the same shallow way it bends everything else.
const LUCK_CHANCE_SCALE: float = 0.12

static var _defs: Dictionary = {}
static var _by_slot: Dictionary = {}


static func _ensure_built() -> void:
	if not _defs.is_empty():
		return

	var entries: Array[ManifestationDef] = [
		# --- movement --------------------------------------------------------
		ManifestationDef.new(
			&"pilgrims_momentum",
			"Pilgrim's Momentum",
			"Travelling without stopping builds Momentum. At full Momentum your next attack fires twice.",
			[&"momentum", &"cadence"] as Array[StringName],
			[SLOT_MOVE, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/PilgrimsMomentum.gd"),
			1.2
		),
		ManifestationDef.new(
			&"anchor_rite",
			"Anchor Rite",
			"Standing still builds Stability. At full Stability your attacks hit far harder and carry through enemies. Moving drains it.",
			[&"momentum", &"cadence"] as Array[StringName],
			[SLOT_MOVE, SLOT_ARMOR, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/AnchorRite.gd"),
			1.0
		),
		ManifestationDef.new(
			&"sunder_wake",
			"Sunder Wake",
			"Attacking spends all Momentum and tears a shockwave out of the ground where it lands.",
			[&"momentum"] as Array[StringName],
			[SLOT_MOVE, SLOT_OFFHAND, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/SunderWake.gd"),
			1.0
		),

		# --- attack ----------------------------------------------------------
		ManifestationDef.new(
			&"third_litany",
			"Third Litany",
			"Every third attack is empowered - but only if you let the second one finish. Panic-firing forfeits the litany.",
			[&"cadence"] as Array[StringName],
			[SLOT_POWER, SLOT_HASTE, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/ThirdLitany.gd"),
			1.0
		),
		ManifestationDef.new(
			&"stored_violence",
			"Stored Violence",
			"While you are not attacking, Violence accumulates. Your next attack releases all of it at once.",
			[&"cadence"] as Array[StringName],
			[SLOT_POWER, SLOT_OFFHAND, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/StoredViolence.gd"),
			1.0
		),
		ManifestationDef.new(
			&"predestination_sigil",
			"Predestination Sigil",
			"Your first hit on an elite Marks it. The Mark takes enormous extra damage, everything else takes less, and killing it detonates the Mark.",
			[&"shard"] as Array[StringName],
			[SLOT_POWER, SLOT_HASTE, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/PredestinationSigil.gd"),
			0.9
		),

		ManifestationDef.new(
			&"fever_litany",
			"Fever Litany",
			"Attacks fired in quick succession stack Fever, and Fever is Haste. Let the chain lapse and it all goes at once.",
			[&"cadence"] as Array[StringName],
			[SLOT_HASTE, SLOT_POWER, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/FeverLitany.gd"),
			1.0
		),

		# --- defence / HP ----------------------------------------------------
		ManifestationDef.new(
			&"impact_scripture",
			"Impact Scripture",
			"Taking a hit spends all Momentum and detonates it around you.",
			[&"momentum", &"ward"] as Array[StringName],
			[SLOT_HP, SLOT_ARMOR, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/ImpactScripture.gd"),
			1.0
		),
		ManifestationDef.new(
			&"martyr_circuit",
			"Martyr Circuit",
			"Healthy, you attack slower. Wounded, you accelerate. Near death, your attacks echo.",
			[&"ward", &"cadence"] as Array[StringName],
			[SLOT_HP, SLOT_ARMOR, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/MartyrCircuit.gd"),
			0.9
		),
		ManifestationDef.new(
			&"retaliation_writ",
			"Retaliation Writ",
			"You evade more often, and every evade answers with a retaliation nova.",
			[&"ward", &"momentum"] as Array[StringName],
			[SLOT_ARMOR, SLOT_MOVE, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/RetaliationWrit.gd"),
			1.0
		),

		ManifestationDef.new(
			&"scar_tissue",
			"Scar Tissue",
			"You refuse most of the healing you receive, and every point refused becomes Armour that slowly bleeds away.",
			[&"ward"] as Array[StringName],
			[SLOT_HP, SLOT_ARMOR, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/ScarTissue.gd"),
			1.0
		),

		# --- Luck / Followers ------------------------------------------------
		ManifestationDef.new(
			&"broken_providence",
			"Broken Providence",
			"Every attack that fails its Lucky Crit banks Misfortune. Your next Lucky Crit spends all of it at once.",
			[&"fortune"] as Array[StringName],
			[SLOT_LUCK, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/BrokenProvidence.gd"),
			1.0
		),
		ManifestationDef.new(
			&"tithe_furnace",
			"Tithe Furnace",
			"Every eighth attack burns a Follower to empower itself. It refuses to spend below your reconstruction cost.",
			[&"cadence", &"fortune"] as Array[StringName],
			[SLOT_LUCK, SLOT_OFFHAND, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/TitheFurnace.gd"),
			0.9
		),

		# --- shards ----------------------------------------------------------
		ManifestationDef.new(
			&"orbiting_testament",
			"Orbiting Testament",
			"Lucky Crits forge a synthetic shard into orbit around you. Shards shred whatever they pass through.",
			[&"shard", &"fortune"] as Array[StringName],
			[SLOT_OFFHAND, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/OrbitingTestament.gd"),
			1.1
		),
		ManifestationDef.new(
			&"splinter_dividend",
			"Splinter Dividend",
			"Elites shatter when they die, throwing their fragments into your orbit.",
			[&"shard"] as Array[StringName],
			[SLOT_OFFHAND, SLOT_POWER, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/SplinterDividend.gd"),
			1.0
		),
		ManifestationDef.new(
			&"vector_halo",
			"Vector Halo",
			"Every tenth attack sheds a shard into orbit, and your orbit holds more. Dashing launches the whole halo along your dash.",
			[&"shard", &"cadence"] as Array[StringName],
			[SLOT_OFFHAND, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/VectorHalo.gd"),
			1.0
		),

		# --- exploration / objectives ----------------------------------------
		ManifestationDef.new(
			&"heretical_cartography",
			"Heretical Cartography",
			"Walking into somewhere you have never been rewards you. The bonus stacks and completing a secondary extends it.",
			[&"fortune"] as Array[StringName],
			[SLOT_LUCK, SLOT_MOVE, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/HereticalCartography.gd"),
			1.0
		),
		ManifestationDef.new(
			&"overtime_gospel",
			"Overtime Gospel",
			"Once the Exit Rite is ready, every moment you refuse to leave makes you stronger - and hunted faster.",
			[&"fortune", &"ward"] as Array[StringName],
			[SLOT_HP, SLOT_LUCK, SLOT_OFFHAND, SLOT_RING] as Array[int],
			preload("res://effects/manifestations/logic/OvertimeGospel.gd"),
			0.8
		),
	]

	for def in entries:
		_defs[def.id] = def
		for slot in def.slots:
			if not _by_slot.has(slot):
				_by_slot[slot] = ([] as Array[ManifestationDef])
			(_by_slot[slot] as Array[ManifestationDef]).append(def)


static func get_def(id: StringName) -> ManifestationDef:
	if id == &"":
		return null
	_ensure_built()
	return _defs.get(id, null) as ManifestationDef


static func all_ids() -> Array:
	_ensure_built()
	return _defs.keys()


static func pool_for_slot(slot: int) -> Array[ManifestationDef]:
	_ensure_built()
	var pool: Variant = _by_slot.get(slot, null)
	if pool == null:
		return [] as Array[ManifestationDef]
	return pool as Array[ManifestationDef]


static func slot_chance(slot: int, polarity: int = ItemInstance.Polarity.POS, luck: float = 0.0) -> float:
	if not SLOT_CHANCE.has(slot):
		return 0.0
	var chance := float(SLOT_CHANCE[slot])
	if polarity == ItemInstance.Polarity.NEG:
		chance += NEG_CHANCE_BONUS
	chance += LuckResolver.effective(luck) * LUCK_CHANCE_SCALE
	return clampf(chance, 0.0, 0.95)


## The single entry point every drop path uses. Returns &"" for "this item is
## an ordinary item", which is the common case for main equipment.
## Prerequisite weighting. A rule whose noun the player already carries is more
## likely to be the one that rolls, which is what turns "two of a noun" from a
## coincidence into something a run can actually build toward.
##
## Deliberately biases the PICK, never the CHANCE: slot_chance() carries a
## separate promise ("rings are the casino, main equipment is a reliable spine")
## that the test suite pins to within 0.04, and letting synergy raise the chance
## would snowball into MORE items rather than better-matched ones.
const BOND_PER_TAG: float = 1.0
const BOND_DUO_BONUS: float = 2.0


static func roll_for(
	data: ItemData,
	polarity: int,
	luck: float,
	rng: RandomNumberGenerator,
	held_tags: Dictionary = {}
) -> StringName:
	if data == null or rng == null:
		return &""
	var slot := int(data.equip_slot)
	if slot < 0:
		return &""
	var pool := pool_for_slot(slot)
	if pool.is_empty():
		return &""
	if rng.randf() > slot_chance(slot, polarity, luck):
		return &""
	return _weighted_pick(pool, rng, held_tags)


## How much a rule's weight is multiplied by, given what the player already
## wears. Both nouns of a two-noun rule held is the strongest pull, mirroring
## the way a Duo needs two prerequisites rather than one.
static func bond_multiplier(def: ManifestationDef, held_tags: Dictionary) -> float:
	if def == null or held_tags.is_empty():
		return 1.0
	var matched := 0
	for tag in def.tags:
		if int(held_tags.get(tag, 0)) > 0:
			matched += 1
	if matched <= 0:
		return 1.0
	return 1.0 + BOND_PER_TAG * float(matched) + (BOND_DUO_BONUS if matched >= 2 else 0.0)


static func _weighted_pick(
	pool: Array[ManifestationDef],
	rng: RandomNumberGenerator,
	held_tags: Dictionary = {}
) -> StringName:
	var weights: Array[float] = []
	var total := 0.0
	for def in pool:
		var w := def.weight * bond_multiplier(def, held_tags)
		weights.append(w)
		total += w
	if total <= 0.0:
		return &""
	var target := rng.randf() * total
	for index in range(pool.size()):
		target -= weights[index]
		if target <= 0.0:
			return pool[index].id
	return pool[pool.size() - 1].id


static func display_name(id: StringName) -> String:
	var def := get_def(id)
	return def.display_name if def != null else ""


static func rule_text(id: StringName) -> String:
	var def := get_def(id)
	return def.rule if def != null else ""


## Tooltip text with THIS instance's real numbers in it.
##
## The logic node is built detached and only its `item`/`definition` fields are
## set - setup_manifestation() is never called, so describe() implementations
## must read nothing but `item`, `definition`, potency() and threshold_scale().
static func describe(id: StringName, inst: ItemInstance) -> String:
	var def := get_def(id)
	if def == null:
		return ""
	if def.logic == null:
		return def.rule
	var node: Object = def.logic.new()
	var effect := node as ManifestationEffect
	if effect == null:
		if node is Node:
			(node as Node).free()
		return def.rule
	effect.item = inst
	effect.definition = def
	var text: String = effect.describe()
	effect.free()
	return text if text.strip_edges() != "" else def.rule


static func tags_of(id: StringName) -> Array[StringName]:
	var def := get_def(id)
	return def.tags if def != null else ([] as Array[StringName])


## Every rule that declares `tag`. A tag with fewer than two members can never
## produce an engine and is a catalog bug, not a design choice.
static func rules_with_tag(tag: StringName) -> Array[StringName]:
	_ensure_built()
	var out: Array[StringName] = []
	for id in _defs:
		if (_defs[id] as ManifestationDef).has_tag(tag):
			out.append(id)
	return out
