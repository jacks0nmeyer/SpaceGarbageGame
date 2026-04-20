extends GridContainer

func _ready():
	GlobalSignals.resourcesUpdated.connect(onResourcesUpdated)
	onResourcesUpdated(GlobalResources.playerResources)
	
func onResourcesUpdated(resources: Dictionary):
	for child in get_children():
		child.queue_free()
	for resource in resources:
		if resources[resource] > 0:
			var label = Label.new()
			label.text = "%s: %d" % [resource.capitalize(), resources[resource]]
			add_child(label)
	
