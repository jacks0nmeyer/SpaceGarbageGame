class_name IconHelper
extends RefCounted

# Populates an icon-slot Control with either a centered TextureRect for the
# given texture, or a solid-color ColorRect fallback at the same size. Clears
# existing children first. Used by robot/building rows and owned cards.

static func populate(holder: Control, texture: Texture2D, size: Vector2, fallback: Color) -> void:
	for child in holder.get_children():
		child.queue_free()
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.custom_minimum_size = size
		rect.size = size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder.add_child(rect)
	else:
		var color := ColorRect.new()
		color.color = fallback
		color.custom_minimum_size = size
		holder.add_child(color)
