extends Node

## JSON save/load under `user://`. Autoload order: after TechTree.

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://save.json"
const SOLAR_SYSTEM_PATH: String = "res://Resources/SolarSystem/SolarSystem.tres"
const ROBOTS_PATH: String = "res://Resources/Robots/Robots.tres"

var _post_reset_emit_save_loaded: bool = false


func _ready() -> void:
	if load_from_user():
		call_deferred("_emit_refresh_after_load")


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
			reg_arr.append({
				"path": region.resource_path,
				"locked": region.locked,
				"trash": region.trash,
				"pollution": region.pollution,
				"researchMilestonesAwarded": region.researchMilestonesAwarded,
				"assigned": assigned,
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
	var tpl_ss: SolarSystemData = ResourceLoader.load(
		SOLAR_SYSTEM_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as SolarSystemData
	var tpl_robots: RobotCollection = ResourceLoader.load(
		ROBOTS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RobotCollection
	if tpl_ss == null or tpl_robots == null:
		push_error("SaveGame: failed to load template world/robots")
		return

	for tpl_p in tpl_ss.planets:
		var live_p: PlanetData = _find_planet_by_path(tpl_p.resource_path)
		if live_p == null:
			continue
		live_p.cumulativeTrashCleaned = tpl_p.cumulativeTrashCleaned
		live_p.cumulativeMilestonesAwarded = tpl_p.cumulativeMilestonesAwarded
		for tpl_r in tpl_p.regions:
			var live_r: RegionData = _find_region_by_path(tpl_r.resource_path)
			if live_r == null:
				continue
			live_r.locked = tpl_r.locked
			live_r.trash = tpl_r.trash
			live_r.pollution = tpl_r.pollution
			live_r.researchMilestonesAwarded = tpl_r.researchMilestonesAwarded
			live_r.assignedRobots.clear()

	for tpl_bot in tpl_robots.robots:
		var live_bot: RobotData = _find_robot_by_path(tpl_bot.resource_path)
		if live_bot == null:
			continue
		live_bot.amount = tpl_bot.amount


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
	GlobalSignals.saveLoaded.emit()
