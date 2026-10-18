extends Node
## Presentation integration: missing identities, geometry drift, lost cleanup
## and accessibility failures must fail independently of gameplay suites.
const WARD := preload("res://scenes/world/wardstones/Wardstone.tscn")
const RITE := preload("res://scenes/world/gates/ExitRite.tscn")
const RELAY := preload("res://core/systems/world/objectives/DistrictRelayObjective.gd")
const VIGIL := preload("res://core/systems/world/objectives/WardVigilObjective.gd")
const BREACH := preload("res://core/systems/world/objectives/BreachSealObjective.gd")
const WAGER := preload("res://core/systems/world/objectives/WagerShrineObjective.gd")
var _passes := 0
var _failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	var ward := WARD.instantiate()
	add_child(ward)
	ward.set_process(false)
	_check("painted/wardstone_v1" in ward.get_node("Obelisk").texture.resource_path, "Wardstone uses its painted world form")
	_check(is_equal_approx(ward.get_node("CaptureZone/CollisionShape2D").shape.radius, ward.capture_zone_radius), "Wardstone capture geometry remains exact")
	ward.restore_active()
	_check(ward.get_node("Obelisk").get("_state") == "complete", "restored Wardstone immediately shows its anchored identity")
	_check(is_equal_approx(ward.get_node("StabilityField/CollisionShape2D").shape.radius, ward.get_stability_radius()), "sanctuary form retains the real modified field geometry")
	var rite := RITE.instantiate()
	add_child(rite)
	rite.set_process(false)
	_check("painted/exit_rite_v1" in rite.get_node("GateFrame").texture.resource_path, "Rite uses its open painted threshold")
	_check(is_equal_approx(rite.get_node("Zone/CollisionShape2D").shape.radius, rite.radius), "Rite siege geometry remains exact")
	rite.set_locked(false)
	_check(rite.get_node("GateFrame").get("_state") == "ready", "unlock immediately shows ready rather than falsely channeling")
	var identities := {}
	for script: Script in [RELAY, VIGIL, BREACH, WAGER]:
		var objective: Node2D = script.new()
		add_child(objective)
		objective.set_process(false)
		var art: Node = objective.get_node_or_null("ObjectiveArt")
		if script == BREACH or script == RELAY:
			var sites: Array = objective.get("_site_art")
			_check(art == null and sites.size() == 3, "only the three real sites have actionable forms")
			art = sites[0] if not sites.is_empty() else null
		_check(art != null, "%s has a painted identity" % script.resource_path.get_file())
		if art != null:
			var sprite := art as Sprite2D
			_check(sprite != null and sprite.texture != null, "objective identity has a texture")
			if sprite != null and sprite.texture != null:
				identities[sprite.texture.resource_path] = true
				if objective.has_method("finish"):
					if script == BREACH:
						objective.set("_sealed", PackedByteArray([1, 1, 1]))
					elif script == RELAY:
						objective.set("_component_silenced", PackedByteArray([1, 1, 1]))
					objective.call("finish")
					_check(sprite.get("_state") == "complete" or sprite.get("_state") == "spent", "objective completion immediately changes its world form")
		objective.queue_free()
	_check(identities.size() == 4, "all four objective variants have distinct forms")
	ward.queue_free()
	rite.queue_free()
	await get_tree().process_frame
	print("ObjectivePresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
