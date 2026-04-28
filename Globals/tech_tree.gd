extends Node

# TechTree autoload — owns unlocked-tech state and exposes a pull-style API
# that consumers (GlobalResources, GameManager, RegionData, click handler,
# robot-row) call when they need to apply tech effects. Effects are queried,
# not pushed: base values stay as design defaults.

const TECH_COLLECTION_PATH := "res://Resources/Tech/Tech.tres"

# Dictionary[TechData -> int] — current unlocked level per tech (0 = locked).
# v1 only uses 0/1 since every tech is single-level.
var unlockedLevels: Dictionary = {}

var collection: TechCollection = null


func _ready() -> void:
	if ResourceLoader.exists(TECH_COLLECTION_PATH):
		collection = load(TECH_COLLECTION_PATH)


# --- Unlock state ---------------------------------------------------------

func is_unlocked(tech: TechData) -> bool:
	if tech == null:
		return false
	return int(unlockedLevels.get(tech, 0)) >= 1


func can_unlock(tech: TechData) -> bool:
	if tech == null or is_unlocked(tech):
		return false
	for prereq in tech.prerequisites:
		if not is_unlocked(prereq):
			return false
	return GlobalResources.can_afford(tech.cost_dict())


# Attempt to spend the tech cost and unlock it. Returns true on success.
func unlock(tech: TechData) -> bool:
	if not can_unlock(tech):
		return false
	if not GlobalResources.purchase(tech.cost_dict()):
		return false
	unlockedLevels[tech] = int(unlockedLevels.get(tech, 0)) + 1
	GlobalSignals.techUnlocked.emit(tech)
	return true


# --- Effect queries -------------------------------------------------------

# Multiplicative scalar applied to gotResource() yields. Each unlocked
# RESOURCE_MULTIPLIER tech matching the given resource adds its effectAmount
# (e.g. +0.10) to the base 1.0.
func get_resource_multiplier(resource: String) -> float:
	var key := resource.to_lower()
	var bonus := 0.0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.RESOURCE_MULTIPLIER \
				and tech.effectKey.to_lower() == key:
			bonus += tech.effectAmount
	return 1.0 + bonus


# Multiplicative scalar applied to robot productionRate per tick. Stacks
# multiplicatively across techs.
func get_global_production_multiplier() -> float:
	var mult := 1.0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.GLOBAL_PRODUCTION_RATE:
			mult *= tech.effectAmount
	return mult


# Multiplicative scalar applied to robot purchase costs (e.g. 0.90 = -10%).
# Stacks multiplicatively.
func get_robot_cost_scalar() -> float:
	var mult := 1.0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.ROBOT_COST_SCALAR:
			mult *= tech.effectAmount
	return mult


# Additive delta applied to robot.size when computing slot usage. Sum across
# all unlocked ROBOT_SIZE_DELTA techs.
func get_robot_size_modifier() -> int:
	var delta := 0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.ROBOT_SIZE_DELTA:
			delta += int(tech.effectAmount)
	return delta


# Additive bonus to a region's robot_capacity.
func get_region_capacity_bonus() -> int:
	var delta := 0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.REGION_CAPACITY_DELTA:
			delta += int(tech.effectAmount)
	return delta


# Sum of all POLLUTION_DECAY techs — applied to assigned regions per tick.
# Sign convention: negative values reduce pollution.
func get_pollution_decay_per_tick() -> int:
	var delta := 0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.POLLUTION_DECAY:
			delta += int(tech.effectAmount)
	return delta


# Multiplicative scalar applied to robot.pollutionEffect when negative
# (i.e. cleaning). Positive (polluting) effects are unaffected.
func get_cleaner_strength_scalar() -> float:
	var mult := 1.0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.CLEANER_STRENGTH_SCALAR:
			mult *= tech.effectAmount
	return mult


# Override for getPollutionProductionMultiplier(). Returns NAN when no tech
# overrides this level — caller should fall back to default.
func get_pollution_multiplier(level: int) -> float:
	var key: String = GlobalResources.PollutionLevel.keys()[level]
	var override := NAN
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.POLLUTION_MULT_OVERRIDE \
				and tech.effectKey.to_upper() == key.to_upper():
			# Last unlocked wins; v1 has at most one override per level.
			override = tech.effectAmount
	return override


# Trash removed per manual click. Default 1; max-wins across all unlocked
# CLICK_TRASH_AMOUNT techs (so Crowbar's 5 supersedes Gloves' 2).
func get_click_trash_amount() -> int:
	var amount := 1
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.CLICK_TRASH_AMOUNT:
			amount = max(amount, int(tech.effectAmount))
	return amount


# Probability [0..1] that a manual click yields 2x resources. Sums across
# techs (v1 only has Salvage Eye so it's just 0.15).
func get_click_double_chance() -> float:
	var chance := 0.0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.CLICK_DOUBLE_CHANCE:
			chance += tech.effectAmount
	return clamp(chance, 0.0, 1.0)


# Pollution change applied to the region per manual click (negative cleans).
func get_click_pollution_bonus() -> int:
	var delta := 0
	for tech in unlockedLevels:
		if not is_unlocked(tech):
			continue
		if tech.effectKind == TechData.TechEffect.CLICK_POLLUTION_DELTA:
			delta += int(tech.effectAmount)
	return delta
