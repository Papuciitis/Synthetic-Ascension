extends RefCounted
class_name AugmentDuos

## Duos (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §1): a rule
## two equipped augments unlock together, dealt as a DUO card once both are
## at LEVEL_REQUIRED. A Duo acts only while both members are equipped; the
## effects that carry it ask Global.augment_duo_active(). The numbers each
## hook reads live here too, so the card, the Grimoire and the hook agree.

const LEVEL_REQUIRED := 3

const LIGHTNING_RODS := &"duo_lightning_rods"
const PHANTOM_STEP := &"duo_phantom_step"
const STATIC_BROOD := &"duo_static_brood"
const BULWARK_ENGINE := &"duo_bulwark_engine"
const SLIPSTREAM_COIL := &"duo_slipstream_coil"
const LOADED_DICE := &"duo_loaded_dice"

const DUOS := {
	LIGHTNING_RODS: {
		"name": "Lightning Rods",
		"members": [&"augment_magic_missile", &"augment_tesla_aura"],
		"rule": "Every missile hit arcs to 2 more enemies for 60% of its damage.",
		"values": {"arcs": 2, "damage_mul": 0.6, "range": 170.0},
	},
	PHANTOM_STEP: {
		"name": "Phantom Step",
		"members": [&"augment_blink_hex", &"augment_spirit_slash"],
		"rule": "Every blink cuts the 3 enemies nearest where you land with a free Spirit Slash.",
		"values": {"targets": 3, "range": 220.0},
	},
	STATIC_BROOD: {
		"name": "Static Brood",
		"members": [&"augment_summon_spiderlings", &"augment_tesla_aura"],
		"rule": "Spiderling bites leap to one more enemy for the full bite and a short stun.",
		"values": {"range": 150.0, "stun": 0.1},
	},
	BULWARK_ENGINE: {
		"name": "Bulwark Engine",
		"members": [&"augment_reflect_shield", &"augment_stamina_core"],
		"rule": "A perfect parry heals 6% of max HP and takes 2 s off Stamina Core's cooldown (at most once a second).",
		"values": {"heal_fraction": 0.06, "cooldown_refund": 2.0, "gap_ms": 1000},
	},
	SLIPSTREAM_COIL: {
		"name": "Slipstream Coil",
		"members": [&"augment_sprint_servos", &"augment_tesla_aura"],
		"rule": "While you move, Tesla Aura pulses 50% faster.",
		"values": {"tick_mul": 1.0 / 1.5},
	},
	LOADED_DICE: {
		"name": "Loaded Dice",
		"members": [&"augment_lucky_charm", &"augment_gamblers_rite"],
		"rule": "A lucky crit near an enemy recruits a Follower (once a second); the Rite's chance +15 points.",
		"values": {"crit_gap_ms": 1000, "rite_bonus": 0.15, "witness_range": 600.0},
	},
}


static func ids() -> Array:
	var out: Array = DUOS.keys()
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func is_duo(id: StringName) -> bool:
	return DUOS.has(id)


static func members(id: StringName) -> Array:
	var row: Dictionary = DUOS.get(id, {})
	return row.get("members", [])


static func display_name(id: StringName) -> String:
	var row: Dictionary = DUOS.get(id, {})
	return String(row.get("name", ""))


static func rule(id: StringName) -> String:
	var row: Dictionary = DUOS.get(id, {})
	return String(row.get("rule", ""))


static func value(id: StringName, key: String, fallback: float = 0.0) -> float:
	var row: Dictionary = DUOS.get(id, {})
	var values: Dictionary = row.get("values", {})
	return float(values.get(key, fallback))


## Duos whose members are both equipped at `level_required` or above and
## that are not active yet, in id order.
static func ready_duos(equipped: Array, levels: Dictionary, active: Dictionary, level_required: int) -> Array:
	var out: Array = []
	for id in ids():
		if active.has(String(id)):
			continue
		var ok := true
		for member in members(id):
			if not equipped.has(member) or int(levels.get(String(member), 1)) < level_required:
				ok = false
				break
		if ok:
			out.append(id)
	return out
