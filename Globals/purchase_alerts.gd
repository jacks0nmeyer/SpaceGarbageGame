extends Node

# Tracks the first time each purchase becomes affordable so the matching
# main-menu button can highlight once. Identity is per resource_path —
# every robot/building/tech fires at most once per playthrough, even though
# robot costs scale with `amount`. (Buildings/techs have flat costs anyway.)
#
# Categories: "robot", "building", "tech". Buttons subscribe via
# GlobalSignals.purchase_alert_changed(category, active).
#
# Suppression: while the matching panel is open, new tiers are still recorded
# as seen but the dirty flag is not raised — the player is already looking at
# the catalog, so a button-pulse on close would be noise.
#
# Save/load: state is session-local. On save_loaded (which fires from both
# load-from-file and reset_to_new_game) all currently-affordable tiers are
# pre-seeded as "seen" so loading a mature save does not blare alerts.

const CATEGORY_ROBOT := "robot"
const CATEGORY_BUILDING := "building"
const CATEGORY_TECH := "tech"

var _seen_robot_tiers: Dictionary = {}
var _seen_building_tiers: Dictionary = {}
var _seen_tech_tiers: Dictionary = {}

var has_new_robot: bool = false
var has_new_building: bool = false
var has_new_tech: bool = false

var _suppressed: Dictionary = {
	CATEGORY_ROBOT: false,
	CATEGORY_BUILDING: false,
	CATEGORY_TECH: false,
}


func _ready() -> void:
	GlobalSignals.resources_updated.connect(_on_resources_updated)
	GlobalSignals.robot_purchased.connect(_on_robot_purchased)
	GlobalSignals.building_purchased.connect(_on_building_purchased)
	GlobalSignals.tech_unlocked.connect(_on_tech_unlocked)
	GlobalSignals.save_loaded.connect(_on_save_loaded)


# --- Public API ---------------------------------------------------------------

func notify_panel_opened(category: String) -> void:
	_suppressed[category] = true
	_set_alert(category, false)


func notify_panel_closed(category: String) -> void:
	_suppressed[category] = false


func clear_alert(category: String) -> void:
	_set_alert(category, false)


# --- Signal handlers ----------------------------------------------------------

func _on_resources_updated(_resources: Dictionary) -> void:
	_check_all()


func _on_robot_purchased(_r: RobotData) -> void:
	_check_all()


func _on_building_purchased(_b: BuildingData) -> void:
	_check_all()


func _on_tech_unlocked(_t: TechData) -> void:
	# Tech unlocks can change robot costs (ROBOT_COST_SCALAR) and unlock
	# prereq-gated techs, so re-evaluate every category.
	_check_all()


func _on_save_loaded() -> void:
	_seen_robot_tiers.clear()
	_seen_building_tiers.clear()
	_seen_tech_tiers.clear()
	_suppressed[CATEGORY_ROBOT] = false
	_suppressed[CATEGORY_BUILDING] = false
	_suppressed[CATEGORY_TECH] = false
	_seed_seen_from_current_state()
	_set_alert(CATEGORY_ROBOT, false)
	_set_alert(CATEGORY_BUILDING, false)
	_set_alert(CATEGORY_TECH, false)


# --- Core check -------------------------------------------------------------

func _check_all() -> void:
	_check_robots()
	_check_buildings()
	_check_tech()


func _check_robots() -> void:
	if GlobalResources.robots == null:
		return
	var any_new := false
	for bot in GlobalResources.robots.robots:
		if bot == null:
			continue
		var key: String = bot.resource_path
		if key.is_empty() or _seen_robot_tiers.has(key):
			continue
		var cost: Dictionary = _robot_cost(bot)
		if cost.is_empty():
			continue
		if GlobalResources.can_afford(cost):
			_seen_robot_tiers[key] = true
			any_new = true
	if any_new and not _suppressed.get(CATEGORY_ROBOT, false):
		_set_alert(CATEGORY_ROBOT, true)


func _check_buildings() -> void:
	if GlobalResources.buildings == null:
		return
	var any_new := false
	for b in GlobalResources.buildings.buildings:
		if b == null:
			continue
		var cost: Dictionary = _building_cost(b)
		if cost.is_empty():
			continue
		var sig: String = _signature(b.resource_path, cost)
		if _seen_building_tiers.has(sig):
			continue
		if GlobalResources.can_afford(cost):
			_seen_building_tiers[sig] = true
			any_new = true
	if any_new and not _suppressed.get(CATEGORY_BUILDING, false):
		_set_alert(CATEGORY_BUILDING, true)


func _check_tech() -> void:
	if TechTree.collection == null:
		return
	var any_new := false
	for tech in TechTree.collection.techs:
		if tech == null:
			continue
		if TechTree.is_unlocked(tech):
			continue
		if not _prereqs_met(tech):
			continue
		var cost: Dictionary = tech.cost_dict()
		if cost.is_empty():
			continue
		var sig: String = _signature(tech.resource_path, cost)
		if _seen_tech_tiers.has(sig):
			continue
		if GlobalResources.can_afford(cost):
			_seen_tech_tiers[sig] = true
			any_new = true
	if any_new and not _suppressed.get(CATEGORY_TECH, false):
		_set_alert(CATEGORY_TECH, true)


# --- Helpers ----------------------------------------------------------------

func _set_alert(category: String, active: bool) -> void:
	match category:
		CATEGORY_ROBOT:
			if has_new_robot == active:
				return
			has_new_robot = active
		CATEGORY_BUILDING:
			if has_new_building == active:
				return
			has_new_building = active
		CATEGORY_TECH:
			if has_new_tech == active:
				return
			has_new_tech = active
		_:
			return
	GlobalSignals.purchase_alert_changed.emit(category, active)


# Mirrors UI/RobotPanel/robot_row.gd::current_cost — kept inline rather than
# extracted to RobotData so the Resource layer doesn't gain a hard dependency
# on the TechTree autoload.
func _robot_cost(bot: RobotData) -> Dictionary:
	var dict: Dictionary = {}
	var multiplier: float = pow(bot.cost_increase, bot.amount)
	var tech_scalar: float = TechTree.get_robot_cost_scalar()
	for entry in bot.unlock_cost:
		dict[entry.resource] = max(1, int(round(entry.amount * multiplier * tech_scalar)))
	return dict


func _building_cost(b: BuildingData) -> Dictionary:
	return CostHelper.to_dict(b.unlock_cost)


func _prereqs_met(tech: TechData) -> bool:
	for prereq in tech.prerequisites:
		if not TechTree.is_unlocked(prereq):
			return false
	return true


# Stable string identity for an (item, cost) tier. Resource keys are lowercased
# so case differences in CostEntry data never invalidate seen-tier tracking.
func _signature(path: String, cost: Dictionary) -> String:
	var keys: Array = cost.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k in keys:
		parts.append("%s=%d" % [str(k).to_lower(), int(cost[k])])
	return "%s|%s" % [path, "|".join(parts)]


func _seed_seen_from_current_state() -> void:
	if GlobalResources.robots != null:
		for bot in GlobalResources.robots.robots:
			if bot == null or bot.resource_path.is_empty():
				continue
			var rcost: Dictionary = _robot_cost(bot)
			if rcost.is_empty():
				continue
			if GlobalResources.can_afford(rcost):
				_seen_robot_tiers[bot.resource_path] = true
	if GlobalResources.buildings != null:
		for b in GlobalResources.buildings.buildings:
			if b == null:
				continue
			var bcost: Dictionary = _building_cost(b)
			if bcost.is_empty():
				continue
			if GlobalResources.can_afford(bcost):
				_seen_building_tiers[_signature(b.resource_path, bcost)] = true
	if TechTree.collection != null:
		for tech in TechTree.collection.techs:
			if tech == null:
				continue
			if TechTree.is_unlocked(tech) or not _prereqs_met(tech):
				continue
			var tcost: Dictionary = tech.cost_dict()
			if tcost.is_empty():
				continue
			if GlobalResources.can_afford(tcost):
				_seen_tech_tiers[_signature(tech.resource_path, tcost)] = true
