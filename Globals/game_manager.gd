extends Node

# Set to true to auto-assign one BasicCleaner to the first unlocked region of
# every planet at startup. Useful for verifying the production loop before the
# drag-drop UI is in place. Should be left false on commit.
const DEBUG_AUTO_ASSIGN_ROBOT: bool = false

# Robot production loop. Walks every region in the solar system each frame,
# accumulating progress for each (region, robot type) pair based on the robot's
# productionRate and the count assigned. When at least one whole unit of work
# has accumulated, debris is processed: region.trash decrements by 1, the
# region's drop table picks a resource via region.returnResource(), and the
# robot's resourceReturn (which can be fractional, e.g. Atomizer 0.4 or
# Recycler 2.5) accumulates into a per-(region, resource) carry pool that
# drains whole integer amounts to GlobalResources.gotResource().
#
# Each trash unit also applies the active robot's pollutionEffect to
# region.pollution (clamped to [0, maxPollution]); regionPollutionUpdated /
# planetPollutionUpdated emit only when the value actually moved.

# Dictionary[RegionData -> Dictionary[RobotData -> float]]
var _progress: Dictionary = {}
# Dictionary[RegionData -> Dictionary[String -> float]]
var _resource_carry: Dictionary = {}


func _ready() -> void:
	if DEBUG_AUTO_ASSIGN_ROBOT:
		_debug_auto_assign()


func _debug_auto_assign() -> void:
	var solar_system: SolarSystemData = GlobalResources.solarSystem
	var robots: RobotCollection = GlobalResources.robots
	if solar_system == null or robots == null or robots.robots.is_empty():
		return
	var basic: RobotData = robots.robots[0]
	for planet in solar_system.planets:
		for region in planet.regions:
			if not region.locked:
				region.assignedRobots[basic] = int(region.assignedRobots.get(basic, 0)) + 1
				GlobalSignals.robotAssigned.emit(basic, region)
				break


func _process(delta: float) -> void:
	var solar_system: SolarSystemData = GlobalResources.solarSystem
	if solar_system == null:
		return

	var global_mult: float = TechTree.get_global_production_multiplier()
	var cleaner_scalar: float = TechTree.get_cleaner_strength_scalar()
	var pollution_decay: int = TechTree.get_pollution_decay_per_tick()

	for planet in solar_system.planets:
		var planet_trash_changed := false
		var planet_pollution_changed := false
		for region in planet.regions:
			if region.locked:
				continue
			if region.assignedRobots.is_empty():
				continue

			var changes := _tick_region(region, planet, delta, global_mult, cleaner_scalar, pollution_decay)
			if changes.trash:
				GlobalSignals.regionTrashUpdated.emit(region)
				planet_trash_changed = true
			if changes.pollution:
				GlobalSignals.regionPollutionUpdated.emit(region)
				planet_pollution_changed = true

		if planet_trash_changed:
			GlobalSignals.planetTrashUpdated.emit(planet)
		if planet_pollution_changed:
			GlobalSignals.planetPollutionUpdated.emit(planet)


func _tick_region(region: RegionData, planet: PlanetData, delta: float, global_mult: float, cleaner_scalar: float, pollution_decay: int) -> Dictionary:
	var region_progress: Dictionary = _progress.get(region, {})
	var region_carry: Dictionary = _resource_carry.get(region, {})
	var trash_changed := false
	var pollution_changed := false

	# Carbon Capture / similar techs: passive pollution decay on assigned regions.
	if pollution_decay != 0 and region.pollution > 0:
		var decayed: int = clamp(region.pollution + pollution_decay, 0, region.maxPollution)
		if decayed != region.pollution:
			region.pollution = decayed
			pollution_changed = true

	if region.trash <= 0:
		_progress[region] = region_progress
		_resource_carry[region] = region_carry
		return {"trash": trash_changed, "pollution": pollution_changed}

	var pollution_mult: float = GlobalResources.getPollutionProductionMultiplier(region.getPollutionLevel())

	for robot in region.assignedRobots:
		var count: int = int(region.assignedRobots[robot])
		if count <= 0:
			continue

		var progress: float = region_progress.get(robot, 0.0)
		progress += float(count) * float(robot.productionRate) * pollution_mult * global_mult * delta

		while progress >= 1.0 and region.trash > 0:
			progress -= 1.0
			region.trash = max(0, region.trash - 1)
			trash_changed = true
			GlobalResources._on_planet_trash_cleaned(planet, 1)

			if robot.pollutionEffect != 0:
				var effect: int = int(robot.pollutionEffect)
				if effect < 0:
					effect = int(round(float(effect) * cleaner_scalar))
				var new_pollution: int = clamp(region.pollution + effect, 0, region.maxPollution)
				if new_pollution != region.pollution:
					region.pollution = new_pollution
					pollution_changed = true

			var res: String = region.returnResource()
			if res == "":
				continue

			var key := res.to_lower()
			var pooled: float = region_carry.get(key, 0.0) + float(robot.resourceReturn)
			var whole: int = int(floor(pooled))
			if whole > 0:
				GlobalResources.gotResource(key, whole)
				pooled -= float(whole)
			region_carry[key] = pooled

		region_progress[robot] = progress

	_progress[region] = region_progress
	_resource_carry[region] = region_carry
	return {"trash": trash_changed, "pollution": pollution_changed}
