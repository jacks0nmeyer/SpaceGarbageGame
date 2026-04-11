extends Control

@onready var trash_progress_bar: ProgressBar = $MarginContainer/VBoxContainer/TrashProgressBar
@onready var pollution_progress_bar: ProgressBar = $MarginContainer/VBoxContainer/PollutionProgressBar


func _process(_delta) -> void:
	trash_progress_bar.value = EarthGlobal.earthTrash
	
	
