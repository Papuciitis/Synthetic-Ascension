extends "res://tools/tests/PickupCoverTest.gd"
## Render-cap envelope only; all original33 predicates remain inherited.


func _ready() -> void:
	Engine.max_fps = 15 # SettingsManager's startup display settings have already run.
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_driver_name() != "opengl3" or Engine.physics_ticks_per_second != 60:
		push_error("PickupCoverDensityNative requires actual OpenGL3 and unchanged60Hz physics")
		get_tree().quit(2)
		return
	print("PickupCoverDensityNative: driver=opengl3 cap=%d physics=%d original_predicates=33" % [Engine.max_fps, Engine.physics_ticks_per_second])
	super._ready()
