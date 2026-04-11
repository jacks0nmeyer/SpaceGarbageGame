extends HBoxContainer


@onready var upgrade_popup: PopupPanel = $"../../../../UpgradePopup"
@onready var upgrade_popup_label: Label = $"../../../../UpgradePopup/UpgradePopupLabel"
@onready var upgrade_2_cost: Label = $Upgrade2Cost


func _process(_delta):
	update_upgrade_text()


func update_upgrade_text(): #updates all text
	upgrade_2_cost.text = "Cost: \n " + str(EarthGlobal.upgrade2Cost) + " Junk"


func _on_mouse_entered(): #show upgrade description popup
	upgrade_popup_label.text = "A depot of robots that clean and harvest from the region they are placed in. \n You have "+ str(EarthGlobal.upgrade2Amount)+ "."
	upgrade_popup.show()
	
	
func _on_mouse_exited(): #hide upgrade description popup
	upgrade_popup.hide()
	

func _on_upgrade_2_buy_button_pressed(): 
	upgrade_popup.show() #button messes with the popup unfavorably
	
	if GlobalResources.junk >= EarthGlobal.upgrade2Cost:
		GlobalResources.junk -= EarthGlobal.upgrade2Cost
		
		EarthGlobal.upgrade2Cost *= 2
		EarthGlobal.upgrade2Amount += 1
		EarthGlobal.addBuilding()
