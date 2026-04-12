extends TextureButton

@onready var region_popup: PopupPanel = $"../RegionPopup"
@onready var region_popup_label: Label = $"../RegionPopup/RegionPopupLabel"


func _on_pressed():
	region_popup.show() #need to find solution for popup vanishing on button press
	if randf() < 0.9:
		GlobalResources.gotJunk(EarthGlobal.trashGrabberPower)
	else:
		GlobalResources.gotScrap()
	
	print("Junk= " + str(GlobalResources.junk) + " & Earth Trash = " + str(EarthGlobal.earthTrash))
	

func _on_mouse_entered(): 
	region_popup.show()
	region_popup_label.text = "A standard region full of trash.\n Base resource chance: 90% Junk, 10% Scrap."


func _on_map_ui_mouse_entered():
	region_popup.hide()









func _ready(): #Creates a click mask for the button
	if texture_normal:
		var image = texture_normal.get_image() # Get the image from the texture normal
		var bitmap = BitMap.new() # Create the BitMap
		bitmap.create_from_image_alpha(image) # Fill it from the image alpha
		texture_click_mask = bitmap # Assign it to the mask
