extends Resource
class_name SolarSystemData

@export var planets: Array[PlanetData] = []

func getTotalTrash() -> int:
	var total:= 0
	for planet in planets:
		total =+ planet.getTotalTrash()
	return total
