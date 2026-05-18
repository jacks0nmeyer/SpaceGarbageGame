extends PanelContainer
class_name AssignedRobotRow

# A single (robot, count) line inside RegionInformation's Robots tab.
# Implements _get_drag_data so the player can drag the row back to the Owned
# tab to unassign one of that robot.

var robot: RobotData
var region: RegionData
var count: int = 0

# Cached production progress (0..1) for the row's background fill. Polled in
# _process from GameManager.get_robot_progress and redrawn only when it moves
# enough to be visible — avoids a queue_redraw every frame.
var _last_progress: float = 0.0
const _PROGRESS_REDRAW_EPSILON: float = 0.005
const _PROGRESS_FILL_COLOR: Color = Color(0.45, 0.85, 1.0, 0.18)


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
	label.text = "%s x%d" % [robot.robot_name, count]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	var remove_btn := Button.new()
	remove_btn.text = "−"
	remove_btn.tooltip_text = "Unassign one (right-click row). Shift+right-click: unassign all of this type."
	remove_btn.custom_minimum_size = Vector2(24, 24)
	remove_btn.focus_mode = Control.FOCUS_NONE
	remove_btn.pressed.connect(_unassign_one)
	hbox.add_child(remove_btn)


func _unassign_one() -> void:
	GlobalResources.unassign_one(robot, region)


func _process(_delta: float) -> void:
	if robot == null or region == null:
		return
	var p: float = 0.0
	if region.trash > 0:
		p = GameManager.get_robot_progress(region, robot)
	if absf(p - _last_progress) >= _PROGRESS_REDRAW_EPSILON \
			or (p == 0.0 and _last_progress != 0.0):
		_last_progress = p
		queue_redraw()


func _draw() -> void:
	if _last_progress <= 0.0:
		return
	var width: float = size.x * _last_progress
	draw_rect(Rect2(0.0, 0.0, width, size.y), _PROGRESS_FILL_COLOR)


# Right-click unassigns one; Shift+right-click clears every bot of this type
# in the region. Drag-back-to-Owned still works on left-click + drag via
# _get_drag_data.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.shift_pressed:
			GlobalResources.unassign_all_of_type(robot, region)
		else:
			_unassign_one()
		accept_event()


func _get_drag_data(_pos: Vector2):
	if robot == null or region == null:
		return null
	if int(region.assigned_robots.get(robot, 0)) <= 0:
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
	label.text = robot.robot_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	set_drag_preview(preview)
	return {"robot": robot, "from_region": region}
