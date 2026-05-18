extends Node

# New-game / reset inventory (SaveGame also fills missing keys from this).
const DEFAULT_PLAYER_RESOURCES: Dictionary = {
	ResourceKeys.JUNK: 0,
	ResourceKeys.SCRAP: 0,
	ResourceKeys.PLASTIC: 0,
	ResourceKeys.GLASS: 0,
	ResourceKeys.RESEARCH: 0,
}

# Editor/debug only — applied from Main menu (not used on reset).
# Generous stacks for robot purchases, region unlocks (e.g. 10k glass), and
# cost_increase scaling while iterating.
const DEV_GODMODE_PLAYER_RESOURCES: Dictionary = {
	ResourceKeys.JUNK: 1_000_000,
	ResourceKeys.SCRAP: 500_000,
	ResourceKeys.PLASTIC: 100_000,
	ResourceKeys.GLASS: 100_000,
	ResourceKeys.RESEARCH: 500,
}

const DEFAULT_MULTIPLIERS: Dictionary = {
	ResourceKeys.JUNK: 1,
	ResourceKeys.SCRAP: 1,
	ResourceKeys.PLASTIC: 1,
	ResourceKeys.GLASS: 1,
}

#Resources
var player_resources: Dictionary = DEFAULT_PLAYER_RESOURCES.duplicate()

# Per-planet cumulative-trash thresholds that grant 1 RP each (early-game ramp).
# A planet awards up to len(thresholds) RP from this source — guarded by
# PlanetData.cumulative_milestones_awarded so refilling trash never re-pays.
const PLANET_CUMULATIVE_RP_THRESHOLDS: Array[int] = [500, 1000, 2000, 4000]

#Modifiers
var global_multiplier: int = 1

var multipliers: Dictionary = DEFAULT_MULTIPLIERS.duplicate()


#pollution
enum PollutionLevel {CLEAN, LOW, MODERATE, HIGH, CRITICAL}

func get_pollution_level(pollution: float) -> PollutionLevel:
	if pollution < 20.0:
		return PollutionLevel.CLEAN
	elif pollution < 40.0:
		return PollutionLevel.LOW
	elif pollution < 60.0:
		return PollutionLevel.MODERATE
	elif pollution < 80.0:
		return PollutionLevel.HIGH
	else: 
		return PollutionLevel.CRITICAL


func get_pollution_color(level: PollutionLevel) -> Color:
	match level:
		PollutionLevel.CLEAN: return Color(0.373, 0.443, 0.196, 1.0)
		PollutionLevel.LOW: return Color(0.761, 0.839, 0.31, 1.0)
		PollutionLevel.MODERATE: return Color(0.882, 0.659, 0.271, 1.0)
		PollutionLevel.HIGH: return Color(0.773, 0.471, 0.208, 1.0)
		PollutionLevel.CRITICAL: return Color(0.765, 0.235, 0.251, 1.0)
		_: return Color.WHITE


func get_pollution_name(level: PollutionLevel) -> String:
	return PollutionLevel.keys()[level].capitalize()


# Per-region production rate multiplier driven by pollution level. MODERATE is
# the neutral anchor (1.0): a player who never builds Recyclers feels like
# they're playing the default game. CLEAN/LOW give small bonuses for engaging
# with the cleanup loop; HIGH/CRITICAL impose meaningful but non-fatal drag so
# a region can still be deliberately neglected for short-term gain.
func get_pollution_production_multiplier(level: PollutionLevel) -> float:
	var override: float = TechTree.get_pollution_multiplier(level)
	if not is_nan(override):
		return override
	match level:
		PollutionLevel.CLEAN: return 1.10
		PollutionLevel.LOW: return 1.05
		PollutionLevel.MODERATE: return 1.00
		PollutionLevel.HIGH: return 0.80
		PollutionLevel.CRITICAL: return 0.55
	return 1.00
		

#robots
var owned_robots: Dictionary = {} #robot data -> amount owned


func _ready() -> void:
	GlobalSignals.region_pin_toggled.connect(_toggle_pinned_region)


#Player gains a resource
func got_resource(resource: String, amount: int):
	var lc_resource := resource.to_lower()
	if player_resources.has(lc_resource):
		var tech_mult: float = TechTree.get_resource_multiplier(lc_resource)
		var gained: float = amount * multipliers.get(lc_resource, 1) * global_multiplier * tech_mult
		player_resources[lc_resource] += int(round(gained))
		GlobalSignals.resources_updated.emit(player_resources)


#gets a resource based on the chances of a specific region, also removes trash from that region
func region_got_resource(region: RegionData, planet: PlanetData, amount: int = 1, double_resources: bool = false):
	if region.trash <= 0:
		return
	var resource : String = region.return_resource()
	if resource.is_empty():
		return
	var prev_trash: int = region.trash
	region.trash = max(0, region.trash - amount)
	var trash_removed: int = prev_trash - region.trash
	var resource_amount: int = trash_removed * (2 if double_resources else 1)
	got_resource(resource, resource_amount)
	_award_region_milestones(region)
	_on_planet_trash_cleaned(planet, trash_removed)
	GlobalSignals.region_trash_updated.emit(region)
	GlobalSignals.planet_trash_updated.emit(planet)


# Award RP for crossing per-region 25% milestones. Idempotent across calls
# thanks to region.research_milestones_awarded.
func _award_region_milestones(region: RegionData) -> void:
	if region == null or region.max_trash <= 0:
		return
	var removed: int = region.max_trash - region.trash
	var current_milestone: int = clamp(int(floor(4.0 * float(removed) / float(region.max_trash))), 0, 4)
	if current_milestone > region.research_milestones_awarded:
		var diff: int = current_milestone - region.research_milestones_awarded
		region.research_milestones_awarded = current_milestone
		got_resource(ResourceKeys.RESEARCH, diff)


# Increment a planet's cumulative-trash counter and award any newly-crossed
# threshold RP. Called from both manual click (region_got_resource) and the
# automated robot tick (GameManager._tick_region).
func _on_planet_trash_cleaned(planet: PlanetData, amount: int) -> void:
	if planet == null or amount <= 0:
		return
	planet.cumulative_trash_cleaned += amount
	while planet.cumulative_milestones_awarded < PLANET_CUMULATIVE_RP_THRESHOLDS.size() \
			and planet.cumulative_trash_cleaned >= PLANET_CUMULATIVE_RP_THRESHOLDS[planet.cumulative_milestones_awarded]:
		got_resource(ResourceKeys.RESEARCH, 1)
		planet.cumulative_milestones_awarded += 1


#purchase functions
func can_afford(cost: Dictionary) -> bool:
	for resource in cost:
		if player_resources.get(resource.to_lower(), 0) < cost[resource]:
			return false
	return true


func purchase(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for resource in cost:
		player_resources[resource.to_lower()] -= cost[resource]
		GlobalSignals.resources_updated.emit(player_resources)
	return true


func apply_new_game_inventory() -> void:
	player_resources = DEFAULT_PLAYER_RESOURCES.duplicate()
	global_multiplier = 1
	multipliers = DEFAULT_MULTIPLIERS.duplicate()
	pinned_region = null
	GlobalSignals.resources_updated.emit(player_resources)


func apply_dev_godmode_inventory() -> void:
	player_resources = DEV_GODMODE_PLAYER_RESOURCES.duplicate()
	GlobalSignals.resources_updated.emit(player_resources)


#Trash Logic
var solar_system: SolarSystemData = preload("res://Resources/SolarSystem/SolarSystem.tres")
var robots: RobotCollection = preload("res://Resources/Robots/Robots.tres")
var buildings: BuildingCollection = preload("res://Resources/Buildings/Buildings.tres")

# Currently pinned region for the info panel. While non-null, hover-driven
# retargeting is disabled and only this region accepts robot drops.
var pinned_region: RegionData = null


func _toggle_pinned_region(region: RegionData) -> void:
	if pinned_region == region:
		pinned_region = null
	else:
		pinned_region = region


# Move/copy one of `robot` to `target`. If `from_region` is non-null and not
# the same as `target`, decrement source first (a cross-region move). Caller
# is responsible for capacity validation via region.can_fit(robot).
func assign_one(robot: RobotData, target: RegionData, from_region: RegionData = null) -> void:
	if robot == null or target == null:
		return
	if from_region != null and from_region != target:
		var src: int = int(from_region.assigned_robots.get(robot, 0))
		if src <= 1:
			from_region.assigned_robots.erase(robot)
		else:
			from_region.assigned_robots[robot] = src - 1
		GlobalSignals.robot_unassigned.emit(robot, from_region)
	target.assigned_robots[robot] = int(target.assigned_robots.get(robot, 0)) + 1
	GlobalSignals.robot_assigned.emit(robot, target)


# Decrement one of `robot` from `region`, clearing the dict entry when it
# reaches zero, and emit robot_unassigned. Safe to call when none are assigned.
func unassign_one(robot: RobotData, region: RegionData) -> void:
	if robot == null or region == null:
		return
	var current: int = int(region.assigned_robots.get(robot, 0))
	if current <= 0:
		return
	if current <= 1:
		region.assigned_robots.erase(robot)
	else:
		region.assigned_robots[robot] = current - 1
	GlobalSignals.robot_unassigned.emit(robot, region)


# Remove every assigned `robot` from `region` in one step (Robots tab:
# Shift+right-click a row). Emits `robot_unassigned` once if anything changed.
func unassign_all_of_type(robot: RobotData, region: RegionData) -> void:
	if robot == null or region == null:
		return
	var current: int = int(region.assigned_robots.get(robot, 0))
	if current <= 0:
		return
	region.assigned_robots.erase(robot)
	GlobalSignals.robot_unassigned.emit(robot, region)


#Total count of a given robot type currently assigned across every region.
func assigned_total(robot: RobotData) -> int:
	if robot == null or solar_system == null:
		return 0
	var total := 0
	for planet in solar_system.planets:
		for region in planet.regions:
			total += int(region.assigned_robots.get(robot, 0))
	return total


#Total minus assigned (in regions) and staffed (in buildings). Never below zero.
func unassigned_count(robot: RobotData) -> int:
	if robot == null:
		return 0
	return max(0, robot.amount - assigned_total(robot) - staffed_total(robot))


# --- Buildings ----------------------------------------------------------------

func assign_one_building(b: BuildingData, target: RegionData, from_region: RegionData = null) -> void:
	if b == null or target == null:
		return
	if from_region != null and from_region != target:
		var src: int = int(from_region.assigned_buildings.get(b, 0))
		if src <= 1:
			from_region.assigned_buildings.erase(b)
		else:
			from_region.assigned_buildings[b] = src - 1
		_enforce_worker_cap(from_region, b)
		GlobalSignals.building_unassigned.emit(b, from_region)
	target.assigned_buildings[b] = int(target.assigned_buildings.get(b, 0)) + 1
	GlobalSignals.building_assigned.emit(b, target)


func unassign_one_building(b: BuildingData, region: RegionData) -> void:
	if b == null or region == null:
		return
	var current: int = int(region.assigned_buildings.get(b, 0))
	if current <= 0:
		return
	if current <= 1:
		region.assigned_buildings.erase(b)
		region.building_storage.erase(b)
	else:
		region.assigned_buildings[b] = current - 1
	_enforce_worker_cap(region, b)
	GlobalSignals.building_unassigned.emit(b, region)


func unassign_all_of_type_building(b: BuildingData, region: RegionData) -> void:
	if b == null or region == null:
		return
	var current: int = int(region.assigned_buildings.get(b, 0))
	if current <= 0:
		return
	region.assigned_buildings.erase(b)
	region.building_storage.erase(b)
	_enforce_worker_cap(region, b)
	GlobalSignals.building_unassigned.emit(b, region)


func assigned_building_total(b: BuildingData) -> int:
	if b == null or solar_system == null:
		return 0
	var total := 0
	for planet in solar_system.planets:
		for region in planet.regions:
			total += int(region.assigned_buildings.get(b, 0))
	return total


func unassigned_building_count(b: BuildingData) -> int:
	if b == null:
		return 0
	return max(0, b.amount - assigned_building_total(b))


# Click-driven processing — pushes processed resources into player_resources.
func process_building_clicked(region: RegionData, b: BuildingData) -> void:
	if region == null or b == null:
		return
	var moved: Dictionary = region.process_building(b)
	if moved.is_empty():
		return
	for res in moved:
		got_resource(res, int(moved[res]))
	GlobalSignals.building_storage_updated.emit(region, b)


# --- Building workers ---------------------------------------------------------

func staffed_total(robot: RobotData) -> int:
	if robot == null or solar_system == null:
		return 0
	var total := 0
	for planet in solar_system.planets:
		for region in planet.regions:
			for b in region.building_workers:
				total += int(region.building_workers[b].get(robot, 0))
	return total


func staff_one_worker(robot: RobotData, region: RegionData, b: BuildingData) -> bool:
	if robot == null or region == null or b == null:
		return false
	if not region.can_staff(b):
		return false
	if unassigned_count(robot) <= 0:
		return false
	if not region.building_workers.has(b):
		region.building_workers[b] = {}
	region.building_workers[b][robot] = int(region.building_workers[b].get(robot, 0)) + 1
	GlobalSignals.building_worker_assigned.emit(robot, region, b)
	return true


func unstaff_one_worker(robot: RobotData, region: RegionData, b: BuildingData) -> bool:
	if robot == null or region == null or b == null:
		return false
	if not region.building_workers.has(b):
		return false
	var current: int = int(region.building_workers[b].get(robot, 0))
	if current <= 0:
		return false
	if current <= 1:
		region.building_workers[b].erase(robot)
		if region.building_workers[b].is_empty():
			region.building_workers.erase(b)
	else:
		region.building_workers[b][robot] = current - 1
	GlobalSignals.building_worker_unassigned.emit(robot, region, b)
	return true


# Picks the first owned robot type with unassigned_count > 0 and staffs one.
func staff_any_available(region: RegionData, b: BuildingData) -> bool:
	if region == null or b == null or robots == null:
		return false
	if not region.can_staff(b):
		return false
	for robot in robots.robots:
		if unassigned_count(robot) > 0:
			return staff_one_worker(robot, region, b)
	return false


# Removes excess workers if assigned_buildings[b] dropped below worker_count.
# Emits one building_worker_unassigned per worker removed.
func _enforce_worker_cap(region: RegionData, b: BuildingData) -> void:
	if region == null or b == null:
		return
	if not region.building_workers.has(b):
		return
	var cap: int = region.worker_cap(b)
	while region.worker_count(b) > cap:
		var workers: Dictionary = region.building_workers.get(b, {})
		if workers.is_empty():
			break
		var any_robot = workers.keys()[0]
		if not unstaff_one_worker(any_robot, region, b):
			break

func get_planet_trash(planet: PlanetData) -> int:
	return planet.get_total_trash()


#picks an item based on chances between 0 and 1
func weighted_random(weights: Dictionary) -> Variant:
	var roll := randf()
	var cumulative := 0.0
	for item in weights:
			cumulative += weights[item]
			if roll < cumulative:
				return item
	return weights.keys().back()
