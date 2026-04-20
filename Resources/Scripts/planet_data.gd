extends Resource
class_name PlanetData

@export var planetName: String
@export var regions: Array[RegionData] = []

func getTotalTrash() -> int:
	var total:= 0
	for region in regions:
		total += region.trash
	return total
