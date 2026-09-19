class_name ItemScaling
extends RefCounted

## Item stat progression (balance revision 2): explicit, ID-keyed profiles
## in data/items/item_scaling_v2.json give each item's TOTAL flat
## contribution as a function of its effective rank (rarity plus banked
## meter). Anchor stats interpolate linearly between ranks 0/1/6/15/30 and
## continue the last slope above 30; rate stats (movement, haste) approach
## an asymptote; a `flat` block is added at every rank. The existing roll is
## applied once afterward by the stat pipeline, so nothing here scales twice.
## An item without a profile keeps the legacy potency formula, so external
## or fixture items never lose their stats.
##
## The same evaluator serves runtime stats, tooltips, comparison previews
## and, later, set descriptions; there is no second copy of the numbers.

const PROFILE_PATH := "res://data/items/item_scaling_v2.json"
const STAT_KEYS := ["max_hp", "armor", "move_speed", "power", "haste", "luck"]
const METER_CAP := 0.999999

static var _profiles: Dictionary = {}
static var _anchor_ranks: Array = [0.0, 1.0, 6.0, 15.0, 30.0]
static var _loaded := false
static var _load_ok := false
static var _errors: PackedStringArray = PackedStringArray()


## Loads and validates the profile file once. Malformed data is reported
## loudly and the file is rejected as a whole: a corrupt profile must never
## be clamped into plausible balance.
static func load_profiles(path: String = PROFILE_PATH, force: bool = false) -> bool:
	if _loaded and not force:
		return _load_ok
	_loaded = true
	_load_ok = false
	_profiles = {}
	_errors = PackedStringArray()
	if not FileAccess.file_exists(path):
		_errors.append("profile file missing: " + path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != 2:
		_errors.append("profile file is not a version 2 object: " + path)
		push_error("ItemScaling: " + _errors[-1])
		return false
	var doc := parsed as Dictionary
	var ranks: Array = doc.get("anchor_ranks", [])
	if ranks.size() < 2:
		_errors.append("anchor_ranks needs at least two ranks")
	for index in range(1, ranks.size()):
		if float(ranks[index]) <= float(ranks[index - 1]) or not is_finite(float(ranks[index])):
			_errors.append("anchor_ranks must be strictly increasing and finite")
	var profiles: Dictionary = doc.get("profiles", {})
	for item_id in profiles:
		var profile: Variant = profiles[item_id]
		if not (profile is Dictionary):
			_errors.append("%s: profile is not an object" % item_id)
			continue
		var seen := {}
		for stat in (profile as Dictionary).get("anchors", {}):
			var values: Array = (profile as Dictionary)["anchors"][stat]
			_validate_stat(String(item_id), String(stat), seen)
			if values.size() != ranks.size():
				_errors.append("%s.%s: %d anchors for %d ranks" % [item_id, stat, values.size(), ranks.size()])
			for value in values:
				if not (value is float or value is int) or not is_finite(float(value)):
					_errors.append("%s.%s: non-finite anchor" % [item_id, stat])
		for stat in (profile as Dictionary).get("rates", {}):
			var rate: Variant = (profile as Dictionary)["rates"][stat]
			_validate_stat(String(item_id), String(stat), seen)
			if not (rate is Dictionary) or float((rate as Dictionary).get("tau", 0.0)) <= 0.0:
				_errors.append("%s.%s: rate needs r0, r1, limit and a positive tau" % [item_id, stat])
			else:
				for key in ["r0", "r1", "limit"]:
					if not is_finite(float((rate as Dictionary).get(key, NAN))):
						_errors.append("%s.%s: rate %s is not finite" % [item_id, stat, key])
		for stat in (profile as Dictionary).get("flat", {}):
			_validate_stat(String(item_id), String(stat), seen)
			if not is_finite(float((profile as Dictionary)["flat"][stat])):
				_errors.append("%s.%s: flat is not finite" % [item_id, stat])
	if not _errors.is_empty():
		for error in _errors:
			push_error("ItemScaling: " + error)
		return false
	_anchor_ranks = []
	for rank in ranks:
		_anchor_ranks.append(float(rank))
	_profiles = profiles
	_load_ok = true
	return true


static func _validate_stat(item_id: String, stat: String, seen: Dictionary) -> void:
	if not STAT_KEYS.has(stat):
		_errors.append("%s: unknown stat %s" % [item_id, stat])
	if seen.has(stat):
		_errors.append("%s: stat %s appears in more than one channel" % [item_id, stat])
	seen[stat] = true


static func errors() -> PackedStringArray:
	return _errors


## True once a valid profile file is loaded: the item-balance revision 2
## numbers are live.
static func active() -> bool:
	return load_profiles()


static func has_profile(item_id: String) -> bool:
	return load_profiles() and _profiles.has(item_id)


static func profile(item_id: String) -> Dictionary:
	return _profiles.get(item_id, {}) if load_profiles() else {}


static func profile_ids() -> Array:
	return _profiles.keys() if load_profiles() else []


static func anchor_ranks() -> Array:
	return _anchor_ranks.duplicate()


static func effective_rank(item: ItemInstance) -> float:
	if item == null:
		return 0.0
	return float(maxi(0, item.rarity)) + clampf(float(item.upgrade_meter), 0.0, METER_CAP)


## Linear between strictly increasing anchors; clamped below the first, the
## last segment's slope continued above the last.
static func sample_anchors(rank: float, points: Array[Vector2]) -> float:
	assert(points.size() >= 2)
	var r := maxf(0.0, rank)
	if r <= points[0].x:
		return points[0].y
	for index in range(1, points.size()):
		if r <= points[index].x:
			var left := points[index - 1]
			var right := points[index]
			return lerpf(left.y, right.y, (r - left.x) / (right.x - left.x))
	var tail_left := points[points.size() - 2]
	var tail_right := points[points.size() - 1]
	return tail_right.y + (r - tail_right.x) * (tail_right.y - tail_left.y) / (tail_right.x - tail_left.x)


## Smooth approach to `limit` from r1 with time constant tau; r0..r1 linear.
static func sample_rate(rank: float, r0: float, r1: float, limit: float, tau: float) -> float:
	assert(tau > 0.0)
	var r := maxf(0.0, rank)
	if r <= 1.0:
		return lerpf(r0, r1, r)
	return r1 + (limit - r1) * (1.0 - exp(-(r - 1.0) / tau))


static func _points(values: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(mini(values.size(), _anchor_ranks.size())):
		out.append(Vector2(float(_anchor_ranks[index]), float(values[index])))
	return out


## The item's total flat contribution at an arbitrary effective rank; the
## legacy potency formula for items without a profile.
static func flat_mods_at(data: ItemData, rank: float) -> StatDelta:
	var out := StatDelta.new()
	if data == null:
		return out
	if not has_profile(String(data.id)):
		return legacy_flat_mods(data, rank)
	var entry := profile(String(data.id))
	for stat in entry.get("anchors", {}):
		out.set(stat, float(out.get(stat)) + sample_anchors(rank, _points(entry["anchors"][stat])))
	for stat in entry.get("rates", {}):
		var rate: Dictionary = entry["rates"][stat]
		out.set(stat, float(out.get(stat)) + sample_rate(rank, float(rate.r0), float(rate.r1), float(rate.limit), float(rate.tau)))
	for stat in entry.get("flat", {}):
		out.set(stat, float(out.get(stat)) + float(entry["flat"][stat]))
	return out


static func flat_mods(item: ItemInstance) -> StatDelta:
	if item == null:
		return StatDelta.new()
	return flat_mods_at(item.data, effective_rank(item))


## The pre-revision-2 formula: base mods plus rarity_base scaled by the
## potency curve, with the rate-stat plateau. Kept for unmigrated items and
## as the documented baseline.
static func legacy_flat_mods(data: ItemData, rank: float) -> StatDelta:
	var out := (data.mods.copy() if data != null and data.mods != null else StatDelta.new())
	if data != null and data.rarity_base != null:
		var k := RarityMath.potency(maxf(0.0, rank)) - 1.0
		var k_rate := minf(k, RarityMath.RATE_STAT_POTENCY_CAP)
		out.max_hp += data.rarity_base.max_hp * k
		out.armor += data.rarity_base.armor * k
		out.move_speed += data.rarity_base.move_speed * k_rate
		out.power += data.rarity_base.power * k
		out.haste += data.rarity_base.haste * k_rate
		out.luck += data.rarity_base.luck * k
	return out


## Scripted-effect scale for accessories (section 3.4): `exp` profiles rise
## from `base` toward base + gain with time constant tau after `from_rank`
## (r0_value below it); `anchors` profiles interpolate then follow a tail.
## 1.0 for items without an effect profile.
static func accessory_factor(item_id: String, rank: float) -> float:
	var entry := profile(item_id)
	var effect: Variant = entry.get("effect", null)
	if not (effect is Dictionary):
		return 1.0
	var spec := effect as Dictionary
	var r := maxf(0.0, rank)
	match String(spec.get("type", "")):
		"exp":
			var from_rank := float(spec.get("from_rank", 1.0))
			var base := float(spec.get("base", 1.0))
			var gain := float(spec.get("gain", 0.0))
			var tau := maxf(0.000001, float(spec.get("tau", 12.0)))
			if r < from_rank:
				var r0_value := float(spec.get("r0_value", base))
				return lerpf(r0_value, base, r / maxf(from_rank, 0.000001))
			return base + gain * (1.0 - exp(-(r - from_rank) / tau))
		"anchors":
			var points := _points(spec.get("points", []))
			var last_rank := points[points.size() - 1].x if not points.is_empty() else 30.0
			if r <= last_rank or not spec.has("tail"):
				return sample_anchors(r, points)
			var tail: Dictionary = spec["tail"]
			var top := points[points.size() - 1].y
			return top + float(tail.get("gain", 0.0)) * (1.0 - exp(-(r - last_rank) / maxf(0.000001, float(tail.get("tau", 20.0)))))
	return 1.0


## Recomputes derived stats for every instance in a container's slots from
## id, rank and meter alone: no feeding, no rerolling, no shared resources.
static func rebuild(items: Array) -> int:
	var count := 0
	for index in items.size():
		var item: Variant = items[index]
		if item is ItemInstance and (item as ItemInstance).data == null:
			# An instance whose ItemData no longer exists (a removed or renamed
			# item in an old save) would be worth 0, offered for 0 and land
			# in the bag as a dead stack (break-the-game audit P5). Drop it.
			push_warning("ItemScaling.rebuild: dropping an item whose data no longer exists from slot %d" % index)
			items[index] = null
			continue
		if item is ItemInstance and (item as ItemInstance).data != null:
			var inst := item as ItemInstance
			# A hand-edited or damaged save can carry a negative rank or a
			# meter past a whole rank; the merge law never produces either.
			inst.rarity = maxi(0, int(inst.rarity))
			inst.upgrade_meter = clampf(float(inst.upgrade_meter), 0.0, 0.999999)
			inst._recompute_flat_mods()
			count += 1
	return count


## The change the next whole rank would bring, for tooltips and previews.
static func next_rank_delta(item: ItemInstance) -> StatDelta:
	var now := flat_mods(item)
	var next := flat_mods_at(item.data, float(maxi(0, item.rarity) + 1))
	var out := StatDelta.new()
	for stat in STAT_KEYS:
		out.set(stat, float(next.get(stat)) - float(now.get(stat)))
	return out
