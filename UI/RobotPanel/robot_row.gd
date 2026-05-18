extends PanelContainer
class_name RobotRow

@export var data: RobotData

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
	GlobalSignals.resources_updated.connect(_on_resources_updated)
	GlobalSignals.tech_unlocked.connect(_on_tech_unlocked)
	_refresh()


func _populate_icon():
	IconHelper.populate(icon_holder, data.texture, Vector2(34, 34), Color.BLACK)


func current_cost() -> Dictionary:
	var dict := {}
	var multiplier: float = pow(data.cost_increase, data.amount)
	var tech_scalar: float = TechTree.get_robot_cost_scalar()
	for entry in data.unlock_cost:
		dict[entry.resource] = max(1, int(round(entry.amount * multiplier * tech_scalar)))
	return dict


func _refresh():
	name_label.text = data.robot_name
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
		GlobalSignals.robot_purchased.emit(data)


func _on_resources_updated(_resources: Dictionary):
	if data == null:
		return
	buy_button.disabled = not GlobalResources.can_afford(current_cost())


func _on_tech_unlocked(_tech) -> void:
	if data == null:
		return
	_refresh()
