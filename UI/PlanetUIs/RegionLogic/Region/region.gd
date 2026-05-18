extends TextureButton
class_name Region

@export var region: RegionData
@export var planet: PlanetData


func _ready(): 
	texture_normal = region.texture_normal #assigns textures from resource
	texture_hover = region.texture_hover
	texture_disabled = region.texture_disabled
	
	if texture_normal: #Matches button size to region texture
		var image = texture_normal.get_image()
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(image)
		texture_click_mask = bitmap
		
	if region.locked == true:
		self.disabled = true
	
	GlobalSignals.region_unlocked.connect(on_region_unlock)
	GlobalSignals.save_loaded.connect(_on_save_loaded)


func on_region_unlock(current_region: RegionData):
	if current_region == region:
		unlock()


func _on_save_loaded() -> void:
	if region != null:
		self.disabled = region.locked


func unlock():
	self.disabled = false
	if region != null:
		region.locked = false
	
	
func _on_pressed():
	# Re-emit hover so the info panel re-opens if it had faded out while the
	# cursor sat on this region (mouse_entered only fires on actual entry).
	GlobalSignals.region_hovered.emit(region)
	GlobalSignals.region_clicked.emit(get_viewport().get_mouse_position())
	var amount: int = TechTree.get_click_trash_amount()
	var double_resources: bool = randf() < TechTree.get_click_double_chance()
	GlobalResources.region_got_resource(region, planet, amount, double_resources)
	var pollution_bonus: int = TechTree.get_click_pollution_bonus()
	if pollution_bonus != 0 and region.pollution > 0:
		var new_pollution: int = clamp(region.pollution + pollution_bonus, 0, region.max_pollution)
		if new_pollution != region.pollution:
			region.pollution = new_pollution
			GlobalSignals.region_pollution_updated.emit(region)
			GlobalSignals.planet_pollution_updated.emit(planet)


func _on_mouse_entered(): 
	GlobalSignals.region_hovered.emit(region)


# TextureButton's pressed signal is left-click only by default. Capture
# right-clicks here for pin/unpin of the region info panel. The pixel-perfect
# texture_click_mask still restricts which pixels fire _gui_input.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		GlobalSignals.region_pin_toggled.emit(region)
		accept_event()


# Drag-drop assignment. Two payload shapes are accepted:
#   {"robot":    RobotData,    "from_region": RegionData|null}
#   {"building": BuildingData, "from_region": RegionData|null}
# A null from_region means the drag came from the corresponding Owned tab.
# A non-null from_region means the player is moving an already-assigned
# robot/building from one region to another; the source is decremented inside
# GlobalResources.assign_one / assign_one_building.
func _can_drop_data(_pos: Vector2, data) -> bool:
	if region == null or region.locked:
		return false
	# While a region is pinned, only that region accepts drops.
	if GlobalResources.pinned_region != null and GlobalResources.pinned_region != region:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("from_region"):
		return false
	var from_region = data["from_region"]
	if from_region == region:
		return false
	if data.has("robot") and data["robot"] is RobotData:
		var robot: RobotData = data["robot"]
		if from_region == null and GlobalResources.unassigned_count(robot) <= 0:
			return false
		return region.can_fit(robot)
	if data.has("building") and data["building"] is BuildingData:
		var b: BuildingData = data["building"]
		if from_region == null and GlobalResources.unassigned_building_count(b) <= 0:
			return false
		return region.can_fit_building(b)
	return false


func _drop_data(_pos: Vector2, data) -> void:
	if data.has("robot"):
		GlobalResources.assign_one(data["robot"], region, data["from_region"])
	elif data.has("building"):
		GlobalResources.assign_one_building(data["building"], region, data["from_region"])
