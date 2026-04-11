extends Control

@onready var region_2: TextureButton = $Region2
@onready var region_3: TextureButton = $Region3
@onready var region_4: TextureButton = $Region4


func ready(): #Lock regions
	region_2.disabled = true
	region_3.disabled = true
	region_4.disabled = true
