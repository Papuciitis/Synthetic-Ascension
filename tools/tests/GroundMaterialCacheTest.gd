extends Node

const Art := preload("res://core/systems/world/WorldArt.gd")
const CACHE := "res://assets/world/ground/baked/ground_materials.res"
const MANIFEST := "res://assets/world/ground/baked/ground_materials.json"
var _passed := 0
var _failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)


func _reject_manifest(manifest: Variant, description: String) -> void:
	var art_script: GDScript = Art
	_check(not bool(art_script.call("ground_material_manifest_is_current", manifest)), description)


func _test_manifest_rejections(manifest: Dictionary) -> void:
	_reject_manifest(null, "null provenance is rejected safely")
	_reject_manifest([], "non-dictionary provenance is rejected safely")
	for field: String in ["algorithm_revision", "layer_size", "format", "cache_sha256", "sources"]:
		var missing := manifest.duplicate(true)
		missing.erase(field)
		_reject_manifest(missing, "provenance requires " + field)
		var malformed := manifest.duplicate(true)
		malformed[field] = {"invalid": true}
		_reject_manifest(malformed, "provenance " + field + " rejects malformed field types")
	var wrong_sources := manifest.duplicate(true)
	wrong_sources["sources"] = "not an array"
	_reject_manifest(wrong_sources, "malformed source-list types are rejected safely")
	var too_many := manifest.duplicate(true)
	(too_many["sources"] as Array).append({})
	_reject_manifest(too_many, "extra sources are rejected before indexing registered layers")
	var too_few := manifest.duplicate(true)
	(too_few["sources"] as Array).pop_back()
	_reject_manifest(too_few, "a missing ordered source requires rebaking")
	var malformed_entry := manifest.duplicate(true)
	malformed_entry["sources"][0] = null
	_reject_manifest(malformed_entry, "malformed source entries are rejected safely")
	var reordered := manifest.duplicate(true)
	var first: Variant = reordered["sources"][0]
	reordered["sources"][0] = reordered["sources"][1]
	reordered["sources"][1] = first
	_reject_manifest(reordered, "source order must match the shader's layer order")
	for field: String in ["path", "sha256", "import_sha256"]:
		var missing := manifest.duplicate(true)
		(missing["sources"][0] as Dictionary).erase(field)
		_reject_manifest(missing, "every source requires " + field)
		var malformed := manifest.duplicate(true)
		malformed["sources"][0][field] = []
		_reject_manifest(malformed, "source " + field + " rejects non-string values")
		var stale := manifest.duplicate(true)
		stale["sources"][0][field] = "res://missing-ground-source.png" if field == "path" else "0".repeat(64)
		_reject_manifest(stale, "changed source " + field + " requires rebaking")
		var empty := manifest.duplicate(true)
		empty["sources"][0][field] = ""
		_reject_manifest(empty, "source " + field + " cannot pass with an empty digest/path")
	var corrupt_cache := manifest.duplicate(true)
	corrupt_cache["cache_sha256"] = "0".repeat(64)
	_reject_manifest(corrupt_cache, "changed derived resource bytes require rebaking")
	var wrong_revision := manifest.duplicate(true)
	wrong_revision["algorithm_revision"] = -1
	_reject_manifest(wrong_revision, "a different preprocessing revision requires rebaking")
	var wrong_size := manifest.duplicate(true)
	wrong_size["layer_size"] = 256
	_reject_manifest(wrong_size, "a different baked layer size is rejected")
	var wrong_format := manifest.duplicate(true)
	wrong_format["format"] = "RGBA8 without mipmaps"
	_reject_manifest(wrong_format, "the recorded array pixel/mipmap format is checked")


func _run() -> void:
	_check(ResourceLoader.exists(CACHE), "the exact ground array is shipped instead of requiring first-entry GPU readback")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) if FileAccess.file_exists(MANIFEST) else null
	_check(manifest is Dictionary, "the derived ground array carries reproducible source provenance")
	var art_script: GDScript = Art
	var has_validator := false
	for method: Dictionary in art_script.get_script_method_list():
		if method.get("name", "") == "ground_material_manifest_is_current": has_validator = true
	_check(has_validator, "source startup shares safe source-freshness validation with the cache test")
	if has_validator and manifest is Dictionary:
		_check(bool(art_script.call("ground_material_manifest_is_current", manifest)), "cached layers match every ordered source and preprocessing revision; art edits require rebaking")
		_test_manifest_rejections(manifest)
		Art.release_static_caches()
		var array := Art.ground_material_array()
		_check(array != null and array.resource_path == CACHE and array.get_layers() == Art.ground_texture_count(), "world startup actually uses the verified derived array")
	print("GroundMaterialCacheTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed else 0)
