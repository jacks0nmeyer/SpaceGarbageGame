extends HBoxContainer

@onready var popup_panel: PopupPanel = $"../../../../PopUp/PopupPanel"


func _on_mouse_entered():
	popup_panel.show()
