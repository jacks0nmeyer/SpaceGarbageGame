extends Node

# Set to true to auto-assign one BasicCleaner to the first unlocked region of
# every planet at startup. Useful for verifying the production loop before the
# drag-drop UI is in place. Should be left false on commit.
const DEBUG_AUTO_ASSIGN_ROBOT: bool = false

# When true, `_process` skips the robot production loop (Main pause button /
# spacebar). The scene tree keeps running so menus, region UI, and assignment
# stay interactive.
var production_paused: bool = false

# Robot production loop. Walks every region in the solar system each frame,
# accumulating progress for each (region, robot type) pair based on the robot's
# productionRate and the count assigned. When at least one whole unit of work
# has accumulated, debris is processed: region.trash decrements by 1, the
# region's drop table picks a resource via region.returnResource(), and the
# robot's resourceReturn (which can be fractional, e.g. Atomizer 0.4 or
# Recycler 2.5) accumulates into a per-(region, resource) carry pool that
# drains whole integer amounts to GlobalResources.gotResource().
#
# Pollution is tracked on a separate per-(region, robot) carry pool that
# accumulates count * robot.pollutionEffect * delta — independent of the
# pollution-level production multiplier and TechTree global multiplier, but
# still gated on region.trash > 0. cleaner_scalar still scales negative
# pollutionEffect (it's a pollution-system tech).

# Dictionary[RegionData -> Dictionary[RobotData -> float]]
var _progress: Dictionary = {}
# Dictionary[RegionData -> Dictionary[String -> float]]
var _resource_carry: Dictionary = {}
# Dictionary[RegionData -> Dictionary[RobotData -> float]]
var _pollution_carry_per_robot: Dictionary = {}
# Dictionary[RegionData -> Dictionary[BuildingData -> float]] — auto-process progress
var _building_progress: Dictionary = {}

# Seconds between auto-process actions per staffed worker. Each worker fires
# one BuildingData.process_amount drain on this period.
const AUTO_PROCESS_PERIOD: float = 2.0


func clear_carry_state() -> void:
	_progress.clear()
	_resource_carry.clear()
	_pollution_carry_per_robot.clear()
	_building_progress.clear()


## Serializable snapshot: outer keys are region resource_path strings; inner
## robot keys are robot resource_path strings. resource_carry inner keys are
## lowercase resource strings.
func get_carry_snapshot() -> Dictionary:
	var progress: Dictionary = {}
	var res_carry: Dictionary = {}
	var pol_carry: Dictionary = {}
	for region in _progress:
		var rp: String = region.resource_path
		if rp.is_empty():
			continue
		var inner: Dictionary = {}
		for robot in _progress[region]:
			var botp: String = robot.resource_path
			if botp.is_empty():
				continue
			inner[botp] = float(_progress[region][robot])
		progress[rp] = inner
	for region in _resource_carry:
		var rp2: String = region.resource_path
		if rp2.is_empty():
			continue
		var inner2: Dictionary = {}
		for res_key in _resource_carry[region]:
			inner2[str(res_key)] = float(_resource_carry[region][res_key])
		res_carry[rp2] = inner2
	for region in _pollution_carry_per_robot:
		var rp3: String = region.resource_path
		if rp3.is_empty():
			continue
		var inner3: Dictionary = {}
		for robot in _pollution_carry_per_robot[region]:
			var botp2: String = robot.resource_path
			if botp2.is_empty():
				continue
			inner3[botp2] = float(_pollution_carry_per_robot[region][robot])
		pol_carry[rp3] = inner3
	return {
		"progress": progress,
		"resource_carry": res_carry,
		"pollution_carry": pol_carry,
	}


func set_carry_snapshot(data: Dictionary) -> void:
	clear_carry_state()
	if typeof(data) != TYPE_DICTIONARY:
		return
	var progress: Variant = data.get("progress", {})
	var res_carry: Variant = data.get("resource_carry", {})
	var pol_carry: Variant = data.get("pollution_carry", {})
	if typeof(progress) == TYPE_DICTIONARY:
		for region_path in progress:
			var region: RegionData = _resolve_region(str(region_path))
			if region == null:
				continue
			var inner: Dictionary = {}
			var inner_raw: Variant = progress[region_path]
			if typeof(inner_raw) != TYPE_DICTIONARY:
				continue
			for robot_path in inner_raw:
				var robot: RobotData = _resolve_robot(str(robot_path))
				if robot == null:
					continue
				inner[robot] = float(inner_raw[robot_path])
			_progress[region] = inner
	if typeof(res_carry) == TYPE_DICTIONARY:
		for region_path in res_carry:
			var region2: RegionData = _resolve_region(str(region_path))
			if region2 == null:
				continue
			var innerc: Dictionary = {}
			var inner_raw2: Variant = res_carry[region_path]
			if typeof(inner_raw2) != TYPE_DICTIONARY:
				continue
			for res_key in inner_raw2:
				innerc[str(res_key).to_lower()] = float(inner_raw2[res_key])
			_resource_carry[region2] = innerc
	if typeof(pol_carry) == TYPE_DICTIONARY:
		for region_path in pol_carry:
			var region3: RegionData = _resolve_region(str(region_path))
			if region3 == null:
				continue
			var innerp: Dictionary = {}
			var inner_raw3: Variant = pol_carry[region_path]
			if typeof(inner_raw3) != TYPE_DICTIONARY:
				continue
			for robot_path in inner_raw3:
				var robot2: RobotData = _resolve_robot(str(robot_path))
				if robot2 == null:
					continue
				innerp[robot2] = float(inner_raw3[robot_path])
			_pollution_carry_per_robot[region3] = innerp


func _resolve_region(path: String) -> RegionData:
	var ss: SolarSystemData = GlobalResources.solarSystem
	if ss == null or path.is_empty():
		return null
	for planet in ss.planets:
		for region in planet.regions:
			if region.resource_path == path:
				return region
	return null


func _resolve_robot(path: String) -> RobotData:
	var coll: RobotCollection = GlobalResources.robots
	if coll == null or path.is_empty():
		return null
	for bot in coll.robots:
		if bot.resource_path == path:
			return bot
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveGame.save_to_user()


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
	if production_paused:
		return
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
			if region.assignedRobots.is_empty() and region.buildingWorkers.is_empty() and (pollution_decay == 0 or region.pollution <= 0):
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
	var region_pollution_carry: Dictionary = _pollution_carry_per_robot.get(region, {})
	var trash_changed := false
	var pollution_changed := false

	# Carbon Capture / similar techs: passive pollution decay on assigned regions.
	if pollution_decay != 0 and region.pollution > 0:
		var decayed: int = clamp(region.pollution + pollution_decay, 0, region.maxPollution)
		if decayed != region.pollution:
			region.pollution = decayed
			pollution_changed = true

	# Storage updates accumulated across both deposit and auto-process passes,
	# emitted once per affected building at the end of the tick.
	var storage_dirty: Dictionary = {}

	if region.trash <= 0 or region.assignedRobots.is_empty():
		_progress[region] = region_progress
		_resource_carry[region] = region_carry
		_pollution_carry_per_robot[region] = region_pollution_carry
		_run_auto_process(region, delta, storage_dirty)
		for b in storage_dirty:
			GlobalSignals.buildingStorageUpdated.emit(region, b)
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

			var res: String = region.returnResource()
			if res == "":
				continue

			var key := res.to_lower()
			var pooled: float = region_carry.get(key, 0.0) + float(robot.resourceReturn)
			var whole: int = int(floor(pooled))
			if whole > 0:
				for _i in range(whole):
					var deposited_into = region.depositResource(key)
					if deposited_into != null:
						storage_dirty[deposited_into] = true
					# else: storage full or no buildings — drop discarded
				pooled -= float(whole)
			region_carry[key] = pooled

		region_progress[robot] = progress

		# Pollution accumulator: independent of cleanup speed and pollution_mult,
		# but still gated on region.trash > 0 (function-level early return above).
		var effective_rate: float = robot.pollutionEffect
		if effective_rate < 0.0:
			effective_rate *= cleaner_scalar
		if effective_rate != 0.0:
			var carry: float = region_pollution_carry.get(robot, 0.0)
			carry += float(count) * effective_rate * delta
			var drain: int = 0
			if carry >= 1.0:
				drain = int(floor(carry))
				carry -= float(drain)
			elif carry <= -1.0:
				drain = int(ceil(carry))
				carry -= float(drain)
			if drain != 0:
				var new_pollution: int = clamp(region.pollution + drain, 0, region.maxPollution)
				if new_pollution != region.pollution:
					region.pollution = new_pollution
					pollution_changed = true
			region_pollution_carry[robot] = carry

	_progress[region] = region_progress
	_resource_carry[region] = region_carry
	_pollution_carry_per_robot[region] = region_pollution_carry

	_run_auto_process(region, delta, storage_dirty)
	for b in storage_dirty:
		GlobalSignals.buildingStorageUpdated.emit(region, b)

	return {"trash": trash_changed, "pollution": pollution_changed}


# Drains storage on a per-(region, building) tick: each staffed worker fires
# one BuildingData.process_amount drain every AUTO_PROCESS_PERIOD seconds.
# Marks affected buildings in `storage_dirty` so the caller emits the signal.
func _run_auto_process(region: RegionData, delta: float, storage_dirty: Dictionary) -> void:
	if region.buildingWorkers.is_empty():
		return
	var per_region: Dictionary = _building_progress.get(region, {})
	for b in region.buildingWorkers:
		var workers: int = region.workerCount(b)
		if workers <= 0:
			continue
		var progress: float = per_region.get(b, 0.0)
		progress += float(workers) * delta / AUTO_PROCESS_PERIOD
		while progress >= 1.0:
			progress -= 1.0
			var moved: Dictionary = region.processBuilding(b)
			if moved.is_empty():
				progress = 0.0
				break
			for res in moved:
				GlobalResources.gotResource(str(res), int(moved[res]))
			storage_dirty[b] = true
		per_region[b] = progress
	_building_progress[region] = per_region
