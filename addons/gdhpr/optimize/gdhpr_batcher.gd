@tool
class_name GDHPRBatcher
extends RefCounted
## Collapses identical repeated props into [MultiMeshInstance3D]s.
##
## This is the single biggest draw-call win on prop-heavy scenes (foliage,
## crates, rocks, city blocks): 200 identical crates become 1 draw call.
##
## Only "safe" instances are batched: leaf nodes, no script, no skeleton, no
## visibility ranges, same mesh + same material. Anything animated or scripted
## is left alone. The batch keeps every instance's world transform, so the
## result is visually identical.

const CONTAINER_NAME := "GDHPR_Batched"


## Batches [param root] and returns a report. Pass [param undo_redo] from an
## editor action to make the change undoable.
static func batch(root: Node, min_instances := 3, undo_redo: Variant = null) -> Dictionary:
	var report := {"groups": 0, "batched_instances": 0, "removed": 0}
	if root == null:
		return report

	var groups := {}
	for node in _walk(root):
		var mi := node as MeshInstance3D
		if not _is_batchable(mi) or node == root:
			continue
		var key := _group_key(mi)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(mi)

	var root3d := root as Node3D
	var inv := Transform3D.IDENTITY
	if root3d != null and root3d.is_inside_tree():
		inv = root3d.global_transform.affine_inverse()

	var container: Node3D = root.get_node_or_null(CONTAINER_NAME) as Node3D
	for key in groups:
		var members: Array = groups[key]
		if members.size() < maxi(min_instances, 2):
			continue

		var first: MeshInstance3D = members[0]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = first.mesh
		multimesh.instance_count = members.size()

		var bounds := AABB()
		var has_bounds := false
		for i in members.size():
			var mi: MeshInstance3D = members[i]
			var xform := mi.transform
			if mi.is_inside_tree() and root3d != null:
				xform = inv * mi.global_transform
			multimesh.set_instance_transform(i, xform)
			var local_aabb := mi.mesh.get_aabb()
			var world_aabb := xform * local_aabb
			bounds = world_aabb if not has_bounds else bounds.merge(world_aabb)
			has_bounds = true

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch_%s" % _clean_name(first.mesh.resource_name)
		mmi.multimesh = multimesh
		mmi.material_override = first.material_override
		mmi.cast_shadow = first.cast_shadow
		mmi.gi_mode = first.gi_mode
		mmi.layers = first.layers
		if has_bounds:
			mmi.custom_aabb = bounds.grow(0.5)

		if container == null:
			container = Node3D.new()
			container.name = CONTAINER_NAME
			_add_node(root, container, undo_redo)
		_add_node(container, mmi, undo_redo)

		for mi in members:
			_remove_node(mi, undo_redo)

		report["groups"] += 1
		report["batched_instances"] += members.size()
		report["removed"] += members.size()

	return report


## How many draw calls batching could save, without touching the scene.
static func analyze(root: Node, min_instances := 3) -> Dictionary:
	var groups := {}
	for node in _walk(root):
		var mi := node as MeshInstance3D
		if not _is_batchable(mi) or node == root:
			continue
		var key := _group_key(mi)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(mi)
	var candidates := 0
	var saved := 0
	for key in groups:
		var members: Array = groups[key]
		if members.size() < maxi(min_instances, 2):
			continue
		candidates += members.size()
		saved += members.size() - 1
	return {"instances": candidates, "draw_calls_saved": saved, "groups": groups.size()}


static func _is_batchable(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null:
		return false
	if not mi.is_visible_in_tree():
		return false
	if mi.skin != null:
		return false
	# [member MeshInstance3D.skeleton] defaults to "..", so only treat it as
	# skinned when it actually resolves to a Skeleton3D.
	if not mi.skeleton.is_empty() and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
		return false
	if mi.get_child_count() > 0 or mi.get_script() != null:
		return false
	for surface in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(surface) != null:
			return false
	if mi.visibility_range_begin > 0.0 or mi.visibility_range_end > 0.0:
		return false
	if mi.has_meta("gdhpr_lod") or mi.is_in_group("gdhpr_no_batch"):
		return false
	return true


static func _group_key(mi: MeshInstance3D) -> String:
	var material_id := mi.material_override.get_instance_id() if mi.material_override != null else 0
	return "%d|%d|%d|%d|%d" % [
		mi.mesh.get_instance_id(),
		material_id,
		mi.cast_shadow,
		mi.layers,
		mi.gi_mode,
	]


static func _add_node(parent: Node, child: Node, undo_redo: Variant) -> void:
	var owner_node := parent.owner
	if owner_node == null and parent is Node:
		owner_node = parent
	if undo_redo != null:
		undo_redo.add_do_method(parent, "add_child", child)
		if owner_node != null and owner_node != child:
			undo_redo.add_do_method(child, "set_owner", owner_node)
		undo_redo.add_do_reference(child)
		undo_redo.add_undo_method(parent, "remove_child", child)
		undo_redo.add_undo_reference(child)
	else:
		parent.add_child(child)
		if owner_node != null and owner_node != child:
			child.owner = owner_node


static func _remove_node(node: Node, undo_redo: Variant) -> void:
	var parent := node.get_parent()
	if parent == null:
		return
	if undo_redo != null:
		undo_redo.add_do_method(parent, "remove_child", node)
		undo_redo.add_do_reference(node)
		undo_redo.add_undo_method(parent, "add_child", node)
		undo_redo.add_undo_reference(node)
	else:
		parent.remove_child(node)
		node.queue_free()


static func _clean_name(source: String) -> String:
	var base := source.get_file().get_basename()
	if base.is_empty():
		base = "mesh"
	return base.validate_node_name()


static func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
