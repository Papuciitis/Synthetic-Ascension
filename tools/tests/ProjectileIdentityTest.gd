extends Node

# Discipline-specific projectile identity (playtest review finding 15): the
# batched renderer carries three silhouettes in one atlas — shared body,
# Precision needle, Barrage tracer — chosen per instance from the attack's
# PROVENANCE tags, so the look can never disagree with the attribution.
#
# Run: <godot> --headless --path . res://tools/tests/ProjectileIdentityTest.tscn

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


func _profile(tags: PackedStringArray) -> HitProfileAdapter:
	var profile := HitProfileAdapter.new()
	profile.damage = 1.0
	profile.speed = 900.0
	profile.max_range = 500.0
	profile.collision_radius = 6.0
	profile.set_meta("asc_tags", tags)
	return profile


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	ProjectileManager.clear_for_run_end()
	var source := Node2D.new()
	add_child(source)

	_check(bool(ProjectileManager.get_debug_counters()["identity_atlas"]), "the renderer composited the identity atlas from the generator PNGs")

	# Provenance picks the silhouette.
	ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(AscensionTags.native("ranged", "bullet")), source)
	ProjectileManager.spawn_player(Vector2(10, 0), Vector2.RIGHT, _profile(AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR02", "bullet", 1, 0.6)), source)
	ProjectileManager.spawn_player(Vector2(20, 0), Vector2.RIGHT, _profile(AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR05", "fragment", 1, 0.4)), source)
	var tiles: Array[float] = []
	for i in range(3):
		tiles.append(ProjectileManager._identity_tiles[i])
	_check(is_zero_approx(tiles[0]), "a native shot rides the shared body (%.0f)" % tiles[0])
	_check(is_equal_approx(tiles[1], 1.0), "a Precision root rides the needle (%.0f)" % tiles[1])
	_check(is_equal_approx(tiles[2], 2.0), "a Barrage root rides the tracer (%.0f)" % tiles[2])

	# The swap-remove keeps identity with the projectile it belongs to.
	ProjectileManager._remove(0)
	_check(is_equal_approx(ProjectileManager._identity_tiles[0], 2.0), "removal swaps the tracer's identity along with its slot")

	# A reused slot never inherits the previous occupant's silhouette.
	ProjectileManager.clear_for_run_end()
	ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "PR02", "bullet", 1, 0.6)), source)
	ProjectileManager._remove(0)
	ProjectileManager.spawn_player(Vector2.ZERO, Vector2.RIGHT, _profile(AscensionTags.native("ranged", "bullet")), source)
	_check(is_zero_approx(ProjectileManager._identity_tiles[0]), "a reused slot re-reads its own provenance")

	# One rendered frame uploads the widened buffer without complaint and
	# clamps to the render budget as before.
	await get_tree().process_frame
	var counters: Dictionary = ProjectileManager.get_debug_counters()
	_check(int(counters["visuals"]) <= int(counters["render_budget"]), "the atlas path keeps the render budget clamp")
	ProjectileManager.clear_for_run_end()

	print("ProjectileIdentityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
