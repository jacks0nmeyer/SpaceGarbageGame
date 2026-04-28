extends Node

# Shipped new-game inventory (also used after Reset). DEV seeds live here until
# you tune release defaults.
const DEFAULT_PLAYER_RESOURCES: Dictionary = {
	"junk": 100000,
	"scrap": 50000,
	"plastic": 0,
	"glass": 0,
	"research": 50,
}

const DEFAULT_MULTIPLIERS: Dictionary = {
	"junk": 1,
	"scrap": 1,
	"plastic": 1,
	"glass": 1,
}

#Resources
var playerResources: Dictionary = DEFAULT_PLAYER_RESOURCES.duplicate()

# Per-planet cumulative-trash thresholds that grant 1 RP each (early-game ramp).
# A planet awards up to len(thresholds) RP from this source — guarded by
# PlanetData.cumulativeMilestonesAwarded so refilling trash never re-pays.
const PLANET_CUMULATIVE_RP_THRESHOLDS: Array[int] = [500, 1000, 2000, 4000]

#Modifiers
var globalMultiplier:= 1

var multipliers: Dictionary = DEFAULT_MULTIPLIERS.duplicate()


#pollution
enum PollutionLevel {CLEAN, LOW, MODERATE, HIGH, CRITICAL}

func getPollutionLevel(pollution: float) -> PollutionLevel:
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


func getPollutionColor(level: PollutionLevel) -> Color:
	match level:
		PollutionLevel.CLEAN: return Color(0.373, 0.443, 0.196, 1.0)
		PollutionLevel.LOW: return Color(0.761, 0.839, 0.31, 1.0)
		PollutionLevel.MODERATE: return Color(0.882, 0.659, 0.271, 1.0)
		PollutionLevel.HIGH: return Color(0.773, 0.471, 0.208, 1.0)
		PollutionLevel.CRITICAL: return Color(0.765, 0.235, 0.251, 1.0)
		_: return Color.WHITE


func getPollutionName(level: PollutionLevel) -> String:
	return PollutionLevel.keys()[level].capitalize()


# Per-region production rate multiplier driven by pollution level. MODERATE is
# the neutral anchor (1.0): a player who never builds Recyclers feels like
# they're playing the default game. CLEAN/LOW give small bonuses for engaging
# with the cleanup loop; HIGH/CRITICAL impose meaningful but non-fatal drag so
# a region can still be deliberately neglected for short-term gain.
func getPollutionProductionMultiplier(level: PollutionLevel) -> float:
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
var ownedRobots: Dictionary = {} #robot data -> amount owned


func _ready():
	GlobalSignals.regionPinToggled.connect(_toggle_pinned_region)


#Player gains a resource
func gotResource(resource: String, amount: int):
	var lcResource := resource.to_lower()
	if playerResources.has(lcResource):
		var tech_mult: float = TechTree.get_resource_multiplier(lcResource)
		var gained: float = amount * multipliers.get(lcResource, 1) * globalMultiplier * tech_mult
		playerResources[lcResource] += int(round(gained))
		GlobalSignals.resourcesUpdated.emit(playerResources)


#gets a resource based on the chances of a specific region, also removes trash from that region
func regionGotResource(region: RegionData, planet: PlanetData, amount: int = 1, double_resources: bool = false):
	if region.trash <= 0:
		return
	var resource : String = region.returnResource()
	if resource.is_empty():
		return
	var prev_trash: int = region.trash
	region.trash = max(0, region.trash - amount)
	var trash_removed: int = prev_trash - region.trash
	var resource_amount: int = trash_removed * (2 if double_resources else 1)
	gotResource(resource, resource_amount)
	_award_region_milestones(region)
	_on_planet_trash_cleaned(planet, trash_removed)
	GlobalSignals.regionTrashUpdated.emit(region)
	GlobalSignals.planetTrashUpdated.emit(planet)
	#GlobalSignals.TotalTrashUpdated.emit(getSolarSystemTrash())


# Award RP for crossing per-region 25% milestones. Idempotent across calls
# thanks to region.researchMilestonesAwarded.
func _award_region_milestones(region: RegionData) -> void:
	if region == null or region.maxTrash <= 0:
		return
	var removed: int = region.maxTrash - region.trash
	var current_milestone: int = clamp(int(floor(4.0 * float(removed) / float(region.maxTrash))), 0, 4)
	if current_milestone > region.researchMilestonesAwarded:
		var diff: int = current_milestone - region.researchMilestonesAwarded
		region.researchMilestonesAwarded = current_milestone
		gotResource("research", diff)
		GlobalSignals.researchMilestoneAwarded.emit(region, diff, null)


# Increment a planet's cumulative-trash counter and award any newly-crossed
# threshold RP. Called from both manual click (regionGotResource) and the
# automated robot tick (GameManager._tick_region).
func _on_planet_trash_cleaned(planet: PlanetData, amount: int) -> void:
	if planet == null or amount <= 0:
		return
	planet.cumulativeTrashCleaned += amount
	while planet.cumulativeMilestonesAwarded < PLANET_CUMULATIVE_RP_THRESHOLDS.size() \
			and planet.cumulativeTrashCleaned >= PLANET_CUMULATIVE_RP_THRESHOLDS[planet.cumulativeMilestonesAwarded]:
		gotResource("research", 1)
		planet.cumulativeMilestonesAwarded += 1
		GlobalSignals.researchMilestoneAwarded.emit(null, 1, planet)


#purchase functions
func can_afford(cost: Dictionary) -> bool:
	for resource in cost:
		if playerResources.get(resource.to_lower(), 0) < cost[resource]:
			return false
	return true


func purchase(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for resource in cost:
		playerResources[resource.to_lower()] -= cost[resource]
		GlobalSignals.resourcesUpdated.emit(playerResources)
	return true


func apply_new_game_inventory() -> void:
	playerResources = DEFAULT_PLAYER_RESOURCES.duplicate()
	globalMultiplier = 1
	multipliers = DEFAULT_MULTIPLIERS.duplicate()
	pinnedRegion = null
	GlobalSignals.resourcesUpdated.emit(playerResources)


#Trash Logic
var solarSystem: SolarSystemData = preload("res://Resources/SolarSystem/SolarSystem.tres")
var robots: RobotCollection = preload("res://Resources/Robots/Robots.tres")

# Currently pinned region for the info panel. While non-null, hover-driven
# retargeting is disabled and only this region accepts robot drops.
var pinnedRegion: RegionData = null


func _toggle_pinned_region(region: RegionData) -> void:
	if pinnedRegion == region:
		pinnedRegion = null
	else:
		pinnedRegion = region


# Move/copy one of `robot` to `target`. If `from_region` is non-null and not
# the same as `target`, decrement source first (a cross-region move). Caller
# is responsible for capacity validation via region.canFit(robot).
func assignOne(robot: RobotData, target: RegionData, from_region: RegionData = null) -> void:
	if robot == null or target == null:
		return
	if from_region != null and from_region != target:
		var src: int = int(from_region.assignedRobots.get(robot, 0))
		if src <= 1:
			from_region.assignedRobots.erase(robot)
		else:
			from_region.assignedRobots[robot] = src - 1
		GlobalSignals.robotUnassigned.emit(robot, from_region)
	target.assignedRobots[robot] = int(target.assignedRobots.get(robot, 0)) + 1
	GlobalSignals.robotAssigned.emit(robot, target)


# Decrement one of `robot` from `region`, clearing the dict entry when it
# reaches zero, and emit robotUnassigned. Safe to call when none are assigned.
func unassignOne(robot: RobotData, region: RegionData) -> void:
	if robot == null or region == null:
		return
	var current: int = int(region.assignedRobots.get(robot, 0))
	if current <= 0:
		return
	if current <= 1:
		region.assignedRobots.erase(robot)
	else:
		region.assignedRobots[robot] = current - 1
	GlobalSignals.robotUnassigned.emit(robot, region)


#Total count of a given robot type currently assigned across every region.
func assignedTotal(robot: RobotData) -> int:
	if robot == null or solarSystem == null:
		return 0
	var total := 0
	for planet in solarSystem.planets:
		for region in planet.regions:
			total += int(region.assignedRobots.get(robot, 0))
	return total


#Total minus assigned. Never goes below zero.
func unassignedCount(robot: RobotData) -> int:
	if robot == null:
		return 0
	return max(0, robot.amount - assignedTotal(robot))

func getPlanetTrash(planet: PlanetData) -> int:
	return planet.getTotalTrash()


#func getSolarSystemTrash() -> int:
	#return solarSystem.getTotalTrash()


#picks an item based on chances between 0 and 1 
func weighted_random(weights: Dictionary) -> Variant:
	var roll := randf()
	var cumulative := 0.0
	for item in weights:
			cumulative += weights[item]
			if roll < cumulative:
				return item
	return weights.keys().back()


#Progress
var totalSystemTrash
