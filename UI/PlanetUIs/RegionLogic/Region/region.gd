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
	region.locked = false
	
	
func _on_pressed():
	GlobalResources.regionGotResource(region, planet)


func _on_mouse_entered(): 
	GlobalSignals.regionHovered.emit(region)
