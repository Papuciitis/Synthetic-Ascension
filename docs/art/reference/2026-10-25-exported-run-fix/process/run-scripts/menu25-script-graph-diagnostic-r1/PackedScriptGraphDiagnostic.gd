extends "/var/tmp/sa-menu25/tools/tests/PackedFrontEndFlowTest.gd"
var _retained_scripts: Array[Resource] = []
func _run() -> void:
	var pending: Array[String] = [GAME_PATH]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if visited.has(path):
			continue
		visited[path] = true
		for entry: String in ResourceLoader.get_dependencies(path):
			var parts := entry.split("::")
			var dependency: String = parts[parts.size() - 1]
			if not visited.has(dependency):
				pending.append(dependency)
		if path.get_extension() in ["gd", "gdc"]:
			print("SCRIPT_GRAPH before ", path)
			var script := load(path)
			_retained_scripts.append(script)
			print("SCRIPT_GRAPH after ", path, " loaded=", script != null)
		await process_frame
	print("SCRIPT_GRAPH prepared scripts=", _retained_scripts.size(), " dependencies=", visited.size())
	await super._run()
