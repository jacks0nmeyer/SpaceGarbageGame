extends TabContainer

@onready var region_name: Label = $Info/RegionName
@onready var trash_bar: ProgressBar = $"Info/T&PContainer/StatusVBox/TrashSection/TrashDisplay/TrashBar"
@onready var trash_display: Label = $"Info/T&PContainer/StatusVBox/TrashSection/TrashDisplay/TrashDisplay"
@onready var trash_removal_trend: Label = $"Info/T&PContainer/StatusVBox/TrashSection/TrashRemovalTrend"
@onready var resource_grid: GridContainer = $"Info/T&PContainer/StatusVBox/PollutionSection/ResourceGrid"
@onready var production_grid: GridContainer = $"Info/T&PContainer/StatusVBox/PollutionSection/ProductionGrid"
@onready var region_description: Label = $"Info/DescContainer/Region Description"
@onready var slots_label: Label = $Robots/Margin/Vbox/SlotsLabel
@onready var assigned_rows: VBoxContainer = $Robots/Margin/Vbox/Scroll/Rows
@onready var empty_label: Label = $Robots/Margin/Vbox/EmptyLabel


func _ready():
	GlobalSignals.regionHovered.connect(onRegionHovered)
	GlobalSignals.regionTrashUpdated.connect(_on_region_trash_updated)
	GlobalSignals.robotAssigned.connect(_on_robot_pair_changed)
	GlobalSignals.robotUnassigned.connect(_on_robot_pair_changed)
	GlobalSignals.regionPinToggled.connect(_on_pin_toggled)
	GlobalSignals.regionPollutionUpdated.connect(onPollutionUpdated)
	GlobalSignals.techUnlocked.connect(_on_tech_changed)
	var bar := get_tab_bar()
	if bar:
		bar.clip_tabs = false
		bar.add_theme_font_size_override(&"font_size", 15)
	hide()


func _on_tech_changed(_tech: TechData) -> void:
	if visible and currentRegion != null:
		updateTrashRemovalRate(currentRegion)
		updateResourceRates(currentRegion)


func _on_region_trash_updated(region: RegionData) -> void:
	updateProgress(region)
	if region != currentRegion:
		return
	updateTrashRemovalRate(region)


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
	updateTrashRemovalRate(region)
	updatePollutionDetails(region)


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
			var res_name: String = entry.resource.capitalize()
			var label := Label.new()
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			label.text = "%s: %d%%" % [res_name, int(entry.chance * 100.0 + 0.5)]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			resource_grid.add_child(label)

			var rate_label := Label.new()
			rate_label.name = entry.resource.to_lower() + "_rate"
			rate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rate_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			rate_label.text = "%s: 0.00/s" % res_name
			rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			production_grid.add_child(rate_label)
			
			limit += 1
 

# Deterministic per-region resource rate. Each robot picks one resource per
# trash unit weighted by region.resourceChances, then deposits resourceReturn
# of it; expected per-second contribution of robot R to resource X is
# count * productionRate * global_mult * chance(X) * resourceReturn(R).
# Updated only when robot composition or relevant tech/pollution tier changes — not each frame.
func updateResourceRates(region: RegionData):
	var rates: Dictionary = {}
	for entry in region.resourceChances:
		rates[entry.resource.to_lower()] = 0.0

	var pollution_mult: float = GlobalResources.getPollutionProductionMultiplier(region.getPollutionLevel())
	var global_mult: float = TechTree.get_global_production_multiplier()
	for robot in region.assignedRobots:
		var count: int = int(region.assignedRobots[robot])
		if count <= 0:
			continue
		var trash_per_sec: float = float(count) * float(robot.productionRate) * pollution_mult * global_mult
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
			var cap: String = resource_name.capitalize()
			child.text = "%s: %.2f/s" % [cap, rate]


# Trash units cleared/sec from assigned robots — matches GameManager progress
# while debris remains; zeros out when trash is depleted.
func updateTrashRemovalRate(region: RegionData) -> void:
	if trash_removal_trend == null:
		return
	if region.trash <= 0 or region.assignedRobots.is_empty():
		trash_removal_trend.text = "Clearance: 0/s"
		trash_removal_trend.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		return

	var pollution_mult: float = GlobalResources.getPollutionProductionMultiplier(region.getPollutionLevel())
	var global_mult: float = TechTree.get_global_production_multiplier()
	var rate := 0.0
	for robot in region.assignedRobots:
		var count: int = int(region.assignedRobots[robot])
		if count <= 0:
			continue
		rate += float(count) * float(robot.productionRate) * pollution_mult * global_mult

	trash_removal_trend.text = "Clearance: %.1f/s" % rate
	trash_removal_trend.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))


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
		updateTrashRemovalRate(region)

@onready var region_pollution: TextureRect = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionFaceRow/RegionPollution"
@onready var pollution_value_left: Label = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionValuesRow/PollutionValueLeft"
@onready var pollution_value_right: Label = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionValuesRow/PollutionValueRight"
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
	updatePollutionDetails(updated_region)
	# Production multiplier is bracket-based, so the displayed rates only need
	# to refresh when the level changes — not on every +1 pollution tick.
	var new_level := int(updated_region.getPollutionLevel())
	if new_level != currentPollutionLevel:
		currentPollutionLevel = new_level
		updateResourceRates(updated_region)
		updatePollutionTrend(updated_region)
		updateTrashRemovalRate(updated_region)


# Net pollution per second from assigned robots (while trash remains). Refreshes
# the value row under the pollution bar together with return multiplier.
func updatePollutionTrend(region: RegionData) -> void:
	_refresh_pollution_value_row(region)


@onready var pollution_display: Control = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionDisplay"
@onready var pollution_progress: ProgressBar = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionDisplay/PollutionProgress"
@onready var pollution_progress_label: Label = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionDisplay/PollutionProgressLabel"


func _refresh_pollution_value_row(region: RegionData) -> void:
	if pollution_value_left == null or pollution_value_right == null:
		return

	var level := region.getPollutionLevel()
	var mult: float = GlobalResources.getPollutionProductionMultiplier(level)
	var mult_str: String = str(mult) + "x"
	pollution_value_left.text = "Return: %s" % mult_str
	pollution_value_left.add_theme_color_override("font_color", GlobalResources.getPollutionColor(level))

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
	var tr_color: Color
	if rate > 0.0:
		sign_str = "+"
		tr_color = Color(1.0, 0.45, 0.45)
	elif rate < 0.0:
		tr_color = Color(0.45, 1.0, 0.55)
	else:
		tr_color = Color(0.75, 0.78, 0.82)

	var rate_str: String = "%s%.1f/s" % [sign_str, rate]
	pollution_value_right.text = "Poll/s: %s" % rate_str
	pollution_value_right.add_theme_color_override("font_color", tr_color)


func updatePollutionDetails(region: RegionData) -> void:
	pollution_progress.max_value = region.maxPollution
	pollution_progress.value = region.pollution
	if pollution_progress_label != null:
		pollution_progress_label.text = "%d / %d" % [region.pollution, region.maxPollution]
	if pollution_display != null:
		pollution_display.tooltip_text = "%s tier — return multiplier applies to debris processed here." % region.getPollutionName()
	_refresh_pollution_value_row(region)


func _on_tab_clicked(tab: int): #Lets the "X" tab close the menu
	if tab == 3:
		if GlobalResources.pinnedRegion != null:
			GlobalSignals.regionPinToggled.emit(GlobalResources.pinnedRegion)
		hide()
