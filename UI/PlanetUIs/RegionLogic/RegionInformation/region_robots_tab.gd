extends MarginContainer

# Drop target inside RegionInformation's Robots tab. Accepts the same payload
# shape as the Region drop target ({"robot": RobotData, "from_region": ...})
# and assigns to whichever region the panel is currently showing.

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("robot") or not data.has("from_region"):
		return false
	var robot = data["robot"]
	if not (robot is RobotData):
		return false
	var target: RegionData = _current_region()
	if target == null or target.locked:
		return false
	var from_region = data["from_region"]
	if from_region == target:
		return false
	if from_region == null:
		if GlobalResources.unassignedCount(robot) <= 0:
			return false
	return target.canFit(robot)


func _drop_data(_pos: Vector2, data) -> void:
	var target: RegionData = _current_region()
	if target == null:
		return
	GlobalResources.assignOne(data["robot"], target, data["from_region"])


func _current_region() -> RegionData:
	# RegionInformation owns currentRegion; we're a direct child of it.
	var parent = get_parent()
	if parent == null:
		return null
	return parent.currentRegion
