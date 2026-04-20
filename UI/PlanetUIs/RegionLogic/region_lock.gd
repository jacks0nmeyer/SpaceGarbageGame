extends TextureButton
class_name RegionLock

@export var unlockCost: Array[CostEntry] = []
@export var region: RegionData
@onready var popup: Panel = %"RegionPopup (Temp)"
@onready var popup_label: Label = %RegionPopupLabel


func cost_dict() -> Dictionary:
	var dict := {}
	for entry in unlockCost:
		dict[entry.resource] = entry.amount
	return dict
	

func _on_pressed():
	if GlobalResources.purchase(cost_dict()): #purchases if you can afford
		GlobalSignals.regionUnlocked.emit(region)
		self.queue_free()


func _on_mouse_entered():
	popup.show()
	popup_label.text = region.lockedDescription


func _on_mouse_exited():
		popup.hide()


func _ready():
	
	if texture_normal: #Matches button size to region texture
		var image = texture_normal.get_image()
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(image)
		texture_click_mask = bitmap
