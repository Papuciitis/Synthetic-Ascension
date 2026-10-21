extends RefCounted
## Plaza presentation (2026-10-21 plaza pass): squares framed by low planter
## edges instead of the full-height wall kit, after the concept plates
## (paved squares framed by buildings and contained planting).
##
## Presentation only: ring cells keep their WALL kind and mask (the 24 px
## collision band); only presentation variant bits change, and the renderer
## draws them with PlazaEdgeKit. No generator RNG stream is read or advanced.
##
## Hook (small, delimited): ChunkGenDistrict (ring mark after the walls are
## spawned).

const KIT := preload("res://core/systems/world/chunks/PlazaEdgeKit.gd")

const META_PLAZA := &"_plaza_presentation"

## Plaza roles whose ring draws as a parapet (boss and miniboss courts,
## checkpoints and gates): no planting along an edge where tells must stay
## readable. Every other ring, ward courts included, is a planter.
const BALUSTRADE_ROLES: Array[StringName] = [&"checkpoint", &"miniboss_arena", &"boss_arena", &"gate"]

## Dev and test toggle: false reproduces the pre-pass chunk exactly.
static var enabled := true


## ChunkGenDistrict, after the walls are spawned: every ring cell that became
## a WALL keeps kind and mask and is marked as a low plaza edge.
static func mark_ring(gen: ChunkGenImpl, chunk: Node2D, role: StringName, archetype: StringName, plaza_cells: Dictionary, ring_cells: Dictionary) -> void:
	if not enabled or plaza_cells.is_empty():
		return
	var data := _build_data(gen)
	var balustrade := role in BALUSTRADE_ROLES or archetype == &"gate"
	var bits := KIT.VARIANT_PLAZA_EDGE | (KIT.VARIANT_BALUSTRADE if balustrade else 0)
	var marked: Array[Vector2i] = []
	if data != null:
		var ordered: Array = ring_cells.keys()
		ordered.sort()
		for cell: Vector2i in ordered:
			if data.kind_at(cell) != WorldBlockerGeometry.Kind.WALL:
				continue
			var index := data._index(cell)
			data.blocker_variant[index] = data.blocker_variant[index] | bits
			marked.append(cell)
	chunk.set_meta(META_PLAZA, {
		"role": role,
		"archetype": archetype,
		"balustrade": balustrade,
		"plaza": plaza_cells.duplicate(),
		"ring": marked,
	})


static func _build_data(gen: ChunkGenImpl) -> ChunkBuildData:
	if gen == null or gen.cm == null:
		return null
	return gen.cm.get("_active_build_data") as ChunkBuildData
