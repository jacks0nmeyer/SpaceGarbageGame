class_name AsteroidData
extends Resource

# A single asteroid archetype: art, HP, drop table, spawn weight.
# Authored as .tres in Resources/Asteroids/.

@export var display_name: String = ""

@export_group("Visuals")
@export var texture: Texture2D
@export var damage_dot_texture: Texture2D
@export var tint: Color = Color.WHITE

@export_group("Combat")
@export var max_hp: int = 3
# If the player's mining strength is below this, clicks do no damage and emit
# asteroid_deflected for a "clink" visual instead.
@export var min_strength_to_crack: int = 1

@export_group("Spawn")
@export var spawn_weight: float = 1.0
@export var speed_min: float = 101.08
@export var speed_max: float = 111.72
@export var path_angle_min_deg: float = 5.0
@export var path_angle_max_deg: float = 25.0

@export_group("Drops")
@export var resource_chances: Array[ResourceEntry] = []
@export var yield_min: int = 1
@export var yield_max: int = 3


# Roll speed and a signed angle off horizontal for this spawn. Angles are
# clamped so the path stays in the vertical margins until the far horizontal
# edge, and forced toward the viewport midline so every asteroid crosses it.
func compute_spawn_velocity(
	from_left: bool,
	spawn_y: float,
	cross_width: float,
	y_margin_min: float,
	y_margin_max: float,
	viewport_mid_y: float,
) -> Vector2:
	var speed: float = randf_range(speed_min, speed_max)
	if cross_width <= 0.0:
		cross_width = 1.0
	var geom_lo: float = atan((y_margin_min - spawn_y) / cross_width)
	var geom_hi: float = atan((y_margin_max - spawn_y) / cross_width)
	if geom_lo > geom_hi:
		var swap: float = geom_lo
		geom_lo = geom_hi
		geom_hi = swap
	var auth_lo: float = deg_to_rad(path_angle_min_deg)
	var auth_hi: float = deg_to_rad(path_angle_max_deg)
	var angle_to_mid: float = atan((viewport_mid_y - spawn_y) / cross_width)
	var angle_rad: float
	if spawn_y < viewport_mid_y:
		# Top half: slope downward and cross the midline before exiting.
		var lo: float = maxf(maxf(geom_lo, auth_lo), angle_to_mid)
		var hi: float = minf(geom_hi, auth_hi)
		if lo <= hi:
			angle_rad = randf_range(lo, hi)
		else:
			angle_rad = clampf(maxf(angle_to_mid, auth_lo), geom_lo, geom_hi)
	elif spawn_y > viewport_mid_y:
		# Bottom half: slope upward and cross the midline before exiting.
		var lo: float = maxf(geom_lo, -auth_hi)
		var hi: float = minf(minf(geom_hi, -auth_lo), angle_to_mid)
		if lo <= hi:
			angle_rad = randf_range(lo, hi)
		else:
			angle_rad = clampf(minf(angle_to_mid, -auth_lo), geom_lo, geom_hi)
	else:
		var positive_lo: float = maxf(geom_lo, auth_lo)
		var positive_hi: float = minf(geom_hi, auth_hi)
		var negative_lo: float = maxf(geom_lo, -auth_hi)
		var negative_hi: float = minf(geom_hi, -auth_lo)
		if randf() < 0.5 and positive_lo <= positive_hi:
			angle_rad = randf_range(positive_lo, positive_hi)
		elif negative_lo <= negative_hi:
			angle_rad = randf_range(negative_lo, negative_hi)
		elif positive_lo <= positive_hi:
			angle_rad = randf_range(positive_lo, positive_hi)
		else:
			angle_rad = clampf((geom_lo + geom_hi) * 0.5, geom_lo, geom_hi)
	# Angle math above assumes RIGHT base (vy = sin(angle)). LEFT.rotated flips vy,
	# so mirror the angle when spawning from the right.
	if not from_left:
		angle_rad = -angle_rad
	var base_dir: Vector2 = Vector2.RIGHT if from_left else Vector2.LEFT
	return base_dir.rotated(angle_rad) * speed


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
