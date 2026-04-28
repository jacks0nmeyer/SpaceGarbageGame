extends Resource
class_name PlanetData

@export var planetName: String
@export var regions: Array[RegionData] = []

func getTotalTrash() -> int:
	var total:= 0
	for region in regions:
		total += region.trash
	return total


func getTotalPollution() -> int:
	if regions.is_empty():
		return 0
	var total:= 0
	for region in regions:
		total += (region.pollution)
	return total


func getTotalMaxPollution() -> int:
	if regions.is_empty():
		return 0
	var total:= 0
	for region in regions:
		total += (region.maxPollution)
	return total

func getAveragePollution() -> float:
	if regions.is_empty():
		return 0.0
	var total:= 0.0
	for region in regions:
		total += (float(region.pollution)/float(region.maxPollution)) * 100
	return total / regions.size()
	

func getPollutionLevel() -> GlobalResources.PollutionLevel:
	return GlobalResources.getPollutionLevel(getAveragePollution())


func getPollutionName() -> String:
	return GlobalResources.getPollutionName(getPollutionLevel())
