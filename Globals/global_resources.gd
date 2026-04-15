extends Node

#Resources
var playerResources: Dictionary = {
	"junk": 4950,
	"scrap": 1490,
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


#gets a resource based on the chances of a specific region
func regionGotResource(region: RegionData, amount: int = 1):
	var resource : String = region.returnResource()
	if resource.is_empty():
		return
	gotResource(resource, amount)


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
	return true


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


	
