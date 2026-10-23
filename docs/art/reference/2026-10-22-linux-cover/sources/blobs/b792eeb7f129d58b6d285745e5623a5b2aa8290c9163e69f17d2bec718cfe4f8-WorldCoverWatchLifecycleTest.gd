extends Node2D
## A provider owns one subscription per watched signal across structural
## rescans and indexed/control round trips. Reconnect once, then verify that
## new nested forms still enter the very next indexed snapshot.
## This is resource lifecycle coverage, not a polling-cost benchmark.

const COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const INDEX_DISABLED_META := &"world_cover_index_disabled"
const FAR := Vector2(24000, 0)
const BEHIND := -100000.0
const WATCH_SIGNALS: Array[StringName] = [&"child_entered_tree", &"child_exiting_tree"]

var _passed: int = 0
var _failed: int = 0
var _cover: Node


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)


func _provider(uncached: bool = false) -> Node:
	var provider: Node = COVER.new() as Node
	provider.name = "WatchLifecycleControl" if uncached else "WatchLifecycleIndexed"
	if uncached:
		provider.set_meta(INDEX_DISABLED_META, true)
	get_viewport().add_child(provider)
	provider.set_process(false)
	return provider


func _roof_at(offset: Vector2) -> RoofOverlay:
	var roof: RoofOverlay = ROOF.instantiate() as RoofOverlay
	add_child(roof)
	roof.position = offset
	roof.configure(Rect2i(2, 2, 4, 3), 64, Vector2i.DOWN, null)
	return roof


func _form_at(parent: Node2D, point: Vector2) -> Polygon2D:
	var form: Polygon2D = Polygon2D.new()
	form.name = "LifecycleFullForm"
	form.set_meta(&"city_roof_form", &"lifecycle_return")
	form.set_meta(&"roof_occlusion_full_form", true)
	parent.add_child(form)
	var points: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in [point, point + Vector2(64, 0), point + Vector2(64, 64), point + Vector2(0, 64)]:
		points.append(form.to_local(corner))
	form.polygon = points
	return form


func _expect_next_refresh(label: String, samples: Array[Vector2]) -> void:
	_cover.call("refresh", self, true)
	var control: Node = _provider(true)
	control.call("refresh", self, true)
	_check(_cover.call("_semantic_records") == control.call("_semantic_records"), label + ": exact next-refresh records match uncached control")
	for sample: Vector2 in samples:
		var indexed: float = float(_cover.call("strength_at", sample, BEHIND))
		var reference: float = float(control.call("strength_at", sample, BEHIND))
		_check(reference > 0.99, label + ": original new form covers its control sample")
		_check(is_equal_approx(indexed, reference), label + ": indexed sample matches control on the next refresh")
	control.free()


func _run() -> void:
	_cover = _provider()
	var roof: RoofOverlay = _roof_at(FAR)
	var plane: Polygon2D = roof.get_node("RoofPoly") as Polygon2D
	var composition: Node2D = Node2D.new()
	composition.name = "LifecycleComposition"
	plane.add_child(composition)
	var leaf: Node2D = Node2D.new()
	leaf.name = "LifecycleLeaf"
	composition.add_child(leaf)
	_cover.call("refresh", self, true)
	_check((_cover.call("snapshot_stats") as Dictionary).primitive_count == 0, "far original roof contributes no visible coverage")
	# Structural churn forces the same retained subtree to be rescanned.
	for cycle in range(8):
		var temporary: Node2D = Node2D.new()
		temporary.name = "TransientBranch%d" % cycle
		leaf.add_child(temporary)
		_cover.call("refresh", self, true)
		temporary.free()
		_cover.call("refresh", self, true)
	# Resetting index state must not reacquire an already owned connection.
	for _cycle in range(4):
		_cover.set_meta(INDEX_DISABLED_META, true)
		_cover.call("refresh", self, true)
		_cover.set_meta(INDEX_DISABLED_META, false)
		_cover.call("refresh", self, true)
	# Ordinary group membership churn keeps the retained roof's subscriptions.
	for cycle in range(3):
		var streamed: RoofOverlay = _roof_at(FAR + Vector2(800 + cycle * 400, 0))
		_cover.call("refresh", self, true)
		streamed.free()
		_cover.call("refresh", self, true)
	var watcher: Callable = Callable(_cover, "_on_roof_subtree_changed")
	var watched: Array[Node] = [roof]
	watched.append_array(roof.find_children("*", "", true, false))
	for node: Node in watched:
		for signal_name: StringName in WATCH_SIGNALS:
			var connected: bool = node.is_connected(signal_name, watcher)
			_check(connected, "%s owns the provider's %s subscription after churn" % [node.name, signal_name])
			if not connected:
				continue
			node.disconnect(signal_name, watcher)
			var disconnected: bool = not node.is_connected(signal_name, watcher)
			_check(disconnected, "%s %s releases its sole provider subscription with one disconnect" % [node.name, signal_name])
			# A failing old implementation stays subscribed; do not accumulate
			# another reference merely to continue the independent parity checks.
			if disconnected:
				node.connect(signal_name, watcher)
	# Add a whole new branch below the retained reconnected leaf, with a form
	# whose original world geometry is in view although its roof is far away.
	var origin: Vector2 = _cover.get("_origin")
	var grid: Vector2i = _cover.get("_grid_size")
	var point: Vector2 = origin + Vector2(grid) * COVER.CELL_PX * 0.5
	var branch: Node2D = Node2D.new()
	branch.name = "NewNestedBranch"
	leaf.add_child(branch)
	_form_at(branch, point)
	_expect_next_refresh("new branch below reconnected leaf", [point + Vector2(32, 32)])
	# The new branch itself must have acquired a watch during that rescan.
	var child_point: Vector2 = point + Vector2(128, 0)
	var form: Polygon2D = _form_at(branch, child_point)
	_expect_next_refresh("later form below newly watched branch", [point + Vector2(32, 32), child_point + Vector2(32, 32)])
	var provider_ref: WeakRef = weakref(_cover)
	_cover.free()
	_check(provider_ref.get_ref() == null, "provider is released without ownership by watched nodes")
	for node: Node in watched:
		for signal_name: StringName in WATCH_SIGNALS:
			_check(not node.is_connected(signal_name, watcher), "%s %s disconnects when its provider is freed" % [node.name, signal_name])
	# Freed-provider callbacks cannot survive later mutations of live scenery.
	branch.add_child(Node2D.new())
	form.free()
	roof.free()
	await get_tree().process_frame
	print("WorldCoverWatchLifecycleTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
