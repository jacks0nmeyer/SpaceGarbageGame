extends ProgressBar

@export var planet: PlanetData
@onready var label: Label = $"../Label"


func _ready():
	step = 1
	max_value = planet.get_total_max_trash()
	value = planet.get_total_trash()
	GlobalSignals.planet_trash_updated.connect(on_planet_trash_updated)
	label.text = "%d / %d" % [value, max_value]


func on_planet_trash_updated(updated_planet: PlanetData):
	if updated_planet == planet:
		max_value = planet.get_total_max_trash()
		value = planet.get_total_trash()
		label.text = "%d / %d" % [value, max_value]
