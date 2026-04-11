extends Node
#Upgrades
var trashGrabberPower := 1
var upgrade1Amount := 0
var upgrade1Cost := 20


var upgrade2Amount := 0
var upgrade2Cost := 100


#Progress
var earthTrash := 1000000
var earthPollution := 1.00


# Buildings
const MAX_BUILDINGS_EARTH := 80
const MAX_BUILDINGS_REGION := 20
var totalBuildsEarth := 0
var region_builds = {"1": 0, "2": 0, "3": 0, "4": 0}

# Function that increments totalBuildsEarth. If adding exceeds max, we return false and set var to max. Otherwise, return true
func addBuilding():
	# Increment and run check
	totalBuildsEarth += 1
	if totalBuildsEarth > MAX_BUILDINGS_EARTH:
		totalBuildsEarth = MAX_BUILDINGS_EARTH
		return false
		
	# For now, just loop through all four regions and try to add to next one
	var success = false
	var i = 0
	while not success:
		i += 1
		success = assignBuilding(str(i))
	
	# Return true if falls through
	print("Success adding building to region " + str(i) + ". Region total now at: " + str(region_builds[str(i)]))
	return true

# Function that tries to assign one building to passed region. Returns true if successful, else false
func assignBuilding(region):
	# Make sure region is valid
	if not region_builds.has(region):
		return false
	
	# Increment region builds. If too much, change back and return false
	region_builds[region] += 1
	if region_builds[region] > MAX_BUILDINGS_REGION:
		region_builds[region] = MAX_BUILDINGS_REGION
		return false
	
	# Return true if falls through successfully
	return true
