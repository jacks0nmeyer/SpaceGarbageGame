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
	
	GlobalSignals.regionUnlocked.connect(onRegionUnlock)


func onRegionUnlock(current_region: RegionData):
	if current_region == region:
		unlock()


func unlock():
	self.disabled = false
	if region != null:
		region.locked = false
	
	
func _on_pressed():
	GlobalResources.regionGotResource(region, planet)


func _on_mouse_entered(): 
	GlobalSignals.regionHovered.emit(region)


# TextureButton's pressed signal is left-click only by default. Capture
# right-clicks here for pin/unpin of the region info panel. The pixel-perfect
# texture_click_mask still restricts which pixels fire _gui_input.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		GlobalSignals.regionPinToggled.emit(region)
		accept_event()


# Drag-drop assignment. Payload shape:
#   {"robot": RobotData, "from_region": RegionData|null}
# A null from_region means the drag came from the Owned tab. A non-null
# from_region means the player is moving an already-assigned robot from one
# region to another; we decrement the source before incrementing here.
func _can_drop_data(_pos: Vector2, data) -> bool:
	if region == null or region.locked:
		return false
	# While a region is pinned, only that region accepts drops.
	if GlobalResources.pinnedRegion != null and GlobalResources.pinnedRegion != region:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("robot") or not data.has("from_region"):
		return false
	var robot = data["robot"]
	if not (robot is RobotData):
		return false
	var from_region = data["from_region"]
	if from_region == region:
		return false
	if from_region == null:
		if GlobalResources.unassignedCount(robot) <= 0:
			return false
	return region.canFit(robot)


func _drop_data(_pos: Vector2, data) -> void:
	GlobalResources.assignOne(data["robot"], region, data["from_region"])
