@tool
class_name GDHPRBlueprintGraph
extends Resource
## A blueprint graph: plain data that the editor edits and the compiler turns
## into GDScript. Saved as a normal Godot [code].tres[/code] resource.
##
## Node dictionaries look like:
## [codeblock]
## {"id": 3, "type": "print", "pos": Vector2(0, 0), "props": {"text": "hi"}}
## [/codeblock]
## Connections look like [code]{"from_node": 1, "from_port": 0, "to_node": 3, "to_port": 0}[/code].

@export var graph_name: String = "Blueprint"
## Base class of the generated script.
@export_enum("Node", "Node2D", "Node3D", "Control", "CharacterBody3D", "RigidBody3D", "Area3D")
var base_class: String = "Node3D"

@export var nodes: Array = []
@export var connections: Array = []


func _next_id() -> int:
	var highest := 0
	for node in nodes:
		highest = maxi(highest, int(node.get("id", 0)))
	return highest + 1


## Adds a node of [param type] and returns its id.
func add_node(type: String, pos: Vector2, props: Dictionary = {}) -> int:
	var definition := GDHPRBlueprintDefs.get_def(type)
	var node_data := {
		"id": _next_id(),
		"type": type,
		"pos": pos,
		"props": props.duplicate(true),
	}
	for param in definition.get("params", []):
		if not node_data["props"].has(param["name"]):
			node_data["props"][param["name"]] = param.get("default", "")
	nodes.append(node_data)
	return int(node_data["id"])


func remove_node(id: int) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if int(nodes[i].get("id", -1)) == id:
			nodes.remove_at(i)
	for i in range(connections.size() - 1, -1, -1):
		var link: Dictionary = connections[i]
		if int(link.get("from_node", -1)) == id or int(link.get("to_node", -1)) == id:
			connections.remove_at(i)


func node_data(id: int) -> Dictionary:
	for node in nodes:
		if int(node.get("id", -1)) == id:
			return node
	return {}


## Updates a node property (persisted in the graph).
func set_prop(id: int, key: String, value: Variant) -> void:
	var data := node_data(id)
	if data.is_empty():
		return
	if not data.has("props"):
		data["props"] = {}
	data["props"][key] = value


func set_pos(id: int, pos: Vector2) -> void:
	var data := node_data(id)
	if not data.is_empty():
		data["pos"] = pos


## Connects two ports. Returns true when the link is new and valid.
func connect_ports(from_node: int, from_port: int, to_node: int, to_port: int) -> bool:
	if from_node == to_node:
		return false
	for link in connections:
		if int(link["from_node"]) == from_node and int(link["from_port"]) == from_port \
				and int(link["to_node"]) == to_node and int(link["to_port"]) == to_port:
			return false
	connections.append({
		"from_node": from_node,
		"from_port": from_port,
		"to_node": to_node,
		"to_port": to_port,
	})
	return true


func disconnect_ports(from_node: int, from_port: int, to_node: int, to_port: int) -> void:
	for i in range(connections.size() - 1, -1, -1):
		var link: Dictionary = connections[i]
		if int(link["from_node"]) == from_node and int(link["from_port"]) == from_port \
				and int(link["to_node"]) == to_node and int(link["to_port"]) == to_port:
			connections.remove_at(i)


## All links going out of one output port.
func links_from(node_id: int, port: int) -> Array:
	var out := []
	for link in connections:
		if int(link["from_node"]) == node_id and int(link["from_port"]) == port:
			out.append(link)
	return out


## The link feeding one input port, or an empty dictionary.
func link_into(node_id: int, port: int) -> Dictionary:
	for link in connections:
		if int(link["to_node"]) == node_id and int(link["to_port"]) == port:
			return link
	return {}


func event_nodes() -> Array:
	var out := []
	for node in nodes:
		if GDHPRBlueprintDefs.get_def(node["type"]).get("category", "") == "Event":
			out.append(node)
	return out


func count_by_category(category: String) -> int:
	var total := 0
	for node in nodes:
		if GDHPRBlueprintDefs.get_def(node["type"]).get("category", "") == category:
			total += 1
	return total
