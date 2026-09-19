extends RefCounted
class_name AscensionLedger
## Ownership and purchase rules for the V4 advancement tree, operating on one
## plain Dictionary so the run state saves as-is (Global.attempt_ascension).
##
## A purchase needs: access to the node's Core, one owned adjacent node (or an
## owned Core anchor next to it), the authored requirements, no owned conflict,
## and enough Followers. Gates grant a chosen Core anchor. Evolutions spend a
## banked reward claim instead of Followers. Milestone choices are free and
## exclusive. Sinks rank up at base x (rank+1)^exponent. The first ring-1
## local of the native Core is the free starter.
##
## Followers are spent through Global.transaction_followers so the wallet,
## feedback and autosave stay the game's; nothing here holds money.

const REASON_PURCHASE := &"ascension_purchase"
const REASON_REFUND := &"ascension_refund"
const KEYSTONE_SLOTS := 2
const AXIOM_SLOTS := 3

var db: AscensionTreeDB
var state: Dictionary


static func fresh_state(native_core_id: String) -> Dictionary:
	return {
		"native_core": native_core_id,
		"cores": [native_core_id],
		"owned": {"core.%s" % native_core_id: 1},
		"paid": {},
		"starter": "",
		"equipped": {"q": "", "v": "", "v2": "", "reaction": "", "keystones": [], "axioms": []},
		"reaction_trigger": "catastrophe",
		"disabled_mutations": [],
		"evolution_claims": 0,
		"segments_completed": 0,
		"spent": 0,
		"refunded": 0,
		"history": [],
	}


func _init(tree: AscensionTreeDB, run_state: Dictionary) -> void:
	db = tree
	state = run_state
	# A state saved by an older build, or an empty one, gets the defaults.
	var native := String(state.get("native_core", ""))
	if native.is_empty():
		native = "melee"
	var defaults := fresh_state(native)
	for key in defaults:
		if not state.has(key):
			state[key] = defaults[key]
	for slot in ["reaction", "v2"]:
		if not (state["equipped"] as Dictionary).has(slot):
			(state["equipped"] as Dictionary)[slot] = ""
	if not state.has("reaction_trigger"):
		state["reaction_trigger"] = "catastrophe"


# ---------------------------------------------------------------- queries

func native_core() -> String:
	return String(state.get("native_core", "melee"))


func cores() -> Array:
	return state.get("cores", [])


func has_core(core: String) -> bool:
	return cores().has(core)


func owned() -> Dictionary:
	return state.get("owned", {})


func owns(id: String) -> bool:
	return int(owned().get(id, 0)) > 0


func rank(id: String) -> int:
	return int(owned().get(id, 0))


func owned_ids() -> Array:
	var out: Array = []
	for id in owned():
		if int(owned()[id]) > 0 and db.has(String(id)):
			out.append(String(id))
	return out


func owned_of_kind(kind_name: String) -> Array:
	var out: Array = []
	for id in owned_ids():
		if db.kind(id) == kind_name:
			out.append(id)
	return out


func equipped(slot: String) -> String:
	return String((state.get("equipped", {}) as Dictionary).get(slot, ""))


func equipped_list(slot: String) -> Array:
	return (state.get("equipped", {}) as Dictionary).get(slot, [])


func is_equipped(id: String) -> bool:
	if equipped("q") == id or equipped("v") == id or equipped("v2") == id or equipped("reaction") == id:
		return true
	return equipped_list("keystones").has(id) or equipped_list("axioms").has(id)


## The Reaction Q slot opens with the first Gate (review F14): a second owned
## Q that casts itself on a trigger at 60% damage and twice the recovery.
func reaction_slot_open() -> bool:
	return owns("G1")


## A mutation runs when owned, enabled, and its parent Q / Revelation is equipped.
func mutation_active(id: String) -> bool:
	if not owns(id) or (state.get("disabled_mutations", []) as Array).has(id):
		return false
	var parent := mutation_parent(id)
	return not parent.is_empty() and is_equipped(parent)


func mutation_parent(id: String) -> String:
	var kind := db.kind(id)
	if kind != "mutation" and kind != "revelation_mutation":
		return ""
	for req_id in db._owned_ids_in(db.node(id).get("requires", {})):
		var req_kind := db.kind(req_id)
		if req_kind == "active" or req_kind == "revelation":
			return req_id
	return ""


## Local, fork, keystone, catastrophe, fusion, axiom, union and sink effects
## run whenever owned; Q/V and their mutations only when equipped.
func effect_active(id: String) -> bool:
	if not owns(id):
		return false
	match db.kind(id):
		"active", "revelation":
			return is_equipped(id)
		"mutation", "revelation_mutation":
			return mutation_active(id)
		"evolution":
			var q := ""
			for req_id in db._owned_ids_in(db.node(id).get("requires", {})):
				if db.kind(req_id) == "active":
					q = req_id
			return not q.is_empty() and (equipped("q") == q or equipped("reaction") == q)
		"keystone":
			return equipped_list("keystones").has(id)
		"axiom":
			return equipped_list("axioms").has(id)
		_:
			return true


func milestone(name: String) -> bool:
	match name:
		"first_gate":
			return not owns("G1")
		"evolution_reward":
			return int(state.get("evolution_claims", 0)) > 0
		"one_fusion_owned":
			return not owned_of_kind("fusion").is_empty()
		"union_diversity_mr", "union_diversity_mm", "union_diversity_rm":
			return _union_diversity(name.substr(name.length() - 2))
		_:
			if name.begins_with("segment_") and name.ends_with("_complete"):
				var number := int(name.trim_prefix("segment_").trim_suffix("_complete"))
				return int(state.get("segments_completed", 0)) >= number
	return false


## A Union needs three Fusions on its border spanning two disciplines on each side.
func _union_diversity(border: String) -> bool:
	var prefix := border.to_upper()
	var left: Dictionary = {}
	var right: Dictionary = {}
	var count := 0
	for id in owned_of_kind("fusion"):
		if not id.begins_with(prefix):
			continue
		count += 1
		var pair := db.fusion_disciplines(id)
		if pair.size() >= 2:
			left[pair[0]] = true
			right[pair[1]] = true
	return count >= 3 and left.size() >= 2 and right.size() >= 2


# ---------------------------------------------------------------- pricing

func is_free_starter(id: String) -> bool:
	return String(state.get("starter", "")).is_empty() and db.kind(id) == "local" and db.ring_of(id) == 1 and db.core_of(id) == native_core()


func price(id: String) -> int:
	var kind := db.kind(id)
	if db.is_reward_kind(id):
		return 0
	if kind == "sink":
		return db.sink_price(id, rank(id))
	if is_free_starter(id):
		return 0
	return db.base_cost(id)


# ---------------------------------------------------------------- purchase rules

func adjacent_owned(id: String) -> bool:
	for other in db.neighbours(id):
		if owns(other):
			return true
	return false


## {ok, reason, cost}. `followers` is the wallet the caller wants checked.
func can_buy(id: String, followers: int, chosen_core: String = "") -> Dictionary:
	if not db.has(id):
		return _no("unknown node")
	var kind := db.kind(id)
	if kind == "core":
		return _no("a Core anchor comes from a Gate")
	if kind == "sink":
		if rank(id) >= db.sink_rank_cap(id):
			return _no("at maximum rank")
	elif owns(id):
		return _no("already owned")
	var core := db.core_of(id)
	if not core.is_empty() and not has_core(core):
		return _no("no access to the %s Core" % core)
	if kind == "gate":
		if chosen_core.is_empty() or not AscensionTreeDB.CORES.has(chosen_core):
			return _no("choose a Core to open")
		if has_core(chosen_core):
			return _no("that Core is already open")
	if kind != "choice" and kind != "gate" and not adjacent_owned(id):
		return _no("not adjacent to anything owned")
	if kind == "gate" and id == "G1" and not adjacent_owned(id):
		return _no("not adjacent to anything owned")
	for other in db.conflicts(id):
		if owns(other):
			return _no("sealed by %s" % String(db.node(other).get("name", other)))
	if not db.requirement_holds(db.node(id).get("requires", {}), owned(), Callable(self, "milestone")):
		var gaps := db.requirement_gaps(db.node(id).get("requires", {}), owned(), Callable(self, "milestone"))
		return _no("needs " + ", ".join(gaps))
	var cost := price(id)
	if followers < cost:
		return _no("needs %d Followers" % cost)
	return {"ok": true, "reason": "", "cost": cost}


func _no(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "cost": 0}


## Records ownership after the caller has paid. Returns the amount recorded.
func record_purchase(id: String, cost: int, chosen_core: String = "") -> int:
	var kind := db.kind(id)
	var owned_map: Dictionary = state["owned"]
	owned_map[id] = int(owned_map.get(id, 0)) + 1
	if cost > 0:
		var paid: Dictionary = state["paid"]
		paid[id] = int(paid.get(id, 0)) + cost
		state["spent"] = int(state.get("spent", 0)) + cost
	if is_free_starter(id) and cost == 0:
		state["starter"] = id
	if kind == "gate" and not chosen_core.is_empty():
		var opened: Array = state["cores"]
		if not opened.has(chosen_core):
			opened.append(chosen_core)
		owned_map["core.%s" % chosen_core] = 1
	if kind == "evolution":
		state["evolution_claims"] = maxi(0, int(state.get("evolution_claims", 0)) - 1)
	(state["history"] as Array).append(id)
	_auto_equip(id)
	return cost


## Sworn nodes never refund (the V4 economy rule): a Revelation, a fork, a
## Union, an Axiom or a Catastrophe is a commitment, and a refund that would
## take one down with it is refused rather than forfeited by accident.
const NON_REFUNDABLE_KINDS := ["core", "gate", "choice", "revelation", "fork", "union", "axiom", "catastrophe", "ascendant"]


## The share of a node's recorded price a refund returns at a segment: half
## in the first two segments, a tenth less each segment after, floor a tenth.
static func refund_share(segment: int) -> float:
	return clampf(0.5 * pow(0.9, float(maxi(0, segment - 2))), 0.1, 0.5)


## What refunding `id` would do, without doing it: every node that would
## leave (the node and each dependent that could no longer reach a Core or
## keep its requirements), the sworn nodes among them (which block the
## refund), and the total recorded price of the leavers.
func refund_preview(id: String) -> Dictionary:
	var out := {"removed": [], "blocked": [], "paid": 0}
	if not owns(id) or db.kind(id) in ["core", "gate", "choice"]:
		return out
	var owned_map: Dictionary = (state["owned"] as Dictionary).duplicate()
	var paid: Dictionary = state["paid"]
	var removed: Array = []
	var total := 0
	var pending: Array = [id]
	while not pending.is_empty():
		for dep in pending:
			if owned_map.has(dep):
				total += int(paid.get(dep, 0))
				owned_map.erase(dep)
				removed.append(dep)
		pending.clear()
		var reachable := _reachable_in(owned_map)
		for other_key in owned_map.keys():
			var other := String(other_key)
			if db.kind(other) in ["core", "gate", "choice"]:
				continue
			var holds := db.requirement_holds(db.node(other).get("requires", {}), owned_map, Callable(self, "milestone"))
			if not holds or not reachable.has(other):
				pending.append(other)
	var blocked: Array = []
	for gone in removed:
		if db.kind(String(gone)) in NON_REFUNDABLE_KINDS:
			blocked.append(gone)
	out["removed"] = removed
	out["blocked"] = blocked
	out["paid"] = total
	return out


## Refund: removes the node and everything that depended on it and returns
## `share` of each leaver's recorded price (the rest is forfeited). Refused
## when a sworn node would leave, unless `force` (the simulator's ablation
## removes nodes to measure them, not to respec). Returns the amount refunded.
func refund(id: String, share: float = 1.0, force: bool = false) -> int:
	var preview := refund_preview(id)
	var removed: Array = preview["removed"]
	if removed.is_empty():
		return 0
	if not force and not (preview["blocked"] as Array).is_empty():
		return 0
	var owned_map: Dictionary = state["owned"]
	var paid: Dictionary = state["paid"]
	var safe_share := clampf(share, 0.0, 1.0)
	var total := 0
	var returned := 0
	for gone_key in removed:
		var gone := String(gone_key)
		var price := int(paid.get(gone, 0))
		total += price
		returned += int(round(float(price) * safe_share))
		owned_map.erase(gone)
		paid.erase(gone)
		_unequip(gone)
	state["refunded"] = int(state.get("refunded", 0)) + returned
	state["forfeited"] = int(state.get("forfeited", 0)) + (total - returned)
	state["spent"] = maxi(0, int(state.get("spent", 0)) - total)
	return returned


## Owned nodes connected to an owned Core anchor through owned links.
func _reachable_owned() -> Dictionary:
	return _reachable_in(state["owned"])


func _reachable_in(owned_map: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var frontier: Array = []
	for core in cores():
		var anchor := "core.%s" % core
		if owned_map.has(anchor):
			seen[anchor] = true
			frontier.append(anchor)
	while not frontier.is_empty():
		var current: String = frontier.pop_back()
		for other in db.neighbours(current):
			var next := String(other)
			if owned_map.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen


# ---------------------------------------------------------------- equipment

func can_equip(slot: String, id: String) -> bool:
	if not owns(id):
		return false
	match slot:
		"q":
			return db.kind(id) == "active"
		"reaction":
			return db.kind(id) == "active" and reaction_slot_open() and equipped("q") != id
		"v":
			return db.kind(id) == "revelation"
		"v2":
			return db.kind(id) == "revelation" and owns("ASC") and equipped("v") != id
		"keystones":
			return db.kind(id) == "keystone" and (equipped_list("keystones").has(id) or equipped_list("keystones").size() < keystone_slots())
		"axioms":
			return db.kind(id) == "axiom" and (equipped_list("axioms").has(id) or equipped_list("axioms").size() < AXIOM_SLOTS)
	return false


func keystone_slots() -> int:
	return KEYSTONE_SLOTS + (1 if owns("ASC") else 0)


func equip(slot: String, id: String) -> bool:
	if not can_equip(slot, id):
		return false
	var eq: Dictionary = state["equipped"]
	if slot == "q" or slot == "v" or slot == "v2" or slot == "reaction":
		eq[slot] = id
		if slot == "q" and String(eq.get("reaction", "")) == id:
			eq["reaction"] = ""
		if slot == "v" and String(eq.get("v2", "")) == id:
			eq["v2"] = ""
	else:
		var list: Array = eq[slot]
		if not list.has(id):
			list.append(id)
	return true


func unequip(slot: String, id: String) -> void:
	var eq: Dictionary = state["equipped"]
	if slot == "q" or slot == "v" or slot == "v2" or slot == "reaction":
		if String(eq.get(slot, "")) == id:
			eq[slot] = ""
	else:
		(eq[slot] as Array).erase(id)


func _auto_equip(id: String) -> void:
	# The first Q, V, Keystone or Axiom bought is equipped so it works at once.
	match db.kind(id):
		"active":
			if equipped("q").is_empty():
				equip("q", id)
			elif equipped("reaction").is_empty():
				equip("reaction", id)
		"gate":
			# The Gate opens the Reaction slot: a second owned Q fills it.
			if equipped("reaction").is_empty():
				for other in owned_of_kind("active"):
					if other != equipped("q") and equip("reaction", other):
						break
		"revelation":
			if equipped("v").is_empty():
				equip("v", id)
			elif equipped("v2").is_empty():
				equip("v2", id)
		"ascendant":
			if equipped("v2").is_empty():
				for other in owned_of_kind("revelation"):
					if other != equipped("v") and equip("v2", other):
						break
		"keystone":
			equip("keystones", id)
		"axiom":
			equip("axioms", id)


func _unequip(id: String) -> void:
	for slot in ["q", "v", "v2", "reaction", "keystones", "axioms"]:
		unequip(slot, id)


const REACTION_TRIGGERS: Array[String] = ["catastrophe", "damage", "elite"]


## The chosen Reaction Q trigger (V4: catastrophe begins, lose 15% max HP
## to enemies, or the first elite enters 2R).
func reaction_trigger() -> String:
	return String(state.get("reaction_trigger", "catastrophe"))


func set_reaction_trigger(trigger: String) -> void:
	if REACTION_TRIGGERS.has(trigger):
		state["reaction_trigger"] = trigger


func set_mutation_enabled(id: String, enabled: bool) -> void:
	var disabled: Array = state["disabled_mutations"]
	if enabled:
		disabled.erase(id)
	elif not disabled.has(id):
		disabled.append(id)


func grant_evolution_claim(count: int = 1) -> void:
	state["evolution_claims"] = int(state.get("evolution_claims", 0)) + count


func note_segment_completed(segment: int) -> void:
	state["segments_completed"] = maxi(int(state.get("segments_completed", 0)), segment)
