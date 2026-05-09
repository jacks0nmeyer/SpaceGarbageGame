class_name RegionData
extends Resource


@export var regionName: String

@export_group("Data")
@export var resourceChances: Array[ResourceEntry] = []


@export var building: bool
@export var robot_capacity: int
@export var building_capacity: int
@export var isWater: bool = false

# Runtime-only mapping of RobotData -> int count of that type assigned here.
# Mutated at runtime; not persisted into the .tres on disk.
var assignedRobots: Dictionary = {}

# Runtime-only: BuildingData -> int count of that type assigned to this region.
var assignedBuildings: Dictionary = {}

# Runtime-only: BuildingData -> { resource_name (String) -> int stored }.
# Stored amount per building TYPE in this region — buildings of the same type pool.
var buildingStorage: Dictionary = {}

# Runtime-only: BuildingData -> { RobotData -> int worker count } staffing this
# building type. Capped by assignedBuildings[type] (one worker per building unit).
var buildingWorkers: Dictionary = {}

# Runtime-only counter (0..4): how many of the per-region 25% RP milestones
# have already been awarded. Monotonically increases so refilling trash never
# re-pays.
var researchMilestonesAwarded: int = 0


@export var trash: int
@export var maxTrash: int 
@export var pollution: int
@export var maxPollution: int



@export var description: String
@export var lockedDescription: String
@export var locked: bool

@export_group("Textures")
@export var texture_normal: Texture2D
@export var texture_hover: Texture2D
@export var texture_disabled: Texture2D


func getPollutionLevel() -> GlobalResources.PollutionLevel:
	var percentage := (float(pollution)/float(maxPollution)) * 100.0
	return GlobalResources.getPollutionLevel(percentage)
	
	
func getPollutionName() -> String:
	return GlobalResources.getPollutionName(getPollutionLevel())


func assignedSlotsUsed() -> int:
	var used := 0
	for robot in assignedRobots:
		used += int(assignedRobots[robot]) * int(robot.size)
	return used


func canFit(robot: RobotData) -> bool:
	if locked:
		return false
	if isWater and not robot.worksInWater:
		return false
	var size_mod: int = TechTree.get_robot_size_modifier()
	var effective_size: int = max(1, int(robot.size) + size_mod)
	var capacity: int = robot_capacity + TechTree.get_region_capacity_bonus()
	return assignedSlotsUsed() + effective_size <= capacity


func returnResource(): #outputs a string based on the region's resource chance
	if resourceChances.is_empty():
		return ""

	var weights := {}
	for entry in resourceChances:
		if entry.chance > 0.0:
			weights[entry.resource] = entry.chance

	if weights.is_empty():
		return ""

	return GlobalResources.weighted_random(weights)


# --- Building helpers ---------------------------------------------------------

func assignedBuildingSlotsUsed() -> int:
	var used := 0
	for b in assignedBuildings:
		used += int(assignedBuildings[b]) * int(b.size)
	return used


func canFitBuilding(b: BuildingData) -> bool:
	if locked:
		return false
	return assignedBuildingSlotsUsed() + int(b.size) <= building_capacity


func storedInBuilding(b: BuildingData) -> int:
	if not buildingStorage.has(b):
		return 0
	var total := 0
	for res in buildingStorage[b]:
		total += int(buildingStorage[b][res])
	return total


func capacityForBuilding(b: BuildingData) -> int:
	return int(assignedBuildings.get(b, 0)) * int(b.storage_capacity)


func regionHasStorageRoom() -> bool:
	for b in assignedBuildings:
		if storedInBuilding(b) < capacityForBuilding(b):
			return true
	return false


# Deposits one unit of `res_name` into the first building type with room.
# Returns the BuildingData it deposited into, or null if discarded.
func depositResource(res_name: String):
	var key := res_name.to_lower()
	for b in assignedBuildings:
		if storedInBuilding(b) >= capacityForBuilding(b):
			continue
		if not buildingStorage.has(b):
			buildingStorage[b] = {}
		buildingStorage[b][key] = int(buildingStorage[b].get(key, 0)) + 1
		return b
	return null


# Drains up to b.process_amount units total from buildingStorage[b].
# Round-robin across resource keys so one resource doesn't starve another.
# Returns { resource_name -> qty_moved }.
func processBuilding(b: BuildingData) -> Dictionary:
	var moved: Dictionary = {}
	if not buildingStorage.has(b):
		return moved
	var pool: Dictionary = buildingStorage[b]
	if pool.is_empty():
		return moved

	var remaining := int(b.process_amount)
	while remaining > 0:
		var keys := pool.keys()
		var any_drained := false
		for k in keys:
			if remaining <= 0:
				break
			if int(pool[k]) <= 0:
				continue
			pool[k] = int(pool[k]) - 1
			moved[k] = int(moved.get(k, 0)) + 1
			remaining -= 1
			any_drained = true
		if not any_drained:
			break

	# Tidy up zero / empty entries
	for k in pool.keys():
		if int(pool[k]) <= 0:
			pool.erase(k)
	if pool.is_empty():
		buildingStorage.erase(b)

	return moved


func workerCount(b: BuildingData) -> int:
	if not buildingWorkers.has(b):
		return 0
	var total := 0
	for r in buildingWorkers[b]:
		total += int(buildingWorkers[b][r])
	return total


func workerCap(b: BuildingData) -> int:
	return int(assignedBuildings.get(b, 0))


func canStaff(b: BuildingData) -> bool:
	return workerCount(b) < workerCap(b)
