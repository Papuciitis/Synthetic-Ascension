extends RefCounted
class_name SiteManager

# Thin facade over SiteOverlayImpl + SiteParcelsImpl.
# This keeps ChunkManager.gd and SiteManager.gd small & stable.

const OVERLAY_IMPL: Script = preload("res://core/systems/world/proc/SiteOverlayImpl.gd")
const PARCELS_IMPL: Script = preload("res://core/systems/world/proc/SiteParcelsImpl.gd")

var _overlay: SiteOverlayImpl = OVERLAY_IMPL.new() as SiteOverlayImpl
var _parcels: SiteParcelsImpl = PARCELS_IMPL.new() as SiteParcelsImpl


func reset() -> void:
	if _overlay != null:
		_overlay.reset()


func decorate_chunk(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	cfg: Dictionary
) -> bool:
	if _overlay == null:
		return false
	return _overlay.decorate_chunk(chunk_manager, chunk, coord, cfg)


func decorate_district_parcels(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	lane_rect_h: Rect2i,
	lane_rect_v: Rect2i,
	keepout_rects: Array[Rect2i],
	cfg: Dictionary
) -> Array[Rect2i]:
	if _parcels == null:
		return []
	return _parcels.decorate_district_parcels(chunk_manager, chunk, coord, lane_rect_h, lane_rect_v, keepout_rects, cfg)

func decorate_urban_fill(
	chunk_manager: Node,
	chunk: Node2D,
	coord: Vector2i,
	cfg: Dictionary
) -> Array[Rect2i]:
	if _parcels == null:
		return []
	return _parcels.decorate_urban_fill(chunk_manager, chunk, coord, cfg)
