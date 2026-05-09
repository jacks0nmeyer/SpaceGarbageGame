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
	GlobalSignals.buildingPurchased.connect(_on_building_changed)
	GlobalSignals.buildingAssigned.connect(_on_building_pair_changed)
	GlobalSignals.buildingUnassigned.connect(_on_building_pair_changed)
	GlobalSignals.saveLoaded.connect(_refresh)
	_refresh()


func _populate_icon():
	for child in icon_holder.get_children():
		child.queue_free()
	if data.texture != null:
		var rect := TextureRect.new()
		rect.texture = data.texture
		rect.custom_minimum_size = Vector2(40, 40)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.add_child(rect)
	else:
		var color := ColorRect.new()
		color.color = Color(0.3, 0.3, 0.3)
		color.custom_minimum_size = Vector2(40, 40)
		icon_holder.add_child(color)


func _refresh():
	if data == null:
		return
	name_label.text = data.buildingName
	var unassigned := GlobalResources.unassignedBuildingCount(data)
	count_label.text = "Unassigned: %d / Total: %d" % [unassigned, data.amount]
	visible = data.amount > 0


func _on_building_changed(_b):
	_refresh()


func _on_building_pair_changed(_b, _region):
	_refresh()


func _get_drag_data(_pos):
	if data == null:
		return null
	if GlobalResources.unassignedBuildingCount(data) <= 0:
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
		rect.custom_minimum_size = Vector2(40, 40)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(rect)
	var label := Label.new()
	label.text = b.buildingName
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
	GlobalResources.unassignOneBuilding(drag_data["building"], drag_data["from_region"])
