extends RefCounted
class_name PrimaryObjectiveCatalog

## Which primary objective a segment gets.
##
## For a long time the answer was "the District Relay", because the type was
## hardcoded in SegmentProcBuilder and its wording was hardcoded next to it.
## Adding a second was a builder rewrite, so there was never a second.
##
## Segment 2 is pinned to the relay on purpose: it is the vertical slice and the
## first procedural district a player ever sees, so it should teach the gentlest
## template - go to the marked places, stand on them - before anything asks for
## a fight or punishes hesitation. Everything after that is drawn from the seed,
## which is what makes two runs of segment 6 different runs.

const TEACHING_SEGMENT: int = 2

## Ordered so the index is stable: appending a new type must never change which
## objective an existing seed produced.
const TYPES: Array[Dictionary] = [
	{"id": &"district_relay", "script": "res://core/systems/world/objectives/DistrictRelayObjective.gd"},
	{"id": &"ward_vigil", "script": "res://core/systems/world/objectives/WardVigilObjective.gd"},
	{"id": &"breach_seal", "script": "res://core/systems/world/objectives/BreachSealObjective.gd"},
]


static func all_ids() -> Array:
	var out: Array = []
	for entry in TYPES:
		out.append(entry["id"])
	return out


static func script_for(id: StringName) -> GDScript:
	for entry in TYPES:
		if entry["id"] == id:
			return load(entry["script"]) as GDScript
	return null


## Deterministic pick. Same segment and seed always produce the same objective,
## which matters because the plan validator and the seed-reproduction tooling
## both assume a seed fully determines a district.
static func pick_id(segment: int, seed_value: int) -> StringName:
	if segment <= TEACHING_SEGMENT:
		return TYPES[0]["id"]
	if TYPES.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("primary_objective:%d:%d" % [segment, seed_value]))
	return TYPES[rng.randi_range(0, TYPES.size() - 1)]["id"]


## Instantiate the objective for a segment, already configured.
static func create_for(segment: int, seed_value: int) -> PrimaryObjective:
	var id := pick_id(segment, seed_value)
	var script := script_for(id)
	if script == null:
		return null
	var objective := script.new() as PrimaryObjective
	if objective == null:
		return null
	objective.name = String(id).to_pascal_case()
	objective.configure(seed_value)
	return objective
