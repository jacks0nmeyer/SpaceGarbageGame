class_name TechData
extends Resource

# One tech node in the tech tree. Effects are described declaratively via
# (effectKind, effectKey, effectAmount) and queried by the TechTree autoload.
# Multi-level support is left in via `levels` but v1 uses single-level perks.

enum TechEffect {
	RESOURCE_MULTIPLIER,         # effectKey = resource name, effectAmount = additive bonus (+0.10)
	GLOBAL_PRODUCTION_RATE,      # effectAmount = multiplicative scalar (1.15)
	ROBOT_COST_SCALAR,           # effectAmount = multiplicative scalar (0.90)
	ROBOT_SIZE_DELTA,            # effectAmount = additive delta (-1)
	REGION_CAPACITY_DELTA,       # effectAmount = additive delta (+2)
	POLLUTION_MULT_OVERRIDE,     # effectKey = "CLEAN"/"LOW"/"HIGH"/"CRITICAL", effectAmount = new mult
	POLLUTION_DECAY,             # effectAmount = pollution change per tick (e.g. -1)
	CLEANER_STRENGTH_SCALAR,     # effectAmount = multiplicative scalar (1.25)
	CLICK_TRASH_AMOUNT,          # effectAmount = absolute trash-per-click override (max wins)
	CLICK_DOUBLE_CHANCE,         # effectAmount = probability (0.0 - 1.0) of 2x resource yield
	CLICK_POLLUTION_DELTA,       # effectAmount = pollution change per click (e.g. -1)
	MINING_STRENGTH_DELTA,       # effectAmount = additive asteroid-click damage delta (+1)
}

@export var id: String = ""
@export var displayName: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Cost & Progression")
@export var cost: Array[CostEntry] = []
@export var levels: int = 1
@export var prerequisites: Array[TechData] = []

@export_group("Effect")
@export var effectKind: TechEffect = TechEffect.RESOURCE_MULTIPLIER
@export var effectKey: String = ""
@export var effectAmount: float = 0.0

@export_group("Layout")
@export var position: Vector2 = Vector2.ZERO


# Cost as a Dictionary[resource -> amount] consumable by GlobalResources.purchase().
func cost_dict() -> Dictionary:
	var dict := {}
	for entry in cost:
		dict[entry.resource] = entry.amount
	return dict
