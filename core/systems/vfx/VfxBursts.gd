extends RefCounted
class_name VfxBursts

## The textured burst kinds and one call to play them anywhere in the
## world: VfxBursts.play(&"death", position). Scenes are loaded once and
## instances live in the PoolManager (PooledVfx), so a storm of deaths
## costs a few sprite draws, not a node per burst.

const SCENES := {
	&"death": "res://assets/vfx/world/bursts/Burst_Death.tscn",
	&"elite_death": "res://assets/vfx/world/bursts/Burst_EliteDeath.tscn",
	&"pickup": "res://assets/vfx/world/bursts/Burst_Pickup.tscn",
	&"dash": "res://assets/vfx/world/bursts/Burst_Dash.tscn",
	&"cast": "res://assets/vfx/world/bursts/Burst_Cast.tscn",
	&"hit_spark": "res://assets/vfx/world/bursts/Burst_HitSpark.tscn",
}

static var _cache: Dictionary = {}


static func kinds() -> Array:
	return SCENES.keys()


static func scene(kind: StringName) -> PackedScene:
	if _cache.has(kind):
		return _cache[kind] as PackedScene
	var path: String = String(SCENES.get(kind, ""))
	if path.is_empty():
		return null
	var packed := load(path) as PackedScene
	_cache[kind] = packed
	return packed


## Loads every kind now (segment build), so no burst pays a first-touch load.
static func warm() -> void:
	for kind in SCENES:
		scene(kind)


## Plays a burst at a world position under the current scene. Returns the
## node, or null when there is no scene or the kind's live cap is reached.
static func play(kind: StringName, pos: Vector2, size: float = 1.0, tint: Color = Color.WHITE, dir: Vector2 = Vector2.ZERO) -> VfxBurst:
	var packed := scene(kind)
	if packed == null:
		return null
	var tree := Engine.get_main_loop() as SceneTree
	var parent: Node = tree.current_scene if tree != null else null
	if parent == null:
		return null
	var node := PooledVfx.obtain(packed, parent) as VfxBurst
	if node == null:
		return null
	node.play(pos, size, tint, dir)
	return node
