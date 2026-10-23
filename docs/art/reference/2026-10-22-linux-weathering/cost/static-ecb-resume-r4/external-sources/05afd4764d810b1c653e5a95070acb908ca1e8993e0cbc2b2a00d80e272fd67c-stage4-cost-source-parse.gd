extends Node


func _ready() -> void:
	var failures: int = 0
	var paths: Array[String] = [
		"/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-r3/Stage4StaticCostProbe.gd",
		"/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-r3/FinalCombinedCityPreview.gd",
	]
	for path: String in paths:
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			failures += 1
			push_error("Stage4CostSourceParse cannot instantiate external helper: " + path)
	print("Stage4CostSourceParse: checked=%d failures=%d" % [paths.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)
