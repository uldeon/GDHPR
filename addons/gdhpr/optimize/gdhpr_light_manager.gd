@tool
class_name GDHPRLightManager
extends Node
## Runtime light budget.
##
## Many-light scenes usually spend most of their fragment/vertex budget on
## shadow maps for lights nobody is looking at. This node keeps the N most
## important lights casting shadows and fades out distant lights smoothly.
## Non-destructive: original shadow flags are restored when a light leaves the
## budget or the manager exits the tree.

@export_range(0, 32, 1) var shadow_budget: int = 6
@export var max_distance: float = 150.0
@export_range(0.05, 2.0, 0.01) var update_interval: float = 0.3
@export var fade_lights: bool = true
@export var budget_shadows: bool = true

var _camera: Camera3D = null
var _timer: float = 0.0
var _forced_off: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = update_interval
	refresh()


## Recomputes the budget immediately.
func refresh() -> void:
	var cam := _camera
	if cam == null or not is_instance_valid(cam):
		cam = get_viewport().get_camera_3d() if is_inside_tree() else null
		_camera = cam
	if cam == null:
		return
	var origin := cam.global_position
	var lights := _collect_lights(get_parent() if get_parent() != null else self)

	for light in lights:
		if fade_lights:
			light.distance_fade_enabled = true
			light.distance_fade_begin = maxf(max_distance * 0.8, 1.0)
			light.distance_fade_length = maxf(max_distance * 0.5, 1.0)

	if not budget_shadows:
		return

	var ranked: Array[Light3D] = []
	for light in lights:
		if light is DirectionalLight3D:
			continue # the sun is never budgeted away
		ranked.append(light)
	ranked.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return _score(a, origin) > _score(b, origin)
	)

	for i in ranked.size():
		var light := ranked[i]
		var id := light.get_instance_id()
		if i < shadow_budget:
			if _forced_off.has(id):
				light.shadow_enabled = _forced_off[id]
				_forced_off.erase(id)
		elif light.shadow_enabled:
			_forced_off[id] = true
			light.shadow_enabled = false


func _exit_tree() -> void:
	for node in _collect_lights(get_parent() if get_parent() != null else self):
		var id := node.get_instance_id()
		if _forced_off.has(id):
			node.shadow_enabled = _forced_off[id]
	_forced_off.clear()


static func _score(light: Light3D, origin: Vector3) -> float:
	var distance := light.global_position.distance_to(origin)
	return light.light_energy * (1.0 + light.light_size) / pow(maxf(distance, 1.0), 1.5)


static func _collect_lights(root: Node) -> Array[Light3D]:
	var out: Array[Light3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Light3D:
			out.append(node as Light3D)
		for child in node.get_children():
			stack.append(child)
	return out
