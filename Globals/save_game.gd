extends Node

## JSON save/load under `user://`. Autoload order: after TechTree.

const SAVE_VERSION: int = 2
const DEFAULT_SAVE_PATH: String = "user://save.json"
const SOLAR_SYSTEM_PATH: String = "res://Resources/SolarSystem/SolarSystem.tres"
const ROBOTS_PATH: String = "res://Resources/Robots/Robots.tres"

var _post_reset_emit_save_loaded: bool = false

# Snapshots taken once at startup (before save load) for "New game" reset.
# SolarSystemData.duplicate(true) does NOT duplicate external RegionData .tres
# instances — they stay aliased to GlobalResources — so we store per-region
# Resource.duplicate(true) and plain dicts for planet/robot runtime fields.
var _pristine_regions: Dictionary = {}
var _pristine_planet_meta: Dictionary = {}
var _pristine_robot_amounts: Dictionary = {}
var _pristine_building_amounts: Dictionary = {}


func _ready() -> void:
	_capture_pristine_template()
	if load_from_user():
		call_deferred("_emit_refresh_after_load")


func _capture_pristine_template() -> void:
	_pristine_regions.clear()
	_pristine_planet_meta.clear()
	_pristine_robot_amounts.clear()
	_pristine_building_amounts.clear()

	var ss: SolarSystemData = GlobalResources.solarSystem
	if ss != null:
		for planet in ss.planets:
			var ppath: String = planet.resource_path
			if not ppath.is_empty():
				_pristine_planet_meta[ppath] = {
					"cumulativeTrashCleaned": planet.cumulativeTrashCleaned,
					"cumulativeMilestonesAwarded": planet.cumulativeMilestonesAwarded,
				}
			for region in planet.regions:
				var rpath: String = region.resource_path
				if rpath.is_empty():
					continue
				_pristine_regions[rpath] = region.duplicate(true) as RegionData

	var coll: RobotCollection = GlobalResources.robots
	if coll != null:
		for bot in coll.robots:
			var bpath: String = bot.resource_path
			if bpath.is_empty():
				continue
			_pristine_robot_amounts[bpath] = int(bot.amount)

	var bcoll: BuildingCollection = GlobalResources.buildings
	if bcoll != null:
		for b in bcoll.buildings:
			var bp: String = b.resource_path
			if bp.is_empty():
				continue
			_pristine_building_amounts[bp] = int(b.amount)


func consume_post_reset_refresh() -> bool:
	if not _post_reset_emit_save_loaded:
		return false
	_post_reset_emit_save_loaded = false
	_emit_refresh_after_load()
	return true


func save_to_user(path: String = DEFAULT_SAVE_PATH) -> bool:
	var data: Dictionary = _build_snapshot()
	var json_text: String = JSON.stringify(data, "\t")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: could not open %s for write (error %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(json_text)
	f.close()
	return true


func load_from_user(path: String = DEFAULT_SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SaveGame: could not open %s for read" % path)
		return false
	var json_text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveGame: invalid JSON in %s" % path)
		return false
	return _apply_snapshot(parsed as Dictionary)


func reset_to_new_game() -> void:
	_delete_save_file()
	TechTree.unlockedLevels.clear()
	GameManager.production_paused = false
	GameManager.clear_carry_state()
	GlobalResources.apply_new_game_inventory()
	_apply_template_from_disk()
	_post_reset_emit_save_loaded = true
	get_tree().reload_current_scene()


func _delete_save_file() -> void:
	if not FileAccess.file_exists(DEFAULT_SAVE_PATH):
		return
	var dir_path: String = DEFAULT_SAVE_PATH.get_base_dir()
	var file_name: String = DEFAULT_SAVE_PATH.get_file()
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		push_warning("SaveGame: could not open %s to delete save" % dir_path)
		return
	if d.file_exists(file_name):
		var err: Error = d.remove(file_name)
		if err != OK:
			push_warning("SaveGame: remove save failed (%d)" % err)


func _build_snapshot() -> Dictionary:
	var pinned_path: String = ""
	if GlobalResources.pinnedRegion != null:
		pinned_path = GlobalResources.pinnedRegion.resource_path

	var robots_arr: Array = []
	var coll: RobotCollection = GlobalResources.robots
	if coll != null:
		for bot in coll.robots:
			if bot.resource_path.is_empty():
				continue
			robots_arr.append({"path": bot.resource_path, "amount": int(bot.amount)})

	var buildings_arr: Array = []
	var bcoll: BuildingCollection = GlobalResources.buildings
	if bcoll != null:
		for b in bcoll.buildings:
			if b.resource_path.is_empty():
				continue
			buildings_arr.append({"path": b.resource_path, "amount": int(b.amount)})

	var tech_unlocks: Dictionary = {}
	for tech in TechTree.unlockedLevels:
		if tech == null:
			continue
		var lvl: int = int(TechTree.unlockedLevels[tech])
		if lvl <= 0:
			continue
		var tid: String = tech.id
		if tid.is_empty():
			continue
		tech_unlocks[tid] = lvl

	return {
		"save_version": SAVE_VERSION,
		"globals": {
			"playerResources": GlobalResources.playerResources.duplicate(),
			"globalMultiplier": GlobalResources.globalMultiplier,
			"multipliers": GlobalResources.multipliers.duplicate(),
			"pinned_region_path": pinned_path,
		},
		"robots": robots_arr,
		"buildings": buildings_arr,
		"tech": tech_unlocks,
		"planets": _collect_planets_array(),
		"carry": GameManager.get_carry_snapshot(),
	}


func _collect_planets_array() -> Array:
	var out: Array = []
	var ss: SolarSystemData = GlobalResources.solarSystem
	if ss == null:
		return out
	for planet in ss.planets:
		var reg_arr: Array = []
		for region in planet.regions:
			var assigned: Dictionary = {}
			for robot in region.assignedRobots:
				if robot.resource_path.is_empty():
					continue
				assigned[robot.resource_path] = int(region.assignedRobots[robot])
			var assigned_buildings: Dictionary = {}
			for b in region.assignedBuildings:
				if b.resource_path.is_empty():
					continue
				assigned_buildings[b.resource_path] = int(region.assignedBuildings[b])
			var building_storage: Dictionary = {}
			for b in region.buildingStorage:
				if b.resource_path.is_empty():
					continue
				var inner: Dictionary = {}
				for res_key in region.buildingStorage[b]:
					inner[str(res_key)] = int(region.buildingStorage[b][res_key])
				building_storage[b.resource_path] = inner
			var building_workers: Dictionary = {}
			for b in region.buildingWorkers:
				if b.resource_path.is_empty():
					continue
				var winner: Dictionary = {}
				for robot in region.buildingWorkers[b]:
					if robot.resource_path.is_empty():
						continue
					winner[robot.resource_path] = int(region.buildingWorkers[b][robot])
				building_workers[b.resource_path] = winner
			reg_arr.append({
				"path": region.resource_path,
				"locked": region.locked,
				"trash": region.trash,
				"pollution": region.pollution,
				"researchMilestonesAwarded": region.researchMilestonesAwarded,
				"assigned": assigned,
				"assignedBuildings": assigned_buildings,
				"buildingStorage": building_storage,
				"buildingWorkers": building_workers,
			})
		out.append({
			"path": planet.resource_path,
			"cumulativeTrashCleaned": planet.cumulativeTrashCleaned,
			"cumulativeMilestonesAwarded": planet.cumulativeMilestonesAwarded,
			"regions": reg_arr,
		})
	return out


func _apply_snapshot(root: Dictionary) -> bool:
	var ver: int = int(root.get("save_version", 0))
	if ver != SAVE_VERSION:
		push_warning("SaveGame: unsupported save_version %d (expected %d)" % [ver, SAVE_VERSION])
		return false

	var globals_raw: Variant = root.get("globals", {})
	if typeof(globals_raw) != TYPE_DICTIONARY:
		return false
	var g: Dictionary = globals_raw

	# Tech first (affects costs / multipliers used elsewhere)
	TechTree.unlockedLevels.clear()
	var tech_raw: Variant = root.get("tech", {})
	if typeof(tech_raw) == TYPE_DICTIONARY:
		var id_to_tech: Dictionary = _build_tech_id_map()
		for tid in tech_raw:
			var tech: TechData = id_to_tech.get(str(tid), null) as TechData
			if tech == null:
				continue
			var lvl: int = int(tech_raw[tid])
			if lvl > 0:
				TechTree.unlockedLevels[tech] = lvl

	var pr: Variant = g.get("playerResources", {})
	if typeof(pr) == TYPE_DICTIONARY:
		GlobalResources.playerResources.clear()
		for k in pr:
			GlobalResources.playerResources[str(k).to_lower()] = int(pr[k])

	GlobalResources.globalMultiplier = int(g.get("globalMultiplier", 1))
	var mult: Variant = g.get("multipliers", {})
	if typeof(mult) == TYPE_DICTIONARY:
		GlobalResources.multipliers.clear()
		for k in mult:
			GlobalResources.multipliers[str(k).to_lower()] = int(mult[k])

	for k in GlobalResources.DEFAULT_PLAYER_RESOURCES:
		if not GlobalResources.playerResources.has(k):
			GlobalResources.playerResources[k] = int(GlobalResources.DEFAULT_PLAYER_RESOURCES[k])

	_apply_planets_array(root.get("planets", []))
	_apply_robots_array(root.get("robots", []))
	_apply_buildings_array(root.get("buildings", []))

	var carry_raw: Variant = root.get("carry", {})
	if typeof(carry_raw) == TYPE_DICTIONARY:
		GameManager.set_carry_snapshot(carry_raw)

	var pin_path: String = str(g.get("pinned_region_path", ""))
	if pin_path.is_empty():
		GlobalResources.pinnedRegion = null
	else:
		GlobalResources.pinnedRegion = _find_region_by_path(pin_path)

	return true


func _apply_template_from_disk() -> void:
	if _pristine_regions.is_empty():
		push_error("SaveGame: pristine region snapshot missing; cannot reset world state")
		return

	for ppath: String in _pristine_planet_meta:
		var live_p: PlanetData = _find_planet_by_path(ppath)
		if live_p == null:
			continue
		var meta: Variant = _pristine_planet_meta[ppath]
		if typeof(meta) == TYPE_DICTIONARY:
			var md: Dictionary = meta
			live_p.cumulativeTrashCleaned = int(md.get("cumulativeTrashCleaned", 0))
			live_p.cumulativeMilestonesAwarded = int(md.get("cumulativeMilestonesAwarded", 0))

	for rpath: String in _pristine_regions:
		var pr: RegionData = _pristine_regions[rpath] as RegionData
		if pr == null:
			continue
		var live_r: RegionData = _find_region_by_path(rpath)
		if live_r == null:
			continue
		live_r.locked = pr.locked
		live_r.trash = pr.trash
		live_r.pollution = pr.pollution
		live_r.researchMilestonesAwarded = pr.researchMilestonesAwarded
		live_r.assignedRobots.clear()
		live_r.assignedBuildings.clear()
		live_r.buildingStorage.clear()
		live_r.buildingWorkers.clear()

	for bpath: String in _pristine_robot_amounts:
		var live_bot: RobotData = _find_robot_by_path(bpath)
		if live_bot == null:
			continue
		live_bot.amount = int(_pristine_robot_amounts[bpath])

	for bpath2: String in _pristine_building_amounts:
		var live_b: BuildingData = _find_building_by_path(bpath2)
		if live_b == null:
			continue
		live_b.amount = int(_pristine_building_amounts[bpath2])


func _apply_planets_array(arr: Variant) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var planet: PlanetData = _find_planet_by_path(str(d.get("path", "")))
		if planet == null:
			continue
		planet.cumulativeTrashCleaned = int(d.get("cumulativeTrashCleaned", 0))
		planet.cumulativeMilestonesAwarded = int(d.get("cumulativeMilestonesAwarded", 0))
		var regs: Variant = d.get("regions", [])
		if typeof(regs) != TYPE_ARRAY:
			continue
		for reg_item in regs:
			if typeof(reg_item) != TYPE_DICTIONARY:
				continue
			var rd: Dictionary = reg_item
			var region: RegionData = _find_region_by_path(str(rd.get("path", "")))
			if region == null:
				continue
			region.locked = bool(rd.get("locked", false))
			region.trash = int(rd.get("trash", 0))
			region.pollution = int(rd.get("pollution", 0))
			region.researchMilestonesAwarded = int(rd.get("researchMilestonesAwarded", 0))
			region.assignedRobots.clear()
			var asg: Variant = rd.get("assigned", {})
			if typeof(asg) == TYPE_DICTIONARY:
				for bot_path in asg:
					var bot: RobotData = _find_robot_by_path(str(bot_path))
					if bot == null:
						continue
					var cnt: int = int(asg[bot_path])
					if cnt > 0:
						region.assignedRobots[bot] = cnt

			region.assignedBuildings.clear()
			region.buildingStorage.clear()
			region.buildingWorkers.clear()

			var asgb: Variant = rd.get("assignedBuildings", {})
			if typeof(asgb) == TYPE_DICTIONARY:
				for bpath in asgb:
					var b: BuildingData = _find_building_by_path(str(bpath))
					if b == null:
						continue
					var bcnt: int = int(asgb[bpath])
					if bcnt > 0:
						region.assignedBuildings[b] = bcnt

			var stg: Variant = rd.get("buildingStorage", {})
			if typeof(stg) == TYPE_DICTIONARY:
				for bpath in stg:
					var b2: BuildingData = _find_building_by_path(str(bpath))
					if b2 == null:
						continue
					var inner_raw: Variant = stg[bpath]
					if typeof(inner_raw) != TYPE_DICTIONARY:
						continue
					var inner: Dictionary = {}
					for res_key in inner_raw:
						inner[str(res_key).to_lower()] = int(inner_raw[res_key])
					if not inner.is_empty():
						region.buildingStorage[b2] = inner

			var wrk: Variant = rd.get("buildingWorkers", {})
			if typeof(wrk) == TYPE_DICTIONARY:
				for bpath in wrk:
					var b3: BuildingData = _find_building_by_path(str(bpath))
					if b3 == null:
						continue
					var winner_raw: Variant = wrk[bpath]
					if typeof(winner_raw) != TYPE_DICTIONARY:
						continue
					var winner: Dictionary = {}
					for bot_path in winner_raw:
						var bot2: RobotData = _find_robot_by_path(str(bot_path))
						if bot2 == null:
							continue
						var wcnt: int = int(winner_raw[bot_path])
						if wcnt > 0:
							winner[bot2] = wcnt
					if not winner.is_empty():
						region.buildingWorkers[b3] = winner


func _apply_robots_array(arr: Variant) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var bot: RobotData = _find_robot_by_path(str(d.get("path", "")))
		if bot == null:
			continue
		bot.amount = int(d.get("amount", 0))


func _apply_buildings_array(arr: Variant) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var b: BuildingData = _find_building_by_path(str(d.get("path", "")))
		if b == null:
			continue
		b.amount = int(d.get("amount", 0))


func _find_building_by_path(path: String) -> BuildingData:
	if path.is_empty():
		return null
	var coll: BuildingCollection = GlobalResources.buildings
	if coll == null:
		return null
	for b in coll.buildings:
		if b.resource_path == path:
			return b
	return null


func _find_planet_by_path(path: String) -> PlanetData:
	if path.is_empty():
		return null
	var ss: SolarSystemData = GlobalResources.solarSystem
	if ss == null:
		return null
	for p in ss.planets:
		if p.resource_path == path:
			return p
	return null


func _find_region_by_path(path: String) -> RegionData:
	if path.is_empty():
		return null
	var ss: SolarSystemData = GlobalResources.solarSystem
	if ss == null:
		return null
	for p in ss.planets:
		for r in p.regions:
			if r.resource_path == path:
				return r
	return null


func _find_robot_by_path(path: String) -> RobotData:
	if path.is_empty():
		return null
	var coll: RobotCollection = GlobalResources.robots
	if coll == null:
		return null
	for bot in coll.robots:
		if bot.resource_path == path:
			return bot
	return null


func _build_tech_id_map() -> Dictionary:
	var out: Dictionary = {}
	if TechTree.collection == null:
		return out
	for tech in TechTree.collection.techs:
		if tech == null:
			continue
		if not tech.id.is_empty():
			out[tech.id] = tech
	return out


func _emit_refresh_after_load() -> void:
	GlobalSignals.resourcesUpdated.emit(GlobalResources.playerResources)
	var ss: SolarSystemData = GlobalResources.solarSystem
	if ss != null:
		for planet in ss.planets:
			for region in planet.regions:
				GlobalSignals.regionTrashUpdated.emit(region)
				GlobalSignals.regionPollutionUpdated.emit(region)
			GlobalSignals.planetTrashUpdated.emit(planet)
			GlobalSignals.planetPollutionUpdated.emit(planet)
	var coll: RobotCollection = GlobalResources.robots
	if coll != null:
		for bot in coll.robots:
			GlobalSignals.robotPurchased.emit(bot)
	var bcoll: BuildingCollection = GlobalResources.buildings
	if bcoll != null:
		for b in bcoll.buildings:
			GlobalSignals.buildingPurchased.emit(b)
	GlobalSignals.saveLoaded.emit()
