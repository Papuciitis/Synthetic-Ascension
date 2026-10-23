extends RefCounted
## Presentation-only shared materials for ordinary world cues. The provider
## owns these four persistent variants for its viewport; no material per cue.
const COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
const MIX := preload("res://core/systems/world/visibility/WorldCueMix.gdshader")
const ADD := preload("res://core/systems/world/visibility/WorldCueAdd.gdshader")

static func material_for(item: CanvasItem, additive: bool = false, ground_points: bool = false) -> ShaderMaterial:
	var provider := COVER.get_for(item)
	var key := StringName("world_cue_%s_%s" % ["add" if additive else "mix", "ground" if ground_points else "anchor"])
	if provider.has_meta(key):
		return provider.get_meta(key) as ShaderMaterial
	var result := ShaderMaterial.new()
	result.shader = ADD if additive else MIX
	result.set_shader_parameter(&"ground_points", ground_points)
	provider.call("bind_material", result)
	provider.set_meta(key, result)
	return result

static func bind_material(item: CanvasItem, surface: ShaderMaterial) -> void:
	COVER.get_for(item).call("bind_material", surface)
