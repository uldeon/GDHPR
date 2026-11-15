@tool
class_name GDHPRBlueprintDefs
extends RefCounted
## Node catalogue for the blueprint editor.
##
## Every entry declares its ports and its editable parameters. The compiler
## ([GDHPRBlueprintCompiler]) and the editor UI both read from here, so adding a
## node type is a one-entry change.

const FLOW_COLOR := Color(0.85, 0.88, 0.95)
const VALUE_COLOR := Color(0.30, 0.78, 0.72)
const EXEC_COLOR := Color(0.95, 0.55, 0.30)

## Ordered list of categories for the "Add node" menu.
const CATEGORIES := ["Event", "Flow", "Value"]

const NODES := {
	# --- Events -------------------------------------------------------------
	"event_ready": {
		"title": "On Ready",
		"category": "Event",
		"desc": "Runs once when the node enters the tree.",
		"inputs": [],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [],
	},
	"event_process": {
		"title": "On Process",
		"category": "Event",
		"desc": "Runs every frame.",
		"inputs": [],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [],
	},
	"event_input": {
		"title": "On Action Pressed",
		"category": "Event",
		"desc": "Runs when an input action is pressed.",
		"inputs": [],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [{"name": "action", "type": "String", "default": "ui_accept"}],
	},
	"func_define": {
		"title": "Function",
		"category": "Event",
		"desc": "Declares a custom function. Its body runs from the Then port.",
		"inputs": [],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [
			{"name": "function", "type": "String", "default": "my_function"},
			{"name": "arg_count", "type": "int", "default": 0, "max": 3},
			{"name": "arg0", "type": "String", "default": "a"},
			{"name": "arg1", "type": "String", "default": "b"},
			{"name": "arg2", "type": "String", "default": "c"},
		],
	},

	# --- Flow ---------------------------------------------------------------
	"print": {
		"title": "Print",
		"category": "Flow",
		"desc": "Prints a message to the output log.",
		"inputs": [{"name": "Then", "kind": "flow"}, {"name": "Message", "kind": "value"}],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [{"name": "text", "type": "String", "default": "Hello GDHPR"}],
	},
	"if_branch": {
		"title": "Branch (If)",
		"category": "Flow",
		"desc": "Runs one of two chains based on a condition.",
		"inputs": [{"name": "Then", "kind": "flow"}, {"name": "Condition", "kind": "value"}],
		"outputs": [{"name": "True", "kind": "flow"}, {"name": "False", "kind": "flow"}],
		"params": [],
	},
	"set_var": {
		"title": "Set Variable",
		"category": "Flow",
		"desc": "Stores a value in a variable on this script.",
		"inputs": [{"name": "Then", "kind": "flow"}, {"name": "Value", "kind": "value"}],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [
			{"name": "variable", "type": "String", "default": "my_value"},
			{"name": "value", "type": "float", "default": 0.0},
		],
	},
	"call_method": {
		"title": "Call Method",
		"category": "Flow",
		"desc": "Calls a method on a node. Target 'self' means this script.",
		"inputs": [
			{"name": "Then", "kind": "flow"},
			{"name": "Arg 0", "kind": "value"},
			{"name": "Arg 1", "kind": "value"},
		],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [
			{"name": "target", "type": "String", "default": "self"},
			{"name": "method", "type": "String", "default": "print"},
			{"name": "arg_count", "type": "int", "default": 0},
		],
	},
	"set_property": {
		"title": "Set Property",
		"category": "Flow",
		"desc": "Assigns a property on a node.",
		"inputs": [{"name": "Then", "kind": "flow"}, {"name": "Value", "kind": "value"}],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [
			{"name": "target", "type": "String", "default": "self"},
			{"name": "property", "type": "String", "default": "visible"},
			{"name": "value", "type": "bool", "default": true},
		],
	},
	"wait": {
		"title": "Wait",
		"category": "Flow",
		"desc": "Pauses this chain for N seconds, then continues.",
		"inputs": [{"name": "Then", "kind": "flow"}, {"name": "Seconds", "kind": "value"}],
		"outputs": [{"name": "Then", "kind": "flow"}],
		"params": [{"name": "seconds", "type": "float", "default": 1.0}],
	},
	"for_range": {
		"title": "For Loop",
		"category": "Flow",
		"desc": "Runs Body once per number in range(From, To), then continues from After.",
		"inputs": [
			{"name": "Then", "kind": "flow"},
			{"name": "From", "kind": "value"},
			{"name": "To", "kind": "value"},
		],
		"outputs": [{"name": "Body", "kind": "flow"}, {"name": "After", "kind": "flow"}],
		"params": [
			{"name": "variable", "type": "String", "default": "i"},
			{"name": "from", "type": "float", "default": 0.0},
			{"name": "to", "type": "float", "default": 10.0},
		],
	},
	"while_loop": {
		"title": "While Loop",
		"category": "Flow",
		"desc": "Repeats Body while Condition is true, then continues from After.",
		"inputs": [{"name": "Then", "kind": "flow"}, {"name": "Condition", "kind": "value"}],
		"outputs": [{"name": "Body", "kind": "flow"}, {"name": "After", "kind": "flow"}],
		"params": [],
	},
	"loop_break": {
		"title": "Break",
		"category": "Flow",
		"desc": "Leaves the innermost loop.",
		"inputs": [{"name": "Then", "kind": "flow"}],
		"outputs": [],
		"params": [],
	},
	"loop_continue": {
		"title": "Continue",
		"category": "Flow",
		"desc": "Skips to the next iteration of the innermost loop.",
		"inputs": [{"name": "Then", "kind": "flow"}],
		"outputs": [],
		"params": [],
	},
	"func_return": {
		"title": "Return",
		"category": "Flow",
		"desc": "Ends the current function, optionally returning a value.",
		"inputs": [{"name": "Then", "kind": "flow"}, {"name": "Value", "kind": "value"}],
		"outputs": [],
		"params": [],
	},
	"call_custom": {
		"title": "Call Function",
		"category": "Flow",
		"desc": "Calls a function made with a Function node. The Value port can feed expressions.",
		"inputs": [
			{"name": "Then", "kind": "flow"},
			{"name": "Arg 0", "kind": "value"},
			{"name": "Arg 1", "kind": "value"},
			{"name": "Arg 2", "kind": "value"},
		],
		"outputs": [{"name": "Then", "kind": "flow"}, {"name": "Value", "kind": "value"}],
		"params": [
			{"name": "function", "type": "String", "default": "my_function"},
			{"name": "arg_count", "type": "int", "default": 0, "max": 3},
		],
	},

	# --- Values -------------------------------------------------------------
	"const_float": {
		"title": "Number",
		"category": "Value",
		"desc": "A constant number.",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [{"name": "value", "type": "float", "default": 0.0}],
	},
	"const_string": {
		"title": "Text",
		"category": "Value",
		"desc": "A constant string.",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [{"name": "value", "type": "String", "default": ""}],
	},
	"const_bool": {
		"title": "Boolean",
		"category": "Value",
		"desc": "A constant true/false.",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [{"name": "value", "type": "bool", "default": true}],
	},
	"const_vector3": {
		"title": "Vector3",
		"category": "Value",
		"desc": "A constant 3D vector.",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [{"name": "value", "type": "Vector3", "default": Vector3.ZERO}],
	},
	"get_var": {
		"title": "Get Variable",
		"category": "Value",
		"desc": "Reads a variable declared by Set Variable.",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [{"name": "variable", "type": "String", "default": "my_value"}],
	},
	"math": {
		"title": "Math",
		"category": "Value",
		"desc": "Combines two numbers.",
		"inputs": [{"name": "A", "kind": "value"}, {"name": "B", "kind": "value"}],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [
			{"name": "op", "type": "enum", "options": ["+", "-", "*", "/", "%", "min", "max"], "default": "+"},
			{"name": "a", "type": "float", "default": 0.0},
			{"name": "b", "type": "float", "default": 1.0},
		],
	},
	"compare": {
		"title": "Compare",
		"category": "Value",
		"desc": "Compares two values, returns true/false.",
		"inputs": [{"name": "A", "kind": "value"}, {"name": "B", "kind": "value"}],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [
			{"name": "op", "type": "enum", "options": ["==", "!=", ">", ">=", "<", "<="], "default": "=="},
			{"name": "a", "type": "float", "default": 0.0},
			{"name": "b", "type": "float", "default": 0.0},
		],
	},
	"random_range": {
		"title": "Random Number",
		"category": "Value",
		"desc": "Random float between min and max.",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [
			{"name": "min", "type": "float", "default": 0.0},
			{"name": "max", "type": "float", "default": 1.0},
		],
	},
	"get_delta": {
		"title": "Delta",
		"category": "Value",
		"desc": "Frame time. Only valid inside On Process.",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [],
	},
	"get_position": {
		"title": "Position",
		"category": "Value",
		"desc": "Global position of a node (self by default).",
		"inputs": [],
		"outputs": [{"name": "Value", "kind": "value"}],
		"params": [{"name": "target", "type": "String", "default": "self"}],
	},
}


static func get_def(type: String) -> Dictionary:
	return NODES.get(type, NODES["print"])


static func has_type(type: String) -> bool:
	return NODES.has(type)


static func types_in_category(category: String) -> Array:
	var out := []
	for type in NODES:
		if NODES[type]["category"] == category:
			out.append(type)
	return out


static func port_count(type: String, output: bool) -> int:
	var definition := get_def(type)
	return definition["outputs"].size() if output else definition["inputs"].size()


static func port_kind(type: String, output: bool, port: int) -> String:
	var definition := get_def(type)
	var ports: Array = definition["outputs"] if output else definition["inputs"]
	if port < 0 or port >= ports.size():
		return ""
	return ports[port]["kind"]


static func port_color(type: String, output: bool, port: int) -> Color:
	match port_kind(type, output, port):
		"flow":
			return FLOW_COLOR
		"value":
			return VALUE_COLOR
	return EXEC_COLOR
