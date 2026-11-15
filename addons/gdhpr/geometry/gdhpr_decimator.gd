@tool
class_name GDHPRDecimator
extends RefCounted
## Mesh simplification by vertex clustering (a.k.a. voxel-grid decimation).
##
## It is not as pretty as quadric edge collapse, but it is fast, robust on
## broken/boolean/scan meshes, and it keeps UVs, vertex colours and materials.
## Perfect for generating LOD and shadow meshes at bake time.
##
## Usage:
## [codeblock]
## var low: ArrayMesh = GDHPRDecimator.simplify(mesh, 0.35)
## [/codeblock]

## Meshes above this vertex count are skipped with a warning to avoid freezing
## the editor. Split huge meshes or decimate them offline.
const MAX_VERTICES := 600_000


## Returns a new [ArrayMesh] with roughly [method vertex_count] * [param ratio]
## vertices. [param ratio] is clamped to 0.02 .. 1.0; 1.0 returns a copy.
static func simplify(mesh: Mesh, ratio := 0.5) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.resource_name = (mesh.resource_name if mesh != null else "mesh") + "_lod"
	if mesh == null:
		return out

	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.is_empty() or GDHPRGeometry.surface_primitive(mesh, surface) != Mesh.PRIMITIVE_TRIANGLES:
			_copy_surface(out, mesh, surface)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		if verts.size() < 8 or verts.size() > MAX_VERTICES or (bones != null and (bones as PackedInt32Array).size() > 0):
			# Skinned or absurdly large: keep it as-is rather than risk a hang.
			_copy_surface(out, mesh, surface)
			continue

		var simplified := _simplify_surface(arrays, clampf(ratio, 0.02, 1.0))
		if simplified.is_empty():
			_copy_surface(out, mesh, surface)
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, simplified)
		out.surface_set_material(out.get_surface_count() - 1, material)
	return out


## Simplifies down to at most [param max_triangles] triangles (approximate).
static func simplify_to_triangles(mesh: Mesh, max_triangles: int) -> ArrayMesh:
	var stats := GDHPRGeometry.mesh_stats(mesh)
	var tris: int = maxi(stats["triangles"], 1)
	if tris <= max_triangles:
		return simplify(mesh, 1.0)
	return simplify(mesh, clampf(float(max_triangles) / float(tris), 0.02, 1.0))


static func _simplify_surface(arrays: Array, ratio: float) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
	var uvs2: Variant = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: Variant = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	var aabb := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		aabb = aabb.expand(v)
	if aabb.size.length_squared() <= 0.0:
		return []

	var target := maxi(8, int(round(verts.size() * ratio)))
	var cell := _solve_cell_size(verts, aabb, target)
	var grid := _build_clusters(verts, aabb, cell, uvs, uvs2, colors, indices)
	if grid.is_empty():
		return []

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = grid["positions"]
	out[Mesh.ARRAY_NORMAL] = grid["normals"]
	out[Mesh.ARRAY_INDEX] = grid["indices"]
	if uvs != null:
		out[Mesh.ARRAY_TEX_UV] = grid["uvs"]
	if uvs2 != null:
		out[Mesh.ARRAY_TEX_UV2] = grid["uvs2"]
	if colors != null:
		out[Mesh.ARRAY_COLOR] = grid["colors"]
	return out


## Binary-searches the grid cell size that produces about [param target] cells.
static func _solve_cell_size(verts: PackedVector3Array, aabb: AABB, target: int) -> float:
	var lo := 0.00001
	var hi := maxf(aabb.size.length(), 0.001)
	for _iteration in 10:
		var mid := (lo + hi) * 0.5
		var cells := {}
		for v in verts:
			cells[_cell_of(v, aabb.position, mid)] = true
		if cells.size() > target:
			lo = mid
		else:
			hi = mid
	return maxf(hi, 0.00001)


## Groups vertices per cell and emits a new triangle list.
static func _build_clusters(
	verts: PackedVector3Array,
	aabb: AABB,
	cell: float,
	uvs: Variant,
	uvs2: Variant,
	colors: Variant,
	indices: PackedInt32Array
) -> Dictionary:
	var cell_to_index := {}
	var sums: Array[Vector3] = []
	var counts: Array[int] = []
	var first_uv: Array[Vector2] = []
	var first_uv2: Array[Vector2] = []
	var first_color: Array[Color] = []
	var vmap := PackedInt32Array()
	vmap.resize(verts.size())

	for i in verts.size():
		var key := _cell_of(verts[i], aabb.position, cell)
		var cluster: int = cell_to_index.get(key, -1)
		if cluster < 0:
			cluster = sums.size()
			cell_to_index[key] = cluster
			sums.append(verts[i])
			counts.append(1)
			if uvs != null:
				first_uv.append((uvs as PackedVector2Array)[i])
			if uvs2 != null:
				first_uv2.append((uvs2 as PackedVector2Array)[i])
			if colors != null:
				first_color.append((colors as PackedColorArray)[i])
		else:
			sums[cluster] = sums[cluster] + verts[i]
			counts[cluster] = counts[cluster] + 1
		vmap[i] = cluster

	var count := sums.size()
	var positions := PackedVector3Array()
	var normals_acc := PackedVector3Array()
	positions.resize(count)
	normals_acc.resize(count)
	for c in count:
		positions[c] = sums[c] / float(counts[c])

	var out_indices := PackedInt32Array()
	var seen := {}
	var index_count := indices.size()
	var sequential := index_count == 0
	if sequential:
		index_count = verts.size() - (verts.size() % 3)

	var a: int
	var b: int
	var c: int
	for t in range(0, index_count - 2, 3):
		if sequential:
			a = vmap[t]
			b = vmap[t + 1]
			c = vmap[t + 2]
		else:
			a = vmap[indices[t]]
			b = vmap[indices[t + 1]]
			c = vmap[indices[t + 2]]
		if a == b or b == c or a == c:
			continue
		var tri_key := _sorted_key(a, b, c)
		if seen.has(tri_key):
			continue
		seen[tri_key] = true
		out_indices.append(a)
		out_indices.append(b)
		out_indices.append(c)
		var face := (positions[b] - positions[a]).cross(positions[c] - positions[a])
		normals_acc[a] = normals_acc[a] + face
		normals_acc[b] = normals_acc[b] + face
		normals_acc[c] = normals_acc[c] + face

	if out_indices.is_empty():
		return {}

	for i in count:
		normals_acc[i] = normals_acc[i].normalized() if normals_acc[i].length_squared() > 0.0 else Vector3.UP

	return {
		"positions": positions,
		"normals": normals_acc,
		"indices": out_indices,
		"uvs": PackedVector2Array(first_uv),
		"uvs2": PackedVector2Array(first_uv2),
		"colors": PackedColorArray(first_color),
	}


static func _cell_of(v: Vector3, origin: Vector3, cell: float) -> Vector3i:
	var local := (v - origin) / cell
	return Vector3i(int(floor(local.x)), int(floor(local.y)), int(floor(local.z)))


static func _sorted_key(a: int, b: int, c: int) -> Vector3i:
	var lo: int = mini(a, mini(b, c))
	var hi: int = maxi(a, maxi(b, c))
	return Vector3i(lo, a + b + c - lo - hi, hi)


static func _copy_surface(out: ArrayMesh, mesh: Mesh, surface: int) -> void:
	var arrays: Array = mesh.surface_get_arrays(surface)
	if arrays.is_empty():
		return
	out.add_surface_from_arrays(GDHPRGeometry.surface_primitive(mesh, surface), arrays)
	out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(surface))


## Rough vertex count after [method simplify] at [param ratio], for UI previews.
static func vertex_count(mesh: Mesh, ratio: float) -> int:
	var stats := GDHPRGeometry.mesh_stats(mesh)
	return int(stats["vertices"] * clampf(ratio, 0.02, 1.0))
