extends Control

# Data-driven tech tree panel. Iterates the TechCollection on _ready, spawns
# one TechTreeNode per TechData (positioned via TechData.position), draws a
# Line2D connector from each prerequisite, and routes hover events to the
# shared TechPopup. Visibility is toggled by main.tscn's Research button via
# the same panelOpened/panelClosed pattern RobotUI uses.

const TECH_NODE_SCENE: PackedScene = preload("res://WIP/TechTree/tech_tree_node.tscn")

signal panelOpened
signal panelClosed

@onready var tech_popup: PopupPanel = $TechPopup
@onready var popup_label: Label = $TechPopup/Label
@onready var nodes_root: Control = $Nodes
@onready var connectors_root: Control = $Connectors

var _nodes_by_tech: Dictionary = {}


func _ready() -> void:
	hide()
	_build_tree()


func toggle() -> void:
	if visible:
		hide()
		tech_popup.hide()
		panelClosed.emit()
	else:
		show()
		panelOpened.emit()


# ESC closes the panel. ui_cancel is bound to Escape by default in Godot's
# built-in InputMap, so no project-level action setup is needed.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		toggle()
		accept_event()


func _build_tree() -> void:
	if TechTree.collection == null:
		return
	for tech in TechTree.collection.techs:
		_spawn_node(tech)
	# Connectors after every node exists so prereq positions are resolved.
	for tech in TechTree.collection.techs:
		_draw_connectors(tech)


func _spawn_node(tech: TechData) -> void:
	var node: TechTreeNode = TECH_NODE_SCENE.instantiate()
	nodes_root.add_child(node)
	# tech_tree_node.tscn uses center anchors (PRESET_8); reset to top-left so
	# TechData.position lands the node where authored.
	node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	node.size = Vector2(80, 80)
	node.position = tech.position
	node.setup(tech)
	node.hovered.connect(_on_node_hovered)
	node.unhovered.connect(_on_node_unhovered)
	_nodes_by_tech[tech] = node


func _draw_connectors(tech: TechData) -> void:
	var child_node: Control = _nodes_by_tech.get(tech)
	if child_node == null:
		return
	for prereq in tech.prerequisites:
		var parent_node: Control = _nodes_by_tech.get(prereq)
		if parent_node == null:
			continue
		var line := Line2D.new()
		line.width = 4.0
		line.default_color = Color(0.5, 0.5, 0.5, 1.0)
		line.z_index = -1
		var parent_center: Vector2 = parent_node.position + parent_node.size * 0.5
		var child_center: Vector2 = child_node.position + child_node.size * 0.5
		line.points = PackedVector2Array([parent_center, child_center])
		connectors_root.add_child(line)


func _on_node_hovered(tech: TechData) -> void:
	if tech == null:
		return
	var lines: Array[String] = []
	lines.append(tech.displayName)
	if tech.description != "":
		lines.append(tech.description)
	var cost_parts: Array[String] = []
	for entry in tech.cost:
		cost_parts.append("%s: %d" % [str(entry.resource).capitalize(), entry.amount])
	if not cost_parts.is_empty():
		lines.append("Cost: " + ", ".join(cost_parts))
	if TechTree.is_unlocked(tech):
		lines.append("(unlocked)")
	elif not tech.prerequisites.is_empty():
		var missing: Array[String] = []
		for prereq in tech.prerequisites:
			if not TechTree.is_unlocked(prereq):
				missing.append(prereq.displayName)
		if not missing.is_empty():
			lines.append("Requires: " + ", ".join(missing))
	popup_label.text = "\n".join(lines)
	tech_popup.popup()


func _on_node_unhovered() -> void:
	tech_popup.hide()


func _on_background_mouse_entered() -> void:
	tech_popup.hide()
