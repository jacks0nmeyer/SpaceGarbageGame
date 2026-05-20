extends CanvasLayer
class_name AsteroidSpawner

# Periodically spawns Asteroid scenes that drift across the screen. Spawn
# weights are drawn from AsteroidCollection. Movement and timer accumulation
# both respect GameManager.production_paused, so the global pause button
# freezes asteroid traffic in place.

const ASTEROID_SCENE := preload("res://UI/Asteroids/asteroid.tscn")

@export var collection: AsteroidCollection
@export var spawn_interval_min: float = 12.0
@export var spawn_interval_max: float = 30.0
# Fraction of viewport height (centred) where asteroid centres may spawn.
@export_range(0.1, 1.0) var spawn_y_screen_fraction: float = 0.85

var _time_to_next: float = 0.0


func _ready() -> void:
	# Seed the first delay short-ish so the world doesn't feel empty after a
	# fresh launch or scene reload.
	_time_to_next = randf_range(2.0, max(2.0, spawn_interval_max * 0.5))


func _process(delta: float) -> void:
	if GameManager.production_paused:
		return
	if collection == null or collection.asteroids.is_empty():
		return
	_time_to_next -= delta
	if _time_to_next <= 0.0:
		_spawn_one()
		_time_to_next = randf_range(spawn_interval_min, spawn_interval_max)


func _spawn_one() -> void:
	var data: AsteroidData = _pick_asteroid()
	if data == null:
		return
	var ast: Asteroid = ASTEROID_SCENE.instantiate()
	ast.data = data
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = data.texture.get_size() if data.texture else Vector2(32, 32)
	var half: Vector2 = tex_size * 0.5
	var path_y_min: float = half.y
	var path_y_max: float = max(half.y, vp.y - half.y)
	var band_inset: float = (1.0 - clampf(spawn_y_screen_fraction, 0.1, 1.0)) * 0.5
	var spawn_center_y_min: float = maxf(path_y_min, vp.y * band_inset)
	var spawn_center_y_max: float = minf(path_y_max, vp.y * (1.0 - band_inset))
	if spawn_center_y_min > spawn_center_y_max:
		spawn_center_y_min = path_y_min
		spawn_center_y_max = path_y_max
	var from_left: bool = randf() < 0.5
	var off_margin: float = 4.0
	var center_x: float
	var exit_center_x: float
	if from_left:
		center_x = -half.x - off_margin
		exit_center_x = vp.x + Asteroid.EDGE_MARGIN + half.x
	else:
		center_x = vp.x + half.x + off_margin
		exit_center_x = -Asteroid.EDGE_MARGIN - half.x
	var cross_width: float = absf(exit_center_x - center_x)
	var center_y: float = randf_range(spawn_center_y_min, spawn_center_y_max)
	var viewport_mid_y: float = vp.y * 0.5
	ast.position = Vector2(center_x - half.x, center_y - half.y)
	ast.velocity = data.compute_spawn_velocity(
		from_left,
		center_y,
		cross_width,
		path_y_min,
		path_y_max,
		viewport_mid_y,
	)
	add_child(ast)
	GlobalSignals.asteroid_spawned.emit(data)


func _pick_asteroid() -> AsteroidData:
	var weights: Dictionary = {}
	for a in collection.asteroids:
		if a != null and a.spawn_weight > 0.0:
			weights[a] = a.spawn_weight
	if weights.is_empty():
		return null
	# Normalise weights so weighted_random's roll < cumulative test sums to 1.
	var total: float = 0.0
	for k in weights:
		total += weights[k]
	if total <= 0.0:
		return null
	for k in weights:
		weights[k] = weights[k] / total
	var picked: Variant = GlobalResources.weighted_random(weights)
	return picked as AsteroidData
