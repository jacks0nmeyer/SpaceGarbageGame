extends VBoxContainer

@onready var region_name: Label = $RegionName
@onready var trash_bar: ProgressBar = $"T&PContainer/Trash&Pollution/TrashDisplay/TrashBar"
@onready var trash_display: Label = $"T&PContainer/Trash&Pollution/TrashDisplay/TrashDisplay"
@onready var region_pollution: TextureRect = $"T&PContainer/Trash&Pollution/RegionPollution"
@onready var resource_grid: GridContainer = $ResourceGrid
@onready var production_grid: GridContainer = $ProductionGrid
@onready var region_description: Label = $"DescContainer/Region Description"


func _ready():
	GlobalSignals.regionHovered.connect(onRegionHovered)
	GlobalSignals.regionTrashUpdated.connect(updateProgress)
	hide()


func onRegionHovered(region: RegionData):
	show()
	updateInfo(region)
	updateResources(region)
	updateProgress(region)


func updateInfo(region: RegionData):
	region_name.text = region.name
	region_description.text = region.description


func updateResources(region: RegionData):
	for child in resource_grid.get_children(): #removes placeholder labels
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


func updateProgress(region: RegionData):
	trash_bar.max_value = region.maxTrash
	trash_bar.value = region.trash
	trash_display.text = "%d / %d" % [region.trash, region.maxTrash]
	
