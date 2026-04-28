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

@onready var background: Panel = $Background
@onready var globe: TextureRect = $Background/GlobeTexture
@onready var earth_ui: Control = $EarthUI
@onready var region_info_layer: CanvasLayer = $EarthUI/RegionInformationLayer
@onready var robot_ui: Control = $RobotUI
@onready var robots_button: Button = $RobotsButton
@onready var tech_tree: Control = $TechTree
@onready var research_button: Button = $ResearchButton


func _ready() -> void:
	robot_ui.panelOpened.connect(_on_robot_ui_opened)
	robot_ui.panelClosed.connect(_on_robot_ui_closed)
	tech_tree.panelOpened.connect(_on_tech_tree_opened)
	tech_tree.panelClosed.connect(_on_tech_tree_closed)


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
