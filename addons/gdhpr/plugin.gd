@tool
extends EditorPlugin
## GDHPR editor entry point: registers the GDHPR dock and a Tools menu shortcut.

const DockScript := preload("res://addons/gdhpr/editor/gdhpr_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "GDHPR"
	_dock.editor_plugin = self
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)
	add_tool_menu_item("GDHPR: Quick Setup", _on_quick_setup)
	add_tool_menu_item("GDHPR: Optimize Scene", _on_quick_optimize)


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	remove_tool_menu_item("GDHPR: Quick Setup")
	remove_tool_menu_item("GDHPR: Optimize Scene")


func _on_quick_setup() -> void:
	if _dock != null:
		_dock.quick_setup()


func _on_quick_optimize() -> void:
	if _dock != null:
		_dock.optimize_scene()
