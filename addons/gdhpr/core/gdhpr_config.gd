@tool
class_name GDHPRConfig
extends Resource
## Every 3D rendering knob GDHPR knows about, in one resource.
##
## Create one with [method GDHPRPresets.from_quality] (or the GDHPR dock) and
## hand it to [method GDHPR.apply]. Everything is grouped and preset driven so a
## whole scene can be retuned from one place instead of a dozen inspector panels.

enum Quality { LOW, MEDIUM, HIGH, ULTRA, CUSTOM }
enum Target { AUTO, DESKTOP, MOBILE, WEB }
enum ScalingMode { BILINEAR = 0, FSR1 = 1, FSR2 = 2, NEAREST = 5 }

@export_group("Preset")
## Human readable name of the preset this config came from.
@export var preset_name: String = "High"
@export var quality: Quality = Quality.HIGH:
	set(value):
		quality = value
		notify_property_list_changed()
## Hardware this config is being tuned for. AUTO resolves on first use.
@export var target: Target = Target.AUTO

@export_group("Viewport")
@export var msaa_3d: Viewport.MSAA = Viewport.MSAA_2X
@export var screen_space_aa: Viewport.ScreenSpaceAA = Viewport.SCREEN_SPACE_AA_FXAA
@export var use_taa: bool = true
@export var scaling_3d_mode: Viewport.Scaling3DMode = Viewport.SCALING_3D_MODE_BILINEAR
## Render resolution multiplier. 1.0 is native, 0.75 is a good "cheap" setting.
@export_range(0.4, 1.0, 0.01) var scaling_3d_scale: float = 1.0
@export_range(0.0, 2.0, 0.05) var fsr_sharpness: float = 0.2
## Higher values switch mesh LODs / visibility ranges sooner (cheaper, uglier).
@export_range(0.0, 4.0, 0.05) var mesh_lod_threshold: float = 1.0

@export_group("Shadows")
@export_range(512, 8192, 512) var shadow_atlas_size: int = 4096
@export var shadow_atlas_16_bits: bool = false
## Distance at which directional/sun shadows stop being drawn.
@export_range(20.0, 500.0, 1.0) var directional_shadow_distance: float = 120.0
## Soft shadow filtering is a project setting; applied when [member apply_project_settings] is on.
@export_range(0, 4, 1) var soft_shadow_filter_quality: int = 2
## Maximum number of shadow casting lights kept alive by [GDHPRLightManager].
@export_range(0, 32, 1) var shadow_light_budget: int = 6

@export_group("Environment")
## 0 = none (keep whatever the scene already has).
@export_enum("None", "Studio", "Outdoor", "Golden Hour", "Dusk", "Night", "Neon", "Plain") var sky: int = 2
@export var background_energy: float = 1.0
@export var ambient_energy: float = 1.0
@export var ambient_sky_contribution: float = 0.85
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_ACES
@export_range(0.1, 8.0, 0.01) var tonemap_exposure: float = 1.0
@export var tonemap_white: float = 6.0

@export_group("Environment / AO")
@export var ssao_enabled: bool = true
@export_range(0.0, 8.0, 0.05) var ssao_radius: float = 1.6
@export_range(0.0, 8.0, 0.05) var ssao_intensity: float = 2.0
@export_range(0.0, 4.0, 0.05) var ssao_power: float = 1.6
@export var ssil_enabled: bool = false
@export_range(0.0, 8.0, 0.05) var ssil_radius: float = 4.0
@export_range(0.0, 8.0, 0.05) var ssil_intensity: float = 1.0

@export_group("Environment / Reflections")
@export var ssr_enabled: bool = false
@export_range(1, 512, 1) var ssr_max_steps: int = 64
@export var sdfgi_enabled: bool = false
@export_range(1, 8, 1) var sdfgi_cascades: int = 3
@export_range(0.05, 1.0, 0.01) var sdfgi_min_cell_size: float = 0.2

@export_group("Environment / Glow")
@export var glow_enabled: bool = true
@export_range(0.0, 4.0, 0.01) var glow_intensity: float = 0.5
@export_range(0.0, 1.0, 0.01) var glow_bloom: float = 0.05
@export_range(0.0, 4.0, 0.01) var glow_hdr_threshold: float = 1.0
@export var glow_blend_mode: Environment.GlowBlendMode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

@export_group("Environment / Fog")
@export var fog_enabled: bool = true
@export_range(0.0, 0.1, 0.0001) var fog_density: float = 0.004
@export_range(0.0, 1.0, 0.01) var fog_aerial_perspective: float = 0.4
@export_range(0.0, 1.0, 0.01) var fog_sky_affect: float = 0.4
@export var volumetric_fog_enabled: bool = false
@export_range(0.0, 0.5, 0.001) var volumetric_fog_density: float = 0.02
@export_range(-1.0, 1.0, 0.01) var volumetric_fog_anisotropy: float = 0.2
@export_range(16.0, 512.0, 1.0) var volumetric_fog_length: float = 96.0

@export_group("Environment / Color")
@export var adjustment_enabled: bool = true
@export_range(0.5, 2.0, 0.01) var adjustment_brightness: float = 1.0
@export_range(0.5, 2.0, 0.01) var adjustment_contrast: float = 1.05
@export_range(0.0, 2.0, 0.01) var adjustment_saturation: float = 1.05

@export_group("Scene")
## 0 = none. Adds [GDHPRLightingRig] when [method GDHPR.apply] runs on a scene.
@export_enum("None", "Studio", "Outdoor Day", "Golden Hour", "Indoor Warm", "Night", "Neon", "Product") var lighting_rig: int = 0
## Merge identical static meshes into MultiMeshes (big draw-call win).
@export var batch_meshes: bool = true
## Only batch groups with at least this many copies.
@export_range(2, 64, 1) var batch_min_instances: int = 3
## Generate lower-poly shadow/LOD copies for heavy meshes.
@export var generate_lods: bool = true
## Triangle count above which a mesh is considered for LOD generation.
@export_range(100, 100000, 100) var lod_min_triangles: int = 3000
## Disable shadow casting on small/distant props at runtime.
@export var budget_lights_at_runtime: bool = false
## Distance past which props stop being drawn by the light manager / LODs start.
@export_range(10.0, 500.0, 1.0) var view_distance: float = 150.0

@export_group("Project Settings")
## Writes recommended project settings (debanding, occlusion culling, shadow
## filter quality). These only take effect after an editor restart.
@export var apply_project_settings: bool = false
@export var use_debanding: bool = true
@export var occlusion_culling: bool = true


## Deep copy so presets can be handed out and edited without touching the original.
func copy() -> GDHPRConfig:
	return duplicate(true) as GDHPRConfig


## Resolves [member target] to a concrete device class.
func resolved_target() -> Target:
	if target != Target.AUTO:
		return target
	if OS.has_feature("web"):
		return Target.WEB
	if OS.has_feature("mobile"):
		return Target.MOBILE
	return Target.DESKTOP


## Applies mobile/web safety caps on top of whatever the preset asked for.
func apply_target_caps() -> GDHPRConfig:
	match resolved_target():
		Target.MOBILE:
			ssil_enabled = false
			ssr_enabled = false
			sdfgi_enabled = false
			volumetric_fog_enabled = false
			msaa_3d = Viewport.MSAA_2X
			shadow_atlas_size = mini(shadow_atlas_size, 2048)
			scaling_3d_scale = minf(scaling_3d_scale, 0.85)
		Target.WEB:
			ssil_enabled = false
			ssr_enabled = false
			sdfgi_enabled = false
			volumetric_fog_enabled = false
			use_taa = false
			shadow_atlas_size = mini(shadow_atlas_size, 2048)
	return self


## Short one-line summary used by the dock and the report output.
func describe() -> String:
	return "%s (%s, %s)" % [
		preset_name,
		Quality.keys()[quality],
		Target.keys()[resolved_target()],
	]
