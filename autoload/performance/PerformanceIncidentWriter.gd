extends RefCounted
class_name PerformanceIncidentWriter


static func write_incident(incident: Dictionary, directory: String) -> Dictionary:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return {"ok": false, "json_path": "", "csv_path": "", "error": error_string(error)}
	var metadata := incident.get("metadata", {}) as Dictionary
	var sequence := int(metadata.get("sequence", 0))
	var segment := int(metadata.get("segment", 0))
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var base := "%s_segment-%02d_incident-%03d" % [stamp, segment, sequence]
	var json_path := directory.path_join(base + ".json")
	var csv_path := directory.path_join(base + ".csv")
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		return {"ok": false, "json_path": "", "csv_path": "", "error": "Cannot open JSON report: %s" % FileAccess.get_open_error()}
	json_file.store_string(JSON.stringify(_json_safe(incident), "\t"))
	json_file.close()
	var csv_file := FileAccess.open(csv_path, FileAccess.WRITE)
	if csv_file == null:
		return {"ok": false, "json_path": json_path, "csv_path": "", "error": "Cannot open CSV report: %s" % FileAccess.get_open_error()}
	csv_file.store_line("t_usec,elapsed_sec,frame_ms,fps,process_ms,physics_ms,enemies,projectiles,physics_objects,nodes,chunks,flow_building,sim_full,sim_mid,sim_far,sim_protected,sim_physics_enabled,sim_pressure,sim_spatial_demotions,tier_changes_total,tier_reversals_total,world_materialized,world_data_only")
	for sample_variant in incident.get("samples", []):
		var sample := sample_variant as Dictionary
		csv_file.store_csv_line(PackedStringArray([
			str(sample.get("t_usec", 0)),
			str(sample.get("elapsed_sec", 0.0)),
			str(sample.get("frame_ms", 0.0)),
			str(sample.get("fps", 0.0)),
			str(sample.get("process_ms", 0.0)),
			str(sample.get("physics_ms", 0.0)),
			str(sample.get("enemies", 0)),
			str(sample.get("projectiles", 0)),
			str(sample.get("physics_objects", 0)),
			str(sample.get("nodes", 0)),
			str(sample.get("chunks", 0)),
			str(sample.get("flow_building", false)),
			str(sample.get("sim_full", 0)),
			str(sample.get("sim_mid", 0)),
			str(sample.get("sim_far", 0)),
			str(sample.get("sim_protected", 0)),
			str(sample.get("sim_physics_enabled", 0)),
			str(sample.get("sim_pressure", 0)),
			str(sample.get("sim_spatial_demotions", 0)),
			str(sample.get("tier_changes_total", 0)),
			str(sample.get("tier_reversals_total", 0)),
			str(sample.get("enemy_world_materialized", 0)),
			str(sample.get("enemy_world_data_only", 0)),
		]))
	csv_file.close()
	return {"ok": true, "json_path": json_path, "csv_path": csv_path, "error": ""}


static func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var output := {}
			for key in (value as Dictionary).keys():
				output[str(key)] = _json_safe((value as Dictionary)[key])
			return output
		TYPE_ARRAY:
			var output: Array = []
			for item in value as Array:
				output.append(_json_safe(item))
			return output
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_STRING_NAME:
			return str(value)
		_:
			return value
