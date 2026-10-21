extends RefCounted
## Low plaza edges (2026-10-21 plaza pass). The perimeter ring of a plaza,
## arena or gate chunk keeps its physical WALL cells (kind, connection mask,
## 24 px collision band) but draws as knee-high dressed limestone instead of
## the 92 px wall kit: a planter box with clipped box shrubs and lavender on
## ordinary squares, a plain parapet with corner piers where combat must stay
## readable (gates and arena courts). Pieces are baked one per connection mask
## by tools/design/build_plaza_kit.py on the wall kit's canvas (the cell plus
## 28 px above it), so ChunkBlockRenderer batches them through its kit path.
##
## Maintenance states (plaza pass 2, after the lead's phase-1 review): the
## ordinary ring follows its district's use and upkeep instead of one tidy
## planter family; a worn kerb in working yards, the stump of a tumbled wall
## in ruined districts, a neglected mossy planter in damp S7, the bare
## parapet on military ground (tools/design/build_plaza_wear_kit.py,
## processed existing kits).

const N := WorldBlockerGeometry.N
const E := WorldBlockerGeometry.E
const S := WorldBlockerGeometry.S
const W := WorldBlockerGeometry.W

## Blocker variant bits on WALL cells only (HALF_COVER uses bits 0..4 for
## its texture and rotation). PLAZA_EDGE marks a cell built by the plaza
## ring; BALUSTRADE selects the parapet style for it.
const VARIANT_PLAZA_EDGE := 16
const VARIANT_BALUSTRADE := 64

const PLANTER: Array[Texture2D] = [
	preload("res://assets/world/plazas_v1/kit/planter34_00.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_01.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_02.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_03.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_04.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_05.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_06.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_07.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_08.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_09.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_10.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_11.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_12.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_13.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_14.png"),
	preload("res://assets/world/plazas_v1/kit/planter34_15.png"),
]
## Straight runs alternate two plantings by cell parity (box / lavender order).
const PLANTER_H_B := preload("res://assets/world/plazas_v1/kit/planter34_h_b.png")
const PLANTER_V_B := preload("res://assets/world/plazas_v1/kit/planter34_v_b.png")
const PLANTER_FILL := preload("res://assets/world/plazas_v1/kit/planter34_fill.png")
const BALUSTRADE: Array[Texture2D] = [
	preload("res://assets/world/plazas_v1/kit/balustrade34_00.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_01.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_02.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_03.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_04.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_05.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_06.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_07.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_08.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_09.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_10.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_11.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_12.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_13.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_14.png"),
	preload("res://assets/world/plazas_v1/kit/balustrade34_15.png"),
]
const BALUSTRADE_PIER_H := preload("res://assets/world/plazas_v1/kit/balustrade34_pier_h.png")
const BALUSTRADE_PIER_V := preload("res://assets/world/plazas_v1/kit/balustrade34_pier_v.png")
const BALUSTRADE_FILL := preload("res://assets/world/plazas_v1/kit/balustrade34_fill.png")

## Maintenance states (ChunkBuildData.plaza_edge_state), set per plaza chunk
## by PlazaPresentation from the district family: tended civic and market
## squares, working yards (industrial, rail), ruined districts, damp S7
## districts and military ground.
const STATE_TENDED := 0
const STATE_WORKING := 1
const STATE_RUINED := 2
const STATE_DAMP := 3
const STATE_MILITARY := 4

## Maintenance state of each district family's squares (lead review of
## phase 1, "Theme identity"): tended civic and market squares keep their
## planters; working yards get worn kerbs, stacked goods and bare packed
## ground; ruined districts tumbled wall stumps, rubble, weeds and neglected
## beds; damp S7 mossy rims and wet beds; military ground bare stone and
## supplies. Unlisted families (S1, the hub, S11+ fallbacks) stay tended.
const STATE_BY_FAMILY := {
	&"service_courtyards": STATE_TENDED, &"checkpoint_lanes": STATE_TENDED,
	&"civilian_cutthrough": STATE_TENDED, &"inner_district_gate": STATE_TENDED,
	&"gate_district": STATE_TENDED,
	&"industrial_cutthrough": STATE_WORKING, &"rail_yard": STATE_WORKING,
	&"collapsed_ward": STATE_RUINED, &"ruined_services": STATE_RUINED,
	&"siege_services": STATE_RUINED,
	&"underpass_veins": STATE_DAMP, &"canal_services": STATE_DAMP,
	&"military_staging": STATE_MILITARY, &"outer_wall": STATE_MILITARY,
}

## Edge styles a ring cell draws in: the balustrade bit (arenas and gates)
## wins in every state; military ground takes the same plain parapet.
const STYLE_PLANTER := 0
const STYLE_BALUSTRADE := 1
const STYLE_KERB := 2
const STYLE_RUIN := 3
const STYLE_MOSS := 4

## The worn edge kits (tools/design/build_plaza_wear_kit.py, processed from
## existing kits): a worn kerb for working yards, the stump of a tumbled
## wall for ruined districts, a neglected mossy planter for damp S7. Only the
## active segment's state is resident (warm_state, called when the segment's
## world is configured): a set is 19 (kerb) or 37 (ruin, moss) pieces of
## 128 x 184 RGBA, ~94 KB each uncompressed and without mipmaps, so all three
## at once would hold ~8.7 MB of shared GPU memory no segment can use.
## Ruined and damp pieces carry several variants per mask (straight runs 4,
## others 2), picked per global cell by a stable hash (SALT_VARIANT), so a
## run never repeats one break every other cell.
const KIT_DIR := "res://assets/world/plazas_v1/kit/"
const WORN_STEMS := {STYLE_KERB: "kerb34", STYLE_RUIN: "ruin34", STYLE_MOSS: "moss34"}
const SALT_VARIANT := 0x51A7EA
## Textures the dressing of a worn square adds (PlazaDressing): the worn prop
## atlas in every worn state, the dry weedy bed fill in ruined squares and the
## wet moss bed fill in damp ones. Loaded with the state's edge set.
const WORN_ATLAS_PATH := KIT_DIR + "plaza_props_worn.png"
const WEEDS_GROUND_PATH := KIT_DIR + "plaza_weeds.png"
const MOSS_SOIL_PATH := KIT_DIR + "plaza_moss_soil.png"

static var _loaded_style := -1
## [mask] -> Array of the variant pieces of _loaded_style.
static var _loaded_pieces: Array = []
static var _loaded_fill: Texture2D = null
static var _dressing_state := -1
static var _dressing: Dictionary = {}

## Geometry baked into the pieces (world px): band thickness, lift (face
## height; for the ruin, its height at a continuing cell edge) and planter
## coping per style (STYLE_* order). Fills cover an open quadrant (plus, for
## a planter-shaped style, the coping of the arms beside it).
const PLANTER_THICK := 40.0
const PLANTER_LIFT := 16.0
const PLANTER_COPING := 5.0
const BALUSTRADE_THICK := 28.0
const BALUSTRADE_LIFT := 17.0
const STYLE_THICK: Array[float] = [40.0, 28.0, 26.0, 30.0, 40.0]
const STYLE_LIFT: Array[float] = [16.0, 17.0, 8.0, 6.0, 16.0]
const STYLE_COPING: Array[float] = [5.0, 0.0, 0.0, 0.0, 5.0]
## A knee-high edge casts a short contact shadow, not the wall kit's long one.
const SHADOW_OFFSET := Vector2(-5.0, 4.0)
## Parapet piers along straight runs, staggered per row like the wall kit.
const PIER_SPACING := 4


static func owns(kind: int, variant: int) -> bool:
	return kind == WorldBlockerGeometry.Kind.WALL and (variant & VARIANT_PLAZA_EDGE) != 0


static func is_balustrade(variant: int) -> bool:
	return (variant & VARIANT_BALUSTRADE) != 0


static func state_for_family(family: StringName) -> int:
	return int(STATE_BY_FAMILY.get(family, STATE_TENDED))


## The style a plaza edge cell draws in: arena and gate rings keep the plain
## parapet in every district; otherwise the chunk's maintenance state picks
## the finish (tended planter, worn kerb, tumbled wall stump, mossy planter,
## or the bare parapet of military ground).
static func style_of(variant: int, state: int) -> int:
	if is_balustrade(variant):
		return STYLE_BALUSTRADE
	return style_for_state(state)


static func style_for_state(state: int) -> int:
	match state:
		STATE_WORKING:
			return STYLE_KERB
		STATE_RUINED:
			return STYLE_RUIN
		STATE_DAMP:
			return STYLE_MOSS
		STATE_MILITARY:
			return STYLE_BALUSTRADE
	return STYLE_PLANTER


static func style_at(data: ChunkBuildData, cell: Vector2i) -> int:
	return style_of(data.variant_at(cell), data.plaza_edge_state)


## The piece for a plaza edge cell, from its own mask and (for parapet piers)
## its run neighbours inside the same chunk. Deterministic per global cell.
static func texture_for(data: ChunkBuildData, cell: Vector2i) -> Texture2D:
	var mask := data.mask_at(cell) & 15
	var style := style_at(data, cell)
	var global_cell := data.coord * data.cells_per_side + cell
	var horizontal := mask == (E | W)
	var vertical := mask == (N | S)
	if style == STYLE_PLANTER:
		if horizontal and posmod(global_cell.x, 2) == 1:
			return PLANTER_H_B
		if vertical and posmod(global_cell.y, 2) == 1:
			return PLANTER_V_B
		return PLANTER[mask]
	if style != STYLE_BALUSTRADE:
		var variants: Array = _worn_pieces(style)[mask]
		return variants[variant_index(global_cell, variants.size())]
	if horizontal or vertical:
		var along := global_cell.x if horizontal else global_cell.y
		var across := global_cell.y if horizontal else global_cell.x
		var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
		# A run end already stands on a pier: no second one beside it.
		if posmod(along + posmod(across * 7919, PIER_SPACING), PIER_SPACING) == 0 and _straight(data, cell - step, mask) and _straight(data, cell + step, mask):
			return BALUSTRADE_PIER_H if horizontal else BALUSTRADE_PIER_V
	return BALUSTRADE[mask]


## Stable per-cell variant pick (own salt; no generator, chunk or global RNG).
static func variant_index(global_cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	var h := int((SALT_VARIANT * 0x9E3779B9) & 0x7FFFFFFF)
	h = int((h ^ (global_cell.x * 73856093)) & 0x7FFFFFFF)
	h = int((h ^ (global_cell.y * 19349663)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return (h >> 7) % count


## Variants baked per connection mask (build_plaza_wear_kit.variant_count).
static func variant_count(style: int, mask: int) -> int:
	if style == STYLE_KERB:
		return 2 if mask == (E | W) or mask == (N | S) else 1
	if style == STYLE_RUIN or style == STYLE_MOSS:
		return 4 if mask == (E | W) or mask == (N | S) else 2
	return 1


static func piece_paths(style: int) -> Array:
	var stem: String = KIT_DIR + String(WORN_STEMS[style])
	var out: Array = []
	for mask in 16:
		var paths: Array[String] = []
		if style == STYLE_KERB:
			paths.append("%s_%02d.png" % [stem, mask])
			if mask == (E | W):
				paths.append(stem + "_h_b.png")
			elif mask == (N | S):
				paths.append(stem + "_v_b.png")
		else:
			for v in variant_count(style, mask):
				paths.append("%s_%02d_%d.png" % [stem, mask, v])
		out.append(paths)
	return out


## Make a maintenance state's edge set and dressing textures resident and
## release the previous state's (their textures free once no batch or node
## holds them). ChunkManager calls this when a segment's world is configured,
## so streaming never pays the first-touch load; texture_for loads on demand
## as a fallback (tests, direct chunk builds).
static func warm_state(state: int) -> void:
	var style := style_for_state(state)
	if WORN_STEMS.has(style):
		_load_style(style)
	_load_dressing(state)


static func warm_family(family: StringName) -> void:
	warm_state(state_for_family(family))


## The style whose edge set is resident, or -1 (planter and parapet only).
static func resident_style() -> int:
	return _loaded_style


static func _worn_pieces(style: int) -> Array:
	if _loaded_style != style:
		_load_style(style)
	return _loaded_pieces


static func _load_style(style: int) -> void:
	if _loaded_style == style:
		return
	var pieces: Array = []
	for paths: Array in piece_paths(style):
		var variants: Array[Texture2D] = []
		for path: String in paths:
			variants.append(load(path) as Texture2D)
		pieces.append(variants)
	_loaded_pieces = pieces
	_loaded_fill = load(KIT_DIR + String(WORN_STEMS[style]) + "_fill.png") as Texture2D
	_loaded_style = style


static func _load_dressing(state: int) -> void:
	if _dressing_state == state:
		return
	var out: Dictionary = {}
	if state != STATE_TENDED:
		out[&"worn_atlas"] = load(WORN_ATLAS_PATH) as Texture2D
	if state == STATE_RUINED:
		out[&"weeds_ground"] = load(WEEDS_GROUND_PATH) as Texture2D
	elif state == STATE_DAMP:
		out[&"moss_soil"] = load(MOSS_SOIL_PATH) as Texture2D
	_dressing = out
	_dressing_state = state


## A worn square's dressing texture (&"worn_atlas", &"weeds_ground",
## &"moss_soil") for `state`, loaded with the state if it is not resident.
static func dressing_texture(state: int, id: StringName) -> Texture2D:
	if _dressing_state != state:
		_load_dressing(state)
	return _dressing.get(id) as Texture2D


static func _straight(data: ChunkBuildData, cell: Vector2i, mask: int) -> bool:
	# Outside this chunk the neighbour is unknown; treat it as continuing.
	if cell.x < 0 or cell.y < 0 or cell.x >= data.cells_per_side or cell.y >= data.cells_per_side:
		return true
	return data.kind_at(cell) == WorldBlockerGeometry.Kind.WALL and (data.mask_at(cell) & 15) == mask


static func fill_texture(style: int) -> Texture2D:
	match style:
		STYLE_PLANTER:
			return PLANTER_FILL
		STYLE_BALUSTRADE:
			return BALUSTRADE_FILL
	if _loaded_style != style:
		_load_style(style)
	return _loaded_fill


## World offset of a quadrant fill's centre from its cell centre.
static func fill_offset(style: int, diagonal: Vector2i) -> Vector2:
	var side := (64.0 - STYLE_THICK[style]) * 0.5 + STYLE_COPING[style]
	return Vector2(diagonal) * (32.0 - side * 0.5) + Vector2(0.0, -STYLE_LIFT[style])


## Pieces, alternates and the fill of one style.
static func style_texture_count(style: int) -> int:
	if style == STYLE_PLANTER or style == STYLE_BALUSTRADE:
		return 16 + 2 + 1
	var total := 1
	for mask in 16:
		total += variant_count(style, mask)
	return total


## Distinct textures this kit can add to the renderer's batches, over every
## state: planter 19 + parapet 19 + kerb 19 + ruin 37 + moss 37.
static func texture_count() -> int:
	var total := 0
	for style in 5:
		total += style_texture_count(style)
	return total


## Textures resident while a segment in `state` streams: the always-loaded
## planter and parapet sets plus that state's worn set (if any).
static func resident_texture_count(state: int) -> int:
	var style := style_for_state(state)
	var total := style_texture_count(STYLE_PLANTER) + style_texture_count(STYLE_BALUSTRADE)
	if WORN_STEMS.has(style):
		total += style_texture_count(style)
	return total
