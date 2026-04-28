extends GridContainer

# Resources we want pinned even at zero (so the player can see Research Points
# from session start). Other resources only render once they've been earned.
const ALWAYS_SHOW: PackedStringArray = ["research"]


func _ready():
	GlobalSignals.resourcesUpdated.connect(onResourcesUpdated)
	onResourcesUpdated(GlobalResources.playerResources)


func onResourcesUpdated(resources: Dictionary):
	for child in get_children():
		child.queue_free()
	for resource in resources:
		if resources[resource] > 0 or resource in ALWAYS_SHOW:
			var label = Label.new()
			label.text = "%s: %d" % [resource.capitalize(), resources[resource]]
			add_child(label)
