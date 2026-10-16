extends RefCounted
class_name CityLoreDiscovery
## Recovery copies use existing profile evidence and Grimoire discoveries.
## Looking up availability never records, reads, rewards or rolls anything.

const DOCUMENTS := preload("res://data/narrative/CityLoreDocuments.gd")
const STAGE_COMPLETIONS := {"method": 3, "doctrine": 6, "apotheosis": 9}


static func document(id: String) -> Dictionary:
	for row: Dictionary in DOCUMENTS.DOCUMENTS:
		if String(row["id"]) == id:
			return row.duplicate(true)
	return {}


## The tray can recover earlier papers on either route and on later attempts.
## Completed S3 is evidence of S3 itself, never an unplayed arrival in S4.
static func available_documents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if Global == null:
		return out
	var completed := _completed_progress()
	var reached := completed
	for segment: int in range(1, 11):
		if StoryDirector.has_flag("city_lore:reached:%d" % segment):
			reached = maxi(reached, segment)
	for row: Dictionary in DOCUMENTS.DOCUMENTS:
		var completion_needed := maxi(int(row.get("completion_required", 0)), int(row.get("hub_completion_required", 0)))
		if completed < completion_needed or reached < int(row.get("min_segment", 1)):
			continue
		var copy := row.duplicate(true)
		copy["copied"] = Global.grimoire_has("record:" + String(row["id"]))
		out.append(copy)
	return out


## Only the inspection panel's explicit Keep a copy action calls this path.
## Saving here makes the profile durable before the interaction can close.
static func collect(id: String) -> bool:
	if Global == null or document(id).is_empty():
		return false
	var offered := false
	for row: Dictionary in available_documents():
		if String(row["id"]) == id:
			offered = true
			break
	if not offered or not Global.grimoire_note("record:" + id):
		return false
	Global.save_current_profile(false)
	return true


static func _completed_progress() -> int:
	var saved := StoryDirector.state_for_save()
	var completed := clampi(int(saved.get("best", 0)), 0, 10)
	if StoryDirector.has_flag("area:1") or StoryDirector.has_flag("chapter:1"):
		completed = 10
	# These stages only commit after their own segment has completed. A
	# preserved Doctrine does not claim the seventh district was entered.
	for stage: String in STAGE_COMPLETIONS:
		var preserved := String(Global.meta_city_commitments.get(stage, ""))
		var current := String(Global.attempt_doctrine_stage_ids.get(stage, Global.attempt_doctrine_stage_ids.get(StringName(stage), "")))
		if not preserved.is_empty() or not current.is_empty():
			completed = maxi(completed, int(STAGE_COMPLETIONS[stage]))
	return completed
