extends TextureButton
class_name Asteroid

# A single in-flight asteroid. Drifts across the screen on an angled path; each click subtracts the
# player's mining_strength from hp. Below the asteroid's min_strength_to_crack
# clicks emit asteroid_deflected and do no damage. Breaking awards a bundle of
# drops via AsteroidData.roll_drops().

@export var data: AsteroidData

var velocity: Vector2 = Vector2.ZERO
var hp: int = 0
var _dot_parent: Control = null
var _allow_vertical_despawn: bool = false
const EDGE_MARGIN: float = 64.0


func _ready() -> void:
	if data == null:
		queue_free()
		return
	hp = data.max_hp
	texture_normal = data.texture
	modulate = data.tint
	if texture_normal:
		var img := texture_normal.get_image()
		var bm := BitMap.new()
		bm.create_from_image_alpha(img)
		texture_click_mask = bm
		# Size the control to the texture; pivot is centre for rotation only.
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
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()


func _process(delta: float) -> void:
	if GameManager.production_paused:
		return
	position += velocity * delta
	var vp: Vector2 = get_viewport_rect().size
	var m: float = EDGE_MARGIN
	var center_x: float = position.x + size.x * 0.5
	if not _allow_vertical_despawn:
		if velocity.x > 0.0 and center_x >= vp.x * 0.5:
			_allow_vertical_despawn = true
		elif velocity.x < 0.0 and center_x <= vp.x * 0.5:
			_allow_vertical_despawn = true
	# Free once fully off a horizontal edge (position is top-left).
	if position.x + size.x < -m or position.x > vp.x + m:
		queue_free()
		return
	if _allow_vertical_despawn and (position.y + size.y < -m or position.y > vp.y + m):
		queue_free()


func _on_pressed() -> void:
	var strength: int = TechTree.get_mining_strength()
	var hit_pos: Vector2 = get_global_mouse_position()
	if strength < data.min_strength_to_crack:
		GlobalSignals.asteroid_deflected.emit(data, hit_pos)
		return
	hp -= strength
	GlobalSignals.asteroid_hit.emit(data, hit_pos, strength)
	_spawn_damage_dots(strength)
	if hp <= 0:
		var drops: Dictionary = data.roll_drops()
		for res in drops:
			GlobalResources.got_resource(res, int(drops[res]))
		GlobalSignals.asteroid_broken.emit(data, drops)
		queue_free()


# Add `amount` little black dots scattered inside the inscribed square of the
# asteroid circle. Good enough for placeholder art; rejection-sample by alpha
# later if the silhouette becomes non-circular.
func _spawn_damage_dots(amount: int) -> void:
	if data.damage_dot_texture == null or _dot_parent == null:
		return
	var dot_size: Vector2 = data.damage_dot_texture.get_size()
	# Inscribed square inside the circle: side = diameter / sqrt(2).
	var inset: float = size.x * (1.0 - 1.0 / sqrt(2.0)) * 0.5
	var min_x: float = inset
	var max_x: float = size.x - inset - dot_size.x
	var min_y: float = inset
	var max_y: float = size.y - inset - dot_size.y
	for _i in amount:
		var dot := TextureRect.new()
		dot.texture = data.damage_dot_texture
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		_dot_parent.add_child(dot)
