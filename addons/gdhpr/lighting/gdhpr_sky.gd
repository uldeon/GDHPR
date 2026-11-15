@tool
class_name GDHPRSky
extends RefCounted
## Procedural sky presets.
##
## These are built from [ProceduralSkyMaterial] only, so GDHPR needs no
## textures or HDRIs to give a scene believable ambient light and reflections.

## Ordered names matching [member GDHPRConfig.sky].
const PRESET_NAMES: PackedStringArray = [
	"None", "Studio", "Outdoor", "Golden Hour", "Dusk", "Night", "Neon", "Plain",
]


## Builds a sky for [param preset]; returns [code]null[/code] for preset 0 (None).
static func make(preset: int) -> Sky:
	if preset <= 0:
		return null

	var mat := ProceduralSkyMaterial.new()
	mat.use_debanding = true

	match preset:
		1: # Studio: neutral seamless backdrop, bright overhead softbox feel
			mat.sky_top_color = Color(0.52, 0.55, 0.60)
			mat.sky_horizon_color = Color(0.72, 0.73, 0.75)
			mat.ground_horizon_color = Color(0.55, 0.55, 0.56)
			mat.ground_bottom_color = Color(0.30, 0.30, 0.31)
			mat.sky_energy_multiplier = 1.0
			mat.ground_energy_multiplier = 0.6
			mat.sky_curve = 0.2
		2: # Outdoor: clear midday
			mat.sky_top_color = Color(0.25, 0.44, 0.78)
			mat.sky_horizon_color = Color(0.72, 0.83, 0.95)
			mat.ground_horizon_color = Color(0.55, 0.62, 0.68)
			mat.ground_bottom_color = Color(0.16, 0.17, 0.17)
			mat.sky_energy_multiplier = 1.15
			mat.ground_energy_multiplier = 0.35
			mat.sky_curve = 0.12
			mat.sun_angle_max = 22.0
			mat.sun_curve = 0.08
		3: # Golden hour
			mat.sky_top_color = Color(0.22, 0.34, 0.60)
			mat.sky_horizon_color = Color(0.98, 0.70, 0.42)
			mat.ground_horizon_color = Color(0.62, 0.45, 0.34)
			mat.ground_bottom_color = Color(0.11, 0.10, 0.11)
			mat.sky_energy_multiplier = 1.05
			mat.ground_energy_multiplier = 0.35
			mat.sky_curve = 0.22
			mat.sun_angle_max = 30.0
			mat.sun_curve = 0.12
		4: # Dusk
			mat.sky_top_color = Color(0.10, 0.13, 0.28)
			mat.sky_horizon_color = Color(0.46, 0.36, 0.48)
			mat.ground_horizon_color = Color(0.22, 0.19, 0.26)
			mat.ground_bottom_color = Color(0.05, 0.05, 0.07)
			mat.sky_energy_multiplier = 0.85
			mat.ground_energy_multiplier = 0.25
			mat.sky_curve = 0.25
		5: # Night: moonlit
			mat.sky_top_color = Color(0.015, 0.022, 0.055)
			mat.sky_horizon_color = Color(0.05, 0.07, 0.14)
			mat.ground_horizon_color = Color(0.04, 0.05, 0.08)
			mat.ground_bottom_color = Color(0.008, 0.01, 0.015)
			mat.sky_energy_multiplier = 0.55
			mat.ground_energy_multiplier = 0.15
			mat.sky_curve = 0.3
		6: # Neon city
			mat.sky_top_color = Color(0.03, 0.02, 0.07)
			mat.sky_horizon_color = Color(0.35, 0.09, 0.36)
			mat.ground_horizon_color = Color(0.14, 0.05, 0.18)
			mat.ground_bottom_color = Color(0.02, 0.01, 0.03)
			mat.sky_energy_multiplier = 0.7
			mat.ground_energy_multiplier = 0.25
			mat.sky_curve = 0.35
		7: # Plain: cheapest possible, flat colour, no sun disc
			mat.sky_top_color = Color(0.30, 0.33, 0.38)
			mat.sky_horizon_color = Color(0.42, 0.45, 0.50)
			mat.ground_horizon_color = Color(0.28, 0.29, 0.31)
			mat.ground_bottom_color = Color(0.12, 0.12, 0.13)
			mat.sky_energy_multiplier = 0.8
			mat.ground_energy_multiplier = 0.3
			mat.sky_curve = 0.0

	var sky := Sky.new()
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if preset == 7 else Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME if preset == 7 else Sky.PROCESS_MODE_INCREMENTAL
	return sky


## Colours sampled from a preset, handy for matching fog/fill light to the sky.
static func palette(preset: int) -> Dictionary:
	var sky := make(preset)
	if sky == null or not sky.sky_material is ProceduralSkyMaterial:
		return {"horizon": Color(0.5, 0.55, 0.6), "top": Color(0.3, 0.4, 0.55)}
	var mat: ProceduralSkyMaterial = sky.sky_material
	return {"horizon": mat.sky_horizon_color, "top": mat.sky_top_color}
