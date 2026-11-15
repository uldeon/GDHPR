@tool
class_name GDHPRBlueprintEditor
extends VBoxContainer
## The visual scripting workspace: a [GraphEdit] plus save / load / compile.
##
## Graphs are saved as [GDHPRBlueprintGraph] resources (.tres) and compiled to
## plain GDScript you can hand over to any node's [code]script[/code] slot.

signal code_generated(path: String)
signal graph_changed

const PREVIEW_MIN_HEIGHT := 120.0

var graph: GDHPRBlueprintGraph = null
var _graph_edit: GraphEdit
var _status: Label
var _preview: TextEdit
var _nodes_by_id: Dictionary = {}
var _add_menu: PopupMenu
var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _ui_built := false


func _ready() -> void:
	_ensure_ui()
	set_graph(GDHPRBlueprintGraph.new())


## Builds the widget tree on demand, so the class is safe to use (and to call
## [method set_graph] on) before it has entered the tree.
func _ensure_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	_build_ui()


func set_graph(new_graph: GDHPRBlueprintGraph) -> void:
	_ensure_ui()
	graph = new_graph if new_graph != null else GDHPRBlueprintGraph.new()
	_rebuild()
	_set_status("Editing '%s' (%d nodes)" % [graph.graph_name, graph.nodes.size()])
	graph_changed.emit()


## Compiles the current graph and returns the GDScript source.
func generate_code() -> String:
	_ensure_ui()
	var result := GDHPRBlueprintCompiler.compile_graph(graph)
	var warnings: PackedStringArray = result["warnings"]
	_preview.text = String(result["code"])
	if not _preview.visible:
		_preview.visible = true
	var line_count: int = String(result["code"]).split("\n").size()
	if warnings.is_empty():
		_set_status("Generated %d lines." % line_count)
	else:
		_set_status("Generated %d lines with %d warning(s)." % [line_count, warnings.size()])
	return String(result["code"])


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	var add_button := MenuButton.new()
	add_button.text = "Add Node"
	add_button.flat = false
	_add_menu = add_button.get_popup()
	_add_menu.id_pressed.connect(_on_add_menu_id)
	_build_add_menu()
	toolbar.add_child(add_button)

	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_on_save)
	toolbar.add_child(save)

	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_on_load)
	toolbar.add_child(load_button)

	var generate := Button.new()
	generate.text = "Generate GDScript"
	generate.pressed.connect(_on_generate)
	toolbar.add_child(generate)

	var preview_toggle := CheckButton.new()
	preview_toggle.text = "Preview"
	preview_toggle.button_pressed = false
	preview_toggle.toggled.connect(func(on: bool) -> void: _preview.visible = on)
	toolbar.add_child(preview_toggle)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	toolbar.add_child(_status)

	_graph_edit = GraphEdit.new()
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.custom_minimum_size.y = 260
	_graph_edit.right_disconnects = true
	_graph_edit.connection_request.connect(_on_connection_request)
	_graph_edit.disconnection_request.connect(_on_disconnection_request)
	_graph_edit.delete_nodes_request.connect(_on_delete_nodes)
	add_child(_graph_edit)

	_preview = TextEdit.new()
	_preview.visible = false
	_preview.editable = false
	_preview.custom_minimum_size.y = PREVIEW_MIN_HEIGHT
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_preview)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.filters = PackedStringArray(["*.tres ; GDHPR Blueprint"])
	_save_dialog.title = "Save blueprint"
	_save_dialog.file_selected.connect(_on_save_path_chosen)
	add_child(_save_dialog)

	_load_dialog = FileDialog.new()
	_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_dialog.access = FileDialog.ACCESS_RESOURCES
	_load_dialog.filters = PackedStringArray(["*.tres ; GDHPR Blueprint"])
	_load_dialog.title = "Load blueprint"
	_load_dialog.file_selected.connect(_on_load_path_chosen)
	add_child(_load_dialog)


func _build_add_menu() -> void:
	_add_menu.clear()
	var next_id := 0
	for category in GDHPRBlueprintDefs.CATEGORIES:
		_add_menu.add_separator(category)
		for type in GDHPRBlueprintDefs.types_in_category(category):
			var definition: Dictionary = GDHPRBlueprintDefs.get_def(type)
			_add_menu.add_item(String(definition["title"]), next_id)
			_add_menu.set_item_metadata(_add_menu.get_item_index(next_id), type)
			next_id += 1


func _rebuild() -> void:
	for child in _graph_edit.get_children():
		if child is GraphNode:
			_graph_edit.remove_child(child)
			child.queue_free()
	_nodes_by_id.clear()
	_graph_edit.clear_connections()
	for data in graph.nodes:
		_add_visual_node(data)
	for link in graph.connections:
		_graph_edit.connect_node(
			str(int(link["from_node"])), int(link["from_port"]),
			str(int(link["to_node"])), int(link["to_port"])
		)


func _add_visual_node(data: Dictionary) -> void:
	var id := int(data["id"])
	var visual := GDHPRBlueprintNode.new()
	visual.name = str(id)
	_graph_edit.add_child(visual)
	visual.setup(id, String(data["type"]), graph)
	visual.edited.connect(func() -> void: graph_changed.emit())
	_nodes_by_id[id] = visual


func _on_add_menu_id(id: int) -> void:
	var index := _add_menu.get_item_index(id)
	var type := String(_add_menu.get_item_metadata(index))
	var center := _graph_edit.scroll_offset + _graph_edit.size * 0.5
	var node_id := graph.add_node(type, center)
	_add_visual_node(graph.node_data(node_id))
	_set_status("Added %s" % GDHPRBlueprintDefs.get_def(type)["title"])
	graph_changed.emit()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_id := int(from_node)
	var to_id := int(to_node)
	var from_data := graph.node_data(from_id)
	var to_data := graph.node_data(to_id)
	if from_data.is_empty() or to_data.is_empty():
		return
	var from_kind := GDHPRBlueprintDefs.port_kind(String(from_data["type"]), true, from_port)
	var to_kind := GDHPRBlueprintDefs.port_kind(String(to_data["type"]), false, to_port)
	if from_kind.is_empty() or to_kind.is_empty() or from_kind != to_kind:
		_set_status("Cannot connect %s to %s." % [from_kind, to_kind])
		return
	graph.connect_ports(from_id, from_port, to_id, to_port)
	_graph_edit.connect_node(from_node, from_port, to_node, to_port)
	graph_changed.emit()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph.disconnect_ports(int(from_node), from_port, int(to_node), to_port)
	_graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	graph_changed.emit()


func _on_delete_nodes(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var id := int(node_name)
		graph.remove_node(id)
		var visual: GDHPRBlueprintNode = _nodes_by_id.get(id)
		if visual != null:
			_graph_edit.remove_child(visual)
			visual.queue_free()
		_nodes_by_id.erase(id)
	graph_changed.emit()


func _on_save() -> void:
	_save_dialog.current_file = graph.graph_name.to_snake_case() + ".tres"
	_save_dialog.popup_centered_ratio(0.5)


func _on_save_path_chosen(path: String) -> void:
	var error := ResourceSaver.save(graph, path)
	if error == OK:
		_set_status("Saved to %s" % path)
	else:
		_set_status("Save failed: %s" % error_string(error))


func _on_load() -> void:
	_load_dialog.popup_centered_ratio(0.5)


func _on_load_path_chosen(path: String) -> void:
	var loaded := ResourceLoader.load(path)
	if loaded is GDHPRBlueprintGraph:
		set_graph(loaded as GDHPRBlueprintGraph)
		_set_status("Loaded %s" % path)
	else:
		_set_status("Not a GDHPR blueprint: %s" % path)


## Compiles the graph and writes it to [param path] (a .gd path).
func save_generated_code(path: String) -> Error:
	var code := generate_code()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Could not write %s" % path)
		return FileAccess.get_open_error()
	file.store_string(code)
	file.close()
	code_generated.emit(path)
	_set_status("Wrote %s" % path)
	return OK


func _on_generate() -> void:
	generate_code()
	_set_status("Code ready — press 'Save as .gd' to write it to disk.")


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
