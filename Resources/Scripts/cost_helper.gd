class_name CostHelper
extends RefCounted

# Shared helper for converting an `Array[CostEntry]` into the
# `Dictionary[resource_string -> amount_int]` shape that
# `GlobalResources.can_afford()` / `purchase()` expect.
#
# Callers with scaling (e.g. RobotRow.current_cost applies cost_increase ^ amount
# and TechTree.get_robot_cost_scalar) still build their own dict — this only
# handles the flat case shared by TechData, RegionLock, and BuildingRow.

static func to_dict(entries: Array[CostEntry]) -> Dictionary:
	var dict := {}
	for entry in entries:
		dict[entry.resource] = int(entry.amount)
	return dict
