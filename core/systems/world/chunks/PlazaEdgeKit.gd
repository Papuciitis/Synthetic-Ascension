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
## planter family; a worn kerb in working yards, a broken weedy planter in
## ruined districts, a mossy one in damp S7, the bare parapet on military
## ground (tools/design/build_plaza_wear_kit.py, processed existing kits).

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

## Edge styles a ring cell draws in: the balustrade bit (arenas and gates)
## wins in every state; military ground takes the same plain parapet.
const STYLE_PLANTER := 0
const STYLE_BALUSTRADE := 1
const STYLE_KERB := 2
const STYLE_RUIN := 3
const STYLE_MOSS := 4

## Working districts: a low worn kerb, no planting (build_plaza_wear_kit.py).
const KERB: Array[Texture2D] = [
	preload("res://assets/world/plazas_v1/kit/kerb34_00.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_01.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_02.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_03.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_04.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_05.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_06.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_07.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_08.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_09.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_10.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_11.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_12.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_13.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_14.png"),
	preload("res://assets/world/plazas_v1/kit/kerb34_15.png"),
]
const KERB_H_B := preload("res://assets/world/plazas_v1/kit/kerb34_h_b.png")
const KERB_V_B := preload("res://assets/world/plazas_v1/kit/kerb34_v_b.png")
const KERB_FILL := preload("res://assets/world/plazas_v1/kit/kerb34_fill.png")
## Ruined districts: the planter neglected, coping broken, weeds.
const RUIN: Array[Texture2D] = [
	preload("res://assets/world/plazas_v1/kit/ruin34_00.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_01.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_02.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_03.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_04.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_05.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_06.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_07.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_08.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_09.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_10.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_11.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_12.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_13.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_14.png"),
	preload("res://assets/world/plazas_v1/kit/ruin34_15.png"),
]
const RUIN_H_B := preload("res://assets/world/plazas_v1/kit/ruin34_h_b.png")
const RUIN_V_B := preload("res://assets/world/plazas_v1/kit/ruin34_v_b.png")
const RUIN_FILL := preload("res://assets/world/plazas_v1/kit/ruin34_fill.png")
## Damp districts: mossy coping, wet soil, unclipped weeds and ivy.
const MOSS: Array[Texture2D] = [
	preload("res://assets/world/plazas_v1/kit/moss34_00.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_01.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_02.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_03.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_04.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_05.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_06.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_07.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_08.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_09.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_10.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_11.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_12.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_13.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_14.png"),
	preload("res://assets/world/plazas_v1/kit/moss34_15.png"),
]
const MOSS_H_B := preload("res://assets/world/plazas_v1/kit/moss34_h_b.png")
const MOSS_V_B := preload("res://assets/world/plazas_v1/kit/moss34_v_b.png")
const MOSS_FILL := preload("res://assets/world/plazas_v1/kit/moss34_fill.png")

## Geometry baked into the pieces (world px): band thickness, lift (face
## height) and planter coping per style (STYLE_* order). Fills cover an open
## quadrant (plus, for a planter-shaped style, the coping of the arms beside
## it).
const PLANTER_THICK := 40.0
const PLANTER_LIFT := 16.0
const PLANTER_COPING := 5.0
const BALUSTRADE_THICK := 28.0
const BALUSTRADE_LIFT := 17.0
const STYLE_THICK: Array[float] = [40.0, 28.0, 26.0, 40.0, 40.0]
const STYLE_LIFT: Array[float] = [16.0, 17.0, 8.0, 14.0, 16.0]
const STYLE_COPING: Array[float] = [5.0, 0.0, 0.0, 5.0, 5.0]
## A knee-high edge casts a short contact shadow, not the wall kit's long one.
const SHADOW_OFFSET := Vector2(-5.0, 4.0)
## Parapet piers along straight runs, staggered per row like the wall kit.
const PIER_SPACING := 4


static func owns(kind: int, variant: int) -> bool:
	return kind == WorldBlockerGeometry.Kind.WALL and (variant & VARIANT_PLAZA_EDGE) != 0


static func is_balustrade(variant: int) -> bool:
	return (variant & VARIANT_BALUSTRADE) != 0


## The style a plaza edge cell draws in: arena and gate rings keep the plain
## parapet in every district; otherwise the chunk's maintenance state picks
## the finish (tended planter, worn kerb, broken planter, mossy planter, or
## the bare parapet of military ground).
static func style_of(variant: int, state: int) -> int:
	if is_balustrade(variant):
		return STYLE_BALUSTRADE
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
	if style != STYLE_BALUSTRADE:
		var pieces: Array = _pieces_of(style)
		if horizontal and posmod(global_cell.x, 2) == 1:
			return pieces[1]
		if vertical and posmod(global_cell.y, 2) == 1:
			return pieces[2]
		return (pieces[0] as Array)[mask]
	if horizontal or vertical:
		var along := global_cell.x if horizontal else global_cell.y
		var across := global_cell.y if horizontal else global_cell.x
		var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
		# A run end already stands on a pier: no second one beside it.
		if posmod(along + posmod(across * 7919, PIER_SPACING), PIER_SPACING) == 0 and _straight(data, cell - step, mask) and _straight(data, cell + step, mask):
			return BALUSTRADE_PIER_H if horizontal else BALUSTRADE_PIER_V
	return BALUSTRADE[mask]


## [masks, straight-run alternate (E-W), alternate (N-S), fill] per style.
static func _pieces_of(style: int) -> Array:
	match style:
		STYLE_KERB:
			return [KERB, KERB_H_B, KERB_V_B, KERB_FILL]
		STYLE_RUIN:
			return [RUIN, RUIN_H_B, RUIN_V_B, RUIN_FILL]
		STYLE_MOSS:
			return [MOSS, MOSS_H_B, MOSS_V_B, MOSS_FILL]
		STYLE_BALUSTRADE:
			return [BALUSTRADE, BALUSTRADE_PIER_H, BALUSTRADE_PIER_V, BALUSTRADE_FILL]
	return [PLANTER, PLANTER_H_B, PLANTER_V_B, PLANTER_FILL]


static func _straight(data: ChunkBuildData, cell: Vector2i, mask: int) -> bool:
	# Outside this chunk the neighbour is unknown; treat it as continuing.
	if cell.x < 0 or cell.y < 0 or cell.x >= data.cells_per_side or cell.y >= data.cells_per_side:
		return true
	return data.kind_at(cell) == WorldBlockerGeometry.Kind.WALL and (data.mask_at(cell) & 15) == mask


static func fill_texture(style: int) -> Texture2D:
	return _pieces_of(style)[3]


## World offset of a quadrant fill's centre from its cell centre.
static func fill_offset(style: int, diagonal: Vector2i) -> Vector2:
	var side := (64.0 - STYLE_THICK[style]) * 0.5 + STYLE_COPING[style]
	return Vector2(diagonal) * (32.0 - side * 0.5) + Vector2(0.0, -STYLE_LIFT[style])


## Distinct textures this kit can add to the renderer's batches.
static func texture_count() -> int:
	return PLANTER.size() + 3 + BALUSTRADE.size() + 3 + KERB.size() + 3 + RUIN.size() + 3 + MOSS.size() + 3
