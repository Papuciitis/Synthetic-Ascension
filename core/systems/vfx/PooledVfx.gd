extends RefCounted
class_name PooledVfx

## Short-lived set VFX (pulse rings, spokes, arc lines, cleave arcs,
## shockwaves) through the PoolManager instead of instantiate / queue_free
## per burst (performance war room M2). A Lattice triangle spawns up to
## nineteen of these and a Mass Arrest slam a dozen, each with its own
## additive material; the churn was the worst frame cost the build simulator
## saw on those sets. Nodes obtained here come back through release(),
## reset themselves in _on_pool_obtain(), and share one additive material.
## A per-kind live cap refuses spawns past LIVE_CAP_PER_KIND (callers
## already null-check), so a burst storm degrades to fewer rings, never to
## a longer frame. A VFX instantiated some other way still works: release()
## falls back to queue_free() for a node the pool never saw.

const RETAINED_PER_KIND := 48
const LIVE_CAP_PER_KIND := 64

static var _configured: Dictionary = {}
static var _live: Dictionary = {}
static var refused := 0
static var _fallback_material: CanvasItemMaterial = null


static func obtain(scene: PackedScene, parent: Node = null) -> Node:
	if scene == null:
		return null
	var pool := _pool_manager()
	var key := scene.resource_path
	if pool == null:
		var tree := Engine.get_main_loop() as SceneTree
		var target: Node = parent if parent != null and is_instance_valid(parent) else (tree.current_scene if tree != null else null)
		if target == null:
			return null
		var raw := scene.instantiate()
		if raw != null:
			target.add_child(raw)
		return raw
	var live: Array = _live_nodes(key)
	if live.size() >= LIVE_CAP_PER_KIND:
		refused += 1
		return null
	if not _configured.has(key):
		_configured[key] = true
		pool.call("set_limit_for_scene", scene, RETAINED_PER_KIND)
	var node: Node = pool.call("obtain", scene, parent)
	if node != null:
		live.append(node)
	return node


## Hands a VFX back to its pool; queue_free for one the pool never saw.
static func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var pool := _pool_manager()
	if pool == null or not node.has_meta("__pool_key"):
		node.queue_free()
		return
	if bool(node.get_meta("__in_pool", false)):
		return
	var key := str(node.get_meta("__pool_key"))
	_live_nodes(key).erase(node)
	pool.call("recycle", node)


static func live_count(scene: PackedScene) -> int:
	return _live_nodes(scene.resource_path).size() if scene != null else 0


## One additive material for every pooled VFX (they all blend additively).
static func additive_material() -> CanvasItemMaterial:
	var pool := _pool_manager()
	if pool != null and pool.has_method("get_additive_material"):
		return pool.call("get_additive_material") as CanvasItemMaterial
	if _fallback_material == null:
		_fallback_material = CanvasItemMaterial.new()
		_fallback_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _fallback_material


static func debug_counters() -> Dictionary:
	var live := 0
	for key in _live.keys():
		live += _live_nodes(String(key)).size()
	return {"live": live, "refused": refused, "kinds": _live.size()}


## Live nodes of one kind, pruned of anything freed, pooled or out of the
## tree (a scene change frees VFX without a release; the count must not
## climb toward the cap on their behalf).
static func _live_nodes(key: String) -> Array:
	var live: Array = _live.get(key, [])
	if not _live.has(key):
		_live[key] = live
	var index := live.size() - 1
	while index >= 0:
		var candidate: Variant = live[index]
		if not is_instance_valid(candidate) or bool((candidate as Node).get_meta("__in_pool", false)) or not (candidate as Node).is_inside_tree():
			live.remove_at(index)
		index -= 1
	return live


static func _pool_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("PoolManager")
