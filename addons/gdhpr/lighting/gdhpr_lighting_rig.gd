@tool
class_name GDHPRLightingRig
extends RefCounted
## One-call, art-directed lighting rigs.
##
## Instead of hand-placing a sun, a fill and a rim every time, ask for a mood.
## Every rig is a plain [Node3D] with ordinary light nodes inside, named
## "Key"/"Fill"/"Rim"/"Accent" so you can keep tweaking by hand afterwards.

## Ordered names matching [member GDHPRConfig.lighting_rig].
const MOOD_NAMES: PackedStringArray = [
	"None", "Studio", "Outdoor Day", "Golden Hour", "Indoor Warm", "Night", "Neon", "Product",
]

const RIG_ROOT_NAME := "GDHPR_Lighting"


## Builds a rig for [param mood] (see [constant MOOD_NAMES]) under
## [param parent] and returns the rig root, or [code]null[/code] for mood 0.
static func build(mood: int, parent: Node3D = null, owner_node: Node = null, undo_redo: Variant = null) -> Node3D:
	if mood <= 0:
		return null

	var root := Node3D.new()
	root.name = RIG_ROOT_NAME
	root.set_meta("gdhpr_rig", mood)

	match mood:
		1: # Studio: neutral key + cool fill + warm rim
			_add_directional(root, "Key", Color(1.0, 0.97, 0.92), 1.25, Vector3(-42, 35, 0), true, 2.0, 0.02)
			_add_omni(root, "Fill", Color(0.62, 0.74, 1.0), 0.55, Vector3(4.0, 3.0, 4.0), 14.0)
			_add_directional(root, "Rim", Color(1.0, 0.86, 0.7), 0.7, Vector3(-28, -140, 0), false, 0.0, 0.01)
		2: # Outdoor Day: strong sun + sky bounce
			_add_directional(root, "Sun", Color(1.0, 0.96, 0.88), 1.6, Vector3(-52, 32, 0), true, 0.8, 0.03)
			_add_directional(root, "Bounce", Color(0.55, 0.66, 0.85), 0.22, Vector3(58, -20, 0), false, 0.0, 0.0)
		3: # Golden Hour: low warm sun, long shadows, cool sky fill
			_add_directional(root, "Sun", Color(1.0, 0.72, 0.44), 1.55, Vector3(-16, 68, 0), true, 0.6, 0.04)
			_add_directional(root, "SkyFill", Color(0.4, 0.55, 0.85), 0.3, Vector3(60, -50, 0), false, 0.0, 0.0)
		4: # Indoor Warm: practical ceiling lights, soft direction
			_add_omni(root, "Ceiling_A", Color(1.0, 0.78, 0.55), 2.4, Vector3(-3.0, 3.2, -2.0), 9.0)
			_add_omni(root, "Ceiling_B", Color(1.0, 0.8, 0.58), 2.4, Vector3(3.0, 3.2, 2.0), 9.0)
			_add_directional(root, "Window", Color(0.72, 0.84, 1.0), 0.45, Vector3(-35, 120, 0), true, 2.5, 0.02)
		5: # Night: moon + practicals
			_add_directional(root, "Moon", Color(0.55, 0.66, 1.0), 0.4, Vector3(-38, -60, 0), true, 0.4, 0.05)
			_add_omni(root, "Practical_A", Color(1.0, 0.72, 0.42), 1.8, Vector3(-4.0, 2.4, 1.0), 8.0)
			_add_omni(root, "Practical_B", Color(0.55, 0.75, 1.0), 1.2, Vector3(5.0, 2.0, -3.0), 10.0)
		6: # Neon: colour contrast, no shadow cost
			_add_omni(root, "Magenta", Color(1.0, 0.15, 0.75), 4.0, Vector3(-5.0, 2.2, 2.0), 18.0)
			_add_omni(root, "Cyan", Color(0.1, 0.85, 1.0), 4.0, Vector3(5.0, 2.6, -2.0), 18.0)
			_add_directional(root, "Haze", Color(0.35, 0.25, 0.6), 0.25, Vector3(-20, 30, 0), false, 0.0, 0.0)
		7: # Product: clean softbox key, gradient fill, edge light
			_add_directional(root, "Key", Color(1.0, 0.99, 0.97), 1.05, Vector3(-40, 30, 0), true, 4.0, 0.03)
			_add_directional(root, "Fill", Color(0.9, 0.94, 1.0), 0.5, Vector3(-10, -50, 0), false, 6.0, 0.0)
			_add_directional(root, "Rim", Color(1.0, 1.0, 1.0), 0.9, Vector3(-25, -160, 0), false, 0.0, 0.01)

	if parent != null:
		if undo_redo != null:
			undo_redo.add_do_method(parent, "add_child", root)
			if owner_node != null:
				undo_redo.add_do_method(root, "set_owner", owner_node)
			undo_redo.add_do_reference(root)
			undo_redo.add_undo_method(parent, "remove_child", root)
			undo_redo.add_undo_reference(root)
		else:
			parent.add_child(root)
			if owner_node != null:
				root.owner = owner_node
	return root


## Adds the rig to [param parent] only if no GDHPR rig is already there.
static func ensure(mood: int, parent: Node3D) -> Node3D:
	if parent == null or mood <= 0:
		return null
	var existing := parent.get_node_or_null(RIG_ROOT_NAME) as Node3D
	if existing != null:
		return existing
	return build(mood, parent)


static func _add_directional(
	parent: Node3D,
	name: String,
	color: Color,
	energy: float,
	rotation_degrees_xyz: Vector3,
	shadows: bool,
	angular_distance: float,
	volumetric_energy: float
) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = name
	light.light_color = color
	light.light_energy = energy
	light.rotation_degrees = rotation_degrees_xyz
	light.shadow_enabled = shadows
	light.light_angular_distance = angular_distance
	light.light_volumetric_fog_energy = volumetric_energy
	light.shadow_bias = 0.02
	light.shadow_normal_bias = 1.0
	light.directional_shadow_max_distance = 140.0
	parent.add_child(light)
	return light


static func _add_omni(
	parent: Node3D,
	name: String,
	color: Color,
	energy: float,
	position: Vector3,
	range_metres: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = name
	light.light_color = color
	light.light_energy = energy
	light.position = position
	light.omni_range = range_metres
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.05
	parent.add_child(light)
	return light
