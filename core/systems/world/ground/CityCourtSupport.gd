extends RefCounted
## Presentation support for a district-fill court (2026-10-31 yard pass).
##
## SiteParcelsImpl.decorate_urban_fill stamps every block's courtyard as one
## full rectangle of court setts (ground index 8) with a kerb ring, centred in
## the chunk: the most repeated broad rectangle in the city. The court stays
## that rectangle semantically (material, walkability, navigation, RNG); this
## planner only decides how strongly its setts PRESENT per cell, from actual
## use: the walking lines from every passage mouth and doorway into the
## court's working middle keep their setts, and the corners nobody crosses
## hand their ground back to the district (ground_splat's support_map; the
## theme decides what shows there, DistrictGroundPolicy court_release).
## The court is flush paving, so no kerb draws in or around it.
##
## The lines and the middle meander: their distances are measured at a point
## displaced by a smooth hashed field over the global cells, so no two courts
## share a shape and no edge runs as a long straight cut (2026-10-31 review).

## Half-width of a walking line that stays fully set, and where it has faded.
const ARM_IN := 1.3
const ARM_OUT := 2.6
## The court's working middle: a share of its short side, and its fade.
const HUB_SHARE := 0.22
const HUB_FADE := 1.6
## Every entrance keeps a fully set landing of this radius, before any warp.
const LANDING := 1.4
## How far (cells) and over what scale (cells) the lines and middle meander.
const WARP := 0.9
const WARP_SCALE := 3.2
## How far from the court a doorway still opens onto it (cells).
const DOOR_REACH := 3


## Use support over court.grow(1) clipped to the chunk: {"region": Rect2i,
## "support": PackedByteArray (one byte per region cell, row-major)}. Ring
## cells take the value of the court cell beside them, so the court edge only
## recedes where its own cells are unused. `entrances` are chunk-local cell
## points on or beside the court; `origin` is the chunk's first global cell,
## which places the meander.
static func plan(court: Rect2i, entrances: Array[Vector2], cells_per_chunk: int, origin: Vector2i = Vector2i.ZERO) -> Dictionary:
	var region := court.grow(1).intersection(Rect2i(0, 0, cells_per_chunk, cells_per_chunk))
	var support := PackedByteArray()
	support.resize(region.get_area())
	if not court.has_area() or not region.has_area():
		return {"region": Rect2i(), "support": PackedByteArray()}
	var hub := Vector2(court.position) + Vector2(court.size) * 0.5
	var hub_radius := HUB_SHARE * float(mini(court.size.x, court.size.y))
	var lo := Vector2(court.position) + Vector2(0.5, 0.5)
	var hi := Vector2(court.end) - Vector2(0.5, 0.5)
	var mouths: Array[Vector2] = []
	for entrance: Vector2 in entrances:
		mouths.append(entrance.clamp(lo, hi))
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var point := (Vector2(x, y) + Vector2(0.5, 0.5)).clamp(lo, hi)
			var global := Vector2(origin) + point
			var warped := point + Vector2(_noise(global / WARP_SCALE, 7151) - 0.5, _noise(global / WARP_SCALE, 9283) - 0.5) * (2.0 * WARP)
			var amount := 1.0 - smoothstep(hub_radius, hub_radius + HUB_FADE, warped.distance_to(hub))
			for mouth: Vector2 in mouths:
				var along := Geometry2D.get_closest_point_to_segment(warped, mouth, hub)
				amount = maxf(amount, 1.0 - smoothstep(ARM_IN, ARM_OUT, warped.distance_to(along)))
				amount = maxf(amount, 1.0 - smoothstep(LANDING, LANDING + 1.0, point.distance_to(mouth)))
			support[(y - region.position.y) * region.size.x + (x - region.position.x)] = roundi(amount * 255.0)
	return {"region": region, "support": support}


## Where use enters the court, in chunk-local cell points: the middle of every
## passage's overlap with the court, and the front cell of every doorway
## (ChunkGen door markers) within DOOR_REACH cells of it.
static func entrances(chunk: Node2D, court: Rect2i, passages: Array, cell_px: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for passage: Rect2i in passages:
		var mouth := passage.intersection(court.grow(1))
		if mouth.has_area():
			points.append(Vector2(mouth.position) + Vector2(mouth.size) * 0.5)
	var reach := court.grow(DOOR_REACH)
	for child: Node in chunk.get_children():
		if not (child is Marker2D and StringName(child.get_meta(&"spawn_socket_kind", &"")) == &"door"):
			continue
		var front := Vector2i(((child as Node2D).position / cell_px).floor())
		if reach.has_point(front):
			points.append(Vector2(front) + Vector2(0.5, 0.5))
	return points


## Smooth value noise in [0, 1] over the global cell lattice (the same hash
## CityGroundCare uses for its pockets): deterministic, no generator RNG.
static func _noise(point: Vector2, seed_value: int) -> float:
	var lattice := Vector2i(floori(point.x), floori(point.y))
	var fraction := point - Vector2(lattice)
	fraction = fraction * fraction * (Vector2(3, 3) - 2.0 * fraction)
	return lerpf(lerpf(_hash(lattice, seed_value), _hash(lattice + Vector2i.RIGHT, seed_value), fraction.x), lerpf(_hash(lattice + Vector2i.DOWN, seed_value), _hash(lattice + Vector2i.ONE, seed_value), fraction.x), fraction.y)


static func _hash(cell: Vector2i, seed_value: int) -> float:
	var bits := (cell.x * 374761393) ^ (cell.y * 668265263) ^ seed_value
	bits = ((bits ^ (bits >> 13)) & 0x7fffffff) * 1274126177
	bits = (bits ^ (bits >> 16)) & 0x7fffffff
	return float(bits) / 2147483647.0
