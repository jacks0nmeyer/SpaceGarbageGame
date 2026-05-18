extends Resource
class_name PlanetData

@export var planet_name: String
@export var regions: Array[RegionData] = []

# Runtime-only counters (parallel to RegionData.assigned_robots): cumulative
# trash removed across all this planet's regions, and how many cumulative-RP
# milestones have already been awarded. Monotonic; not persisted.
var cumulative_trash_cleaned: int = 0
var cumulative_milestones_awarded: int = 0

func get_total_trash() -> int:
	var total:= 0
	for region in regions:
		total += region.trash
	return total


func get_total_max_trash() -> int:
	var total := 0
	for region in regions:
		total += region.max_trash
	return total


func get_total_pollution() -> int:
	if regions.is_empty():
		return 0
	var total:= 0
	for region in regions:
		total += (region.pollution)
	return total


func get_total_max_pollution() -> int:
	if regions.is_empty():
		return 0
	var total:= 0
	for region in regions:
		total += (region.max_pollution)
	return total

func get_average_pollution() -> float:
	if regions.is_empty():
		return 0.0
	var total:= 0.0
	for region in regions:
		total += (float(region.pollution)/float(region.max_pollution)) * 100
	return total / regions.size()
	

func get_pollution_level() -> GlobalResources.PollutionLevel:
	return GlobalResources.get_pollution_level(get_average_pollution())


func get_pollution_name() -> String:
	return GlobalResources.get_pollution_name(get_pollution_level())
