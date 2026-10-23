extends Node

func _ready() -> void:
	var checked: int = 0
	var failed: int = 0
	for path: String in OS.get_cmdline_user_args():
		if not path.ends_with(".gd") or not (path.is_absolute_path() or path.begins_with("res://")):
			continue
		checked += 1
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			failed += 1
			push_error("ExternalSourceParseProbe cannot instantiate: " + path)
	print("ExternalSourceParseProbe: checked=%d failures=%d" % [checked, failed])
	get_tree().quit(1 if failed > 0 or checked == 0 else 0)
