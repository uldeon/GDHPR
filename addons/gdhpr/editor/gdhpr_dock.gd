@tool
extends VBoxContainer
## The GDHPR dock: presets, optimization, lighting, materials and the
## blueprint (visual scripting) workspace in one panel.
##
## Set [member editor_plugin] before adding it to the editor. Every scene change
## goes through the editor's undo stack, so nothing is destructive.

var editor_plugin: EditorPlugin = null

const ARCHETYPES: PackedStringArray = ["None", "Outdoor", "Indoor", "Night", "Neon", "Product"]
const ARCHETYPE_KEYS: PackedStringArray = ["none", "outdoor", "indoor", "night", "neon", "product"]

var _quality: OptionButton
var _target: OptionButton
var _archetype: OptionButton
var _project_settings: CheckBox
var _rig_mood: OptionButton
var _batch: CheckBox
var _lods: CheckBox
var _light_budget: CheckBox
var _batch_min: SpinBox
var _lod_triangles: SpinBox
var _view_distance: SpinBox
var _output: RichTextLabel
var _status: Label
var _materials: ItemList
var _blueprint: GDHPRBlueprintEditor
var _code_dialog: FileDialog


func _ready() -> void:
	custom_minimum_size = Vector2(320, 480)
	add_theme_constant_override("separation", 6)
	_build_presets_tab()
	_build_optimize_tab()
	_build_lighting_tab()
	_build_materials_tab()
	_build_blueprint_tab()
	_build_report_panel()

	_code_dialog = FileDialog.new()
	_code_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_code_dialog.access = FileDialog.ACCESS_RESOURCES
	_code_dialog.filters = PackedStringArray(["*.gd ; GDScript"])
	_code_dialog.title = "Save generated GDScript"
	_code_dialog.file_selected.connect(_on_code_path_chosen)
	add_child(_code_dialog)


# --- UI construction ---------------------------------------------------------

func _build_presets_tab() -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	var presets := _tab(tabs, "Presets")

	_quality = _option(presets, "Quality", GDHPRPresets.QUALITY_NAMES.slice(0, 4))
	_target = _option(presets, "Target", GDHPRPresets.TARGET_NAMES)
	_archetype = _option(presets, "Scene look", ARCHETYPES)
	_project_settings = _check(presets, "Write recommended project settings", false)

	_hint(presets, "Project settings (debanding, occlusion culling, shadow filter quality) apply after an editor restart.")
	_row_buttons(presets, [
		["Apply Rendering", apply_rendering],
		["Quick Setup", quick_setup],
	])
	_row_buttons(presets, [
		["Add GDHPRWorld Node", add_world_node],
		["Analyze Scene", analyze_scene],
	])


## Report panel lives below the tabs so results stay visible from any tab.
func _build_report_panel() -> void:
	_output = RichTextLabel.new()
	_output.bbcode_enabled = false
	_output.scroll_active = true
	_output.custom_minimum_size.y = 120
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_output)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.65, 0.78, 0.68))
	add_child(_status)


func _build_optimize_tab() -> void:
	var optimize := _tab(_tabs_node(), "Optimize")
	_batch = _check(optimize, "Batch identical meshes (MultiMesh)", true)
	_lods = _check(optimize, "Generate automatic LODs", true)
	_light_budget = _check(optimize, "Add runtime light budget", false)
	_batch_min = _spin(optimize, "Batch at least N copies", 3, 2, 64, 1)
	_lod_triangles = _spin(optimize, "LOD threshold (triangles)", 3000, 100, 200000, 100)
	_view_distance = _spin(optimize, "View distance (m)", 150, 10, 1000, 5)
	_hint(optimize, "Undoable. Batching removes the original instances and keeps their world transforms.")
	_row_buttons(optimize, [
		["Analyze", analyze_scene],
		["Optimize Scene", optimize_scene],
	])


func _build_lighting_tab() -> void:
	var lighting := _tab(_tabs_node(), "Lighting")
	_rig_mood = _option(lighting, "Rig", GDHPRPresets.RIG_NAMES.slice(1))
	_row_buttons(lighting, [
		["Add Lighting Rig", add_lighting_rig],
		["Apply Sky Only", apply_sky],
	])
	_hint(lighting, "Rigs are plain Node3Ds with Key/Fill/Rim/Accessory lights you can keep editing.")


func _build_materials_tab() -> void:
	var materials := _tab(_tabs_node(), "Materials")
	_materials = ItemList.new()
	_materials.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_materials.custom_minimum_size.y = 160
	for name in GDHPRMaterialLibrary.MATERIAL_NAMES:
		_materials.add_item(name.capitalize())
	materials.add_child(_materials)
	_row_buttons(materials, [
		["Assign to Selection", assign_to_selection],
		["Assign to Scene", assign_to_scene],
	])
	_hint(materials, "Materials use procedural normal detail, so they need no textures.")


func _build_blueprint_tab() -> void:
	var tabs := _tabs_node()
	var blueprint := _tab(tabs, "Blueprint")
	_blueprint = GDHPRBlueprintEditor.new()
	_blueprint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_blueprint.custom_minimum_size.y = 360
	blueprint.add_child(_blueprint)
	var row := HBoxContainer.new()
	var save_code := Button.new()
	save_code.text = "Save as .gd"
	save_code.pressed.connect(_on_save_code)
	row.add_child(save_code)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	blueprint.add_child(row)
	_hint(blueprint, "Graphs compile to plain GDScript with no GDHPR dependency.")


func _tabs_node() -> TabContainer:
	for child in get_children():
		if child is TabContainer:
			return child as TabContainer
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	return tabs


func _tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.name = tab_name
	panel.add_theme_constant_override("separation", 6)
	tabs.add_child(panel)
	return panel


func _option(parent: Control, label_text: String, items: PackedStringArray) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var option := OptionButton.new()
	for item in items:
		option.add_item(item)
	row.add_child(option)
	parent.add_child(row)
	return option


func _check(parent: Control, text: String, value: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = value
	parent.add_child(box)
	return box


func _spin(parent: Control, label_text: String, value: float, min_value: float, max_value: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 90
	row.add_child(spin)
	parent.add_child(row)
	return spin


func _hint(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.6, 0.64, 0.7))
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)


func _row_buttons(parent: Control, entries: Array) -> void:
	var row := HBoxContainer.new()
	for entry in entries:
		var button := Button.new()
		button.text = String(entry[0])
		button.pressed.connect(entry[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	parent.add_child(row)


# --- Actions ----------------------------------------------------------------

func _current_scene() -> Node:
	return EditorInterface.get_edited_scene_root()


func _config() -> GDHPRConfig:
	var cfg := GDHPRPresets.from_quality(_quality.selected if _quality else GDHPRConfig.Quality.HIGH)
	cfg.target = (_target.selected if _target else 1) as GDHPRConfig.Target
	if _archetype != null and _archetype.selected > 0:
		var archetype := ARCHETYPE_KEYS[_archetype.selected]
		cfg = GDHPRPresets.from_archetype(archetype, _quality.selected)
		if _rig_mood != null:
			cfg.lighting_rig = _rig_mood.selected + 1
	if _rig_mood != null and _rig_mood.selected > 0 and cfg.lighting_rig == 0:
		cfg.lighting_rig = _rig_mood.selected + 1
	if _project_settings != null:
		cfg.apply_project_settings = _project_settings.button_pressed
	if _batch != null:
		cfg.batch_meshes = _batch.button_pressed
	if _lods != null:
		cfg.generate_lods = _lods.button_pressed
	if _light_budget != null:
		cfg.budget_lights_at_runtime = _light_budget.button_pressed
	if _batch_min != null:
		cfg.batch_min_instances = int(_batch_min.value)
	if _lod_triangles != null:
		cfg.lod_min_triangles = int(_lod_triangles.value)
	if _view_distance != null:
		cfg.view_distance = _view_distance.value
	return cfg


func apply_rendering() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a 3D scene first.")
		return
	var cfg := _config()
	var undo = editor_plugin.get_undo_redo()
	undo.create_action("GDHPR: Apply Rendering")
	var report := GDHPR.apply(cfg, root, undo)
	undo.commit_action()
	_set_status("Applied %s" % cfg.describe())
	_output.text = "Environment: %s\nViewport: %s\nDirectional lights tuned: %d" % [
		"yes" if report.get("environment", false) else "no",
		"yes" if report.get("viewport", false) else "no",
		int(report.get("lights", 0)),
	]


func quick_setup() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a 3D scene first.")
		return
	var cfg := _config()
	if cfg.lighting_rig == 0:
		cfg.lighting_rig = 2
	var undo = editor_plugin.get_undo_redo()
	undo.create_action("GDHPR: Quick Setup")
	GDHPR.apply(cfg, root, undo)
	var parent3d := root as Node3D
	if parent3d != null:
		GDHPRLightingRig.ensure(cfg.lighting_rig, parent3d)
	var report := GDHPROptimizer.run(root, cfg, undo)
	undo.commit_action()
	_output.text = GDHPROptimizer.format_report(report)
	_set_status("Quick setup done: %s" % cfg.describe())


func optimize_scene() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a scene first.")
		return
	var cfg := _config()
	var undo = editor_plugin.get_undo_redo()
	undo.create_action("GDHPR: Optimize Scene")
	var report := GDHPROptimizer.run(root, cfg, undo)
	undo.commit_action()
	_output.text = GDHPROptimizer.format_report(report)
	_set_status("Optimization applied.")


func analyze_scene() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a scene first.")
		return
	var info := GDHPROptimizer.analyze(root, int(_batch_min.value) if _batch_min else 3)
	var stats: Dictionary = info["stats"]
	var batchable: Dictionary = info["batchable"]
	_output.text = "\n".join(PackedStringArray([
		"Instances: %d   Draw calls: %d" % [stats["instances"], stats["draw_calls"]],
		"Triangles: %d   Meshes: %d" % [stats["triangles"], stats["instances"]],
		"Lights: %d (%d shadow casters)" % [info["lights"], info["shadow_lights"]],
		"Heavy meshes (>=3000 tris): %d" % info["heavy_meshes"],
		"Batching would save ~%d draw calls." % batchable["draw_calls_saved"],
		"",
		"Tip: run Optimize Scene, then check the profiler.",
	]))
	_set_status("Analysis complete.")


func add_world_node() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a 3D scene first.")
		return
	var world := GDHPRWorld.new()
	world.name = "GDHPRWorld"
	world.quality = _quality.selected as GDHPRConfig.Quality
	world.archetype = ARCHETYPE_KEYS[_archetype.selected]
	world.config = _config()
	var undo = editor_plugin.get_undo_redo()
	undo.create_action("GDHPR: Add World Node")
	undo.add_do_method(root, "add_child", world)
	undo.add_do_method(world, "set_owner", root)
	undo.add_do_reference(world)
	undo.add_undo_method(root, "remove_child", world)
	undo.commit_action()
	_set_status("Added GDHPRWorld. It configures the scene at runtime.")


func add_lighting_rig() -> void:
	var root := _current_scene() as Node3D
	if root == null:
		_set_status("Open a 3D scene first.")
		return
	var mood: int = _rig_mood.selected + 1 if _rig_mood.selected >= 0 else 1
	var undo = editor_plugin.get_undo_redo()
	undo.create_action("GDHPR: Add Lighting Rig")
	var existing := root.get_node_or_null(GDHPRLightingRig.RIG_ROOT_NAME)
	if existing != null:
		undo.add_do_method(root, "remove_child", existing)
		undo.add_undo_method(root, "add_child", existing)
		undo.add_undo_reference(existing)
	var rig := GDHPRLightingRig.build(mood, root, root, undo)
	undo.commit_action()
	_set_status("Added %s lighting rig." % GDHPRLightingRig.MOOD_NAMES[mood] if rig != null else "Could not add rig.")


func apply_sky() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a 3D scene first.")
		return
	var cfg := _config()
	cfg.fog_enabled = true
	var undo = editor_plugin.get_undo_redo()
	undo.create_action("GDHPR: Apply Sky")
	GDHPR.apply(cfg, root, undo)
	undo.commit_action()
	_set_status("Sky and environment updated.")


func assign_to_selection() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a scene first.")
		return
	var preset_name := _selected_material()
	if preset_name.is_empty():
		_set_status("Pick a material first.")
		return
	var material := GDHPRMaterialLibrary.preset(preset_name)
	var undo = editor_plugin.get_undo_redo()
	undo.create_action("GDHPR: Assign Material")
	var count := 0
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node is MeshInstance3D:
			undo.add_do_property(node, "material_override", material)
			undo.add_undo_property(node, "material_override", (node as MeshInstance3D).material_override)
			count += 1
		elif node is Node:
			count += GDHPRMaterialLibrary.override_meshes(node, preset_name)
	undo.commit_action()
	_set_status("Assigned '%s' to %d node(s)." % [preset_name, count])


func assign_to_scene() -> void:
	var root := _current_scene()
	if root == null:
		_set_status("Open a scene first.")
		return
	var preset_name := _selected_material()
	if preset_name.is_empty():
		_set_status("Pick a material first.")
		return
	GDHPRMaterialLibrary.override_meshes(root, preset_name)
	_set_status("Assigned '%s' to the whole scene." % preset_name)


func _selected_material() -> String:
	if _materials == null:
		return ""
	var selected := _materials.get_selected_items()
	if selected.is_empty():
		return ""
	return GDHPRMaterialLibrary.MATERIAL_NAMES[selected[0]]


func _on_save_code() -> void:
	_code_dialog.current_file = "generated_blueprint.gd"
	_code_dialog.popup_centered_ratio(0.5)


func _on_code_path_chosen(path: String) -> void:
	if _blueprint.save_generated_code(path) == OK:
		_set_status("Generated %s" % path)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
