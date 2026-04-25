extends PanelContainer
class_name RobotRow

@export var data: RobotData

@onready var icon_holder: Control = $HBox/IconHolder
@onready var name_label: Label = $HBox/Info/NameLabel
@onready var desc_label: Label = $HBox/Info/DescLabel
@onready var owned_label: Label = $HBox/Info/OwnedLabel
@onready var cost_label: Label = $HBox/Buy/CostLabel
@onready var buy_button: Button = $HBox/Buy/BuyButton


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
	var multiplier: float = pow(data.costIncrease, data.amount)
	for entry in data.unlockCost:
		dict[entry.resource] = int(round(entry.amount * multiplier))
	return dict


func _refresh():
	name_label.text = data.robotName
	desc_label.text = data.description
	owned_label.text = "Owned: %d" % data.amount
	var cost := current_cost()
	if cost.is_empty():
		cost_label.text = "Free"
	else:
		var parts: Array[String] = []
		for resource in cost:
			parts.append("%s: %d" % [str(resource).capitalize(), cost[resource]])
		cost_label.text = ", ".join(parts)
	buy_button.disabled = not GlobalResources.can_afford(cost)


func _on_buy_pressed():
	var cost := current_cost()
	if GlobalResources.purchase(cost):
		data.amount += 1
		_refresh()
		GlobalSignals.robotPurchased.emit(data)


func _on_resources_updated(_resources: Dictionary):
	if data == null:
		return
	buy_button.disabled = not GlobalResources.can_afford(current_cost())
