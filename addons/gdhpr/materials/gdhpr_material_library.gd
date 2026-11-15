@tool
class_name GDHPRMaterialLibrary
extends RefCounted
## A library of good-looking PBR materials with zero asset dependencies.
##
## Every material is a [StandardMaterial3D] filled in with sensible metallic /
## roughness / clearcoat values plus a procedurally generated normal-detail map,
## so a grey-blocked scene looks like a real one before any texturing work.

## Ordered list of built-in presets.
const MATERIAL_NAMES: PackedStringArray = [
	"metal",
	"brushed_metal",
	"gold",
	"concrete",
	"asphalt",
	"marble",
	"wood",
	"fabric",
	"glass",
	"plastic",
	"rubber",
	"ceramic",
	"emissive",
	"car_paint",
	"snow",
	"water",
	"foliage",
	"clay",
]


## Builds a preset by name. Unknown names return the "plastic" default.
## Set [param detail] to false for the cheapest possible material.
static func preset(preset_name: String, detail := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "GDHPR_" + preset_name

	match preset_name.to_lower():
		"metal":
			_pbr(mat, Color(0.56, 0.57, 0.58), 1.0, 0.28)
			if detail:
				_detail(mat, 0.05, 0.15)
		"brushed_metal":
			_pbr(mat, Color(0.66, 0.67, 0.69), 1.0, 0.22)
			if detail:
				_anisotropic_detail(mat, 0.12)
		"gold":
			_pbr(mat, Color(1.0, 0.77, 0.34), 1.0, 0.18)
			if detail:
				_detail(mat, 0.06, 0.08)
		"concrete":
			_pbr(mat, Color(0.58, 0.57, 0.55), 0.0, 0.82)
			if detail:
				_detail(mat, 0.35, 0.55)
		"asphalt":
			_pbr(mat, Color(0.16, 0.16, 0.17), 0.0, 0.92)
			if detail:
				_detail(mat, 0.7, 0.7)
		"marble":
			_pbr(mat, Color(0.91, 0.90, 0.88), 0.05, 0.16)
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.6
			mat.clearcoat_roughness = 0.08
			if detail:
				_detail(mat, 0.12, 0.35)
		"wood":
			_pbr(mat, Color(0.42, 0.27, 0.15), 0.0, 0.55)
			if detail:
				_detail(mat, 0.55, 0.35)
		"fabric":
			_pbr(mat, Color(0.34, 0.36, 0.42), 0.0, 0.95)
			mat.rim_enabled = true
			mat.rim = 0.35
			if detail:
				_detail(mat, 3.0, 0.5)
		"glass":
			_pbr(mat, Color(0.78, 0.86, 0.9), 0.25, 0.04)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.22
			mat.refraction_enabled = true
			mat.refraction_scale = 0.08
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mat.metallic_specular = 0.85
		"plastic":
			_pbr(mat, Color(0.8, 0.8, 0.82), 0.0, 0.32)
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.45
			mat.clearcoat_roughness = 0.2
		"rubber":
			_pbr(mat, Color(0.09, 0.09, 0.1), 0.0, 0.9)
			if detail:
				_detail(mat, 1.2, 0.4)
		"ceramic":
			_pbr(mat, Color(0.94, 0.93, 0.9), 0.0, 0.2)
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.9
			mat.clearcoat_roughness = 0.04
			mat.rim_enabled = true
			mat.rim = 0.25
		"emissive":
			_pbr(mat, Color(0.1, 0.1, 0.1), 0.0, 0.5)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.85, 0.6)
			mat.emission_energy_multiplier = 3.0
		"car_paint":
			_pbr(mat, Color(0.55, 0.04, 0.06), 0.65, 0.3)
			mat.clearcoat_enabled = true
			mat.clearcoat = 1.0
			mat.clearcoat_roughness = 0.03
			mat.rim_enabled = true
			mat.rim = 0.4
		"snow":
			_pbr(mat, Color(0.93, 0.95, 0.98), 0.0, 0.6)
			mat.subsurf_scatter_enabled = true
			mat.subsurf_scatter_strength = 0.1
			if detail:
				_detail(mat, 0.8, 0.25)
		"water":
			_pbr(mat, Color(0.05, 0.18, 0.24), 0.1, 0.06)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.62
			mat.rim_enabled = true
			mat.rim = 0.5
			mat.rim_tint = 0.9
			if detail:
				_detail(mat, 0.25, 0.8)
		"foliage":
			_pbr(mat, Color(0.22, 0.42, 0.16), 0.0, 0.7)
			mat.backlight_enabled = true
			mat.backlight = Color(0.4, 0.7, 0.25)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.rim_enabled = true
			mat.rim = 0.4
		"clay":
			_pbr(mat, Color(0.62, 0.42, 0.34), 0.0, 0.75)
			if detail:
				_detail(mat, 0.4, 0.3)
		_:
			_pbr(mat, Color(0.8, 0.8, 0.82), 0.0, 0.32)
	return mat


## Builds a custom material from a dictionary, e.g.
## [code]{ "albedo": Color.RED, "metallic": 0.2, "roughness": 0.4, "detail": 0.3 }[/code]
static func pbr_from(options: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	_pbr(
		mat,
		options.get("albedo", Color(0.8, 0.8, 0.8)),
		float(options.get("metallic", 0.0)),
		float(options.get("roughness", 0.5))
	)
	if options.has("emission"):
		mat.emission_enabled = true
		mat.emission = options["emission"]
		mat.emission_energy_multiplier = float(options.get("emission_energy", 1.0))
	if options.has("alpha"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = float(options["alpha"])
	if options.get("detail", 0.0) > 0.0:
		_detail(mat, float(options.get("detail_frequency", 0.3)), float(options["detail"]))
	if options.get("triplanar", false):
		make_triplanar(mat, float(options.get("triplanar_scale", 1.0)))
	return mat


## Turns any material into a world-space triplanar one. Great for blockout and
## level geometry that has no usable UVs; costs a little vertex work.
static func make_triplanar(mat: StandardMaterial3D, scale := 1.0) -> StandardMaterial3D:
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale
	mat.uv1_triplanar_sharpness = 2.0
	return mat


## Adds a procedural normal-detail map. [param frequency] controls feature size
## (smaller = larger features), [param strength] how bumpy it is (0..1).
static func add_detail(mat: StandardMaterial3D, frequency := 0.3, strength := 0.4) -> StandardMaterial3D:
	_detail(mat, frequency, strength)
	return mat


## Sets a preset as [member GeometryInstance3D.material_override] on every mesh
## under [param root]. Purely for quick look-dev on grey boxes.
static func override_meshes(root: Node, preset_name: String) -> int:
	var mat := preset(preset_name)
	var count := 0
	for node in _walk(root):
		var mi := node as MeshInstance3D
		if mi == null or not mi.visible:
			continue
		mi.material_override = mat
		count += 1
	return count


static func _pbr(mat: StandardMaterial3D, albedo: Color, metallic: float, roughness: float) -> void:
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = roughness
	mat.metallic_specular = 0.55
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


static func _detail(mat: StandardMaterial3D, frequency: float, strength: float) -> void:
	mat.normal_enabled = true
	mat.normal_texture = _noise_normal(frequency, strength)
	mat.normal_scale = 1.0


static func _anisotropic_detail(mat: StandardMaterial3D, strength: float) -> void:
	_detail(mat, 0.08, strength)
	mat.anisotropy_enabled = true
	mat.anisotropy = 0.7


static func _noise_normal(frequency: float, strength: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.seed = 1337

	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = clampf(strength * 12.0, 0.5, 16.0)
	texture.generate_mipmaps = true
	return texture


static func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
