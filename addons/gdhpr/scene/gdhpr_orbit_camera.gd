@tool
class_name GDHPROrbitCamera
extends Camera3D
## Small orbit camera for look-dev. Middle/right-drag to orbit, wheel to zoom,
## shift-drag to pan. Not a gameplay camera — GDHPR creates one only when a
## scene has no camera of its own.

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 9.0
@export var yaw: float = 35.0
@export var pitch: float = -22.0
@export var min_distance: float = 0.5
@export var max_distance: float = 400.0
@export var orbit_sensitivity: float = 0.25
@export var zoom_step: float = 1.12
## Degrees per second of idle spin; 0 disables it.
@export var auto_rotate_speed: float = 0.0


func _ready() -> void:
	fov = 60.0
	near = 0.05
	far = 4000.0
	current = not Engine.is_editor_hint()
	set_process(auto_rotate_speed != 0.0)
	_update_transform()


func _process(delta: float) -> void:
	if auto_rotate_speed != 0.0:
		yaw += auto_rotate_speed * delta
		_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton)
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance / zoom_step, min_distance, max_distance)
			_update_transform()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * zoom_step, min_distance, max_distance)
			_update_transform()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
			if motion.shift_pressed:
				var pan := Vector3(-motion.relative.x, motion.relative.y, 0.0) * distance * 0.0015
				target += global_transform.basis * pan
			else:
				yaw -= motion.relative.x * orbit_sensitivity
				pitch = clampf(pitch - motion.relative.y * orbit_sensitivity, -89.0, 89.0)
			_update_transform()


## Frames an AABB so it fills the view.
func frame(bounds: AABB, margin := 1.6) -> void:
	target = bounds.get_center()
	distance = clampf(bounds.size.length() * margin, min_distance, max_distance)
	_update_transform()


func _update_transform() -> void:
	var rotation_rad := Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)
	var offset := Basis.from_euler(rotation_rad) * Vector3(0.0, 0.0, distance)
	global_transform = Transform3D(Basis.IDENTITY, target + offset).looking_at(target, Vector3.UP)
