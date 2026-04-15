extends Control

@onready var junk_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/JunkLabel
@onready var scrap_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/ScrapLabel
@onready var plastic_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/PlasticLabel
@onready var glass_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/GlassLabel



func _process(_delta) -> void:
	update_resource_text()

func update_resource_text():
	junk_label.text = "Junk: " + str(GlobalResources.playerResources["junk"])
	scrap_label.text = "Scrap: " + str(GlobalResources.playerResources["scrap"])
	plastic_label.text = "Plastic: " + str(GlobalResources.playerResources["plastic"])
	glass_label.text = "Glass: " + str(GlobalResources.playerResources["glass"])
