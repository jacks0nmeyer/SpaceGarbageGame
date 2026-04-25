extends PanelContainer
class_name OwnedRobotCard

@export var data: RobotData

@onready var icon_holder: Control = $Margin/HBox/IconHolder
@onready var name_label: Label = $Margin/HBox/Info/NameLabel
@onready var count_label: Label = $Margin/HBox/Info/CountLabel


func _ready():
	if data == null:
		return
	_populate_icon()
	GlobalSignals.robotPurchased.connect(_on_robot_changed)
	GlobalSignals.robotAssigned.connect(_on_robot_pair_changed)
	GlobalSignals.robotUnassigned.connect(_on_robot_pair_changed)
	_refresh()


func _populate_icon():
	for child in icon_holder.get_children():
		child.queue_free()
	if data.texture != null:
		var rect := TextureRect.new()
		rect.texture = data.texture
		rect.custom_minimum_size = Vector2(40, 40)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.add_child(rect)
	else:
		var color := ColorRect.new()
		color.color = Color(0.3, 0.3, 0.3)
		color.custom_minimum_size = Vector2(40, 40)
		icon_holder.add_child(color)


func _refresh():
	if data == null:
		return
	name_label.text = data.robotName
	var unassigned := GlobalResources.unassignedCount(data)
	count_label.text = "Unassigned: %d / Total: %d" % [unassigned, data.amount]
	visible = data.amount > 0


func _on_robot_changed(_robot):
	_refresh()


func _on_robot_pair_changed(_robot, _region):
	_refresh()


func _get_drag_data(_pos):
	if data == null:
		return null
	if GlobalResources.unassignedCount(data) <= 0:
		return null
	set_drag_preview(_make_drag_preview(data))
	return {"robot": data, "from_region": null}


static func _make_drag_preview(robot: RobotData) -> Control:
	var preview := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	preview.add_child(hbox)
	if robot.texture != null:
		var rect := TextureRect.new()
		rect.texture = robot.texture
		rect.custom_minimum_size = Vector2(40, 40)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(rect)
	var label := Label.new()
	label.text = robot.robotName
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	return preview
