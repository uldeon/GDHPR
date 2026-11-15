@tool
class_name GDHPROptimizer
extends RefCounted
## One-call scene optimization pass plus a before/after report.
##
## [codeblock]
## var report := GDHPROptimizer.run(get_tree().current_scene, GDHPRPresets.from_quality(GDHPRConfig.Quality.HIGH))
## print(GDHPROptimizer.format_report(report))
## [/codeblock]


## Read-only analysis: what could be optimized, and how much is on screen.
static func analyze(root: Node, min_instances := 3) -> Dictionary:
	var stats := GDHPRGeometry.scene_stats(root)
	var batchable := GDHPRBatcher.analyze(root, min_instances)
	var heavy := 0
	var heavy_triangles := 0
	var lights := 0
	var shadow_lights := 0
	for node in _walk(root):
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null or mi.has_meta("gdhpr_lod"):
				continue
			var mesh_stats := GDHPRGeometry.mesh_stats(mi.mesh)
			if int(mesh_stats["triangles"]) >= 3000:
				heavy += 1
				heavy_triangles += int(mesh_stats["triangles"])
		elif node is Light3D:
			lights += 1
			if (node as Light3D).shadow_enabled:
				shadow_lights += 1
	return {
		"stats": stats,
		"batchable": batchable,
		"heavy_meshes": heavy,
		"heavy_triangles": heavy_triangles,
		"lights": lights,
		"shadow_lights": shadow_lights,
	}


## Runs the full pass described by [param cfg] and returns a report dictionary.
## Pass an [UndoRedo] from an editor action to make everything undoable.
static func run(root: Node, cfg: GDHPRConfig, undo_redo: Variant = null) -> Dictionary:
	var report := {"actions": [], "before": {}, "after": {}, "error": ""}
	if root == null or cfg == null:
		report["error"] = "Nothing to optimize."
		return report
	report["before"] = GDHPRGeometry.scene_stats(root)

	if cfg.batch_meshes:
		var batched := GDHPRBatcher.batch(root, cfg.batch_min_instances, undo_redo)
		if int(batched["groups"]) > 0:
			report["actions"].append(
				"Batched %d repeated meshes into %d MultiMesh groups."
				% [batched["batched_instances"], batched["groups"]]
			)
		else:
			report["actions"].append("Batching: no repeated meshes found.")

	if cfg.generate_lods:
		var lod_count := 0
		var near_triangles := 0
		var far_triangles := 0
		var distances: Array = [cfg.view_distance * 0.35, cfg.view_distance * 0.8]
		var owner_node: Node = root.owner if root.owner != null else root
		for node in _walk(root):
			var mi := node as MeshInstance3D
			if mi == null or mi.mesh == null or mi.has_meta("gdhpr_lod"):
				continue
			if mi.get_child_count() > 0 or mi.get_script() != null:
				continue
			var mesh_stats := GDHPRGeometry.mesh_stats(mi.mesh)
			var triangles := int(mesh_stats["triangles"])
			if triangles < cfg.lod_min_triangles:
				continue
			var created := GDHPRLOD.generate(mi, GDHPRLOD.DEFAULT_RATIOS, distances, owner_node, undo_redo)
			if created.is_empty():
				continue
			lod_count += 1
			near_triangles += triangles
			far_triangles += int(GDHPRGeometry.mesh_stats(created[created.size() - 1].mesh)["triangles"])
		if lod_count > 0:
			report["actions"].append(
				"Generated %d LOD chains: %s → %s triangles at distance."
				% [lod_count, _thousands(near_triangles), _thousands(far_triangles)]
			)
		else:
			report["actions"].append("LODs: no mesh exceeded %d triangles." % cfg.lod_min_triangles)

	if cfg.budget_lights_at_runtime:
		var manager := root.get_node_or_null("GDHPRLightManager") as GDHPRLightManager
		if manager == null:
			manager = GDHPRLightManager.new()
			manager.name = "GDHPRLightManager"
			manager.shadow_budget = cfg.shadow_light_budget
			manager.max_distance = cfg.view_distance
			if undo_redo != null:
				undo_redo.add_do_method(root, "add_child", manager)
				undo_redo.add_do_method(manager, "set_owner", root.owner if root.owner != null else root)
				undo_redo.add_do_reference(manager)
				undo_redo.add_undo_method(root, "remove_child", manager)
			else:
				root.add_child(manager)
				if root.owner != null:
					manager.owner = root.owner
			report["actions"].append("Added a runtime light budget (max %d shadow lights)." % cfg.shadow_light_budget)
		else:
			manager.shadow_budget = cfg.shadow_light_budget
			manager.max_distance = cfg.view_distance
			report["actions"].append("Updated the existing runtime light budget.")

	report["after"] = GDHPRGeometry.scene_stats(root)
	report["draw_calls_saved"] = maxi(
		int(report["before"]["draw_calls"]) - int(report["after"]["draw_calls"]), 0
	)
	return report


## Pretty-prints a report for the dock / console.
static func format_report(report: Dictionary) -> String:
	if report.has("error") and not String(report["error"]).is_empty():
		return String(report["error"])
	var before: Dictionary = report.get("before", {})
	var after: Dictionary = report.get("after", {})
	var lines := PackedStringArray()
	for action in report.get("actions", []):
		lines.append("• " + String(action))
	if not before.is_empty():
		lines.append("")
		lines.append(
			"Draw calls: %d → %d    Instances: %d → %d"
			% [
				before.get("draw_calls", 0),
				after.get("draw_calls", 0),
				before.get("instances", 0),
				after.get("instances", 0),
			]
		)
		lines.append(
			"Triangles: %s → %s"
			% [_thousands(before.get("triangles", 0)), _thousands(after.get("triangles", 0))]
		)
	return "\n".join(lines)


static func _thousands(value: int) -> String:
	var text := str(value)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


static func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
