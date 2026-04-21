extends TabContainer

@onready var region_name: Label = $Info/RegionName
@onready var trash_bar: ProgressBar = $"Info/T&PContainer/Trash&Pollution/TrashDisplay/TrashBar"
@onready var trash_display: Label = $"Info/T&PContainer/Trash&Pollution/TrashDisplay/TrashDisplay"
@onready var region_pollution: TextureRect = $"Info/T&PContainer/Trash&Pollution/RegionPollution"
@onready var resource_grid: GridContainer = $Info/ResourceGrid
@onready var production_grid: GridContainer = $Info/ProductionGrid
@onready var region_description: Label = $"Info/DescContainer/Region Description"


func _ready():
	GlobalSignals.regionHovered.connect(onRegionHovered)
	GlobalSignals.regionTrashUpdated.connect(updateProgress)
	GlobalSignals.resourceRateUpdated.connect(onRateUpdated)
	hide()


var currentRegion: RegionData = null
func onRegionHovered(region: RegionData):
	show()
	if region != currentRegion:
		currentRegion = region
		updateInfo(region)
		updateResources(region)
		updateProgress(region)


func updateInfo(region: RegionData):
	region_name.text = region.regionName
	if region.locked == true:
		region_description.text = region.lockedDescription
	else:
		region_description.text = region.description


func updateResources(region: RegionData):
	for child in resource_grid.get_children(): #removes placeholder labels
		child.queue_free()
	for child in production_grid.get_children():
		child.queue_free()
		
	var limit := 0
	for entry in region.resourceChances: #sets labels based on region's resource chances
		if entry.chance > 0.0 and limit < 4: 
			var label = Label.new() 
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			label.text = "%s: %d%%" % [entry.resource.capitalize(), entry.chance*100]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			resource_grid.add_child(label)
			
			var rate_label = Label.new()
			rate_label.name = entry.resource.to_lower() + "_rate"
			rate_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rate_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			rate_label.text = "%s/S: 0" % entry.resource.capitalize()
			rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			production_grid.add_child(rate_label)
			
			limit += 1
 

func onRateUpdated(rates: Dictionary):
	for child in production_grid.get_children():
		if child.name.ends_with("_rate"):
			var resource_name = child.name.replace("_rate", "")
			var rate = rates.get(resource_name, 0)
			child.text = "%s/S: %d" % [resource_name.capitalize(), rate]

func updateProgress(region: RegionData):
	if region != currentRegion:
		return
	trash_bar.max_value = region.maxTrash
	trash_bar.value = region.trash
	trash_display.text = "%d / %d" % [region.trash, region.maxTrash]
	
	
func _on_tab_clicked(tab: int): #Lets the "X" tab close the menu
	if tab == 3:
		hide()
