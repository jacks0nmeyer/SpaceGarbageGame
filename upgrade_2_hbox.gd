extends HBoxContainer


@onready var upgrade_popup: PopupPanel = $"../../../../../UpgradePopup"
@onready var upgrade_popup_label: Label = $"../../../../../UpgradePopup/UpgradePopupLabel"
@onready var upgrade_2_cost: Label = $Upgrade2Cost
var timerActive := false
@onready var upgrade_2_timer: Timer = $Upgrade2Timer
@onready var upgrade_2_prog: ProgressBar = $".."
var fill_rate = 0.1


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
		if not timerActive:
			timerActive = true
			upgrade_2_timer.start()


func _on_timer_timeout() -> void:
	upgrade_2_prog.value += fill_rate
	if upgrade_2_prog.value >= upgrade_2_prog.max_value:
		upgrade_2_prog.value = 0.0
		# trigger whatever happens when bar completes (e.g. collect garbage)
		GlobalResources.gotJunk(5)
