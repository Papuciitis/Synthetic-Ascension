extends Node
const BREACH := preload("res://core/systems/world/objectives/BreachSealObjective.gd")
var passed := 0
var failed := 0

func _ready() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var objective := BREACH.new()
	objective.configure(87139)
	add_child(objective)
	objective.set_process(false)
	var sites: Array = objective.get("_site_art")
	check(sites.size() == 3, "only three real breach sites have art")
	check(objective.get_node_or_null("ObjectiveArt") == null, "no decorative fourth breach invites a false interaction")
	check(is_equal_approx(objective.seal_radius_px, 132.0) and is_equal_approx(objective.seal_seconds, 5.0), "presentation preserves original sealing geometry and duration")
	check(is_equal_approx(objective.breach_spawn_spread_px, 96.0) and objective.breach_spawn_count == 3, "source footprint and actual spawn count remain original")
	if not sites.is_empty():
		var art := sites[0] as Sprite2D
		var at: Vector2 = objective.get("_positions")[0]
		check(art.position.is_equal_approx(at), "painted form retains its real gameplay site origin")
		var open_texture := art.texture
		var seals: PackedByteArray = objective.get("_sealed")
		seals[0] = 1
		objective.set("_sealed", seals)
		objective.update_presentation()
		check(art.texture != open_texture, "sealed breach physically changes its texture without waiting for a gameplay tick")
		check("sealed" in art.texture.resource_path, "completed breach is a closed cap, not a recolored open cavity")
		check(not art.z_as_relative and art.z_index < 0, "low breach artwork is below actor bodies")
		check(absf(art.offset.y) < art.texture.get_height() * 0.15, "low ground footprint does not inherit upright 85-percent foot anchor")
	objective.queue_free()
	await get_tree().process_frame
	print("BreachGroundingTest: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)
