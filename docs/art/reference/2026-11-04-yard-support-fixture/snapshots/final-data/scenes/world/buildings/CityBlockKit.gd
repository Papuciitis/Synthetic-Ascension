extends RefCounted
# TEST ASSET-LOADER LEAF ONLY: tiny white, NOT native art evidence.
static func _texture(_file: String) -> Texture2D:
    var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    return ImageTexture.create_from_image(image)
