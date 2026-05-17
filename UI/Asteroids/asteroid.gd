extends TextureButton
class_name Asteroid

# A single in-flight asteroid. Drifts horizontally; each click subtracts the
# player's mining_strength from hp. Below the asteroid's minStrengthToCrack
# clicks emit asteroidDeflected and do no damage. Breaking awards a bundle of
# drops via AsteroidData.rollDrops().

@export var data: AsteroidData

var velocity: Vector2 = Vector2.ZERO
var hp: int = 0
var _dot_parent: Control = null
const EDGE_MARGIN: float = 64.0


func _ready() -> void:
	if data == null:
		queue_free()
		return
	hp = data.maxHp
	texture_normal = data.texture
	if texture_normal:
		var img := texture_normal.get_image()
		var bm := BitMap.new()
		bm.create_from_image_alpha(img)
		texture_click_mask = bm
		# Pivot/size so position is treated as the asteroid's centre.
		var tex_size: Vector2 = texture_normal.get_size()
		custom_minimum_size = tex_size
		size = tex_size
		pivot_offset = tex_size * 0.5
	# Damage dots are children of a separate Control that ignores mouse input
	# so they don't shrink the click mask coverage.
	_dot_parent = Control.new()
	_dot_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot_parent.anchor_right = 1.0
	_dot_parent.anchor_bottom = 1.0
	add_child(_dot_parent)
	pressed.connect(_on_pressed)


func _process(delta: float) -> void:
	if GameManager.production_paused:
		return
	position += velocity * delta
	var vp: Vector2 = get_viewport_rect().size
	# Free once fully off either side.
	if velocity.x > 0 and position.x > vp.x + EDGE_MARGIN:
		queue_free()
	elif velocity.x < 0 and position.x + size.x < -EDGE_MARGIN:
		queue_free()


func _on_pressed() -> void:
	var strength: int = TechTree.get_mining_strength()
	var hit_pos: Vector2 = get_global_mouse_position()
	if strength < data.minStrengthToCrack:
		GlobalSignals.asteroidDeflected.emit(data, hit_pos)
		return
	hp -= strength
	GlobalSignals.asteroidHit.emit(data, hit_pos, strength)
	_spawn_damage_dots(strength)
	if hp <= 0:
		var drops: Dictionary = data.rollDrops()
		for res in drops:
			GlobalResources.gotResource(res, int(drops[res]))
		GlobalSignals.asteroidBroken.emit(data, drops)
		queue_free()


# Add `amount` little black dots scattered inside the inscribed square of the
# asteroid circle. Good enough for placeholder art; rejection-sample by alpha
# later if the silhouette becomes non-circular.
func _spawn_damage_dots(amount: int) -> void:
	if data.damageDotTexture == null or _dot_parent == null:
		return
	var dot_size: Vector2 = data.damageDotTexture.get_size()
	# Inscribed square inside the circle: side = diameter / sqrt(2).
	var inset: float = size.x * (1.0 - 1.0 / sqrt(2.0)) * 0.5
	var min_x: float = inset
	var max_x: float = size.x - inset - dot_size.x
	var min_y: float = inset
	var max_y: float = size.y - inset - dot_size.y
	for _i in amount:
		var dot := TextureRect.new()
		dot.texture = data.damageDotTexture
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		_dot_parent.add_child(dot)
