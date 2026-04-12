extends Control
@onready var tech_popup: PopupPanel = $TechPopup


func _on_background_mouse_entered():
	tech_popup.hide()
