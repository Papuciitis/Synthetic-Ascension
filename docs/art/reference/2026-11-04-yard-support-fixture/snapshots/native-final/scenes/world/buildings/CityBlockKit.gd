extends RefCounted
# TEST ASSET-LOADER LEAF ONLY; actual imported textures, no building behavior.
static func _texture(file: String) -> Texture2D:
    return load("res://assets/world/city_block/" + file) as Texture2D
