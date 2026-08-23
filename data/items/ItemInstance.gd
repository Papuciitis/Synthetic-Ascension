extends Resource
class_name ItemInstance

enum Polarity { POS = 1, NEG = -1 }

@export var data: ItemData
@export var rolled_mods: StatDelta
@export var rarity: int = 0
@export var polarity: int = Polarity.POS

@export var progress: int = 0
@export var upgrade_meter: float = 0.0
@export var best_pct: float = 0.0

# Player protection flag. Locked items are never eligible for trade, discard,
# automatic replacement or duplicate-cleanup actions.
@export var locked: bool = false

func is_locked() -> bool:
	return locked

func toggle_locked() -> bool:
	locked = not locked
	emit_changed()
	return locked

func snapshot_copy() -> ItemInstance:
	# Transaction snapshots must not share mutable ItemInstance/StatDelta state
	# with the live inventory, otherwise duplicate feeding can survive an undo.
	var copy := ItemInstance.new()
	copy.data = data
	copy.rolled_mods = rolled_mods.copy() if rolled_mods != null else null
	copy.rarity = rarity
	copy.polarity = polarity
	copy.progress = progress
	copy.upgrade_meter = upgrade_meter
	copy.best_pct = best_pct
	copy.locked = locked
	return copy


static func from_roll(d: ItemData, r: int, pol: int, roll_pct: float) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = d
	inst.rarity = r
	inst.polarity = (Polarity.POS if pol >= 0 else Polarity.NEG)
	inst.best_pct = absf(roll_pct) * (1.0 if inst.polarity == Polarity.POS else -1.0)
	inst.progress = 1
	inst._recompute_flat_mods()
	return inst


func active_pct() -> float:
	return best_pct


func feed_roll(roll_pct: float) -> void:
	if data == null:
		return
	var incoming := ItemInstance.from_roll(data, rarity, polarity, roll_pct)
	merge_from(incoming)


func can_merge(incoming: ItemInstance) -> bool:
	return (
		incoming != null
		and incoming != self
		and data != null
		and incoming.data != null
		and data.id == incoming.data.id
		and int(polarity) == int(incoming.polarity)
		and not locked
		and not incoming.locked
	)


func merge_from(incoming: ItemInstance) -> bool:
	if not can_merge(incoming):
		return false
	var quality := RarityMath.merge_quality(incoming.data, incoming.best_pct)
	var mass := RarityMath.merge_mass(incoming.rarity, rarity, quality)
	if incoming.upgrade_meter > 0.0:
		mass += RarityMath.merge_mass(
			incoming.rarity + 1,
			rarity,
			incoming.upgrade_meter
		)
	upgrade_meter += mass
	progress += maxi(1, incoming.progress)
	if polarity == Polarity.POS:
		best_pct = maxf(best_pct, incoming.best_pct)
	else:
		# Default: merging STABILIZES a curse — the mildest roll survives,
		# so duplicate progression never ruins a deliberately mild NEG item
		# (Ballast-style builds). Corruption Engine inverts the meaning of
		# NEG progression: while it is equipped, merging DEEPENS the curse.
		var deepen_curses: bool = (
			Global != null
			and Global.permanent_augment_ids.has(&"augment_corruption_engine")
		)
		if deepen_curses:
			best_pct = minf(best_pct, incoming.best_pct)
		else:
			best_pct = maxf(best_pct, incoming.best_pct)
	while upgrade_meter >= 1.0 - 0.000001:
		# Each rarity step doubles the required absolute merge mass.
		upgrade_meter = maxf(0.0, upgrade_meter - 1.0) * 0.5
		_upgrade()
	return true


func _upgrade() -> void:
	if data == null:
		return

	rarity += 1
	_recompute_flat_mods()

func _recompute_flat_mods() -> void:
	# Flat mods are: base mods (data.mods) + rarity scaling (data.rarity_base * rarity)
	# This keeps conduit items (which have empty mods) behaving the same,
	# while allowing accessories and future items to have a meaningful baseline at rarity 0.
	rolled_mods = (data.mods.copy() if data != null and data.mods != null else StatDelta.new())

	if data != null and data.rarity_base != null:
		var k := RarityMath.potency(float(rarity)) - 1.0
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
	inst.progress = 1
	for copy_index in range(n):
		var roll := 0.0
		if d != null and (not is_equal_approx(d.pct_min, 0.0) or not is_equal_approx(d.pct_max, 0.0)):
			roll = Global.roll_percent(Global.run_luck, d.pct_min, d.pct_max)
			roll = absf(roll) * (1.0 if inst.polarity == Polarity.POS else -1.0)
		if copy_index == 0:
			inst.best_pct = roll
		elif d != null:
			inst.feed_roll(roll)

	return inst
