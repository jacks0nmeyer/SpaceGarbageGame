extends VBoxContainer

# Drop target inside RegionInformation's Buildings tab. Accepts the same
# {"building": BuildingData, "from_region": RegionData|null} payload shape that
# OwnedBuildingCard / AssignedBuildingRow produce.

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("building") or not data.has("from_region"):
		return false
	var b = data["building"]
	if not (b is BuildingData):
		return false
	var target: RegionData = _current_region()
	if target == null or target.locked:
		return false
	var from_region = data["from_region"]
	if from_region == target:
		return false
	if from_region == null:
		if GlobalResources.unassigned_building_count(b) <= 0:
			return false
	return target.can_fit_building(b)


func _drop_data(_pos: Vector2, data) -> void:
	var target: RegionData = _current_region()
	if target == null:
		return
	GlobalResources.assign_one_building(data["building"], target, data["from_region"])


func _current_region() -> RegionData:
	# RegionInformation owns current_region; we're a direct child of it.
	var parent = get_parent()
	if parent == null:
		return null
	return parent.current_region
