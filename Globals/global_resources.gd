extends Node

#Resources
var playerResources: Dictionary = {
	"junk": 100000,
	"scrap": 50000,
	"plastic": 0,
	"glass": 0,
}

#Modifiers
var globalMultiplier:= 1

var multipliers: Dictionary = {
	"junk": 1,
	"scrap": 1,
	"plastic": 1,
	"glass": 1,
}


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


func getPollutionName(level: PollutionLevel) -> String:
	return PollutionLevel.keys()[level].capitalize()
		

#robots
var ownedRobots: Dictionary = {} #robot data -> amount owned


#rate tracking
var resourceRates: Dictionary = {}
var rateTracker: Dictionary = {}
var rateInterval: float = 1.0
var rateTimer: float = 0.0


func _ready():
	GlobalSignals.regionPinToggled.connect(_toggle_pinned_region)


func _process(delta):
	rateTimer += delta
	if rateTimer >= rateInterval:
		rateTimer = 0.0
		resourceRates = rateTracker.duplicate()
		rateTracker.clear()
		GlobalSignals.resourceRateUpdated.emit(resourceRates)

#Player gains a resource
func gotResource(resource: String, amount: int):
	var lcResource := resource.to_lower()
	if playerResources.has(lcResource):
		playerResources[lcResource] += amount * multipliers.get(lcResource, 1) * globalMultiplier
		rateTracker[lcResource] = rateTracker.get(lcResource, 0) + amount
		GlobalSignals.resourcesUpdated.emit(playerResources)


#gets a resource based on the chances of a specific region, also removes trash from that region
func regionGotResource(region: RegionData, planet: PlanetData, amount: int = 1):
	if region.trash <= 0:
		return
	var resource : String = region.returnResource()
	if resource.is_empty():
		return
	region.trash = max(0, region.trash - amount)
	gotResource(resource, amount)
	GlobalSignals.regionTrashUpdated.emit(region)
	GlobalSignals.planetTrashUpdated.emit(planet)
	#GlobalSignals.TotalTrashUpdated.emit(getSolarSystemTrash())


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
