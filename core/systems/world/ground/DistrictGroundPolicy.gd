extends RefCounted
## Per-district ground presentation for the procedural city (2026-10-21).
##
## Every segment generates the same semantic floor stamps (roads, sidewalks,
## aprons, building floors, plazas) on a per-chunk base terrain. This policy
## decides how those semantic materials READ in each district: which source a
## role draws with (painterly setts, limestone flags, or one of the splat
## array layers), how strongly the texture shows through a quiet mid tone,
## kerbs, ground occlusion and lawn/soil grading. It never changes material
## ownership, slots, walkability or any generator RNG.
##
## Deliberately not a global class (see WorldArt.gd): consumers preload it.
##
## Concept direction (docs/art/concepts/2026-10-19-segment-directions and the
## governing 08 plate): bright temperate daylight, cool-neutral limestone and
## grey setts, crisp kerbs where carriageway meets footway, combat ground kept
## quiet (low texture weight, broad value structure instead of outlines), no
## beige desert drift, wild ground only outside the built district.

## Presentation roles. A slot's ground index maps to one of these.
const ROLE_RAW := 0
## Kerbed carriageway and its squares: main streets and plazas (7), secondary
## routes / alleys / courts (8), the primary objective (9), and the stone
## courts, plaza lips, hub pads and checkpoint lanes (3) that sit inside them.
const ROLE_ROAD := 1
## Flush setts: service lanes, door aprons, access corridors, passages (4).
const ROLE_LANE := 2
## Flags: sidewalks and house floors (2).
const ROLE_FOOTWAY := 3
## The built district's continuous hard surface (semantic terrain "urban", 6).
const ROLE_YARD := 4
## Overgrowth: grass, meadow, scrub, moss (0, 10, 11, 12).
const ROLE_LAWN := 5
## Bare ground: dirt and wet earth (1, 5).
const ROLE_SOIL := 6
const ROLE_COUNT := 7

## Texture sources a role can draw with.
const SOURCE_OWN := 0
const SOURCE_SETTS := 1
const SOURCE_FLAGS := 2
const SOURCE_LAYER := 3

## The semantic ground index of the district surface ("urban" terrain).
const DISTRICT_GROUND_INDEX := 6
const DISTRICT_TERRAIN := &"urban"

const INDEX_ROLES := {
	0: ROLE_LAWN, 1: ROLE_SOIL, 2: ROLE_FOOTWAY, 3: ROLE_ROAD, 4: ROLE_LANE,
	5: ROLE_SOIL, 6: ROLE_YARD, 7: ROLE_ROAD, 8: ROLE_ROAD, 9: ROLE_ROAD,
	10: ROLE_LAWN, 11: ROLE_LAWN, 12: ROLE_LAWN,
}

const FAMILIES: Array[StringName] = [
	&"service_courtyards", &"checkpoint_lanes", &"collapsed_ward",
	&"civilian_cutthrough", &"inner_district_gate", &"industrial_cutthrough",
	&"ruined_services", &"underpass_veins", &"canal_services", &"rail_yard",
	&"military_staging", &"outer_wall", &"siege_services", &"gate_district",
]

## Array layers used as alternative sources (WorldArt._GROUND_TEX_PATHS).
const LAYER_DIRT := 1
const LAYER_COBBLE := 2
const LAYER_STONE_TILES := 3
const LAYER_DARK_FLAGS := 4
const LAYER_WET_EARTH := 5
const LAYER_WEEDY_FLAGS := 7
const LAYER_MOSSY_FLAGS := 8
const LAYER_ROUND_COBBLE := 9
const LAYER_SCRUB := 11
const LAYER_DAMP_MOSS := 12


static func role_for_index(index: int) -> int:
	return int(INDEX_ROLES.get(index, ROLE_RAW))


static func is_paved_role(role: int) -> bool:
	return role == ROLE_ROAD or role == ROLE_LANE or role == ROLE_FOOTWAY or role == ROLE_YARD


## The ground presentation of a district family. An empty family (Segment 1,
## the Hub, tests without a theme) keeps the original raw palette; an unknown
## procedural family falls back to Service Courtyards like the atmosphere
## profiles do. Always a fresh deep copy.
static func resolve(family: StringName) -> Dictionary:
	if family == &"":
		return _legacy()
	var policy := _service_courtyards()
	match family:
		&"checkpoint_lanes": policy = _checkpoint_lanes()
		&"collapsed_ward": policy = _collapsed_ward()
		&"civilian_cutthrough": policy = _civilian_cutthrough()
		&"inner_district_gate": policy = _inner_district_gate()
		&"industrial_cutthrough": policy = _industrial_cutthrough()
		&"ruined_services": policy = _ruined_services()
		&"underpass_veins": policy = _underpass_veins()
		&"canal_services": policy = _canal_services()
		&"rail_yard": policy = _rail_yard()
		&"military_staging": policy = _military_staging()
		&"outer_wall": policy = _outer_wall()
		&"siege_services": policy = _siege_services()
		&"gate_district": policy = _gate_district()
	policy["family"] = family
	return policy.duplicate(true)


## A compact, order-stable fingerprint of what the policy draws (tests and
## evidence compare themes with it).
static func signature(policy: Dictionary) -> String:
	var parts: Array[String] = [str(policy.get("id", &"")), str(policy.get("enabled", false))]
	var roles: Dictionary = policy.get("roles", {})
	for role in range(ROLE_COUNT):
		var entry: Dictionary = roles.get(role, {})
		parts.append("%d:%s:%s:%s:%s:%s" % [role, str(entry.get("source", SOURCE_OWN)), str(entry.get("layer", -1)), str(entry.get("repeat_px", 0.0)), str(entry.get("mid", Color.BLACK)), str(entry.get("tint", Color.WHITE))])
	for key: String in ["kerb", "gutter", "joint", "ao", "lawn_mottle", "paving_variation", "verge_layer", "verge_strength", "wet_patches", "yard_patch"]:
		parts.append("%s=%s" % [key, str(policy.get(key, 0.0))])
	return ";".join(parts).sha256_text()


static func _role(source: int, repeat_px: float, mid: Color, weight: float, tint: Color = Color.WHITE, layer: int = -1) -> Dictionary:
	return {"source": source, "layer": layer, "repeat_px": repeat_px, "mid": Color(mid.r, mid.g, mid.b, weight), "tint": tint}


static func _legacy() -> Dictionary:
	return {"id": &"legacy", "family": &"", "enabled": false, "district_terrain": &"", "roles": {}}


## Service Courtyards (S2, and the S11+ fallback): pale limestone flags with
## grey sett carriageways and slate-grey bands, the governing 08 look.
static func _service_courtyards() -> Dictionary:
	return {
		"id": &"service_courtyards",
		"enabled": true,
		"district_terrain": DISTRICT_TERRAIN,
		"roles": {
			ROLE_ROAD: _role(SOURCE_SETTS, 272.0, Color(0.455, 0.47, 0.48), 0.42, Color(0.91, 0.95, 0.98)),
			ROLE_LANE: _role(SOURCE_SETTS, 256.0, Color(0.48, 0.49, 0.49), 0.40, Color(0.93, 0.95, 0.97)),
			ROLE_FOOTWAY: _role(SOURCE_FLAGS, 384.0, Color(0.61, 0.615, 0.585), 0.46, Color(1.0, 1.0, 0.98)),
			ROLE_YARD: _role(SOURCE_FLAGS, 448.0, Color(0.585, 0.59, 0.56), 0.46, Color(0.99, 0.99, 0.96)),
			ROLE_LAWN: _role(SOURCE_OWN, 320.0, Color(0.31, 0.37, 0.27), 0.50, Color(1.10, 1.14, 1.04)),
			ROLE_SOIL: _role(SOURCE_OWN, 384.0, Color(0.40, 0.38, 0.33), 0.45, Color(1.0, 1.0, 1.0)),
		},
		"kerb": 0.80,
		"gutter": 0.60,
		"joint": 0.40,
		"ao": 0.24,
		"lip_shadow": 0.22,
		"seam_shadow": 0.0,
		"lawn_mottle": 0.14,
		"paving_variation": 0.08,
		"paved_stain_strength": 0.45,
		"wet_patches": 0.0,
		"yard_patch": {},
		"verge_layer": -1,
		"verge_strength": 0.0,
		"kerb_lod": 0.5,
		"kerb_warp_cells": 0.10,
	}


static func _patch(layer: int, coverage: float, repeat_px: float, weight: float, tint: Color) -> Dictionary:
	return {"layer": layer, "coverage": coverage, "repeat_px": repeat_px, "weight": weight, "tint": tint}


## Checkpoint Lanes (S3): crooked grey cobbled lanes with kerbs opening into a
## cobbled inspection court; cool overcast stone, not blue.
static func _checkpoint_lanes() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"checkpoint_lanes"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 336.0, Color(0.415, 0.435, 0.45), 0.48, Color(0.90, 0.94, 0.97))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 320.0, Color(0.455, 0.47, 0.48), 0.44, Color(0.92, 0.95, 0.97))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.575, 0.585, 0.585), 0.44, Color(0.97, 0.99, 1.0))
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 288.0, Color(0.49, 0.505, 0.51), 0.44, Color(0.92, 0.95, 0.98))
	p.kerb = 0.95
	p.gutter = 0.70
	p.ao = 0.27
	return p


## Collapsed Ward (S4A): a worn cobbled street through old flags gone to
## weeds, with rubble-dusted patches and scrub where the paving gives out.
static func _collapsed_ward() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"collapsed_ward"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 304.0, Color(0.40, 0.405, 0.40), 0.52, Color(0.90, 0.92, 0.93))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 288.0, Color(0.45, 0.455, 0.45), 0.48, Color(0.93, 0.95, 0.96))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.57, 0.57, 0.545), 0.50, Color(0.98, 0.98, 0.96))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 384.0, Color(0.545, 0.54, 0.515), 0.40, Color(1.13, 1.13, 1.30), LAYER_WEEDY_FLAGS)
	p.roles[ROLE_LAWN] = _role(SOURCE_OWN, 320.0, Color(0.33, 0.37, 0.26), 0.55, Color(1.06, 1.10, 1.0))
	p.yard_patch = _patch(LAYER_COBBLE, 0.32, 256.0, 0.55, Color(1.55, 1.53, 1.58))
	p.kerb = 0.55
	p.gutter = 0.45
	p.paving_variation = 0.11
	p.verge_layer = LAYER_SCRUB
	p.verge_strength = 0.65
	return p


## Civilian Cut-through (S4B): homely pale sett courts and limestone footways
## between terraces, finer and a touch warmer than the service courts.
static func _civilian_cutthrough() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"civilian_cutthrough"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 240.0, Color(0.445, 0.45, 0.45), 0.44, Color(0.93, 0.95, 0.96))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 320.0, Color(0.625, 0.62, 0.585), 0.46, Color(1.0, 0.99, 0.97))
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 176.0, Color(0.60, 0.595, 0.565), 0.40, Color(1.02, 1.01, 0.98))
	p.roles[ROLE_LAWN] = _role(SOURCE_OWN, 320.0, Color(0.30, 0.38, 0.26), 0.50, Color(1.08, 1.16, 1.02))
	p.kerb = 0.70
	return p


## Inner District Gate (S5): a broad, empty court of pale ashlar flags; the
## streets and the miniboss court are large kerbed flags, lanes stay setts.
static func _inner_district_gate() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"inner_district_gate"
	p.roles[ROLE_ROAD] = _role(SOURCE_FLAGS, 512.0, Color(0.55, 0.565, 0.565), 0.46, Color(0.95, 0.98, 1.0))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 272.0, Color(0.44, 0.46, 0.48), 0.42, Color(0.90, 0.94, 0.98))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 448.0, Color(0.62, 0.63, 0.62), 0.44, Color(0.99, 1.0, 1.0))
	p.roles[ROLE_YARD] = _role(SOURCE_FLAGS, 576.0, Color(0.635, 0.64, 0.625), 0.42, Color(0.99, 1.0, 0.99))
	p.kerb = 0.85
	p.gutter = 0.65
	return p


## Industrial Cut-through (S6A): dirt-and-sett service yards between dark
## basalt carriageways; sootier occlusion.
static func _industrial_cutthrough() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"industrial_cutthrough"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.38, 0.39, 0.40), 0.50, Color(0.86, 0.88, 0.90))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 272.0, Color(0.42, 0.42, 0.42), 0.46, Color(0.88, 0.90, 0.91))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.545, 0.545, 0.525), 0.46, Color(0.96, 0.96, 0.94))
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 240.0, Color(0.46, 0.46, 0.45), 0.46, Color(0.90, 0.91, 0.91))
	p.roles[ROLE_SOIL] = _role(SOURCE_OWN, 384.0, Color(0.42, 0.405, 0.375), 0.45, Color(1.08, 1.07, 1.04))
	p.yard_patch = _patch(LAYER_DIRT, 0.55, 384.0, 0.42, Color(1.30, 1.28, 1.22))
	p.kerb = 0.65
	p.gutter = 0.70
	p.ao = 0.30
	return p


## Ruined Service District (S6B): the same yards gone to wet, puddled earth
## with broken sett remnants and damp moss at the edges.
static func _ruined_services() -> Dictionary:
	var p := _industrial_cutthrough()
	p.id = &"ruined_services"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 304.0, Color(0.40, 0.41, 0.41), 0.52, Color(0.88, 0.90, 0.91))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 384.0, Color(0.415, 0.42, 0.405), 0.46, Color(1.12, 1.22, 1.26), LAYER_WET_EARTH)
	p.yard_patch = _patch(LAYER_COBBLE, 0.40, 320.0, 0.42, Color(1.30, 1.32, 1.36))
	p.kerb = 0.45
	p.gutter = 0.55
	p.paving_variation = 0.10
	p.wet_patches = 0.55
	p.verge_layer = LAYER_DAMP_MOSS
	p.verge_strength = 0.55
	return p


## Underpass Veins (S7A): cool grey cobble lanes bending between piers into
## small yards of dark, damp flags.
static func _underpass_veins() -> Dictionary:
	var p := _checkpoint_lanes()
	p.id = &"underpass_veins"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 320.0, Color(0.39, 0.415, 0.435), 0.46, Color(0.88, 0.93, 0.97))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 352.0, Color(0.43, 0.455, 0.465), 0.46, Color(1.42, 1.46, 1.54), LAYER_DARK_FLAGS)
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 352.0, Color(0.53, 0.55, 0.56), 0.44, Color(0.96, 0.98, 1.0))
	p.kerb = 0.80
	p.ao = 0.32
	return p


## Canal Service Routes (S7B): broad quay stone with moss in the joints and
## damp moss where it meets earth.
static func _canal_services() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"canal_services"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.41, 0.435, 0.445), 0.44, Color(0.89, 0.93, 0.96))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 416.0, Color(0.56, 0.575, 0.57), 0.46, Color(0.97, 0.99, 0.99))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 448.0, Color(0.53, 0.55, 0.54), 0.42, Color(1.24, 1.20, 1.42), LAYER_MOSSY_FLAGS)
	p.roles[ROLE_SOIL] = _role(SOURCE_OWN, 384.0, Color(0.36, 0.35, 0.31), 0.50, Color(1.04, 1.04, 1.02))
	p.ao = 0.28
	p.verge_layer = LAYER_DAMP_MOSS
	p.verge_strength = 0.75
	return p


## Rail Yard Expanse (S8A): fine grey ballast gravel around sett crossings.
static func _rail_yard() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"rail_yard"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.42, 0.43, 0.43), 0.44, Color(0.90, 0.92, 0.94))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.56, 0.56, 0.54), 0.46, Color(0.98, 0.98, 0.96))
	# The sett source at a small repeat reads as coarse gravel at gameplay zoom.
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 104.0, Color(0.495, 0.49, 0.47), 0.42, Color(0.93, 0.93, 0.92))
	p.yard_patch = _patch(LAYER_DIRT, 0.18, 384.0, 0.35, Color(1.45, 1.42, 1.36))
	p.kerb = 0.70
	p.paving_variation = 0.08
	return p


## Military Staging Ground (S8B): a packed-earth muster court ringed by setts.
static func _military_staging() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"military_staging"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.41, 0.43, 0.44), 0.44, Color(0.89, 0.93, 0.95))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.56, 0.565, 0.55), 0.46, Color(0.98, 0.99, 0.97))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 384.0, Color(0.525, 0.515, 0.49), 0.42, Color(1.30, 1.28, 1.22), LAYER_DIRT)
	p.kerb = 0.75
	p.paving_variation = 0.05
	return p


## Outer Wall Approaches (S9A): a broad approach of round cobbles with grass in
## the joints, scrub verges where it meets the outskirts.
static func _outer_wall() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"outer_wall"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 352.0, Color(0.43, 0.44, 0.45), 0.46, Color(0.90, 0.93, 0.95))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.58, 0.58, 0.56), 0.46, Color(0.99, 0.99, 0.97))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 320.0, Color(0.50, 0.515, 0.48), 0.55, Color(1.18, 1.12, 1.34), LAYER_ROUND_COBBLE)
	p.kerb = 0.70
	p.verge_layer = LAYER_SCRUB
	p.verge_strength = 0.70
	return p


## Siege Service District (S9B): a rough stone yard of large irregular blocks.
static func _siege_services() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"siege_services"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.42, 0.42, 0.42), 0.46, Color(0.90, 0.92, 0.93))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.57, 0.565, 0.545), 0.46, Color(0.98, 0.97, 0.95))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 448.0, Color(0.535, 0.53, 0.515), 0.48, Color(1.60, 1.58, 1.62), LAYER_COBBLE)
	p.kerb = 0.65
	p.paving_variation = 0.08
	return p


## Gate District (S10): a ceremonial civic square of regular pale tiles around
## large kerbed flag streets; carriage lanes in setts.
static func _gate_district() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"gate_district"
	p.roles[ROLE_ROAD] = _role(SOURCE_FLAGS, 544.0, Color(0.565, 0.58, 0.585), 0.46, Color(0.96, 0.99, 1.0))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 272.0, Color(0.42, 0.45, 0.48), 0.44, Color(0.89, 0.94, 0.98))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 448.0, Color(0.63, 0.64, 0.63), 0.44, Color(0.99, 1.0, 1.0))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 512.0, Color(0.625, 0.63, 0.62), 0.45, Color(1.62, 1.62, 1.66), LAYER_STONE_TILES)
	p.kerb = 0.90
	p.gutter = 0.65
	return p
