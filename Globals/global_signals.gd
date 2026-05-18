extends Node

@warning_ignore("unused_signal")
signal region_unlocked(region: RegionData)

@warning_ignore("unused_signal")
signal resources_updated(resources: Dictionary)

@warning_ignore("unused_signal")
signal region_trash_updated(region: RegionData)

@warning_ignore("unused_signal")
signal planet_trash_updated(planet: PlanetData)

@warning_ignore("unused_signal")
signal total_trash_updated(total: int)

@warning_ignore("unused_signal")
signal region_hovered(region: RegionData)

@warning_ignore("unused_signal")
signal robot_purchased(robot: RobotData)

@warning_ignore("unused_signal")
signal robot_assigned(robot: RobotData, region: RegionData)

@warning_ignore("unused_signal")
signal robot_unassigned(robot: RobotData, region: RegionData)

@warning_ignore("unused_signal")
signal region_pin_toggled(region: RegionData)

@warning_ignore("unused_signal")
signal region_pollution_updated(region: RegionData)

@warning_ignore("unused_signal")
signal planet_pollution_updated(planet: PlanetData)

@warning_ignore("unused_signal")
signal tech_unlocked(tech: TechData)

@warning_ignore("unused_signal")
signal save_loaded

@warning_ignore("unused_signal")
signal region_clicked(position: Vector2)

@warning_ignore("unused_signal")
signal robot_panel_requested

@warning_ignore("unused_signal")
signal building_panel_requested

@warning_ignore("unused_signal")
signal building_purchased(building: BuildingData)

@warning_ignore("unused_signal")
signal building_assigned(building: BuildingData, region: RegionData)

@warning_ignore("unused_signal")
signal building_unassigned(building: BuildingData, region: RegionData)

@warning_ignore("unused_signal")
signal building_storage_updated(region: RegionData, building: BuildingData)

@warning_ignore("unused_signal")
signal building_worker_assigned(robot: RobotData, region: RegionData, building: BuildingData)

@warning_ignore("unused_signal")
signal building_worker_unassigned(robot: RobotData, region: RegionData, building: BuildingData)

@warning_ignore("unused_signal")
signal purchase_alert_changed(category: String, active: bool)

@warning_ignore("unused_signal")
signal asteroid_spawned(asteroid: AsteroidData)

@warning_ignore("unused_signal")
signal asteroid_hit(asteroid: AsteroidData, position: Vector2, damage: int)

@warning_ignore("unused_signal")
signal asteroid_deflected(asteroid: AsteroidData, position: Vector2)

@warning_ignore("unused_signal")
signal asteroid_broken(asteroid: AsteroidData, drops: Dictionary)
