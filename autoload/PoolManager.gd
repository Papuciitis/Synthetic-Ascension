extends Node

# Simple node pooling for high-churn gameplay objects (bullets, missiles, VFX).
# Keeps visuals/feel identical while cutting instantiate()/queue_free() spikes.

var _pools: Dictionary = {} # String (scene path) -> Array[Node]
var _additive_material: CanvasItemMaterial = null

func _get_pool(key: String) -> Array:
	# Dictionary.get() returns Nil when missing; avoid assigning Nil to a typed Array.
	var p = _pools.get(key)
	if p is Array:
		return p
	var arr: Array = []
	_pools[key] = arr
	return arr

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_material()

func _ensure_material() -> void:
	if _additive_material != null:
		return
	_additive_material = CanvasItemMaterial.new()
	_additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func get_additive_material() -> CanvasItemMaterial:
	_ensure_material()
	return _additive_material

func obtain(scene: PackedScene, parent: Node = null) -> Node:
	if scene == null:
		return null
	var key: String = scene.resource_path
	if key == "":
		# fallback key (still works, just no sharing across reloads)
		key = str(scene.get_instance_id())

	var pool: Array = _get_pool(key)
	var node: Node = null
	if pool != null and pool.size() > 0:
		node = pool.pop_back() as Node
	else:
		node = scene.instantiate()

	if node == null:
		return null

	node.set_meta("__pool_key", key)

	# Attach first (some scripts expect to be in-tree during reset)
	var target_parent: Node = null
	if parent != null and is_instance_valid(parent):
		target_parent = parent
	else:
		var cs := get_tree().current_scene
		target_parent = cs if cs != null else self

	# Nodes pulled from the pool are usually still parented under PoolManager.
	# Detach before attaching to the requested parent/current scene.
	if node.get_parent() != target_parent:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		target_parent.add_child(node)
		
	# Re-enable after attach
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node.has_method("set_process"):
		node.set_process(true)
	if node.has_method("set_physics_process"):
		node.set_physics_process(true)
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if "monitoring" in node:
		node.set("monitoring", true)
	if "monitorable" in node:
		node.set("monitorable", true)

	if node.has_method("_on_pool_obtain"):
		node.call("_on_pool_obtain")

	return node

func recycle(node: Node) -> void:
	if node == null:
		return
	if not is_instance_valid(node):
		return

	var key: String = ""
	if node.has_meta("__pool_key"):
		key = str(node.get_meta("__pool_key"))

	if key == "":
		node.queue_free()
		return

	# custom hook first (so scripts can reset internal state while still in tree)
	if node.has_method("_on_pool_recycle"):
		node.call("_on_pool_recycle")

	# detach
	if node.get_parent() != null:
		node.get_parent().remove_child(node)

	# disable
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.has_method("set_process"):
		node.set_process(false)
	if node.has_method("set_physics_process"):
		node.set_physics_process(false)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	if "monitoring" in node:
		node.set("monitoring", false)
	if "monitorable" in node:
		node.set("monitorable", false)

	# keep pooled nodes under PoolManager (so they stay alive & valid)
	add_child(node)

	var pool: Array = _get_pool(key)
	pool.append(node)

func warm(scene: PackedScene, count: int) -> void:
	if scene == null or count <= 0:
		return
	var key: String = scene.resource_path
	if key == "":
		key = str(scene.get_instance_id())
	var pool: Array = _get_pool(key)
	while pool.size() < count:
		var n: Node = scene.instantiate()
		if n == null:
			break
		n.set_meta("__pool_key", key)
		n.process_mode = Node.PROCESS_MODE_DISABLED
		if n is CanvasItem:
			(n as CanvasItem).visible = false
		add_child(n)
		pool.append(n)
