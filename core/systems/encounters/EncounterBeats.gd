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
## through apply_elite_modifiers; "announce" is the popup line when it should
## say more than the label; "kind": RITUAL_KIND marks a beat whose one member
## is a world node (RitualInterference) rather than an enemy formation;
## "kind_tag" names the question the beat asks (charge, crossfire, shield,
## support, ambush, nest, hunter, area, ritual) so the director can rotate
## them; "max_segment" keeps a beat out of the random draw after a segment.

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
const CHANTER := "res://scenes/world/enemies/EnemyChanter.tscn"
const LURKER := "res://scenes/world/enemies/EnemyLurker.tscn"
const WARDEN := "res://scenes/world/enemies/EnemyWarden.tscn"
## Ritual interference (§8.1, Phase 2.7) is a script-built world node, placed
## like a formation but spawning nothing itself.
const RITUAL := "res://core/systems/world/RitualInterference.gd"
const RITUAL_KIND := &"ritual"

const PHASE_ORDER: Array[StringName] = [&"recon", &"disturbance", &"ascension", &"collapse"]

# Explicit-only Rite formation. Keeping it outside CATALOG prevents the larger
# crossfire from silently changing ordinary district encounters.
const RITE_SNIPER_CROSSFIRE: Dictionary = {
	"id": &"rite_sniper_crossfire",
	"kind_tag": &"crossfire",
	"label": "RITE CROSSFIRE",
	"callout": "Sights settle around the Rite.",
	"answer": "break line of sight",
	"mode": &"around",
	"distance": 1400.0,
	"min_phase": &"disturbance",
	"cooldown": 0.0,
	"members": [
		{"scene": SNIPER, "offset": Vector2(1400.0, 0.0), "elite": false},
		{"scene": SNIPER, "offset": Vector2(-700.0, -1212.4), "elite": false},
		{"scene": SNIPER, "offset": Vector2(-700.0, 1212.4), "elite": false},
	],
}

# Explicit-only Rite melee (plan 2026-09-17 §6.2: "at most 2 living/pending
# authored melee ... a charger counts as a full arrival by itself"). The
# six-charger wedge used to answer the channel; a pair keeps the player
# moving without turning the sniper encounter back into a horde.
const RITE_CHARGER_PAIR: Dictionary = {
	"id": &"rite_charger_pair",
	"kind_tag": &"charge",
	"label": "FLANKERS",
	"callout": "Two break from the line.",
	"answer": "step aside",
	"mode": &"flank",
	"distance": 820.0,
	"min_phase": &"disturbance",
	"cooldown": 0.0,
	"members": [
		{"scene": CHARGER, "offset": Vector2(0.0, -60.0), "elite": false},
		{"scene": CHARGER, "offset": Vector2(0.0, 60.0), "elite": false},
	],
}

# Explicit-only: the channel's last wave (94%) - one fast, vampiric hunter,
# the world's final argument for staying.
const RITE_HUNTER: Dictionary = {
	"id": &"rite_hunter",
	"kind_tag": &"hunter",
	"label": "THE LAST HUNTER",
	"announce": "SOMETHING FAST WANTS YOU TO STAY",
	"callout": "Something fast wants you to stay.",
	"answer": "finish the rite",
	"mode": &"off_route",
	"distance": 900.0,
	"min_phase": &"disturbance",
	"cooldown": 0.0,
	"modifiers": [&"fast", &"vampiric"],
	"members": [
		{"scene": RUNNER, "offset": Vector2(0.0, 0.0), "elite": true},
	],
}

# Explicit-only "rematch" (2026-10-04, vision "Power Escalation Should Be
# Visible"): when the player crosses a power threshold the EncounterDirector
# rings them with the district's oldest fodder while the Threat Director holds
# enemy scaling still, so the enemies that used to crowd them simply burst.
const REMATCH_RING: Dictionary = {
	"id": &"rematch_ring",
	"kind_tag": &"rematch",
	"label": "THE OLD PATROLS",
	"announce": "THE OLD PATROLS RETURN",
	"callout": "They come the way they came at the start.",
	"answer": "let the build answer",
	"mode": &"around",
	"distance": 560.0,
	"min_phase": &"recon",
	"cooldown": 0.0,
	"members": [
		{"scene": GRUNT, "offset": Vector2(560.0, 0.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(517.4, 214.3), "elite": false},
		{"scene": GRUNT, "offset": Vector2(396.0, 396.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(214.3, 517.4), "elite": false},
		{"scene": GRUNT, "offset": Vector2(0.0, 560.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(-214.3, 517.4), "elite": false},
		{"scene": GRUNT, "offset": Vector2(-396.0, 396.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(-517.4, 214.3), "elite": false},
		{"scene": GRUNT, "offset": Vector2(-560.0, 0.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(-517.4, -214.3), "elite": false},
		{"scene": GRUNT, "offset": Vector2(-396.0, -396.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(-214.3, -517.4), "elite": false},
		{"scene": GRUNT, "offset": Vector2(0.0, -560.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(214.3, -517.4), "elite": false},
		{"scene": GRUNT, "offset": Vector2(396.0, -396.0), "elite": false},
		{"scene": RUNNER, "offset": Vector2(517.4, -214.3), "elite": false},
	],
}

const CATALOG: Array[Dictionary] = [
	# Segment 1 pass S5: two authored punctuations sized for the tutorial's
	# service street and approach (three chargers, two snipers close in).
	{
		"id": &"charger_wedge_small",
		"kind_tag": &"charge",
		"max_segment": 1,
		"label": "CHARGER WEDGE",
		"callout": "Three chargers line up on your flank.",
		"answer": "move laterally",
		"mode": &"flank",
		"distance": 640.0,
		"min_phase": &"disturbance",
		"cooldown": 180.0,
		"members": [
			{"scene": CHARGER, "offset": Vector2(0.0, 0.0), "elite": false},
			{"scene": CHARGER, "offset": Vector2(70.0, -80.0), "elite": false},
			{"scene": CHARGER, "offset": Vector2(70.0, 80.0), "elite": false},
		],
	},
	{
		"id": &"sniper_pair",
		"kind_tag": &"crossfire",
		"max_segment": 1,
		"label": "CROSSFIRE",
		"callout": "Two sights settle on you.",
		"answer": "break line of sight",
		"mode": &"around",
		"distance": 640.0,
		"min_phase": &"disturbance",
		"cooldown": 180.0,
		"members": [
			{"scene": SNIPER, "offset": Vector2(520.0, -380.0), "elite": false},
			{"scene": SNIPER, "offset": Vector2(-520.0, 380.0), "elite": false},
		],
	},
	{
		"id": &"warden_line",
		"kind_tag": &"shield",
		"label": "WARDEN LINE",
		"callout": "Shields lock across the street.",
		"answer": "flank the shields",
		"mode": &"ahead",
		"distance": 700.0,
		"min_phase": &"ascension",
		"cooldown": 160.0,
		"members": [
			{"scene": WARDEN, "offset": Vector2(0.0, -90.0), "elite": false},
			{"scene": WARDEN, "offset": Vector2(0.0, 90.0), "elite": false},
			{"scene": SPITTER, "offset": Vector2(150.0, -140.0), "elite": false},
			{"scene": SPITTER, "offset": Vector2(150.0, 0.0), "elite": false},
			{"scene": SPITTER, "offset": Vector2(150.0, 140.0), "elite": false},
		],
	},
	{
		"id": &"chanter_choir",
		"kind_tag": &"support",
		"label": "CHOIR",
		"callout": "A chant rises behind the line.",
		"answer": "silence the chanter",
		"mode": &"ahead",
		"distance": 720.0,
		"min_phase": &"ascension",
		"cooldown": 150.0,
		"members": [
			{"scene": CHANTER, "offset": Vector2(160.0, 0.0), "elite": false},
			{"scene": GRUNT, "offset": Vector2(0.0, -120.0), "elite": false},
			{"scene": GRUNT, "offset": Vector2(0.0, -40.0), "elite": false},
			{"scene": GRUNT, "offset": Vector2(0.0, 40.0), "elite": false},
			{"scene": GRUNT, "offset": Vector2(0.0, 120.0), "elite": false},
			{"scene": BRUTE, "offset": Vector2(60.0, 0.0), "elite": false},
		],
	},
	{
		"id": &"lurker_pair",
		"kind_tag": &"ambush",
		"label": "LURKERS",
		"callout": "Something waits for you to stop.",
		"answer": "keep moving",
		"mode": &"around",
		"distance": 520.0,
		"min_phase": &"ascension",
		"cooldown": 140.0,
		"members": [
			{"scene": LURKER, "offset": Vector2(-460.0, 240.0), "elite": false},
			{"scene": LURKER, "offset": Vector2(440.0, -260.0), "elite": false},
		],
	},
	{
		"id": &"charger_wedge",
		"kind_tag": &"charge",
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
		"kind_tag": &"shield",
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
		"kind_tag": &"crossfire",
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
		"kind_tag": &"nest",
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
		"kind_tag": &"hunter",
		"label": "HUNTER",
		"callout": "Something fast has your scent.",
		"answer": "turn and fight",
		"mode": &"off_route",
		"distance": 1000.0,
		"min_phase": &"recon",
		"cooldown": 100.0,
		"modifiers": [&"fast", &"vampiric"],
		"members": [
			{"scene": RUNNER, "offset": Vector2(0.0, 0.0), "elite": true},
		],
	},
	{
		"id": &"bomber_carpet",
		"kind_tag": &"area",
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
		"kind_tag": &"ambush",
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
	{
		"id": &"ritual_interference",
		"kind_tag": &"ritual",
		"label": "RITUAL INTERFERENCE",
		"announce": "RITUAL INTERFERENCE — THE DEAD RISE HERE",
		"callout": "The dead rise here.",
		"answer": "fight outside the sigil, or kill twice",
		"mode": &"ahead",
		"distance": 700.0,
		"min_phase": &"collapse",
		"cooldown": 150.0,
		"kind": RITUAL_KIND,
		"members": [
			{"scene": RITUAL, "offset": Vector2(0.0, 0.0), "elite": false},
		],
	},
]


static func find(id: StringName) -> Dictionary:
	if id == &"rite_sniper_crossfire":
		return RITE_SNIPER_CROSSFIRE
	if id == &"rematch_ring":
		return REMATCH_RING
	if id == &"rite_charger_pair":
		return RITE_CHARGER_PAIR
	if id == &"rite_hunter":
		return RITE_HUNTER
	for beat in CATALOG:
		if beat["id"] == id:
			return beat
	return {}


## A beat whose member is a world node that bends a local rule, not enemies.
static func is_ritual(beat: Dictionary) -> bool:
	return StringName(beat.get("kind", &"")) == RITUAL_KIND


static func phase_rank(phase: StringName) -> int:
	var index := PHASE_ORDER.find(phase)
	return index if index >= 0 else 0


## Beats whose minimum phase is at or below the current one and whose
## optional "max_segment" admits `segment` (0 = ungated). The two tutorial-
## sized formations are segment-1 only: in segment 2 the human capture's two
## beats were always charger_wedge_small then warden_line.
static func eligible(phase: StringName, segment: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rank := phase_rank(phase)
	for beat in CATALOG:
		if phase_rank(beat["min_phase"]) > rank:
			continue
		var max_segment := int(beat.get("max_segment", 0))
		if segment > 0 and max_segment > 0 and segment > max_segment:
			continue
		out.append(beat)
	return out


## The beat's kind ("charge", "crossfire", "shield", ...): the director
## rotates kinds so consecutive punctuations ask different questions.
static func kind_of(beat: Dictionary) -> StringName:
	return StringName(beat.get("kind_tag", beat.get("id", &"")))
