extends PanelContainer
class_name OwnedBuildingCard

# Owned card for one building type. Drags carry
# {"building": BuildingData, "from_region": null}; the Buildings tab inside
# RegionInformation accepts the drop.

@export var data: BuildingData

@onready var icon_holder: Control = $Margin/HBox/IconHolder
@onready var name_label: Label = $Margin/HBox/Info/NameLabel
@onready var count_label: Label = $Margin/HBox/Info/CountLabel


func _ready():
	if data == null:
		return
	_populate_icon()
	GlobalSignals.building_purchased.connect(_on_building_changed)
	GlobalSignals.building_assigned.connect(_on_building_pair_changed)
	GlobalSignals.building_unassigned.connect(_on_building_pair_changed)
	GlobalSignals.save_loaded.connect(_refresh)
	_refresh()


func _populate_icon():
	IconHelper.populate(icon_holder, data.texture, Vector2(34, 34), Color(0.3, 0.3, 0.3))


func _refresh():
	if data == null:
		return
	name_label.text = data.building_name
	var unassigned := GlobalResources.unassigned_building_count(data)
	count_label.text = "Unassigned: %d / Total: %d" % [unassigned, data.amount]
	visible = data.amount > 0


func _on_building_changed(_b):
	_refresh()


func _on_building_pair_changed(_b, _region):
	_refresh()


func _get_drag_data(_pos):
	if data == null:
		return null
	if GlobalResources.unassigned_building_count(data) <= 0:
		return null
	set_drag_preview(_make_drag_preview(data))
	return {"building": data, "from_region": null}


static func _make_drag_preview(b: BuildingData) -> Control:
	var preview := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	preview.add_child(hbox)
	if b.texture != null:
		var rect := TextureRect.new()
		rect.texture = b.texture
		rect.custom_minimum_size = Vector2(34, 34)
		rect.size = Vector2(34, 34)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(rect)
	var label := Label.new()
	label.text = b.building_name
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	return preview


# Owned cards also act as a drop target for unassigning a building dragged
# from a region's Buildings tab.
func _can_drop_data(_pos: Vector2, drag_data) -> bool:
	if typeof(drag_data) != TYPE_DICTIONARY:
		return false
	if not drag_data.has("building") or not drag_data.has("from_region"):
		return false
	if drag_data["building"] != data:
		return false
	return drag_data["from_region"] is RegionData


func _drop_data(_pos: Vector2, drag_data) -> void:
	GlobalResources.unassign_one_building(drag_data["building"], drag_data["from_region"])
