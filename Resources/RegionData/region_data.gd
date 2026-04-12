class_name RegionData
extends Resource


@export_group("Textures")
@export var texture_normal: Texture2D
@export var texture_hover: Texture2D
@export var texture_disabled: Texture2D


@export_group("Resource Chance")
@export var junk_chance:= 0.00
@export var scrap_chance:= 0.00
@export var plastic_chance:= 0.00
@export var glass_chance:= 0.00


@export var building:= false
@export var robot_capacity:= 4


@export var trash:= 0
@export var pollution:= 0


@export var locked:= true
