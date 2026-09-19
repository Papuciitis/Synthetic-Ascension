extends Node

# Headless build simulator ("internal PoB"). Every build is bought through the
# real ledger rules, installed on the real runner and fought on the real
# combat services; nothing here is a model of the game except the scripted
# player inputs and the scripted incoming pressure, both stated in the row.
#
# Passes:
#   structure  every node's reachability, cheapest owned set to unlock it,
#              conflicts and requirement gaps, judged by AscensionLedger.can_buy
#              under an unlimited wallet and all milestones satisfied.
#   builds     the authored presets/routes plus seeded random walks per
#              native core and budget tier (a segment with its Follower budget,
#              gear rank and the ThreatDirector's enemy multipliers), each
#              fought for SIM_FRAMES frames: a native strike every 4th frame,
#              Q whenever it is off recovery, V whenever it charged naturally,
#              a dash every 90 frames, a 60-body mixed crowd refilled every 30
#              frames, contact ticks from enemies within reach and spitter /
#              sniper volleys through the player's real damage path.
#
# Run: <godot> --headless --path . res://tools/tests/BuildSimulator.tscn --quit-after 0
# Env: SIM_OUT (directory, relative to the project; default user://build_sim),
#      SIM_BUILDS (random builds per core per tier; default 4), SIM_FRAMES (600),
#      SIM_SEED (20260919), SIM_SHARD ("i/n", default "0/1"), SIM_PRESETS (1),
#      SIM_STRUCTURE (1), SIM_CROWD (60), SIM_TIERS (comma list of tier indices),
#      SIM_CORES (comma list of native cores to keep: melee, ranged, magic),
#      SIM_SET ("" = the gear seed picks the set; a set id pins it for every build),
#      SIM_GEAR_POLARITY (neg:<n>: the first n statistical set pieces roll NEG at
#      their authored floor), SIM_CURSES (comma list of curse relic ids worn in
#      their slots at their floor), SIM_AUGMENTS (up to three augment ids),
#      SIM_ABLATE (0; 1 = for every authored "pure" preset, also fight one variant
#      per owned node with that node refunded through the real refund rule, so a
#      node's contribution to its own authored build is measured directly)

const PLAYER := preload("res://core/actors/player/player.tscn")
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const Queue := preload("res://autoload/performance/PerformanceIncidentWriteQueue.gd")
const DirectorScript := preload("res://autoload/ThreatDirector.gd")
const PRESETS := "res://data/ascension/presets_v4.json"
const ROUTES := "res://data/ascension/routes_prototype.json"
const FEATURE_STATUS := "res://tools/design/v4_status.json"

## Budget tiers: the segment the build is judged at, the Followers it may
## spend on the tree, the gear rank worn, and the crowd density. Budgets are
## laboratory choices (roughly the hoards the economy probe reports), not
## claims about natural progression.
const TIERS := [
	{"name": "seg2", "segment": 2, "budget": 3000, "gear_rank": 1},
	{"name": "seg4", "segment": 4, "budget": 8000, "gear_rank": 3},
	{"name": "seg6", "segment": 6, "budget": 16000, "gear_rank": 6},
	{"name": "seg9", "segment": 9, "budget": 32000, "gear_rank": 10},
	{"name": "seg12", "segment": 12, "budget": 64000, "gear_rank": 15},
]
## The crowd mix by spec id: base HP, follower rewards, contact/ranged role.
## Values are the enemy specs' authored numbers (defaults where the spec
## does not override them).
const CROWD_MIX := [
	{"id": "enemy_grunt", "hp": 10.0, "reward": [1, 1], "weight": 30, "role": "contact"},
	{"id": "enemy_runner", "hp": 8.0, "reward": [1, 2], "weight": 14, "role": "contact"},
	{"id": "enemy_orbiter", "hp": 14.0, "reward": [2, 3], "weight": 10, "role": "contact"},
	{"id": "enemy_charger", "hp": 22.0, "reward": [3, 4], "weight": 8, "role": "contact"},
	{"id": "enemy_leech", "hp": 18.0, "reward": [3, 5], "weight": 6, "role": "contact"},
	{"id": "enemy_spitter", "hp": 16.0, "reward": [2, 3], "weight": 14, "role": "spitter"},
	{"id": "enemy_brute", "hp": 55.0, "reward": [2, 3], "weight": 8, "role": "contact"},
	{"id": "enemy_herald", "hp": 28.0, "reward": [5, 8], "weight": 4, "role": "spitter"},
	{"id": "enemy_sniper", "hp": 40.0, "reward": [1, 2], "weight": 4, "role": "sniper"},
	{"id": "enemy_splitter", "hp": 60.0, "reward": [0, 1], "weight": 2, "role": "contact"},
]
const CONTACT_DAMAGE := 10.0
const CONTACT_REACH := 56.0
const CONTACT_TICK_FRAMES := 30
const SPITTER_DAMAGE := 5.0
const SPITTER_FRAMES := 84
const SPITTER_RANGE := 300.0
const SNIPER_DAMAGE := 10.0
const SNIPER_FRAMES := 180
## Crowd durability: enemy HP is multiplied so the crowd's available HP per
## second stays well above what a build removes; otherwise kills are spawn
## limited and every build reads the same. Refill rate per half second.
const HP_DURABILITY := 4.0
const REFILL_PER_TICK := 20
const SETS := ["conduit", "lattice", "gravemarch"]
const ACCESSORIES := ["acc_oakheart", "acc_firestone", "ring_regeneration", "ring_crusher"]
const KIND_WEIGHTS := {"local": 6.0, "mutation": 4.0, "active": 8.0, "fork": 3.0, "keystone": 3.0, "revelation": 8.0,
	"revelation_mutation": 3.0, "fusion": 3.0, "axiom": 2.0, "sink": 1.0, "catastrophe": 3.0, "evolution": 4.0,
	"choice": 4.0, "gate": 1.5, "union": 2.0, "ascendant": 2.0}

var _out_dir := ""
var _builds_per_core := 4
var _frames := 600
var _seed := 20260919
var _shard := 0
var _shards := 1
var _cores: Array = []
var _include_presets := true
## SIM_SET: wear this set on every build instead of the gear seed's pick.
var _forced_set := ""
## SIM_GEAR_POLARITY=neg:<n>: the first n statistical set pieces roll NEG at
## their authored floor; SIM_CURSES=<ids>: curse relics worn in their slots
## at their floor, replacing the set piece there; SIM_AUGMENTS as above.
var _neg_pieces := 0
var _curses := ""
var _augments := ""
var _structure := true
var _crowd := 60
var _durability := HP_DURABILITY
var _ablate := false
var _tiers: Array = []
var _rng := RandomNumberGenerator.new()
var _player: Node = null
var _runner: AscensionRunner = null
var _recorder: Node = null
var _origin := Vector2.ZERO
var _spawned: Array[int] = []
var _spawn_roles: Dictionary = {}
var _attacker: Node2D = null
var _attacker_handle := 0
var _db: AscensionTreeDB = null
var _status: Dictionary = {}
var _rows_file: FileAccess = null
var _footprints: Dictionary = {}
var _rows := 0
var _started_usec := 0


static func noop_write(_batch: Dictionary, _directory: String) -> Dictionary:
	return {"ok": true, "error": "", "directory": ""}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _env(key: String, fallback: String) -> String:
	var value := OS.get_environment(key).strip_edges()
	return value if not value.is_empty() else fallback


func _run() -> void:
	_started_usec = Time.get_ticks_usec()
	var out := _env("SIM_OUT", "user://build_sim")
	_out_dir = out if out.begins_with("user://") or out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out)
	_builds_per_core = int(_env("SIM_BUILDS", "4"))
	_frames = int(_env("SIM_FRAMES", "600"))
	_seed = int(_env("SIM_SEED", "20260919"))
	var shard := _env("SIM_SHARD", "0/1").split("/")
	_shard = int(shard[0])
	_shards = maxi(1, int(shard[1]) if shard.size() > 1 else 1)
	_include_presets = _env("SIM_PRESETS", "1") != "0"
	_forced_set = _env("SIM_SET", "")
	_structure = _env("SIM_STRUCTURE", "1") != "0"
	_crowd = int(_env("SIM_CROWD", "60"))
	_durability = float(_env("SIM_HP_MUL", str(HP_DURABILITY)))
	_ablate = _env("SIM_ABLATE", "0") != "0"
	for index in _env("SIM_TIERS", "0,1,2,3,4").split(","):
		if not index.strip_edges().is_empty():
			_tiers.append(int(index))
	for core_name in _env("SIM_CORES", "").split(","):
		if not core_name.strip_edges().is_empty():
			_cores.append(core_name.strip_edges())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("user://") else _out_dir)
	_db = AscensionTreeDB.shared()
	_status = _load_json(FEATURE_STATUS)
	Global.start_new_attempt()
	Global.debug_player_god_mode = false
	Global.debug_ascension_revelations_enabled = true
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	# SIM_AUGMENTS: up to three augment ids slotted for every build (the NEG
	# archetypes read them in the stat pass and the augment runner).
	var slot := 0
	for aug in _env("SIM_AUGMENTS", "").split(","):
		var aug_id := aug.strip_edges()
		if aug_id.is_empty() or slot >= 3 or not Global.augment_db.has(StringName(aug_id)):
			continue
		Global.permanent_augment_ids[slot] = StringName(aug_id)
		slot += 1
	_augments = _env("SIM_AUGMENTS", "")
	_neg_pieces = int(_env("SIM_GEAR_POLARITY", "neg:0").trim_prefix("neg:"))
	_curses = _env("SIM_CURSES", "")
	Global.run_luck = 0.0
	_player = PLAYER.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_player.set_process(false)
	_player.set_physics_process(false)
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_origin = _player.global_position
	_attacker = Node2D.new()
	_attacker.global_position = _origin + Vector2(-400, 400)
	add_child(_attacker)
	_attacker_handle = EnemyWorld.create_enemy(SpawnState.new(&"sim_pressure", "res://sim_pressure.tscn", _attacker.global_position, 1000000.0, 0.0, 8.0, 0, 0, {"follower_reward_min": 0, "follower_reward_max": 0}))
	EnemyWorld.bind_actor(_attacker_handle, _attacker)
	_recorder = get_node("/root/BalanceRecorder")
	_recorder.record_headless = true
	_recorder.extended = false
	_recorder.report_directory = "user://build_sim_scratch"
	_recorder._queue = Queue.new(noop_write)
	ProjectileManager.clear_for_run_end()
	await get_tree().process_frame

	if _structure and _shard == 0:
		_write_json("structure.json", _structure_pass())
	_rows_file = FileAccess.open(_out_dir.path_join("builds_%d.jsonl" % _shard), FileAccess.WRITE)
	var jobs := _jobs()
	if not _cores.is_empty():
		jobs = jobs.filter(func(job: Dictionary) -> bool: return _cores.has(String(job.get("core", ""))))
	print("[sim] shard %d/%d: %d builds, %d frames each, seed %d -> %s" % [_shard, _shards, jobs.size(), _frames, _seed, _out_dir])
	var index := 0
	for job in jobs:
		index += 1
		var row: Dictionary = await _simulate(job)
		_rows_file.store_line(JSON.stringify(_recorder.Writer.json_safe(row)))
		_rows_file.flush()
		_rows += 1
		print("[sim] %3d/%d %-34s core %-6s tier %-5s nodes %2d spent %6d | hp removed %8.0f kills %3d | lost %6.0f deaths %d | casts q%d v%d | frame p95 %.1f ms | tail %s %.1f" % [index, jobs.size(), String(row.name).left(34), row.core, row.tier, int(row.node_count), int(row.spent), float(row.enemy_hp_removed), int(row.kills), float(row.player_hp_lost), int(row.deaths), int(row.q_casts), int(row.v_casts), float(row.frame_p95_ms), String(row.tail_step), float((row.step_max_ms as Dictionary).get(row.tail_step, 0.0))])
	_rows_file.close()
	print("[sim] done: %d rows in %.1f s" % [_rows, float(Time.get_ticks_usec() - _started_usec) / 1000000.0])
	get_tree().quit(0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _write_json(name: String, data: Variant) -> void:
	var file := FileAccess.open(_out_dir.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_recorder.Writer.json_safe(data), "\t"))
		file.close()


# ---------------------------------------------------------------- structure

## Judged by the real rules under an unlimited wallet with every milestone
## satisfied (segment 12 completed, evolution claims banked). For each node
## a guided walk starts from each Core it could be reached from and buys only
## what the node's requirement closure needs, preferring nodes that shorten
## the link distance to the target; the Followers it spends before the node
## becomes buyable (plus the node's own price) is `guided_unlock`, an upper
## bound on the true minimum. A node no guided walk can reach is reported
## with the requirement gaps the ledger names.
func _structure_pass() -> Dictionary:
	var nodes := {}
	var unreachable: Array = []
	var by_kind := {}
	var started := Time.get_ticks_usec()
	for id in _db.nodes:
		var kind := _db.kind(id)
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var entry := {"id": id, "kind": kind, "ring": _db.ring_of(id), "cost": _db.base_cost(id), "discipline": _db.discipline_of(id),
			"conflicts": Array(_db.conflicts(id)), "status": String((_status.get(id, {}) as Dictionary).get("status", "unknown")),
			"reachable_from": [], "guided_unlock": null, "guided_purchases": null, "closure": []}
		if kind == "core":
			entry["reachable_from"] = [id.trim_prefix("core.")]
			entry["guided_unlock"] = 0
			nodes[id] = entry
			continue
		var closure := _closure(id)
		entry["closure"] = closure.mandatory.keys()
		var cores: Array = []
		var own_core := _db.core_of(id)
		if own_core.is_empty():
			cores = AscensionTreeDB.CORES.duplicate()
		else:
			# Its own Core first; a foreign Core only when the node is out of
			# reach from its own (a Gate then opens it).
			cores = [own_core]
		var best := {}
		var attempts: Array = []
		for core in cores:
			var walk := _guided_walk(id, core, closure)
			attempts.append({"core": core, "reached": walk.reached, "purchases": (walk.purchases as Array).size(), "needed": walk.get("needed", []), "reason": walk.get("reason", ""), "last": (walk.purchases as Array).slice(maxi(0, (walk.purchases as Array).size() - 6))})
			if bool(walk.reached):
				(entry.reachable_from as Array).append(core)
				if best.is_empty() or int(walk.spent) < int(best.spent):
					best = walk
		if best.is_empty() and not own_core.is_empty():
			for other in AscensionTreeDB.CORES:
				if other == own_core:
					continue
				var walk := _guided_walk(id, other, closure)
				if bool(walk.reached):
					(entry.reachable_from as Array).append(other)
					if best.is_empty() or int(walk.spent) < int(best.spent):
						best = walk
		if not best.is_empty():
			entry["guided_unlock"] = int(best.spent)
			entry["guided_purchases"] = best.purchases
			entry["guided_core"] = best.core
		else:
			var authored := _authored_routes_reaching(id)
			entry["authored_routes"] = authored
			if not authored.is_empty():
				var cheapest_authored: Dictionary = authored[0]
				for route in authored:
					if int(route.spent) < int(cheapest_authored.spent):
						cheapest_authored = route
				entry["guided_unlock"] = int(cheapest_authored.spent)
				entry["guided_core"] = "authored: " + String(cheapest_authored.name)
				entry["reachable_from"] = ["authored route"]
			else:
				unreachable.append({"id": id, "kind": kind, "requires": _db.node(id).get("requires", {}), "attempts": attempts, "gaps": Array(_db.requirement_gaps(_db.node(id).get("requires", {}), {}, func(_m: String) -> bool: return true))})
		nodes[id] = entry
	return {"nodes": nodes, "unreachable": unreachable, "by_kind": by_kind, "node_count": _db.nodes.size(), "seconds": float(Time.get_ticks_usec() - started) / 1000000.0,
		"method": "AscensionLedger.can_buy with unlimited Followers, segment 12 completed and four evolution claims; per node, a guided walk from each Core buys only the requirement closure and the shortest link path, so guided_unlock is an upper bound on the cheapest unlock."}


func _fresh_ledger(core: String, segments_completed: int) -> AscensionLedger:
	var ledger := AscensionLedger.new(_db, AscensionLedger.fresh_state(core))
	ledger.note_segment_completed(segments_completed)
	return ledger


## Ids the node's requirements name, transitively: mandatory (`owned` under
## `all`) and optional (`count` lists, `any` branches and everything under
## them). Used only to size a node's dependency footprint.
func _closure(id: String) -> Dictionary:
	var mandatory := {}
	var optional := {}
	var pending: Array = [[id, true]]
	var seen := {}
	while not pending.is_empty():
		var item: Array = pending.pop_back()
		var current := String(item[0])
		var mandatory_context := bool(item[1])
		if seen.has(current):
			continue
		seen[current] = true
		_collect_rule(_db.node(current).get("requires", {}), mandatory_context, mandatory, optional, pending)
	mandatory.erase(id)
	optional.erase(id)
	return {"mandatory": mandatory, "optional": optional}


func _collect_rule(rule: Variant, mandatory_context: bool, mandatory: Dictionary, optional: Dictionary, pending: Array) -> void:
	if not (rule is Dictionary):
		return
	var dict := rule as Dictionary
	if dict.has("all"):
		for child in dict["all"]:
			_collect_rule(child, mandatory_context, mandatory, optional, pending)
	elif dict.has("any"):
		for child in dict["any"]:
			_collect_rule(child, false, mandatory, optional, pending)
	elif dict.has("owned"):
		var other := String(dict["owned"])
		if mandatory_context:
			mandatory[other] = true
		else:
			optional[other] = true
		pending.append([other, mandatory_context])
	elif dict.has("count"):
		for other in (dict["count"] as Dictionary).get("ids", []):
			optional[String(other)] = true
			pending.append([String(other), false])


## What the target still lacks right now, as id -> priority (0: required
## outright, 1: one option of a group), following unowned needs into their
## own gaps so a walk can approach a deep option step by step.
func _gap_ids(ledger: AscensionLedger, rule: Variant, out: Dictionary, priority: int, depth: int) -> void:
	if depth > 8 or not (rule is Dictionary):
		return
	var dict := rule as Dictionary
	var owned := ledger.owned()
	var milestones := Callable(ledger, "milestone")
	if _db.requirement_holds(dict, owned, milestones):
		return
	if dict.has("all"):
		for child in dict["all"]:
			_gap_ids(ledger, child, out, priority, depth)
	elif dict.has("any"):
		for child in dict["any"]:
			_gap_ids(ledger, child, out, maxi(priority, 1), depth)
	elif dict.has("owned"):
		var other := String(dict["owned"])
		if not ledger.owns(other):
			if not out.has(other) or int(out[other]) > priority:
				out[other] = priority
			if priority == 0 or depth < 3:
				_gap_ids(ledger, _db.node(other).get("requires", {}), out, priority, depth + 1)
	elif dict.has("count"):
		# Each unowned option is a goal, and so is what it needs itself.
		var listed: Array = (dict["count"] as Dictionary).get("ids", [])
		var follow := listed.size() <= 12 and depth < 2
		for other in listed:
			if not ledger.owns(String(other)):
				if not out.has(String(other)) or int(out[String(other)]) > 1:
					out[String(other)] = 1
				if follow:
					_gap_ids(ledger, _db.node(String(other)).get("requires", {}), out, 1, depth + 1)
	elif dict.has("milestone"):
		var name := String(dict["milestone"])
		var ids: Array = []
		if name == "one_fusion_owned":
			ids = _db.ids_of_kind("fusion")
		elif name.begins_with("union_diversity_"):
			# Three Fusions on the border spanning two disciplines on each
			# side: prefer Fusions that add a discipline the owned ones lack.
			var prefix := name.substr(name.length() - 2).to_upper()
			var left := {}
			var right := {}
			for fusion_id in ledger.owned_of_kind("fusion"):
				if String(fusion_id).begins_with(prefix):
					var pair := _db.fusion_disciplines(String(fusion_id))
					if pair.size() >= 2:
						left[pair[0]] = true
						right[pair[1]] = true
			for fusion_id in _db.ids_of_kind("fusion"):
				if not String(fusion_id).begins_with(prefix) or ledger.owns(String(fusion_id)):
					continue
				var pair := _db.fusion_disciplines(String(fusion_id))
				var adds := pair.size() >= 2 and (not left.has(pair[0]) or not right.has(pair[1]))
				if adds or left.size() >= 2 and right.size() >= 2:
					ids.append(fusion_id)
		for other in ids:
			if not ledger.owns(String(other)) and (not out.has(String(other)) or int(out[String(other)]) > 1):
				out[String(other)] = 1
				if depth < 2:
					_gap_ids(ledger, _db.node(String(other)).get("requires", {}), out, 1, depth + 1)


func _footprint(id: String) -> int:
	if not _footprints.has(id):
		var closure := _closure(id)
		_footprints[id] = (closure.mandatory as Dictionary).size() + (closure.optional as Dictionary).size() / 4
	return int(_footprints[id])


## Multi-source link distance from every node to the nearest of `sources`.
func _distances_from(sources: Array) -> Dictionary:
	var dist := {}
	var queue: Array = []
	for source in sources:
		dist[String(source)] = 0
		queue.append(String(source))
	var reverse := {}
	for id in _db.nodes:
		for other in _db.neighbours(id):
			if not reverse.has(String(other)):
				reverse[String(other)] = []
			(reverse[String(other)] as Array).append(id)
	while not queue.is_empty():
		var current := String(queue.pop_front())
		var next_distance := int(dist[current]) + 1
		var around: Array = []
		for other in _db.neighbours(current):
			around.append(String(other))
		around.append_array(reverse.get(current, []))
		for other in around:
			if not dist.has(String(other)):
				dist[String(other)] = next_distance
				queue.append(String(other))
	return dist


func _guided_walk(target: String, core: String, closure: Dictionary) -> Dictionary:
	var ledger := _fresh_ledger(core, 12)
	ledger.grant_evolution_claim(4)
	var spent := 0
	var purchases: Array = []
	var target_core := _db.core_of(target)
	var target_rule: Variant = _db.node(target).get("requires", {})
	for _step in range(200):
		var chosen_for_target := ""
		if _db.kind(target) == "gate":
			for candidate in AscensionTreeDB.CORES:
				if not ledger.has_core(candidate):
					chosen_for_target = candidate
					break
		var verdict := ledger.can_buy(target, 1 << 30, chosen_for_target)
		if bool(verdict.ok):
			return {"reached": true, "spent": spent + int(verdict.cost), "purchases": purchases, "core": core}
		# What is still missing: requirement gaps, a Core the target or a
		# needed node lives in, then adjacency toward the target itself.
		var needed := {}
		_gap_ids(ledger, target_rule, needed, 0, 0)
		if not target_core.is_empty() and not ledger.has_core(target_core):
			needed["core." + target_core] = 0
		var cores_needed := {}
		for id in needed:
			var id_core := _db.core_of(String(id))
			if not id_core.is_empty() and not ledger.has_core(id_core):
				cores_needed[id_core] = int(needed[id])
		var goals: Array = needed.keys()
		if goals.is_empty():
			goals = [target]
		var dist := _distances_from(goals)
		var candidates := {}
		for owned_id in ledger.owned_ids():
			for other in _db.neighbours(String(owned_id)):
				candidates[String(other)] = true
		for id in needed:
			candidates[String(id)] = true
		for gate_id in _db.ids_of_kind("gate"):
			candidates[String(gate_id)] = true
		for choice_id in _db.ids_of_kind("choice"):
			candidates[String(choice_id)] = true
		var best := ""
		var best_key := [9, 1 << 30, 1 << 30, 1 << 30]
		var best_core := ""
		for id in candidates:
			var kind := _db.kind(id)
			if kind == "core" or id == target or ledger.owns(id):
				continue
			var chosen := ""
			if kind == "gate":
				for candidate_core in cores_needed:
					chosen = String(candidate_core)
					break
				if chosen.is_empty():
					continue
			var step_verdict := ledger.can_buy(id, 1 << 30, chosen)
			if not bool(step_verdict.ok):
				continue
			var priority := 3
			if needed.has(id):
				priority = int(needed[id])
			elif kind == "gate":
				priority = 0
			var footprint := _footprint(id) if priority <= 1 else 0
			var key := [priority, footprint, int(dist.get(id, 1 << 20)), int(step_verdict.cost)]
			if key < best_key:
				best_key = key
				best = id
				best_core = chosen
		if best.is_empty():
			return {"reached": false, "spent": spent, "purchases": purchases, "core": core, "needed": needed.keys(), "reason": String(verdict.reason)}
		if _db.kind(best) == "evolution":
			ledger.grant_evolution_claim()
		spent += ledger.record_purchase(best, int(best_key[3]), best_core)
		purchases.append(best)
	return {"reached": false, "spent": spent, "purchases": purchases, "core": core, "needed": [], "reason": "step cap"}


## Authored routes that contain a node, replayed through the real rules:
## the cross-check for anything the guided walk could not reach.
func _authored_routes_reaching(id: String) -> Array:
	var found: Array = []
	var lists: Array = []
	for preset in _load_json(PRESETS).get("presets", []):
		lists.append(preset)
	for build in _db.builds:
		lists.append(build)
	for route in _load_json(ROUTES).get("routes", []):
		lists.append(route)
	for entry in lists:
		var nodes: Array = entry.get("nodes", [])
		if not nodes.has(id):
			continue
		var ledger := _fresh_ledger(String(entry.get("native_core", "melee")), 12)
		ledger.grant_evolution_claim(4)
		var spent := 0
		var ok := true
		for index in range(nodes.size()):
			var node_id := String(nodes[index])
			if node_id.begins_with("core."):
				continue
			var chosen := ""
			if _db.kind(node_id) == "gate" and index + 1 < nodes.size() and String(nodes[index + 1]).begins_with("core."):
				chosen = String(nodes[index + 1]).trim_prefix("core.")
			var verdict := ledger.can_buy(node_id, 1 << 30, chosen)
			if not bool(verdict.ok):
				ok = false
				break
			if _db.kind(node_id) == "evolution":
				ledger.grant_evolution_claim()
			spent += ledger.record_purchase(node_id, int(verdict.cost), chosen)
			if node_id == id:
				break
		if ok:
			found.append({"name": String(entry.get("name", "")), "spent": spent})
	return found


# ---------------------------------------------------------------- build generation

func _jobs() -> Array:
	var jobs: Array = []
	if _include_presets:
		var presets: Array = _load_json(PRESETS).get("presets", [])
		for preset in presets:
			jobs.append({"name": String(preset.name), "source": "preset", "core": String(preset.native_core), "nodes": preset.nodes, "equip": preset.get("equip", {}), "tier": _tier_for_cost(preset)})
		for build in _db.builds:
			jobs.append({"name": "Authored: " + String(build.name), "source": "authored", "core": String(build.native_core), "nodes": build.nodes, "equip": build.get("equip", {}), "tier": _tier_for_cost(build)})
		for route in _load_json(ROUTES).get("routes", []):
			jobs.append({"name": "Route: " + String(route.name), "source": "route", "core": String(route.native_core), "nodes": route.nodes, "equip": route.get("equip", {}), "tier": _tier_for_cost(route)})
	for tier_index in _tiers:
		if tier_index < 0 or tier_index >= TIERS.size():
			continue
		for core in AscensionTreeDB.CORES:
			for n in range(_builds_per_core):
				jobs.append({"name": "random %s %s #%d" % [core, TIERS[tier_index].name, n], "source": "random", "core": core, "nodes": [], "equip": {}, "tier": tier_index, "random_index": n})
	if _ablate:
		# Every "pure" preset, then one variant per owned node with that node
		# (and whatever the real refund rule removes with it) taken away.
		var presets: Array = _load_json(PRESETS).get("presets", [])
		var only := _env("SIM_ABLATE_PRESETS", "")
		var base_index := jobs.size()
		for preset in presets:
			if String(preset.get("tier", "")) != "pure":
				continue
			if not only.is_empty() and not only.split(",").has(String(preset.name)):
				continue
			var base_job := {"name": "Ablation base: " + String(preset.name), "source": "ablation_base", "core": String(preset.native_core), "nodes": preset.nodes, "equip": preset.get("equip", {}), "tier": _tier_for_cost(preset), "gear_seed": base_index, "ablation_of": String(preset.name)}
			jobs.append(base_job)
			# The same whole build on a second crowd stream: the noise floor.
			var repeat := base_job.duplicate()
			repeat["name"] = "Ablation repeat: " + String(preset.name)
			repeat["source"] = "ablation_repeat"
			repeat["fight_seed_offset"] = 1
			jobs.append(repeat)
			for id in preset.nodes:
				var kind := _db.kind(String(id))
				if kind in ["core", "gate", "choice"]:
					continue
				jobs.append({"name": "Ablation: %s - %s" % [String(preset.name), String(id)], "source": "ablation", "core": String(preset.native_core), "nodes": preset.nodes, "equip": preset.get("equip", {}), "tier": int(base_job.tier), "gear_seed": base_index, "ablation_of": String(preset.name), "ablate": String(id)})
			base_index = jobs.size()
	# Shard by stable index so shards never overlap and never miss a job.
	var mine: Array = []
	for index in range(jobs.size()):
		if index % _shards == _shard:
			var job: Dictionary = jobs[index]
			job["job_index"] = index
			mine.append(job)
	return mine


func _tier_for_cost(build: Dictionary) -> int:
	var cost := 0
	for id in build.get("nodes", []):
		cost += _db.base_cost(String(id))
	for index in range(TIERS.size()):
		if cost <= int(TIERS[index].budget):
			return index
	return TIERS.size() - 1


## A seeded random walk through the real purchase rules: every step picks
## among the currently buyable nodes, weighted by kind, and buys it. Gates
## open a random closed Core. Stops when nothing is affordable.
func _random_build(core: String, tier: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state := AscensionLedger.fresh_state(core)
	var ledger := AscensionLedger.new(_db, state)
	var segment := int(tier.segment)
	ledger.note_segment_completed(segment - 1)
	var claims := 0
	for completed in [6, 9, 12, 15]:
		if segment - 1 >= completed:
			claims += 1
	ledger.grant_evolution_claim(claims)
	var wallet := int(tier.budget)
	var order: Array = []
	var guard := 0
	while guard < 400:
		guard += 1
		var options: Array = []
		var weights: Array = []
		for id in _db.nodes:
			var kind := _db.kind(id)
			if kind == "core":
				continue
			if ledger.owns(id) and kind != "sink":
				continue
			var chosen := ""
			if kind == "gate":
				var closed: Array = []
				for candidate in AscensionTreeDB.CORES:
					if not ledger.has_core(candidate):
						closed.append(candidate)
				if closed.is_empty():
					continue
				chosen = String(closed[rng.randi_range(0, closed.size() - 1)])
			var verdict := ledger.can_buy(id, wallet, chosen)
			if not bool(verdict.ok):
				continue
			var weight := float(KIND_WEIGHTS.get(kind, 1.0))
			if kind == "sink":
				weight = weight / float(1 + ledger.rank(id))
			options.append({"id": id, "cost": int(verdict.cost), "core": chosen})
			weights.append(weight)
		if options.is_empty():
			break
		var pick := _weighted(rng, weights)
		var option: Dictionary = options[pick]
		if _db.kind(option.id) == "evolution" and int(state.get("evolution_claims", 0)) <= 0:
			continue
		wallet -= int(option.cost)
		ledger.record_purchase(String(option.id), int(option.cost), String(option.core))
		order.append(String(option.id))
	# Random equipment among what is owned (the ledger auto-equips the first).
	for slot in ["q", "v"]:
		var owned: Array = ledger.owned_of_kind("active" if slot == "q" else "revelation")
		if owned.size() > 1:
			ledger.equip(slot, String(owned[rng.randi_range(0, owned.size() - 1)]))
	return {"state": state, "order": order, "spent": int(state.get("spent", 0))}


func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += float(weight)
	var roll := rng.randf() * total
	for index in range(weights.size()):
		roll -= float(weights[index])
		if roll <= 0.0:
			return index
	return weights.size() - 1


# ---------------------------------------------------------------- install

## Installs a job on the live runner: fresh attempt state, purchases through
## the real rules (authored lists in order, random walks replayed), gear for
## the tier, real stat recompute.
func _install(job: Dictionary) -> Dictionary:
	_clear_enemies()
	var core := String(job.core)
	var tier: Dictionary = TIERS[int(job.tier)]
	Global.selected_style_id = core
	var result := {"failed": "", "spent": 0, "order": []}
	if String(job.source) == "random":
		var built := _random_build(core, tier, _seed * 7919 + int(job.job_index) * 104729 + int(job.random_index))
		Global.attempt_ascension = built.state
		result["spent"] = int(built.spent)
		result["order"] = built.order
	else:
		Global.attempt_ascension = AscensionLedger.fresh_state(core)
		var ledger := Global.ascension_ledger()
		ledger.note_segment_completed(12)
		ledger.grant_evolution_claim(4)
		var nodes: Array = job.nodes
		for index in range(nodes.size()):
			var id := String(nodes[index])
			if id.begins_with("core."):
				continue
			var chosen := ""
			if _db.kind(id) == "gate" and index + 1 < nodes.size() and String(nodes[index + 1]).begins_with("core."):
				chosen = String(nodes[index + 1]).trim_prefix("core.")
			var verdict := ledger.can_buy(id, 100000000, chosen)
			if not bool(verdict.ok):
				result["failed"] = "%s: %s" % [id, verdict.reason]
				break
			result["spent"] = int(result.spent) + ledger.record_purchase(id, int(verdict.cost), chosen)
			(result.order as Array).append(id)
		var equip: Variant = job.get("equip", {})
		if equip is Dictionary:
			for slot in ["q", "v", "v2", "reaction"]:
				var id_for_slot := String((equip as Dictionary).get(slot, ""))
				if not id_for_slot.is_empty():
					ledger.equip(slot, id_for_slot)
			for slot in ["keystones", "axioms"]:
				for id_for_slot in (equip as Dictionary).get(slot, []):
					ledger.equip(slot, String(id_for_slot))
		var ablate := String(job.get("ablate", ""))
		if not ablate.is_empty():
			# The real refund rule: dependents that can no longer reach a Core
			# or whose requirements no longer hold leave with the node.
			var before: Array = ledger.owned_ids().duplicate()
			ledger.refund(ablate, 1.0, true)
			var removed: Array = []
			for id in before:
				if not ledger.owns(String(id)):
					removed.append(String(id))
			result["removed"] = removed
			# Re-equip what the refund left unequipped, as the ledger would on a
			# later purchase, so a refunded Q does not silently disable casting.
			for slot in ["q", "v"]:
				if ledger.equipped(slot).is_empty():
					for other in ledger.owned_of_kind("active" if slot == "q" else "revelation"):
						if ledger.equip(slot, String(other)):
							break
	Global.ascension_ledger()
	Global.attempt_segment = int(tier.segment)
	_wear_gear(job, tier)
	var race: RaceData = Global.race_db.get("human", null)
	var style: StyleData = Global.style_db.get(core, null)
	_player.recompute_run_stats(race, style, false)
	_runner.q_cooldown_left = 0.0
	_runner._saved_recovery.clear()
	_runner._v_gap_left = 0.0
	_runner.v_charge = 0.0
	_runner.v2_charge = 0.0
	_runner._q_holding = false
	_player.global_position = _origin
	_player.hp = _player.max_hp
	_player.invulnerable_time = 0.0
	_player.respawn_phase_left = 0.0
	_runner.aim_override = _origin + Vector2(200, 0)
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	for key in _runner.telemetry:
		_runner.telemetry[key] = 0
	return result


## Gear for the tier: one set's six core items at the tier rank plus two
## accessories, all neutral positive rolls. The set and accessories are
## chosen from the job's seed so a build is reproducible.
func _wear_gear(job: Dictionary, tier: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 31 + int(job.get("gear_seed", job.job_index)) * 977
	var set_id: String = SETS[rng.randi_range(0, SETS.size() - 1)]
	if SETS.has(_forced_set):
		set_id = _forced_set
	var rank := int(tier.gear_rank)
	Global.run_inventory.clear()
	var worn: Array = []
	for id in Global.item_db:
		var data: ItemData = Global.item_db[id]
		if String(data.set_id) == set_id and int(data.equip_slot) >= 0 and int(data.equip_slot) < Inventory.STAT_SLOT_COUNT:
			Global.run_inventory.set_item(int(data.equip_slot), ItemInstance.from_roll(data, rank, ItemInstance.Polarity.POS, 0.0, false), null)
			worn.append(String(data.id))
	var offhand: String = ACCESSORIES[rng.randi_range(0, 1)]
	var ring: String = ACCESSORIES[rng.randi_range(2, 3)]
	for id in [offhand, ring]:
		var data: ItemData = Global.item_db.get(id, null)
		if data != null:
			Global.run_inventory.set_item(int(data.equip_slot), ItemInstance.from_roll(data, rank, ItemInstance.Polarity.POS, 0.0, false), null)
			worn.append(id)
	# NEG wardrobes: the first n statistical pieces at their authored floor.
	var cursed_slots: Array = []
	for slot in range(mini(_neg_pieces, Inventory.STAT_SLOT_COUNT)):
		var piece: ItemInstance = Global.run_inventory.get_at(slot)
		if piece == null or piece.data == null or piece.data.pct_min >= 0.0:
			continue
		Global.run_inventory.set_item(slot, ItemInstance.from_roll(piece.data, rank, ItemInstance.Polarity.NEG, piece.data.pct_min, false), null)
		cursed_slots.append(slot)
	var relics: Array = []
	for curse in _curses.split(","):
		var curse_id := curse.strip_edges()
		var data: ItemData = Global.item_db.get(curse_id, null)
		if curse_id.is_empty() or data == null or int(data.equip_slot) < 0 or int(data.equip_slot) >= Inventory.STAT_SLOT_COUNT:
			continue
		Global.run_inventory.set_item(int(data.equip_slot), ItemInstance.from_roll(data, rank, ItemInstance.Polarity.NEG, data.pct_min, false), null)
		relics.append(curse_id)
	return {"set": set_id, "rank": rank, "worn": worn, "cursed_slots": cursed_slots, "relics": relics, "augments": _augments}


# ---------------------------------------------------------------- crowd

func _spawn(spec: Dictionary, at: Vector2, hp_mul: float, elite: bool) -> int:
	var hp := float(spec.hp) * hp_mul * _durability * (1.6 if elite else 1.0)
	var flags := EnemyWorldTypes.Flags.ELITE if elite else 0
	var handle := EnemyWorld.create_enemy(SpawnState.new(StringName(String(spec.id)), "res://sim/%s.tscn" % String(spec.id), at, hp, 10.0, 8.0, 0, flags, {"follower_reward_min": int(spec.reward[0]), "follower_reward_max": int(spec.reward[1]), "elite_follower_bonus": 3}))
	_spawned.append(handle)
	_spawn_roles[handle] = String(spec.role)
	return handle


func _pick_spec(rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array = []
	for spec in CROWD_MIX:
		weights.append(float(spec.weight))
	return CROWD_MIX[_weighted(rng, weights)]


func _clear_enemies() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"sim")
	_spawned.clear()
	_spawn_roles.clear()
	ProjectileManager.clear_for_run_end()
	if _runner != null:
		_runner.flush_attacks()


func _alive() -> Array[int]:
	var out: Array[int] = []
	for handle in _spawned:
		if _runner.enemy_alive(handle):
			out.append(handle)
	return out


func _native_tags(core: String, cast: int) -> PackedStringArray:
	var path: String = {"melee": "slash", "ranged": "bullet", "magic": "impact"}[core]
	var tags := AscensionTags.native(core, path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	if core == "melee":
		tags = AscensionTags.with_flag(tags, "execute_enabled")
	tags.append("cast:native:%d" % cast)
	return tags


func _pressure(segment: int) -> Dictionary:
	var director := DirectorScript.new()
	director.set_process(false)
	add_child(director)
	var saved := Global.attempt_segment
	Global.attempt_segment = segment
	director.call("reset_run_state")
	director.call("set_segment_phase", &"disturbance")
	director.call("_on_resonance_changed", 0.6)
	var result := {"enemy_hp_mul": float(director.get("enemy_hp_mul")), "enemy_damage_mul": float(director.get("enemy_damage_mul")), "threat": float(director.get("threat"))}
	Global.attempt_segment = saved
	director.queue_free()
	return result


# ---------------------------------------------------------------- one build

func _simulate(job: Dictionary) -> Dictionary:
	var tier: Dictionary = TIERS[int(job.tier)]
	var core := String(job.core)
	var installed := _install(job)
	var gear := _wear_gear(job, tier)
	var pressure := _pressure(int(tier.segment))
	var ledger := Global.ascension_ledger()
	var row := {"name": job.name, "source": job.source, "core": core, "tier": tier.name, "segment": int(tier.segment), "budget": int(tier.budget),
		"job_index": int(job.job_index), "failed": installed.failed, "spent": int(installed.spent), "nodes": ledger.owned_ids(), "node_count": ledger.owned_ids().size(),
		"ablation_of": job.get("ablation_of", ""), "ablate": job.get("ablate", ""), "removed": installed.get("removed", []),
		"order": installed.order, "equipped": (ledger.state.get("equipped", {}) as Dictionary).duplicate(true), "gear": gear,
		"player": {"max_hp": float(_player.max_hp), "armor": float(_player.stats.armor), "power": float(_player.stats.power), "haste": float(_player.stats.haste), "luck": float(_player.stats.luck), "move_speed": float(_player.stats.move_speed)},
		"pressure": pressure, "frames": _frames, "crowd": _crowd, "durability": _durability, "refill_per_tick": REFILL_PER_TICK}
	if not String(installed.failed).is_empty():
		row["enemy_hp_removed"] = 0.0
		row["kills"] = 0
		row["player_hp_lost"] = 0.0
		row["deaths"] = 0
		row["q_casts"] = 0
		row["v_casts"] = 0
		row["frame_p95_ms"] = 0.0
		return row
	Global.set_followers(100000)
	Global.attempt_deaths_this_segment = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 13 + int(job.get("gear_seed", job.job_index)) + int(job.get("fight_seed_offset", 0)) * 7919
	var hp_mul := float(pressure.enemy_hp_mul)
	var dmg_mul := float(pressure.enemy_damage_mul)
	for i in range(_crowd):
		_spawn(_pick_spec(rng), _origin + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(30.0, 320.0), hp_mul, i % 15 == 14)
	_recorder.begin_gameplay(_player)
	_recorder.set_process(false)
	var strikes := 0
	var q_casts := 0
	var v_casts := 0
	var deaths := 0
	var contact_ticks := 0
	var volleys := 0
	var min_hp: float = _player.hp
	var hp_samples: Array = []
	var frame_ms: Array = []
	# Per-step cost of the scripted frame (the fight's own synchronous work:
	# the recorder's window, the native strike and every hook it fires, Q / V
	# / dash, scripted pressure, the crowd refill), so a slow build names
	# the step behind its tail.
	var step_ms: Dictionary = {"recorder": [], "strike": [], "casts": [], "pressure": [], "refill": []}
	# Inside the strike: the tree's hit handling (runner + engines on_hit) and
	# the enemy lifecycle work of the kills it causes; the rest is the combat
	# service, set hooks, drops and the recorder's callbacks.
	var strike_split: Dictionary = {"tree_hit": [], "lifecycle": [], "damaged_emit": [], "battletext": [], "hit_landed": [], "death": [], "other": []}
	EnemyCombatService.debug_timing = true
	var v_first_frame := -1
	var q_hold_until := 0
	var q_holding := false
	var spawned_total := _crowd
	var hp_before_frames: float = _player.hp
	for frame in range(_frames):
		await get_tree().process_frame
		var frame_start := Time.get_ticks_usec()
		var step_usec := frame_start
		_recorder._process(1.0 / 60.0)
		var frame_steps: Dictionary = {"recorder": float(Time.get_ticks_usec() - step_usec) / 1000.0}
		step_usec = Time.get_ticks_usec()
		var alive := _alive()
		var hit_usec_before: int = int(_runner.get("_frame_hit_usec"))
		var lifecycle_before := _lifecycle_usec()
		var combat_before: Dictionary = EnemyCombatService.debug_usec.duplicate()
		if frame % 4 == 0 and not alive.is_empty():
			# Fight what is on you: the nearest body most of the time, a random
			# one otherwise so ranged builds still spread their attention.
			var target: int = alive[rng.randi_range(0, alive.size() - 1)]
			if rng.randf() < 0.7:
				var best_distance := INF
				for handle in alive:
					var distance := _runner.enemy_position(handle).distance_squared_to(_player.global_position)
					if distance < best_distance:
						best_distance = distance
						target = handle
			var target_pos := _runner.enemy_position(target)
			_runner.aim_override = target_pos
			RunEvents.weapon_fired.emit(_player, StringName(core), _origin, target_pos, 1.0, 1.0)
			strikes += 1
			if core == "ranged":
				_player.call("_spawn_ranged_bullet", _origin, (target_pos - _origin).normalized(), _runner.native_damage())
			else:
				_runner.damage_enemy(target, _runner.native_damage(), _native_tags(core, strikes))
		frame_steps["strike"] = float(Time.get_ticks_usec() - step_usec) / 1000.0
		var tree_hit_ms := float(int(_runner.get("_frame_hit_usec")) - hit_usec_before) / 1000.0
		var lifecycle_ms := float(_lifecycle_usec() - lifecycle_before) / 1000.0
		(strike_split["tree_hit"] as Array).append(tree_hit_ms)
		(strike_split["lifecycle"] as Array).append(lifecycle_ms)
		var combat_ms := 0.0
		for part in ["damaged_emit", "battletext", "hit_landed", "death"]:
			var part_ms := float(int(EnemyCombatService.debug_usec[part]) - int(combat_before[part])) / 1000.0
			(strike_split[part] as Array).append(part_ms)
			combat_ms += part_ms
		(strike_split["other"] as Array).append(maxf(0.0, float(frame_steps["strike"]) - tree_hit_ms - lifecycle_ms - combat_ms))
		step_usec = Time.get_ticks_usec()
		# A held Q (Guard, Deadshot, Designate) is pressed once, fed through
		# the engine's hold hook for two seconds, then released with the
		# runner's recovery rule, exactly as a held key does; the hold state
		# is tracked here because not every hold engine reports q_active.
		# A tap Q is pressed whenever it is off recovery.
		var q_engine: AscensionEngine = _runner.engine_for(_runner.q_id) if not _runner.q_id.is_empty() else null
		if q_holding:
			if q_engine == null:
				q_holding = false
			else:
				q_engine.hold_q(_runner.q_id, 1.0 / 60.0)
				if frame >= q_hold_until:
					q_holding = false
					var released: Dictionary = q_engine.release_q(_runner.q_id)
					var cooldown: float = _runner._recovery(float(released.get("cooldown", 0.0)))
					_runner.q_cooldown_max = cooldown
					_runner.q_cooldown_left = cooldown
		elif _runner.q_cooldown_left <= 0.0 and not _runner.q_id.is_empty() and frame % 6 == 3:
			if bool(_runner.activate_q().get("ok", false)):
				q_casts += 1
				if q_engine != null and q_engine.q_is_hold(_runner.q_id):
					q_holding = true
					q_hold_until = frame + 120
		if _runner.v_charge >= AscensionRunner.V_CHARGE_MAX and not _runner.v_id.is_empty() and _runner._v_gap_left <= 0.0:
			if bool(_runner.activate_v().get("ok", false)):
				v_casts += 1
				if v_first_frame < 0:
					v_first_frame = frame
		if frame % 90 == 40 and not _player.is_dashing():
			_runner.dash_toward(Vector2.from_angle(rng.randf_range(0.0, TAU)), 160.0)
		frame_steps["casts"] = float(Time.get_ticks_usec() - step_usec) / 1000.0
		step_usec = Time.get_ticks_usec()
		# Scripted pressure through the real damage path: contact ticks from
		# enemies within reach, spitter volleys in range, one sniper shot.
		if frame % CONTACT_TICK_FRAMES == CONTACT_TICK_FRAMES - 1:
			var touching := 0
			var spitters := 0
			var snipers := 0
			for handle in alive:
				var distance := _runner.enemy_position(handle).distance_to(_player.global_position)
				var role := String(_spawn_roles.get(handle, "contact"))
				if role == "contact" and distance <= CONTACT_REACH:
					touching += 1
				elif role == "spitter" and distance <= SPITTER_RANGE:
					spitters += 1
				elif role == "sniper":
					snipers += 1
			if touching > 0 and not _player.is_dead:
				var swarm := minf(2.25, 1.0 + float(touching - 1) * 0.35)
				_player.take_damage(CONTACT_DAMAGE * swarm * dmg_mul, _attacker)
				contact_ticks += 1
			if frame % SPITTER_FRAMES < CONTACT_TICK_FRAMES and spitters > 0 and not _player.is_dead:
				_player.take_damage(SPITTER_DAMAGE * dmg_mul * float(mini(spitters, 4)), _attacker)
				volleys += 1
			if frame % SNIPER_FRAMES < CONTACT_TICK_FRAMES and snipers > 0 and not _player.is_dead:
				_player.take_damage(SNIPER_DAMAGE * dmg_mul, _attacker)
				volleys += 1
			if _player.hp < hp_before_frames and _player.hp <= 0.0:
				deaths += 1
		frame_steps["pressure"] = float(Time.get_ticks_usec() - step_usec) / 1000.0
		step_usec = Time.get_ticks_usec()
		min_hp = minf(min_hp, float(_player.hp))
		if frame % 30 == 0:
			hp_samples.append(float(_player.hp))
		if frame % 30 == 15:
			var deficit := _crowd - alive.size()
			for i in range(mini(deficit, REFILL_PER_TICK)):
				_spawn(_pick_spec(rng), _origin + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(40.0, 320.0), hp_mul, false)
				spawned_total += 1
		frame_steps["refill"] = float(Time.get_ticks_usec() - step_usec) / 1000.0
		frame_ms.append(float(Time.get_ticks_usec() - frame_start) / 1000.0)
		for step_name in step_ms:
			(step_ms[step_name] as Array).append(float(frame_steps.get(step_name, 0.0)))
	for _i in range(90):
		await get_tree().process_frame
		if _runner.pending_attacks().is_empty() and ProjectileManager.active_count() == 0:
			break
	_runner.flush_attacks()
	var summary: Dictionary = _recorder.get_summary()
	_recorder.end_capture("sim")
	var totals: Dictionary = summary.totals
	var by_node := {}
	var by_origin := {}
	for key in totals.attribution.by_emitter:
		var parts: PackedStringArray = String(key).split(":")
		var node_id := parts[1] if parts.size() >= 2 and parts[0] == "ascension" else String(key)
		var entry: Dictionary = totals.attribution.by_emitter[key]
		if not by_node.has(node_id):
			by_node[node_id] = {"hp_removed": 0.0, "hits": 0, "kills": 0}
		by_node[node_id]["hp_removed"] = float(by_node[node_id]["hp_removed"]) + float(entry.get("hp_removed", 0.0))
		by_node[node_id]["hits"] = int(by_node[node_id]["hits"]) + int(entry.get("hits", 0))
		by_node[node_id]["kills"] = int(by_node[node_id]["kills"]) + int(entry.get("kills", 0))
	for key in totals.attribution.by_origin:
		var entry: Dictionary = totals.attribution.by_origin[key]
		by_origin[String(key)] = {"hp_removed": float(entry.get("hp_removed", 0.0)), "kills": int(entry.get("kills", 0)), "casts": int(entry.get("casts", 0))}
	var engines := {}
	var described: Dictionary = _runner.describe()
	for key in described:
		if described[key] is Dictionary and key not in ["telemetry"]:
			engines[String(key)] = described[key]
	var seconds := float(_frames) / 60.0
	row.merge({
		"enemy_hp_removed": float(totals.enemy_hp_removed), "kills": int(totals.kills), "spawned": spawned_total,
		"hp_per_second": float(totals.enemy_hp_removed) / seconds, "kills_per_second": float(totals.kills) / seconds,
		"player_hp_lost": float(totals.player_hp_lost), "player_damage_before_defenses": float(totals.player_damage_before_defenses),
		"healing": float(totals.healing), "deaths": int(totals.deaths), "min_hp": min_hp, "hp_samples": hp_samples,
		"evaded_hits": int(totals.evaded_hits), "intercepted_hits": int(totals.intercepted_hits), "contact_ticks": contact_ticks, "volleys": volleys,
		"followers_earned": int(totals.followers_earned), "combat_income": int((totals.followers_by_reason.get("combat_influence", {}) as Dictionary).get("gained", 0)),
		"followers_per_minute": float((totals.followers_by_reason.get("combat_influence", {}) as Dictionary).get("gained", 0)) / (seconds / 60.0),
		"strikes": strikes, "q_casts": q_casts, "v_casts": v_casts, "v_first_second": (float(v_first_frame) / 60.0) if v_first_frame >= 0 else null,
		"generated": int(_runner.telemetry.get("generated", 0)), "tree_hits": int(_runner.telemetry.get("tree_hits", 0)), "tree_kills": int(_runner.telemetry.get("tree_kills", 0)),
		"chain_kills": int(_runner.telemetry.get("chain_kills", 0)), "catastrophes": int(_runner.telemetry.get("catastrophes", 0)), "r0": _runner.r0(),
		"by_node": by_node, "by_origin": by_origin, "engines": engines, "attribution_coverage": summary.attribution_coverage,
		"frame_p50_ms": _pct(frame_ms, 0.5), "frame_p95_ms": _pct(frame_ms, 0.95), "frame_p99_ms": _pct(frame_ms, 0.99), "frame_max_ms": _pct(frame_ms, 1.0),
		"step_p95_ms": _step_percentiles(step_ms, 0.95), "step_max_ms": _step_percentiles(step_ms, 1.0), "tail_step": _tail_step(frame_ms, step_ms),
		"strike_split_p95_ms": _step_percentiles(strike_split, 0.95), "strike_split_max_ms": _step_percentiles(strike_split, 1.0),
	})
	_clear_enemies()
	return row


static func _lifecycle_usec() -> int:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return 0
	var index: Node = loop.root.get_node_or_null("EnemyIndex")
	if index == null or not index.has_method("get_debug_counters"):
		return 0
	var lifecycle: Dictionary = (index.call("get_debug_counters") as Dictionary).get("lifecycle", {})
	return int(lifecycle.get("attach_total_usec", 0)) + int(lifecycle.get("detach_total_usec", 0)) + int(lifecycle.get("retire_total_usec", 0))


static func _step_percentiles(step_ms: Dictionary, fraction: float) -> Dictionary:
	var out := {}
	for step_name in step_ms:
		out[step_name] = _pct(step_ms[step_name], fraction)
	return out


## The step that dominated the slowest 1% of frames (at least three), by
## count; "" when no frame was measured.
static func _tail_step(frame_ms: Array, step_ms: Dictionary) -> String:
	if frame_ms.is_empty():
		return ""
	var order: Array = range(frame_ms.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(frame_ms[a]) > float(frame_ms[b]))
	var tail_count := maxi(3, int(ceil(0.01 * frame_ms.size())))
	var votes := {}
	for i in range(mini(tail_count, order.size())):
		var frame_index: int = order[i]
		var best := ""
		var best_ms := -1.0
		for step_name in step_ms:
			var values: Array = step_ms[step_name]
			if frame_index < values.size() and float(values[frame_index]) > best_ms:
				best_ms = float(values[frame_index])
				best = String(step_name)
		votes[best] = int(votes.get(best, 0)) + 1
	var winner := ""
	var winner_votes := 0
	for step_name in votes:
		if int(votes[step_name]) > winner_votes:
			winner_votes = int(votes[step_name])
			winner = String(step_name)
	return winner


static func _pct(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return float(sorted_values[clampi(int(ceil(fraction * sorted_values.size())) - 1, 0, sorted_values.size() - 1)])
