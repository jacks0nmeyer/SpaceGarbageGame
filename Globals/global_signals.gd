extends Node

@warning_ignore("unused_signal")
signal regionUnlocked(region: RegionData)

@warning_ignore("unused_signal")
signal resourcesUpdated(resources: Dictionary)

@warning_ignore("unused_signal")
signal resourceRateUpdated(rates: Dictionary)

@warning_ignore("unused_signal")
signal regionTrashUpdated(region: RegionData)

@warning_ignore("unused_signal")
signal planetTrashUpdated(planet: PlanetData)

@warning_ignore("unused_signal")
signal TotalTrashUpdated(total: int)

@warning_ignore("unused_signal")
signal regionHovered(region: RegionData)
