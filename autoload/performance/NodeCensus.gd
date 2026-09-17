extends RefCounted
class_name NodeCensus
## A one-shot count of the scene tree by class and by top-level branch, for
## the moment a capture shows thousands of nodes nobody can account for.
## Walking 5,000 nodes costs a few milliseconds; never call it per frame.


static func count(root: Node) -> Dictionary:
	var by_class: Dictionary = {}
	var by_branch: Dictionary = {}
	var by_script: Dictionary = {}
	var total := 0
	var stack: Array = [[root, root.name]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var branch: String = pair[1]
		total += 1
		var cls := node.get_class()
		by_class[cls] = int(by_class.get(cls, 0)) + 1
		by_branch[branch] = int(by_branch.get(branch, 0)) + 1
		var script: Script = node.get_script()
		if script != null:
			var key := String(script.get_global_name())
			if key.is_empty():
				key = script.resource_path.get_file()
			by_script[key] = int(by_script.get(key, 0)) + 1
		for child in node.get_children(true):
			# Branch = the child of the root's first scene-level node, so the
			# game scene's UI, world and enemies count separately.
			var child_branch := branch
			if node == root:
				child_branch = String(child.name)
			elif node.get_parent() == root:
				child_branch = branch + "/" + String(child.name)
			stack.append([child, child_branch])
	return {"total": total, "by_class": by_class, "by_branch": by_branch, "by_script": by_script}


static func _top(dict: Dictionary, limit: int) -> String:
	var keys := dict.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(dict[a]) > int(dict[b]))
	var parts := PackedStringArray()
	for i in range(mini(limit, keys.size())):
		parts.append("%s %d" % [String(keys[i]), int(dict[keys[i]])])
	return ", ".join(parts)


static func report(root: Node, limit: int = 12) -> String:
	var census := count(root)
	return "nodes %d | classes: %s | scripts: %s | branches: %s" % [
		int(census["total"]), _top(census["by_class"], limit), _top(census["by_script"], limit), _top(census["by_branch"], limit)]
