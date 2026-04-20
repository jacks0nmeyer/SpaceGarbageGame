extends Node

#Resources
var playerResources: Dictionary = {
	"junk": 10000,
	"scrap": 5000,
	"plastic": 0,
	"glass": 0,
}

#Modifiers
var globalMultiplier:= 1

var multipliers: Dictionary = {
	"junk": 1,
	"scrap": 1,
	"plastic": 1,
	"glass": 1,
}


#Player gains a resource
func gotResource(resource: String, amount: int):
	var lcResource := resource.to_lower()
	if playerResources.has(lcResource):
		playerResources[lcResource] += amount * multipliers.get(lcResource, 1) * globalMultiplier
		GlobalSignals.resourcesUpdated.emit(playerResources)


#gets a resource based on the chances of a specific region, also removes trash from that region
func regionGotResource(region: RegionData, planet: PlanetData, amount: int = 1):
	if region.trash <= 0:
		return
	var resource : String = region.returnResource()
	if resource.is_empty():
		return
	region.trash = max(0, region.trash - amount)
	gotResource(resource, amount)
	GlobalSignals.regionTrashUpdated.emit(region)
	GlobalSignals.planetTrashUpdated.emit(planet)
	#GlobalSignals.TotalTrashUpdated.emit(getSolarSystemTrash())


#purchase functions
func can_afford(cost: Dictionary) -> bool:
	for resource in cost:
		if playerResources.get(resource.to_lower(), 0) < cost[resource]:
			return false
	return true


func purchase(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for resource in cost:
		playerResources[resource.to_lower()] -= cost[resource]
		GlobalSignals.resourcesUpdated.emit(playerResources)
	return true


#Trash Logic
var solarSystem: SolarSystemData = preload("res://Resources/SolarSystem/SolarSystem.tres")

func getPlanetTrash(planet: PlanetData) -> int:
	return planet.getTotalTrash()


#func getSolarSystemTrash() -> int:
	#return solarSystem.getTotalTrash()


#picks an item based on chances between 0 and 1 
func weighted_random(weights: Dictionary) -> Variant:
	var roll := randf()
	var cumulative := 0.0
	for item in weights:
			cumulative += weights[item]
			if roll < cumulative:
				return item
	return weights.keys().back()


#Progress
var totalSystemTrash
var totalSystemPollution


	
