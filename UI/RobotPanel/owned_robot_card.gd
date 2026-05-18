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
	GlobalSignals.robot_purchased.connect(_on_robot_changed)
	GlobalSignals.robot_assigned.connect(_on_robot_pair_changed)
	GlobalSignals.robot_unassigned.connect(_on_robot_pair_changed)
	GlobalSignals.building_worker_assigned.connect(_on_worker_changed)
	GlobalSignals.building_worker_unassigned.connect(_on_worker_changed)
	_refresh()


func _populate_icon():
	IconHelper.populate(icon_holder, data.texture, Vector2(34, 34), Color(0.3, 0.3, 0.3))


func _refresh():
	if data == null:
		return
	name_label.text = data.robot_name
	var unassigned := GlobalResources.unassigned_count(data)
	count_label.text = "Unassigned: %d / Total: %d" % [unassigned, data.amount]
	visible = data.amount > 0


func _on_robot_changed(_robot):
	_refresh()


func _on_robot_pair_changed(_robot, _region):
	_refresh()


func _on_worker_changed(_robot, _region, _building):
	_refresh()


func _get_drag_data(_pos):
	if data == null:
		return null
	if GlobalResources.unassigned_count(data) <= 0:
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
		rect.custom_minimum_size = Vector2(34, 34)
		rect.size = Vector2(34, 34)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(rect)
	var label := Label.new()
	label.text = robot.robot_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	return preview
