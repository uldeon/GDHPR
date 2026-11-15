extends Node3D
## GDHPR demo: builds a small scene, then configures and optimizes it with
## GDHPR in a handful of calls. Run this scene, then open the GDHPR dock.

const CRATE_COUNT := 6


func _ready() -> void:
	_build_ground()
	_build_crates()
	_build_hero_objects()

	# 1) Rendering: quality preset + look, one call.
	var cfg := GDHPRPresets.from_quality(GDHPRConfig.Quality.HIGH)
	cfg.lighting_rig = 2 # Outdoor Day
	GDHPR.apply(cfg, self)

	# 2) Lighting: a full rig in one call.
	GDHPRLightingRig.ensure(cfg.lighting_rig, self)

	# 3) Optimization: batching + auto LOD in one call.
	var report := GDHPR.optimize(self, cfg)
	print(GDHPROptimizer.format_report(report))

	# 4) A camera, because demo scenes rarely ship with one.
	var camera := GDHPROrbitCamera.new()
	camera.name = "Camera"
	camera.distance = 22.0
	camera.pitch = -24.0
	camera.auto_rotate_speed = 5.0
	add_child(camera)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	ground.mesh = plane
	var material := GDHPRMaterialLibrary.preset("concrete")
	GDHPRMaterialLibrary.make_triplanar(material, 0.25)
	ground.material_override = material
	add_child(ground)


func _build_crates() -> void:
	var group := Node3D.new()
	group.name = "Crates"
	add_child(group)
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(1.2, 1.2, 1.2)
	var crate_material := GDHPRMaterialLibrary.preset("wood")
	for x in CRATE_COUNT:
		for z in CRATE_COUNT:
			var crate := MeshInstance3D.new()
			crate.name = "Crate_%d_%d" % [x, z]
			crate.mesh = crate_mesh
			crate.material_override = crate_material
			crate.position = Vector3(x * 1.35 - 3.4, 0.6, z * 1.35 - 3.4)
			crate.rotation.y = randf_range(-0.2, 0.2)
			group.add_child(crate)


func _build_hero_objects() -> void:
	var sphere := MeshInstance3D.new()
	sphere.name = "Hero_Sphere"
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.6
	sphere_mesh.height = 3.2
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32
	sphere.mesh = sphere_mesh
	sphere.material_override = GDHPRMaterialLibrary.preset("car_paint")
	sphere.position = Vector3(0, 1.6, 4.0)
	add_child(sphere)

	var torus := MeshInstance3D.new()
	torus.name = "Hero_Torus"
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 1.2
	torus_mesh.outer_radius = 2.4
	torus_mesh.rings = 96
	torus_mesh.ring_segments = 64
	torus.mesh = torus_mesh
	torus.material_override = GDHPRMaterialLibrary.preset("gold")
	torus.position = Vector3(4.5, 2.4, 0.0)
	torus.rotation_degrees = Vector3(20, 0, 70)
	add_child(torus)

	var pedestal := MeshInstance3D.new()
	pedestal.name = "Pedestal"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.1
	cylinder.height = 0.8
	pedestal.mesh = cylinder
	pedestal.material_override = GDHPRMaterialLibrary.preset("marble")
	pedestal.position = Vector3(4.5, 0.4, 0.0)
	add_child(pedestal)
