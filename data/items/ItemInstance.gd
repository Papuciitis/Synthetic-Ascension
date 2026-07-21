extends Resource
class_name ItemInstance

enum Polarity { POS = 1, NEG = -1 }

const RARITY_QUADRATIC: float = 0.08 # tuned: higher rarities matter, but less runaway # makes higher rarities matter more (k = r * (1 + r*q))
const RARITY_QUAD_CAP: float = 20.0   # allow higher rarity scaling before cap   # safety cap for r in the quadratic scaling

@export var data: ItemData
@export var rolled_mods: StatDelta
@export var rarity: int = 0
@export var polarity: int = Polarity.POS

@export var progress: int = 0
@export var upgrade_meter: float = 0.0
@export var best_pct: float = 0.0


static func from_roll(d: ItemData, r: int, pol: int, roll_pct: float) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = d
	inst.rarity = r
	inst.polarity = (Polarity.POS if pol >= 0 else Polarity.NEG)
	inst._recompute_flat_mods()
	inst.feed_roll(roll_pct)
	return inst


func active_pct() -> float:
	return best_pct


func feed_roll(roll_pct: float) -> void:
	if data == null:
		return

	roll_pct = absf(roll_pct) * (1.0 if polarity == Polarity.POS else -1.0)

	progress += 1

	if polarity == Polarity.POS:
		if roll_pct > best_pct:
			best_pct = roll_pct
	else:
		if roll_pct < best_pct:
			best_pct = roll_pct

	upgrade_meter += absf(roll_pct)

	while upgrade_meter >= 1.0:
		upgrade_meter -= 1.0
		_upgrade()


func _upgrade() -> void:
	if data == null:
		return

	var prev_r := rarity
	rarity += 1
	best_pct = 0.0
	progress = 0
	_recompute_flat_mods()

	print("[ITEM UPGRADE]", data.id, " r", prev_r, "->", rarity, " pol=", ("POS" if polarity == Polarity.POS else "NEG"))



func _recompute_flat_mods() -> void:
	# Flat mods are: base mods (data.mods) + rarity scaling (data.rarity_base * rarity)
	# This keeps conduit items (which have empty mods) behaving the same,
	# while allowing accessories and future items to have a meaningful baseline at rarity 0.
	rolled_mods = (data.mods.copy() if data != null and data.mods != null else StatDelta.new())

	if data != null and data.rarity_base != null:
		var r := float(rarity)
		r = clampf(r, 0.0, RARITY_QUAD_CAP)
		var k := r * (1.0 + r * RARITY_QUADRATIC)
		rolled_mods.max_hp += data.rarity_base.max_hp * k
		rolled_mods.armor += data.rarity_base.armor * k
		rolled_mods.move_speed += data.rarity_base.move_speed * k
		rolled_mods.power += data.rarity_base.power * k
		rolled_mods.haste += data.rarity_base.haste * k
		rolled_mods.luck += data.rarity_base.luck * k
static func from_data(d: ItemData, copies: int = 1, rarity_in: int = 0, polarity_in: int = Polarity.POS) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = d
	inst.rarity = rarity_in
	inst.polarity = (Polarity.POS if polarity_in >= 0 else Polarity.NEG)
	inst._recompute_flat_mods()

	var n := maxi(1, copies)
	for _i in range(n):
		var roll := 0.0
		if d != null and (not is_equal_approx(d.pct_min, 0.0) or not is_equal_approx(d.pct_max, 0.0)):
			roll = Global.roll_percent(Global.run_luck, d.pct_min, d.pct_max)
			roll = absf(roll) * (1.0 if inst.polarity == Polarity.POS else -1.0)
		inst.feed_roll(roll)

	return inst
