extends TextureRect

@export var planet: PlanetData
@export var pollution_atlas: Texture2D
var icon_size := Vector2(76, 48)
var icon_spacing := 20

func _ready():
	GlobalSignals.planet_pollution_updated.connect(on_planet_pollution_updated)
	update_pollution()
	update_pollution_popup()
	pollution_popup.hide()

func update_pollution():
	if pollution_atlas == null or planet == null:
		return
	var level :=  planet.get_pollution_level()
	var step := icon_size.x + icon_spacing
	var atlas := AtlasTexture.new()
	atlas.atlas =  pollution_atlas
	atlas.region = Rect2(step * int(level), 0, icon_size.x, icon_size.y)
	texture = atlas
	
	
func on_planet_pollution_updated(updated_planet: PlanetData):
	if updated_planet == planet:
		update_pollution()
		update_pollution_popup()


@onready var pollution_popup: Panel = $PollutionPopup
@onready var pollution_level_label: Label = $PollutionPopup/PopupMargin/PopupVbox/Level/PollutionLevelLabel
@onready var pollution_progress: ProgressBar = $PollutionPopup/PopupMargin/PopupVbox/PollutionDisplay/PollutionProgress
@onready var pollution_progress_label: Label = $PollutionPopup/PopupMargin/PopupVbox/PollutionDisplay/PollutionProgressLabel
@onready var pollution_return_label: Label = $PollutionPopup/PopupMargin/PopupVbox/Return/PollutionReturnLabel


func update_pollution_popup():
	var level := planet.get_pollution_level()
	var pollution_name := planet.get_pollution_name()
	
	pollution_level_label.text = str(pollution_name)
	pollution_level_label.add_theme_color_override("font_color", GlobalResources.get_pollution_color(level))
	
	pollution_progress.max_value = planet.get_total_max_pollution()
	pollution_progress.value = planet.get_total_pollution()
	
	pollution_progress_label.text = "%d / %d" % [planet.get_total_pollution(), planet.get_total_max_pollution()]
	
	pollution_return_label.text =str(GlobalResources.get_pollution_production_multiplier(level)) + "x"
	pollution_return_label.add_theme_color_override("font_color", GlobalResources.get_pollution_color(level))


func _on_mouse_entered() :
	pollution_popup.show()


func _on_mouse_exited() :
	pollution_popup.hide()
