extends HBoxContainer

@onready var upgrade_popup: PopupPanel = $"../../../../UpgradePopup"
@onready var upgrade_popup_label: Label = $"../../../../UpgradePopup/UpgradePopupLabel"
@onready var upgrade_1_cost: Label = $Upgrade1Cost

func _process(_delta):
	update_upgrade_text()


func update_upgrade_text(): #updates all text
	upgrade_1_cost.text = "Cost: \n " + str(EarthGlobal.upgrade1Cost) + " Junk"


func _on_mouse_entered(): #show upgrade description popup
	upgrade_popup_label.text = "Increases your trash grabbing power by 1 per click. \n You have "+ str(EarthGlobal.upgrade1Amount)+ "."
	upgrade_popup.show()
	
	
func _on_mouse_exited(): #hide upgrade description popup
	upgrade_popup.hide()
	

func _on_upgrade_1_buy_button_pressed(): 
	upgrade_popup.show() #button messes with the popup unfavorably
	
	if GlobalResources.junk >= EarthGlobal.upgrade1Cost:
		GlobalResources.junk -= EarthGlobal.upgrade1Cost
		EarthGlobal.trashGrabberPower += 1
		@warning_ignore("narrowing_conversion")
		EarthGlobal.upgrade1Cost *= 1.5
		EarthGlobal.upgrade1Amount += 1
	else: 
		pass
		
