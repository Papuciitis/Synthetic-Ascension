extends RefCounted
## One fixed top-right light for the painted world. Upright art projects onto
## the ground southwest from its feet; no live lights or occluders are needed.
##
## Every caster shares one light model: one sun direction; one multiplicative
## shade, so a shadow darkens lawn, paving and dirt by the same ratio; building
## casts sized from the drawn wall height; a soft penumbra; wall-base contact
## shade. Themes vary shade strength, cast length and softness, never the sun's
## direction. Presentation only: nothing here touches collision or RNG.

const SHADOW_DIRECTION := Vector2(-0.72, 0.50)
## Actor/prop silhouette casts (actor_cast_shadow). Near-black at 0.32 alpha
## leaves any ground at about x0.68, the same ratio as SUN_SHADE. They stay
## alpha-blended: the Hub's CanvasModulate would tint a multiplied quad.
const SHADOW_COLOR := Color(0.018, 0.024, 0.032, 0.32)
const SHADOW_Z := -7
const SHADOW_SHADER := preload("res://core/systems/world/actor_cast_shadow.gdshader")
## Building, kit-foliage, chimney/roof-on-roof and wall-base contact shade:
## one shared material, so a theme's shade is a single uniform update.
const SUN_SHADOW_MATERIAL := preload("res://core/systems/world/sun_shadow_material.tres")
## Absolute z of every ground-level sun shade (building casts, kit foliage
## casts, wall-base contact). It sits above every flat ground layer: splat
## -100, floor stamps -95..-92, paving and footways -94/-93, garden soil,
## herbs and beds, chunk decals -90. It stays below upright art: wild
## foliage shadows -86 and plants -85, landmarks -83, room tones -80, props,
## walls, actors and their shadows (-7). A shadow then darkens exactly the
## ground beneath it, whatever order a kit happened to add its children in.
## Flat ground that should receive shade draws below this layer.
const GROUND_SHADE_Z := -87
## Clear-daylight ground ratio inside a cast shadow: a cool, sky-lit x0.69.
const SUN_SHADE := Color(0.66, 0.69, 0.76)
## A building casts from its eave (facade height * K) plus its gable.
const BUILDING_SHADOW_K := 0.85
const GABLE_ALLOWANCE_PX := 24.0
const PENUMBRA_PX := 4.0
## Wall-base contact: strongest under the shaded south face, lighter on the
## west, faint on the sunlit east. Widths in world px; strength is the share
## of the sun shade applied at the wall foot.
const CONTACT_SOUTH_PX := 18.0
const CONTACT_WEST_PX := 11.0
const CONTACT_EAST_PX := 6.0
const CONTACT_SOUTH := 0.80
const CONTACT_WEST := 0.60
const CONTACT_EAST := 0.28
const CONTACT_CORNER_PX := 22.0
const CONTACT_CORNER := 0.45

## Build-time theme light. The segment builder sets it before chunks stream.
static var length_scale := 1.0
static var penumbra_px := PENUMBRA_PX
static var contact_strength := 1.0


static func projection_at(feet: Vector2) -> Transform2D:
	var projection := Transform2D(Vector2.RIGHT, -SHADOW_DIRECTION, Vector2.ZERO)
	projection.origin = feet - projection.basis_xform(feet)
	return projection


static func project_transform(visual_transform: Transform2D, feet: Vector2) -> Transform2D:
	return projection_at(feet) * visual_transform


static func offset_for_height(height_px: float) -> Vector2:
	return SHADOW_DIRECTION * maxf(0.0, height_px)


## Cast height of a building whose south wall is drawn `facade_height` tall.
static func building_shadow_height(facade_height: float) -> float:
	return (maxf(0.0, facade_height) * BUILDING_SHADOW_K + GABLE_ALLOWANCE_PX) * length_scale


static func building_shadow_offset(facade_height: float) -> Vector2:
	return offset_for_height(building_shadow_height(facade_height))


## Theme light from its atmosphere profile. Length, penumbra and contact are
## build-time geometry; the shade is the shared material's uniform. Unknown
## themes resolve to the clear-daylight fallback profile.
static func use_theme(theme_id: StringName) -> void:
	var profiles := load("res://core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd") as GDScript
	apply_light(profiles.call("resolve", theme_id) as Dictionary)


static func apply_light(profile: Dictionary) -> void:
	length_scale = clampf(float(profile.get("shadow_length", 1.0)), 0.4, 1.4)
	penumbra_px = clampf(float(profile.get("penumbra_px", PENUMBRA_PX)), 0.0, 12.0)
	contact_strength = clampf(float(profile.get("contact_strength", 1.0)), 0.0, 1.25)
	set_sun_shade(profile.get("sun_shade", SUN_SHADE) as Color)


static func reset_light() -> void:
	length_scale = 1.0
	penumbra_px = PENUMBRA_PX
	contact_strength = 1.0
	set_sun_shade(SUN_SHADE)


static func set_sun_shade(shade: Color) -> void:
	SUN_SHADOW_MATERIAL.set_shader_parameter("shade_color", Vector3(shade.r, shade.g, shade.b))


static func sun_shade() -> Color:
	var value: Variant = SUN_SHADOW_MATERIAL.get_shader_parameter("shade_color")
	if value is Vector3:
		var shade := value as Vector3
		return Color(shade.x, shade.y, shade.z)
	return SUN_SHADE


## Puts a ground-level shade on the shared shade layer, independent of its
## parent's z and of its position among its siblings.
static func place_ground_shade(item: CanvasItem) -> void:
	item.z_as_relative = false
	item.z_index = GROUND_SHADE_Z
