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
#
# Callouts (popup / progress) stack instead of piling up. Every callout
# raised at about the same spot joins one COLUMN: the newest line enters at
# the column's base and every older line still alive there is pushed up far
# enough to clear the line below it, eased rather than snapped. Lines keep
# rising and fading as before, so a column reads as a list scrolling up and
# away, and a line pushed past the column's ceiling fades out early - a burst
# of ten Manifestations shows the latest five or six, never a tower.
# Callouts at the player join the player's column, which follows the
# character; callouts anywhere else (an enemy, a vault) form a column that
# stays where it was raised. Damage numbers never join a column.

const MAX_ENTRIES := 96
const RISE_SPEED := 46.0
const LIFETIME := 0.7
const CRIT_LIFETIME := 0.95
const DAMAGE_COLOR := Color(0.98, 0.96, 0.92, 1.0)
const CRIT_COLOR := Color(1.0, 0.84, 0.25, 1.0)
const CRIT_SCALE := 1.35
const MERGE_WINDOW := 0.35
## Font size of an entry at scale 1.0.
const FONT_SIZE := 15.0
## Shaped line box. Wide enough that a long callout ("THE DISTRICT SHIFTS -
## ...") stays centred and whole: at 200 px TextLine's default ellipsis cut it.
const LINE_WIDTH := 480.0

## Callouts sit this far above the point they were raised at.
const CALLOUT_RAISE := Vector2(0.0, -34.0)
## Column ids are 1-based (0 = none): PLAYER_COLUMN is the player's, the rest
## are world anchors. With all of them busy a callout floats free, the way
## every callout used to.
const MAX_COLUMNS := 12
const PLAYER_COLUMN := 1
## A callout raised this close to the player joins the player's column. Wide
## enough for the item lines that nudge their own text up a little.
const PLAYER_JOIN_RADIUS := 48.0
## A world callout this close to a live column's base joins that column.
const COLUMN_JOIN_RADIUS := 40.0
## How far a line may rise (drift plus push) before it starts fading, and over
## how many pixels above that it is gone. A lone callout drifts at most ~60 px
## in its life, so only a pushed line ever reaches the ceiling.
const COLUMN_CEILING := 96.0
const COLUMN_FADE_SPAN := 24.0
## Rate (1/s) of the push's exponential ease, ~90% there in 0.1 s, with a
## floor speed (px/s) so the last pixels land instead of creeping forever.
const COLUMN_EASE_RATE := 24.0
const COLUMN_EASE_MIN_SPEED := 60.0
## A line's box for stacking, in ems of its font size: capitals and ascenders
## above the baseline, descenders below, plus half the 4 px outline each side.
const LINE_ASCENT_EM := 0.76
const LINE_DESCENT_EM := 0.24
const LINE_PAD := 2.0
## Damage TAKEN falls from the player's side instead of rising: the air above
## the character is the callout column's, and a number rising at the same
## speed as the lines would sit on top of one for its whole life.
const PLAYER_DAMAGE_OFFSET := Vector2(18.0, -12.0)
const FALLING := -1

var _texts: PackedStringArray = PackedStringArray()
var _positions := PackedVector2Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _colors: PackedColorArray = PackedColorArray()
var _scales := PackedFloat32Array()
var _amounts := PackedFloat32Array()
var _keys: Array[int] = []
# Column of each entry (0 = free-floating, FALLING = damage taken) and how far
# it has been pushed up the column: _lifts eases toward _lift_targets, and
# never past it.
var _columns := PackedInt32Array()
var _lifts := PackedFloat32Array()
var _lift_targets := PackedFloat32Array()
# Shaped text cache: draw_string() re-shapes and re-rasterises every entry
# every frame (twice, with the outline). A TextLine per slot is shaped once
# and only rebuilt when its text or font size changes (crit pop, merges).
var _lines: Array[TextLine] = []
var _line_texts: PackedStringArray = PackedStringArray()
var _line_sizes := PackedInt32Array()
var _count := 0
var _overwrite_slot := 0
var _font: Font = null

# Column bases (world) and live line counts by id - 1, recounted every frame.
# The player's base is re-read from the player each frame its column is in use.
var _column_bases := PackedVector2Array()
var _column_members := PackedInt32Array()
var _player_id := 0
# Scratch for stacking one column, sized once.
var _stack_slots := PackedInt32Array()
var _stack_lifts := PackedFloat32Array()


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
	_columns.resize(MAX_ENTRIES)
	_lifts.resize(MAX_ENTRIES)
	_lift_targets.resize(MAX_ENTRIES)
	_lines.resize(MAX_ENTRIES)
	_line_texts.resize(MAX_ENTRIES)
	_line_sizes.resize(MAX_ENTRIES)
	_column_bases.resize(MAX_COLUMNS)
	_column_members.resize(MAX_COLUMNS)
	_stack_slots.resize(MAX_ENTRIES)
	_stack_lifts.resize(MAX_ENTRIES)
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
				# A crit that lands on a number still climbing used to vanish
				# into it, white and small: the 1% event the player most wants
				# to see. It promotes the merged number (never the reverse), and
				# the reset age replays the crit pop.
				if crit:
					_colors[i] = CRIT_COLOR
					_scales[i] = CRIT_SCALE
					_lifetimes[i] = CRIT_LIFETIME
				queue_redraw()
				return
	var color := CRIT_COLOR if crit else DAMAGE_COLOR
	var entry_scale := CRIT_SCALE if crit else 1.0
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
	var slot := _spawn(_format_amount(amount), world_pos + PLAYER_DAMAGE_OFFSET, Color(1.0, 0.35, 0.3, 1.0), 1.15, LIFETIME, amount, 0)
	_columns[slot] = FALLING


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
				_refresh_callout(i, world_pos, 1.3)
				queue_redraw()
				return
	var slot := _spawn(text, world_pos + CALLOUT_RAISE, color, 1.0, 1.3, 0.0, merge_key)
	_stack_callout(slot, world_pos)


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
				_colors[i] = color
				_scales[i] = entry_scale
				_refresh_callout(i, world_pos, 0.9)
				queue_redraw()
				return
	var slot := _spawn(text, world_pos + CALLOUT_RAISE, color, entry_scale, 0.9, 0.0, merge_key)
	_stack_callout(slot, world_pos)


func _spawn(text: String, world_pos: Vector2, color: Color, entry_scale: float, lifetime: float, amount: float, merge_key: int) -> int:
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
	_columns[slot] = 0
	_lifts[slot] = 0.0
	_lift_targets[slot] = 0.0
	set_process(true)
	queue_redraw()
	return slot


func _format_amount(amount: float) -> String:
	var value := int(round(amount))
	if value >= 10000:
		return "%.0fk" % (float(value) / 1000.0)
	if value >= 1000:
		return "%.1fk" % (float(value) / 1000.0)
	return str(value)


# ---------------------------------------------------------------------------
# Callout columns
#
# All the stacking work happens when a callout is raised (a few times a second
# at most); a frame only eases each pushed line toward its target and moves
# the player's column with the player. Drift (RISE_SPEED * age) is the same for
# every line, so the gap a push opens never closes again on its own.
# ---------------------------------------------------------------------------

## Put a freshly spawned callout at the base of its column and push the
## column's older lines up to make room.
func _stack_callout(slot: int, world_pos: Vector2) -> void:
	var column := _column_for(world_pos)
	if column == 0:
		return
	_columns[slot] = column
	_column_members[column - 1] += 1
	_positions[slot] = _column_bases[column - 1]
	_settle_column(column, slot)


## A merged callout updates IN PLACE: same height in its column, no push. Its
## drift so far is folded into its lift so resetting its age does not drop it
## onto the line below. A merge raised somewhere else entirely moves the line
## there, as the newest of that spot's column.
func _refresh_callout(slot: int, world_pos: Vector2, lifetime: float) -> void:
	var column := _columns[slot]
	if column > 0 and column == _column_for(world_pos):
		var drift := RISE_SPEED * _ages[slot]
		_lifts[slot] += drift
		_lift_targets[slot] += drift
		_ages[slot] = 0.0
		_lifetimes[slot] = lifetime
		# A merge that grew the line must still clear its neighbours.
		_settle_column(column, -1)
		return
	_positions[slot] = world_pos + CALLOUT_RAISE
	_ages[slot] = 0.0
	_lifetimes[slot] = lifetime
	_columns[slot] = 0
	_lifts[slot] = 0.0
	_lift_targets[slot] = 0.0
	_stack_callout(slot, world_pos)


## Column id (1-based; 0 = none free) for a callout raised at `world_pos`,
## claiming a free slot for a new world column when nothing live is close.
func _column_for(world_pos: Vector2) -> int:
	var player := _player_node()
	if player != null and world_pos.distance_squared_to(player.global_position) <= PLAYER_JOIN_RADIUS * PLAYER_JOIN_RADIUS:
		_column_bases[PLAYER_COLUMN - 1] = player.global_position + CALLOUT_RAISE
		return PLAYER_COLUMN
	var base := world_pos + CALLOUT_RAISE
	var best := 0
	var best_distance := COLUMN_JOIN_RADIUS * COLUMN_JOIN_RADIUS
	var free := 0
	# World columns: ids PLAYER_COLUMN + 1 and up, so indices PLAYER_COLUMN up.
	for index in range(PLAYER_COLUMN, MAX_COLUMNS):
		if _column_members[index] <= 0:
			if free == 0:
				free = index + 1
			continue
		var distance := base.distance_squared_to(_column_bases[index])
		if distance <= best_distance:
			best_distance = distance
			best = index + 1
	if best != 0:
		return best
	if free != 0:
		_column_bases[free - 1] = base
	return free


## Push lines up until none overlaps the one below it. `floor_slot` is a line
## entering at the base (it stays put, even against a line of the same age:
## the first of a same-frame burst ends on top); -1 re-settles a column in
## its current order. Lines only ever move UP.
func _settle_column(column: int, floor_slot: int) -> void:
	var n := 0
	var fixed := 0
	if floor_slot >= 0:
		_stack_slots[0] = floor_slot
		_stack_lifts[0] = RISE_SPEED * _ages[floor_slot] + _lift_targets[floor_slot]
		n = 1
		fixed = 1
	# Gather the column bottom-up by height. Columns are a handful of lines,
	# so an insertion sort into preallocated scratch is the cheap option.
	for i in range(_count):
		if _columns[i] != column or i == floor_slot:
			continue
		var lift := RISE_SPEED * _ages[i] + _lift_targets[i]
		var at := n
		while at > fixed and _stack_lifts[at - 1] > lift:
			_stack_slots[at] = _stack_slots[at - 1]
			_stack_lifts[at] = _stack_lifts[at - 1]
			at -= 1
		_stack_slots[at] = i
		_stack_lifts[at] = lift
		n += 1
	var instant := _reduced_motion()
	for k in range(1, n):
		var slot := _stack_slots[k]
		var below := _stack_slots[k - 1]
		var need := _stack_lifts[k - 1] + FONT_SIZE * (_scales[slot] * LINE_DESCENT_EM + _scales[below] * LINE_ASCENT_EM) + LINE_PAD * 2.0
		if _stack_lifts[k] < need:
			_lift_targets[slot] += need - _stack_lifts[k]
			_stack_lifts[k] = need
		if instant:
			_lifts[slot] = _lift_targets[slot]


func _player_node() -> Node2D:
	var player: Node2D = null
	if _player_id != 0:
		player = instance_from_id(_player_id) as Node2D
		if player != null and player.is_inside_tree() and player.is_in_group(&"player"):
			return player
	_player_id = 0
	if not is_inside_tree():
		return null
	player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		_player_id = player.get_instance_id()
	return player


## Reduced Motion makes the push instant instead of eased.
func _reduced_motion() -> bool:
	if SettingsManager == null:
		return false
	return bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))


func _process(delta: float) -> void:
	# The player's column follows the player: its base is re-read once here
	# and every line in it shares that base.
	if _column_members[PLAYER_COLUMN - 1] > 0:
		var player := _player_node()
		if player != null:
			_column_bases[PLAYER_COLUMN - 1] = player.global_position + CALLOUT_RAISE
	var player_base := _column_bases[PLAYER_COLUMN - 1]
	_column_members.fill(0)
	var ease := 1.0 - exp(-COLUMN_EASE_RATE * delta)
	var ease_floor := COLUMN_EASE_MIN_SPEED * delta
	var i := 0
	while i < _count:
		var age := _ages[i] + delta
		_ages[i] = age
		if age >= _lifetimes[i]:
			_remove_at(i)
			continue
		# Damage numbers stop at this one read; only callouts carry a column.
		var column := _columns[i]
		if column > 0:
			var lift := _lifts[i]
			var target := _lift_targets[i]
			if lift < target:
				lift = minf(target, lift + maxf((target - lift) * ease, ease_floor))
				_lifts[i] = lift
			if column == PLAYER_COLUMN:
				_positions[i] = player_base
			# Pushed out of the top of its column: already faded to nothing.
			if RISE_SPEED * age + lift >= COLUMN_CEILING + COLUMN_FADE_SPAN:
				_remove_at(i)
				continue
			_column_members[column - 1] += 1
		i += 1
	if _count == 0:
		set_process(false)
	queue_redraw()


## Retire entry `slot` by moving the last entry into it.
func _remove_at(slot: int) -> void:
	var last := _count - 1
	_texts[slot] = _texts[last]
	_positions[slot] = _positions[last]
	_ages[slot] = _ages[last]
	_lifetimes[slot] = _lifetimes[last]
	_colors[slot] = _colors[last]
	_scales[slot] = _scales[last]
	_amounts[slot] = _amounts[last]
	_keys[slot] = _keys[last]
	_columns[slot] = _columns[last]
	_lifts[slot] = _lifts[last]
	_lift_targets[slot] = _lift_targets[last]
	# Swap (not overwrite) the shaped line so every slot keeps its
	# TextLine for the node's lifetime instead of reallocating per hit.
	var expired_line := _lines[slot]
	var expired_text := _line_texts[slot]
	var expired_size := _line_sizes[slot]
	_lines[slot] = _lines[last]
	_line_texts[slot] = _line_texts[last]
	_line_sizes[slot] = _line_sizes[last]
	_lines[last] = expired_line
	_line_texts[last] = expired_text
	_line_sizes[last] = expired_size
	_count = last


func clear() -> void:
	_count = 0
	_column_members.fill(0)
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
		var rise := RISE_SPEED * _ages[i]
		var column := _columns[i]
		if column > 0:
			rise += _lifts[i]
			# Past the column's ceiling a line fades out over the span.
			if rise > COLUMN_CEILING:
				alpha = minf(alpha, 1.0 - (rise - COLUMN_CEILING) / COLUMN_FADE_SPAN)
				if alpha <= 0.0:
					continue
		elif column == FALLING:
			rise = -rise
		# Crit pop: brief overshoot at birth.
		var pop := 1.0 + maxf(0.0, 0.25 - _ages[i] * 2.0) * (_scales[i] - 1.0) * 4.0
		var font_size := int(round(FONT_SIZE * _scales[i] * pop))
		if column > 0 and pop > 1.0:
			# In a column the pop grows DOWN from the line's top edge rather
			# than up into the line it just pushed, which is still easing away.
			rise -= (float(font_size) - FONT_SIZE * _scales[i]) * LINE_ASCENT_EM
		var draw_pos := _positions[i] + Vector2(-LINE_WIDTH * 0.5, -rise)
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
		line.width = LINE_WIDTH
		line.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_lines[slot] = line
	else:
		line.clear()
	line.add_string(_texts[slot], _font, font_size)
	_line_texts[slot] = _texts[slot]
	_line_sizes[slot] = font_size
	return line


# ---------------------------------------------------------------------------
# Read-back for tests and probes (mirrors _draw; never called per frame)
# ---------------------------------------------------------------------------

## Baseline centre of entry `slot` as it is drawn right now (the birth pop's
## brief offset left out).
func drawn_position(slot: int) -> Vector2:
	var rise := RISE_SPEED * _ages[slot]
	if _columns[slot] > 0:
		rise += _lifts[slot]
	elif _columns[slot] == FALLING:
		rise = -rise
	return _positions[slot] + Vector2(0.0, -rise)


## Top and bottom (world y) of entry `slot`'s stacking box as drawn now.
func drawn_extent(slot: int) -> Vector2:
	var baseline := drawn_position(slot).y
	var size := FONT_SIZE * _scales[slot]
	return Vector2(baseline - size * LINE_ASCENT_EM - LINE_PAD, baseline + size * LINE_DESCENT_EM + LINE_PAD)


## Opacity entry `slot` is drawn with right now (0 = not drawn).
func drawn_alpha(slot: int) -> float:
	var life_t := clampf(_ages[slot] / maxf(_lifetimes[slot], 0.01), 0.0, 1.0)
	var alpha := 1.0 if life_t < 0.55 else 1.0 - (life_t - 0.55) / 0.45
	if _columns[slot] > 0:
		var rise := RISE_SPEED * _ages[slot] + _lifts[slot]
		if rise > COLUMN_CEILING:
			alpha = minf(alpha, 1.0 - (rise - COLUMN_CEILING) / COLUMN_FADE_SPAN)
	return maxf(alpha, 0.0)
