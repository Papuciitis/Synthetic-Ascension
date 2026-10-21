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
## quiet (broad value structure instead of outlines), no beige desert drift,
## wild ground only outside the built district.
##
## Role values are calibrated against in-game captures (2026-10-21): each
## mid is the pre-light mean a role should land on, its tint carries the
## source texture onto that mean, and the weight lets the stones themselves
## read at gameplay zoom (lit luminance spread about 0.055-0.075, where the
## first pass measured 0.035-0.055 and read as a smooth mat). Footways sit a
## step above the carriageway and lanes level with it, so door aprons do not
## read as darker squares.
##
## Hierarchy pass (2026-10-21 lead review, S2 / S6A / S7): the carriageway is
## the quiet field combat runs over (a lower texture weight on the same mean,
## so the actors keep the strongest contrast); household approaches and
## service lanes sit between it and the yard instead of matching the road;
## working yards wear into packed use-areas in their open middle
## (yard_patch.open_bias > 0) and neglected damp ones green at their wall feet
## (< 0) instead of carrying free camouflage blotches; S7 gets its damp green
## setting back with smaller, darker, mossier stone.

## Presentation roles. A slot's ground index maps to one of these.
const ROLE_RAW := 0
## Kerbed carriageway and its squares: main streets and plazas, checkpoint
## lanes, gate and arena courts, hub pads (7), secondary routes / alleys /
## courts (8), the primary objective (9).
const ROLE_ROAD := 1
## Flush setts: service lanes, door aprons, access corridors, passages (4).
const ROLE_LANE := 2
## Flags: sidewalks and house floors (2), and the dressed stone floor (3) of
## shops, civic and passage parcels, structures, facility and DonJon rooms.
## Index 3 used to present as kerbed carriageway, so every such floor drew a
## dark sett sliver and a kerb at its building's base and kerbs between
## DonJon rooms and halls; the district's carriageway stamps that used it now
## stamp the main-street index (ChunkGenDistrict, ChunkGenStamp), which draws
## the same, so the split needs no further splat slot.
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
	0: ROLE_LAWN, 1: ROLE_SOIL, 2: ROLE_FOOTWAY, 3: ROLE_FOOTWAY, 4: ROLE_LANE,
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
			ROLE_ROAD: _role(SOURCE_SETTS, 272.0, Color(0.503, 0.50, 0.501), 0.60, Color(0.88, 0.90, 0.94)),
			ROLE_LANE: _role(SOURCE_SETTS, 224.0, Color(0.547, 0.545, 0.545), 0.54, Color(0.96, 0.98, 1.02)),
			ROLE_FOOTWAY: _role(SOURCE_FLAGS, 384.0, Color(0.623, 0.622, 0.615), 0.66, Color(1.12, 1.12, 1.12)),
			ROLE_YARD: _role(SOURCE_FLAGS, 448.0, Color(0.592, 0.591, 0.594), 0.72, Color(1.06, 1.06, 1.08)),
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


## A patch placed by use rather than by free noise (ground_splat's
## yard_patch_place): open_bias > 0 wears it into the open middle of a yard,
## < 0 settles it at the wall feet and enclosed corners; threshold is the
## level the placement field must stay under (higher = more ground taken;
## the shader's coverage term is 0.5 - coverage / 4, so coverage is derived
## from it); noise is how much the broad noise field still moves it (1 = free
## field); rim darkens a worn edge, edge is the half-width of the
## transition, ragged its fine breakup, mid the patch's own quiet tone.
static func _placed_patch(layer: int, threshold: float, repeat_px: float, weight: float, tint: Color, mid: Color, open_bias: float, noise: float, rim: float, edge: float, ragged: float) -> Dictionary:
	var patch := _patch(layer, (0.5 - threshold) * 4.0, repeat_px, weight, tint)
	patch.merge({"mid": mid, "open_bias": open_bias, "noise": noise, "rim": rim, "edge": edge, "ragged": ragged})
	return patch


## Checkpoint Lanes (S3): crooked grey cobbled lanes with kerbs opening into a
## cobbled inspection court; cool overcast stone, not blue.
static func _checkpoint_lanes() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"checkpoint_lanes"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 336.0, Color(0.537, 0.529, 0.52), 0.73, Color(0.94, 0.96, 0.98))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 320.0, Color(0.519, 0.512, 0.504), 0.67, Color(0.91, 0.92, 0.95))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.662, 0.655, 0.637), 0.68, Color(1.19, 1.18, 1.16))
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 288.0, Color(0.611, 0.603, 0.615), 0.67, Color(1.07, 1.09, 1.16))
	p.kerb = 0.95
	p.gutter = 0.70
	p.ao = 0.27
	return p


## Collapsed Ward (S4A): a worn cobbled street through old flags gone to
## weeds, with rubble-dusted patches and scrub where the paving gives out.
static func _collapsed_ward() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"collapsed_ward"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 304.0, Color(0.503, 0.501, 0.502), 0.75, Color(0.88, 0.91, 0.95))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 288.0, Color(0.537, 0.538, 0.538), 0.66, Color(0.94, 0.97, 1.01))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.631, 0.631, 0.628), 0.69, Color(1.13, 1.14, 1.14))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 384.0, Color(0.598, 0.592, 0.563), 0.77, Color(1.29, 1.29, 1.50), LAYER_WEEDY_FLAGS)
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
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 240.0, Color(0.528, 0.525, 0.525), 0.68, Color(0.92, 0.95, 0.99))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 256.0, Color(0.522, 0.52, 0.52), 0.63, Color(0.91, 0.94, 0.98))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 320.0, Color(0.658, 0.655, 0.651), 0.64, Color(1.18, 1.18, 1.19))
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 176.0, Color(0.656, 0.653, 0.667), 0.60, Color(1.15, 1.18, 1.26))
	p.roles[ROLE_LAWN] = _role(SOURCE_OWN, 320.0, Color(0.30, 0.38, 0.26), 0.50, Color(1.08, 1.16, 1.02))
	p.kerb = 0.70
	return p


## Inner District Gate (S5): a broad, empty court of pale ashlar flags; the
## streets and the miniboss court are large kerbed flags, lanes stay setts.
static func _inner_district_gate() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"inner_district_gate"
	p.roles[ROLE_ROAD] = _role(SOURCE_FLAGS, 512.0, Color(0.611, 0.604, 0.584), 0.66, Color(1.09, 1.09, 1.06))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 272.0, Color(0.528, 0.524, 0.517), 0.66, Color(0.92, 0.95, 0.97))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 448.0, Color(0.66, 0.656, 0.632), 0.66, Color(1.18, 1.18, 1.15))
	p.roles[ROLE_YARD] = _role(SOURCE_FLAGS, 576.0, Color(0.658, 0.654, 0.655), 0.68, Color(1.18, 1.18, 1.19))
	p.kerb = 0.85
	p.gutter = 0.65
	return p


## Industrial Cut-through (S6A): dirt-and-sett service yards between dark
## basalt carriageways; sootier occlusion.
static func _industrial_cutthrough() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"industrial_cutthrough"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.441, 0.442, 0.443), 0.68, Color(0.77, 0.80, 0.84))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 240.0, Color(0.478, 0.477, 0.474), 0.60, Color(0.84, 0.86, 0.89))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.612, 0.611, 0.605), 0.75, Color(1.10, 1.10, 1.10))
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 240.0, Color(0.57, 0.564, 0.546), 0.62, Color(1.00, 1.02, 1.03))
	p.roles[ROLE_SOIL] = _role(SOURCE_OWN, 384.0, Color(0.42, 0.405, 0.375), 0.45, Color(1.08, 1.07, 1.04))
	# Packed earth worn into the open middle of the working yards; setts stay
	# along the walls and a worn rut edges each use-area.
	p.yard_patch = _placed_patch(LAYER_DIRT, 0.40, 352.0, 0.60, Color(1.80, 1.95, 2.25), Color(0.53, 0.515, 0.485), 1.0, 0.45, 0.12, 0.010, 0.14)
	p.kerb = 0.65
	p.gutter = 0.70
	p.ao = 0.30
	return p


## Ruined Service District (S6B): the same yards gone to wet, puddled earth
## with broken sett remnants and damp moss at the edges.
static func _ruined_services() -> Dictionary:
	var p := _industrial_cutthrough()
	p.id = &"ruined_services"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 304.0, Color(0.475, 0.477, 0.468), 0.81, Color(0.83, 0.86, 0.88))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 272.0, Color(0.473, 0.47, 0.463), 0.74, Color(0.83, 0.85, 0.87))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.58, 0.579, 0.559), 0.75, Color(1.04, 1.04, 1.02))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 384.0, Color(0.485, 0.471, 0.442), 0.57, Color(1.66, 2.04, 2.48), LAYER_WET_EARTH)
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
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 272.0, Color(0.525, 0.506, 0.493), 0.62, Color(0.92, 0.91, 0.93))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 256.0, Color(0.537, 0.522, 0.51), 0.56, Color(0.93, 0.93, 0.95))
	# Small yards of damp dark flags, smaller and quieter than the first pass
	# (their big pale joints competed with the actor), greening at the walls.
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 240.0, Color(0.50, 0.52, 0.505), 0.48, Color(1.64, 1.72, 1.84), LAYER_DARK_FLAGS)
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 352.0, Color(0.637, 0.617, 0.594), 0.66, Color(1.14, 1.11, 1.08))
	p.yard_patch = _placed_patch(LAYER_DAMP_MOSS, 0.45, 320.0, 0.55, Color(1.38, 1.62, 2.27), Color(0.43, 0.47, 0.37), -0.9, 0.8, 0.0, 0.03, 0.26)
	p.kerb = 0.80
	p.ao = 0.32
	p.verge_layer = LAYER_DAMP_MOSS
	p.verge_strength = 0.65
	return p


## Canal Service Routes (S7B): broad quay stone with moss in the joints and
## damp moss where it meets earth.
static func _canal_services() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"canal_services"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 256.0, Color(0.525, 0.512, 0.507), 0.60, Color(0.92, 0.92, 0.95))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 240.0, Color(0.545, 0.535, 0.525), 0.55, Color(0.95, 0.95, 0.98))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 352.0, Color(0.64, 0.625, 0.61), 0.62, Color(1.15, 1.13, 1.12))
	# Quay yards: smaller, darker mossy flags (the first pass's big pale tiles
	# competed with the actor and lost the damp green setting), damp moss
	# settled along the wall feet and in enclosed corners.
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 224.0, Color(0.50, 0.535, 0.485), 0.40, Color(1.32, 1.31, 1.55), LAYER_MOSSY_FLAGS)
	p.roles[ROLE_SOIL] = _role(SOURCE_OWN, 384.0, Color(0.355, 0.36, 0.31), 0.50, Color(1.04, 1.08, 1.02))
	p.yard_patch = _placed_patch(LAYER_DAMP_MOSS, 0.49, 320.0, 0.55, Color(1.38, 1.62, 2.27), Color(0.43, 0.47, 0.37), -0.9, 0.8, 0.0, 0.03, 0.26)
	p.ao = 0.28
	p.verge_layer = LAYER_DAMP_MOSS
	p.verge_strength = 0.85
	return p


## Rail Yard Expanse (S8A): fine grey ballast gravel around sett crossings.
static func _rail_yard() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"rail_yard"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.479, 0.479, 0.483), 0.74, Color(0.84, 0.87, 0.91))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 256.0, Color(0.463, 0.463, 0.465), 0.69, Color(0.81, 0.84, 0.88))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.575, 0.575, 0.572), 0.70, Color(1.03, 1.04, 1.04))
	# The sett source at a small repeat reads as coarse gravel at gameplay zoom.
	p.roles[ROLE_YARD] = _role(SOURCE_SETTS, 104.0, Color(0.622, 0.635, 0.655), 0.71, Color(1.09, 1.15, 1.23))
	p.yard_patch = _placed_patch(LAYER_DIRT, 0.36, 384.0, 0.36, Color(1.80, 1.95, 2.25), Color(0.55, 0.545, 0.53), 0.8, 0.5, 0.10, 0.012, 0.12)
	p.kerb = 0.70
	p.paving_variation = 0.08
	return p


## Military Staging Ground (S8B): a packed-earth muster court ringed by setts.
static func _military_staging() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"military_staging"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.502, 0.489, 0.485), 0.73, Color(0.88, 0.88, 0.91))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 256.0, Color(0.494, 0.482, 0.478), 0.67, Color(0.86, 0.87, 0.90))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.596, 0.581, 0.571), 0.68, Color(1.07, 1.05, 1.04))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 384.0, Color(0.62, 0.595, 0.56), 0.88, Color(2.22, 2.40, 2.77), LAYER_DIRT)
	p.kerb = 0.75
	p.paving_variation = 0.05
	return p


## Outer Wall Approaches (S9A): a broad approach of round cobbles with grass in
## the joints, scrub verges where it meets the outskirts.
static func _outer_wall() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"outer_wall"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 352.0, Color(0.511, 0.505, 0.503), 0.71, Color(0.89, 0.91, 0.95))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 256.0, Color(0.498, 0.492, 0.49), 0.66, Color(0.87, 0.89, 0.92))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.616, 0.611, 0.601), 0.67, Color(1.10, 1.10, 1.10))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 320.0, Color(0.573, 0.586, 0.543), 0.57, Color(1.46, 1.39, 1.67), LAYER_ROUND_COBBLE)
	p.kerb = 0.70
	p.verge_layer = LAYER_SCRUB
	p.verge_strength = 0.70
	return p


## Siege Service District (S9B): a rough stone yard of large irregular blocks.
static func _siege_services() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"siege_services"
	p.roles[ROLE_ROAD] = _role(SOURCE_SETTS, 288.0, Color(0.513, 0.517, 0.52), 0.73, Color(0.90, 0.93, 0.98))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 256.0, Color(0.488, 0.493, 0.494), 0.67, Color(0.85, 0.89, 0.93))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 384.0, Color(0.646, 0.658, 0.655), 0.68, Color(1.16, 1.18, 1.19))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 448.0, Color(0.633, 0.628, 0.606), 0.88, Color(1.94, 1.91, 1.98), LAYER_COBBLE)
	p.kerb = 0.65
	p.paving_variation = 0.08
	return p


## Gate District (S10): a ceremonial civic square of regular pale tiles around
## large kerbed flag streets; carriage lanes in setts.
static func _gate_district() -> Dictionary:
	var p := _service_courtyards()
	p.id = &"gate_district"
	p.roles[ROLE_ROAD] = _role(SOURCE_FLAGS, 544.0, Color(0.61, 0.603, 0.584), 0.64, Color(1.09, 1.09, 1.06))
	p.roles[ROLE_LANE] = _role(SOURCE_SETTS, 272.0, Color(0.531, 0.529, 0.524), 0.66, Color(0.93, 0.96, 0.99))
	p.roles[ROLE_FOOTWAY] = _role(SOURCE_FLAGS, 448.0, Color(0.661, 0.656, 0.631), 0.63, Color(1.18, 1.18, 1.15))
	p.roles[ROLE_YARD] = _role(SOURCE_LAYER, 512.0, Color(0.656, 0.656, 0.648), 0.88, Color(1.80, 1.82, 1.85), LAYER_STONE_TILES)
	p.kerb = 0.90
	p.gutter = 0.65
	return p
