class_name RegionData
extends Resource


@export var region_name: String

@export_group("Data")
@export var resource_chances: Array[ResourceEntry] = []


@export var building: bool
@export var robot_capacity: int
@export var building_capacity: int
@export var is_water: bool = false

# Runtime-only mapping of RobotData -> int count of that type assigned here.
# Mutated at runtime; not persisted into the .tres on disk.
var assigned_robots: Dictionary = {}

# Runtime-only: BuildingData -> int count of that type assigned to this region.
var assigned_buildings: Dictionary = {}

# Runtime-only: BuildingData -> { resource_name (String) -> int stored }.
# Stored amount per building TYPE in this region — buildings of the same type pool.
var building_storage: Dictionary = {}

# Runtime-only: BuildingData -> { RobotData -> int worker count } staffing this
# building type. Capped by assigned_buildings[type] (one worker per building unit).
var building_workers: Dictionary = {}

# Runtime-only counter (0..4): how many of the per-region 25% RP milestones
# have already been awarded. Monotonically increases so refilling trash never
# re-pays.
var research_milestones_awarded: int = 0


@export var trash: int
@export var max_trash: int 
@export var pollution: int
@export var max_pollution: int



@export var description: String
@export var locked_description: String
@export var locked: bool

@export_group("Textures")
@export var texture_normal: Texture2D
@export var texture_hover: Texture2D
@export var texture_disabled: Texture2D


func get_pollution_level() -> GlobalResources.PollutionLevel:
	var percentage := (float(pollution)/float(max_pollution)) * 100.0
	return GlobalResources.get_pollution_level(percentage)
	
	
func get_pollution_name() -> String:
	return GlobalResources.get_pollution_name(get_pollution_level())


func assigned_slots_used() -> int:
	var used := 0
	for robot in assigned_robots:
		used += int(assigned_robots[robot]) * int(robot.size)
	return used


func can_fit(robot: RobotData) -> bool:
	if locked:
		return false
	if is_water and not robot.works_in_water:
		return false
	var size_mod: int = TechTree.get_robot_size_modifier()
	var effective_size: int = max(1, int(robot.size) + size_mod)
	var capacity: int = robot_capacity + TechTree.get_region_capacity_bonus()
	return assigned_slots_used() + effective_size <= capacity


func return_resource(): #outputs a string based on the region's resource chance
	if resource_chances.is_empty():
		return ""

	var weights := {}
	for entry in resource_chances:
		if entry.chance > 0.0:
			weights[entry.resource] = entry.chance

	if weights.is_empty():
		return ""

	return GlobalResources.weighted_random(weights)


# --- Building helpers ---------------------------------------------------------

func assigned_building_slots_used() -> int:
	var used := 0
	for b in assigned_buildings:
		used += int(assigned_buildings[b]) * int(b.size)
	return used


func can_fit_building(b: BuildingData) -> bool:
	if locked:
		return false
	return assigned_building_slots_used() + int(b.size) <= building_capacity


func stored_in_building(b: BuildingData) -> int:
	if not building_storage.has(b):
		return 0
	var total := 0
	for res in building_storage[b]:
		total += int(building_storage[b][res])
	return total


func capacity_for_building(b: BuildingData) -> int:
	return int(assigned_buildings.get(b, 0)) * int(b.storage_capacity)


func region_has_storage_room() -> bool:
	for b in assigned_buildings:
		if stored_in_building(b) < capacity_for_building(b):
			return true
	return false


# Deposits one unit of `res_name` into the first building type with room.
# Returns the BuildingData it deposited into, or null if discarded.
func deposit_resource(res_name: String):
	var key := res_name.to_lower()
	for b in assigned_buildings:
		if stored_in_building(b) >= capacity_for_building(b):
			continue
		if not building_storage.has(b):
			building_storage[b] = {}
		building_storage[b][key] = int(building_storage[b].get(key, 0)) + 1
		return b
	return null


# Drains up to b.process_amount units total from building_storage[b].
# Round-robin across resource keys so one resource doesn't starve another.
# Returns { resource_name -> qty_moved }.
func process_building(b: BuildingData) -> Dictionary:
	var moved: Dictionary = {}
	if not building_storage.has(b):
		return moved
	var pool: Dictionary = building_storage[b]
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
		building_storage.erase(b)

	return moved


func worker_count(b: BuildingData) -> int:
	if not building_workers.has(b):
		return 0
	var total := 0
	for r in building_workers[b]:
		total += int(building_workers[b][r])
	return total


func worker_cap(b: BuildingData) -> int:
	return int(assigned_buildings.get(b, 0))


func can_staff(b: BuildingData) -> bool:
	return worker_count(b) < worker_cap(b)
