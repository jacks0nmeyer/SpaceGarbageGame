class_name RobotData
extends Resource

@export var robot_name: String

@export_group("Textures")
@export var texture: Texture2D
@export var ui_sprite: Texture2D

@export_group("PurchaseData")
@export var description: String
@export var unlock_cost: Array[CostEntry] = []
@export var cost_increase: float
@export var amount: int

@export_group ("Stats")
@export var size: int
@export var production_rate: float
@export var resource_return: float
@export var pollution_effect: float
@export var works_in_water: bool = true
