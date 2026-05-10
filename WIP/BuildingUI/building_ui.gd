extends Control

# Mirror of WIP/RobotUI/robot_ui.gd for buildings. Two tabs:
# - Buy: building_row entries with flat (non-scaling) cost.
# - Owned: one card per building with amount > 0; supports drag-to-region's
#   Buildings tab to assign and accepts drag-from-region to unassign.

const BUILDING_ROW_SCENE: PackedScene = preload("res://WIP/BuildingUI/building_row.tscn")
const OWNED_CARD_SCENE: PackedScene = preload("res://WIP/BuildingUI/owned_building_card.tscn")

signal panelOpened
signal panelClosed

@onready var buy_rows: VBoxContainer = $Panel/Margin/Vbox/Tabs/Buy/Scroll/Rows
@onready var owned_rows: VBoxContainer = $Panel/Margin/Vbox/Tabs/Owned/Scroll/Rows


func _ready():
	hide()
	for building in GlobalResources.buildings.buildings:
		var row = BUILDING_ROW_SCENE.instantiate()
		row.data = building
		buy_rows.add_child(row)

		var card = OWNED_CARD_SCENE.instantiate()
		card.data = building
		owned_rows.add_child(card)


func toggle():
	if visible:
		hide()
		panelClosed.emit()
	else:
		show()
		panelOpened.emit()
