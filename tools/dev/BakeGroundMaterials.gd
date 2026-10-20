extends SceneTree
## Run with a real renderer, --path . --script res://tools/dev/BakeGroundMaterials.gd.
## Uses the original imported-texture algorithm; no source artwork is changed.
const Art := preload("res://core/systems/world/WorldArt.gd")
const DIRECTORY := "res://assets/world/ground/baked/"

func _initialize() -> void:
	_run.call_deferred()


func _import_is_current(path: String) -> bool:
	if not FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".import"):
		push_error("Ground bake requires the source PNG and its import settings: " + path)
		return false
	var settings := ConfigFile.new()
	if settings.load(path + ".import") != OK:
		push_error("Cannot read ground import settings: " + path)
		return false
	var remap: Variant = settings.get_value("remap", "path", "")
	if not remap is String or String(remap).is_empty():
		push_error("Ground texture has no imported resource; run --headless --import first: " + path)
		return false
	var imported_path: String = remap
	var checksum_path := imported_path.get_basename() + ".md5"
	if not FileAccess.file_exists(imported_path) or not FileAccess.file_exists(checksum_path):
		push_error("Ground import data is missing; run --headless --import first: " + path)
		return false
	# Godot's importer stores these two assignments without a section header.
	var checksums := ConfigFile.new()
	if checksums.parse("[hashes]\n" + FileAccess.get_file_as_string(checksum_path)) != OK:
		push_error("Cannot read ground import checksums: " + path)
		return false
	var source_md5: Variant = checksums.get_value("hashes", "source_md5", "")
	var dest_md5: Variant = checksums.get_value("hashes", "dest_md5", "")
	if not source_md5 is String or not dest_md5 is String:
		push_error("Malformed ground import checksums: " + path)
		return false
	if String(source_md5).length() != 32 or String(dest_md5).length() != 32 or source_md5 != FileAccess.get_md5(path) or dest_md5 != FileAccess.get_md5(imported_path):
		push_error("Ground import is stale; run --headless --import before native baking: " + path)
		return false
	if not ResourceLoader.exists(path, "Texture2D"):
		push_error("Ground texture is not registered as an imported resource: " + path)
		return false
	return true


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Ground material baking requires real texture readback, not the Dummy renderer")
		quit(1)
		return
	# Reject bad inputs before touching either committed derived output.
	var sources: Array[Dictionary] = []
	for path: String in Art._GROUND_TEX_PATHS:
		if not _import_is_current(path):
			quit(1)
			return
		var source_hash := FileAccess.get_sha256(path)
		var import_hash := FileAccess.get_sha256(path + ".import")
		if source_hash.length() != 64 or import_hash.length() != 64:
			push_error("Cannot fingerprint ground bake inputs: " + path)
			quit(1)
			return
		sources.append({"path": path, "sha256": source_hash, "import_sha256": import_hash})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var images: Array[Image] = []
	for index in Art.ground_texture_count():
		var path: String = Art._GROUND_TEX_PATHS[index]
		var texture := Art.ground_texture(index)
		var imported_image: Image = texture.get_image() if texture != null else null
		if texture == null or texture.resource_path != path or imported_image == null or imported_image.is_empty():
			push_error("Ground bake cannot substitute fallback pixels for unreadable imported art: " + path)
			quit(1)
			return
		imported_image = null
		var image := Art.prepare_ground_material_layer(index)
		if image == null or image.is_empty() or image.get_width() != Art._GROUND_ARRAY_LAYER_PX or image.get_height() != Art._GROUND_ARRAY_LAYER_PX or image.get_format() != Image.FORMAT_RGB8 or not image.has_mipmaps():
			push_error("Ground preprocessing did not produce a complete RGB8 mipmapped layer: " + path)
			quit(1)
			return
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(image.get_data())
		images.append(image)
		sources[index]["layer_sha256"] = hash.finish().hex_encode()
		await RenderingServer.frame_post_draw
		await process_frame
	for entry: Dictionary in sources:
		var path: String = entry.path
		if entry.sha256 != FileAccess.get_sha256(path) or entry.import_sha256 != FileAccess.get_sha256(path + ".import"):
			push_error("Ground inputs changed during preparation; derived outputs were not replaced: " + path)
			quit(1)
			return
	var array := Texture2DArray.new()
	var result := array.create_from_images(images)
	if result == OK:
		result = ResourceSaver.save(array, DIRECTORY + "ground_materials.res", ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Ground material bake failed: " + error_string(result))
		quit(1)
		return
	var manifest := {"algorithm_revision": Art.GROUND_ARRAY_CACHE_REVISION, "layer_size": Art._GROUND_ARRAY_LAYER_PX, "format": "RGB8 with generated mipmaps", "cache_sha256": FileAccess.get_sha256(DIRECTORY + "ground_materials.res"), "sources": sources}
	var file := FileAccess.open(DIRECTORY + "ground_materials.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot save ground bake provenance")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	if not Art.ground_material_manifest_is_current(manifest):
		push_error("Ground sources or derived bytes changed during baking; bake provenance is not current")
		quit(1)
		return
	print("BakeGroundMaterials: saved %d original-algorithm layers" % images.size())
	quit(0)
