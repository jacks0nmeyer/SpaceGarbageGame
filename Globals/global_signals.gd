extends Node

@warning_ignore("unused_signal")
signal regionUnlocked(region: RegionData)

@warning_ignore("unused_signal")
signal resourcesUpdated(resources: Dictionary)

@warning_ignore("unused_signal")
signal regionTrashUpdated(region: RegionData)

@warning_ignore("unused_signal")
signal planetTrashUpdated(planet: PlanetData)

@warning_ignore("unused_signal")
signal TotalTrashUpdated(total: int)

@warning_ignore("unused_signal")
signal regionHovered(region: RegionData)

@warning_ignore("unused_signal")
signal robotPurchased(robot: RobotData)

@warning_ignore("unused_signal")
signal robotAssigned(robot: RobotData, region: RegionData)

@warning_ignore("unused_signal")
signal robotUnassigned(robot: RobotData, region: RegionData)

@warning_ignore("unused_signal")
signal regionPinToggled(region: RegionData)

@warning_ignore("unused_signal")
signal regionPollutionUpdated(region: RegionData)

@warning_ignore("unused_signal")
signal planetPollutionUpdated(planet: PlanetData)

@warning_ignore("unused_signal")
signal techUnlocked(tech: TechData)

@warning_ignore("unused_signal")
signal researchMilestoneAwarded(region: RegionData, points: int, planet: PlanetData)
