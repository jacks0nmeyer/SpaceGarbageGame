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
# Fraction of vertical screen height around the centre that asteroids will
# never spawn into, so they don't fly over the planet/regions and steal clicks.
@export var planet_center_avoid_band: float = 0.35

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
	# Pick side and velocity sign.
	var from_left: bool = randf() < 0.5
	var speed: float = randf_range(data.speed_min, data.speed_max)
	var vx: float = speed if from_left else -speed
	var start_x: float = -tex_size.x - 4.0 if from_left else vp.x + 4.0
	# Pick Y outside the planet-avoidance band.
	var band: float = clamp(planet_center_avoid_band, 0.0, 0.9)
	var top_band_h: float = vp.y * (1.0 - band) * 0.5
	var bottom_band_top: float = vp.y - top_band_h
	var y: float
	if randf() < 0.5:
		y = randf_range(0.0, max(0.0, top_band_h - tex_size.y))
	else:
		y = randf_range(bottom_band_top, max(bottom_band_top, vp.y - tex_size.y))
	ast.position = Vector2(start_x, y)
	ast.velocity = Vector2(vx, 0.0)
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
