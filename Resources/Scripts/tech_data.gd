class_name TechData
extends Resource

# One tech node in the tech tree. Effects are described declaratively via
# (effect_kind, effect_key, effect_amount) and queried by the TechTree autoload.
# Multi-level support is left in via `levels` but v1 uses single-level perks.

enum TechEffect {
	RESOURCE_MULTIPLIER,         # effect_key = resource name, effect_amount = additive bonus (+0.10)
	GLOBAL_PRODUCTION_RATE,      # effect_amount = multiplicative scalar (1.15)
	ROBOT_COST_SCALAR,           # effect_amount = multiplicative scalar (0.90)
	ROBOT_SIZE_DELTA,            # effect_amount = additive delta (-1)
	REGION_CAPACITY_DELTA,       # effect_amount = additive delta (+2)
	POLLUTION_MULT_OVERRIDE,     # effect_key = "CLEAN"/"LOW"/"HIGH"/"CRITICAL", effect_amount = new mult
	POLLUTION_DECAY,             # effect_amount = pollution change per tick (e.g. -1)
	CLEANER_STRENGTH_SCALAR,     # effect_amount = multiplicative scalar (1.25)
	CLICK_TRASH_AMOUNT,          # effect_amount = absolute trash-per-click override (max wins)
	CLICK_DOUBLE_CHANCE,         # effect_amount = probability (0.0 - 1.0) of 2x resource yield
	CLICK_POLLUTION_DELTA,       # effect_amount = pollution change per click (e.g. -1)
	MINING_STRENGTH_DELTA,       # effect_amount = additive asteroid-click damage delta (+1)
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Cost & Progression")
@export var cost: Array[CostEntry] = []
@export var levels: int = 1
@export var prerequisites: Array[TechData] = []

@export_group("Effect")
@export var effect_kind: TechEffect = TechEffect.RESOURCE_MULTIPLIER
@export var effect_key: String = ""
@export var effect_amount: float = 0.0

@export_group("Layout")
@export var position: Vector2 = Vector2.ZERO


# Cost as a Dictionary[resource -> amount] consumable by GlobalResources.purchase().
func cost_dict() -> Dictionary:
	return CostHelper.to_dict(cost)
