extends PanelContainer
class_name AssignedBuildingRow

# A single (building, count) line inside RegionInformation's Buildings tab.
# - "Stored: X / Y" label (sum across resources)
# - "Process" button — drains process_amount into the player's inventory
# - "Workers: X / Y" with +/- buttons to staff/unstaff a robot worker
# - Right-click: unassign one. Shift+right-click: unassign all of this type.
# - Drag: returns {building, from_region} so the row can be dragged back to
#   the Owned card to unassign one. Also accepts robot drag payloads to staff.

var building: BuildingData
var region: RegionData
var count: int = 0

var stored_label: Label
var process_button: Button
var workers_label: Label
var workers_minus: Button
var workers_plus: Button
var storage_row: HBoxContainer

# Auto-process progress (0..1) for the bar drawn behind the Stored row. Polled
# in _process from GameManager.get_building_progress; redrawn only when it
# moves enough to be visible. Gated on worker_count > 0 — no worker, no bar.
var _last_progress: float = 0.0
const _PROGRESS_REDRAW_EPSILON: float = 0.005
const _PROGRESS_FILL_COLOR: Color = Color(0.45, 0.85, 1.0, 0.18)


func setup(p_building: BuildingData, p_region: RegionData, p_count: int) -> void:
	building = p_building
	region = p_region
	count = p_count
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Top row: icon + name + unassign button
	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(top)

	if building.texture != null:
		var icon := TextureRect.new()
		icon.texture = building.texture
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(icon)

	var name_label := Label.new()
	name_label.text = "%s x%d" % [building.building_name, count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_label)

	var remove_btn := Button.new()
	remove_btn.text = "−"
	remove_btn.tooltip_text = "Unassign one (right-click row). Shift+right-click: unassign all of this type."
	remove_btn.custom_minimum_size = Vector2(24, 24)
	remove_btn.focus_mode = Control.FOCUS_NONE
	remove_btn.pressed.connect(_unassign_one)
	top.add_child(remove_btn)

	# Storage row: "Stored: X / Y" + Process button
	storage_row = HBoxContainer.new()
	storage_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(storage_row)

	stored_label = Label.new()
	stored_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stored_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	storage_row.add_child(stored_label)

	process_button = Button.new()
	process_button.text = "Process"
	process_button.focus_mode = Control.FOCUS_NONE
	process_button.pressed.connect(_on_process_pressed)
	storage_row.add_child(process_button)

	# Workers row: "Workers: X / Y" + + / - buttons
	var workers_row := HBoxContainer.new()
	workers_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(workers_row)

	workers_label = Label.new()
	workers_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workers_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	workers_row.add_child(workers_label)

	workers_minus = Button.new()
	workers_minus.text = "−"
	workers_minus.tooltip_text = "Unstaff one worker"
	workers_minus.custom_minimum_size = Vector2(24, 24)
	workers_minus.focus_mode = Control.FOCUS_NONE
	workers_minus.pressed.connect(_on_workers_minus)
	workers_row.add_child(workers_minus)

	workers_plus = Button.new()
	workers_plus.text = "+"
	workers_plus.tooltip_text = "Staff a worker (uses any unassigned robot)"
	workers_plus.custom_minimum_size = Vector2(24, 24)
	workers_plus.focus_mode = Control.FOCUS_NONE
	workers_plus.pressed.connect(_on_workers_plus)
	workers_row.add_child(workers_plus)

	refresh_storage()
	refresh_workers()


func refresh_storage() -> void:
	if building == null or region == null or stored_label == null:
		return
	var stored: int = region.stored_in_building(building)
	var cap: int = region.capacity_for_building(building)
	stored_label.text = "Stored: %d / %d" % [stored, cap]
	if process_button != null:
		process_button.disabled = stored <= 0


func refresh_workers() -> void:
	if building == null or region == null or workers_label == null:
		return
	var workers: int = region.worker_count(building)
	var cap: int = region.worker_cap(building)
	workers_label.text = "Workers: %d / %d" % [workers, cap]
	if workers_plus != null:
		workers_plus.disabled = (workers >= cap) or (not _any_robot_available())
	if workers_minus != null:
		workers_minus.disabled = workers <= 0


func _any_robot_available() -> bool:
	var coll: RobotCollection = GlobalResources.robots
	if coll == null:
		return false
	for robot in coll.robots:
		if GlobalResources.unassigned_count(robot) > 0:
			return true
	return false


func _unassign_one() -> void:
	GlobalResources.unassign_one_building(building, region)


func _on_process_pressed() -> void:
	GlobalResources.process_building_clicked(region, building)


func _on_workers_plus() -> void:
	GlobalResources.staff_any_available(region, building)


func _on_workers_minus() -> void:
	if not region.building_workers.has(building):
		return
	var any_robot = region.building_workers[building].keys()[0]
	GlobalResources.unstaff_one_worker(any_robot, region, building)


func _process(_delta: float) -> void:
	if building == null or region == null:
		return
	var p: float = 0.0
	if region.worker_count(building) > 0:
		p = GameManager.get_building_progress(region, building)
	if absf(p - _last_progress) >= _PROGRESS_REDRAW_EPSILON \
			or (p == 0.0 and _last_progress != 0.0):
		_last_progress = p
		queue_redraw()


func _draw() -> void:
	if _last_progress <= 0.0 or storage_row == null:
		return
	var row_rect := Rect2(storage_row.position, storage_row.size)
	row_rect.size.x *= _last_progress
	draw_rect(row_rect, _PROGRESS_FILL_COLOR)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.shift_pressed:
			GlobalResources.unassign_all_of_type_building(building, region)
		else:
			_unassign_one()
		accept_event()


func _get_drag_data(_pos: Vector2):
	if building == null or region == null:
		return null
	if int(region.assigned_buildings.get(building, 0)) <= 0:
		return null
	var preview := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	preview.add_child(hbox)
	if building.texture != null:
		var rect := TextureRect.new()
		rect.texture = building.texture
		rect.custom_minimum_size = Vector2(34, 34)
		rect.size = Vector2(34, 34)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(rect)
	var label := Label.new()
	label.text = building.building_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	set_drag_preview(preview)
	return {"building": building, "from_region": region}


# Accept two drag payload shapes:
# - {robot, from_region: ...}    — staff a worker in this building.
#   * from_region null   → drag from Owned card → staff one
#   * from_region == region → drag from this region's Robots tab → atomic
#     move: unassign from region.assigned_robots, then staff
# - {building, from_region: ...} — assign another building of any type into
#   this region. Forwards to the same logic as region_buildings_tab so that
#   drops over an existing row don't get swallowed (Godot's drop propagation
#   up the parent chain is unreliable when an inner control rejects the
#   payload).
func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("from_region"):
		return false
	if region == null or region.locked:
		return false
	if data.has("robot") and data["robot"] is RobotData:
		if building == null or not region.can_staff(building):
			return false
		var from_region = data["from_region"]
		if from_region == null:
			return GlobalResources.unassigned_count(data["robot"]) > 0
		if from_region != region:
			return false
		return int(region.assigned_robots.get(data["robot"], 0)) > 0
	if data.has("building") and data["building"] is BuildingData:
		var b: BuildingData = data["building"]
		var from_region = data["from_region"]
		if from_region == region:
			return false
		if from_region == null and GlobalResources.unassigned_building_count(b) <= 0:
			return false
		return region.can_fit_building(b)
	return false


func _drop_data(_pos: Vector2, data) -> void:
	if data.has("robot"):
		var robot: RobotData = data["robot"]
		var from_region = data["from_region"]
		if from_region == region:
			GlobalResources.unassign_one(robot, region)
			GlobalResources.staff_one_worker(robot, region, building)
		else:
			GlobalResources.staff_one_worker(robot, region, building)
	elif data.has("building"):
		GlobalResources.assign_one_building(data["building"], region, data["from_region"])
