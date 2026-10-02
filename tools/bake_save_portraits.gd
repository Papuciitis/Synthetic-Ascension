extends "res://tools/bake_character_atlases.gd"
## Bakes one standing portrait per race for the Archive cards: the idle "down"
## body with its head on the collar, composited exactly as PlayerVisualController
## does in game, but cut from the source sheets at PORTRAIT_SCALE times the game
## size, so the card shows the painted character rather than an enlarged sprite.
##
##     godot --headless --path . -s tools/bake_save_portraits.gd
##     godot --headless --path . --import
##
## Output: assets/textures/characters/portraits/<race_id>.png. SaveCard shows
## that file for the save's race, so dedicated portrait art can replace a
## baked one simply by overwriting it (keep the feet on the bottom edge and
## the figure centred).

const PORTRAIT_DIR := "res://assets/textures/characters/portraits"
## Times the in-game size (a 48 px body becomes ~230 px).
const PORTRAIT_SCALE := 4.8
const PAD := 6


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PORTRAIT_DIR))
	for path in RACE_DEFINITIONS:
		var definition := load(path) as RaceVisualDefinition
		if definition == null:
			_fail("cannot load " + path)
			continue
		_bake_portrait(definition)
	if _failures > 0:
		push_error("portrait bake finished with %d failure(s)" % _failures)
	else:
		print("portrait bake finished cleanly")
	quit(1 if _failures > 0 else 0)


func _bake_portrait(definition: RaceVisualDefinition) -> void:
	var race := String(definition.race_id)
	var idle := _load_sheet(definition.idle_sheet)
	var head := _load_sheet(definition.head_sheet)
	if idle == null or head == null:
		_fail("%s: missing sheet" % race)
		return
	var idle_down := _first_cell(definition.idle_cells, "down")
	var idle_band := _band(idle, idle_down.x)
	var idle_scale := definition.idle_height_px / float(idle_band.y - idle_band.x)
	var head_down: Vector2i = definition.head_cells.get("down", Vector2i.ZERO)
	var head_cell := _cell_sheet(head, head_down.x, head_down.y, definition.head_columns)
	var head_scale := definition.head_height_px / float(_bbox(head_cell, _whole(head_cell)).size.y)

	var body := _cut_body(idle, idle_down.x, idle_down.y, definition.idle_columns, idle_scale * PORTRAIT_SCALE)
	var face := _cut_head(head, head_down.x, head_down.y, definition.head_columns, head_scale * PORTRAIT_SCALE, false)
	# Origin = the feet under the collar. The head hangs from its scarf at the
	# body's collar plus the definition's per-facing nudge, both scaled up.
	var body_origin := -body.anchor
	var head_hang := body.collar + definition.head_offset(&"down") * PORTRAIT_SCALE
	var head_origin := head_hang - face.anchor
	var top_left := Vector2(minf(body_origin.x, head_origin.x), minf(body_origin.y, head_origin.y))
	var bottom_right := Vector2(
		maxf(body_origin.x + body.image.get_width(), head_origin.x + face.image.get_width()),
		maxf(body_origin.y + body.image.get_height(), head_origin.y + face.image.get_height()))
	# Centre the feet: equal room either side of the origin.
	var half_width := maxf(-top_left.x, bottom_right.x)
	var width := int(ceil(half_width * 2.0)) + PAD * 2
	var height := int(ceil(bottom_right.y - top_left.y)) + PAD * 2
	var canvas := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var origin := Vector2(width * 0.5, height - PAD - bottom_right.y)
	_blend(canvas, body.image, origin + body_origin)
	_blend(canvas, face.image, origin + head_origin)
	var out_path := "%s/%s.png" % [PORTRAIT_DIR, race]
	var err := canvas.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		_fail("%s: cannot write %s (%s)" % [race, out_path, error_string(err)])
		return
	print("  %s portrait %dx%d" % [race, width, height])


func _blend(canvas: Image, layer: Image, at: Vector2) -> void:
	var src := layer
	if src.get_format() != Image.FORMAT_RGBA8:
		src = layer.duplicate() as Image
		src.convert(Image.FORMAT_RGBA8)
	canvas.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(roundi(at.x), roundi(at.y)))
