extends Control

# Buy menu for robots. Future slices will add:
# - Tab that switches between Buy and Owned
# - Per-region inventory and drag-drop assignment

const ROBOT_ROW_SCENE: PackedScene = preload("res://WIP/RobotUI/robot_row.tscn")

signal panelOpened
signal panelClosed

@onready var rows_parent: VBoxContainer = $Panel/Vbox/Scroll/Rows


func _ready():
	hide()
	for robot in GlobalResources.robots.robots:
		var row = ROBOT_ROW_SCENE.instantiate()
		row.data = robot
		rows_parent.add_child(row)


func toggle():
	if visible:
		hide()
		panelClosed.emit()
	else:
		show()
		panelOpened.emit()
