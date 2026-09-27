extends Node

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_compact_blockers()
	_test_floor_stamps()
	_test_wall_catalog()
	_test_half_cover_catalog()
	print("ChunkBuildDataTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_compact_blockers() -> void:
	var data := ChunkBuildData.new(Vector2i(-2, 3), 4)
	_check(data.coord == Vector2i(-2, 3), "chunk coordinate is retained")
	_check(data.add_blocker(Vector2i(1, 2), WorldBlockerGeometry.Kind.WALL, 10, 0), "first blocker write succeeds")
	_check(not data.add_blocker(Vector2i(1, 2), WorldBlockerGeometry.Kind.WINDOW, 5, 0), "duplicate blocker write is suppressed")
	_check(data.kind_at(Vector2i(1, 2)) == WorldBlockerGeometry.Kind.WALL, "kind code decodes without colliding with empty zero")
	_check(data.mask_at(Vector2i(1, 2)) == 10, "wall mask is retained")
	_check(data.variant_at(Vector2i(1, 2)) == 0, "blocker variant is retained")
	_check(data.occupied_indices() == PackedInt32Array([9]), "occupied index is recorded once")
	_check(data.cell_for_index(9) == Vector2i(1, 2), "occupied index converts back to its local cell")
	_check(data.kind_at(Vector2i(0, 0)) == -1, "empty cell decodes to no blocker")
	_check(not data.add_blocker(Vector2i(-1, 0), WorldBlockerGeometry.Kind.WALL), "negative local cell is rejected")
	_check(not data.add_blocker(Vector2i(4, 0), WorldBlockerGeometry.Kind.WALL), "cell outside chunk width is rejected")


func _test_floor_stamps() -> void:
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_floor_stamp(Rect2i(2, 3, 5, 7), 4, 0.75, -93)
	_check(data.floor_stamp_count() == 1, "floor rectangle is retained as one descriptor")
	_check(data.floor_rect_and_style == PackedInt32Array([2, 3, 5, 7, 4, -93]), "floor rectangle and style remain packed together")
	_check(data.floor_alpha == PackedFloat32Array([0.75]), "floor alpha is retained without a node")


func _test_wall_catalog() -> void:
	# The legacy top-down set, still selectable behind the kit flag.
	var kit_was := ChunkBlockVisualCatalog.three_quarter_walls
	ChunkBlockVisualCatalog.three_quarter_walls = false
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 5)).ends_with("wall_stone_straight_v.png"), "vertical wall mask selects vertical texture")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 10)).ends_with("wall_stone_straight_h.png"), "horizontal wall mask selects horizontal texture")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 3)).ends_with("wall_stone_corner_ne.png"), "north-east wall mask selects matching corner")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 15)).ends_with("wall_stone_cross.png"), "four-way wall mask selects cross texture")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WINDOW, 5)).ends_with("wall_stone_window_v.png"), "vertical window selects window texture")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WINDOW, 3)).ends_with("wall_stone_corner_ne.png"), "unsupported window mask falls back to matching full wall")
	# 17 wall/window pieces, the Phase 3 face, and 8 half-cover variants.
	_check(ChunkBlockVisualCatalog.texture_count() == 26, "legacy catalog reports 18 wall and 8 half-cover texture variants")
	_check(ChunkBlockVisualCatalog.face_texture(WorldBlockerGeometry.Kind.WALL, 10) != null, "legacy walls hang a separate face under an exposed edge")
	# The three-quarter kit (default): one baked piece per connection mask.
	ChunkBlockVisualCatalog.three_quarter_walls = true
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 5)).ends_with("kit/wall34_05.png"), "kit: vertical wall mask selects its piece")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 10)).ends_with("kit/wall34_10.png"), "kit: horizontal wall mask selects its piece")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 3)).ends_with("kit/wall34_03.png"), "kit: north-east corner selects its piece")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 15)).ends_with("kit/wall34_15.png"), "kit: four-way mask selects its piece")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WINDOW, 5)).ends_with("kit/wall34_window_v.png"), "kit: vertical window selects the barred piece")
	_check(_texture_path(ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WINDOW, 3)).ends_with("kit/wall34_03.png"), "kit: unsupported window mask falls back to the wall piece")
	_check(ChunkBlockVisualCatalog.face_texture(WorldBlockerGeometry.Kind.WALL, 10) == null, "kit: faces are baked into the pieces, never hung separately")
	var piece := ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 0)
	_check(is_equal_approx(ChunkBlockVisualCatalog.cell_scale(piece).x * piece.get_width(), 64.0), "kit: a piece draws exactly one cell wide")
	_check(is_equal_approx(ChunkBlockVisualCatalog.cell_scale(piece).y * piece.get_height(), 64.0 + ChunkBlockVisualCatalog.KIT_HEIGHT), "kit: a piece draws one cell plus the wall height tall")
	# Rhythm: a straight run gets a buttress every PIER_SPACING cells and
	# the same cell always gets the same piece.
	var piers := 0
	for x in range(0, 60):
		var run_piece := ChunkBlockVisualCatalog.wall_texture_at(WorldBlockerGeometry.Kind.WALL, 10, Vector2i(x, 3))
		if run_piece == ChunkBlockVisualCatalog.KIT_PIER_H:
			piers += 1
	_check(piers == 10, "kit: a 60-cell straight run carries a buttress every 6 cells (%d)" % piers)
	_check(ChunkBlockVisualCatalog.wall_texture_at(WorldBlockerGeometry.Kind.WALL, 10, Vector2i(17, -4)) == ChunkBlockVisualCatalog.wall_texture_at(WorldBlockerGeometry.Kind.WALL, 10, Vector2i(17, -4)), "kit: rhythm is deterministic per cell")
	_check(ChunkBlockVisualCatalog.wall_texture_at(WorldBlockerGeometry.Kind.WALL, 3, Vector2i(0, 0)) == ChunkBlockVisualCatalog.wall_texture(WorldBlockerGeometry.Kind.WALL, 3), "kit: corners never take a rhythm variant")
	_check(ChunkBlockVisualCatalog.wall_texture_at(WorldBlockerGeometry.Kind.WINDOW, 10, Vector2i(0, 0)) == ChunkBlockVisualCatalog.KIT_WIN_H, "kit: windows never take a rhythm variant")
	ChunkBlockVisualCatalog.three_quarter_walls = kit_was


func _test_half_cover_catalog() -> void:
	var first := ChunkBlockVisualCatalog.half_variant(Vector2(32, 32))
	var second := ChunkBlockVisualCatalog.half_variant(Vector2(96, 160))
	var negative := ChunkBlockVisualCatalog.half_variant(Vector2(-32, 96))
	_check(first == 11, "legacy half-cover RNG encodes texture 3 and quarter-turn 1 at 32,32")
	_check(second == 25, "legacy half-cover RNG encodes texture 1 and quarter-turn 3 at 96,160")
	_check(negative == 13, "legacy half-cover RNG remains stable for negative world coordinates")
	_check(_texture_path(ChunkBlockVisualCatalog.half_texture(first)).ends_with("prop_rubble_small_01.png"), "packed half-cover variant selects its legacy texture")
	_check(is_equal_approx(ChunkBlockVisualCatalog.half_rotation(first), PI * 0.5), "packed half-cover variant selects its legacy rotation")
	_check(ChunkBlockVisualCatalog.texture_count() == 34, "kit catalog reports 16 pieces, 2 windows, 4 rhythm variants, 4 fills and 8 half-cover variants")


func _texture_path(texture: Texture2D) -> String:
	return "" if texture == null else texture.resource_path
