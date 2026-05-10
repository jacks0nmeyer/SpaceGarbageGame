extends TabContainer

@onready var region_name: Label = $Info/RegionName
@onready var trash_bar: ProgressBar = $"Info/T&PContainer/StatusVBox/TrashSection/TrashDisplay/TrashBar"
@onready var trash_display: Label = $"Info/T&PContainer/StatusVBox/TrashSection/TrashDisplay/TrashDisplay"
@onready var trash_removal_trend: Label = $"Info/T&PContainer/StatusVBox/TrashSection/TrashRemovalTrend"
@onready var resource_grid: GridContainer = $"Info/T&PContainer/StatusVBox/PollutionSection/ResourceGrid"
@onready var production_grid: GridContainer = $"Info/T&PContainer/StatusVBox/PollutionSection/ProductionGrid"
@onready var region_description: Label = $"Info/DescContainer/Region Description"
@onready var robots_region_name: Label = $Robots/Margin/Vbox/RegionNameLabel
@onready var slots_label: Label = $Robots/Margin/Vbox/SlotsLabel
@onready var assigned_rows: VBoxContainer = $Robots/Margin/Vbox/Scroll/Rows
@onready var empty_label: Label = $Robots/Margin/Vbox/EmptyLabel
@onready var buildings_region_name: Label = $Buildings/Margin/Vbox/RegionNameLabel
@onready var building_slots_label: Label = $Buildings/Margin/Vbox/SlotsLabel
@onready var building_rows: VBoxContainer = $Buildings/Margin/Vbox/Scroll/Rows
@onready var building_empty_label: Label = $Buildings/Margin/Vbox/EmptyLabel

# Idle-fade: panel quietly fades out when the player is just glancing past
# regions and isn't doing anything that would care about info. Any "activity"
# (region hover, mouse on panel, sub-menu interaction, drag-drop) resets the
# countdown. Pin overrides everything — pinned panels never fade.
const IDLE_TIMEOUT_S: float = 3.0
const FADE_DURATION_S: float = 0.4

var _idle_timer: Timer
var _fade_tween: Tween
var _robot_ui_ref: Control
var _building_ui_ref: Control
var _mouse_inside: bool = false


func _ready():
	GlobalSignals.regionHovered.connect(onRegionHovered)
	GlobalSignals.regionTrashUpdated.connect(_on_region_trash_updated)
	GlobalSignals.robotAssigned.connect(_on_robot_pair_changed)
	GlobalSignals.robotUnassigned.connect(_on_robot_pair_changed)
	GlobalSignals.regionPinToggled.connect(_on_pin_toggled)
	GlobalSignals.regionPollutionUpdated.connect(onPollutionUpdated)
	GlobalSignals.techUnlocked.connect(_on_tech_changed)
	GlobalSignals.saveLoaded.connect(_on_save_loaded)
	GlobalSignals.buildingAssigned.connect(_on_building_pair_changed)
	GlobalSignals.buildingUnassigned.connect(_on_building_pair_changed)
	GlobalSignals.buildingStorageUpdated.connect(_on_building_storage_updated)
	GlobalSignals.buildingWorkerAssigned.connect(_on_building_worker_changed)
	GlobalSignals.buildingWorkerUnassigned.connect(_on_building_worker_changed)
	GlobalSignals.robotPurchased.connect(_on_robot_purchased)
	var bar := get_tab_bar()
	if bar:
		bar.clip_tabs = false
		bar.add_theme_font_size_override(&"font_size", 15)
	hide()

	_idle_timer = Timer.new()
	_idle_timer.one_shot = true
	_idle_timer.wait_time = IDLE_TIMEOUT_S
	_idle_timer.timeout.connect(_on_idle_timeout)
	add_child(_idle_timer)

	mouse_entered.connect(_on_panel_mouse_entered)
	mouse_exited.connect(_on_panel_mouse_exited)
	visibility_changed.connect(_on_visibility_changed)

	# Cache the right-side inventory panels so the timeout check can defer
	# fading while the player has either of them open.
	var main_node: Node = get_tree().root.get_node_or_null("Main")
	if main_node != null:
		_robot_ui_ref = main_node.get_node_or_null("RobotUI")
		_building_ui_ref = main_node.get_node_or_null("BuildingUI")

	GlobalSignals.robotPanelRequested.connect(_kick_idle_timer)
	GlobalSignals.buildingPanelRequested.connect(_kick_idle_timer)
	GlobalSignals.regionClicked.connect(_on_region_clicked)


func _on_tech_changed(_tech: TechData) -> void:
	if visible and currentRegion != null:
		updateTrashRemovalRate(currentRegion)
		updateResourceRates(currentRegion)


func _on_save_loaded() -> void:
	if visible and currentRegion != null:
		_switch_to(currentRegion)


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
	_kick_idle_timer()


func _switch_to(region: RegionData):
	currentRegion = region
	currentPollutionLevel = int(region.getPollutionLevel())
	updateInfo(region)
	updateResources(region)
	updateResourceRates(region)
	updateProgress(region)
	updateRobots(region)
	updateBuildings(region)
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
			_kick_idle_timer()
			return
	_refresh_pin_indicator()
	_kick_idle_timer()


func _refresh_pin_indicator():
	if currentRegion == null:
		return
	var prefix := ""
	if GlobalResources.pinnedRegion == currentRegion:
		prefix = "📌 "
	var display_name := prefix + currentRegion.regionName
	region_name.text = display_name
	robots_region_name.text = display_name
	buildings_region_name.text = display_name


func updateInfo(region: RegionData):
	_refresh_pin_indicator()
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
	# Robot count change (anywhere) affects every visible building's
	# "+ button" availability — refresh worker rows in the current region.
	if currentRegion != null:
		_refresh_all_building_workers()
	_kick_idle_timer()


# Rebuild the assigned-building rows (called on region switch or whenever the
# building composition changes — buildingAssigned / buildingUnassigned).
func updateBuildings(region: RegionData):
	for child in building_rows.get_children():
		building_rows.remove_child(child)
		child.queue_free()

	var used := region.assignedBuildingSlotsUsed()
	building_slots_label.text = "Slots: %d / %d" % [used, region.building_capacity]

	var any := false
	for b in region.assignedBuildings:
		var count: int = int(region.assignedBuildings[b])
		if count <= 0:
			continue
		any = true
		var row := AssignedBuildingRow.new()
		row.name = "row_" + b.resource_path.get_file().get_basename()
		building_rows.add_child(row)
		row.setup(b, region, count)

	building_empty_label.visible = not any


func _on_building_pair_changed(_b: BuildingData, region: RegionData):
	if region == currentRegion:
		updateBuildings(region)
	_kick_idle_timer()


func _on_building_storage_updated(region: RegionData, b: BuildingData):
	if region != currentRegion:
		return
	# In-place refresh — don't rebuild rows (storage signals fire often).
	for child in building_rows.get_children():
		if child is AssignedBuildingRow and child.building == b:
			child.refresh_storage()
			return


func _on_building_worker_changed(_robot: RobotData, region: RegionData, b: BuildingData):
	if region != currentRegion:
		return
	# A worker change for THIS building updates that row, but every row's
	# "+ button" availability depends on global unassignedCount, so refresh
	# all rows' worker controls.
	for child in building_rows.get_children():
		if child is AssignedBuildingRow:
			if child.building == b:
				child.refresh_workers()
			else:
				child.refresh_workers()


func _on_robot_purchased(_robot: RobotData) -> void:
	# A new robot enters the unassigned pool — refresh "+" availability.
	if currentRegion != null:
		_refresh_all_building_workers()


func _refresh_all_building_workers() -> void:
	for child in building_rows.get_children():
		if child is AssignedBuildingRow:
			child.refresh_workers()

@onready var region_pollution: TextureRect = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionFaceRow/RegionPollution"
@onready var pollution_value_left: Label = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionValuesRow/PollutionValueLeft"
@onready var pollution_value_right: Label = $"Info/T&PContainer/StatusVBox/PollutionSection/PollutionValuesRow/PollutionValueRight"
@export var pollutionAtlas: Texture2D
var pollutionIconSize := Vector2(76, 48)
var pollutionIconSpacing := 20


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
	pollution_value_right.text = "Pollution/s: %s" % rate_str
	pollution_value_right.add_theme_color_override("font_color", tr_color)


func updatePollutionDetails(region: RegionData) -> void:
	pollution_progress.max_value = region.maxPollution
	pollution_progress.value = region.pollution
	if pollution_progress_label != null:
		pollution_progress_label.text = "%d / %d" % [region.pollution, region.maxPollution]
	if pollution_display != null:
		pollution_display.tooltip_text = "%s tier — return multiplier applies to debris processed here." % region.getPollutionName()
	_refresh_pollution_value_row(region)


func _on_tab_clicked(tab: int):
	# Tab 1 (Robots) / 2 (Buildings) auto-open their right-side inventory
	# panel so the drag source is visible alongside the drop target. The
	# panel stays open after the player switches back to Info — they close
	# it explicitly via its own X.
	# Tab 3 ("X") closes this whole panel and unpins.
	if tab == 1:
		GlobalSignals.robotPanelRequested.emit()
	elif tab == 2:
		GlobalSignals.buildingPanelRequested.emit()
	elif tab == 3:
		if GlobalResources.pinnedRegion != null:
			GlobalSignals.regionPinToggled.emit(GlobalResources.pinnedRegion)
		hide()
	_kick_idle_timer()


# --- Idle fade ---------------------------------------------------------------

func _on_region_clicked(_pos: Vector2) -> void:
	_kick_idle_timer()


func _kick_idle_timer() -> void:
	# Any sign of activity bumps the countdown to a fresh IDLE_TIMEOUT_S and
	# snaps any in-progress fade back to fully opaque.
	_cancel_fade()
	if not is_visible_in_tree():
		return
	if currentRegion != null and GlobalResources.pinnedRegion == currentRegion:
		_idle_timer.stop()
		return
	_idle_timer.start()


func _cancel_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	modulate.a = 1.0


func _on_idle_timeout() -> void:
	# If anything still counts as "in use" when the countdown expires, just
	# kick it again — no need to fade now.
	if not is_visible_in_tree():
		return
	if currentRegion != null and GlobalResources.pinnedRegion == currentRegion:
		return
	if _mouse_inside:
		_idle_timer.start()
		return
	if (_robot_ui_ref != null and _robot_ui_ref.visible) \
			or (_building_ui_ref != null and _building_ui_ref.visible):
		_idle_timer.start()
		return
	_fade_out()


func _fade_out() -> void:
	_cancel_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION_S)
	_fade_tween.tween_callback(_on_fade_finished)


func _on_fade_finished() -> void:
	hide()
	modulate.a = 1.0
	_fade_tween = null


func _on_panel_mouse_entered() -> void:
	_mouse_inside = true
	_cancel_fade()
	_idle_timer.stop()


func _on_panel_mouse_exited() -> void:
	_mouse_inside = false
	_kick_idle_timer()


func _on_visibility_changed() -> void:
	if visible:
		_kick_idle_timer()
	else:
		_idle_timer.stop()
		_cancel_fade()
