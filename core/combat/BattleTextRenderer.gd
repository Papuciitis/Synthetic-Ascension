extends Node2D

# Batched floating combat text (damage numbers, EVADED, LUCKY, ...).
# The genre shows hundreds of hits per second, so this follows the same
# architecture as the batched bullets/impacts: every entry is drawn from
# ONE canvas item in a ring buffer — no Label nodes, no per-hit churn.
# Autoloaded as BattleText; world-positioned like the other autoload
# renderers (ProjectileManager).
#
# Per-frame damage to one target should be merged by the CALLER where a
# natural key exists (EnemyCombat's hit ledgers already do this); the
# `merge_key` here additionally coalesces rapid repeat damage (DoT ticks)
# into one climbing number instead of a stack of overlapping ones.

const MAX_ENTRIES := 96
const RISE_SPEED := 46.0
const LIFETIME := 0.7
const CRIT_LIFETIME := 0.95
const MERGE_WINDOW := 0.35

var _texts: PackedStringArray = PackedStringArray()
var _positions := PackedVector2Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _colors: PackedColorArray = PackedColorArray()
var _scales := PackedFloat32Array()
var _amounts := PackedFloat32Array()
var _keys: Array[int] = []
# Shaped text cache: draw_string() re-shapes and re-rasterises every entry
# every frame (twice, with the outline). A TextLine per slot is shaped once
# and only rebuilt when its text or font size changes (crit pop, merges).
var _lines: Array[TextLine] = []
var _line_texts: PackedStringArray = PackedStringArray()
var _line_sizes := PackedInt32Array()
var _count := 0
var _overwrite_slot := 0
var _font: Font = null


func _ready() -> void:
	z_index = 1000
	_font = ThemeDB.fallback_font
	_texts.resize(MAX_ENTRIES)
	_positions.resize(MAX_ENTRIES)
	_ages.resize(MAX_ENTRIES)
	_lifetimes.resize(MAX_ENTRIES)
	_colors.resize(MAX_ENTRIES)
	_scales.resize(MAX_ENTRIES)
	_amounts.resize(MAX_ENTRIES)
	_keys.resize(MAX_ENTRIES)
	_lines.resize(MAX_ENTRIES)
	_line_texts.resize(MAX_ENTRIES)
	_line_sizes.resize(MAX_ENTRIES)
	set_process(false)


func enabled() -> bool:
	if SettingsManager == null:
		return true
	return bool(SettingsManager.get_value(&"accessibility", &"damage_numbers", true))


## Named callouts - LUCKY, EVADED, a Manifestation firing - are a different
## channel from the damage stream and get their own setting. Gating them on
## `damage_numbers` meant a player who turned the number spam off also turned
## off every word the Manifestation layer says.
func callouts_enabled() -> bool:
	if SettingsManager == null:
		return true
	return bool(SettingsManager.get_value(&"accessibility", &"ability_callouts", true))


func damage(world_pos: Vector2, amount: float, crit: bool = false, merge_key: int = 0) -> void:
	if amount < 0.5 or not enabled():
		return
	if merge_key != 0:
		for i in range(_count):
			if _keys[i] == merge_key and _ages[i] < MERGE_WINDOW:
				_amounts[i] += amount
				_texts[i] = _format_amount(_amounts[i])
				_positions[i] = world_pos + Vector2(0.0, -20.0)
				_ages[i] = 0.0
				queue_redraw()
				return
	var color := Color(1.0, 0.84, 0.25, 1.0) if crit else Color(0.98, 0.96, 0.92, 1.0)
	var entry_scale := 1.35 if crit else 1.0
	_spawn(
		_format_amount(amount),
		world_pos + Vector2(0.0, -20.0),
		color,
		entry_scale,
		CRIT_LIFETIME if crit else LIFETIME,
		amount,
		merge_key
	)


func player_damage(world_pos: Vector2, amount: float) -> void:
	if amount < 0.5 or not enabled():
		return
	_spawn(_format_amount(amount), world_pos + Vector2(0.0, -30.0), Color(1.0, 0.35, 0.3, 1.0), 1.15, LIFETIME, amount, 0)


func progress(world_pos: Vector2, text: String, merge_key: int, color: Color = Color(0.82, 0.88, 1.0, 1.0)) -> void:
	# Compact combat feed toast: successive feeds of the same item REPLACE
	# one floating line instead of stacking (K6 combat/inspection split —
	# full math lives in the tooltip, this just says what happened).
	if not callouts_enabled():
		return
	if merge_key != 0:
		for i in range(_count):
			if _keys[i] == merge_key:
				_texts[i] = text
				_positions[i] = world_pos + Vector2(0.0, -34.0)
				_ages[i] = 0.0
				_lifetimes[i] = 1.3
				queue_redraw()
				return
	_spawn(text, world_pos + Vector2(0.0, -34.0), color, 1.0, 1.3, 0.0, merge_key)


func popup(world_pos: Vector2, text: String, color: Color, entry_scale: float = 1.0, merge_key: int = 0) -> void:
	# `entry_scale` is authored emphasis that scales with the payout - Broken
	# Providence with the bank, Stored Violence with the charge - so a popup is
	# NOT a progress() with a different colour and must not be routed through
	# one. `merge_key` is opt-in: a rule that can fire the same line several
	# times in a second replaces its own line instead of stacking, but two
	# different lines from one rule still both get read.
	if not callouts_enabled():
		return
	if merge_key != 0:
		for i in range(_count):
			if _keys[i] == merge_key:
				_texts[i] = text
				_positions[i] = world_pos + Vector2(0.0, -34.0)
				_ages[i] = 0.0
				_lifetimes[i] = 0.9
				_colors[i] = color
				_scales[i] = entry_scale
				queue_redraw()
				return
	_spawn(text, world_pos + Vector2(0.0, -34.0), color, entry_scale, 0.9, 0.0, merge_key)


func _spawn(text: String, world_pos: Vector2, color: Color, entry_scale: float, lifetime: float, amount: float, merge_key: int) -> void:
	var slot: int
	if _count < MAX_ENTRIES:
		slot = _count
		_count += 1
	else:
		slot = _overwrite_slot
		_overwrite_slot = (_overwrite_slot + 1) % MAX_ENTRIES
	# Small deterministic-ish x jitter so stacked hits fan out.
	var jitter := float((Time.get_ticks_usec() % 17) - 8)
	_texts[slot] = text
	_positions[slot] = world_pos + Vector2(jitter, 0.0)
	_ages[slot] = 0.0
	_lifetimes[slot] = lifetime
	_colors[slot] = color
	_scales[slot] = entry_scale
	_amounts[slot] = amount
	_keys[slot] = merge_key
	set_process(true)
	queue_redraw()


func _format_amount(amount: float) -> String:
	var value := int(round(amount))
	if value >= 10000:
		return "%.0fk" % (float(value) / 1000.0)
	if value >= 1000:
		return "%.1fk" % (float(value) / 1000.0)
	return str(value)


func _process(delta: float) -> void:
	var i := 0
	while i < _count:
		_ages[i] += delta
		if _ages[i] >= _lifetimes[i]:
			var last := _count - 1
			_texts[i] = _texts[last]
			_positions[i] = _positions[last]
			_ages[i] = _ages[last]
			_lifetimes[i] = _lifetimes[last]
			_colors[i] = _colors[last]
			_scales[i] = _scales[last]
			_amounts[i] = _amounts[last]
			_keys[i] = _keys[last]
			# Swap (not overwrite) the shaped line so every slot keeps its
			# TextLine for the node's lifetime instead of reallocating per hit.
			var expired_line := _lines[i]
			var expired_text := _line_texts[i]
			var expired_size := _line_sizes[i]
			_lines[i] = _lines[last]
			_line_texts[i] = _line_texts[last]
			_line_sizes[i] = _line_sizes[last]
			_lines[last] = expired_line
			_line_texts[last] = expired_text
			_line_sizes[last] = expired_size
			_count = last
			continue
		i += 1
	if _count == 0:
		set_process(false)
	queue_redraw()


func clear() -> void:
	_count = 0
	set_process(false)
	queue_redraw()


func _exit_tree() -> void:
	# Release the shaped lines (TextServer RIDs) while the server is still up;
	# script members are otherwise destroyed during script-server teardown,
	# after the TextServer may already be gone.
	_count = 0
	for i in range(_lines.size()):
		_lines[i] = null
	_font = null


func _draw() -> void:
	if _font == null:
		return
	var canvas := get_canvas_item()
	for i in range(_count):
		var life_t := clampf(_ages[i] / maxf(_lifetimes[i], 0.01), 0.0, 1.0)
		var alpha := 1.0 if life_t < 0.55 else 1.0 - (life_t - 0.55) / 0.45
		# Crit pop: brief overshoot at birth.
		var pop := 1.0 + maxf(0.0, 0.25 - _ages[i] * 2.0) * (_scales[i] - 1.0) * 4.0
		var font_size := int(round(15.0 * _scales[i] * pop))
		var pos := _positions[i] + Vector2(0.0, -RISE_SPEED * _ages[i])
		var draw_pos := pos + Vector2(-100.0, 0.0)
		var color := _colors[i]
		color.a = alpha
		var outline := Color(0.05, 0.05, 0.08, alpha * 0.9)
		var line := _shaped_line(i, font_size)
		# TextLine draws from the top-left of its box; draw_string took the
		# baseline. Keep the numbers where they were.
		var line_pos := draw_pos - Vector2(0.0, line.get_line_ascent())
		line.draw_outline(canvas, line_pos, 4, outline)
		line.draw(canvas, line_pos, color)


func _shaped_line(slot: int, font_size: int) -> TextLine:
	var line := _lines[slot]
	if line != null and _line_sizes[slot] == font_size and _line_texts[slot] == _texts[slot]:
		return line
	if line == null:
		line = TextLine.new()
		line.width = 200.0
		line.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lines[slot] = line
	else:
		line.clear()
	line.add_string(_texts[slot], _font, font_size)
	_line_texts[slot] = _texts[slot]
	_line_sizes[slot] = font_size
	return line
