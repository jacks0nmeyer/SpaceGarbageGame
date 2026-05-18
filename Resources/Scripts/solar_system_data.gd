extends Resource
class_name SolarSystemData

@export var planets: Array[PlanetData] = []

func get_total_trash() -> int:
	var total:= 0
	for planet in planets:
		total += planet.get_total_trash()
	return total
