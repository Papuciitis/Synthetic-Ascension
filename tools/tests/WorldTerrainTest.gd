extends Node

# The ground set and the terrains the themes paint: every terrain maps to
# a distinct, loadable texture, the grass-like ones repeat at the grass
# scale, and the later segments' themes use the new variants.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/WorldTerrainTest.tscn

const _WORLD_ART := preload("res://core/systems/world/WorldArt.gd")
const TERRAINS: Array[StringName] = [&"grass", &"dirt", &"urban", &"mud", &"meadow", &"scrub", &"moss"]

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


func cm_min_guard() -> int:
	return 0


func _run() -> void:
	var count: int = _WORLD_ART.ground_texture_count()
	_check(count == 13, "thirteen ground textures are registered (%d)" % count)
	var all_load := true
	for index in count:
		if _WORLD_ART.ground_texture(index) == null:
			all_load = false
	_check(all_load, "every ground texture loads")
	var manager := ChunkManager.new()
	var seen: Dictionary = {}
	var in_range := true
	for terrain in TERRAINS:
		var index: int = manager.call("_ground_index_for_terrain", terrain)
		seen[index] = true
		if index < 0 or index >= count:
			in_range = false
	_check(seen.size() == TERRAINS.size() and in_range, "the seven terrains map to seven distinct textures")
	_check(int(manager.call("_ground_index_for_terrain", &"lava")) == 0, "an unknown terrain falls back to grass")
	manager.free()
	_check(_WORLD_ART.ground_repeat_world_px(10) == _WORLD_ART.ground_repeat_world_px(0) and _WORLD_ART.ground_repeat_world_px(12) == _WORLD_ART.ground_repeat_world_px(0) and _WORLD_ART.ground_repeat_world_px(6) != _WORLD_ART.ground_repeat_world_px(0), "meadow and moss repeat at the grass scale, urban does not")
	var used: Dictionary = {}
	var valid := true
	for segment in range(2, 11):
		for seed in range(6):
			var theme: SegmentThemeData = SegmentThemePicker.get_theme(segment, 1000 + seed * 7919)
			if theme == null:
				valid = false
				continue
			for terrain in [StringName(theme.base_terrain), StringName(theme.exploration_terrain)]:
				used[terrain] = true
				if not TERRAINS.has(terrain):
					valid = false
	_check(valid, "every theme from segment 2 to 10 paints known terrains")
	_check(used.has(&"meadow") and used.has(&"scrub") and used.has(&"moss"), "the later segments use meadow, scrub and moss (%s)" % str(used.keys()))
	var ward: SegmentThemeData = SegmentThemePicker._theme_collapsed_ward()
	var staging: SegmentThemeData = SegmentThemePicker._theme_military_staging()
	var cm := ChunkManager.new()
	var default_veg := cm.veg_per_chunk_max
	ward.apply_to_chunk_manager(cm)
	var ward_veg := cm.veg_per_chunk_max
	staging.apply_to_chunk_manager(cm)
	var staging_veg := cm.veg_per_chunk_max
	cm.free()
	_check(ward_veg > default_veg and staging_veg < default_veg and staging_veg >= cm_min_guard(), "an overgrown theme scatters more vegetation than the default and a staging ground less (%d / %d / %d)" % [ward_veg, default_veg, staging_veg])
	print("WorldTerrainTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
