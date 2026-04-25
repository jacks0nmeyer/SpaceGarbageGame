extends PanelContainer
class_name AssignedRobotRow

# A single (robot, count) line inside RegionInformation's Robots tab.
# Implements _get_drag_data so the player can drag the row back to the Owned
# tab to unassign one of that robot.

var robot: RobotData
var region: RegionData
var count: int = 0


func setup(p_robot: RobotData, p_region: RegionData, p_count: int) -> void:
	robot = p_robot
	region = p_region
	count = p_count
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	if robot.texture != null:
		var icon := TextureRect.new()
		icon.texture = robot.texture
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(icon)

	var label := Label.new()
	label.text = "%s x%d" % [robot.robotName, count]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	var remove_btn := Button.new()
	remove_btn.text = "−"
	remove_btn.tooltip_text = "Unassign one (or right-click the row)"
	remove_btn.custom_minimum_size = Vector2(24, 24)
	remove_btn.focus_mode = Control.FOCUS_NONE
	remove_btn.pressed.connect(_unassign_one)
	hbox.add_child(remove_btn)


func _unassign_one() -> void:
	GlobalResources.unassignOne(robot, region)


# Right-click anywhere on the row also unassigns one. Drag-back-to-Owned still
# works on left-click + drag via _get_drag_data.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_unassign_one()
		accept_event()


func _get_drag_data(_pos: Vector2):
	if robot == null or region == null:
		return null
	if int(region.assignedRobots.get(robot, 0)) <= 0:
		return null
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
	set_drag_preview(preview)
	return {"robot": robot, "from_region": region}
