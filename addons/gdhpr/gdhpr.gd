@tool
class_name GDHPR
extends RefCounted
## GDHPR — Godot High Performance Rendering.
##
## The one-stop entry point. Everything else in the addon is reachable from
## here, so normal use never needs more than three lines:
##
## [codeblock]
## var cfg := GDHPR.config("high")
## GDHPR.apply(cfg, get_tree().current_scene)
## GDHPR.optimize(get_tree().current_scene, cfg)
## [/codeblock]
##
## Or, in the editor, open the GDHPR dock and press the buttons.

const VERSION := "1.0.0"

## Source of truth for the addon's own folder, so callers never hardcode paths.
const ADDON_PATH := "res://addons/gdhpr"


## Returns a fresh config for a quality tier: "low", "medium", "high", "ultra".
static func config(quality_name: String) -> GDHPRConfig:
	var index := GDHPRPresets.QUALITY_NAMES.find(quality_name.capitalize())
	if index < 0:
		index = GDHPRConfig.Quality.HIGH
	return GDHPRPresets.from_quality(index)


## Full quality preset for a scene archetype: outdoor, indoor, night, neon, product.
static func archetype_config(archetype: String, quality_name := "high") -> GDHPRConfig:
	var index := GDHPRPresets.QUALITY_NAMES.find(quality_name.capitalize())
	if index < 0:
		index = GDHPRConfig.Quality.HIGH
	return GDHPRPresets.from_archetype(archetype, index)


## Applies rendering settings from [param cfg] to [param scene_root]
## (defaults to the current scene). Returns an applier report.
static func apply(cfg: GDHPRConfig, scene_root: Node = null, undo_redo: Variant = null) -> Dictionary:
	var root := _resolve_root(scene_root)
	if root == null:
		push_warning("GDHPR.apply: no scene root found.")
		return {}
	return GDHPRApplier.apply(cfg, root, undo_redo)


## Runs the optimization pass (batching, LODs, light budget) on [param scene_root].
static func optimize(scene_root: Node = null, cfg: GDHPRConfig = null, undo_redo: Variant = null) -> Dictionary:
	var root := _resolve_root(scene_root)
	if root == null:
		return {"error": "GDHPR.optimize: no scene root found."}
	var use_cfg := cfg if cfg != null else config("high")
	return GDHPROptimizer.run(root, use_cfg, undo_redo)


## Adds a lighting rig: "studio", "outdoor", "golden", "indoor", "night", "neon", "product".
static func rig(mood_name: String, parent: Node3D = null) -> Node3D:
	var moods := {
		"studio": 1, "outdoor": 2, "golden": 3, "indoor": 4, "night": 5, "neon": 6, "product": 7,
	}
	var index: int = moods.get(mood_name.to_lower(), 1)
	return GDHPRLightingRig.build(index, parent)


## Returns a material preset, e.g. "metal", "concrete", "marble", "car_paint".
static func material(preset_name: String, detail := true) -> StandardMaterial3D:
	return GDHPRMaterialLibrary.preset(preset_name, detail)


## The whole "make my scene look good and run fast" flow in one call.
## [param archetype] may be empty; otherwise outdoor/indoor/night/neon/product.
static func setup(
	scene_root: Node = null,
	quality_name := "high",
	archetype := "",
	with_rig := true,
	with_optimize := true
) -> Dictionary:
	var root := _resolve_root(scene_root)
	if root == null:
		return {"error": "GDHPR.setup: no scene root found."}
	var cfg: GDHPRConfig = archetype_config(archetype, quality_name) if not archetype.is_empty() else config(quality_name)
	var applied := apply(cfg, root)
	var rigged := false
	if with_rig and cfg.lighting_rig > 0:
		var parent3d := root as Node3D
		if parent3d != null and GDHPRLightingRig.ensure(cfg.lighting_rig, parent3d) != null:
			rigged = true
	var optimized := {}
	if with_optimize:
		optimized = optimize(root, cfg)
	return {"config": cfg, "applied": applied, "rigged": rigged, "optimized": optimized}


## Read-only analysis of the current scene.
static func analyze(scene_root: Node = null) -> Dictionary:
	var root := _resolve_root(scene_root)
	if root == null:
		return {}
	return GDHPROptimizer.analyze(root)


## Human readable summary of what is currently in the scene.
static func report(scene_root: Node = null) -> String:
	var root := _resolve_root(scene_root)
	if root == null:
		return "GDHPR %s — no scene." % VERSION
	var info := GDHPROptimizer.analyze(root)
	var stats: Dictionary = info["stats"]
	var batch: Dictionary = info["batchable"]
	return "\n".join(PackedStringArray([
		"GDHPR %s" % VERSION,
		"Instances: %d   Draw calls: %d   Triangles: %d" % [
			stats["instances"], stats["draw_calls"], stats["triangles"],
		],
		"Lights: %d (%d casting shadows)" % [info["lights"], info["shadow_lights"]],
		"Batching could save %d draw calls (%d instances in %d groups)." % [
			batch["draw_calls_saved"], batch["instances"], batch["groups"],
		],
	]))


static func _resolve_root(scene_root: Node) -> Node:
	if scene_root != null:
		return scene_root
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).current_scene
	return null
