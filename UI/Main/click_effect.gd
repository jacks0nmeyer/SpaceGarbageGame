extends CanvasLayer

# Spawns a small burst of fading pixels at a click position. Driven by
# GlobalSignals.region_clicked (white burst) and GlobalSignals.asteroid_hit /
# asteroid_deflected (white and cyan respectively) so the effect only fires
# for gameplay clicks — not menu/UI button presses. Particles are anchored
# at the spawn position and don't follow the cursor.

const PARTICLE_COUNT := 8
const PARTICLE_SIZE := Vector2(4, 4)
const PARTICLE_DISTANCE := 18.0
const PARTICLE_DURATION := 0.35
const PARTICLE_COLOR := Color(1, 1, 1, 1)
const ASTEROID_DEFLECT_COLOR := Color(0.5, 0.85, 1.0, 1.0)


func _ready() -> void:
	GlobalSignals.region_clicked.connect(_spawn_burst)
	GlobalSignals.asteroid_hit.connect(_on_asteroid_hit)
	GlobalSignals.asteroid_deflected.connect(_on_asteroid_deflected)


func _on_asteroid_hit(_asteroid: AsteroidData, pos: Vector2, _damage: int) -> void:
	_spawn_burst(pos)


func _on_asteroid_deflected(_asteroid: AsteroidData, pos: Vector2) -> void:
	_spawn_burst(pos, ASTEROID_DEFLECT_COLOR)


func _spawn_burst(pos: Vector2, color: Color = PARTICLE_COLOR) -> void:
	for i in PARTICLE_COUNT:
		var angle: float = (TAU / PARTICLE_COUNT) * i + randf_range(-0.25, 0.25)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var pixel := ColorRect.new()
		pixel.color = color
		pixel.size = PARTICLE_SIZE
		pixel.position = pos - PARTICLE_SIZE * 0.5
		pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pixel)
		var target: Vector2 = pixel.position + dir * PARTICLE_DISTANCE
		var tween := create_tween().set_parallel(true)
		tween.tween_property(pixel, "position", target, PARTICLE_DURATION) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(pixel, "modulate:a", 0.0, PARTICLE_DURATION)
		tween.chain().tween_callback(pixel.queue_free)
