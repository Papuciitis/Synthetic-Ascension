extends Control
class_name AscensionTreeView
## Draws the radial advancement tree as an arcane astrolabe and reports hover
## and clicks.
##
## Layers, back to front: the Sky (one shader: nebula, stars, the orbits, the
## rete and the limb with its degree scale, ui/shaders/ascension_sky), the
## Lattice of edges, a live additive Glow (the breathing of what can be
## bought, the light flowing outward along owned edges, a purchase's fuse),
## the Nodes (one instanced draw of signed-distance shapes,
## ui/shaders/ascension_nodes), the Marks (labels, rank pips, Core stars), an
## Overlay (the territory names on the limb, and the hovered or selected
## node's edges, rim and name) and live additive Sparks (reticles, dials,
## ripples, bursts).
##
## Keeping it affordable with hundreds of nodes and edges: Lattice, Nodes and
## Marks redraw only when the zoom, the states or the opening change; a pan
## just slides them. Hover and selection redraw only the Overlay. The live
## layers draw only the few things that move.
##
## States: owned gold with a lit lens, buyable ember and breathing, reachable
## but unaffordable dim amber, locked bronze in its territory's tint, sealed by
## a conflict dull red; the equipped Q / V / Reaction / Keystones / Axioms
## carry a turning dial. Zoom with the wheel about the cursor, pan by dragging.
## Nodes are not scene children. Motion runs on real time (the screen can open
## while the game is paused or slowed) and honours reduced motion.

signal node_hovered(id: String)
signal node_clicked(id: String, button: int)
## A deliberate purchase gesture (double-click). The screen confirms with
## the exact cost and rechecks eligibility before buying.
signal node_activated(id: String)

const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")
const ArcaneParticles := preload("res://ui/widgets/ArcaneParticles.gd")
const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const SKY_SHADER := preload("res://ui/shaders/ascension_sky.gdshader")
const NODE_SHADER := preload("res://ui/shaders/ascension_nodes.gdshader")
const NOISE := preload("res://assets/ui/menu/cloud_noise.png")

const INK := Color(0.045, 0.038, 0.032, 1.0)
const GOLD := Color(0.86, 0.64, 0.36, 1.0)
const GOLD_DIM := Color(0.62, 0.47, 0.30, 1.0)
const GOLD_BRIGHT := Color(0.99, 0.84, 0.58, 1.0)
const PARCHMENT := Color(0.91, 0.86, 0.77, 1.0)
const EMBER := Color(1.0, 0.62, 0.30, 1.0)
const BRONZE := Color(0.45, 0.37, 0.28, 1.0)
const DANGER := Color(0.86, 0.32, 0.24, 1.0)
const CORE_TINT: Dictionary = {"melee": Color(0.82, 0.38, 0.27), "ranged": Color(0.42, 0.6, 0.88), "magic": Color(0.64, 0.46, 0.86)}
const LABEL_KINDS: Array[String] = ["active", "keystone", "axiom", "catastrophe", "evolution", "revelation", "fusion", "union", "gate", "ascendant", "core", "fork"]
## Below this zoom the view is an OVERVIEW: labels collapse to what the
## player is looking at and edges to what is theirs or in reach (playtest
## finding: fixed-width labels overlapped into noise at fit zoom).
const OVERVIEW_ZOOM := 0.55

const ST_LOCKED := 0
const ST_REACHABLE := 1
const ST_BUYABLE := 2
const ST_OWNED := 3
const ST_SEALED := 4
const STATE_NAMES: Array[String] = ["locked", "reachable", "buyable", "owned", "sealed"]
## Height kept clear of the tree by fit(): the legend band and the hint band.
const CHROME_BANDS := 96.0

const SH_CIRCLE := 0
const SH_HEX := 1
const SH_TRIANGLE := 2
const SH_OCTAGON := 3
const SH_DIAMOND := 4
const SH_SQUARE := 5
## The code bits ui/shaders/ascension_nodes reads.
const BIT_LENS := 8
const BIT_PIP := 16
const BIT_SLASH := 32
const BIT_EQUIPPED := 64
const BIT_OUTER := 128
const BIT_HALO := 256
const QUAD_WIDE := 2.6
const QUAD_TIGHT := 1.35

## The limb (the fixed degree scale) sits just outside the outermost orbit,
## a little behind the tree: it follows a share of the pan.
const LIMB_GAP := 36.0
const LIMB_WIDTH := 30.0
const LIMB_PARALLAX := 0.94
## Light flowing outward along owned edges: world units per second, the gap
## between waves, and the comet's tail.
const FLOW_SPEED := 120.0
const FLOW_PERIOD := 400.0
const FLOW_TAIL := 44.0
const BREATH_SECONDS := 2.8
const INTRO_STILL_SECONDS := 0.35
const LABEL_CELL := 64.0

var db: AscensionTreeDB = null
var layout: AscensionTreeLayout = null
var ledger: AscensionLedger = null
var followers: int = 0
var zoom: float = 0.55:
	set(value):
		if zoom == value:
			return
		zoom = value
		_view_dirty = true
var offset: Vector2 = Vector2.ZERO:
	set(value):
		if offset == value:
			return
		offset = value
		_view_dirty = true
var hovered: String = "":
	set(value):
		if hovered == value:
			return
		hovered = value
		_hover_since = _now()
		_overlay_dirty = true
var selected: String = "":
	set(value):
		if selected == value:
			return
		selected = value
		_select_since = _now()
		_overlay_dirty = true
## Screen px on the right that the side panel covers; the tree centres in
## the rest.
var reserve_right: float = 0.0:
	set(value):
		if reserve_right == value:
			return
		reserve_right = value
		_view_dirty = true
## Screen px from the right edge that an opaque panel hides: the live layers
## and the overlay skip what lies under it.
var cover_right: float = 0.0
var _dragging: bool = false
var _drag_moved: float = 0.0
## Once the player zooms or pans, a resize no longer refits the view.
var _user_moved: bool = false
## After the opening unfurls the camera glides in: to the core while nothing
## has been bought, otherwise to the furthest of what is owned (the most
## important node on that outermost ring). Never once the player has moved
## the view; under reduced motion it simply cuts there.
const GLIDE_SECONDS := 1.5
const GLIDE_ZOOM_CORE := 1.9
const GLIDE_ZOOM_NODE := 2.1
## How much a kind counts when choosing where the glide ends, among owned
## nodes that are (nearly) the furthest out.
const GLIDE_WEIGHT: Dictionary = {
	"ascendant": 9, "union": 8, "fusion": 7, "revelation": 6, "evolution": 6,
	"keystone": 5, "axiom": 5, "catastrophe": 5, "active": 4, "gate": 3, "fork": 3,
}
var _fit_zoom: float = -1.0
var _glide_pending: bool = false
var _glide_active: bool = false
var _glide_from_zoom: float = 1.0
var _glide_to_zoom: float = 1.0
var _glide_from_offset: Vector2 = Vector2.ZERO
var _glide_to_offset: Vector2 = Vector2.ZERO
var _glide_started: float = 0.0
var _states: Dictionary = {}   # id -> "owned" | "buyable" | "reachable" | "locked" | "sealed"
var _font: Font = null
var _font_caps: Font = null
var _still: bool = false
var _t0_usec: int = 0
var _opened_at: float = 0.0
var _intro_done: bool = false
var _hover_since: float = 0.0
var _select_since: float = 0.0
var _view_dirty: bool = true
var _static_dirty: bool = true
var _overlay_dirty: bool = true
## Where the static layers were last drawn: a pan within reach slides them.
var _static_center: Vector2 = Vector2.ZERO
var _static_zoom: float = -1.0
var _static_size: Vector2 = Vector2.ZERO
## How the static layers sit now: moved by _static_pos, scaled by _static_k.
var _static_pos: Vector2 = Vector2.ZERO
var _static_k: float = 1.0
var _last_zoom: float = -1.0
var _zoom_changed_at: float = -10.0

var _sky: ColorRect = null
var _sky_mat: ShaderMaterial = null
var _lattice: Node2D = null
var _glow: Control = null
var _nodes: Node2D = null
var _marks: Node2D = null
var _overlay: Control = null
var _sparks: Control = null
var _multimesh: MultiMesh = null
var _buffer: PackedFloat32Array = PackedFloat32Array()
var _dot: Texture2D = null

# Per-node caches, built once from the db and layout.
var _ids: PackedStringArray = PackedStringArray()
var _index: Dictionary = {}
var _world: PackedVector2Array = PackedVector2Array()
var _radius: PackedFloat32Array = PackedFloat32Array()
var _shape: PackedInt32Array = PackedInt32Array()
var _kinds: PackedStringArray = PackedStringArray()
var _names: PackedStringArray = PackedStringArray()
var _tint: PackedColorArray = PackedColorArray()
var _max_rank: PackedInt32Array = PackedInt32Array()
var _reach_u: PackedFloat32Array = PackedFloat32Array()
var _big_label: PackedByteArray = PackedByteArray()
var _adjacent: Array = []   # node index -> PackedInt32Array of edge indices
# Edges.
var _edge_a: PackedInt32Array = PackedInt32Array()
var _edge_b: PackedInt32Array = PackedInt32Array()
var _edge_len: PackedFloat32Array = PackedFloat32Array()
var _edge_of: Dictionary = {}   # Vector2i(lo, hi) -> edge index
# Per-refresh state, and the look of each node's shown state.
var _state: PackedInt32Array = PackedInt32Array()
var _ranks: PackedInt32Array = PackedInt32Array()
var _equipped: PackedByteArray = PackedByteArray()
var _owned_edge: PackedByteArray = PackedByteArray()
var _path: PackedFloat32Array = PackedFloat32Array()
var _fill_col: PackedColorArray = PackedColorArray()
var _rim_col: PackedColorArray = PackedColorArray()
var _code: PackedFloat32Array = PackedFloat32Array()
var _buyable_list: PackedInt32Array = PackedInt32Array()
var _owned_list: PackedInt32Array = PackedInt32Array()
var _equipped_list: PackedInt32Array = PackedInt32Array()
var _flow_a: PackedInt32Array = PackedInt32Array()
var _flow_b: PackedInt32Array = PackedInt32Array()
var _flow_e: PackedInt32Array = PackedInt32Array()
var _cores_open: Dictionary = {}
var _has_baseline: bool = false
# Current screen positions, and the opening's per-node fade and scale.
var _screen: PackedVector2Array = PackedVector2Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _grow: PackedFloat32Array = PackedFloat32Array()
# Purchase moments: {i, t0, arrive, big, prev, parent, edge, fuse, sparks,
# quiet, revealed}; the edges still igniting; refunds fading.
var _bursts: Array = []
var _igniting: Dictionary = {}
var _fading: Array = []
var _reveal_pending: bool = false
var _glow_was_live: bool = true
var _sparks_were_live: bool = true
var _label_width: Dictionary = {}   # node index * 64 + font size -> px
var _label_spots: Dictionary = {}   # node index -> [Rect2 in static space, font size]
var _unit_shapes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_t0_usec = Time.get_ticks_usec()
	_font = ARCANE_THEME.get_font(&"font", &"ArcaneBody")
	_font_caps = ARCANE_THEME.get_font(&"font", &"ArcaneCaption")
	if _font == null:
		_font = ThemeDB.fallback_font
	if _font_caps == null:
		_font_caps = _font
	_dot = ArcaneParticles.soft_dot()
	_still = ArcaneMotion.reduced()
	_build_layers()
	_build_unit_shapes()
	resized.connect(_on_resized)
	mouse_exited.connect(func() -> void:
		if not _dragging and not hovered.is_empty():
			hovered = ""
			node_hovered.emit(""))
	_opened_at = _now()
	set_process(true)


func setup(tree: AscensionTreeDB, tree_layout: AscensionTreeLayout) -> void:
	db = tree
	layout = tree_layout
	_build_cache()
	fit()


## Plays the opening again from the core (the screen calls it on open).
func replay_opening() -> void:
	_still = ArcaneMotion.reduced()
	_opened_at = _now()
	_intro_done = false
	_view_dirty = true
	_glide_active = false
	_glide_pending = true


func fit() -> void:
	_user_moved = false
	_glide_active = false
	if layout == null:
		return
	# The legend row above and the controls hint below keep their bands clear.
	var avail := Vector2(maxf(size.x - reserve_right, 120.0), maxf(size.y - CHROME_BANDS, 120.0))
	var reach := maxf(maxf(layout.extent(), 100.0), _limb_inner() + LIMB_WIDTH + 44.0)
	zoom = clampf(minf(avail.x, avail.y) * 0.5 / reach, 0.2, 3.0)
	_fit_zoom = zoom
	offset = Vector2.ZERO
	_view_dirty = true


## Where the opening's glide ends: the core while nothing is bought, else the
## most important owned node on the outermost owned ring.
func _glide_target() -> Array:
	var best := -1
	var best_reach := 0.0
	if _state.size() == _ids.size():
		for i in range(_ids.size()):
			if _state[i] != ST_OWNED or _kinds[i] == "core" or _kinds[i] == "sink":
				continue
			best_reach = maxf(best_reach, _world[i].length())
		var best_score := -1
		for i in range(_ids.size()):
			if _state[i] != ST_OWNED or _kinds[i] == "core" or _kinds[i] == "sink":
				continue
			if _world[i].length() < best_reach * 0.92:
				continue
			var score := int(GLIDE_WEIGHT.get(_kinds[i], 1)) * 100000 + int(_world[i].length())
			if score > best_score:
				best_score = score
				best = i
	if best < 0:
		return [Vector2.ZERO, maxf(GLIDE_ZOOM_CORE, _fit_zoom)]
	return [_world[best], maxf(GLIDE_ZOOM_NODE, _fit_zoom)]


func _start_glide() -> void:
	_glide_pending = false
	# Only from the untouched opening view (a test or the player may have set
	# their own).
	if _user_moved or _fit_zoom <= 0.0 or not is_equal_approx(zoom, _fit_zoom) or offset != Vector2.ZERO:
		return
	var target: Array = _glide_target()
	var to_zoom: float = target[1]
	_glide_from_zoom = zoom
	_glide_to_zoom = to_zoom
	_glide_from_offset = offset
	_glide_to_offset = -(target[0] as Vector2) * to_zoom
	if _still:
		zoom = _glide_to_zoom
		offset = _glide_to_offset
		_user_moved = true
		return
	_glide_started = _now()
	_glide_active = true


func _step_glide(now: float) -> void:
	if not _glide_active:
		return
	if _user_moved:
		_glide_active = false
		return
	var k := clampf((now - _glide_started) / GLIDE_SECONDS, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	# Zoom eases in log space so the move feels even from far to near.
	zoom = exp(lerpf(log(_glide_from_zoom), log(_glide_to_zoom), e))
	var k_zoom := zoom / _glide_to_zoom
	offset = _glide_from_offset.lerp(_glide_to_offset, e) if is_equal_approx(_glide_from_zoom, _glide_to_zoom) else _glide_to_offset * k_zoom * e + _glide_from_offset * (1.0 - e)
	if k >= 1.0:
		_glide_active = false
		# The glided view is the player's now: a resize keeps it, Fit resets it.
		_user_moved = true


func refresh(run_ledger: AscensionLedger, wallet: int) -> void:
	ledger = run_ledger
	followers = wallet
	_states.clear()
	_static_dirty = true
	if ledger == null or db == null:
		return
	_still = ArcaneMotion.reduced()
	var count := _ids.size()
	var previous_state := _state.duplicate()
	var previous_rank := _ranks.duplicate()
	_state.resize(count)
	_ranks.resize(count)
	_equipped.resize(count)
	_buyable_list.clear()
	_owned_list.clear()
	_equipped_list.clear()
	for i in range(count):
		var id := _ids[i]
		var state_name := _state_of(id)
		_states[id] = state_name
		_state[i] = STATE_NAMES.find(state_name)
		_ranks[i] = ledger.rank(id)
		_equipped[i] = 1 if ledger.is_equipped(id) else 0
		if _state[i] == ST_BUYABLE:
			_buyable_list.append(i)
		if _ranks[i] > 0:
			_owned_list.append(i)
		if _equipped[i] == 1:
			_equipped_list.append(i)
	_cores_open.clear()
	for core in AscensionTreeDB.CORES:
		_cores_open[core] = ledger.has_core(core)
	_owned_edge.resize(_edge_a.size())
	for e in range(_edge_a.size()):
		_owned_edge[e] = 1 if (_ranks[_edge_a[e]] > 0 and _ranks[_edge_b[e]] > 0) else 0
	_compute_paths()
	if _has_baseline and previous_rank.size() == count:
		for i in range(count):
			if _ranks[i] > previous_rank[i]:
				_celebrate(i, int(previous_state[i]), previous_rank[i] == 0, previous_rank)
			elif _ranks[i] == 0 and previous_rank[i] > 0:
				_fading.append({"i": i, "t0": _now()})
	_has_baseline = true
	_restyle()
	_push_sky_static()


func _state_of(id: String) -> String:
	if ledger.owns(id) and db.kind(id) != "sink":
		return "owned"
	for other in db.conflicts(id):
		if ledger.owns(other):
			return "sealed"
	var verdict := ledger.can_buy(id, followers, "melee" if db.kind(id) == "gate" else "")
	if db.kind(id) == "gate" and not bool(verdict["ok"]):
		for core in AscensionTreeDB.CORES:
			if bool(ledger.can_buy(id, followers, core)["ok"]):
				verdict = {"ok": true}
				break
	if bool(verdict["ok"]):
		return "owned" if (db.kind(id) == "sink" and ledger.rank(id) > 0) else "buyable"
	var rich := ledger.can_buy(id, 1 << 30, "melee" if db.kind(id) == "gate" else "")
	if bool(rich["ok"]) or (db.kind(id) == "sink" and ledger.rank(id) > 0):
		return "reachable" if ledger.rank(id) == 0 else "owned"
	return "locked"


func state_of(id: String) -> String:
	return String(_states.get(id, "locked"))


func _now() -> float:
	return float(Time.get_ticks_usec() - _t0_usec) / 1000000.0


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _sky_mat == null:
		return
	var now := _now()
	_step_glide(now)
	if not _intro_done:
		_view_dirty = true
	if _view_dirty:
		_view_dirty = false
		_recompute_screen(now)
		_push_sky_transform(now)
		_overlay_dirty = true
		if zoom != _last_zoom:
			_last_zoom = zoom
			_zoom_changed_at = now
		# The static layers follow a pan or a zoom step by moving and scaling
		# what they last drew, while that still covers the view; a zoom is
		# laid out afresh once it settles.
		var k := zoom / _static_zoom if _static_zoom > 0.0 else 1.0
		var at := (_origin() + offset) - _static_center * k
		var covered := at.x - size.x * 0.8 * k <= 0.0 and at.x + size.x * 1.8 * k >= size.x \
				and at.y - size.y * 0.8 * k <= 0.0 and at.y + size.y * 1.8 * k >= size.y
		if not _intro_done or _static_zoom <= 0.0 or size != _static_size or k < 0.8 or k > 1.25 or not covered:
			_static_dirty = true
		else:
			_slide_static(at, k)
	if not _static_dirty and zoom != _static_zoom and now - _zoom_changed_at > 0.14:
		_static_dirty = true
	if _reveal_pending:
		_reveal_pending = false
		for burst in _bursts:
			if now < float(burst["arrive"]):
				_reveal_pending = true
			elif not bool(burst["revealed"]):
				burst["revealed"] = true
				_igniting.erase(int(burst["edge"]))
				_restyle()
	if _static_dirty:
		_static_dirty = false
		_static_center = _origin() + offset
		_static_zoom = zoom
		_static_size = size
		_slide_static(Vector2.ZERO, 1.0)
		_rebuild_nodes()
		_lattice.queue_redraw()
		_nodes.queue_redraw()
		_marks.queue_redraw()
		_overlay_dirty = true
	if _overlay_dirty:
		_overlay_dirty = false
		_overlay.queue_redraw()
	_sky_mat.set_shader_parameter(&"t", now)
	_prune(now)
	# The live layers redraw only while something on them moves (and once
	# more to clear what they last drew).
	var glowing := not (_buyable_list.is_empty() and _equipped_list.is_empty() and _flow_a.is_empty() and _bursts.is_empty() and _fading.is_empty())
	if glowing or _glow_was_live:
		_glow.queue_redraw()
	_glow_was_live = glowing
	var sparking := glowing or not hovered.is_empty() or not selected.is_empty()
	if sparking or _sparks_were_live:
		_sparks.queue_redraw()
	_sparks_were_live = sparking


func _slide_static(at: Vector2, k: float) -> void:
	_static_pos = at
	_static_k = k
	for layer in [_lattice, _nodes, _marks]:
		(layer as Node2D).position = at
		(layer as Node2D).scale = Vector2(k, k)


# ---------------------------------------------------------------- transforms

func _origin() -> Vector2:
	return Vector2((size.x - reserve_right) * 0.5, size.y * 0.5)


func world_to_screen(point: Vector2) -> Vector2:
	return _origin() + offset + point * zoom


func screen_to_world(point: Vector2) -> Vector2:
	return (point - _origin() - offset) / zoom


func _deco_center() -> Vector2:
	return _origin() + offset * (1.0 if _still else LIMB_PARALLAX)


func _limb_inner() -> float:
	return float(AscensionTreeLayout.RING_RADIUS[6]) + LIMB_GAP


func _on_resized() -> void:
	if not _user_moved:
		fit()
	_view_dirty = true


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if layout == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mouse.pressed:
				var factor := 1.12 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
				var before := screen_to_world(mouse.position)
				zoom = clampf(zoom * factor, 0.2, 3.0)
				var after := screen_to_world(mouse.position)
				offset += (after - before) * zoom
				_user_moved = true
				_hover_at(mouse.position)
			accept_event()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_RIGHT or mouse.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse.pressed:
				if mouse.double_click and mouse.button_index == MOUSE_BUTTON_LEFT:
					var target := layout.hit(screen_to_world(mouse.position), 6.0 / zoom)
					if not target.is_empty():
						selected = target
						node_activated.emit(target)
					accept_event()
					return
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 6.0:
					var id := layout.hit(screen_to_world(mouse.position), 6.0 / zoom)
					if not id.is_empty():
						selected = id
						node_clicked.emit(id, mouse.button_index)
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging and (motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
			offset += motion.relative
			_drag_moved += motion.relative.length()
			if _drag_moved >= 6.0:
				_user_moved = true
		_hover_at(motion.position)


func _hover_at(point: Vector2) -> void:
	var id := layout.hit(screen_to_world(point), 6.0 / zoom)
	if id != hovered:
		hovered = id
		node_hovered.emit(id)


func focus_on(id: String) -> void:
	if layout == null or not layout.positions.has(id):
		return
	offset = -(layout.position_of(id) * zoom)
	selected = id
	_user_moved = true


# ---------------------------------------------------------------- build

func _build_layers() -> void:
	_sky = ColorRect.new()
	_sky.name = "Sky"
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter(&"noise_tex", NOISE)
	var rings: Array = AscensionTreeLayout.RING_RADIUS
	_sky_mat.set_shader_parameter(&"rings_a", Vector4(rings[1], rings[2], rings[3], rings[4]))
	_sky_mat.set_shader_parameter(&"rings_b", Vector2(rings[5], rings[6]))
	_sky_mat.set_shader_parameter(&"limb_inner", _limb_inner())
	_sky_mat.set_shader_parameter(&"limb_outer", _limb_inner() + LIMB_WIDTH)
	var border := AscensionTreeLayout.BORDER_ANGLE
	var mr := Vector2.from_angle(deg_to_rad(float(border["MR"])))
	var rm := Vector2.from_angle(deg_to_rad(float(border["RM"])))
	var mm := Vector2.from_angle(deg_to_rad(float(border["MM"])))
	_sky_mat.set_shader_parameter(&"border_dirs", Vector4(mr.x, mr.y, rm.x, rm.y))
	_sky_mat.set_shader_parameter(&"border_dir_c", mm)
	var core := AscensionTreeLayout.CORE_ANGLE
	_sky_mat.set_shader_parameter(&"cores", Vector3(core["melee"], core["ranged"], core["magic"]))
	_sky.material = _sky_mat
	add_child(_sky)
	_lattice = _static_layer("Lattice", null, _draw_lattice)
	_glow = _layer("Glow", ArcaneParticles.additive(), _draw_glow)
	var node_mat := ShaderMaterial.new()
	node_mat.shader = NODE_SHADER
	_nodes = _static_layer("Nodes", node_mat, _draw_node_mesh)
	_marks = _static_layer("Marks", null, _draw_marks)
	_overlay = _layer("Overlay", null, _draw_overlay)
	_sparks = _layer("Sparks", ArcaneParticles.additive(), _draw_sparks)
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad


func _layer(layer_name: String, layer_material: Material, painter: Callable) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if layer_material != null:
		layer.material = layer_material
	layer.draw.connect(painter)
	add_child(layer)
	return layer


## The static layers are Node2D: moving or scaling one never redraws it (a
## Control's scale would).
func _static_layer(layer_name: String, layer_material: Material, painter: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	if layer_material != null:
		layer.material = layer_material
	layer.draw.connect(painter)
	add_child(layer)
	return layer


func _build_unit_shapes() -> void:
	for sides in [3, 4, 6, 8]:
		var points := PackedVector2Array()
		for i in range(sides + 1):
			var angle := -PI * 0.5 + TAU * float(i) / float(sides)
			points.append(Vector2(cos(angle), sin(angle)))
		_unit_shapes[sides] = points
	_unit_shapes[-4] = PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8), Vector2(-0.8, -0.8)])


func _build_cache() -> void:
	_ids.clear()
	_index.clear()
	_world.clear()
	_radius.clear()
	_shape.clear()
	_kinds.clear()
	_names.clear()
	_tint.clear()
	_max_rank.clear()
	_reach_u.clear()
	_big_label.clear()
	_edge_a.clear()
	_edge_b.clear()
	_edge_len.clear()
	_edge_of.clear()
	_state.clear()
	_ranks.clear()
	_label_width.clear()
	_has_baseline = false
	if db == null or layout == null:
		return
	var extent := maxf(layout.extent(), 1.0)
	for id in db.nodes:
		var sid := String(id)
		_index[sid] = _ids.size()
		_ids.append(sid)
		var at := layout.position_of(sid)
		_world.append(at)
		_radius.append(layout.radius_of(sid))
		var kind := db.kind(sid)
		_kinds.append(kind)
		var shape := SH_CIRCLE
		match kind:
			"keystone":
				shape = SH_HEX
			"axiom":
				shape = SH_TRIANGLE
			"catastrophe":
				shape = SH_OCTAGON
			"fork":
				shape = SH_DIAMOND
			"sink":
				shape = SH_SQUARE
		_shape.append(shape)
		var label := String(db.node(sid).get("name", sid))
		_names.append(label.to_upper() if kind in ["core", "ascendant"] else label)
		_tint.append(CORE_TINT.get(db.core_of(sid), BRONZE) as Color)
		_max_rank.append(db.max_rank(sid))
		_reach_u.append(clampf(at.length() / extent, 0.0, 1.0))
		_big_label.append(1 if kind in LABEL_KINDS else 0)
	for id in db.links:
		var sid_from := String(id)
		if not _index.has(sid_from):
			continue
		for other in db.links[id]:
			var sid_to := String(other)
			if sid_to < sid_from or not _index.has(sid_to):
				continue
			var a: int = _index[sid_from]
			var b: int = _index[sid_to]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if _edge_of.has(key):
				continue
			_edge_of[key] = _edge_a.size()
			_edge_a.append(a)
			_edge_b.append(b)
			_edge_len.append(_world[a].distance_to(_world[b]))
	_adjacent = _rebuild_adjacency()
	var count := _ids.size()
	_screen.resize(count)
	_alpha.resize(count)
	_grow.resize(count)
	_alpha.fill(1.0 if _intro_done else 0.0)
	_grow.fill(1.0)
	_multimesh.instance_count = count
	_buffer.resize(count * 16)
	_buffer.fill(0.0)
	_restyle()
	_view_dirty = true
	_static_dirty = true


## Edge indices per node. Packed arrays are values inside an Array, so each
## grown list is written back.
func _rebuild_adjacency() -> Array:
	var lists: Array = []
	lists.resize(_ids.size())
	for i in range(_ids.size()):
		lists[i] = PackedInt32Array()
	for e in range(_edge_a.size()):
		var a := _edge_a[e]
		var b := _edge_b[e]
		var la: PackedInt32Array = lists[a]
		la.append(e)
		lists[a] = la
		var lb: PackedInt32Array = lists[b]
		lb.append(e)
		lists[b] = lb
	return lists


## Path length from the opened Cores through owned nodes: the light flows
## outward along it, and a fresh purchase ignites from its nearest owned
## neighbour.
func _compute_paths() -> void:
	var count := _ids.size()
	_path.resize(count)
	_path.fill(INF)
	var frontier: Array[int] = []
	for i in _owned_list:
		if _kinds[i] == "core" or _kinds[i] == "ascendant":
			_path[i] = 0.0
			frontier.append(i)
	while not frontier.is_empty():
		var i: int = frontier.pop_back()
		for e in (_adjacent[i] as PackedInt32Array):
			if _owned_edge[e] == 0:
				continue
			var j := _edge_b[e] if _edge_a[e] == i else _edge_a[e]
			var through := _path[i] + _edge_len[e]
			if through + 0.01 < _path[j]:
				_path[j] = through
				frontier.append(j)
	for i in _owned_list:
		if _path[i] == INF:
			_path[i] = _world[i].length()
	_flow_a.clear()
	_flow_b.clear()
	_flow_e.clear()
	for e in range(_edge_a.size()):
		if _owned_edge[e] == 0:
			continue
		var a := _edge_a[e]
		var b := _edge_b[e]
		if _path[b] < _path[a]:
			var swap := a
			a = b
			b = swap
		_flow_a.append(a)
		_flow_b.append(b)
		_flow_e.append(e)


## The look of every node's shown state, packed for the node shader.
func _restyle() -> void:
	var count := _ids.size()
	_fill_col.resize(count)
	_rim_col.resize(count)
	_code.resize(count)
	var has_state := _state.size() == count
	for i in range(count):
		var state := _display_state(i) if has_state else ST_LOCKED
		var tint := _tint[i]
		var fill := INK.lerp(tint, 0.13)
		var rim := fill.lerp(BRONZE.lerp(tint, 0.35), 0.75)
		var width := 1.0
		var bits := _shape[i]
		match state:
			ST_REACHABLE:
				fill = INK.lerp(EMBER, 0.08).lerp(tint, 0.08)
				rim = fill.lerp(GOLD_DIM, 0.95)
				width = 1.25
			ST_BUYABLE:
				fill = INK.lerp(EMBER, 0.2)
				rim = EMBER.lerp(GOLD_BRIGHT, 0.3)
				width = 1.8
			ST_OWNED:
				fill = Color(0.3, 0.2, 0.1)
				rim = GOLD_BRIGHT
				width = 1.6
				bits |= BIT_LENS | BIT_HALO
				if _kinds[i] != "core" and _kinds[i] != "ascendant":
					bits |= BIT_PIP
			ST_SEALED:
				fill = INK.lerp(DANGER, 0.14)
				rim = fill.lerp(DANGER.darkened(0.25), 0.85)
				width = 1.25
				bits |= BIT_SLASH
		if has_state and _equipped[i] == 1:
			bits |= BIT_EQUIPPED
		if _kinds[i] == "core" or _kinds[i] == "ascendant":
			bits |= BIT_OUTER
		_fill_col[i] = fill
		_rim_col[i] = rim
		_code[i] = float(bits) + clampf(width / 4.0, 0.0, 0.999)
	_static_dirty = true


# ---------------------------------------------------------------- moments

func _celebrate(i: int, previous_state: int, first_time: bool, previous_rank: PackedInt32Array) -> void:
	var now := _now()
	var parent := -1
	var best := INF
	for e in (_adjacent[i] as PackedInt32Array):
		var j := _edge_b[e] if _edge_a[e] == i else _edge_a[e]
		if _ranks[j] <= 0:
			continue
		var was_owned := j < previous_rank.size() and previous_rank[j] > 0
		var score := _path[j] - (100000.0 if was_owned else 0.0)
		if score < best:
			best = score
			parent = j
	var edge := -1
	var fuse := 0.0
	if first_time and parent >= 0 and not _still:
		edge = int(_edge_of.get(Vector2i(mini(i, parent), maxi(i, parent)), -1))
		if edge >= 0:
			fuse = clampf(_edge_len[edge] / 520.0, 0.16, 0.32)
			_igniting[edge] = true
	var sparks: Array = []
	if not _still:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(_ids[i]) ^ int(now * 1000.0)
		var count := 18 if first_time else 9
		for k in range(count):
			var angle := TAU * (float(k) + rng.randf_range(-0.4, 0.4)) / float(count)
			sparks.append([angle, rng.randf_range(150.0, 360.0), rng.randf_range(0.55, 1.0), rng.randf_range(0.75, 1.0)])
	_bursts.append({
		"i": i, "t0": now, "arrive": now + fuse, "big": first_time, "prev": previous_state,
		"parent": parent, "edge": edge, "fuse": fuse, "sparks": sparks, "quiet": _still,
		"revealed": fuse <= 0.0,
	})
	if fuse > 0.0:
		_reveal_pending = true


func _prune(now: float) -> void:
	if not _bursts.is_empty():
		var keep: Array = []
		for burst in _bursts:
			if now - float(burst["arrive"]) < 1.4:
				keep.append(burst)
			else:
				_igniting.erase(int(burst["edge"]))
		_bursts = keep
	if not _fading.is_empty():
		var still_fading: Array = []
		for fade in _fading:
			if now - float(fade["t0"]) < 0.8:
				still_fading.append(fade)
		_fading = still_fading


## The state a node shows: until a purchase's fuse arrives, its old one.
func _display_state(i: int) -> int:
	if not _bursts.is_empty():
		for burst in _bursts:
			if int(burst["i"]) == i and not bool(burst["revealed"]):
				return int(burst["prev"])
	return _state[i] if i < _state.size() else ST_LOCKED


# ---------------------------------------------------------------- view update

func _recompute_screen(now: float) -> void:
	var count := _ids.size()
	if _screen.size() != count:
		_screen.resize(count)
		_alpha.resize(count)
		_grow.resize(count)
	var origin := _origin() + offset
	if _intro_done:
		for i in range(count):
			_screen[i] = origin + _world[i] * zoom
		return
	var elapsed := now - _opened_at
	var finished := true
	for i in range(count):
		var eased := 1.0
		if _still:
			eased = clampf(elapsed / INTRO_STILL_SECONDS, 0.0, 1.0)
			_alpha[i] = eased
			_grow[i] = 1.0
			_screen[i] = origin + _world[i] * zoom
		else:
			# Unfurling: each node swings out from the core, ring by ring.
			var start := 0.16 + _reach_u[i] * 0.72
			var k := clampf((elapsed - start) / 0.46, 0.0, 1.0)
			eased = 1.0 - pow(1.0 - k, 3.0)
			_alpha[i] = eased
			_grow[i] = lerpf(0.55, 1.0, eased)
			_screen[i] = origin + _world[i].rotated(-(1.0 - eased) * 0.32) * lerpf(0.62, 1.0, eased) * zoom
		if eased < 1.0:
			finished = false
	if finished:
		_intro_done = true
		_alpha.fill(1.0)
		_grow.fill(1.0)
		if _glide_pending:
			_start_glide.call_deferred()


func _push_sky_transform(now: float) -> void:
	_sky_mat.set_shader_parameter(&"view_size", size)
	_sky_mat.set_shader_parameter(&"tree_center", _origin() + offset)
	_sky_mat.set_shader_parameter(&"deco_center", _deco_center())
	_sky_mat.set_shader_parameter(&"pan", offset)
	_sky_mat.set_shader_parameter(&"zoom", zoom)
	_sky_mat.set_shader_parameter(&"spin", 0.0 if _still else 1.0)
	_sky_mat.set_shader_parameter(&"parallax", 0.0 if _still else 1.0)
	_sky_mat.set_shader_parameter(&"wake", _wake(now))
	_sky_mat.set_shader_parameter(&"sweep", _sweep(now))


## The opening's light (0..1) and how far the rings have unfurled (0..1).
func _wake(now: float) -> float:
	var elapsed := now - _opened_at
	if _still:
		return clampf(elapsed / INTRO_STILL_SECONDS, 0.0, 1.0)
	return smoothstep(0.0, 0.7, elapsed)


func _sweep(now: float) -> float:
	if _still or _intro_done:
		return 1.0
	return clampf((now - _opened_at - 0.04) / 1.15, 0.0, 1.0)


func _push_sky_static() -> void:
	if _sky_mat == null:
		return
	_sky_mat.set_shader_parameter(&"core_lit", Vector3(
		1.0 if bool(_cores_open.get("melee", false)) else 0.0,
		1.0 if bool(_cores_open.get("ranged", false)) else 0.0,
		1.0 if bool(_cores_open.get("magic", false)) else 0.0))


## Packs every node drawn this pass into the node shader's instance buffer:
## owned nodes first, so their halos lie under their neighbours.
func _rebuild_nodes() -> void:
	var count := _ids.size()
	if count == 0 or _fill_col.size() != count or _screen.size() != count:
		_multimesh.visible_instance_count = 0
		return
	var rect := _static_rect()
	var written := 0
	for pass_owned in [true, false]:
		for i in range(count):
			var code := _code[i]
			if ((int(code) & BIT_HALO) != 0) != pass_owned:
				continue
			var alpha := _alpha[i]
			if alpha <= 0.02:
				continue
			var at := _screen[i]
			var r := _radius[i] * zoom * _grow[i]
			if not rect.grow(r * 3.0).has_point(at):
				continue
			var wide := (int(code) & (BIT_HALO | BIT_OUTER | BIT_EQUIPPED)) != 0
			var half := r * (QUAD_WIDE if wide else QUAD_TIGHT)
			var fill := _fill_col[i]
			var rim := _rim_col[i]
			var o := written * 16
			_buffer[o] = half
			_buffer[o + 1] = 0.0
			_buffer[o + 2] = 0.0
			_buffer[o + 3] = at.x
			_buffer[o + 4] = 0.0
			_buffer[o + 5] = half
			_buffer[o + 6] = 0.0
			_buffer[o + 7] = at.y
			_buffer[o + 8] = rim.r
			_buffer[o + 9] = rim.g
			_buffer[o + 10] = rim.b
			_buffer[o + 11] = alpha
			_buffer[o + 12] = fill.r
			_buffer[o + 13] = fill.g
			_buffer[o + 14] = fill.b
			_buffer[o + 15] = code
			written += 1
	_multimesh.buffer = _buffer
	_multimesh.visible_instance_count = written


## What the static layers draw: the view and most of a screen round it, so a
## pan only slides them until it runs past.
func _static_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow_individual(size.x * 0.8, size.y * 0.8, size.x * 0.8, size.y * 0.8)


## What the live layers and the overlay draw: the view, less the panel.
func _drawn_rect(margin: float) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(maxf(size.x - cover_right, 0.0), size.y)).grow(margin)


static func _segment_visible(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if (a.x < rect.position.x and b.x < rect.position.x) or (a.x > rect.end.x and b.x > rect.end.x):
		return false
	if (a.y < rect.position.y and b.y < rect.position.y) or (a.y > rect.end.y and b.y > rect.end.y):
		return false
	return true


# ---------------------------------------------------------------- static layers

func _draw_node_mesh() -> void:
	if _multimesh != null and _multimesh.instance_count > 0:
		_nodes.draw_multimesh(_multimesh, null)


## The lattice: edges in three weights (faint, in reach, owned with an ember
## underglow). The hovered or selected node's edges are the overlay's.
func _draw_lattice() -> void:
	if db == null or layout == null or _screen.size() != _ids.size():
		return
	var overview := zoom < OVERVIEW_ZOOM
	var rect := _static_rect()
	var has_state := _state.size() == _ids.size()
	var faint := PackedVector2Array()
	var faint_col := PackedColorArray()
	var reach := PackedVector2Array()
	var reach_col := PackedColorArray()
	var owned := PackedVector2Array()
	var owned_col := PackedColorArray()
	var owned_glow := PackedColorArray()
	for e in range(_edge_a.size()):
		var a := _edge_a[e]
		var b := _edge_b[e]
		var alpha := minf(_alpha[a], _alpha[b])
		if alpha <= 0.02:
			continue
		var owned_edge := has_state and _owned_edge[e] == 1 and not _igniting.has(e)
		var touches_buyable := has_state and (_state[a] == ST_BUYABLE or _state[b] == ST_BUYABLE)
		if overview and not owned_edge and not touches_buyable:
			continue
		var pa := _screen[a]
		var pb := _screen[b]
		if not _segment_visible(pa, pb, rect):
			continue
		if owned_edge:
			owned.append(pa)
			owned.append(pb)
			owned_col.append(Color(GOLD, 0.62 * alpha))
			owned_glow.append(Color(EMBER, 0.08 * alpha))
		elif touches_buyable:
			reach.append(pa)
			reach.append(pb)
			reach_col.append(Color(EMBER.lerp(GOLD_DIM, 0.4), 0.42 * alpha))
		else:
			faint.append(pa)
			faint.append(pb)
			faint_col.append(Color(BRONZE, 0.21 * alpha))
	if not faint.is_empty():
		_lattice.draw_multiline_colors(faint, faint_col, -1.0, false)
	if not reach.is_empty():
		_lattice.draw_multiline_colors(reach, reach_col, 1.15, true)
	if not owned.is_empty():
		_lattice.draw_multiline_colors(owned, owned_glow, 5.0, true)
		_lattice.draw_multiline_colors(owned, owned_col, 1.6, true)


## The marks over the nodes: Core stars, rank pips and numerals, sink
## counts, then every name that has room.
func _draw_marks() -> void:
	_label_spots.clear()
	if db == null or layout == null or _screen.size() != _ids.size():
		return
	var canvas := _marks
	var rect := _static_rect()
	var has_state := _state.size() == _ids.size()
	var close := zoom >= 0.75
	# Node discs are obstacles the labels steer round; `names` holds only the
	# placed names, for the promised names that must never be dropped.
	var grid := {}
	var names := {}
	for i in range(_ids.size()):
		var alpha := _alpha[i]
		if alpha <= 0.02:
			continue
		var at := _screen[i]
		if not rect.has_point(at):
			continue
		var r := _radius[i] * zoom * _grow[i]
		if r > 2.0:
			var keep := r * 0.82 + (7.0 if has_state and _equipped[i] == 1 else 0.0)
			_claim(grid, Rect2(at - Vector2(keep, keep), Vector2(keep, keep) * 2.0))
		var kind := _kinds[i]
		var state := _display_state(i) if has_state else ST_LOCKED
		if kind == "core" or kind == "ascendant":
			var star := Color(PARCHMENT, 0.92 * alpha) if state == ST_OWNED else Color(GOLD_DIM, 0.6 * alpha)
			_draw_star(canvas, at, r * (0.62 if kind == "ascendant" else 0.5), star)
		if has_state and _ranks[i] > 0:
			if kind == "sink":
				var count := "×%d" % _ranks[i]
				canvas.draw_string_outline(_font, at + Vector2(r * 0.55, -r * 0.6), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(INK, 0.9 * alpha))
				canvas.draw_string(_font, at + Vector2(r * 0.55, -r * 0.6), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GOLD_BRIGHT, alpha))
			elif _max_rank[i] > 1:
				_draw_rank_pips(canvas, at, r, _ranks[i], _max_rank[i], alpha)
				if close:
					var roman: Array = ["", "I", "II", "III", "IV"]
					canvas.draw_string(_font_caps, at + Vector2(-r, r * 0.42), String(roman[mini(_ranks[i], 4)]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 10, Color(INK if state == ST_OWNED else PARCHMENT, alpha))
	# Names by importance, each in the first free spot round its node
	# (below, above, right, left), or not at all: hover reads the rest.
	var queue: Array = []
	for i in range(_ids.size()):
		if _alpha[i] <= 0.05 or not rect.has_point(_screen[i]):
			continue
		var state := _display_state(i) if has_state else ST_LOCKED
		if not _label_shown(_kinds[i], state, i):
			continue
		queue.append(Vector3i(_label_rank(i, state), i, state))
	queue.sort()
	for entry in queue:
		var item := entry as Vector3i
		# Promised (never dropped): the loadout, the Cores and what is buyable
		# now, the playtest rule; owned and other names give way when crowded.
		var promised := item.x <= 1 or item.z == ST_BUYABLE
		_place_label(canvas, grid, names, item.y, item.z, promised)


## The overlay, redrawn as the view moves or the focus changes: the
## territory names on the limb and the hovered and selected nodes' edges,
## rims and names.
func _draw_overlay() -> void:
	if db == null or layout == null or _screen.size() != _ids.size():
		return
	_draw_limb_names(_overlay)
	var hi: int = _index.get(hovered, -1)
	var si: int = _index.get(selected, -1)
	var has_state := _state.size() == _ids.size()
	var rect := _drawn_rect(40.0)
	var lines := PackedVector2Array()
	var colours := PackedColorArray()
	for focus in [si, hi]:
		if focus < 0 or _alpha[focus] < 0.3:
			continue
		for e in (_adjacent[focus] as PackedInt32Array):
			var a := _edge_a[e]
			var b := _edge_b[e]
			var pa := _screen[a]
			var pb := _screen[b]
			if not _segment_visible(pa, pb, rect):
				continue
			var span := pb - pa
			var length := span.length()
			var ra := _radius[a] * zoom + 1.0
			var rb := _radius[b] * zoom + 1.0
			if length <= ra + rb:
				continue
			var dir := span / length
			lines.append(pa + dir * ra)
			lines.append(pb - dir * rb)
			var owned_edge := has_state and _owned_edge[e] == 1
			colours.append(Color(GOLD_BRIGHT, 0.8) if owned_edge else Color(GOLD.lerp(GOLD_BRIGHT, 0.35), 0.58))
	if not lines.is_empty():
		_overlay.draw_multiline_colors(lines, colours, 1.4, true)
	for focus in [si, hi]:
		if focus < 0 or _alpha[focus] < 0.3 or not rect.has_point(_screen[focus]):
			continue
		var at := _screen[focus]
		var r := _radius[focus] * zoom * _grow[focus]
		var rim := Color(GOLD_BRIGHT, 0.95)
		if _shape[focus] == SH_CIRCLE:
			_overlay.draw_arc(at, r, 0.0, TAU, clampi(int(r * 1.4) + 10, 16, 64), rim, 2.0, true)
		else:
			_overlay.draw_polyline(_shape_points(_shape[focus], at, r), rim, 2.0, true)
		var state := _display_state(focus) if has_state else ST_LOCKED
		var spot: Array = _label_spots.get(focus, [])
		if not spot.is_empty():
			var placed: Rect2 = spot[0]
			_draw_name(_overlay, focus, Rect2(_static_pos + placed.position * _static_k, placed.size), int(spot[1]), state, true)
		else:
			var font_size := _label_size(focus) + 1
			var font := _label_font(focus)
			var width := _name_width(focus, font, font_size)
			var height := font.get_ascent(font_size) + font.get_descent(font_size) * 0.6
			var ring := r + (6.0 if has_state and _equipped[focus] == 1 else 2.0)
			_draw_name(_overlay, focus, Rect2(at.x - width * 0.5, at.y + ring, width, height), font_size, state, true)


## The territory names, curved along the limb, and a diamond on each border.
func _draw_limb_names(canvas: CanvasItem) -> void:
	var center := _deco_center()
	var radius := (_limb_inner() + LIMB_WIDTH * 0.5) * zoom
	var now := _now()
	var limb_reach := _sweep(now) * 1.2 - 0.25
	var wake := _wake(now)
	var font_size := clampi(int(round(15.0 * zoom / 0.6)), 11, 30)
	var tracking := font_size * 0.32
	var ascent := _font_caps.get_ascent(font_size)
	var rect := _drawn_rect(30.0)
	for core in AscensionTreeLayout.CORE_ANGLE:
		var angle := deg_to_rad(float(AscensionTreeLayout.CORE_ANGLE[core]))
		var reveal := wake if _sweep(now) >= 1.0 else smoothstep(0.0, 0.08, limb_reach - _from_top(angle) + 0.03)
		if reveal <= 0.0:
			continue
		var mid := center + Vector2(cos(angle), sin(angle)) * radius
		if not rect.has_point(mid):
			continue
		var text := String(core).to_upper()
		var open := bool(_cores_open.get(core, false))
		var colour: Color = (GOLD if open else GOLD_DIM).lerp(CORE_TINT[core], 0.22)
		colour.a = (0.92 if open else 0.6) * reveal
		var widths: Array[float] = []
		var total := 0.0
		for ch in text:
			var w := _font_caps.get_char_size(ch.unicode_at(0), font_size).x
			widths.append(w)
			total += w + tracking
		total -= tracking
		var span := total / maxf(radius, 1.0)
		# The lower half reads counter-clockwise so the letters stay upright.
		var lower := sin(angle) > 0.05
		var direction := -1.0 if lower else 1.0
		var cursor := angle - direction * span * 0.5
		for k in range(text.length()):
			var w: float = widths[k]
			var theta := cursor + direction * (w * 0.5) / radius
			var at := center + Vector2(cos(theta), sin(theta)) * radius
			canvas.draw_set_transform(at, theta + (-PI * 0.5 if lower else PI * 0.5), Vector2.ONE)
			canvas.draw_char(_font_caps, Vector2(-w * 0.5, ascent * 0.36), text[k], font_size, colour)
			cursor += direction * (w + tracking) / radius
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	for border in AscensionTreeLayout.BORDER_ANGLE:
		var angle := deg_to_rad(float(AscensionTreeLayout.BORDER_ANGLE[border]))
		var reveal := wake if _sweep(now) >= 1.0 else smoothstep(0.0, 0.05, limb_reach - _from_top(angle))
		if reveal <= 0.0:
			continue
		var at := center + Vector2(cos(angle), sin(angle)) * radius
		var r := clampf(4.0 * zoom / 0.6, 3.0, 7.0)
		var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0), at + Vector2(0, -r)])
		canvas.draw_colored_polygon(diamond, Color(INK, 0.95 * reveal))
		canvas.draw_polyline(diamond, Color(GOLD_DIM, 0.75 * reveal), 1.2, true)


## 0 at the top of the dial, rising clockwise to 1 (the sweep's measure).
static func _from_top(angle: float) -> float:
	return fposmod((rad_to_deg(angle) + 90.0) / 360.0, 1.0)


## Lower is placed first: the loadout, then the Cores, what is owned or
## buyable, the Ascendant, the landmark kinds, then everything else.
func _label_rank(i: int, state: int) -> int:
	if _equipped.size() > i and _equipped[i] == 1:
		return 0
	var kind := _kinds[i]
	if kind == "core":
		return 1
	if state == ST_OWNED or state == ST_BUYABLE:
		return 2
	if kind == "ascendant":
		return 3
	if _big_label[i] == 1:
		return 4
	return 5 if state == ST_REACHABLE else 6


## _label_visible without the focus: the overlay names what is hovered.
func _label_shown(kind: String, state: int, i: int) -> bool:
	if kind == "mutation" or kind == "revelation_mutation":
		return false
	if zoom >= 0.9:
		return true
	if zoom >= OVERVIEW_ZOOM:
		return _big_label[i] == 1
	if kind == "core" or state == ST_BUYABLE:
		return true
	return _equipped.size() > i and _equipped[i] == 1


static func _claim(grid: Dictionary, rect: Rect2) -> void:
	var from := Vector2i(floori(rect.position.x / LABEL_CELL), floori(rect.position.y / LABEL_CELL))
	var to := Vector2i(floori(rect.end.x / LABEL_CELL), floori(rect.end.y / LABEL_CELL))
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var key := Vector2i(x, y)
			if grid.has(key):
				(grid[key] as Array).append(rect)
			else:
				grid[key] = [rect]


static func _is_free(grid: Dictionary, rect: Rect2) -> bool:
	var from := Vector2i(floori(rect.position.x / LABEL_CELL), floori(rect.position.y / LABEL_CELL))
	var to := Vector2i(floori(rect.end.x / LABEL_CELL), floori(rect.end.y / LABEL_CELL))
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var key := Vector2i(x, y)
			if not grid.has(key):
				continue
			for other in grid[key]:
				if (other as Rect2).intersects(rect):
					return false
	return true


func _label_font(i: int) -> Font:
	return _font_caps if (_kinds[i] == "core" or _kinds[i] == "ascendant") else _font


func _label_size(i: int) -> int:
	# Stepped, so a zoom does not rasterise the names at every size between.
	var step_scale := snappedf(clampf(0.88 + (zoom - 0.6) * 0.32, 0.86, 1.32), 0.11)
	if _kinds[i] == "core" or _kinds[i] == "ascendant":
		return int(round(12.5 * step_scale))
	return int(round((15.0 if _big_label[i] == 1 else 13.5) * step_scale))


func _name_width(i: int, font: Font, font_size: int) -> float:
	var key := i * 64 + font_size
	var width: float = _label_width.get(key, -1.0)
	if width < 0.0:
		width = font.get_string_size(_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_label_width[key] = width
	return width


## `promised` names (the loadout, the Cores, what is buyable now) may
## overlap a node disc when every spot is taken, and in the last resort sit
## in their first spot; any other name gives way and is read on hover.
func _place_label(canvas: CanvasItem, grid: Dictionary, names: Dictionary, i: int, state: int, promised: bool) -> void:
	var font_size := _label_size(i)
	var font := _label_font(i)
	var at := _screen[i]
	var r := _radius[i] * zoom * _grow[i]
	var width := _name_width(i, font, font_size)
	var height := font.get_ascent(font_size) + font.get_descent(font_size) * 0.6
	var ring := r + (6.0 if _equipped.size() > i and _equipped[i] == 1 else 2.0)
	if _max_rank[i] > 1 and _ranks.size() > i and _ranks[i] > 0:
		ring = maxf(ring, r + 5.0)
	var below := Rect2(at.x - width * 0.5, at.y + ring, width, height)
	var above := Rect2(at.x - width * 0.5, at.y - ring - height, width, height)
	var right := Rect2(at.x + ring + 3.0, at.y - height * 0.5, width, height)
	var left := Rect2(at.x - ring - 3.0 - width, at.y - height * 0.5, width, height)
	var spots: Array[Rect2] = [below, above, right, left]
	if _kinds[i] == "core":
		# A Core names itself away from the centre (the cluster is tight).
		if _world[i].y < -1.0:
			spots = [above, right, left, below]
		else:
			spots = [below, left if _world[i].x < 0.0 else right, right if _world[i].x < 0.0 else left, above]
	for spot in spots:
		var padded := spot.grow_individual(2.0, 0.0, 2.0, 0.0)
		if _is_free(grid, padded):
			_take_spot(canvas, grid, names, i, spot, padded, font_size, state)
			return
	if not promised:
		return
	for spot in spots:
		var padded := spot.grow_individual(2.0, 0.0, 2.0, 0.0)
		if _is_free(names, padded):
			_take_spot(canvas, grid, names, i, spot, padded, font_size, state)
			return
	_take_spot(canvas, grid, names, i, spots[0], spots[0].grow_individual(2.0, 0.0, 2.0, 0.0), font_size, state)


func _take_spot(canvas: CanvasItem, grid: Dictionary, names: Dictionary, i: int, spot: Rect2, padded: Rect2, font_size: int, state: int) -> void:
	_claim(grid, padded)
	_claim(names, padded)
	_label_spots[i] = [spot, font_size]
	_draw_name(canvas, i, spot, font_size, state, false)


func _draw_name(canvas: CanvasItem, i: int, spot: Rect2, font_size: int, state: int, focused: bool) -> void:
	var font := _label_font(i)
	var alpha := _alpha[i]
	var colour := Color(0.6, 0.55, 0.48)
	match state:
		ST_REACHABLE:
			colour = Color(0.76, 0.66, 0.52)
		ST_BUYABLE:
			colour = Color(1.0, 0.8, 0.56)
		ST_OWNED:
			colour = PARCHMENT
		ST_SEALED:
			colour = Color(0.72, 0.45, 0.4)
	if font == _font_caps:
		colour = colour.lerp(GOLD, 0.35)
	if focused:
		colour = GOLD_BRIGHT
	colour.a = alpha
	var pos := Vector2(spot.position.x, spot.position.y + font.get_ascent(font_size))
	canvas.draw_string_outline(font, pos, _names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5 if focused else 4, Color(0.012, 0.01, 0.008, (0.95 if focused else 0.88) * alpha))
	canvas.draw_string(font, pos, _names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


func _shape_points(shape: int, at: Vector2, r: float) -> PackedVector2Array:
	var unit: PackedVector2Array
	match shape:
		SH_HEX:
			unit = _unit_shapes[6]
		SH_TRIANGLE:
			unit = _unit_shapes[3]
		SH_OCTAGON:
			unit = _unit_shapes[8]
		SH_DIAMOND:
			unit = _unit_shapes[4]
		_:
			unit = _unit_shapes[-4]
	return Transform2D(0.0, Vector2(r, r), 0.0, at) * unit


## Ranks as pips round the top of the rim: lit for each rank owned.
func _draw_rank_pips(canvas: CanvasItem, at: Vector2, r: float, rank: int, top: int, alpha: float) -> void:
	var step := deg_to_rad(16.0)
	var start := -PI * 0.5 - step * float(top - 1) * 0.5
	var pip := clampf(r * 0.16, 1.4, 3.0)
	for k in range(top):
		var angle := start + step * float(k)
		var p := at + Vector2(cos(angle), sin(angle)) * (r + pip + 2.5)
		if k < rank:
			canvas.draw_circle(p, pip, Color(GOLD_BRIGHT, alpha))
		else:
			canvas.draw_circle(p, pip, Color(GOLD_DIM, 0.45 * alpha), false, 1.0, true)


static func _draw_diamond(canvas: CanvasItem, c: Vector2, r: float, colour: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), colour)


## A four-pointed star: the Core and Ascendant glyph.
static func _draw_star(canvas: CanvasItem, c: Vector2, r: float, colour: Color) -> void:
	var waist := r * 0.22
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(waist, -waist), c + Vector2(r, 0), c + Vector2(waist, waist),
		c + Vector2(0, r), c + Vector2(-waist, waist), c + Vector2(-r, 0), c + Vector2(-waist, -waist),
	]), colour)


## What deserves a written name at the current zoom. Hover and selection
## always; close zoom names everything; mid zoom the landmark kinds; the
## overview only cores, the equipped loadout and what is buyable NOW.
func _label_visible(sid: String, kind: String, state: String) -> bool:
	if kind == "mutation" or kind == "revelation_mutation":
		return sid == hovered or sid == selected
	if sid == hovered or sid == selected:
		return true
	# The same rule the renderer draws by, so the test reads what is drawn.
	if _index.has(sid):
		return _label_shown(kind, STATE_NAMES.find(state), int(_index[sid]))
	if zoom >= 0.9:
		return true
	if zoom >= OVERVIEW_ZOOM:
		return kind in LABEL_KINDS
	if kind == "core":
		return true
	if state == "buyable":
		return true
	return ledger != null and ledger.is_equipped(sid)


# ---------------------------------------------------------------- live layers

func _soft(canvas: CanvasItem, at: Vector2, radius: float, colour: Color) -> void:
	canvas.draw_texture_rect(_dot, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, colour)


## Under the nodes, additive: the breathing of what can be bought, the glow
## of the equipped loadout, the light flowing outward through the owned
## lattice and the edges igniting toward a fresh purchase.
func _draw_glow() -> void:
	if _screen.size() != _ids.size() or _state.size() != _ids.size():
		return
	var canvas := _glow
	var now := _now()
	var rect := _drawn_rect(40.0)
	var period := BREATH_SECONDS * (1.5 if _still else 1.0)
	var depth := 0.5 if _still else 1.0
	for i in _buyable_list:
		if _alpha[i] <= 0.02 or not rect.has_point(_screen[i]):
			continue
		var r := _radius[i] * zoom * _grow[i]
		var breath := 0.5 - 0.5 * cos(now * TAU / period - _world[i].length() * 0.004)
		_soft(canvas, _screen[i], r * (2.3 + 0.5 * breath * depth) + 5.0, Color(EMBER, (0.12 + 0.24 * breath * depth) * _alpha[i]))
	for i in _equipped_list:
		if _alpha[i] <= 0.02 or not rect.has_point(_screen[i]):
			continue
		var r := _radius[i] * zoom * _grow[i]
		var shimmer := 0.5 + 0.5 * sin(now * 1.3 + float(i))
		_soft(canvas, _screen[i], r * 3.0 + 8.0, Color(GOLD_BRIGHT, (0.14 + 0.08 * shimmer) * _alpha[i]))
	# Light flowing outward along the owned lattice, wave after wave.
	var travel := now * FLOW_SPEED * (0.5 if _still else 1.0)
	var head_size := clampf(4.0 + 5.0 * zoom, 4.0, 12.0)
	for f in range(_flow_a.size()):
		var e := _flow_e[f]
		if _igniting.has(e):
			continue
		var a := _flow_a[f]
		var b := _flow_b[f]
		var alpha := minf(_alpha[a], _alpha[b])
		if alpha <= 0.3:
			continue
		var pa := _screen[a]
		var pb := _screen[b]
		if not _segment_visible(pa, pb, rect):
			continue
		var length := _edge_len[e]
		if length <= 1.0:
			continue
		var start := _radius[a]
		var finish := length - _radius[b]
		var u := fposmod(travel - _path[a], FLOW_PERIOD)
		while u <= finish + FLOW_TAIL:
			var head := clampf(u, start, finish)
			var tail := clampf(u - FLOW_TAIL, start, finish)
			if head - tail > 1.0:
				var fade := smoothstep(start, start + 18.0, u) * (1.0 - smoothstep(finish, finish + FLOW_TAIL, u)) * alpha
				var p_head := pa.lerp(pb, head / length)
				var p_tail := pa.lerp(pb, tail / length)
				canvas.draw_polyline_colors(PackedVector2Array([p_tail, p_head]), PackedColorArray([Color(EMBER, 0.0), Color(GOLD_BRIGHT, 0.7 * fade)]), 2.0, true)
				if u <= finish:
					_soft(canvas, p_head, head_size, Color(GOLD_BRIGHT, 0.55 * fade))
			u += FLOW_PERIOD
	# Purchases: the fuse running from the parent, then the edge glowing out.
	for burst in _bursts:
		var e := int(burst["edge"])
		var i := int(burst["i"])
		var since := now - float(burst["t0"])
		var after := now - float(burst["arrive"])
		var at := _screen[i]
		var r := _radius[i] * zoom
		if e >= 0:
			var parent := int(burst["parent"])
			var pa := _screen[parent]
			var length := _edge_len[e]
			var start := _radius[parent]
			var finish := length - _radius[i]
			var reach := clampf(since / maxf(float(burst["fuse"]), 0.001), 0.0, 1.0)
			var p_from := pa.lerp(at, start / length)
			var p_head := pa.lerp(at, lerpf(start, finish, reach) / length)
			var glow := 1.0 if after < 0.0 else clampf(1.0 - after / 0.9, 0.0, 1.0)
			canvas.draw_line(p_from, p_head, Color(GOLD_BRIGHT, 0.9 * glow), 2.6, true)
			canvas.draw_line(p_from, p_head, Color(EMBER, 0.25 * glow), 7.0, true)
			if after < 0.0:
				_soft(canvas, p_head, head_size * 1.8, Color(1.0, 0.92, 0.75, 0.95))
		elif bool(burst["quiet"]) and int(burst["parent"]) >= 0:
			# Reduced motion: the edge to the parent brightens and settles.
			var glow_quiet := clampf(1.0 - since / 1.0, 0.0, 1.0)
			canvas.draw_line(_screen[int(burst["parent"])], at, Color(GOLD_BRIGHT, 0.5 * glow_quiet), 2.2, true)
		if after >= 0.0:
			var k := clampf(after / (0.9 if bool(burst["quiet"]) else 0.6), 0.0, 1.0)
			var strength := (1.0 if bool(burst["big"]) else 0.6) * (1.0 - k) * (1.0 - k)
			if bool(burst["quiet"]):
				strength = (1.0 if bool(burst["big"]) else 0.6) * sin(k * PI) * 0.8
			_soft(canvas, at, r * 6.0 + 16.0, Color(GOLD_BRIGHT, 0.8 * strength))
	for fade in _fading:
		var i := int(fade["i"])
		var k := clampf((now - float(fade["t0"])) / 0.8, 0.0, 1.0)
		_soft(canvas, _screen[i], _radius[i] * zoom * lerpf(3.4, 1.2, k) + 4.0, Color(EMBER, 0.45 * (1.0 - k)))


## Over the nodes, additive: hover and selection reticles, the turning dial
## of each equipped node, the ripple of what can be bought, and bursts.
func _draw_sparks() -> void:
	if _screen.size() != _ids.size() or _state.size() != _ids.size():
		return
	var canvas := _sparks
	var now := _now()
	var rect := _drawn_rect(40.0)
	if not _still:
		for i in _buyable_list:
			if _alpha[i] < 0.9 or not rect.has_point(_screen[i]):
				continue
			var r := _radius[i] * zoom
			var k := fposmod(now / BREATH_SECONDS - _world[i].length() * 0.004 / TAU - 0.2, 1.0)
			var alpha := 0.3 * (1.0 - k) * (1.0 - k)
			if alpha > 0.01:
				canvas.draw_arc(_screen[i], r + 1.5 + 9.0 * k, 0.0, TAU, clampi(int(r * 1.5) + 12, 16, 48), Color(EMBER, alpha), 1.2, true)
	for i in _equipped_list:
		if _alpha[i] < 0.5 or not rect.has_point(_screen[i]):
			continue
		var r := _radius[i] * zoom + 5.5
		var turn := 0.0 if _still else now * 0.35
		var ticks := PackedVector2Array()
		for k in range(12):
			var angle := turn + TAU * float(k) / 12.0
			var dir := Vector2(cos(angle), sin(angle))
			ticks.append(_screen[i] + dir * r)
			ticks.append(_screen[i] + dir * (r + (3.5 if k % 3 == 0 else 2.0)))
		canvas.draw_multiline(ticks, Color(GOLD_BRIGHT, 0.75 * _alpha[i]), 1.0, true)
	var si: int = _index.get(selected, -1)
	if si >= 0 and _alpha[si] > 0.3 and rect.has_point(_screen[si]):
		var eased := 1.0 if _still else clampf((now - _select_since) / 0.18, 0.0, 1.0)
		var r := _radius[si] * zoom + lerpf(16.0, 8.0, eased)
		var c := _screen[si]
		canvas.draw_arc(c, r, 0.0, TAU, clampi(int(r * 1.2) + 12, 20, 64), Color(GOLD_BRIGHT, 0.55 * eased), 1.0, true)
		for k in range(4):
			var angle := PI * 0.5 * float(k) - PI * 0.5
			_draw_diamond(canvas, c + Vector2(cos(angle), sin(angle)) * r, 3.0, Color(GOLD_BRIGHT, 0.85 * eased))
	var hi: int = _index.get(hovered, -1)
	if hi >= 0 and hi != si and _alpha[hi] > 0.3 and rect.has_point(_screen[hi]):
		var eased := 1.0 if _still else clampf((now - _hover_since) / 0.14, 0.0, 1.0)
		var r := _radius[hi] * zoom + lerpf(12.0, 5.0, eased)
		var c := _screen[hi]
		canvas.draw_arc(c, r, 0.0, TAU, clampi(int(r * 1.2) + 12, 20, 64), Color(GOLD_BRIGHT, 0.5 * eased), 1.0, true)
		var turn := 0.0 if _still else now * 0.8
		var ticks := PackedVector2Array()
		for k in range(4):
			var angle := turn + PI * 0.25 + PI * 0.5 * float(k)
			var dir := Vector2(cos(angle), sin(angle))
			ticks.append(c + dir * (r + 2.0))
			ticks.append(c + dir * (r + 6.0))
		canvas.draw_multiline(ticks, Color(GOLD_BRIGHT, 0.8 * eased), 1.2, true)
	for burst in _bursts:
		if bool(burst["quiet"]):
			continue
		var after := now - float(burst["arrive"])
		if after < 0.0:
			continue
		var i := int(burst["i"])
		var c := _screen[i]
		var r := _radius[i] * zoom
		var big := bool(burst["big"])
		var burst_scale := clampf(zoom / 0.6, 0.7, 1.6)
		# Shockwaves: a gold ring, then a fainter ember one.
		for wave in range(2 if big else 1):
			var k := clampf((after - 0.09 * wave) / 0.62, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var ring := r + 2.0 + (r * 2.2 + 30.0 * burst_scale) * (1.0 - pow(1.0 - k, 2.4)) * (1.0 if wave == 0 else 0.7)
			var colour := GOLD_BRIGHT if wave == 0 else EMBER
			canvas.draw_arc(c, ring, 0.0, TAU, clampi(int(ring * 0.9) + 16, 24, 96), Color(colour, 0.85 * pow(1.0 - k, 1.6)), lerpf(2.4, 0.6, k), true)
		# An astrolabe stamp: eight ticks turning a little as they fade.
		var stamp := clampf(after / 0.7, 0.0, 1.0)
		if stamp < 1.0:
			var marks := PackedVector2Array()
			var reach := r + 6.0 + 6.0 * stamp
			for k in range(8):
				var angle := stamp * 0.5 + TAU * float(k) / 8.0
				var dir := Vector2(cos(angle), sin(angle))
				marks.append(c + dir * reach)
				marks.append(c + dir * (reach + 5.0))
			canvas.draw_multiline(marks, Color(GOLD_BRIGHT, 0.7 * (1.0 - stamp)), 1.2, true)
		# Sparks: streaks flung outward, slowed by drag, cooling as they go.
		var streaks := PackedVector2Array()
		var colours := PackedColorArray()
		for spark in burst["sparks"]:
			var k: float = after / float(spark[2])
			if k >= 1.0:
				continue
			var dir := Vector2(cos(float(spark[0])), sin(float(spark[0])))
			var speed: float = float(spark[1]) * burst_scale
			var drag := 4.2
			var head := c + dir * (r + speed / drag * (1.0 - exp(-drag * after)))
			var tail := head - dir * clampf(speed * exp(-drag * after) * 0.05, 2.5, 20.0)
			streaks.append(tail)
			streaks.append(head)
			colours.append(Color(Color(1.0, 0.95, 0.82).lerp(EMBER, k), float(spark[3]) * (1.0 - k * k)))
		if not streaks.is_empty():
			canvas.draw_multiline_colors(streaks, colours, 2.0, true)
