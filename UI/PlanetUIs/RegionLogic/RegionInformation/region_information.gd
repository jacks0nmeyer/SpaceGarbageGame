extends TabContainer

@onready var region_name: Label = $Info/RegionName
@onready var trash_bar: ProgressBar = $"Info/T&PContainer/Trash&Pollution/TrashDisplay/TrashBar"
@onready var trash_display: Label = $"Info/T&PContainer/Trash&Pollution/TrashDisplay/TrashDisplay"
@onready var region_pollution: TextureRect = $"Info/T&PContainer/Trash&Pollution/RegionPollution"
@onready var resource_grid: GridContainer = $Info/ResourceGrid
@onready var production_grid: GridContainer = $Info/ProductionGrid
@onready var region_description: Label = $"Info/DescContainer/Region Description"
@onready var slots_label: Label = $Robots/Margin/Vbox/SlotsLabel
@onready var assigned_rows: VBoxContainer = $Robots/Margin/Vbox/Scroll/Rows
@onready var empty_label: Label = $Robots/Margin/Vbox/EmptyLabel


func _ready():
	GlobalSignals.regionHovered.connect(onRegionHovered)
	GlobalSignals.regionTrashUpdated.connect(updateProgress)
	GlobalSignals.resourceRateUpdated.connect(onRateUpdated)
	GlobalSignals.robotAssigned.connect(_on_robot_pair_changed)
	GlobalSignals.robotUnassigned.connect(_on_robot_pair_changed)
	GlobalSignals.regionPinToggled.connect(_on_pin_toggled)
	hide()


var currentRegion: RegionData = null


func onRegionHovered(region: RegionData):
	# Don't retarget mid-drag (e.g. dragging an AssignedRobotRow back to the
	# Owned tab and brushing past another region) and don't retarget while
	# the panel is pinned to a specific region.
	if get_viewport().gui_is_dragging():
		return
	if GlobalResources.pinnedRegion != null:
		return
	show()
	if region != currentRegion:
		_switch_to(region)


func _switch_to(region: RegionData):
	currentRegion = region
	updateInfo(region)
	updateResources(region)
	updateProgress(region)
	updateRobots(region)


# Fires after GlobalResources has already toggled its pinnedRegion. We just
# react: if the new pin targets a different region, switch to it; either way,
# refresh the 📌 indicator.
func _on_pin_toggled(_region: RegionData):
	var pinned: RegionData = GlobalResources.pinnedRegion
	if pinned != null:
		show()
		if pinned != currentRegion:
			_switch_to(pinned)
			return
	_refresh_pin_indicator()


func _refresh_pin_indicator():
	if currentRegion == null:
		return
	var prefix := ""
	if GlobalResources.pinnedRegion == currentRegion:
		prefix = "📌 "
	region_name.text = prefix + currentRegion.regionName


func updateInfo(region: RegionData):
	var prefix := ""
	if GlobalResources.pinnedRegion == region:
		prefix = "📌 "
	region_name.text = prefix + region.regionName
	if region.locked == true:
		region_description.text = region.lockedDescription
	else:
		region_description.text = region.description


func updateResources(region: RegionData):
	for child in resource_grid.get_children(): #removes placeholder labels
		child.queue_free()
	for child in production_grid.get_children():
		child.queue_free()
		
	var limit := 0
	for entry in region.resourceChances: #sets labels based on region's resource chances
		if entry.chance > 0.0 and limit < 4: 
			var label = Label.new() 
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			label.text = "%s: %d%%" % [entry.resource.capitalize(), entry.chance*100]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			resource_grid.add_child(label)
			
			var rate_label = Label.new()
			rate_label.name = entry.resource.to_lower() + "_rate"
			rate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rate_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			rate_label.text = "%s/S: 0" % entry.resource.capitalize()
			rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			production_grid.add_child(rate_label)
			
			limit += 1
 

func onRateUpdated(rates: Dictionary):
	for child in production_grid.get_children():
		if child.name.ends_with("_rate"):
			var resource_name = child.name.replace("_rate", "")
			var rate = rates.get(resource_name, 0)
			child.text = "%s/S: %d" % [resource_name.capitalize(), rate]

func updateProgress(region: RegionData):
	if region != currentRegion:
		return
	trash_bar.max_value = region.maxTrash
	trash_bar.value = region.trash
	trash_display.text = "%d / %d" % [region.trash, region.maxTrash]
	
	
func updateRobots(region: RegionData):
	for child in assigned_rows.get_children():
		child.queue_free()

	var used := region.assignedSlotsUsed()
	slots_label.text = "Slots: %d / %d" % [used, region.robot_capacity]

	var any := false
	for robot in region.assignedRobots:
		var count: int = int(region.assignedRobots[robot])
		if count <= 0:
			continue
		any = true
		var row := AssignedRobotRow.new()
		assigned_rows.add_child(row)
		row.setup(robot, region, count)

	empty_label.visible = not any


func _on_robot_pair_changed(_robot: RobotData, region: RegionData):
	if region == currentRegion:
		updateRobots(region)


func _on_tab_clicked(tab: int): #Lets the "X" tab close the menu
	if tab == 2:
		if GlobalResources.pinnedRegion != null:
			GlobalSignals.regionPinToggled.emit(GlobalResources.pinnedRegion)
		hide()
