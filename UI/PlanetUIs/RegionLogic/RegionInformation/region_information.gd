extends TabContainer

@onready var region_name: Label = $Info/RegionName
@onready var trash_bar: ProgressBar = $"Info/T&PContainer/Trash&Pollution/TrashDisplay/TrashBar"
@onready var trash_display: Label = $"Info/T&PContainer/Trash&Pollution/TrashDisplay/TrashDisplay"
@onready var resource_grid: GridContainer = $Info/ResourceGrid
@onready var production_grid: GridContainer = $Info/ProductionGrid
@onready var region_description: Label = $"Info/DescContainer/Region Description"
@onready var slots_label: Label = $Robots/Margin/Vbox/SlotsLabel
@onready var assigned_rows: VBoxContainer = $Robots/Margin/Vbox/Scroll/Rows
@onready var empty_label: Label = $Robots/Margin/Vbox/EmptyLabel


func _ready():
	GlobalSignals.regionHovered.connect(onRegionHovered)
	GlobalSignals.regionTrashUpdated.connect(updateProgress)
	GlobalSignals.robotAssigned.connect(_on_robot_pair_changed)
	GlobalSignals.robotUnassigned.connect(_on_robot_pair_changed)
	GlobalSignals.regionPinToggled.connect(_on_pin_toggled)
	GlobalSignals.regionPollutionUpdated.connect(onPollutionUpdated)
	hide()


var currentRegion: RegionData = null
var currentPollutionLevel: int = -1


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
	currentPollutionLevel = int(region.getPollutionLevel())
	updateInfo(region)
	updateResources(region)
	updateResourceRates(region)
	updateProgress(region)
	updateRobots(region)
	updatePollution(region)
	updatePollutionTrend(region)
	updatePollutionPopup(region)


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
	# remove_child first so the name slot is freed synchronously; queue_free alone
	# defers deletion to end-of-frame, which causes add_child below to see the
	# old "junk_rate" / "scrap_rate" siblings still present and silently rename
	# the replacements to "junk_rate2" — breaking the suffix-based lookup in
	# updateResourceRates on every hover after the first.
	for child in resource_grid.get_children(): #removes placeholder labels
		resource_grid.remove_child(child)
		child.queue_free()
	for child in production_grid.get_children():
		production_grid.remove_child(child)
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
 

# Deterministic per-region resource rate. Each robot picks one resource per
# trash unit weighted by region.resourceChances, then deposits resourceReturn
# of it; expected per-second contribution of robot R to resource X is
# count * productionRate * chance(X) * resourceReturn(R). Updated only when
# robot composition changes, not on a polling timer.
func updateResourceRates(region: RegionData):
	var rates: Dictionary = {}
	for entry in region.resourceChances:
		rates[entry.resource.to_lower()] = 0.0

	var pollution_mult: float = GlobalResources.getPollutionProductionMultiplier(region.getPollutionLevel())
	for robot in region.assignedRobots:
		var count: int = int(region.assignedRobots[robot])
		if count <= 0:
			continue
		var trash_per_sec: float = float(count) * float(robot.productionRate) * pollution_mult
		var per_unit_return: float = float(robot.resourceReturn)
		for entry in region.resourceChances:
			var key := entry.resource.to_lower()
			if not rates.has(key):
				continue
			rates[key] += trash_per_sec * float(entry.chance) * per_unit_return

	for child in production_grid.get_children():
		if child.name.ends_with("_rate"):
			var resource_name: String = child.name.replace("_rate", "")
			var rate: float = rates.get(resource_name, 0.0)
			child.text = "%s/S: %.2f" % [resource_name.capitalize(), rate]


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
		updateResourceRates(region)
		updatePollutionTrend(region)

@onready var region_pollution: TextureRect = $"Info/T&PContainer/Trash&Pollution/RegionPollution"
@onready var pollution_trend: Label = $"Info/T&PContainer/Trash&Pollution/PollutionTrend"
@export var pollutionAtlas: Texture2D
var pollutionIconSize := Vector2(44, 44)
var pollutionIconSpacing := 8


func updatePollution(region: RegionData):
	if pollutionAtlas == null:
		return
	var level := region.getPollutionLevel()
	var step := pollutionIconSize.x + pollutionIconSpacing
	
	var atlas := AtlasTexture.new()
	atlas.atlas = pollutionAtlas
	atlas.region = Rect2(step * int(level), 0, pollutionIconSize.x, pollutionIconSize.y)
	region_pollution.texture = atlas
	
	
	


func onPollutionUpdated(updated_region: RegionData):
	if updated_region != currentRegion:
		return
	updatePollution(updated_region)
	updatePollutionPopup(updated_region)
	# Production multiplier is bracket-based, so the displayed rates only need
	# to refresh when the level changes — not on every +1 pollution tick.
	var new_level := int(updated_region.getPollutionLevel())
	if new_level != currentPollutionLevel:
		currentPollutionLevel = new_level
		updateResourceRates(updated_region)
		updatePollutionTrend(updated_region)


# Net pollution per second this region accrues at the current robot assignment,
# while there is trash to process. Pollution is independent of productionRate
# and the pollution-level multiplier — each robot contributes its raw
# pollutionEffect/sec, with cleaner_scalar applied to negative effects.
func updatePollutionTrend(region: RegionData):
	var cleaner_scalar: float = TechTree.get_cleaner_strength_scalar()
	var rate := 0.0
	for robot in region.assignedRobots:
		var count: int = int(region.assignedRobots[robot])
		if count <= 0:
			continue
		var effect: float = robot.pollutionEffect
		if effect < 0.0:
			effect *= cleaner_scalar
		rate += float(count) * effect

	var sign_str := ""
	var color: Color
	if rate > 0.0:
		sign_str = "+"
		color = Color(1.0, 0.45, 0.45)
	elif rate < 0.0:
		color = Color(0.45, 1.0, 0.55)
	else:
		color = Color(0.7, 0.7, 0.7)

	pollution_trend.text = "%s%.1f/s" % [sign_str, rate]
	pollution_trend.add_theme_color_override("font_color", color)


@onready var pollution_level_label: Label = $"Info/T&PContainer/Trash&Pollution/RegionPollution/PollutionPopup/PopupMargin/PopupVbox/Level/PollutionLevelLabel"
@onready var pollution_popup: Panel = $"Info/T&PContainer/Trash&Pollution/RegionPollution/PollutionPopup"
@onready var pollution_progress: ProgressBar = $"Info/T&PContainer/Trash&Pollution/RegionPollution/PollutionPopup/PopupMargin/PopupVbox/PollutionDisplay/PollutionProgress"
@onready var pollution_progress_label: Label = $"Info/T&PContainer/Trash&Pollution/RegionPollution/PollutionPopup/PopupMargin/PopupVbox/PollutionDisplay/PollutionProgressLabel"
@onready var pollution_return_label: Label = $"Info/T&PContainer/Trash&Pollution/RegionPollution/PollutionPopup/PopupMargin/PopupVbox/Return/PollutionReturnLabel"


func _on_region_pollution_mouse_entered():
	pollution_popup.show()


func _on_region_pollution_mouse_exited():
	pollution_popup.hide()


func updatePollutionPopup(region: RegionData):
	var level := region.getPollutionLevel()
	var pollutionName := region.getPollutionName()
	
	pollution_level_label.text = str(pollutionName)
	pollution_level_label.add_theme_color_override("font_color", GlobalResources.getPollutionColor(level))
	
	pollution_progress.max_value = region.maxPollution
	pollution_progress.value = region.pollution
	
	pollution_progress_label.text = "%d / %d" % [region.pollution, region.maxPollution]
	
	pollution_return_label.text =str(GlobalResources.getPollutionProductionMultiplier(level)) + "x"
	pollution_return_label.add_theme_color_override("font_color", GlobalResources.getPollutionColor(level))


func _on_tab_clicked(tab: int): #Lets the "X" tab close the menu
	if tab == 3:
		if GlobalResources.pinnedRegion != null:
			GlobalSignals.regionPinToggled.emit(GlobalResources.pinnedRegion)
		hide()
