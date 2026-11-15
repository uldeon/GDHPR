@tool
class_name GDHPRBlueprintNode
extends GraphNode
## One visual-scripting node inside the blueprint editor.
##
## Builds its rows (parameters, input ports, output ports) from
## [GDHPRBlueprintDefs] so adding a node type needs no UI work.

signal edited

var node_id: int = -1
var type: String = "print"
var graph: GDHPRBlueprintGraph = null
## Called before a parameter is changed, so the editor can snapshot for undo.
var edit_hook: Callable = Callable()

var _building := false


## Builds the node UI from the graph data.
func setup(id: int, node_type: String, target_graph: GDHPRBlueprintGraph) -> void:
	_building = true
	node_id = id
	type = node_type
	graph = target_graph
	var definition := GDHPRBlueprintDefs.get_def(type)

	title = definition["title"]
	tooltip_text = String(definition.get("desc", ""))
	resizable = false
	add_theme_color_override("title_color", _category_color(String(definition["category"])))

	var data := graph.node_data(node_id)
	var props: Dictionary = data.get("props", {})

	for param in definition.get("params", []):
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(param["name"]).capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(_make_editor(param, props.get(param["name"], param.get("default"))))
		add_child(row)

	for i in definition["inputs"].size():
		var input: Dictionary = definition["inputs"][i]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(input["name"])
		label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
		row.add_child(label)
		add_child(row)
		set_slot(
			get_child_count() - 1,
			true, 0, GDHPRBlueprintDefs.port_color(type, false, i),
			false, 0, Color.WHITE
		)

	for i in definition["outputs"].size():
		var output: Dictionary = definition["outputs"][i]
		var row := HBoxContainer.new()
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var label := Label.new()
		label.text = String(output["name"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(label)
		add_child(row)
		set_slot(
			get_child_count() - 1,
			false, 0, Color.WHITE,
			true, 0, GDHPRBlueprintDefs.port_color(type, true, i)
		)

	position_offset = data.get("pos", Vector2.ZERO)
	reset_size()
	_building = false

	position_offset_changed.connect(_on_moved)


func _on_moved() -> void:
	if _building or graph == null:
		return
	graph.set_pos(node_id, position_offset)


func _make_editor(param: Dictionary, current: Variant) -> Control:
	match String(param.get("type", "String")):
		"float":
			var spin := SpinBox.new()
			spin.min_value = -1_000_000.0
			spin.max_value = 1_000_000.0
			spin.step = 0.01
			spin.value = float(current)
			spin.custom_minimum_size.x = 96
			spin.value_changed.connect(func(value: float) -> void:
				_set_prop(String(param["name"]), value)
			)
			return spin
		"int":
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = int(param.get("max", 64))
			spin.step = 1
			spin.value = int(current)
			spin.custom_minimum_size.x = 96
			spin.value_changed.connect(func(value: float) -> void:
				_set_prop(String(param["name"]), int(value))
			)
			return spin
		"bool":
			var check := CheckBox.new()
			check.button_pressed = bool(current)
			check.toggled.connect(func(pressed: bool) -> void:
				_set_prop(String(param["name"]), pressed)
			)
			return check
		"enum":
			var option := OptionButton.new()
			var options: Array = param.get("options", [])
			for i in options.size():
				option.add_item(String(options[i]), i)
			var index := options.find(current)
			option.select(index if index >= 0 else 0)
			option.item_selected.connect(func(selected: int) -> void:
				_set_prop(String(param["name"]), String(options[selected]))
			)
			return option
		"Vector3":
			var box := HBoxContainer.new()
			var values := Vector3.ZERO
			if current is Vector3:
				values = current
			for axis in 3:
				var spin := SpinBox.new()
				spin.min_value = -1_000_000.0
				spin.max_value = 1_000_000.0
				spin.step = 0.1
				spin.value = values[axis]
				spin.custom_minimum_size.x = 70
				spin.value_changed.connect(func(value: float) -> void:
					var data := graph.node_data(node_id)
					var vector: Vector3 = data.get("props", {}).get(String(param["name"]), Vector3.ZERO)
					vector[axis] = value
					_set_prop(String(param["name"]), vector)
				)
				box.add_child(spin)
			return box
		_:
			var edit := LineEdit.new()
			edit.text = String(current)
			edit.custom_minimum_size.x = 120
			edit.text_changed.connect(func(text: String) -> void:
				_set_prop(String(param["name"]), text)
			)
			return edit


func _set_prop(key: String, value: Variant) -> void:
	if _building or graph == null:
		return
	if edit_hook.is_valid():
		edit_hook.call()
	graph.set_prop(node_id, key, value)
	edited.emit()


func _category_color(category: String) -> Color:
	match category:
		"Event":
			return Color(0.98, 0.62, 0.36)
		"Value":
			return Color(0.42, 0.86, 0.78)
	return Color(0.82, 0.86, 0.94)
