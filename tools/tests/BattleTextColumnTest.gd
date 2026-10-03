extends Node

# Callouts raised at one spot used to pile on top of each other: every
# Manifestation popup spawned at the player and rose at the same speed, so
# rules firing a few frames apart sat a few pixels apart and none could be
# read. BattleText now stacks them into a column - newest at the base, older
# lines pushed up and fading - and this pins that on the real autoload:
# bursts over several frames and in one frame never overlap and keep the
# oldest on top, mixed emphasis sizes clear each other, a merged line updates
# in place without pushing, the column is capped, the player's column follows
# the player while a world column stays put, Reduced Motion makes the push
# instant, and damage numbers stay out of it.
#
# Synchronous throughout: time only moves when the test steps BattleText's
# _process itself, so nothing expires behind its back.
#
# Run: <godot> --headless --path . res://tools/tests/BattleTextColumnTest.tscn

const DT := 1.0 / 60.0

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var previous := {
		&"ability_callouts": SettingsManager.get_value(&"accessibility", &"ability_callouts", true),
		&"damage_numbers": SettingsManager.get_value(&"accessibility", &"damage_numbers", true),
		&"reduced_motion": SettingsManager.get_value(&"accessibility", &"reduced_motion", false),
	}
	SettingsManager.set_value(&"accessibility", &"ability_callouts", true, false)
	SettingsManager.set_value(&"accessibility", &"damage_numbers", true, false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)

	_test_burst_over_frames()
	_test_same_frame_burst()
	_test_mixed_sizes()
	_test_merge_updates_in_place()
	_test_column_is_capped()
	_test_separate_anchors()
	_test_player_column_follows()
	_test_reduced_motion_is_instant()
	_test_damage_numbers_stay_out()
	_test_progress_joins_and_merges()

	BattleText.clear()
	for key in previous:
		SettingsManager.set_value(&"accessibility", key, previous[key], false)
	print("BattleTextColumnTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _step(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		BattleText._process(minf(DT, left))
		left -= DT


func _slot_of(text: String) -> int:
	for i in range(BattleText._count):
		if BattleText._texts[i] == text:
			return i
	return -1


## Slots of `texts`, -1 for a line no longer alive.
func _slots_of(texts: Array) -> Array[int]:
	var out: Array[int] = []
	for text in texts:
		out.append(_slot_of(String(text)))
	return out


func _live(slots: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for slot in slots:
		if slot >= 0:
			out.append(slot)
	return out


## No two live lines' boxes intersect.
func _no_overlap(slots: Array[int]) -> bool:
	var live := _live(slots)
	for a in range(live.size()):
		var ea: Vector2 = BattleText.drawn_extent(live[a])
		for b in range(a + 1, live.size()):
			var eb: Vector2 = BattleText.drawn_extent(live[b])
			if ea.x < eb.y and eb.x < ea.y:
				return false
	return true


## `slots` in spawn order: every live line sits above (smaller y) the next.
func _oldest_on_top(slots: Array[int]) -> bool:
	var live := _live(slots)
	for k in range(live.size() - 1):
		if BattleText.drawn_position(live[k]).y >= BattleText.drawn_position(live[k + 1]).y:
			return false
	return true


func _ys(slots: Array[int]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for slot in slots:
		parts.append("-" if slot < 0 else "%.1f" % BattleText.drawn_position(slot).y)
	return ", ".join(parts)


func _burst(anchor: Vector2, prefix: String, count: int, gap_seconds: float, entry_scale: float = 1.15) -> Array:
	var texts := []
	for k in range(count):
		var text := "%s%d" % [prefix, k]
		texts.append(text)
		BattleText.popup(anchor, text, Color.WHITE, entry_scale)
		if gap_seconds > 0.0 and k < count - 1:
			_step(gap_seconds)
	return texts


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _test_burst_over_frames() -> void:
	BattleText.clear()
	var anchor := Vector2(1000.0, 1000.0)
	var texts := _burst(anchor, "FRAMES ", 4, 0.05)
	var slots := _slots_of(texts)
	var column: int = BattleText._columns[slots[0]]
	var same := column != 0
	for slot in slots:
		same = same and slot >= 0 and BattleText._columns[slot] == column
	_check(same, "four callouts a few frames apart at one spot share one column")
	# The newest has just landed: the line above it is on its way up, not
	# teleported there.
	var older := slots[2]
	_check(BattleText._lifts[older] < BattleText._lift_targets[older] - 1.0, "the push is eased, not snapped (%.1f of %.1f px)" % [BattleText._lifts[older], BattleText._lift_targets[older]])
	_step(0.3)
	slots = _slots_of(texts)
	_check(_live(slots).size() == 4, "all four are still alive after the ease settles")
	_check(_no_overlap(slots), "and no two overlap (%s)" % _ys(slots))
	_check(_oldest_on_top(slots), "the oldest sits on top, the newest at the base (%s)" % _ys(slots))
	var aligned := true
	for slot in _live(slots):
		aligned = aligned and is_equal_approx(BattleText.drawn_position(slot).x, anchor.x)
	_check(aligned, "every line of the column is centred on the spot it was raised at")


func _test_same_frame_burst() -> void:
	BattleText.clear()
	var texts := _burst(Vector2(1400.0, 1000.0), "SAME ", 4, 0.0)
	_step(0.3)
	var slots := _slots_of(texts)
	_check(_live(slots).size() == 4 and _no_overlap(slots), "four callouts in one frame stack without overlapping (%s)" % _ys(slots))
	_check(_oldest_on_top(slots), "and the first caller of the frame ends on top, as the old stagger had it (%s)" % _ys(slots))


func _test_mixed_sizes() -> void:
	BattleText.clear()
	var anchor := Vector2(1800.0, 1000.0)
	var texts := []
	var scales := [1.0, 1.8, 0.8, 1.6, 1.15]
	for k in range(scales.size()):
		texts.append("SIZE %d" % k)
		BattleText.popup(anchor, texts[k], Color.WHITE, scales[k])
		_step(0.03)
	_step(0.3)
	var slots := _slots_of(texts)
	_check(_live(slots).size() == scales.size(), "a burst of mixed emphasis sizes stays alive")
	_check(_no_overlap(slots), "each size gets its own line height, so none overlaps (%s)" % _ys(slots))
	_check(_oldest_on_top(slots), "in order (%s)" % _ys(slots))


func _test_merge_updates_in_place() -> void:
	BattleText.clear()
	var anchor := Vector2(1000.0, 1400.0)
	var key := 77001
	BattleText.popup(anchor, "TITHE 1", Color.WHITE, 1.25, key)
	_step(0.1)
	BattleText.popup(anchor, "BELOW 1", Color.WHITE, 1.15)
	_step(0.1)
	BattleText.popup(anchor, "BELOW 2", Color.WHITE, 1.15)
	_step(0.3)
	var count_before: int = BattleText._count
	var slots := _slots_of(["TITHE 1", "BELOW 1", "BELOW 2"])
	var ys_before: Array[float] = []
	for slot in slots:
		ys_before.append(BattleText.drawn_position(slot).y)
	BattleText.popup(anchor, "TITHE 2", Color.WHITE, 1.25, key)
	var merged := _slot_of("TITHE 2")
	_check(BattleText._count == count_before and merged == slots[0] and _slot_of("TITHE 1") == -1, "a merge key replaces its own line instead of adding one")
	var moved := 0.0
	for k in range(slots.size()):
		moved = maxf(moved, absf(BattleText.drawn_position(slots[k]).y - ys_before[k]))
	_check(moved < 0.5, "the merged line updates in place and pushes nothing (largest move %.2f px)" % moved)
	_check(is_equal_approx(BattleText.drawn_alpha(merged), 1.0) and BattleText._ages[merged] == 0.0, "and its life starts over")
	_step(0.2)
	slots = _slots_of(["TITHE 2", "BELOW 1", "BELOW 2"])
	_check(_no_overlap(slots) and _oldest_on_top(slots), "the column still reads in order after the merge (%s)" % _ys(slots))


func _test_column_is_capped() -> void:
	BattleText.clear()
	var texts := _burst(Vector2(1400.0, 1400.0), "CAP ", 10, 0.02)
	_step(0.25)
	var slots := _slots_of(texts)
	var visible := 0
	var top_rise := 0.0
	var column := 0
	for slot in _live(slots):
		column = BattleText._columns[slot]
		if BattleText.drawn_alpha(slot) > 0.01:
			visible += 1
			top_rise = maxf(top_rise, BattleText._positions[slot].y - BattleText.drawn_position(slot).y)
	var ceiling: float = BattleText.COLUMN_CEILING + BattleText.COLUMN_FADE_SPAN
	_check(visible <= 6, "ten callouts in 0.2 s show at most six lines (%d)" % visible)
	_check(top_rise <= ceiling, "and the column never grows past its ceiling (%.0f of %.0f px)" % [top_rise, ceiling])
	_check(_live(slots).size() < 10, "lines pushed out of the top are retired early (%d of 10 left)" % _live(slots).size())
	var newest_clear := true
	for k in range(6, 10):
		newest_clear = newest_clear and slots[k] >= 0 and is_equal_approx(BattleText.drawn_alpha(slots[k]), 1.0)
	_check(newest_clear, "while the newest four are fully readable")
	_check(_no_overlap(slots) and _oldest_on_top(slots), "and what is left still reads in order (%s)" % _ys(slots))
	_check(column != 0, "fixture: the burst formed a column")


func _test_separate_anchors() -> void:
	BattleText.clear()
	var here := Vector2(1000.0, 1800.0)
	BattleText.popup(here, "HERE", Color.WHITE, 1.15)
	_step(0.05)
	var there := here + Vector2(300.0, 0.0)
	BattleText.popup(there, "THERE 0", Color.WHITE, 1.15)
	BattleText.popup(there, "THERE 1", Color.WHITE, 1.15)
	var here_slot := _slot_of("HERE")
	_check(BattleText._lift_targets[here_slot] == 0.0, "callouts at another spot do not push this column")
	_check(BattleText._columns[here_slot] != BattleText._columns[_slot_of("THERE 0")], "they form their own column")
	BattleText.popup(here + Vector2(14.0, 18.0), "NEAR", Color.WHITE, 1.15)
	var near := _slot_of("NEAR")
	_check(BattleText._columns[near] == BattleText._columns[here_slot] and BattleText._lift_targets[here_slot] > 0.0, "a callout raised a few pixels off joins the live column and pushes it")
	_check(BattleText.drawn_position(near).x == BattleText.drawn_position(here_slot).x, "aligned to the column, not to where it was raised")


func _test_player_column_follows() -> void:
	BattleText.clear()
	var fake := Node2D.new()
	fake.name = "ColumnFakePlayer"
	add_child(fake)
	fake.add_to_group(&"player")
	fake.global_position = Vector2(3000.0, 600.0)
	BattleText.popup(fake.global_position, "AT PLAYER 0", Color.WHITE, 1.15)
	_step(0.05)
	# Item lines nudge their own text up a little; they still join.
	BattleText.popup(fake.global_position + Vector2(0.0, -26.0), "AT PLAYER 1", Color.WHITE, 1.1)
	var world_at := Vector2(3600.0, 600.0)
	BattleText.popup(world_at, "ON THE GROUND", Color.WHITE, 1.15)
	var a := _slot_of("AT PLAYER 0")
	var b := _slot_of("AT PLAYER 1")
	var ground := _slot_of("ON THE GROUND")
	_check(BattleText._columns[a] == BattleText.PLAYER_COLUMN and BattleText._columns[b] == BattleText.PLAYER_COLUMN, "callouts at the player join the player's column")
	_check(BattleText._columns[ground] != BattleText.PLAYER_COLUMN, "a callout across the room does not")
	_step(0.3)
	var ground_before := BattleText.drawn_position(ground)
	var a_before := BattleText.drawn_position(a)
	var shift := Vector2(120.0, 40.0)
	fake.global_position += shift
	_step(DT)
	var a_moved := BattleText.drawn_position(a) - a_before
	_check(a_moved.distance_to(shift + Vector2(0.0, -BattleText.RISE_SPEED * DT)) < 0.6, "the player's column moves with the player (%s for %s)" % [a_moved, shift])
	_check(is_equal_approx(BattleText.drawn_position(b).x, fake.global_position.x) and is_equal_approx(BattleText.drawn_position(a).x, fake.global_position.x), "and stays centred on them")
	_check(is_equal_approx(BattleText.drawn_position(ground).x, ground_before.x), "while the world column stays where it was raised")
	for _k in range(12):
		fake.global_position += Vector2(9.0, -4.0)
		_step(DT)
	var slots := _slots_of(["AT PLAYER 0", "AT PLAYER 1"])
	_check(_no_overlap(slots) and _oldest_on_top(slots), "the player's column reads in order while moving (%s)" % _ys(slots))
	fake.remove_from_group(&"player")
	remove_child(fake)
	fake.free()
	var still := BattleText.drawn_position(_slot_of("AT PLAYER 0"))
	_step(DT)
	_check(BattleText.drawn_position(_slot_of("AT PLAYER 0")).x == still.x, "with the player gone the column simply stays put")


func _test_reduced_motion_is_instant() -> void:
	BattleText.clear()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	_burst(Vector2(1000.0, 2200.0), "STILL ", 3, 0.0)
	var top := _slot_of("STILL 0")
	_check(BattleText._lift_targets[top] > 0.0 and BattleText._lifts[top] == BattleText._lift_targets[top], "under Reduced Motion the push lands at once")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	_burst(Vector2(1400.0, 2200.0), "EASED ", 2, 0.0)
	var older := _slot_of("EASED 0")
	_check(BattleText._lifts[older] < BattleText._lift_targets[older], "with it off the same push eases")
	_step(0.3)
	_check(is_equal_approx(BattleText._lifts[older], BattleText._lift_targets[older]), "and arrives")


func _test_damage_numbers_stay_out() -> void:
	BattleText.clear()
	var anchor := Vector2(1800.0, 2200.0)
	BattleText.popup(anchor, "CALLOUT", Color.WHITE, 1.15)
	var callout := _slot_of("CALLOUT")
	BattleText.damage(anchor + Vector2(0.0, -14.0), 123.0)
	BattleText.player_damage(anchor, 45.0)
	var number := _slot_of("123")
	var hurt := _slot_of("45")
	_check(number >= 0 and BattleText._columns[number] <= 0 and hurt >= 0 and BattleText._columns[hurt] <= 0, "damage numbers never join a column")
	_check(BattleText._lift_targets[callout] == 0.0, "and never push one")
	# Damage taken shares the player's spot with their column, so it falls
	# away from it instead of rising through it.
	BattleText.clear()
	var fake := Node2D.new()
	add_child(fake)
	fake.add_to_group(&"player")
	fake.global_position = Vector2(3000.0, 2600.0)
	var hits := []
	for k in range(4):
		BattleText.popup(fake.global_position, "HIT LINE %d" % k, Color.WHITE, 1.15 + 0.15 * k)
		var amount := 11.0 + 10.0 * k
		BattleText.player_damage(fake.global_position, amount)
		hits.append(str(int(amount)))
		_step(0.1)
	var clear := true
	var fell := true
	for _k in range(6):
		var lines := _live(_slots_of(["HIT LINE 0", "HIT LINE 1", "HIT LINE 2", "HIT LINE 3"]))
		for text in hits:
			var slot := _slot_of(String(text))
			if slot < 0:
				continue
			fell = fell and BattleText.drawn_position(slot).y >= fake.global_position.y + BattleText.PLAYER_DAMAGE_OFFSET.y
			var e: Vector2 = BattleText.drawn_extent(slot)
			for line in lines:
				var le: Vector2 = BattleText.drawn_extent(line)
				clear = clear and not (e.x < le.y and le.x < e.y)
		_step(0.1)
	_check(fell, "damage taken falls from where it lands instead of rising")
	_check(clear, "so it never crosses a line of the player's column")
	fake.remove_from_group(&"player")
	remove_child(fake)
	fake.free()


func _test_progress_joins_and_merges() -> void:
	BattleText.clear()
	var anchor := Vector2(2200.0, 2200.0)
	var key := 77002
	BattleText.progress(anchor, "FEED 1", key)
	_step(0.05)
	BattleText.popup(anchor, "AFTER FEED", Color.WHITE, 1.15)
	var feed := _slot_of("FEED 1")
	_check(BattleText._columns[feed] != 0 and BattleText._columns[feed] == BattleText._columns[_slot_of("AFTER FEED")], "a feed toast stacks with the callouts at its spot")
	_step(0.3)
	var y_before := BattleText.drawn_position(feed).y
	BattleText.progress(anchor, "FEED 2", key)
	_check(_slot_of("FEED 2") == feed and absf(BattleText.drawn_position(feed).y - y_before) < 0.5, "and a successive feed replaces it in place")
