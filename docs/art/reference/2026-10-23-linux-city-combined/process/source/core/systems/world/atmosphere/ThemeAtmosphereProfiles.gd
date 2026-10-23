extends RefCounted
## Transient physical presentation. Never selects a theme or consumes RNG.


static func resolve(theme_id: StringName, context: StringName = &"procedural") -> Dictionary:
	var profile := _base(theme_id, context)
	if context == &"hub" or context == &"institution":
		profile["enabled"] = false
		profile["id"] = context
		return profile
	match theme_id:
		&"service_courtyards":
			profile["label"] = "Open courtyard daylight"
			_light(profile,Color(0.66,0.69,0.76),1.00,4.0,1.00)
			profile["environment_tint"] = Color(1.0,0.997,0.988)
			profile["cloud_opacity"] = 0.035
			profile["cloud_velocity"] = Vector2(-4.0,1.0)
			profile["ambient_fill"] = Color(0.98,0.99,1.0)
			profile["direct_light"] = 0.96
			profile["cloud_scale_px"] = 900.0
			profile["mist_opacity"] = 0.0
		&"checkpoint_lanes":
			profile["label"] = "Cool broken cloud over inspection lanes"
			_light(profile,Color(0.75,0.78,0.83),0.85,8.0,1.15)
			profile["ambient_fill"] = Color(0.97,0.985,1.0)
			profile["environment_tint"] = Color(0.988,0.995,1.0)
			profile["direct_light"] = 0.78
			profile["cloud_opacity"] = 0.075
			profile["cloud_scale_px"] = 860.0
			profile["cloud_velocity"] = Vector2(-6.0,1.5)
			profile["mist_opacity"] = 0.0
		&"collapsed_ward":
			profile["label"] = "Dry exposed masonry and passing cloud"
			_light(profile,Color(0.67,0.69,0.74),1.10,3.0,0.90)
			profile["environment_tint"] = Color(1.0,0.993,0.982)
			profile["direct_light"] = 0.92
			profile["cloud_opacity"] = 0.055
			profile["cloud_velocity"] = Vector2(-8.0,2.0)
			profile["ambient_fill"] = Color(0.98,0.99,1.0)
			profile["cloud_scale_px"] = 920.0
			profile["mist_opacity"] = 0.0
		&"civilian_cutthrough":
			profile["label"] = "Sheltered plaster daylight"
			_light(profile,Color(0.69,0.72,0.78),1.00,5.0,1.10)
			profile["environment_tint"] = Color(1.0,0.995,0.983)
			profile["direct_light"] = 0.97
			profile["cloud_opacity"] = 0.03
			profile["cloud_scale_px"] = 960.0
			profile["cloud_velocity"] = Vector2(-3.0,0.8)
			profile["ambient_fill"] = Color(0.985,0.99,1.0)
			profile["mist_opacity"] = 0.0
		&"inner_district_gate":
			profile["label"] = "Open gate court under a pale sky"
			_light(profile,Color(0.67,0.70,0.77),1.15,4.0,1.00)
			profile["ambient_fill"] = Color(0.975,0.985,1.0)
			profile["environment_tint"] = Color(0.992,0.995,1.0)
			profile["direct_light"] = 0.82
			profile["cloud_opacity"] = 0.06
			profile["cloud_velocity"] = Vector2(-5.0,1.25)
			profile["cloud_scale_px"] = 1000.0
			profile["mist_opacity"] = 0.0
		&"industrial_cutthrough":
			profile["label"] = "Neutral workshop daylight"
			_light(profile,Color(0.72,0.73,0.76),0.95,7.0,1.10)
			profile["environment_tint"] = Color(0.998,0.993,0.982)
			profile["direct_light"] = 0.8
			profile["cloud_opacity"] = 0.06
			profile["cloud_scale_px"] = 820.0
			profile["cloud_velocity"] = Vector2(-6.0,1.5)
			profile["ambient_fill"] = Color(0.98,0.99,1.0)
			profile["mist_opacity"] = 0.0
		&"ruined_services":
			profile["label"] = "Wind over dry abandoned services"
			_light(profile,Color(0.68,0.69,0.73),1.05,3.0,0.95)
			profile["environment_tint"] = Color(0.997,0.995,0.99)
			profile["direct_light"] = 0.84
			profile["cloud_opacity"] = 0.07
			profile["cloud_scale_px"] = 900.0
			profile["cloud_velocity"] = Vector2(-9.0,2.25)
			profile["ambient_fill"] = Color(0.97,0.985,1.0)
			profile["mist_opacity"] = 0.0
		&"underpass_veins":
			profile["label"] = "Cool sheltered service air"
			_light(profile,Color(0.80,0.83,0.86),0.65,10.0,1.25)
			profile["ambient_fill"] = Color(0.96,0.985,1.0)
			profile["environment_tint"] = Color(0.985,0.995,0.995)
			profile["direct_light"] = 0.62
			profile["cloud_opacity"] = 0.055
			profile["cloud_scale_px"] = 1040.0
			profile["cloud_velocity"] = Vector2(-3.0,0.75)
			profile["mist_opacity"] = 0.015
			profile["mist_tint"] = Color(0.69,0.73,0.70)
		&"canal_services":
			profile["label"] = "Diffuse damp canal-service daylight"
			_light(profile,Color(0.78,0.81,0.84),0.70,9.0,1.20)
			profile["ambient_fill"] = Color(0.965,0.985,1.0)
			profile["environment_tint"] = Color(0.985,0.998,0.99)
			profile["direct_light"] = 0.7
			profile["cloud_opacity"] = 0.075
			profile["cloud_scale_px"] = 1100.0
			profile["cloud_velocity"] = Vector2(-4.0,1.0)
			profile["mist_opacity"] = 0.025
			profile["mist_tint"] = Color(0.70,0.75,0.71)
		&"rail_yard":
			profile["label"] = "Exposed dry loading-ground sun"
			_light(profile,Color(0.66,0.69,0.77),1.05,2.0,0.90)
			profile["environment_tint"] = Color(1.0,0.995,0.985)
			profile["cloud_opacity"] = 0.025
			profile["cloud_scale_px"] = 1160.0
			profile["cloud_velocity"] = Vector2(-12.0,3.0)
			profile["ambient_fill"] = Color(0.98,0.99,1.0)
			profile["direct_light"] = 1.0
			profile["mist_opacity"] = 0.0
		&"military_staging":
			profile["label"] = "Cool open muster-ground sky"
			_light(profile,Color(0.73,0.76,0.80),0.90,6.0,1.05)
			profile["ambient_fill"] = Color(0.975,0.99,1.0)
			profile["environment_tint"] = Color(0.992,0.998,0.99)
			profile["direct_light"] = 0.8
			profile["cloud_opacity"] = 0.075
			profile["cloud_scale_px"] = 940.0
			profile["cloud_velocity"] = Vector2(-8.0,2.0)
			profile["mist_opacity"] = 0.0
		&"outer_wall":
			profile["label"] = "Clear windy outer approaches"
			_light(profile,Color(0.66,0.69,0.78),1.18,3.0,0.95)
			profile["environment_tint"] = Color(0.998,0.998,0.99)
			profile["cloud_opacity"] = 0.025
			profile["cloud_scale_px"] = 1280.0
			profile["cloud_velocity"] = Vector2(-14.0,3.5)
			profile["ambient_fill"] = Color(0.98,0.99,1.0)
			profile["direct_light"] = 1.0
			profile["mist_opacity"] = 0.0
		&"siege_services":
			profile["label"] = "Wind and sun over stone service yards"
			_light(profile,Color(0.67,0.69,0.74),1.00,4.0,1.00)
			profile["environment_tint"] = Color(1.0,0.993,0.982)
			profile["direct_light"] = 0.86
			profile["cloud_opacity"] = 0.07
			profile["cloud_scale_px"] = 940.0
			profile["cloud_velocity"] = Vector2(-10.0,2.5)
			profile["ambient_fill"] = Color(0.98,0.99,1.0)
			profile["mist_opacity"] = 0.0
		&"gate_district":
			profile["label"] = "Pale daylight over the departure court"
			_light(profile,Color(0.66,0.69,0.76),1.15,3.0,1.00)
			profile["ambient_fill"] = Color(0.975,0.99,1.0)
			profile["environment_tint"] = Color(0.992,0.996,1.0)
			profile["direct_light"] = 0.88
			profile["cloud_opacity"] = 0.055
			profile["cloud_scale_px"] = 1120.0
			profile["cloud_velocity"] = Vector2(-6.0,1.5)
			profile["mist_opacity"] = 0.0
		_:
			return resolve(&"service_courtyards",context)
	profile["wind"] = (profile["cloud_velocity"] as Vector2)/15.0
	return profile


static func _base(id: StringName, context: StringName) -> Dictionary:
	return {"id":id,"context":context,"label":"Authored environment","enabled":true,
		"ambient_fill":Color(0.98,0.99,1.0),"direct_light":1.0,"environment_tint":Color.WHITE,
		"cloud_opacity":0.0,"cloud_scale_px":880.0,"cloud_velocity":Vector2.ZERO,
		"mist_opacity":0.0,"mist_tint":Color(0.72,0.75,0.72),"wind":Vector2.ZERO,
		"particle_kind":&"none","particle_density":0.0,"vignette_strength":0.0,
		"sun_shade":Color(0.66,0.69,0.76),"shadow_length":1.0,"penumbra_px":4.0,"contact_strength":1.0}


## Physical sun for a theme (WorldDepthStyle): the multiplicative ground shade
## inside a cast, cast length against clear daylight, edge softness and
## wall-base contact. Overcast or sheltered air lightens and softens shadows
## and deepens contact; open sun casts long, crisp, cool shadows. The sun's
## direction never changes and nothing here flattens roofs or tints actors.
## No theme's shade is deeper than clear S2 daylight (luma x0.69): on the
## current dark lawns and dirt a deeper shade turns casts into near-black
## slabs where dark armour would lose its contrast in a fight.
static func _light(profile: Dictionary, shade: Color, length: float, penumbra: float, contact: float) -> void:
	profile["sun_shade"] = shade
	profile["shadow_length"] = length
	profile["penumbra_px"] = penumbra
	profile["contact_strength"] = contact
