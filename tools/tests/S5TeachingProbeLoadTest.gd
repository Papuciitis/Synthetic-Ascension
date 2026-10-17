extends Node
## Load the boss capture scripts after normal autoload initialization so
## parser diagnostics identify their own source instead of an unresolved base
## class. The S10 telegraph preview needs a display, so only its load is here.
const PATHS: Array[String] = ["res://tools/dev/S5TeachingFightPreview.gd", "res://tools/tests/S5TeachingEscapeTest.gd", "res://tools/dev/S10BossTelegraphPreview.gd"]

func _ready() -> void:
	for path: String in PATHS:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			push_error("S5TeachingProbeLoadTest: failed " + path)
			get_tree().quit(1)
			return
		print("PASS: normal-autoload script load ", path)
	print("S5TeachingProbeLoadTest: %d passed, 0 failed" % PATHS.size())
	get_tree().quit(0)
