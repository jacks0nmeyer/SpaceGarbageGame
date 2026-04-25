extends Control
class_name OwnedTab

# Drop target for un-assigning a robot. Drags from regions carry
# {"robot": RobotData, "from_region": RegionData}; dropping here decrements
# region.assignedRobots[robot] and emits robotUnassigned. Drags originating
# from this same tab (from_region == null) are no-ops on drop.

func _can_drop_data(_pos: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("robot") or not data.has("from_region"):
		return false
	if not (data["robot"] is RobotData):
		return false
	return data["from_region"] is RegionData


func _drop_data(_pos: Vector2, data) -> void:
	GlobalResources.unassignOne(data["robot"], data["from_region"])
