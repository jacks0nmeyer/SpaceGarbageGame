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

@warning_ignore("unused_signal")
signal saveLoaded

@warning_ignore("unused_signal")
signal regionClicked(position: Vector2)

@warning_ignore("unused_signal")
signal robotPanelRequested

@warning_ignore("unused_signal")
signal buildingPanelRequested

@warning_ignore("unused_signal")
signal buildingPurchased(building: BuildingData)

@warning_ignore("unused_signal")
signal buildingAssigned(building: BuildingData, region: RegionData)

@warning_ignore("unused_signal")
signal buildingUnassigned(building: BuildingData, region: RegionData)

@warning_ignore("unused_signal")
signal buildingStorageUpdated(region: RegionData, building: BuildingData)

@warning_ignore("unused_signal")
signal buildingWorkerAssigned(robot: RobotData, region: RegionData, building: BuildingData)

@warning_ignore("unused_signal")
signal buildingWorkerUnassigned(robot: RobotData, region: RegionData, building: BuildingData)

@warning_ignore("unused_signal")
signal purchaseAlertChanged(category: String, active: bool)
