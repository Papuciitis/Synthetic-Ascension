extends RefCounted
## The front end's one question about motion: has the player asked for less?
## Read live from SettingsManager, so flipping Reduced Motion in Settings takes
## effect on the next animation without any screen re-reading it.


static func reduced() -> bool:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return false
	var settings := loop.root.get_node_or_null("SettingsManager")
	if settings == null or not settings.has_method("get_value"):
		return false
	return bool(settings.call("get_value", &"accessibility", &"reduced_motion", false))
