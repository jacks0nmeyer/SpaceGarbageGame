class_name RegionData
extends Resource


@export var regionName: String


@export_group("Data")
@export var resourceChances: Array[ResourceEntry] = []


@export var building: bool
@export var water: bool
@export var robot_capacity: int
@export var assignedRobots: Array[RobotData] = []


@export var trash: int
@export var maxTrash: int 
@export var pollution: int


@export var description: String
@export var lockedDescription: String
@export var locked: bool


@export_group("Textures")
@export var texture_normal: Texture2D
@export var texture_hover: Texture2D
@export var texture_disabled: Texture2D


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


func getRobotAvailability() -> int:
	return robot_capacity - assignedRobots.size()


func canAssignRobot(robot: RobotData) -> bool:
	return getRobotAvailability() >= robot.size
