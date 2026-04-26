extends TextureRect

@export var planet: PlanetData
@export var pollutionAtlas: Texture2D
var iconSize := Vector2(44, 44)
var iconSpacing := 8

func _ready():
	GlobalSignals.planetPollutionUpdated.connect(onPlanetPollutionUpdated)
	updatePollution()


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
