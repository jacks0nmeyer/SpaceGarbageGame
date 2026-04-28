extends Control

# Coordinator for the top-level Main scene. Two responsibilities:
#
# 1. Hide the planet UI (EarthUI + its CanvasLayer-hosted region popup + the
#    static globe sprite) while the tech tree panel is open, so the tree
#    renders on a clean canvas. Hiding EarthUI alone is not enough because
#    its RegionInformationLayer is a CanvasLayer, which sits on its own
#    rendering layer and ignores the parent Control's visibility.
#
# 2. Mutually disable the Robots and Research buttons while the other panel
#    is open, so opening one cannot stack a second panel on top. The button
#    matching the currently-open panel still hides itself (the in-panel X /
#    ESC are the canonical close paths); the *other* button stays visible
#    but non-interactive.
#
# 3. Pause + Menu live on SaveHUDLayer (CanvasLayer layer 50) so they stay
#    above EarthUI's RegionInformationLayer and anchor bottom-left. Menu
#    holds Save, Reset, and (debug builds) dev godmode.

const MENU_ID_SAVE := 0
const MENU_ID_RESET := 1
const MENU_ID_DEV_GODMODE := 2

@onready var background: Panel = $Background
@onready var globe: TextureRect = $Background/GlobeTexture
@onready var earth_ui: Control = $EarthUI
@onready var region_info_layer: CanvasLayer = $EarthUI/RegionInformationLayer
@onready var robot_ui: Control = $RobotUI
@onready var robots_button: Button = $RobotsButton
@onready var tech_tree: Control = $TechTree
@onready var research_button: Button = $ResearchButton
@onready var pause_button: Button = $SaveHUDLayer/HudRoot/SaveStrip/PauseButton
@onready var menu_button: MenuButton = $SaveHUDLayer/HudRoot/SaveStrip/MenuButton
@onready var reset_confirm: ConfirmationDialog = $SaveHUDLayer/ResetConfirm


func _ready() -> void:
	robot_ui.panelOpened.connect(_on_robot_ui_opened)
	robot_ui.panelClosed.connect(_on_robot_ui_closed)
	tech_tree.panelOpened.connect(_on_tech_tree_opened)
	tech_tree.panelClosed.connect(_on_tech_tree_closed)

	pause_button.pressed.connect(_on_pause_pressed)
	var menu_popup: PopupMenu = menu_button.get_popup()
	menu_popup.id_pressed.connect(_on_menu_id_pressed)
	_rebuild_menu_strip()

	reset_confirm.confirmed.connect(_on_reset_confirmed)

	SaveGame.consume_post_reset_refresh()


func _on_pause_pressed() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "Resume" if get_tree().paused else "Pause"


func _rebuild_menu_strip() -> void:
	var menu_popup: PopupMenu = menu_button.get_popup()
	menu_popup.clear()
	menu_popup.add_item("Save now", MENU_ID_SAVE)
	menu_popup.add_item("Reset game…", MENU_ID_RESET)
	if OS.is_debug_build():
		menu_popup.add_separator()
		menu_popup.add_item("Dev: max resources", MENU_ID_DEV_GODMODE)


func _on_menu_id_pressed(id: int) -> void:
	match id:
		MENU_ID_SAVE:
			SaveGame.save_to_user()
		MENU_ID_RESET:
			reset_confirm.popup_centered()
		MENU_ID_DEV_GODMODE:
			if OS.is_debug_build():
				GlobalResources.apply_dev_godmode_inventory()


func _on_reset_confirmed() -> void:
	SaveGame.reset_to_new_game()


func _on_robot_ui_opened() -> void:
	robots_button.hide()
	research_button.disabled = true


func _on_robot_ui_closed() -> void:
	robots_button.show()
	research_button.disabled = false


func _on_tech_tree_opened() -> void:
	research_button.hide()
	robots_button.disabled = true
	_set_planet_ui_visible(false)


func _on_tech_tree_closed() -> void:
	research_button.show()
	robots_button.disabled = false
	_set_planet_ui_visible(true)


func _set_planet_ui_visible(v: bool) -> void:
	earth_ui.visible = v
	region_info_layer.visible = v
	globe.visible = v
