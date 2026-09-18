extends Node
class_name SetEffectBase

@export var effect_id: StringName = &""

@export var tooltip_short: String = ""
@export_multiline var tooltip_long: String = ""


# Filled by SetRunner.setup(...)
var player: Node = null

# Filled by SetRunner when the effect comes from a set tier.
# Used so set strength can scale with equipped item rarity.
var source_set_id: StringName = &""
var set_count: int = 0
var set_avg_rarity: float = 0.0
var set_strength: float = 1.0
## Balance revision 2 (section 4): the named channels from SetScaling.profile
## of the set's mean effective rank. Effects read these; set_strength stays
## for callers that have not migrated and is never combined with `damage`.
var set_scaling: Dictionary = SetScaling.neutral()

func setup(p: Node) -> void:
	player = p

# Optional richer setup (SetRunner will prefer this if present).
func setup_set(p: Node, set_id: StringName, count: int, avg_rarity: float, strength: float) -> void:
	setup(p)
	set_set_scaling(set_id, count, avg_rarity, strength)

# Called whenever inventory changes while this effect stays active.
func set_set_scaling(set_id: StringName, count: int, avg_rarity: float, strength: float) -> void:
	source_set_id = set_id
	set_count = count
	set_avg_rarity = avg_rarity
	set_strength = maxf(0.1, strength)
	set_scaling = SetScaling.profile(avg_rarity)


func channel(name: String) -> float:
	return float(set_scaling.get(name, 1.0))

func get_move_speed_multiplier() -> float:
	return 1.0

func get_haste_multiplier() -> float:
	return 1.0

func get_tooltip_short() -> String:
	return tooltip_short

func get_tooltip_long() -> String:
	return tooltip_long


## Telemetry-only provenance for the balance recorder: this set, its active
## tier and the named payload. Passed as the damage payload; it is not a
## HitLedger, so nothing in combat reads it.
func balance_provenance(emitter: String) -> BalanceProvenance:
	var origin := "set:%s:%d" % [String(source_set_id), set_count]
	return BalanceAttribution.provenance(origin, origin + ":" + emitter, "set")
