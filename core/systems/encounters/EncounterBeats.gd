extends RefCounted
class_name EncounterBeats

## Authored encounter beats (roadmap §8.1, Phase 2.4): readable PROBLEMS
## layered on the ThreatDirector's continuous pressure. Each beat is a
## composition of existing archetypes placed in a formation relative to an
## anchor, so the player has to stop autopiloting and answer it.
##
## Member offsets are in the anchor's local frame: +x along the anchor
## direction (away from the player), +y to the player's right. "around"
## beats use offsets as absolute positions relative to the player.
##
## Numbers here are shapes to playtest, not tuning: EncounterDirector exports
## the cadence, and every beat's counts and distances are plain data.
##
## Optional keys: "modifiers" names elite modifiers (§9) every member receives
## through apply_elite_modifiers.

const GRUNT := "res://scenes/world/enemies/EnemyGrunt.tscn"
const RUNNER := "res://scenes/world/enemies/EnemyRunner.tscn"
const CHARGER := "res://scenes/world/enemies/EnemyCharger.tscn"
const BRUTE := "res://scenes/world/enemies/EnemyBrute.tscn"
const SPITTER := "res://scenes/world/enemies/EnemySpitter.tscn"
const BOMBER := "res://scenes/world/enemies/EnemyBomber.tscn"
const LEECH := "res://scenes/world/enemies/EnemyLeech.tscn"
const SNIPER := "res://scenes/world/enemies/EnemySniper.tscn"
const HERALD := "res://scenes/world/enemies/EnemyHerald.tscn"
const SUMMONER := "res://scenes/world/enemies/EnemySummoner.tscn"

const PHASE_ORDER: Array[StringName] = [&"recon", &"disturbance", &"ascension", &"collapse"]

const CATALOG: Array[Dictionary] = [
	{
		"id": &"charger_wedge",
		"label": "CHARGER WEDGE",
		"callout": "A wedge forms on your flank.",
		"answer": "move laterally",
		"mode": &"flank",
		"distance": 900.0,
		"min_phase": &"disturbance",
		"cooldown": 90.0,
		"members": [
			{"scene": CHARGER, "offset": Vector2(0.0, 0.0), "elite": true},
			{"scene": CHARGER, "offset": Vector2(60.0, -70.0), "elite": false},
			{"scene": CHARGER, "offset": Vector2(60.0, 70.0), "elite": false},
			{"scene": CHARGER, "offset": Vector2(120.0, -140.0), "elite": false},
			{"scene": CHARGER, "offset": Vector2(120.0, 140.0), "elite": false},
			{"scene": CHARGER, "offset": Vector2(180.0, 0.0), "elite": false},
		],
	},
	{
		"id": &"shield_wall",
		"label": "SHIELD WALL",
		"callout": "A wall of brutes blocks the way.",
		"answer": "flank or pierce",
		"mode": &"ahead",
		"distance": 760.0,
		"min_phase": &"disturbance",
		"cooldown": 120.0,
		"members": [
			{"scene": BRUTE, "offset": Vector2(0.0, -180.0), "elite": false},
			{"scene": BRUTE, "offset": Vector2(0.0, -60.0), "elite": false},
			{"scene": BRUTE, "offset": Vector2(0.0, 60.0), "elite": false},
			{"scene": BRUTE, "offset": Vector2(0.0, 180.0), "elite": false},
			{"scene": SPITTER, "offset": Vector2(140.0, -120.0), "elite": false},
			{"scene": SPITTER, "offset": Vector2(140.0, 0.0), "elite": false},
			{"scene": SPITTER, "offset": Vector2(140.0, 120.0), "elite": false},
		],
	},
	{
		"id": &"sniper_crossfire",
		"label": "CROSSFIRE",
		"callout": "Two sights settle on you.",
		"answer": "break line of sight",
		"mode": &"around",
		"distance": 1400.0,
		"min_phase": &"disturbance",
		"cooldown": 150.0,
		"members": [
			{"scene": SNIPER, "offset": Vector2(700.0, -1212.4), "elite": false},
			{"scene": SNIPER, "offset": Vector2(700.0, 1212.4), "elite": false},
		],
	},
	{
		"id": &"summoner_nest",
		"label": "NEST",
		"callout": "Something is breeding nearby.",
		"answer": "commit to a detour",
		"mode": &"off_route",
		"distance": 1100.0,
		"min_phase": &"disturbance",
		"cooldown": 180.0,
		"members": [
			{"scene": SUMMONER, "offset": Vector2(0.0, 0.0), "elite": false},
			{"scene": HERALD, "offset": Vector2(-80.0, -90.0), "elite": false},
			{"scene": HERALD, "offset": Vector2(-80.0, 90.0), "elite": false},
		],
	},
	{
		"id": &"hunter",
		"label": "HUNTER",
		"callout": "Something fast has your scent.",
		"answer": "turn and fight",
		"mode": &"off_route",
		"distance": 1000.0,
		"min_phase": &"disturbance",
		"cooldown": 100.0,
		"modifiers": [&"fast", &"vampiric"],
		"members": [
			{"scene": RUNNER, "offset": Vector2(0.0, 0.0), "elite": true},
		],
	},
	{
		"id": &"bomber_carpet",
		"label": "BOMBER CARPET",
		"callout": "The ground ahead starts ticking.",
		"answer": "reposition",
		"mode": &"ahead",
		"distance": 640.0,
		"min_phase": &"ascension",
		"cooldown": 120.0,
		"members": [
			{"scene": BOMBER, "offset": Vector2(0.0, -250.0), "elite": false},
			{"scene": BOMBER, "offset": Vector2(40.0, -150.0), "elite": false},
			{"scene": BOMBER, "offset": Vector2(60.0, -50.0), "elite": false},
			{"scene": BOMBER, "offset": Vector2(60.0, 50.0), "elite": false},
			{"scene": BOMBER, "offset": Vector2(40.0, 150.0), "elite": false},
			{"scene": BOMBER, "offset": Vector2(0.0, 250.0), "elite": false},
		],
	},
	{
		"id": &"leech_ring",
		"label": "LEECH RING",
		"callout": "The ring closes.",
		"answer": "burst out",
		"mode": &"around",
		"distance": 520.0,
		"min_phase": &"ascension",
		"cooldown": 140.0,
		"members": [
			{"scene": LEECH, "offset": Vector2(520.0, 0.0), "elite": false},
			{"scene": LEECH, "offset": Vector2(367.7, 367.7), "elite": false},
			{"scene": LEECH, "offset": Vector2(0.0, 520.0), "elite": false},
			{"scene": LEECH, "offset": Vector2(-367.7, 367.7), "elite": false},
			{"scene": LEECH, "offset": Vector2(-520.0, 0.0), "elite": false},
			{"scene": LEECH, "offset": Vector2(-367.7, -367.7), "elite": false},
			{"scene": LEECH, "offset": Vector2(-0.0, -520.0), "elite": false},
			{"scene": LEECH, "offset": Vector2(367.7, -367.7), "elite": false},
		],
	},
]


static func find(id: StringName) -> Dictionary:
	for beat in CATALOG:
		if beat["id"] == id:
			return beat
	return {}


static func phase_rank(phase: StringName) -> int:
	var index := PHASE_ORDER.find(phase)
	return index if index >= 0 else 0


## Beats whose minimum phase is at or below the current one.
static func eligible(phase: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rank := phase_rank(phase)
	for beat in CATALOG:
		if phase_rank(beat["min_phase"]) <= rank:
			out.append(beat)
	return out
