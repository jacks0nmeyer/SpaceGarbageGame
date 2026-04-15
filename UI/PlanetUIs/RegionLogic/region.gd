extends TextureButton
class_name Region

@export var region: RegionData
@onready var region_popup: Panel = %RegionPopup
@onready var region_popup_label: Label = %RegionPopupLabel

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
	
	
func _on_pressed():
	GlobalResources.regionGotResource(region)


func _on_mouse_entered(): 
	region_popup.show()
	region_popup_label.text = region.description


func _on_mouse_exited():
		region_popup.hide()
