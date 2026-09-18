extends RefCounted
class_name AscensionTreeDB
## The V4 advancement graph, loaded once from data/ascension/tree_v4.json.
##
## Nodes, undirected links and structured requirements come straight from the
## authored JSON (ids, costs, conflicts, rings, kinds, tooltips). This class
## answers "what is this node" and "does this requirement hold for that
## ownership state"; the purchase rules themselves live in AscensionLedger.
##
## Requirement grammar (as authored):
##   {"all": [...]}  {"any": [...]}  {"owned": "ID"}
##   {"count": {"ids": [...], "at_least": N}}  {"milestone": "name"}

const TREE_PATH := "res://data/ascension/tree_v4.json"

## Sinks charge base x (rank+1)^exponent; the two Ascendant sinks use a
## steeper curve, and Execute Line stops at rank 30 (authored on the nodes).
const SINK_EXPONENT_DEFAULT := 1.25
const SINK_EXPONENT: Dictionary = {"ASC.S1": 1.4, "ASC.S2": 1.4}
const SINK_RANK_CAP: Dictionary = {"EXS2": 30}

## Kinds whose purchase is a reward or a milestone choice, never Followers.
const REWARD_KINDS: Array[String] = ["evolution", "choice"]
const CORES: Array[String] = ["melee", "ranged", "magic"]

static var _shared: AscensionTreeDB = null

var version: String = ""
var nodes: Dictionary = {}          # id -> node Dictionary (as authored)
var links: Dictionary = {}          # id -> PackedStringArray of neighbour ids
var builds: Array = []              # authored example routes
var disciplines: Array = []         # authored discipline metadata
var _by_kind: Dictionary = {}       # kind -> Array[String]
var _by_discipline: Dictionary = {} # discipline code -> Array[String] of local ids


static func shared() -> AscensionTreeDB:
	if _shared == null:
		_shared = AscensionTreeDB.new()
		_shared.load_from(TREE_PATH)
	return _shared


func load_from(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AscensionTreeDB: cannot open " + path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_error("AscensionTreeDB: " + path + " is not a JSON object")
		return false
	var data := parsed as Dictionary
	version = String(data.get("version", ""))
	builds = data.get("builds", [])
	disciplines = data.get("disciplines", [])
	nodes.clear()
	links.clear()
	_by_kind.clear()
	_by_discipline.clear()
	for node_variant in data.get("nodes", []):
		var node_data := node_variant as Dictionary
		var id := String(node_data.get("id", ""))
		nodes[id] = node_data
		var node_kind := String(node_data.get("kind", ""))
		if not _by_kind.has(node_kind):
			_by_kind[node_kind] = []
		(_by_kind[node_kind] as Array).append(id)
		var discipline: Variant = node_data.get("discipline")
		if discipline != null and node_kind == "local":
			var code := String(discipline)
			if not _by_discipline.has(code):
				_by_discipline[code] = []
			(_by_discipline[code] as Array).append(id)
	for node_variant in data.get("nodes", []):
		var node_data := node_variant as Dictionary
		var id := String(node_data.get("id", ""))
		var out := PackedStringArray()
		for other in node_data.get("links", []):
			out.append(String(other))
		links[id] = out
	return true


func has(id: String) -> bool:
	return nodes.has(id)


func node(id: String) -> Dictionary:
	return nodes.get(id, {})


func kind(id: String) -> String:
	return String(node(id).get("kind", ""))


func core_of(id: String) -> String:
	var value: Variant = node(id).get("core")
	return "" if value == null else String(value)


func discipline_of(id: String) -> String:
	var value: Variant = node(id).get("discipline")
	return "" if value == null else String(value)


func ring_of(id: String) -> int:
	return int(node(id).get("ring", 0))


func base_cost(id: String) -> int:
	return int(node(id).get("cost_followers", 0))


func conflicts(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for other in node(id).get("conflicts", []):
		out.append(String(other))
	return out


func neighbours(id: String) -> PackedStringArray:
	return links.get(id, PackedStringArray())


func ids_of_kind(kind_name: String) -> Array:
	return (_by_kind.get(kind_name, []) as Array).duplicate()


func local_ids(discipline_code: String) -> Array:
	return (_by_discipline.get(discipline_code, []) as Array).duplicate()


func is_reward_kind(id: String) -> bool:
	return REWARD_KINDS.has(kind(id))


## The two disciplines a Fusion joins, read from its owned-node requirements.
func fusion_disciplines(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for req_id in _owned_ids_in(node(id).get("requires", {})):
		var code := discipline_of(req_id)
		if not code.is_empty() and not out.has(code):
			out.append(code)
	return out


func _owned_ids_in(rule: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if rule is Dictionary:
		var dict := rule as Dictionary
		if dict.has("owned"):
			out.append(String(dict["owned"]))
		for key in ["all", "any"]:
			if dict.has(key):
				for child in dict[key]:
					out.append_array(_owned_ids_in(child))
	return out


## Sink price for the next rank (rank = ranks already owned).
func sink_price(id: String, rank: int) -> int:
	var exponent: float = float(SINK_EXPONENT.get(id, SINK_EXPONENT_DEFAULT))
	return int(ceil(float(base_cost(id)) * pow(float(rank + 1), exponent)))


func sink_rank_cap(id: String) -> int:
	return int(SINK_RANK_CAP.get(id, 1 << 30))


## Evaluate an authored requirement. `owned` is id -> rank; `milestones` is a
## Callable(name: String) -> bool so the ledger can answer gate, fusion and
## segment milestones from run state.
func requirement_holds(rule: Variant, owned: Dictionary, milestones: Callable) -> bool:
	if rule == null:
		return true
	if not (rule is Dictionary):
		return true
	var dict := rule as Dictionary
	if dict.is_empty():
		return true
	if dict.has("all"):
		for child in dict["all"]:
			if not requirement_holds(child, owned, milestones):
				return false
		return true
	if dict.has("any"):
		var options: Array = dict["any"]
		if options.is_empty():
			return true
		for child in options:
			if requirement_holds(child, owned, milestones):
				return true
		return false
	if dict.has("owned"):
		return int(owned.get(String(dict["owned"]), 0)) > 0
	if dict.has("count"):
		var spec := dict["count"] as Dictionary
		var have := 0
		for id in spec.get("ids", []):
			if int(owned.get(String(id), 0)) > 0:
				have += 1
		return have >= int(spec.get("at_least", 0))
	if dict.has("milestone"):
		return bool(milestones.call(String(dict["milestone"])))
	return true


## Human-readable list of what a requirement still needs, for tooltips.
func requirement_gaps(rule: Variant, owned: Dictionary, milestones: Callable) -> PackedStringArray:
	var gaps := PackedStringArray()
	if not (rule is Dictionary):
		return gaps
	var dict := rule as Dictionary
	if dict.has("all"):
		for child in dict["all"]:
			gaps.append_array(requirement_gaps(child, owned, milestones))
	elif dict.has("any"):
		if not requirement_holds(dict, owned, milestones):
			var names := PackedStringArray()
			for child in dict["any"]:
				var sub := requirement_gaps(child, owned, milestones)
				names.append(" + ".join(sub) if not sub.is_empty() else "?")
			gaps.append("one of: " + " / ".join(names))
	elif dict.has("owned"):
		var id := String(dict["owned"])
		if int(owned.get(id, 0)) <= 0:
			gaps.append(String(node(id).get("name", id)))
	elif dict.has("count"):
		var spec := dict["count"] as Dictionary
		var have := 0
		for id in spec.get("ids", []):
			if int(owned.get(String(id), 0)) > 0:
				have += 1
		var need := int(spec.get("at_least", 0))
		if have < need:
			var first := String(spec.get("ids", [""])[0])
			gaps.append("%d of %s locals (%d owned)" % [need, discipline_of(first) if not discipline_of(first).is_empty() else "the core's", have])
	elif dict.has("milestone"):
		if not bool(milestones.call(String(dict["milestone"]))):
			gaps.append(String(dict["milestone"]).replace("_", " "))
	return gaps
