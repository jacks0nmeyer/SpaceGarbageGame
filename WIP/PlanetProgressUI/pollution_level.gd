extends TextureRect

@export var planet: PlanetData
@export var pollutionAtlas: Texture2D
var iconSize := Vector2(76, 48)
var iconSpacing := 20

func _ready():
	GlobalSignals.planetPollutionUpdated.connect(onPlanetPollutionUpdated)
	updatePollution()
	updatePollutionPopup()
	pollution_popup.hide()
	print("TextureREct size: ", size)

func updatePollution():
	if pollutionAtlas == null or planet == null:
		return
	var level :=  planet.getPollutionLevel()
	var step := iconSize.x + iconSpacing
	var atlas := AtlasTexture.new()
	atlas.atlas =  pollutionAtlas
	atlas.region = Rect2(step * int(level), 0, iconSize.x, iconSize.y)
	texture = atlas
	
	
func onPlanetPollutionUpdated(updated_planet: PlanetData):
	if updated_planet == planet:
		updatePollution()
		updatePollutionPopup()


@onready var pollution_popup: Panel = $PollutionPopup
@onready var pollution_level_label: Label = $PollutionPopup/PopupMargin/PopupVbox/Level/PollutionLevelLabel
@onready var pollution_progress: ProgressBar = $PollutionPopup/PopupMargin/PopupVbox/PollutionDisplay/PollutionProgress
@onready var pollution_progress_label: Label = $PollutionPopup/PopupMargin/PopupVbox/PollutionDisplay/PollutionProgressLabel
@onready var pollution_return_label: Label = $PollutionPopup/PopupMargin/PopupVbox/Return/PollutionReturnLabel


func updatePollutionPopup():
	var level := planet.getPollutionLevel()
	var pollutionName := planet.getPollutionName()
	
	pollution_level_label.text = str(pollutionName)
	pollution_level_label.add_theme_color_override("font_color", GlobalResources.getPollutionColor(level))
	
	pollution_progress.max_value = planet.getTotalMaxPollution()
	pollution_progress.value = planet.getTotalPollution()
	
	pollution_progress_label.text = "%d / %d" % [planet.getTotalPollution(), planet.getTotalMaxPollution()]
	
	pollution_return_label.text =str(GlobalResources.getPollutionProductionMultiplier(level)) + "x"
	pollution_return_label.add_theme_color_override("font_color", GlobalResources.getPollutionColor(level))


func _on_mouse_entered() :
	pollution_popup.show()
	print("test")


func _on_mouse_exited() :
	pollution_popup.hide()
	print("test")
