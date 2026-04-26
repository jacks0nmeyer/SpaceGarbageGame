extends ProgressBar

@export var planet: PlanetData
@onready var label: Label = $"../Label"


func _ready():
	step = 1
	max_value = planet.getTotalTrash()
	value = max_value
	GlobalSignals.planetTrashUpdated.connect(onPlanetTrashUpdated)
	label.text = "%d / %d" % [value, max_value]


func onPlanetTrashUpdated(updated_planet: PlanetData):
	if updated_planet == planet:
		value = planet.getTotalTrash()
		label.text = "%d / %d" % [value, max_value]
