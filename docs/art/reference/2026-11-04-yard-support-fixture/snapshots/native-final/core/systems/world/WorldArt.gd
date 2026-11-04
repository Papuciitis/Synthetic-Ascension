@static_unload
extends RefCounted
# TEST ASSET-LOADER LEAF ONLY. Material IDs and repeats match production.
const GROUND_CARED_LAWN_INDEX := 13
static var _array: Texture2DArray
static func ground_repeat_world_px(index: int = -1) -> int:
    return 320 if index in [0,10,11,12,13] else 384
static func is_overgrowth_ground(index: int) -> bool:
    return index in [0,10,11,12]
static func ground_material_array() -> Texture2DArray:
    if _array != null: return _array
    _array = load("res://assets/world/ground/baked/ground_materials.res") as Texture2DArray
    return _array
static func release_static_caches() -> void:
    _array = null
