extends TextureButton
class_name TechTreeNode

#each node will need to be individually programmed once placed within the tech tree

@onready var label: Label = $Spacer/Label
@onready var node_connector: Line2D = $NodeConnector
@onready var check_button: CheckButton = $CheckButton


var ifCheck := false #set to true  if node is 1 time use
var amount:= 5 #number of total skill points allowed
var level:= 0: #current level of node
	set(value):
		level = value
		label.text = str(level) + "/" + str(amount)


func _ready():
	label.text = str(level) + "/" + str(amount)
	if get_parent() is TechTreeNode: #Creates path to child nodes
		node_connector.add_point(global_position + size/2)
		node_connector.add_point(get_parent().global_position + size/2)
		disabled = true
	if ifCheck == true: #creates checkbox
		check_button.show()
		label.hide()
	

func _on_pressed():
	level = min(level+1, amount) #increases level of node
	node_connector.default_color = Color(0.712, 0.712, 0.712, 1.0) #highlights path to unlocked nodes
	for child in get_children(): #unlocks child nodes
		if child is TextureButton and level >= (amount/2.00):
			child.disabled = false
			
