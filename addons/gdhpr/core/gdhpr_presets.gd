@tool
class_name GDHPRPresets
extends RefCounted
## Ready-made [GDHPRConfig] quality tiers.
##
## Each tier is a complete, self-consistent set of rendering options, so
## switching quality is a single assignment instead of twenty.

## Ordered names matching [enum GDHPRConfig.Quality].
const QUALITY_NAMES: PackedStringArray = ["Low", "Medium", "High", "Ultra", "Custom"]

## Ordered names matching [enum GDHPRConfig.Target].
const TARGET_NAMES: PackedStringArray = ["Auto", "Desktop", "Mobile", "Web"]

## Ordered names matching [member GDHPRConfig.lighting_rig].
const RIG_NAMES: PackedStringArray = [
	"None", "Studio", "Outdoor Day", "Golden Hour", "Indoor Warm", "Night", "Neon", "Product",
]

## Ordered names matching [member GDHPRConfig.sky].
const SKY_NAMES: PackedStringArray = [
	"None", "Studio", "Outdoor", "Golden Hour", "Dusk", "Night", "Neon", "Plain",
]


## Returns a fresh config for [param quality].
static func from_quality(quality: int, apply_caps := true) -> GDHPRConfig:
	var cfg := GDHPRConfig.new()
	cfg.quality = quality as GDHPRConfig.Quality
	cfg.preset_name = QUALITY_NAMES[clampi(quality, 0, QUALITY_NAMES.size() - 2)]

	match quality:
		GDHPRConfig.Quality.LOW:
			cfg.msaa_3d = Viewport.MSAA_DISABLED
			cfg.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			cfg.use_taa = false
			cfg.scaling_3d_scale = 0.8
			cfg.mesh_lod_threshold = 1.8
			cfg.shadow_atlas_size = 2048
			cfg.shadow_atlas_16_bits = true
			cfg.directional_shadow_distance = 60.0
			cfg.shadow_light_budget = 2
			cfg.sky = 7 # Plain, cheapest sky
			cfg.ambient_sky_contribution = 0.4
			cfg.tonemap_mode = Environment.TONE_MAPPER_ACES
			cfg.ssao_enabled = false
			cfg.ssil_enabled = false
			cfg.ssr_enabled = false
			cfg.sdfgi_enabled = false
			cfg.glow_enabled = false
			cfg.fog_enabled = true
			cfg.fog_density = 0.002
			cfg.volumetric_fog_enabled = false
			cfg.adjustment_enabled = false
			cfg.lod_min_triangles = 1500
			cfg.generate_lods = true
		GDHPRConfig.Quality.MEDIUM:
			cfg.msaa_3d = Viewport.MSAA_2X
			cfg.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			cfg.use_taa = true
			cfg.scaling_3d_scale = 0.9
			cfg.mesh_lod_threshold = 1.2
			cfg.shadow_atlas_size = 2048
			cfg.directional_shadow_distance = 90.0
			cfg.shadow_light_budget = 4
			cfg.sky = 2
			cfg.ssao_enabled = true
			cfg.ssao_radius = 1.2
			cfg.ssao_intensity = 1.4
			cfg.ssil_enabled = false
			cfg.ssr_enabled = false
			cfg.sdfgi_enabled = false
			cfg.glow_enabled = true
			cfg.glow_intensity = 0.35
			cfg.volumetric_fog_enabled = false
			cfg.fog_density = 0.003
		GDHPRConfig.Quality.HIGH:
			cfg.msaa_3d = Viewport.MSAA_2X
			cfg.use_taa = true
			cfg.scaling_3d_scale = 1.0
			cfg.mesh_lod_threshold = 1.0
			cfg.shadow_atlas_size = 4096
			cfg.directional_shadow_distance = 120.0
			cfg.shadow_light_budget = 6
			cfg.sky = 2
			cfg.ssao_enabled = true
			cfg.ssil_enabled = true
			cfg.ssil_radius = 3.0
			cfg.ssr_enabled = true
			cfg.ssr_max_steps = 48
			cfg.sdfgi_enabled = false
			cfg.glow_enabled = true
			cfg.volumetric_fog_enabled = true
			cfg.volumetric_fog_density = 0.008
		GDHPRConfig.Quality.ULTRA:
			cfg.msaa_3d = Viewport.MSAA_4X
			cfg.use_taa = true
			cfg.scaling_3d_scale = 1.0
			cfg.mesh_lod_threshold = 0.7
			cfg.shadow_atlas_size = 4096
			cfg.directional_shadow_distance = 180.0
			cfg.shadow_light_budget = 12
			cfg.sky = 2
			cfg.ssao_enabled = true
			cfg.ssao_radius = 2.0
			cfg.ssao_intensity = 2.4
			cfg.ssil_enabled = true
			cfg.ssil_radius = 4.0
			cfg.ssil_intensity = 1.4
			cfg.ssr_enabled = true
			cfg.ssr_max_steps = 128
			cfg.sdfgi_enabled = true
			cfg.sdfgi_cascades = 4
			cfg.glow_enabled = true
			cfg.glow_intensity = 0.7
			cfg.fog_enabled = true
			cfg.volumetric_fog_enabled = true
			cfg.volumetric_fog_density = 0.015
			cfg.volumetric_fog_length = 160.0
			cfg.apply_project_settings = true

	if apply_caps:
		cfg.apply_target_caps()
	return cfg


## Convenience: preset for a scene archetype. Keeps quality, retunes look.
## [param archetype] is one of: outdoor, indoor, night, product, neon.
static func from_archetype(archetype: String, quality := GDHPRConfig.Quality.HIGH) -> GDHPRConfig:
	var cfg := from_quality(quality)
	match archetype.to_lower():
		"outdoor":
			cfg.sky = 2
			cfg.lighting_rig = 2
			cfg.fog_density = 0.0025
			cfg.fog_aerial_perspective = 0.6
			cfg.ambient_energy = 1.0
			cfg.tonemap_exposure = 0.9
		"indoor":
			cfg.sky = 1
			cfg.lighting_rig = 4
			cfg.fog_density = 0.006
			cfg.ambient_sky_contribution = 0.35
			cfg.ambient_energy = 0.7
			cfg.ssao_intensity = 2.6
			cfg.tonemap_exposure = 1.15
		"night":
			cfg.sky = 5
			cfg.lighting_rig = 5
			cfg.glow_intensity = 1.1
			cfg.glow_bloom = 0.15
			cfg.tonemap_exposure = 1.4
			cfg.ambient_energy = 0.35
			cfg.fog_density = 0.01
			cfg.fog_sky_affect = 0.6
			cfg.ssao_intensity = 2.2
		"neon":
			cfg.sky = 6
			cfg.lighting_rig = 6
			cfg.glow_intensity = 1.6
			cfg.glow_bloom = 0.25
			cfg.tonemap_exposure = 1.2
			cfg.ambient_energy = 0.3
			cfg.volumetric_fog_enabled = true
			cfg.volumetric_fog_density = 0.03
			cfg.ssr_enabled = true
		"product":
			cfg.sky = 1
			cfg.lighting_rig = 7
			cfg.fog_enabled = false
			cfg.volumetric_fog_enabled = false
			cfg.tonemap_exposure = 1.0
			cfg.ssao_intensity = 3.0
			cfg.glow_intensity = 0.25
			cfg.adjustment_contrast = 1.1
	return cfg


## All built-in presets, for UI listing.
static func all_names() -> PackedStringArray:
	var out := PackedStringArray()
	for i in QUALITY_NAMES.size() - 1:
		out.append(QUALITY_NAMES[i])
	return out
