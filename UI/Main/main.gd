extends Control

# Coordinator for the top-level Main scene. Responsibilities:
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
#    holds Save, Reset, and (debug builds) dev godmode. Pause only stops
#    GameManager robot production (`production_paused`); the scene tree is
#    not frozen so UI stays usable. Spacebar toggles the same pause state.

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
@onready var building_ui: Control = $BuildingUI
@onready var buildings_button: Button = $BuildingsButton
@onready var pause_button: Button = $SaveHUDLayer/HudRoot/SaveStrip/PauseButton
@onready var menu_button: MenuButton = $SaveHUDLayer/HudRoot/SaveStrip/MenuButton
@onready var reset_confirm: ConfirmationDialog = $SaveHUDLayer/ResetConfirm


func _ready() -> void:
	robot_ui.panelOpened.connect(_on_robot_ui_opened)
	robot_ui.panelClosed.connect(_on_robot_ui_closed)
	tech_tree.panelOpened.connect(_on_tech_tree_opened)
	tech_tree.panelClosed.connect(_on_tech_tree_closed)
	building_ui.panelOpened.connect(_on_building_ui_opened)
	building_ui.panelClosed.connect(_on_building_ui_closed)

	pause_button.pressed.connect(_on_pause_pressed)
	var menu_popup: PopupMenu = menu_button.get_popup()
	menu_popup.id_pressed.connect(_on_menu_id_pressed)
	_rebuild_menu_strip()

	reset_confirm.confirmed.connect(_on_reset_confirmed)

	GlobalSignals.robotPanelRequested.connect(_on_robot_panel_requested)
	GlobalSignals.buildingPanelRequested.connect(_on_building_panel_requested)

	SaveGame.consume_post_reset_refresh()

	_refresh_pause_button_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_production_pause()
			get_viewport().set_input_as_handled()


func _toggle_production_pause() -> void:
	GameManager.production_paused = not GameManager.production_paused
	_refresh_pause_button_text()


func _refresh_pause_button_text() -> void:
	pause_button.text = "Resume" if GameManager.production_paused else "Pause"


func _on_pause_pressed() -> void:
	_toggle_production_pause()


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


# All three sub-menu trigger buttons get hidden together while any panel is
# open. Hiding (rather than just disabling) removes them from the z-stack so
# they can't render in front of the open panel and can't swallow clicks.
# Each panel owns its own close path (in-panel X / ESC), so the trigger
# buttons aren't needed while a panel is up.
func _set_menu_buttons_visible(v: bool) -> void:
	robots_button.visible = v
	research_button.visible = v
	buildings_button.visible = v


func _on_robot_ui_opened() -> void:
	_set_menu_buttons_visible(false)


func _on_robot_ui_closed() -> void:
	_set_menu_buttons_visible(true)


func _on_tech_tree_opened() -> void:
	_set_menu_buttons_visible(false)
	_set_planet_ui_visible(false)


func _on_tech_tree_closed() -> void:
	_set_menu_buttons_visible(true)
	_set_planet_ui_visible(true)


func _on_building_ui_opened() -> void:
	_set_menu_buttons_visible(false)


func _on_building_ui_closed() -> void:
	_set_menu_buttons_visible(true)


# Region info panel's Robots / Buildings tabs request that the matching
# inventory panel pop open on the right. If the *other* inventory panel is
# already open we close it first (mutual exclusion); if the requested panel
# is already open we leave it alone (clicking the tab again shouldn't toggle
# it shut). Tech tree isn't checked because EarthUI is hidden while the tree
# is open, so region tabs can't be clicked from that state.
func _on_robot_panel_requested() -> void:
	if robot_ui.visible:
		return
	if building_ui.visible:
		building_ui.toggle()
	robot_ui.toggle()


func _on_building_panel_requested() -> void:
	if building_ui.visible:
		return
	if robot_ui.visible:
		robot_ui.toggle()
	building_ui.toggle()


func _set_planet_ui_visible(v: bool) -> void:
	earth_ui.visible = v
	region_info_layer.visible = v
	globe.visible = v
