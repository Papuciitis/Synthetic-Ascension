class_name SetScaling
extends RefCounted

## Set bonus growth (balance revision 2, section 4): one profile from the
## set's mean effective rank, with named channels so no effect grows every
## dimension through one number.
##
##   stat      flat tier bonuses (HP, armour, Power, Luck): anchors at
##             ranks 0/1/6/15/30, the last slope continued
##   damage    every set payload's damage; replaces the old strength factor
##             and is never multiplied by legacy potency as well
##   rate      movement and Haste from tiers and Overclock: 1 through R1,
##             then 1 + 0.5 * (1 - exp(-(r - 1) / 12))
##   control   radius, knockback, stun: the old potency at min(r, 15)
##   density   projectile and hit counts inside their existing caps: the old
##             potency at min(r, 15)
##   frequency existing rank-based trigger thresholds: the old potency at
##             min(r, 15); minimum cooldowns and action locks stay

const ANCHOR_RANKS: Array = [0.0, 1.0, 6.0, 15.0, 30.0]
const STAT_ANCHORS: Array = [1.0, 1.0, 1.5, 2.5, 4.0]
const DAMAGE_ANCHORS: Array = [1.0, 1.5, 2.025, 2.85, 4.20]
const RATE_TAU := 12.0
const BOUNDED_RANK := 15.0
const CHANNELS: Array = ["stat", "damage", "rate", "control", "density", "frequency"]


static func _points(values: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(values.size()):
		out.append(Vector2(float(ANCHOR_RANKS[index]), float(values[index])))
	return out


static func profile(mean_rank: float) -> Dictionary:
	var r := maxf(0.0, mean_rank if is_finite(mean_rank) else 0.0)
	var bounded := RarityMath.potency(minf(r, BOUNDED_RANK))
	return {
		"stat": ItemScaling.sample_anchors(r, _points(STAT_ANCHORS)),
		"damage": ItemScaling.sample_anchors(r, _points(DAMAGE_ANCHORS)),
		"rate": 1.0 if r <= 1.0 else 1.0 + 0.5 * (1.0 - exp(-(r - 1.0) / RATE_TAU)),
		"control": bounded,
		"density": bounded,
		"frequency": bounded,
	}


static func neutral() -> Dictionary:
	return profile(0.0)


## Scales a tier's flat bonuses by channel: positive HP/armour/Power/Luck by
## `stat`, positive movement/Haste by `rate`; negative values (Gravemarch's
## movement drawback) stay fixed.
static func scaled_tier_mods(mods: StatDelta, scaling: Dictionary) -> StatDelta:
	var out := StatDelta.new()
	if mods == null:
		return out
	var stat := float(scaling.get("stat", 1.0))
	var rate := float(scaling.get("rate", 1.0))
	out.max_hp = mods.max_hp * (stat if mods.max_hp > 0.0 else 1.0)
	out.armor = mods.armor * (stat if mods.armor > 0.0 else 1.0)
	out.power = mods.power * (stat if mods.power > 0.0 else 1.0)
	out.luck = mods.luck * (stat if mods.luck > 0.0 else 1.0)
	out.move_speed = mods.move_speed * (rate if mods.move_speed > 0.0 else 1.0)
	out.haste = mods.haste * (rate if mods.haste > 0.0 else 1.0)
	return out
