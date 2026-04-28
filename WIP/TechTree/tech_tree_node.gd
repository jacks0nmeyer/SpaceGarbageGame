extends TextureButton
class_name TechTreeNode

# Single tech node in the tree. Data-bound to a TechData via setup() before
# being added to the tree. Listens for techUnlocked / resourcesUpdated to keep
# its visual state in sync with affordability and prerequisites.

signal hovered(tech: TechData)
signal unhovered

@onready var label: Label = $Spacer/Label
@onready var check_button: CheckButton = $CheckButton

var tech: TechData


func setup(data: TechData) -> void:
	tech = data
	# _ready runs at add_child time (before setup), so its _refresh() call sees
	# tech == null and early-returns. Refresh again now that tech is bound.
	if is_node_ready():
		_refresh()


func _ready() -> void:
	check_button.show()
	label.hide()
	check_button.disabled = true
	check_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	GlobalSignals.techUnlocked.connect(_on_any_tech_unlocked)
	GlobalSignals.resourcesUpdated.connect(_on_resources_updated)
	_refresh()


func _refresh() -> void:
	if tech == null:
		return
	var unlocked: bool = TechTree.is_unlocked(tech)
	check_button.button_pressed = unlocked
	if unlocked:
		disabled = true
	else:
		disabled = not TechTree.can_unlock(tech)


func _on_pressed() -> void:
	if tech == null or TechTree.is_unlocked(tech):
		return
	TechTree.unlock(tech)
	# unlock() emits techUnlocked and updates resources, which triggers _refresh
	# via the connected signals.


func _on_any_tech_unlocked(_t) -> void:
	_refresh()


func _on_resources_updated(_resources: Dictionary) -> void:
	_refresh()


func _on_hover_in() -> void:
	if tech != null:
		hovered.emit(tech)


func _on_hover_out() -> void:
	unhovered.emit()
