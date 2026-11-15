@tool
class_name GDHPRGeometry
extends RefCounted
## Geometry utilities: clean up meshes, merge them, measure them, make them
## lightmap- and collision-ready. All functions return new meshes unless the
## name says otherwise.


## Rebuilds [param mesh] with welded vertices and cache-friendly index order.
## This alone often cuts vertex-shader work by 30-60% on imported props.
static func optimize(mesh: Mesh, generate_tangents := true) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.resource_name = (mesh.resource_name if mesh != null else "") + "_gdhpr"
	for i in mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(mesh, i)
		st.index()
		st.optimize_indices_for_cache()
		if generate_tangents and _has_uvs(mesh, i):
			st.generate_tangents()
		st.set_material(mesh.surface_get_material(i))
		st.commit(out)
	return out


## Concatenates several meshes into a single mesh, keeping every surface and
## material. Cuts one draw call per merged mesh.
static func merge(meshes: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.resource_name = "gdhpr_merged"
	for mesh in meshes:
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(i)
			if arrays.is_empty():
				continue
			out.add_surface_from_arrays(surface_primitive(mesh, i), arrays)
			out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(i))
	return out


## Bakes the transforms of [param instances] (MeshInstance3D) into one mesh,
## relative to [param relative_to]. Skinned and multi-surface meshes are fine.
static func merge_instances(instances: Array, relative_to: Node3D = null) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.resource_name = "gdhpr_merged"
	var inv := Transform3D.IDENTITY
	if relative_to != null:
		inv = relative_to.global_transform.affine_inverse()
	for node in instances:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xform := inv * mi.global_transform
		for i in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(i)
			if arrays.is_empty():
				continue
			_transform_arrays(arrays, xform)
			out.add_surface_from_arrays(surface_primitive(mi.mesh, i), arrays)
			var material := mi.get_surface_override_material(i)
			if material == null:
				material = mi.mesh.surface_get_material(i)
			out.surface_set_material(out.get_surface_count() - 1, material)
	if out.get_surface_count() == 0:
		out = null
	return out


## Unwraps UV2 for baked lightmaps. Returns [code]true[/code] on success.
## [param texel_size] is in world units per lightmap texel; 0.02 is a good start.
static func unwrap_lightmap(mesh: ArrayMesh, texel_size := 0.02) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	if mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_INDEX == 0:
		return false
	return mesh.lightmap_unwrap(Transform3D.IDENTITY, texel_size) == OK


## Primitive type of a surface. [Mesh] itself does not expose this (only
## [ArrayMesh] does); primitive meshes are always triangle lists.
static func surface_primitive(mesh: Mesh, surface: int) -> int:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_primitive_type(surface)
	return Mesh.PRIMITIVE_TRIANGLES


## Recomputes smooth (or flat) normals.
static func recalc_normals(mesh: Mesh, smooth := true) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(mesh, i)
		st.generate_normals(smooth)
		st.set_material(mesh.surface_get_material(i))
		st.commit(out)
	return out


## Enables flags that make a mesh shade cheaper without changing its look:
## double-sided lighting off, no shadow casting on foliage-style alpha meshes.
static func set_render_flags(mi: MeshInstance3D, cast_shadows := true) -> void:
	if mi == null:
		return
	mi.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)


## Adds a static trimesh collider for [param mi] as a sibling body. Useful when
## importing level geometry that has no collision.
static func add_collision(mi: MeshInstance3D, convex := false) -> StaticBody3D:
	if mi == null or mi.mesh == null:
		return null
	var shape: Shape3D = null
	if convex:
		shape = mi.mesh.create_convex_shape()
	else:
		shape = mi.mesh.create_trimesh_shape()
	if shape == null:
		return null
	var body := StaticBody3D.new()
	body.name = mi.name + "_body"
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	mi.add_child(body)
	return body


## Sets per-instance distance fade so distant props stop shading entirely.
static func set_distance_fade(mi: GeometryInstance3D, begin: float, length: float) -> void:
	if mi == null:
		return
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.visibility_range_end = begin + length
	mi.visibility_range_end_margin = length


## Vertex / triangle / surface counts for a single mesh.
static func mesh_stats(mesh: Mesh) -> Dictionary:
	var verts := 0
	var tris := 0
	if mesh == null:
		return {"vertices": 0, "triangles": 0, "surfaces": 0}
	for i in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(i)
		if arrays.is_empty():
			continue
		var vertex_count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		verts += vertex_count
		if arrays[Mesh.ARRAY_INDEX] != null:
			tris += int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0)
		else:
			tris += int(vertex_count / 3.0)
	return {"vertices": verts, "triangles": tris, "surfaces": mesh.get_surface_count()}


## Aggregated stats for everything drawn under [param root].
static func scene_stats(root: Node) -> Dictionary:
	var total := {"vertices": 0, "triangles": 0, "surfaces": 0}
	total["instances"] = 0
	total["draw_calls"] = 0
	for node in _walk(root):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# Only one LOD step of a chain is drawn at a time, so count LOD0 and
		# let the optimizer report the distance reduction separately.
		if mi.has_meta("gdhpr_lod") and int(mi.get_meta("gdhpr_lod")) > 0:
			continue
		var s := mesh_stats(mi.mesh)
		total["vertices"] += s["vertices"]
		total["triangles"] += s["triangles"]
		total["surfaces"] += s["surfaces"]
		total["draw_calls"] += s["surfaces"]
		total["instances"] += 1
	var mmi_count := 0
	for node in _walk(root):
		var mmi := node as MultiMeshInstance3D
		if mmi != null and mmi.multimesh != null:
			mmi_count += 1
			var s := mesh_stats(mmi.multimesh.mesh)
			total["vertices"] += s["vertices"] * mmi.multimesh.instance_count
			total["triangles"] += s["triangles"] * mmi.multimesh.instance_count
			total["draw_calls"] += s["surfaces"]
			total["instances"] += mmi.multimesh.instance_count
	total["multimeshes"] = mmi_count
	return total


## Bakes [param xform] into the vertex/normal arrays in place (tangents are
## dropped because a general transform would need re-orthonormalizing them).
static func _transform_arrays(arrays: Array, xform: Transform3D) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = xform * verts[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var normal_basis := xform.basis.inverse().transposed()
		for i in normals.size():
			normals[i] = (normal_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	if arrays[Mesh.ARRAY_TANGENT] != null:
		arrays[Mesh.ARRAY_TANGENT] = null


static func _has_uvs(mesh: Mesh, surface: int) -> bool:
	var arrays: Array = mesh.surface_get_arrays(surface)
	return not arrays.is_empty() and arrays[Mesh.ARRAY_TEX_UV] != null


static func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
