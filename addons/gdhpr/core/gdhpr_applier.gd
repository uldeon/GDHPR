@tool
class_name GDHPRApplier
extends RefCounted
## Pushes a [GDHPRConfig] into a live scene: [Environment], [Viewport] and
## the matching directional lights. This is the engine-facing half of GDHPR;
## call [method GDHPR.apply] instead of using this directly.

## Project settings GDHPR knows how to write, with the value each one gets.
const PROJECT_SETTINGS_SHADOWS := {
	"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality": 2,
	"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 2,
}


## Applies [param cfg] to [param scene_root]. Returns a small report dictionary.
## [param undo_redo] accepts an [UndoRedo] or an [EditorUndoRedoManager].
static func apply(cfg: GDHPRConfig, scene_root: Node, undo_redo: Variant = null) -> Dictionary:
	var report := {"environment": false, "viewport": false, "lights": 0}
	if cfg == null or scene_root == null:
		return report

	var we := find_world_environment(scene_root)
	if we == null:
		we = _create_world_environment(scene_root, undo_redo)
	if we != null:
		if we.environment == null:
			we.environment = Environment.new()
		apply_environment(cfg, we.environment)
		report.environment = true

	var vp := scene_root.get_viewport()
	if vp != null:
		apply_viewport(cfg, vp)
		report.viewport = true

	report.lights = apply_light_distance(cfg, scene_root)

	if cfg.apply_project_settings:
		apply_project_settings(cfg)

	return report


## Finds the first [WorldEnvironment] anywhere under [param root].
static func find_world_environment(root: Node) -> WorldEnvironment:
	if root is WorldEnvironment:
		return root
	for child in root.get_children():
		var found := find_world_environment(child)
		if found != null:
			return found
	return null


static func _create_world_environment(root: Node, undo_redo: Variant) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "GDHPREnvironment"
	we.environment = Environment.new()
	if undo_redo != null:
		undo_redo.add_do_method(root, "add_child", we)
		undo_redo.add_do_method(we, "set_owner", root.owner if root.owner else root)
		undo_redo.add_do_reference(we)
		undo_redo.add_undo_method(root, "remove_child", we)
	else:
		root.add_child(we)
		if root.owner != null:
			we.owner = root.owner
	return we


## Writes every environment knob. Safe to call on an existing [Environment].
static func apply_environment(cfg: GDHPRConfig, env: Environment) -> void:
	if cfg.sky > 0:
		var sky := GDHPRSky.make(cfg.sky)
		if sky != null:
			env.sky = sky
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.background_energy_multiplier = cfg.background_energy
	env.ambient_light_energy = cfg.ambient_energy
	env.ambient_light_sky_contribution = cfg.ambient_sky_contribution

	env.tonemap_mode = cfg.tonemap_mode
	env.tonemap_exposure = cfg.tonemap_exposure
	env.tonemap_white = cfg.tonemap_white

	env.ssao_enabled = cfg.ssao_enabled
	env.ssao_radius = cfg.ssao_radius
	env.ssao_intensity = cfg.ssao_intensity
	env.ssao_power = cfg.ssao_power

	env.ssil_enabled = cfg.ssil_enabled
	env.ssil_radius = cfg.ssil_radius
	env.ssil_intensity = cfg.ssil_intensity

	env.ssr_enabled = cfg.ssr_enabled
	env.ssr_max_steps = cfg.ssr_max_steps

	env.sdfgi_enabled = cfg.sdfgi_enabled
	env.sdfgi_cascades = cfg.sdfgi_cascades
	env.sdfgi_min_cell_size = cfg.sdfgi_min_cell_size

	env.glow_enabled = cfg.glow_enabled
	env.glow_intensity = cfg.glow_intensity
	env.glow_bloom = cfg.glow_bloom
	env.glow_hdr_threshold = cfg.glow_hdr_threshold
	env.glow_blend_mode = cfg.glow_blend_mode

	env.fog_enabled = cfg.fog_enabled
	env.fog_density = cfg.fog_density
	env.fog_aerial_perspective = cfg.fog_aerial_perspective
	env.fog_sky_affect = cfg.fog_sky_affect
	if cfg.sky > 0:
		env.fog_light_color = GDHPRSky.palette(cfg.sky)["horizon"]

	env.volumetric_fog_enabled = cfg.volumetric_fog_enabled
	env.volumetric_fog_density = cfg.volumetric_fog_density
	env.volumetric_fog_anisotropy = cfg.volumetric_fog_anisotropy
	env.volumetric_fog_length = cfg.volumetric_fog_length

	env.adjustment_enabled = cfg.adjustment_enabled
	env.adjustment_brightness = cfg.adjustment_brightness
	env.adjustment_contrast = cfg.adjustment_contrast
	env.adjustment_saturation = cfg.adjustment_saturation


## Writes the viewport-level quality knobs (AA, upscaling, LOD bias, shadows).
static func apply_viewport(cfg: GDHPRConfig, vp: Viewport) -> void:
	vp.msaa_3d = cfg.msaa_3d
	vp.screen_space_aa = cfg.screen_space_aa
	vp.use_taa = cfg.use_taa
	vp.scaling_3d_mode = cfg.scaling_3d_mode
	vp.scaling_3d_scale = cfg.scaling_3d_scale
	vp.fsr_sharpness = cfg.fsr_sharpness
	vp.mesh_lod_threshold = cfg.mesh_lod_threshold
	vp.positional_shadow_atlas_size = cfg.shadow_atlas_size
	vp.positional_shadow_atlas_16_bits = cfg.shadow_atlas_16_bits


## Tightens directional shadow distance on every [DirectionalLight3D] found.
## Returns how many lights were touched.
static func apply_light_distance(cfg: GDHPRConfig, root: Node) -> int:
	var count := 0
	for node in _collect(root, "DirectionalLight3D"):
		var light := node as DirectionalLight3D
		light.directional_shadow_max_distance = cfg.directional_shadow_distance
		if cfg.quality == GDHPRConfig.Quality.LOW:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		count += 1
	return count


## Writes recommended project settings. Requires an editor restart to apply.
static func apply_project_settings(cfg: GDHPRConfig) -> void:
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_debanding", cfg.use_debanding)
	ProjectSettings.set_setting("rendering/occlusion_culling/use_occlusion_culling", cfg.occlusion_culling)
	for key in PROJECT_SETTINGS_SHADOWS:
		ProjectSettings.set_setting(key, cfg.soft_shadow_filter_quality)
	ProjectSettings.set_setting(
		"rendering/lights_and_shadows/directional_shadow/size",
		clampi(cfg.shadow_atlas_size, 2048, 8192)
	)


static func _collect(root: Node, class_name_filter: String) -> Array[Node]:
	var out: Array[Node] = []
	if root.is_class(class_name_filter):
		out.append(root)
	for child in root.get_children():
		out.append_array(_collect(child, class_name_filter))
	return out
