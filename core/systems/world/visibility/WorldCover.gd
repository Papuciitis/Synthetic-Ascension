extends Node
## One visual-only snapshot per viewport/frame. Geometry is spatially indexed;
## consumers provide fragment coordinates and their own ground depth. No actor,
## pickup eligibility, collision, loot or simulation state is read or changed.

const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const CELL_PX := 256.0
const BUFFER_WIDTH := 256
const VIEW_MARGIN := 256.0
## Dev profiling control: same live collection with legacy upload/rebind work.
const FORCE_UPLOAD_META := &"world_cover_force_uploads"
## Shared read-only default for cache lookups (never written).
const _NO_ENTRY := {}
static var _instances: Dictionary = {}
var _frame := -1
var _generation := 0
var _records: Array[Dictionary] = []
var _roof_cache: Dictionary = {}
var _solid_cache: Dictionary = {}
var _source_cache: Dictionary = {}
var _source_reads := 0
var _alpha_keys: Array[int] = []
var _alpha_size := Vector2i.ONE
var _alpha: Texture2DArray
var _grid: ImageTexture
var _indices: ImageTexture
var _data: ImageTexture
var _origin := Vector2.ZERO
var _grid_size := Vector2i.ONE
var _index_count := 0
var _max_candidates := 0
var _materials: Dictionary = {}
var _refresh_usec := 0
var _peak_refresh_usec := 0
var _peak_primitives := 0
var _peak_candidates := 0
var _snapshot_semantics: Array = []
var _snapshot_origin := Vector2.INF
var _snapshot_grid_size := Vector2i.ZERO
var _snapshot_alpha: Texture2DArray
var _snapshot_valid := false
var _snapshot_builds := 0
var _snapshot_reuses := 0
var _data_uploads := 0
var _data_upload_bytes := 0
var _alpha_uploads := 0
var _alpha_upload_bytes := 0
var _material_binds := 0
var _collection_usec := 0
var _comparison_usec := 0
var _snapshot_usec := 0
var _binding_usec := 0
var _roof_usec := 0
var _solid_usec := 0
var _sprite_usec := 0
var _visited_roofs := 0
var _visited_faces := 0
var _index_resyncs := 0

static func get_for(view: Node) -> Node:
	var viewport := view.get_viewport()
	var key := viewport.get_instance_id()
	var existing: WeakRef = _instances.get(key)
	if existing != null and is_instance_valid(existing.get_ref()):
		return existing.get_ref() as Node
	var script: GDScript = load("res://core/systems/world/visibility/WorldCover.gd")
	var service := script.new() as Node
	service.name = "WorldCover"
	viewport.add_child(service)
	_instances[key] = weakref(service)
	return service

func _ready() -> void:
	process_priority = -100

func _process(_delta: float) -> void:
	refresh(self)

func refresh(view: Node, force: bool = false) -> void:
	var frame := Engine.get_process_frames()
	if not force and _frame == frame:
		return
	var began := Time.get_ticks_usec()
	_frame = frame
	_generation += 1
	_records.clear()
	var viewport := view.get_viewport()
	var world := viewport.find_world_2d()
	var canvas := world.canvas
	var inverse := viewport.get_canvas_transform().affine_inverse()
	var rect := viewport.get_visible_rect()
	var area := Rect2(inverse * rect.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		area = area.expand(inverse * corner)
	area = area.grow(VIEW_MARGIN)
	_origin = (area.position / CELL_PX).floor() * CELL_PX
	_grid_size = Vector2i(((area.end - _origin) / CELL_PX).ceil())
	# Entering or leaving the uncached control rebuilds the index, so indexed
	# entries are always watched.
	var uncached := bool(get_meta(INDEX_DISABLED_META,false))
	if uncached or uncached != _uncached:
		_reset_index()
	_uncached = uncached
	_validation_usec = 0
	var roof_started := Time.get_ticks_usec()
	var alpha_memo: Dictionary = {}
	_collect_roofs(view,area,world,canvas,alpha_memo)
	var solid_started := Time.get_ticks_usec()
	_roof_usec = solid_started-roof_started
	_collect_solid_faces(view,area,world,canvas,alpha_memo)
	var sprite_started := Time.get_ticks_usec()
	_solid_usec = sprite_started-solid_started
	var sprites: Array[Dictionary] = []
	var textures: Array[Texture2D] = []
	for node: Node in view.get_tree().get_nodes_in_group(FOREGROUND.GROUP):
		var sprite := node as Sprite2D
		if sprite == null or sprite.get_world_2d() != world or sprite.get_canvas() != canvas:
			continue
		# get_rect includes the live region/frame, offsets and atlas margins.
		# Its transformed AABB is conservative, including rotated/scaled art;
		# avoid building descriptors for loaded scenery outside this view.
		var draw_bounds: Rect2 = sprite.global_transform*sprite.get_rect()
		if not draw_bounds.intersects(area):
			continue
		var descriptor := FOREGROUND.describe(sprite)
		if descriptor.is_empty() or not (descriptor.bounds as Rect2).intersects(area):
			continue
		var texture: Texture2D = descriptor.texture
		if not textures.has(texture):
			textures.append(texture)
		descriptor["kind"] = 1
		descriptor["layer"] = textures.find(texture)
		sprites.append(descriptor)
	_prepare_alpha(textures)
	for descriptor: Dictionary in sprites:
		if _source_cache.has((descriptor.texture as Texture2D).get_instance_id()):
			descriptor["layer"] = _alpha_keys.find((descriptor.texture as Texture2D).get_instance_id())
			_records.append(descriptor)
	_sprite_usec = Time.get_ticks_usec()-sprite_started
	_collection_usec = Time.get_ticks_usec()-began
	var comparison_started := Time.get_ticks_usec()
	var semantics := _semantic_records()
	var snapshot_changed: bool = bool(get_meta(FORCE_UPLOAD_META,false)) or not _snapshot_valid or _origin != _snapshot_origin or _grid_size != _snapshot_grid_size or semantics != _snapshot_semantics
	_comparison_usec = Time.get_ticks_usec()-comparison_started
	_snapshot_usec = 0
	if snapshot_changed:
		var snapshot_started := Time.get_ticks_usec()
		_upload_snapshot()
		_snapshot_usec = Time.get_ticks_usec()-snapshot_started
		_snapshot_semantics = semantics
		_snapshot_origin = _origin
		_snapshot_grid_size = _grid_size
		_snapshot_valid = true
		_snapshot_builds += 1
	else:
		_snapshot_reuses += 1
	var bindings_changed := snapshot_changed or _snapshot_alpha != _alpha
	var binding_started := Time.get_ticks_usec()
	for key: Variant in _materials.keys():
		var material := (_materials[key] as WeakRef).get_ref() as ShaderMaterial
		if material == null:
			_materials.erase(key)
		elif bindings_changed:
			_bind(material)
	_snapshot_alpha = _alpha
	_binding_usec = Time.get_ticks_usec()-binding_started
	_refresh_usec = Time.get_ticks_usec()-began
	_peak_refresh_usec = maxi(_peak_refresh_usec,_refresh_usec)
	_peak_primitives = maxi(_peak_primitives,_records.size())
	_peak_candidates = maxi(_peak_candidates,_max_candidates)

func _semantic_records() -> Array:
	# Exact render/index inputs, including resource identity, not a hash that
	# could collide. describe() creates a fresh owner WeakRef each frame; that
	# reference is not geometry and must not defeat reuse. Integer texture IDs
	# also avoid keeping removed original textures alive through this cache.
	var result: Array = []
	for record: Dictionary in _records:
		if int(record.kind) == 0:
			result.append([0,record.strength,record.front_y,record.points,record.bounds])
		else:
			result.append([1,record.strength,record.front_y,record.layer,(record.texture as Texture2D).get_instance_id(),record.world_to_uv,record.source_rect,record.bounds])
	return result

## Spatial occluder index (2026-10-21). Loaded occluders far outside the view
## used to pay for every live check, alpha walk and geometry fingerprint each
## frame, so the frame cost grew with every building in the loaded chunks
## (1788 faces and 94 roofs cost 32 ms at an S10 street while 291 triangles
## were in view). Each occluder now keeps its world reach - the bounds of
## every piece it can contribute - and sits in BUCKET_PX buckets by reach.
## A refresh visits only occluders indexed in buckets the view area touches
## and runs the full live checks on them as before, in group order, so
## records, their order and their values are unchanged.
##
## Live-transform contract (phase-1 lead review, 21 October 2026): the reach
## is exact at every refresh. Before the gather, every indexed occluder's
## reach inputs are compared exactly with the inputs it was built from - a
## face's global transform and polygon; a roof plane's global transform and
## polygon and, for every roof form at any depth below it, that form's global
## transform and polygon. Structural edits below a roof (a form added,
## removed or reparented at any depth, or a replaced roof plane) arrive as
## child_entered_tree/child_exiting_tree from every watched node of the roof
## subtree. An occluder moved or reshaped from anywhere into view is
## therefore gathered on the next refresh, never after a rolling delay. The
## comparison is a typed loop of native getters, not the old per-occluder
## live checks, alpha walk and geometry hash; only changed entries rebuild.
## Group membership is still compared natively every refresh, and new or
## removed occluders re-index at once. INDEX_DISABLED_META is the uncached
## control: every refresh then rebuilds every entry and visits every
## occluder without the view index or watches.
const BUCKET_PX := 512.0
const INDEX_DISABLED_META := &"world_cover_index_disabled"
const _ROOF_POLY := ^"RoofPoly"
var _roof_index := {"nodes":[],"slot":{},"buckets":{}}
var _face_index := {"nodes":[],"slot":{},"buckets":{}}
## The exact inputs each indexed reach was built from, in flat typed arrays
## so validation is one tight loop per kind. Faces and roof planes are
## slot-aligned (group order; rebuilt on membership changes); roof forms of
## every roof are one flat list with their owning roof slot.
var _roof_nodes: Array[RoofOverlay] = []
var _plane_nodes: Array[Polygon2D] = []
var _plane_xfs: Array[Transform2D] = []
var _plane_polys: Array[PackedVector2Array] = []
var _form_nodes: Array[Polygon2D] = []
var _form_xfs: Array[Transform2D] = []
var _form_polys: Array[PackedVector2Array] = []
var _form_slots := PackedInt32Array()
var _forms_stale := true
var _dirty_roofs: Dictionary = {}
var _face_nodes: Array[Polygon2D] = []
var _face_xfs: Array[Transform2D] = []
var _face_polys: Array[PackedVector2Array] = []
var _uncached := false
var _validation_usec := 0
var _roof_validation_usec := 0
var _renewed_roofs := 0
var _renewed_faces := 0
var _structure_events := 0

func _collect_roofs(view: Node, area: Rect2, world: World2D, canvas: RID, alpha_memo: Dictionary) -> void:
	var nodes := view.get_tree().get_nodes_in_group(&"roof_occluders")
	_sync_roofs(nodes)
	var validation_started := Time.get_ticks_usec()
	_validate_roofs()
	_roof_validation_usec = Time.get_ticks_usec()-validation_started
	_validation_usec += _roof_validation_usec
	_visited_roofs = 0
	var previous := -1
	for slot: int in (_all_slots(nodes.size()) if _uncached else _gather(_roof_index,area)):
		if slot == previous:
			continue
		previous = slot
		var roof := _roof_nodes[slot]
		if roof == null:
			continue
		var entry: Dictionary = _roof_cache.get(roof.get_instance_id(),_NO_ENTRY)
		if entry.is_empty() or (not _uncached and not (entry.reach as Rect2).intersects(area)):
			continue
		var poly := _plane_nodes[slot]
		if poly == null:
			continue
		_visited_roofs += 1
		if roof.is_queued_for_deletion() or not roof.is_visible_in_tree() or roof._inside_count > 0:
			continue
		if poly.get_world_2d() != world or poly.get_canvas() != canvas or not poly.is_visible_in_tree() or roof.footprint_outline_px.size() < 3:
			continue
		var strength := _memo_alpha(poly,alpha_memo)
		if strength <= 0.0:
			continue
		for piece: Dictionary in _roof_geometry(roof,poly,entry):
			if not (piece.bounds as Rect2).intersects(area):
				continue
			_records.append({"kind":0,"points":piece.points,"front_y":piece.front_y,"strength":strength,"bounds":piece.bounds})

func _collect_solid_faces(view: Node, area: Rect2, world: World2D, canvas: RID, alpha_memo: Dictionary = {}) -> void:
	# Only explicitly registered, genuinely opaque masonry is triangulated.
	# Door recesses, thresholds and virtual roof helper masks stay separate.
	var nodes := view.get_tree().get_nodes_in_group(&"foreground_solid_occluders")
	_sync_faces(nodes)
	var validation_started := Time.get_ticks_usec()
	_validate_faces()
	_validation_usec += Time.get_ticks_usec()-validation_started
	_visited_faces = 0
	var previous := -1
	for slot: int in (_all_slots(nodes.size()) if _uncached else _gather(_face_index,area)):
		if slot == previous:
			continue
		previous = slot
		var face := _face_nodes[slot]
		if face == null:
			continue
		var entry: Dictionary = _solid_cache.get(face.get_instance_id(),_NO_ENTRY)
		if entry.is_empty() or (not _uncached and not (entry.reach as Rect2).intersects(area)):
			continue
		_visited_faces += 1
		if face.get_world_2d() != world or face.get_canvas() != canvas or face.is_queued_for_deletion() or not face.is_visible_in_tree() or face.polygon.size() < 3 or not face.has_meta(FOREGROUND.GROUND_CONTACT):
			continue
		var parent := face.get_parent() as CanvasItem
		if parent == null:
			continue
		var strength := _memo_alpha(face,alpha_memo)*face.color.a
		if strength <= 0.0:
			continue
		var ground: Vector2 = face.get_meta(FOREGROUND.GROUND_CONTACT)
		var front_y := (parent.get_global_transform()*ground).y
		if entry.front_y != front_y:
			var pieces: Array[Dictionary] = []
			_triangulate(entry.points,front_y,pieces)
			entry.front_y = front_y
			entry.pieces = pieces
		for piece: Dictionary in entry.pieces:
			if (piece.bounds as Rect2).intersects(area):
				_records.append({"kind":0,"points":piece.points,"front_y":front_y,"strength":strength,"bounds":piece.bounds})

## Membership changes (streamed chunks) index every new occluder at once and
## forget the removed ones; slot order is the group order.
func _sync_faces(nodes: Array[Node]) -> void:
	if nodes == _face_index.nodes:
		return
	_index_resyncs += 1
	var slot: Dictionary = {}
	_face_nodes.resize(nodes.size())
	_face_xfs.resize(nodes.size())
	_face_polys.resize(nodes.size())
	for at in nodes.size():
		var face := nodes[at] as Polygon2D
		_face_nodes[at] = face
		if face == null:
			_face_xfs[at] = Transform2D()
			_face_polys[at] = PackedVector2Array()
			continue
		var key := face.get_instance_id()
		slot[key] = at
		var entry: Dictionary = _solid_cache.get(key,_NO_ENTRY)
		if entry.is_empty():
			entry = _face_entry(face)
		_face_xfs[at] = entry.xf
		_face_polys[at] = entry.polygon
	for key: Variant in _solid_cache.keys():
		if not slot.has(key):
			_unbucket(_face_index,int(key),_solid_cache[key])
			_solid_cache.erase(key)
	_face_index.slot = slot
	_face_index.nodes = nodes

func _sync_roofs(nodes: Array[Node]) -> void:
	if nodes == _roof_index.nodes:
		return
	_index_resyncs += 1
	var slot: Dictionary = {}
	_roof_nodes.resize(nodes.size())
	for at in nodes.size():
		var roof := nodes[at] as RoofOverlay
		_roof_nodes[at] = roof
		if roof != null:
			slot[roof.get_instance_id()] = at
	for key: Variant in _roof_cache.keys():
		if not slot.has(key):
			_unbucket(_roof_index,int(key),_roof_cache[key])
			_roof_cache.erase(key)
	_roof_index.slot = slot
	_roof_index.nodes = nodes
	_plane_nodes.resize(nodes.size())
	_plane_xfs.resize(nodes.size())
	_plane_polys.resize(nodes.size())
	for at in nodes.size():
		_plane_nodes[at] = null
		var roof := _roof_nodes[at]
		if roof == null:
			continue
		var key := roof.get_instance_id()
		var entry: Dictionary = _roof_cache.get(key,_NO_ENTRY)
		if entry.is_empty():
			var poly := roof.get_node_or_null(_ROOF_POLY) as Polygon2D
			if poly == null:
				# A roof plane added later is a structural edit of this roof.
				if not _uncached:
					_watch_roof(roof)
				continue
			entry = _roof_entry(roof,poly,true)
		elif not is_instance_valid(entry.poly):
			_dirty_roofs[key] = true
			continue
		_set_plane(at,entry)
	_forms_stale = true

func _set_plane(at: int, entry: Dictionary) -> void:
	_plane_nodes[at] = entry.poly
	_plane_xfs[at] = entry.poly_xf
	_plane_polys[at] = entry.polygon

## The flat roof-form inputs, in roof slot order, from the roof entries.
func _rebuild_forms() -> void:
	_form_nodes.clear()
	_form_xfs.clear()
	_form_polys.clear()
	_form_slots.clear()
	for at in _roof_nodes.size():
		var roof := _roof_nodes[at]
		if roof == null:
			continue
		var entry: Dictionary = _roof_cache.get(roof.get_instance_id(),_NO_ENTRY)
		if entry.is_empty():
			continue
		var forms: Array = entry.forms
		var form_xfs: Array[Transform2D] = entry.form_xfs
		var form_polys: Array[PackedVector2Array] = entry.form_polys
		for index in forms.size():
			_form_nodes.append(forms[index])
			_form_xfs.append(form_xfs[index])
			_form_polys.append(form_polys[index])
			_form_slots.append(at)
	_forms_stale = false

## Exact reach inputs of every loaded face, every refresh.
func _validate_faces() -> void:
	_renewed_faces = 0
	if _uncached:
		return
	var xfs := _face_xfs
	var polys := _face_polys
	var at := -1
	for face: Polygon2D in _face_nodes:
		at += 1
		if face == null:
			continue
		if face.global_transform != xfs[at] or face.polygon != polys[at]:
			var entry := _face_entry(face)
			xfs[at] = entry.xf
			polys[at] = entry.polygon
			_renewed_faces += 1

## Exact reach inputs of every loaded roof plane and roof form, every refresh,
## after the structural edits signalled since the last one. A plane or form
## is never freed unsignalled (its watched parent reports the exit); the
## validity tests are a cheap safeguard before each typed read.
func _validate_roofs() -> void:
	_renewed_roofs = 0
	if _uncached:
		return
	var renew: Dictionary = {}
	for key: Variant in _dirty_roofs:
		var at: int = (_roof_index.slot as Dictionary).get(key,-1)
		if at >= 0:
			renew[at] = true
	_dirty_roofs.clear()
	if not renew.is_empty():
		_renew_roofs(renew)
		renew.clear()
	if _forms_stale:
		_rebuild_forms()
	var planes := _plane_nodes
	var plane_xfs := _plane_xfs
	var plane_polys := _plane_polys
	for at in planes.size():
		if not is_instance_valid(planes[at]):
			# A planeless roof, or (never expected) a plane freed unsignalled.
			var roof := _roof_nodes[at]
			if roof != null and _roof_cache.has(roof.get_instance_id()):
				renew[at] = true
			continue
		var plane := planes[at]
		if plane.global_transform != plane_xfs[at] or plane.polygon != plane_polys[at]:
			renew[at] = false
	var forms := _form_nodes
	var form_xfs := _form_xfs
	var form_polys := _form_polys
	for index in forms.size():
		if not is_instance_valid(forms[index]):
			renew[_form_slots[index]] = true
			continue
		var form := forms[index]
		if form.global_transform != form_xfs[index] or form.polygon != form_polys[index]:
			renew[_form_slots[index]] = renew.get(_form_slots[index],false)
	if not renew.is_empty():
		_renew_roofs(renew)
		_rebuild_forms()

## Rebuilds the entries of roof slots (slot -> whether to re-find forms).
func _renew_roofs(renew: Dictionary) -> void:
	for at: int in renew:
		var roof := _roof_nodes[at]
		if roof == null:
			continue
		_renewed_roofs += 1
		_forms_stale = true
		var key := roof.get_instance_id()
		var poly := roof.get_node_or_null(_ROOF_POLY) as Polygon2D
		if poly == null:
			var entry: Dictionary = _roof_cache.get(key,_NO_ENTRY)
			if not entry.is_empty():
				_unbucket(_roof_index,key,entry)
				_roof_cache.erase(key)
			_plane_nodes[at] = null
			continue
		_set_plane(at,_roof_entry(roof,poly,bool(renew[at])))

func _reset_index() -> void:
	_roof_cache.clear()
	_solid_cache.clear()
	_roof_index = {"nodes":[],"slot":{},"buckets":{}}
	_face_index = {"nodes":[],"slot":{},"buckets":{}}
	_roof_nodes.clear()
	_plane_nodes.clear()
	_plane_xfs.clear()
	_plane_polys.clear()
	_form_nodes.clear()
	_form_xfs.clear()
	_form_polys.clear()
	_form_slots.clear()
	_forms_stale = true
	_dirty_roofs.clear()
	_face_nodes.clear()
	_face_xfs.clear()
	_face_polys.clear()

func _on_roof_subtree_changed(node: Node) -> void:
	# A node entered or left a watched roof subtree: the first indexed roof
	# above it re-finds its plane and forms on the next refresh.
	var at := node.get_parent()
	while at != null:
		if at is RoofOverlay:
			var key := at.get_instance_id()
			if (_roof_index.slot as Dictionary).has(key):
				_dirty_roofs[key] = true
				_structure_events += 1
			return
		at = at.get_parent()

func _watch_roof(roof: RoofOverlay) -> void:
	var watcher := _on_roof_subtree_changed
	for node: Node in [roof]+roof.find_children("*","",true,false):
		# A structural rescan or index reset must retain one subscription,
		# rather than acquiring another reference to the existing connection.
		if not node.child_entered_tree.is_connected(watcher):
			node.child_entered_tree.connect(watcher)
		if not node.child_exiting_tree.is_connected(watcher):
			node.child_exiting_tree.connect(watcher)

## Group slots of the occluders indexed in the buckets `area` touches, sorted
## into group order (the order the records were always collected in); an
## occluder spanning several buckets repeats, and visitors skip the repeats.
func _gather(index: Dictionary, area: Rect2) -> PackedInt32Array:
	var low := Vector2i((area.position/BUCKET_PX).floor())
	var high := Vector2i((area.end/BUCKET_PX).floor())
	var buckets: Dictionary = index.buckets
	var slot: Dictionary = index.slot
	var order := PackedInt32Array()
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var bucket: Dictionary = buckets.get(Vector2i(x,y),_NO_ENTRY)
			for key: int in bucket:
				order.append(slot[key])
	order.sort()
	return order

## Every group slot in group order: the uncached control visits them all.
func _all_slots(count: int) -> PackedInt32Array:
	var order := PackedInt32Array()
	order.resize(count)
	for at in count:
		order[at] = at
	return order

func _bucket(index: Dictionary, key: int, entry: Dictionary) -> void:
	var reach: Rect2 = entry.reach
	var low := Vector2i((reach.position/BUCKET_PX).floor())
	var high := Vector2i((reach.end/BUCKET_PX).floor())
	var cells: Array[Vector2i] = []
	var buckets: Dictionary = index.buckets
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			if not buckets.has(cell):
				buckets[cell] = {}
			(buckets[cell] as Dictionary)[key] = true
			cells.append(cell)
	entry.cells = cells

func _unbucket(index: Dictionary, key: int, entry: Dictionary) -> void:
	var buckets: Dictionary = index.buckets
	for cell: Vector2i in entry.get("cells",[]):
		var bucket: Dictionary = buckets.get(cell,_NO_ENTRY)
		if bucket.is_empty():
			continue
		bucket.erase(key)
		if bucket.is_empty():
			buckets.erase(cell)

## (Re)builds one face's entry and its buckets from its current inputs.
func _face_entry(face: Polygon2D) -> Dictionary:
	var key := face.get_instance_id()
	var previous: Dictionary = _solid_cache.get(key,_NO_ENTRY)
	if not previous.is_empty():
		_unbucket(_face_index,key,previous)
	var xf := face.global_transform
	var polygon := face.polygon
	var points := xf*polygon
	var entry := {"xf":xf,"polygon":polygon,"points":points,"reach":_bounds_of(points),"front_y":NAN,"pieces":[],"cells":[]}
	_solid_cache[key] = entry
	_bucket(_face_index,key,entry)
	return entry

## (Re)builds one roof's reach from its current plane and roof forms: every
## form is in the reach whether or not it is visible now, so a form shown
## later can never fall outside it. `rescan` re-finds the forms at any depth
## (new roof, structural edit, replaced plane or freed form); otherwise the
## known forms are kept. Pieces stay keyed by their own fingerprint.
func _roof_entry(roof: RoofOverlay, poly: Polygon2D, rescan: bool) -> Dictionary:
	var key := roof.get_instance_id()
	var previous: Dictionary = _roof_cache.get(key,_NO_ENTRY)
	if not previous.is_empty():
		_unbucket(_roof_index,key,previous)
	if not rescan and not previous.is_empty():
		for form: Variant in previous.forms:
			if not is_instance_valid(form) or not (form as Node).is_inside_tree():
				rescan = true
				break
	var forms: Array = _roof_forms(poly) if rescan or previous.is_empty() else previous.forms
	if not _uncached and (previous.is_empty() or rescan):
		_watch_roof(roof)
	var poly_xf := poly.global_transform
	var polygon := poly.polygon
	var reach := _bounds_of(poly_xf*polygon)
	var form_xfs: Array[Transform2D] = []
	var form_polys: Array[PackedVector2Array] = []
	for form: Polygon2D in forms:
		var form_xf := form.global_transform
		var form_polygon := form.polygon
		form_xfs.append(form_xf)
		form_polys.append(form_polygon)
		if form_polygon.size() > 0:
			reach = reach.merge(_bounds_of(form_xf*form_polygon))
	var entry := {"poly":poly,"poly_xf":poly_xf,"polygon":polygon,"forms":forms,"form_xfs":form_xfs,"form_polys":form_polys,
		"reach":reach,"fingerprint":previous.get("fingerprint",0),"pieces":previous.get("pieces",[]),"cells":[]}
	_roof_cache[key] = entry
	_bucket(_roof_index,key,entry)
	return entry

static func _roof_forms(poly: Polygon2D) -> Array:
	var forms: Array = []
	for node: Node in poly.find_children("*","Polygon2D",true,false):
		if node.has_meta(&"city_roof_form"):
			forms.append(node)
	return forms

func _bounds_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds

func bind_material(material: ShaderMaterial) -> void:
	if material == null:
		return
	_materials[material.get_instance_id()] = weakref(material)
	_bind(material)

func _bind(material: ShaderMaterial) -> void:
	_material_binds += 1
	material.set_shader_parameter("world_cover_enabled",not _records.is_empty())
	if _grid == null:
		return
	material.set_shader_parameter("world_cover_grid",_grid)
	material.set_shader_parameter("world_cover_indices",_indices)
	material.set_shader_parameter("world_cover_data",_data)
	material.set_shader_parameter("world_cover_alpha",_alpha)
	material.set_shader_parameter("world_cover_origin",_origin)
	material.set_shader_parameter("world_cover_grid_size",_grid_size)
	material.set_shader_parameter("world_cover_cell_px",CELL_PX)
	material.set_shader_parameter("world_cover_index_width",BUFFER_WIDTH)
	material.set_shader_parameter("world_cover_data_width",BUFFER_WIDTH)
	material.set_shader_parameter("world_cover_alpha_size",Vector2(_alpha_size))

func _prepare_alpha(textures: Array[Texture2D]) -> void:
	# Keep stable slots for cached live resources across view/stream fringes.
	# Source assets are immutable; only genuinely new/dead resources rebuild.
	var keys: Array[int] = []
	for key: int in _alpha_keys:
		if _source_cache.has(key) and is_instance_valid((_source_cache[key].owner as WeakRef).get_ref()):
			keys.append(key)
	var size := Vector2i.ONE
	for texture: Texture2D in textures:
		var key := texture.get_instance_id()
		if not keys.has(key):
			keys.append(key)
		if not _source_cache.has(key):
			var image := texture.get_image()
			_source_reads += 1
			if image == null or image.is_empty():
				push_error("Foreground cover could not read its original shared texture: " + texture.resource_path)
				continue
			if image.is_compressed():
				image.decompress()
			image.clear_mipmaps()
			image.convert(Image.FORMAT_RGBA8)
			_source_cache[key] = {"owner":weakref(texture),"image":image}
	for key: int in keys:
		var entry: Dictionary = _source_cache.get(key,{})
		if entry.is_empty():
			continue
		var image: Image = entry.image
		size.x = maxi(size.x,image.get_width())
		size.y = maxi(size.y,image.get_height())
	for key: Variant in _source_cache.keys():
		if not is_instance_valid((_source_cache[key].owner as WeakRef).get_ref()):
			_source_cache.erase(key)
	if _alpha != null and keys == _alpha_keys and size == _alpha_size:
		return
	# Padding preserves original source pixels, including cropped AtlasTexture
	# images. No rescaling, thresholding or per-frame alpha decoding is used.
	var layers: Array[Image] = []
	for key: int in keys:
		var layer := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		layer.fill(Color.TRANSPARENT)
		if _source_cache.has(key):
			var image: Image = _source_cache[key].image
			layer.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i.ZERO)
		layers.append(layer)
	if layers.is_empty():
		var empty := Image.create(1,1,false,Image.FORMAT_RGBA8)
		empty.fill(Color.TRANSPARENT)
		layers.append(empty)
	var array := Texture2DArray.new()
	if array.create_from_images(layers) != OK:
		push_error("Could not build shared foreground coverage texture array")
		return
	_alpha = array
	_alpha_keys = keys
	_alpha_size = size
	_alpha_uploads += 1
	_alpha_upload_bytes += size.x*size.y*layers.size()*4

func _upload_snapshot() -> void:
	var data := PackedFloat32Array()
	data.resize(maxi(1,ceili(float(_records.size()*4)/BUFFER_WIDTH))*BUFFER_WIDTH*4)
	var cells: Array[PackedInt32Array] = []
	cells.resize(_grid_size.x*_grid_size.y)
	for index in _records.size():
		var record := _records[index]
		var at := index*16
		data[at] = record.kind
		data[at+1] = record.strength
		data[at+2] = record.front_y
		if int(record.kind) == 0:
			var points: PackedVector2Array = record.points
			data[at+4] = points[0].x
			data[at+5] = points[0].y
			data[at+6] = points[1].x
			data[at+7] = points[1].y
			data[at+8] = points[2].x
			data[at+9] = points[2].y
		else:
			var mapping: Transform2D = record.world_to_uv
			var source: Rect2 = record.source_rect
			data[at+3] = record.layer
			data[at+4] = mapping.x.x
			data[at+5] = mapping.y.x
			data[at+6] = mapping.origin.x
			data[at+8] = mapping.x.y
			data[at+9] = mapping.y.y
			data[at+10] = mapping.origin.y
			data[at+12] = source.position.x
			data[at+13] = source.position.y
			data[at+14] = source.size.x
			data[at+15] = source.size.y
		var bounds: Rect2 = record.bounds
		var low := Vector2i(((bounds.position-_origin)/CELL_PX).floor()).clamp(Vector2i.ZERO,_grid_size-Vector2i.ONE)
		var high := Vector2i(((bounds.end-_origin)/CELL_PX).floor()).clamp(Vector2i.ZERO,_grid_size-Vector2i.ONE)
		for y in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				cells[y*_grid_size.x+x].append(index)
	var headers := PackedFloat32Array()
	headers.resize(_grid_size.x*_grid_size.y*4)
	var ids := PackedFloat32Array()
	_max_candidates = 0
	for index in cells.size():
		headers[index*4] = ids.size()
		headers[index*4+1] = cells[index].size()
		_max_candidates = maxi(_max_candidates,cells[index].size())
		for id: int in cells[index]:
			ids.append(float(id))
	_index_count = ids.size()
	ids.resize(maxi(1,ceili(float(ids.size())/(BUFFER_WIDTH*4)))*BUFFER_WIDTH*4)
	_grid = _upload(_grid,Image.create_from_data(_grid_size.x,_grid_size.y,false,Image.FORMAT_RGBAF,headers.to_byte_array()))
	# Both buffers were padded to whole rows above, so the divisions are exact.
	@warning_ignore("integer_division")
	_indices = _upload(_indices,Image.create_from_data(BUFFER_WIDTH,ids.size()/(BUFFER_WIDTH*4),false,Image.FORMAT_RGBAF,ids.to_byte_array()))
	@warning_ignore("integer_division")
	_data = _upload(_data,Image.create_from_data(BUFFER_WIDTH,data.size()/(BUFFER_WIDTH*4),false,Image.FORMAT_RGBAF,data.to_byte_array()))

func _upload(existing: ImageTexture, image: Image) -> ImageTexture:
	# Requested CPU payload/calls, not a GPU transfer/stall timer. All three
	# snapshot images use RGBAF (four32-bit channels).
	_data_uploads += 1
	_data_upload_bytes += image.get_width()*image.get_height()*16
	if existing == null:
		return ImageTexture.create_from_image(image)
	if Vector2i(existing.get_size()) == image.get_size():
		existing.update(image)
	else:
		existing.set_image(image)
	return existing

func _roof_geometry(roof: RoofOverlay, poly: Polygon2D, entry: Dictionary) -> Array[Dictionary]:
	# The roof's forms are found when its entry is built and again after any
	# structural edit below the roof; validation has already checked them this
	# refresh. Defensively, a form freed since is found again and the entry
	# is rebuilt (with aligned inputs) on the next refresh.
	for form: Variant in entry.forms:
		if not is_instance_valid(form) or not (form as Node).is_inside_tree():
			entry.forms = _roof_forms(poly)
			_dirty_roofs[roof.get_instance_id()] = true
			break
	var forms: Array[Polygon2D] = []
	var signature: Array = [roof.global_transform,roof.footprint_outline_px,poly.global_transform,poly.polygon]
	for child: Polygon2D in entry.forms:
		forms.append(child)
		signature.append([child.global_transform,child.polygon,child.is_visible_in_tree(),child.get_meta(&"city_roof_lift",0.0),child.get_meta(&"roof_occlusion_full_form",false)])
	var fingerprint := hash(signature)
	if int(entry.fingerprint) == fingerprint and not (entry.pieces as Array).is_empty():
		return entry.pieces
	var pieces: Array[Dictionary] = []
	var spans := _footprint_spans(roof)
	var projection := poly.global_position-roof.global_position
	_clip_roof_piece(poly,spans,projection,pieces)
	var front_y := -INF
	for point: Vector2 in roof.footprint_outline_px:
		front_y = maxf(front_y,roof.to_global(point).y)
	for child: Polygon2D in forms:
		if not child.is_visible_in_tree():
			continue
		if bool(child.get_meta(&"roof_occlusion_full_form",false)):
			var points := PackedVector2Array()
			for point: Vector2 in child.polygon:
				points.append(child.to_global(point))
			_triangulate(points,front_y,pieces)
		else:
			var shift := projection+poly.global_transform.basis_xform(Vector2(0,-float(child.get_meta(&"city_roof_lift",0.0))))
			_clip_roof_piece(child,spans,shift,pieces)
	# A form reshaped in view widens the reach, so it stays a superset.
	var reach: Rect2 = entry.reach
	for piece: Dictionary in pieces:
		reach = reach.merge(piece.bounds)
	if reach != entry.reach:
		var key := roof.get_instance_id()
		_unbucket(_roof_index,key,entry)
		entry.reach = reach
		_bucket(_roof_index,key,entry)
	entry.fingerprint = fingerprint
	entry.pieces = pieces
	return pieces

func _footprint_spans(roof: RoofOverlay) -> Array[Rect2]:
	var points := PackedVector2Array()
	var xs: Array[float] = []
	for local: Vector2 in roof.footprint_outline_px:
		var point := roof.to_global(local)
		points.append(point)
		if not xs.has(point.x):
			xs.append(point.x)
	xs.sort()
	var spans: Array[Rect2] = []
	for index in range(xs.size()-1):
		var x := (xs[index]+xs[index+1])*0.5
		var ys: Array[float] = []
		for edge in points.size():
			var a := points[edge]
			var b := points[(edge+1)%points.size()]
			if is_equal_approx(a.x,b.x) or x < minf(a.x,b.x) or x >= maxf(a.x,b.x):
				continue
			ys.append(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
		ys.sort()
		for pair in range(0,ys.size()-1,2):
			spans.append(Rect2(xs[index],ys[pair],xs[index+1]-xs[index],ys[pair+1]-ys[pair]))
	return spans

func _clip_roof_piece(poly: Polygon2D, spans: Array[Rect2], shift: Vector2, pieces: Array[Dictionary]) -> void:
	var points := PackedVector2Array()
	for point: Vector2 in poly.polygon:
		points.append(poly.to_global(point))
	for span: Rect2 in spans:
		var area := Rect2(span.position+shift,span.size)
		var rectangle := PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(points,rectangle):
			_triangulate(part,span.end.y,pieces)

func _triangulate(points: PackedVector2Array, front_y: float, pieces: Array[Dictionary]) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	for index in range(0,indices.size(),3):
		var triangle := PackedVector2Array([points[indices[index]],points[indices[index+1]],points[indices[index+2]]])
		var bounds := Rect2(triangle[0],Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
		pieces.append({"points":triangle,"front_y":front_y,"bounds":bounds})

## _effective_alpha with each ancestor chain product computed once per
## refresh: sibling faces of one facade share every ancestor above them.
func _memo_alpha(item: CanvasItem, memo: Dictionary) -> float:
	var alpha := item.self_modulate.a*item.modulate.a
	if not item.top_level:
		var parent := item.get_parent() as CanvasItem
		if parent != null:
			alpha *= _chain_alpha(parent,memo)
	return clampf(alpha,0.0,1.0)

func _chain_alpha(item: CanvasItem, memo: Dictionary) -> float:
	var key := item.get_instance_id()
	var known: Variant = memo.get(key)
	if known != null:
		return known
	var alpha := item.modulate.a
	if not item.top_level:
		var parent := item.get_parent() as CanvasItem
		if parent != null:
			alpha *= _chain_alpha(parent,memo)
	memo[key] = alpha
	return alpha

func _effective_alpha(item: CanvasItem) -> float:
	var alpha := item.self_modulate.a
	var current: CanvasItem = item
	while current != null:
		alpha *= current.modulate.a
		if current.top_level:
			break
		current = current.get_parent() as CanvasItem
	return clampf(alpha,0.0,1.0)

## Diagnostic probe only. Rendering queries the same records on the GPU;
## no per-actor/per-frame CPU texture sampling occurs in production consumers.
func strength_at(point: Vector2, feet_y: float) -> float:
	var result := 0.0
	for record: Dictionary in _records:
		if feet_y >= float(record.front_y) or not (record.bounds as Rect2).has_point(point):
			continue
		if int(record.kind) == 0:
			if Geometry2D.is_point_in_polygon(point,record.points):
				result = maxf(result,float(record.strength))
		else:
			var uv: Vector2 = (record.world_to_uv as Transform2D)*point
			if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1:
				continue
			var region: Rect2 = record.source_rect
			var image: Image = _source_cache[(record.texture as Texture2D).get_instance_id()].image
			var source := Vector2i(region.position+uv*region.size)
			if Rect2i(Vector2i.ZERO,image.get_size()).has_point(source):
				result = maxf(result,image.get_pixelv(source).a*float(record.strength))
	return result

func snapshot_stats() -> Dictionary:
	return {"generation":_generation,"primitive_count":_records.size(),"grid_cells":_grid_size.x*_grid_size.y,"index_count":_index_count,"max_candidates":_max_candidates,"foreground_sources":_alpha_keys.size(),"source_reads":_source_reads,"materials":_materials.size(),"cell_px":CELL_PX,"refresh_usec":_refresh_usec,"peak_refresh_usec":_peak_refresh_usec,"peak_primitives":_peak_primitives,"peak_candidates":_peak_candidates,
		"snapshot_builds":_snapshot_builds,"snapshot_reuses":_snapshot_reuses,"data_uploads":_data_uploads,"data_upload_bytes":_data_upload_bytes,
		"alpha_uploads":_alpha_uploads,"alpha_upload_bytes":_alpha_upload_bytes,"material_binds":_material_binds,
		"collection_usec":_collection_usec,"comparison_usec":_comparison_usec,"snapshot_usec":_snapshot_usec,"binding_usec":_binding_usec,
		"roof_usec":_roof_usec,"solid_usec":_solid_usec,"sprite_usec":_sprite_usec,"visited_roofs":_visited_roofs,"visited_faces":_visited_faces,
		"index_resyncs":_index_resyncs,"indexed_roofs":_roof_cache.size(),"indexed_faces":_solid_cache.size(),"roof_buckets":(_roof_index.buckets as Dictionary).size(),"face_buckets":(_face_index.buckets as Dictionary).size(),
		"validation_usec":_validation_usec,"roof_validation_usec":_roof_validation_usec,"indexed_forms":_form_nodes.size(),"renewed_roofs":_renewed_roofs,"renewed_faces":_renewed_faces,"structure_events":_structure_events,"index_disabled":_uncached,
		"force_uploads":bool(get_meta(FORCE_UPLOAD_META,false))}

func _exit_tree() -> void:
	_materials.clear()
	_source_cache.clear()
	_reset_index()
	_snapshot_semantics.clear()
	_snapshot_alpha = null
	_alpha = null
	_grid = null
	_indices = null
	_data = null
