@tool
class_name GDHPRWorld
extends Node3D
## Drop this one node in a 3D scene and GDHPR configures everything else:
## environment, sky, viewport quality, lighting rig and — optionally — the
## optimization pass, at runtime.
##
## It is inert in the editor on purpose: opening a scene never silently
## restructures it. Use the GDHPR dock for editor-time changes.

## Optional explicit config. When empty, one is generated from the fields below.
@export var config: GDHPRConfig = null
@export var quality: GDHPRConfig.Quality = GDHPRConfig.Quality.HIGH
## "none", or one of: outdoor, indoor, night, neon, product.
@export_enum("none", "outdoor", "indoor", "night", "neon", "product") var archetype: String = "none"
## Adds a lighting rig matching [member GDHPRConfig.lighting_rig].
@export var build_lighting_rig: bool = true
## Runs batching / LOD generation on startup (best done in the editor instead).
@export var optimize_on_ready: bool = false
## Creates an orbit camera if the scene has no active 3D camera.
@export var create_camera: bool = true
@export var camera_distance: float = 9.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	configure()


## Applies the config now. Safe to call again after changing quality.
func configure() -> Dictionary:
	var cfg := active_config()
	var result := GDHPRApplier.apply(cfg, self)
	if build_lighting_rig and cfg.lighting_rig > 0:
		var rig := GDHPRLightingRig.ensure(cfg.lighting_rig, self)
		result["rigged"] = rig != null
	if create_camera and get_viewport() != null and get_viewport().get_camera_3d() == null:
		var cam := GDHPROrbitCamera.new()
		cam.name = "GDHPROrbitCamera"
		cam.distance = camera_distance
		add_child(cam)
		result["camera"] = true
	if optimize_on_ready:
		result["optimized"] = GDHPROptimizer.run(self, cfg)
	return result


## The config in use: the assigned one, or a generated one.
func active_config() -> GDHPRConfig:
	if config != null:
		if archetype != "none" and not archetype.is_empty():
			return GDHPRPresets.from_archetype(archetype, quality)
		return config
	if archetype != "none" and not archetype.is_empty():
		return GDHPRPresets.from_archetype(archetype, quality)
	return GDHPRPresets.from_quality(quality)


## Switches quality live. With an assigned [member config] the matching preset
## is applied while your config resource keeps its identity.
func set_quality(new_quality: GDHPRConfig.Quality) -> void:
	quality = new_quality
	var regenerated := GDHPRPresets.from_quality(new_quality)
	if config != null:
		regenerated.apply_project_settings = config.apply_project_settings
		config.quality = new_quality
		config.preset_name = regenerated.preset_name
	GDHPRApplier.apply(regenerated, self)
	if build_lighting_rig and regenerated.lighting_rig > 0:
		GDHPRLightingRig.ensure(regenerated.lighting_rig, self)


## Convenience for UI: cycles through the quality tiers.
func cycle_quality() -> GDHPRConfig.Quality:
	var next: int = (int(quality) + 1) % 4
	set_quality(next as GDHPRConfig.Quality)
	return quality
