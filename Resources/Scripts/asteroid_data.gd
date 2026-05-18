class_name AsteroidData
extends Resource

# A single asteroid archetype: art, HP, drop table, spawn weight.
# Authored as .tres in Resources/Asteroids/.

@export var display_name: String = ""

@export_group("Visuals")
@export var texture: Texture2D
@export var damage_dot_texture: Texture2D

@export_group("Combat")
@export var max_hp: int = 3
# If the player's mining strength is below this, clicks do no damage and emit
# asteroid_deflected for a "clink" visual instead.
@export var min_strength_to_crack: int = 1

@export_group("Spawn")
@export var spawn_weight: float = 1.0
@export var speed_min: float = 60.0
@export var speed_max: float = 120.0

@export_group("Drops")
@export var resource_chances: Array[ResourceEntry] = []
@export var yield_min: int = 1
@export var yield_max: int = 3


# Build a Dictionary[resource -> chance] for GlobalResources.weighted_random.
func _weights() -> Dictionary:
	var w := {}
	for e in resource_chances:
		if e.chance > 0.0:
			w[e.resource] = e.chance
	return w


# Roll `randi_range(yield_min, yield_max)` weighted picks and aggregate them.
# Returns Dictionary[resource_name -> count].
func roll_drops() -> Dictionary:
	var weights := _weights()
	if weights.is_empty():
		return {}
	var roll_count: int = randi_range(yield_min, yield_max)
	var out: Dictionary = {}
	for _i in roll_count:
		var res: String = GlobalResources.weighted_random(weights)
		out[res] = int(out.get(res, 0)) + 1
	return out
