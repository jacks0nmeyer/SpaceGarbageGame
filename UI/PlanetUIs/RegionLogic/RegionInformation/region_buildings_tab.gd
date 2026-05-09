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
		if GlobalResources.unassignedBuildingCount(b) <= 0:
			return false
	return target.canFitBuilding(b)


func _drop_data(_pos: Vector2, data) -> void:
	var target: RegionData = _current_region()
	if target == null:
		return
	GlobalResources.assignOneBuilding(data["building"], target, data["from_region"])


func _current_region() -> RegionData:
	# RegionInformation owns currentRegion; we're a direct child of it.
	var parent = get_parent()
	if parent == null:
		return null
	return parent.currentRegion
