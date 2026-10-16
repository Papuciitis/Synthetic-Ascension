extends Node
## Load the capture scripts after normal autoload initialization so parser
## diagnostics identify their own source instead of an unresolved base class.

func _ready() -> void:
	for path: String in ["res://tools/dev/S5TeachingFightPreview.gd", "res://tools/tests/S5TeachingEscapeTest.gd"]:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			push_error("S5TeachingProbeLoadTest: failed " + path)
			get_tree().quit(1)
			return
		print("PASS: normal-autoload script load ", path)
	print("S5TeachingProbeLoadTest: 2 passed, 0 failed")
	get_tree().quit(0)
