extends Control

@onready var junk_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/JunkLabel
@onready var scrap_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/ScrapLabel
@onready var plastic_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/PlasticLabel
@onready var glass_label: Label = $ResourceMarginContainer/ResourceHBoxContainer/GlassLabel



func _process(_delta) -> void:
	update_resource_text()

func update_resource_text():
	junk_label.text = "Junk: " + str(GlobalResources.junk)
	scrap_label.text = "Scrap: " + str(GlobalResources.scrap)
	plastic_label.text = "Plastic: " + str(GlobalResources.plastic)
	glass_label.text = "Glass: " + str(GlobalResources.glass)
