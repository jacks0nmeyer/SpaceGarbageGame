class_name RegionData
extends Resource


@export var regionName: String

@export_group("Data")
@export var resourceChances: Array[ResourceEntry] = []


@export var building: bool
@export var robot_capacity: int
@export var isWater: bool = false

# Runtime-only mapping of RobotData -> int count of that type assigned here.
# Mutated at runtime; not persisted into the .tres on disk.
var assignedRobots: Dictionary = {}

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
