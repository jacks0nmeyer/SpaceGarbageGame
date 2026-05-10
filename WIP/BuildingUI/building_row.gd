extends PanelContainer
class_name BuildingRow

# Buy row for a single BuildingData. Cost is FLAT — no scaling exponent.
# Mirrors WIP/RobotUI/robot_row.gd minus the costIncrease/tech-scalar math.

@export var data: BuildingData

@onready var icon_holder: Control = $Margin/HBox/IconHolder
@onready var name_label: Label = $Margin/HBox/Info/NameLabel
@onready var desc_label: Label = $Margin/HBox/Info/DescLabel
@onready var owned_label: Label = $Margin/HBox/Info/OwnedLabel
@onready var cost_label: Label = $Margin/HBox/Buy/CostLabel
@onready var buy_button: Button = $Margin/HBox/Buy/BuyButton


func _ready():
	if data == null:
		return
	_populate_icon()
	buy_button.pressed.connect(_on_buy_pressed)
	GlobalSignals.resourcesUpdated.connect(_on_resources_updated)
	_refresh()


func _populate_icon():
	for child in icon_holder.get_children():
		child.queue_free()
	if data.texture != null:
		var rect := TextureRect.new()
		rect.texture = data.texture
		rect.custom_minimum_size = Vector2(32, 32)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.add_child(rect)
	else:
		var color := ColorRect.new()
		color.color = Color.BLACK
		color.custom_minimum_size = Vector2(32, 32)
		icon_holder.add_child(color)


func current_cost() -> Dictionary:
	var dict := {}
	for entry in data.unlockCost:
		dict[entry.resource] = int(entry.amount)
	return dict


func _refresh():
	name_label.text = data.buildingName
	desc_label.text = data.description
	owned_label.text = "Owned: %d" % data.amount
	var cost := current_cost()
	if cost.is_empty():
		cost_label.text = "Free"
	else:
		var parts: Array[String] = []
		for resource in cost:
			parts.append("%s: %d" % [str(resource).capitalize(), cost[resource]])
		cost_label.text = "\n".join(parts)
	buy_button.disabled = not GlobalResources.can_afford(cost)


func _on_buy_pressed():
	var cost := current_cost()
	if GlobalResources.purchase(cost):
		data.amount += 1
		_refresh()
		GlobalSignals.buildingPurchased.emit(data)


func _on_resources_updated(_resources: Dictionary):
	if data == null:
		return
	buy_button.disabled = not GlobalResources.can_afford(current_cost())
