extends RefCounted
## Low plaza edges (2026-10-21 plaza pass). The perimeter ring of a plaza,
## arena or gate chunk keeps its physical WALL cells (kind, connection mask,
## 24 px collision band) but draws as knee-high dressed limestone instead of
## the 92 px wall kit: a planter box with clipped box shrubs and lavender on
## ordinary squares, a plain parapet with corner piers where combat must stay
## readable (gates and arena courts). Pieces are baked one per connection mask
## by tools/design/build_plaza_kit.py on the wall kit's canvas (the cell plus
## 28 px above it), so ChunkBlockRenderer batches them through its kit path.

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

## Geometry baked into the pieces (world px): band thickness, lift (face
## height) and planter coping. Fills cover an open quadrant (plus, for the
## planter, the coping of the arms beside it).
const PLANTER_THICK := 40.0
const PLANTER_LIFT := 16.0
const PLANTER_COPING := 5.0
const BALUSTRADE_THICK := 28.0
const BALUSTRADE_LIFT := 17.0
## A knee-high edge casts a short contact shadow, not the wall kit's long one.
const SHADOW_OFFSET := Vector2(-5.0, 4.0)
## Parapet piers along straight runs, staggered per row like the wall kit.
const PIER_SPACING := 4


static func owns(kind: int, variant: int) -> bool:
	return kind == WorldBlockerGeometry.Kind.WALL and (variant & VARIANT_PLAZA_EDGE) != 0


static func is_balustrade(variant: int) -> bool:
	return (variant & VARIANT_BALUSTRADE) != 0


## The piece for a plaza edge cell, from its own mask and (for parapet piers)
## its run neighbours inside the same chunk. Deterministic per global cell.
static func texture_for(data: ChunkBuildData, cell: Vector2i) -> Texture2D:
	var mask := data.mask_at(cell) & 15
	var variant := data.variant_at(cell)
	var global_cell := data.coord * data.cells_per_side + cell
	var horizontal := mask == (E | W)
	var vertical := mask == (N | S)
	if not is_balustrade(variant):
		if horizontal and posmod(global_cell.x, 2) == 1:
			return PLANTER_H_B
		if vertical and posmod(global_cell.y, 2) == 1:
			return PLANTER_V_B
		return PLANTER[mask]
	if horizontal or vertical:
		var along := global_cell.x if horizontal else global_cell.y
		var across := global_cell.y if horizontal else global_cell.x
		var step := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
		# A run end already stands on a pier: no second one beside it.
		if posmod(along + posmod(across * 7919, PIER_SPACING), PIER_SPACING) == 0 and _straight(data, cell - step, mask) and _straight(data, cell + step, mask):
			return BALUSTRADE_PIER_H if horizontal else BALUSTRADE_PIER_V
	return BALUSTRADE[mask]


static func _straight(data: ChunkBuildData, cell: Vector2i, mask: int) -> bool:
	# Outside this chunk the neighbour is unknown; treat it as continuing.
	if cell.x < 0 or cell.y < 0 or cell.x >= data.cells_per_side or cell.y >= data.cells_per_side:
		return true
	return data.kind_at(cell) == WorldBlockerGeometry.Kind.WALL and (data.mask_at(cell) & 15) == mask


static func fill_texture(variant: int) -> Texture2D:
	return BALUSTRADE_FILL if is_balustrade(variant) else PLANTER_FILL


## World offset of a quadrant fill's centre from its cell centre.
static func fill_offset(variant: int, diagonal: Vector2i) -> Vector2:
	var thick := BALUSTRADE_THICK if is_balustrade(variant) else PLANTER_THICK
	var coping := 0.0 if is_balustrade(variant) else PLANTER_COPING
	var lift := BALUSTRADE_LIFT if is_balustrade(variant) else PLANTER_LIFT
	var side := (64.0 - thick) * 0.5 + coping
	return Vector2(diagonal) * (32.0 - side * 0.5) + Vector2(0.0, -lift)


## Distinct textures this kit can add to the renderer's batches.
static func texture_count() -> int:
	return PLANTER.size() + 3 + BALUSTRADE.size() + 3
