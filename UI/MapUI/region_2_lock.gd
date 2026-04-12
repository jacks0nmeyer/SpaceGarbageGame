extends TextureButton


@onready var region_popup: PopupPanel = $"../RegionPopup"
@onready var region_popup_label: Label = $"../RegionPopup/RegionPopupLabel"
@onready var region_2_lock: TextureButton = $"."
@onready var region_2: TextureButton = $"../Region2"




func _on_pressed():
	if GlobalResources.junk >= 5000:
		GlobalResources.junk -= 5000
		region_2.disabled = false
	else:
		pass
		

func _on_mouse_entered():
	region_popup.show()
	region_popup_label.text = "Unlock for 5,000 junk?"











func _ready(): #Creates a click mask for the button
	if texture_normal:
		var image = texture_normal.get_image() # Get the image from the texture normal
		var bitmap = BitMap.new() # Create the BitMap
		bitmap.create_from_image_alpha(image) # Fill it from the image alpha
		texture_click_mask = bitmap # Assign it to the mask
