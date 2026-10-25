extends "/var/tmp/sa-menu25/tools/tests/PackedFrontEndFlowTest.gd"
## Adds catalogue/filter and native metadata observations to the frozen flow.

var _catalog_counts: Dictionary = {}


func _run() -> void:
	var global_node: Node = root.get_node("Global")
	var expected := {"race_db": 4, "style_db": 3, "weapon_db": 3, "spell_db": 1, "item_db": 40, "set_db": 3, "augment_db": 16}
	for property: String in expected:
		var catalogue: Dictionary = global_node.get(property)
		_catalog_counts[property] = catalogue.size()
		_check(catalogue.size() == expected[property], "exported %s count is %d" % [property, expected[property]])
	var majors: RefCounted = global_node.get("major_choice_db")
	var definitions: Dictionary = majors.get("defs_by_id")
	_catalog_counts["major_choices"] = definitions.size()
	_check(definitions.size() == 28, "exported major-choice count is 28")
	_check(not (global_node.get("item_db") as Dictionary).has("item_test"), "disabled test item stays excluded")
	_check(not (global_node.get("set_db") as Dictionary).has(StringName()), "empty-ID set template stays excluded")
	for weapon: String in ["magic", "melee", "ranged"]:
		_check((global_node.get("weapon_db") as Dictionary).has(weapon), "starter weapon filename still resolves " + weapon)
	print("EXPORTED_CATALOG_COUNTS ", JSON.stringify(_catalog_counts))
	await super._run()


func _capture(filename: String) -> void:
	await super._capture(filename)
	if not _wants_capture():
		return
	var path := _capture_dir.path_join(filename + ".json")
	var metadata := {"file": filename, "catalogues": _catalog_counts, "window_size": str(root.size), "logical_view": str(root.get_visible_rect()), "render_fps_cap": Engine.max_fps, "physics_hz": Engine.physics_ticks_per_second, "normal_flags": _normal_flags(), "stage": "normal Base selection" if filename == "base-populated.png" else "staged opening-completed S1 reward", "limits": "Original native viewport capture of the exported Windows package using Linux Godot. No Windows OS execution, full cinematic traversal or performance claim."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "native proof metadata can be written")
	if file != null:
		file.store_string(JSON.stringify(metadata, "\t") + "\n")
