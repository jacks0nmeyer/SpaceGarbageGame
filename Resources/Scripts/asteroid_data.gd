class_name AsteroidData
extends Resource

# A single asteroid archetype: art, HP, drop table, spawn weight.
# Authored as .tres in Resources/Asteroids/.

@export var displayName: String = ""

@export_group("Visuals")
@export var texture: Texture2D
@export var damageDotTexture: Texture2D

@export_group("Combat")
@export var maxHp: int = 3
# If the player's mining strength is below this, clicks do no damage and emit
# asteroidDeflected for a "clink" visual instead.
@export var minStrengthToCrack: int = 1

@export_group("Spawn")
@export var spawnWeight: float = 1.0
@export var speedMin: float = 60.0
@export var speedMax: float = 120.0

@export_group("Drops")
@export var resourceChances: Array[ResourceEntry] = []
@export var yieldMin: int = 1
@export var yieldMax: int = 3


# Build a Dictionary[resource -> chance] for GlobalResources.weighted_random.
func _weights() -> Dictionary:
	var w := {}
	for e in resourceChances:
		if e.chance > 0.0:
			w[e.resource] = e.chance
	return w


# Roll `randi_range(yieldMin, yieldMax)` weighted picks and aggregate them.
# Returns Dictionary[resource_name -> count].
func rollDrops() -> Dictionary:
	var weights := _weights()
	if weights.is_empty():
		return {}
	var roll_count: int = randi_range(yieldMin, yieldMax)
	var out: Dictionary = {}
	for _i in roll_count:
		var res: String = GlobalResources.weighted_random(weights)
		out[res] = int(out.get(res, 0)) + 1
	return out
