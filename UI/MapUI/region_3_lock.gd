extends TextureButton

@onready var region_popup: PopupPanel = $"../RegionPopup"
@onready var region_popup_label: Label = $"../RegionPopup/RegionPopupLabel"
@onready var region_3_lock: TextureButton = $"."


func _on_pressed():
	pass

	
func _on_mouse_entered():
	region_popup.show()
	region_popup_label.text = "Unlock for 10,000 scrap?"











func _ready(): #Creates a click mask for the button
	if texture_normal:
		var image = texture_normal.get_image() # Get the image from the texture normal
		var bitmap = BitMap.new() # Create the BitMap
		bitmap.create_from_image_alpha(image) # Fill it from the image alpha
		texture_click_mask = bitmap # Assign it to the mask
