extends Control

# Robot panel with two tabs:
# - Buy: existing robot_row entries that scale cost with RobotData.amount.
# - Owned: one card per robot with amount > 0; supports drag-to-region to
#   assign and accepts drag-from-region to unassign.

const ROBOT_ROW_SCENE: PackedScene = preload("res://WIP/RobotUI/robot_row.tscn")
const OWNED_CARD_SCENE: PackedScene = preload("res://WIP/RobotUI/owned_robot_card.tscn")

signal panelOpened
signal panelClosed

@onready var buy_rows: VBoxContainer = $Panel/Margin/Vbox/Tabs/Buy/Scroll/Rows
@onready var owned_rows: VBoxContainer = $Panel/Margin/Vbox/Tabs/Owned/Scroll/Rows


func _ready():
	hide()
	for robot in GlobalResources.robots.robots:
		var row = ROBOT_ROW_SCENE.instantiate()
		row.data = robot
		buy_rows.add_child(row)

		var card = OWNED_CARD_SCENE.instantiate()
		card.data = robot
		owned_rows.add_child(card)


func toggle():
	if visible:
		hide()
		panelClosed.emit()
	else:
		show()
		panelOpened.emit()
