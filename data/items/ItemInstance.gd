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

# The one curated behavioural rule this particular instance developed, or &""
# for an ordinary item. Manifestation is IDENTITY, not a stat: it is rolled
# once at creation, never rerolled, and survives every merge this item wins.
# See ManifestationCatalog.
@export var manifestation_id: StringName = &""

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
	copy.manifestation_id = manifestation_id
	return copy


static func from_roll(
	d: ItemData,
	r: int,
	pol: int,
	roll_pct: float,
	roll_manifestation: bool = true
) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = d
	inst.rarity = r
	inst.polarity = (Polarity.POS if pol >= 0 else Polarity.NEG)
	inst.best_pct = absf(roll_pct) * (1.0 if inst.polarity == Polarity.POS else -1.0)
	inst.progress = 1
	if roll_manifestation:
		inst._roll_manifestation()
	inst._recompute_flat_mods()
	return inst


func _roll_manifestation() -> void:
	# Fabricated merge material must never roll one (callers pass false):
	# a Manifestation the destination cannot inherit would simply be
	# destroyed, and rolling one there would also burn RNG for nothing.
	if data == null or Global == null or Global._rng == null:
		return
	manifestation_id = ManifestationCatalog.roll_for(
		data,
		polarity,
		Global.run_luck,
		Global._rng,
		# Prerequisite weighting: what the player already wears bends WHICH rule
		# appears, never whether one does. This is the single choke point every
		# drop path funnels through, so nothing has to be told about it.
		Global.equipped_manifestation_tags()
	)


func has_manifestation() -> bool:
	# A rule removed from the catalog leaves its id on saved items; that item
	# no longer carries a manifestation (badge, tooltip and CursedVault's
	# guarantee all follow this answer). The id itself is kept untouched.
	return manifestation_id != &"" and ManifestationCatalog.get_def(manifestation_id) != null


func manifestation_def() -> ManifestationDef:
	return ManifestationCatalog.get_def(manifestation_id)


func active_pct() -> float:
	return best_pct


func rarity_effect_multiplier() -> float:
	# Scripted effects (accessories: burn, shield, regen, speed) scale with
	# the SAME continuous potency curve as rarity_base stats — otherwise
	# ranking up a ring changed a tiny flat stat and nothing you could
	# feel. Includes the banked meter, so every feed grows the effect too.
	return RarityMath.potency(float(rarity) + clampf(upgrade_meter, 0.0, 0.999999))


func feed_roll(roll_pct: float, incoming_rarity: int = 0) -> void:
	# A fed roll is material at its OWN rarity — freshly rolled ground
	# pickups are rank-0 material and pay the gap penalty like everything
	# else. (They used to be fabricated at the destination's rarity, which
	# let any pickup feed an R7 item as a full peer.)
	if data == null:
		return
	var incoming := ItemInstance.from_roll(data, incoming_rarity, polarity, roll_pct, false)
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


func can_absorb_manifestation_of(incoming: ItemInstance) -> bool:
	# NOT a merge gate - merging is never blocked, or two independently found
	# rings would usually refuse to combine and ring progression would die.
	# This is the policy question for AUTOMATIC routing only: "would feeding
	# this destroy a rule the player has not seen yet?".
	#
	# A deliberate merge keeps the destination's rule and dissolves the
	# incoming one, exactly like every other duplicate. But a ground pickup
	# auto-feeding the worn item, or a bag tidy-up pass, must not make that
	# choice unattended - the R2 with the amazing rule has to reach the
	# player's hands so they can decide whether to rebuild around it.
	if incoming == null:
		return true
	if incoming.manifestation_id == &"":
		return true
	return incoming.manifestation_id == manifestation_id


func merge_from(incoming: ItemInstance) -> bool:
	if not can_merge(incoming):
		return false
	# NOTE: manifestation_id is deliberately absent from the swap below.
	# THIS object is the destination and keeps its own rule, even when the
	# incoming copy is the higher-rank side of the maths.
	# Auto-swap: the higher-rarity side is always the mathematical
	# destination — for H != 1 the wrong direction destroys ranks. Only
	# the progression payload swaps; THIS object survives, so equip
	# slots, locks and UI references keep their identity.
	if incoming.rarity > rarity:
		var swap_rarity := rarity
		rarity = incoming.rarity
		incoming.rarity = swap_rarity
		var swap_meter := upgrade_meter
		upgrade_meter = incoming.upgrade_meter
		incoming.upgrade_meter = swap_meter
		var swap_pct := best_pct
		best_pct = incoming.best_pct
		incoming.best_pct = swap_pct
		var swap_progress := progress
		progress = incoming.progress
		incoming.progress = swap_progress
	var quality := RarityMath.merge_quality(incoming.data, incoming.best_pct)
	var mass := RarityMath.merge_mass(incoming.rarity, rarity, quality)
	if incoming.upgrade_meter > 0.0:
		# Stored meter transfers at the material's OWN rank scale: merging
		# a half-fed item yields exactly what feeding both copies directly
		# would have (path-independence — a hard invariant, tested).
		mass += RarityMath.merge_mass(
			incoming.rarity,
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
	var overflow := RarityMath.overflow_factor()
	while upgrade_meter >= 1.0 - 0.000001:
		# Leftover converts at the gap law's per-rank ratio (2^(-1/H)):
		# each rarity step raises the required absolute merge mass by the
		# same factor the gap penalty charges.
		upgrade_meter = maxf(0.0, upgrade_meter - 1.0) * overflow
		rarity += 1
	# Recompute ONCE from the normalized post-merge state — never from a
	# transient meter >= 1.0 mid-loop (continuous-power requirement).
	_recompute_flat_mods()
	return true


func _recompute_flat_mods() -> void:
	# Flat mods are: base mods (data.mods) + rarity scaling (data.rarity_base).
	# CONTINUOUS RARITY POWER: potency reads rarity + banked meter, so every
	# merge physically moves the item's stats — "R0 at 60%" really is a
	# stronger R0, per the original design promise.
	rolled_mods = (data.mods.copy() if data != null and data.mods != null else StatDelta.new())

	if data != null and data.rarity_base != null:
		var effective_rarity := float(rarity) + clampf(upgrade_meter, 0.0, 0.999999)
		var k := RarityMath.potency(effective_rarity) - 1.0
		# Rate-family guardrail (spec §1.6): speed/haste contributions
		# plateau (~R13) instead of scaling through the raw curve forever.
		var k_rate := minf(k, RarityMath.RATE_STAT_POTENCY_CAP)
		rolled_mods.max_hp += data.rarity_base.max_hp * k
		rolled_mods.armor += data.rarity_base.armor * k
		rolled_mods.move_speed += data.rarity_base.move_speed * k_rate
		rolled_mods.power += data.rarity_base.power * k
		rolled_mods.haste += data.rarity_base.haste * k_rate
		rolled_mods.luck += data.rarity_base.luck * k
static func from_data(d: ItemData, copies: int = 1, rarity_in: int = 0, polarity_in: int = Polarity.POS) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = d
	inst.rarity = rarity_in
	inst.polarity = (Polarity.POS if polarity_in >= 0 else Polarity.NEG)
	inst._roll_manifestation()
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
			# Additional copies of a multi-copy construction are peers of
			# the requested rarity, not rank-0 material.
			inst.feed_roll(roll, rarity_in)

	return inst
