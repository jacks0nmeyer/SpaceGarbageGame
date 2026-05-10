extends GridContainer

# Resources we want pinned even at zero (so the player can see Research Points
# from session start). Other resources only render once they've been earned.
const ALWAYS_SHOW: PackedStringArray = ["research"]

var _viewport: Viewport


func _ready():
	GlobalSignals.resourcesUpdated.connect(onResourcesUpdated)
	_viewport = get_viewport()
	if _viewport != null:
		_viewport.size_changed.connect(_schedule_fit_root_height)
	onResourcesUpdated(GlobalResources.playerResources)


func _exit_tree() -> void:
	if is_instance_valid(_viewport) and _viewport.size_changed.is_connected(_schedule_fit_root_height):
		_viewport.size_changed.disconnect(_schedule_fit_root_height)


func _schedule_fit_root_height() -> void:
	if not is_inside_tree():
		return
	if get_child_count() > 0:
		call_deferred("_fit_root_height")


func onResourcesUpdated(resources: Dictionary):
	for child in get_children():
		child.queue_free()
	for resource in resources:
		if resources[resource] > 0 or resource in ALWAYS_SHOW:
			var label := Label.new()
			label.text = "%s: %s" % [resource.capitalize(), _format_amount(int(resources[resource]))]
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(label)
	call_deferred("_fit_root_height")


func _format_amount(n: int) -> String:
	var neg := n < 0
	var v := str(abs(n))
	var parts: Array[String] = []
	while v.length() > 3:
		parts.push_front(v.substr(v.length() - 3, 3))
		v = v.substr(0, v.length() - 3)
	if v.length() > 0:
		parts.push_front(v)
	var body := ""
	for i in parts.size():
		if i > 0:
			body += ","
		body += parts[i]
	return ("-" if neg else "") + body


func _fit_root_height() -> void:
	if not is_inside_tree():
		return
	var margin: MarginContainer = get_parent() as MarginContainer
	if margin == null:
		return
	var root: Control = margin.get_parent() as Control
	if root == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	margin = get_parent() as MarginContainer
	if not is_instance_valid(margin):
		return
	root = margin.get_parent() as Control
	if not is_instance_valid(root):
		return
	var top: int = int(margin.get_theme_constant("margin_top", "MarginContainer"))
	var bottom: int = int(margin.get_theme_constant("margin_bottom", "MarginContainer"))
	var inner_h: float = maxf(get_minimum_size().y, size.y)
	var new_bottom: float = root.offset_top + inner_h + float(top + bottom) + 4.0
	if absf(root.offset_bottom - new_bottom) > 1.0:
		root.offset_bottom = new_bottom
