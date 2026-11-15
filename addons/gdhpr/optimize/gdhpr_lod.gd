@tool
class_name GDHPRLOD
extends RefCounted
## Automatic LOD chains built from decimated copies of a mesh.
##
## Call [method generate] on a heavy [MeshInstance3D]; GDHPR adds lower-poly
## siblings driven by [member GeometryInstance3D.visibility_range_end], so the
## engine swaps detail based on distance with zero runtime cost.

## Default distance (metres) at which each LOD step takes over.
const DEFAULT_DISTANCES := [45.0, 110.0]
## Default vertex ratio kept per LOD step.
const DEFAULT_RATIOS := [0.55, 0.22, 0.08]


## Builds LOD steps for [param mi] and returns the created instances.
## [param owner_node] should be the edited scene root when running in the editor.
static func generate(
	mi: MeshInstance3D,
	ratios: Array = DEFAULT_RATIOS,
	distances: Array = DEFAULT_DISTANCES,
	owner_node: Node = null,
	undo_redo: Variant = null
) -> Array[MeshInstance3D]:
	var created: Array[MeshInstance3D] = []
	if mi == null or mi.mesh == null or mi.get_parent() == null:
		return created
	if mi.has_meta("gdhpr_lod"):
		return created

	var steps: int = mini(distances.size() + 1, ratios.size())
	if steps < 2:
		return created

	# LOD0 is the original mesh: it needs the shortest draw range.
	if undo_redo != null:
		undo_redo.add_do_property(mi, "visibility_range_end", distances[0])
		undo_redo.add_undo_property(mi, "visibility_range_end", mi.visibility_range_end)
		undo_redo.add_do_property(mi, "visibility_range_fade_mode", GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
		undo_redo.add_undo_property(mi, "visibility_range_fade_mode", mi.visibility_range_fade_mode)
	mi.visibility_range_end = distances[0]
	mi.visibility_range_end_margin = _fade_margin(distances[0])
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.set_meta("gdhpr_lod", 0)
	mi.set_meta("gdhpr_lod_id", mi.get_instance_id())

	for step in range(1, steps):
		var ratio: float = ratios[step]
		var lod_mesh := GDHPRDecimator.simplify(mi.mesh, ratio)
		if lod_mesh == null or lod_mesh.get_surface_count() == 0:
			break
		var clone := MeshInstance3D.new()
		clone.name = "%s_LOD%d" % [mi.name, step]
		clone.mesh = lod_mesh
		clone.transform = mi.transform
		clone.cast_shadow = mi.cast_shadow
		clone.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		clone.lod_bias = mi.lod_bias
		clone.visibility_range_begin = distances[step - 1]
		clone.visibility_range_begin_margin = _fade_margin(distances[step - 1])
		if step < steps - 1:
			clone.visibility_range_end = distances[step]
			clone.visibility_range_end_margin = _fade_margin(distances[step])
		clone.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		clone.set_meta("gdhpr_lod", step)
		clone.set_meta("gdhpr_lod_id", mi.get_instance_id())
		# Distant steps do not need to cast shadows: this pays for itself fast.
		if step >= steps - 1:
			clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if undo_redo != null:
			undo_redo.add_do_method(mi.get_parent(), "add_child", clone)
			if owner_node != null:
				undo_redo.add_do_method(clone, "set_owner", owner_node)
			undo_redo.add_do_reference(clone)
			undo_redo.add_undo_method(mi.get_parent(), "remove_child", clone)
			undo_redo.add_undo_reference(clone)
		else:
			mi.get_parent().add_child(clone)
			if owner_node != null:
				clone.owner = owner_node
		created.append(clone)
	return created


## Merged shadow mesh for [param mi]: a cheap lower-poly mesh only used for
## shadow rendering. Saves a lot of shadow-map geometry on heavy props.
static func make_shadow_mesh(mi: MeshInstance3D, ratio := 0.3) -> ArrayMesh:
	if mi == null or mi.mesh == null:
		return null
	return GDHPRDecimator.simplify(mi.mesh, ratio)


## Removes a chain created by [method generate] (including the LOD0 range).
static func clear(mi: MeshInstance3D) -> void:
	if mi == null:
		return
	var chain_id: int = mi.get_meta("gdhpr_lod_id", mi.get_instance_id())
	mi.remove_meta("gdhpr_lod")
	mi.remove_meta("gdhpr_lod_id")
	mi.visibility_range_end = 0.0
	mi.visibility_range_end_margin = 0.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var parent := mi.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is MeshInstance3D and child.get_meta("gdhpr_lod_id", 0) == chain_id:
			parent.remove_child(child)
			child.queue_free()


static func _fade_margin(distance: float) -> float:
	return maxf(distance * 0.08, 1.0)
