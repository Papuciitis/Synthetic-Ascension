extends RefCounted

## Profile preparation and an independent attempt snapshot. Research records
## first city Rites; a rank never spends Followers or rewards a death.
const REVISION := 1
const OPTIONS: Array[Dictionary] = [
	{"id": "health", "name": "Health", "description": "Increase maximum health.", "cap": 3, "step": 5.0, "stat": "max_hp", "unit": "HP"},
	{"id": "armor", "name": "Armor", "description": "Increase armor against incoming hits.", "cap": 3, "step": 1.0, "stat": "armor", "unit": "armor"},
	{"id": "bag", "name": "Carrying space", "description": "Add one bag slot.", "cap": 3, "step": 1.0, "stat": "", "unit": "bag slot"},
	{"id": "augment", "name": "Augment training", "description": "One chosen owned augment starts at level 2. Its later growth remains part of the run.", "cap": 1, "step": 1.0, "stat": "", "unit": "starting level"},
	{"id": "haste", "name": "Haste", "description": "Add Haste to the character's starting stats.", "cap": 3, "step": 0.02, "stat": "haste", "unit": "% Haste"},
	{"id": "speed", "name": "Movement speed", "description": "Add flat movement speed, in world pixels per second.", "cap": 3, "step": 2.0, "stat": "move_speed", "unit": "speed"},
	{"id": "luck", "name": "Luck", "description": "Add Luck; each Luck-dependent outcome uses its existing scaling.", "cap": 3, "step": 0.02, "stat": "luck", "unit": "Luck"},
	{"id": "power", "name": "Power", "description": "Add Power to the character's starting damage stat.", "cap": 3, "step": 0.02, "stat": "power", "unit": "% Power"},
	{"id": "range", "name": "Attack reach", "description": "Increase native melee reach and ranged projectile travel distance.", "cap": 3, "step": 0.05, "stat": "", "unit": "% reach"},
	{"id": "size", "name": "Attack size", "description": "Widen native melee arcs and projectiles, and enlarge native magic bursts.", "cap": 3, "step": 0.05, "stat": "", "unit": "% size"},
	{"id": "binding_echo", "name": "Binding Echo", "description": "At your next attempt's fifth city Rite, take two Binding rewards instead of one. Reach it again on each new attempt.", "cap": 1, "step": 1.0, "stat": "", "unit": "conditional extra Binding"},
]

static func _ranks(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	var source: Dictionary = raw if raw is Dictionary else {}
	for option in OPTIONS:
		var value: Variant = source.get(option["id"], 0)
		out[option["id"]] = clampi(int(value), 0, int(option["cap"])) if typeof(value) == TYPE_INT else 0
	return out

static func _target(raw: Variant, owned: Array) -> String:
	if typeof(raw) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return ""
	var id := String(raw)
	return id if owned.has(StringName(id)) or owned.has(id) else ""

static func normalize_profile(raw: Variant, owned: Array) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var claims: Array = []
	var supplied: Variant = source.get("claimed_segments", [])
	if supplied is Array:
		for segment: Variant in supplied:
			if typeof(segment) == TYPE_INT and segment >= 1 and segment <= 10 and not claims.has(segment):
				claims.append(segment)
	claims.sort()
	var ranks := _ranks(source.get("ranks", {}))
	# A malformed save cannot grant more choices than its verified claims.
	var budget := claims.size()
	for option in OPTIONS:
		var id: String = option["id"]
		ranks[id] = mini(int(ranks[id]), budget)
		budget -= int(ranks[id])
	return {"revision": REVISION, "claimed_segments": claims, "ranks": ranks, "augment_id": _target(source.get("augment_id", ""), owned)}

static func normalize_snapshot(raw: Variant, owned: Array, profile: Dictionary) -> Dictionary:
	if not raw is Dictionary or raw.get("revision", 0) != REVISION:
		return {}
	var ranks := _ranks(raw.get("ranks", {}))
	var budget := 10
	for option in OPTIONS:
		var id: String = option["id"]
		ranks[id] = mini(mini(int(ranks[id]), rank(profile, id)), budget)
		budget -= int(ranks[id])
	return {"revision": REVISION, "ranks": ranks, "augment_id": _target(raw.get("augment_id", ""), owned)}

static func snapshot(profile: Dictionary, owned: Array) -> Dictionary:
	var clean := normalize_profile(profile, owned)
	return {"revision": REVISION, "ranks": clean["ranks"].duplicate(), "augment_id": clean["augment_id"]}

static func rank(state: Dictionary, id: String) -> int:
	return int(state.get("ranks", {}).get(id, 0))

static func points(profile: Dictionary) -> int:
	var spent := 0
	for value: int in profile["ranks"].values():
		spent += value
	return maxi(0, profile["claimed_segments"].size() - spent)

static func bonuses(state: Dictionary) -> Dictionary:
	return {
		"hp": 5 * rank(state, "health"), "armor": rank(state, "armor"), "bag_slots": rank(state, "bag"),
		"haste": 0.02 * rank(state, "haste"), "speed": 2.0 * rank(state, "speed"),
		"luck": 0.02 * rank(state, "luck"), "power": 0.02 * rank(state, "power"),
		"range_multiplier": 1.0 + 0.05 * rank(state, "range"), "size_multiplier": 1.0 + 0.05 * rank(state, "size"),
		"augment_id": String(state.get("augment_id", "")) if rank(state, "augment") > 0 else "",
		"binding_echo": rank(state, "binding_echo") > 0,
	}

static func claim(profile: Dictionary, segment: int) -> bool:
	if segment < 1 or segment > 10 or profile["claimed_segments"].has(segment):
		return false
	profile["claimed_segments"].append(segment)
	profile["claimed_segments"].sort()
	return true

static func purchase(profile: Dictionary, id: StringName, target: StringName, owned: Array) -> bool:
	if points(profile) <= 0:
		return false
	for option in OPTIONS:
		if String(id) != option["id"]:
			continue
		if rank(profile, String(id)) >= int(option["cap"]):
			return false
		if id == &"augment":
			var chosen := _target(target, owned)
			if chosen.is_empty():
				return false
			profile["augment_id"] = chosen
		profile["ranks"][String(id)] += 1
		return true
	return false

static func apply_stats(state: Dictionary, stats: Stats) -> void:
	if stats == null:
		return
	for option in OPTIONS:
		var stat: String = option["stat"]
		if not stat.is_empty():
			stats.set(stat, float(stats.get(stat)) + float(option["step"]) * rank(state, option["id"]))

static func _gain_text(option: Dictionary, ranks: int) -> String:
	var id: String = option["id"]
	if id == "augment":
		return "Start one chosen augment at level 2" if ranks > 0 else "No trained augment"
	if id == "binding_echo":
		return "Two successive Bindings after clearing segment 5" if ranks > 0 else "One Binding after clearing segment 5"
	var amount := float(option["step"]) * ranks
	if id in ["haste", "power", "range", "size"]:
		amount *= 100.0
	if id == "luck":
		return "+%.2f Luck" % amount
	return "+%s %s" % [String.num(amount, 0), String(option["unit"])]

static func options(profile: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for option in OPTIONS:
		var current := rank(profile, option["id"])
		out.append({"id": option["id"], "name": option["name"], "description": option["description"], "cap": option["cap"], "rank": current, "cost": 1, "owned_target_required": option["id"] == "augment", "next_gain_text": _gain_text(option, 1), "total_gain_text": _gain_text(option, current)})
	return out
